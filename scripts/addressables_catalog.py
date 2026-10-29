"""Decode a built Addressables content catalog (catalog.json, or catalog.bin of Addressables 2.x) into the entries an
editor would need to rebuild it.

The AssetRipper export has the addressable assets but not the editor-only AddressableAssetSettings/groups. The player
catalog still records, per asset: its bundle, its address and labels. Output (JSON list):
  {"path": "Assets/...", "bundle": "<bundle file>", "address": "...", "labels": [...], "guid": "<original GUID>"}
Usage: python scripts/addressables_catalog.py <catalog.json | catalog.bin> [--out entries.json]
R.E.P.O. 0.5.0 (Unity 6.3, Addressables 2.9.1) ships the binary catalog: Addressables' BinaryStorageBuffer, decoded by
BinaryCatalog below after Runtime/ResourceManager/Util/BinaryStorageBuffer.cs and ResourceLocators/ContentCatalogData.cs
"""

import argparse
import base64
import json
import re
import struct
import sys

GUID_KEY = re.compile(r"^[0-9a-f]{32}$")


def read_keys(data: bytes) -> list:
    count = struct.unpack_from("<i", data, 0)[0]
    pos, keys = 4, []
    for _ in range(count):
        kind = data[pos]
        pos += 1
        if kind in (0, 1):  # ascii / unicode string
            length = struct.unpack_from("<i", data, pos)[0]
            pos += 4
            raw = data[pos:pos + length]
            pos += length
            keys.append(raw.decode("ascii" if kind == 0 else "utf-16-le"))
        elif kind == 4:  # int32
            keys.append(struct.unpack_from("<i", data, pos)[0])
            pos += 4
        elif kind == 7:  # hash128 string form
            length = data[pos]
            pos += 1
            keys.append(data[pos:pos + length].decode("ascii"))
            pos += length
        else:
            raise ValueError(f"unsupported key type {kind} at offset {pos - 1}")
    return keys


def read_buckets(data: bytes) -> list[list[int]]:
    count = struct.unpack_from("<i", data, 0)[0]
    pos, buckets = 4, []
    for _ in range(count):
        _, entry_count = struct.unpack_from("<ii", data, pos)
        pos += 8
        buckets.append(list(struct.unpack_from(f"<{entry_count}i", data, pos)))
        pos += 4 * entry_count
    return buckets


def read_entries(data: bytes) -> list[tuple]:
    count = struct.unpack_from("<i", data, 0)[0]
    return [struct.unpack_from("<7i", data, 4 + i * 28) for i in range(count)]


def decode(catalog: dict) -> list[dict]:
    ids = catalog["m_InternalIds"]
    providers = catalog["m_ProviderIds"]
    keys = read_keys(base64.b64decode(catalog["m_KeyDataString"]))
    buckets = read_buckets(base64.b64decode(catalog["m_BucketDataString"]))
    entries = read_entries(base64.b64decode(catalog["m_EntryDataString"]))

    keys_for_entry: dict[int, list] = {}
    for key, bucket in zip(keys, buckets):
        for entry in bucket:
            keys_for_entry.setdefault(entry, []).append(key)

    # internal id index -> bundle file, for bundle entries
    bundle_of_key = {}
    for index, (internal_id, provider, *_rest) in enumerate(entries):
        if providers[provider].endswith("AssetBundleProvider"):
            for key in keys_for_entry.get(index, []):
                bundle_of_key[key] = re.split(r"[\\/]", ids[internal_id])[-1]

    result = []
    for index, (internal_id, provider, dependency_key, _dep_hash, _data, primary_key, _type) in enumerate(entries):
        if not providers[provider].endswith("BundledAssetProvider"):
            continue
        entry_keys = [k for k in keys_for_entry.get(index, []) if isinstance(k, str)]
        address = keys[primary_key] if 0 <= primary_key < len(keys) else ids[internal_id]
        labels = sorted({k for k in entry_keys if k != address and not GUID_KEY.match(k) and not k.startswith("Assets/")})
        guids = sorted({k for k in entry_keys if GUID_KEY.match(k)})
        bundle = bundle_of_key.get(keys[dependency_key]) if dependency_key >= 0 else None
        # The asset's GUID in the original project: Localization refers to tables by it
        result.append({"path": ids[internal_id], "bundle": bundle, "address": address, "labels": labels,
                       "guid": guids[0] if guids else None})

    # Sub-objects of one asset appear once per object; keep one entry per path
    unique = {}
    for item in result:
        unique.setdefault(item["path"], item)
    return list(unique.values())


class BinaryCatalog:
    """Addressables 2.x catalog.bin. Offsets point into one buffer; a uint32 length sits in front of
    every array and string. Strings are ASCII, UTF-16 when bit 31 of the id is set, and chains of parts joined by a
    separator when bit 30 is set (DynamicString {part id, next id})."""
    UNICODE, DYNAMIC, MASK, NONE = 0x80000000, 0x40000000, 0x3FFFFFFF, 0xFFFFFFFF

    def __init__(self, data: bytes):
        self.data = data
        self.types: dict[int, str] = {}

    def u32(self, offset: int, count: int = 1):
        values = struct.unpack_from(f"<{count}I", self.data, offset)
        return values if count > 1 else values[0]

    def array(self, offset: int) -> list[int]:
        if offset == self.NONE:
            return []
        size = self.u32(offset - 4)
        return list(struct.unpack_from(f"<{size // 4}I", self.data, offset)) if size else []

    def plain(self, sid: int) -> str:
        offset = sid & self.MASK
        size = self.u32(offset - 4)
        raw = self.data[offset:offset + size]
        return raw.decode("utf-16-le") if sid & self.UNICODE else raw.decode("ascii")

    def string(self, sid: int, sep: str = "") -> str | None:
        if sid == self.NONE:
            return None
        if sep and sid & self.DYNAMIC:
            parts, next_id = [], sid
            while next_id != self.NONE:
                part, next_id = self.u32(next_id & self.MASK, 2)
                parts.append(self.plain(part))
            # the chain runs from the last part to the first (ReadDynamicString fills the string from its end)
            return sep.join(reversed(parts))
        return self.plain(sid)

    def type_name(self, offset: int) -> str:
        if offset not in self.types:
            _assembly, cls = self.u32(offset, 2)
            self.types[offset] = self.string(cls, ".")
        return self.types[offset]

    def obj(self, offset: int):
        """ReadObject: {type id, object id}, then the value by type (keys are strings, ints or Hash128s)"""
        if offset == self.NONE:
            return None
        type_id, object_id = self.u32(offset, 2)
        name = self.type_name(type_id)
        if name == "System.String":
            sid, sep = struct.unpack_from("<IH", self.data, object_id)
            return self.string(sid, chr(sep) if sep else "")
        if name == "System.Int32":
            return struct.unpack_from("<i", self.data, object_id)[0]
        if name == "UnityEngine.Hash128":
            return self.data[object_id:object_id + 16].hex()
        return f"<{name}>"

    def location(self, offset: int) -> dict:
        primary, internal, provider, deps, _dep_hash, _extra, type_id = struct.unpack_from("<IIIIiII", self.data, offset)
        return {"primary": self.string(primary, "/"), "internal": self.string(internal, "/"),
                "provider": self.string(provider, "."), "deps": self.array(deps), "type": self.type_name(type_id)}


def decode_binary(data: bytes) -> list[dict]:
    catalog = BinaryCatalog(data)
    _magic, _version, keys_offset = struct.unpack_from("<iiI", data, 0)
    pairs = catalog.array(keys_offset)
    keys_for_location: dict[int, list] = {}
    for name_offset, set_offset in zip(pairs[0::2], pairs[1::2]):
        key = catalog.obj(name_offset)
        for location in catalog.array(set_offset):
            keys_for_location.setdefault(location, []).append(key)

    cache: dict[int, dict] = {}

    def location(offset: int) -> dict:
        if offset not in cache:
            cache[offset] = catalog.location(offset)
        return cache[offset]

    result = []
    for offset, entry_keys in keys_for_location.items():
        loc = location(offset)
        if not loc["provider"].endswith("BundledAssetProvider"):
            continue
        strings = [k for k in entry_keys if isinstance(k, str)]
        address = loc["primary"] or loc["internal"]
        labels = sorted({k for k in strings if k != address and not GUID_KEY.match(k) and not k.startswith("Assets/")})
        guids = sorted({k for k in strings if GUID_KEY.match(k)})
        # The first dependency is the asset's own bundle (the dependency set keeps the order the entry lists them)
        bundles = [location(d) for d in loc["deps"]]
        bundle = next((re.split(r"[\\/]", b["internal"])[-1] for b in bundles if b["provider"].endswith("AssetBundleProvider")), None)
        result.append({"path": loc["internal"], "bundle": bundle, "address": address, "labels": labels,
                       "guid": guids[0] if guids else None})

    unique = {}
    for item in sorted(result, key=lambda i: i["path"]):
        unique.setdefault(item["path"], item)
    return list(unique.values())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog")
    parser.add_argument("--out")
    args = parser.parse_args()

    with open(args.catalog, "rb") as f:
        data = f.read()
    entries = decode(json.loads(data)) if data[:1] == b"{" else decode_binary(data)
    text = json.dumps(entries, indent=2, ensure_ascii=False)
    if args.out:
        open(args.out, "w", newline="\n").write(text)
    print(text if not args.out else f"{len(entries)} entries -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

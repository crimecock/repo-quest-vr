"""What changed in the game since the version the kit was made for, before a long build (QuestBuilder.Cli check).

Compares the game with scripts/game_fingerprints.json (made from the last tested version):
  - the Unity version (a new major/minor is a new editor for the whole pipeline)
  - the Addressables version and whether the player catalog still decodes (addressables_catalog.py)
  - for every package DLL the pipeline swaps for a Unity package (package_swap.PACKAGES): its set of types; a change
    means a new package version, which then has to be matched and pinned in package_swap.py
  - the set of DLLs in Managed: new ones are new packages or libraries
Usage: python scripts/check_game.py <REPO_Data> --out <report.json>
       python scripts/check_game.py <REPO_Data> --record <version name>   (after a successful build: new baseline)
The report: {"checks": [{"level": "ok|warn|fail", "area": ..., "message": ...}], "facts": {...}}
"""

import argparse
import json
import re
import sys
from pathlib import Path

import dnfile

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).parent / "lib"))
import addressables_catalog  # noqa: E402
from package_swap import PACKAGES  # noqa: E402

FINGERPRINTS = Path(__file__).parent / "game_fingerprints.json"
UNITY_VERSION = re.compile(rb"(\d{4}\.\d+\.\d+[abfp]\d+)")


def unity_version(data: Path) -> str | None:
    with open(data / "globalgamemanagers", "rb") as f:
        match = UNITY_VERSION.search(f.read(4096))
    return match.group(1).decode() if match else None


def types_of(dll: Path) -> list[str]:
    pe = dnfile.dnPE(str(dll))
    md = pe.net.mdtables
    nested = {row.NestedClass.row_index for row in (md.NestedClass.rows if md.NestedClass else [])}
    text = lambda v: str(v.value) if hasattr(v, "value") else str(v)
    names = []
    for i, t in enumerate(md.TypeDef.rows, start=1):
        name = text(t.TypeName)
        if i in nested or name.startswith("<") or "__" in name or name in ("MonoScriptData",
                                                                           "UnitySourceGeneratedAssemblyMonoScriptTypes_v1"):
            continue
        names.append(f"{text(t.TypeNamespace)}.{name}".lstrip("."))
    return sorted(set(names))


def snapshot(data: Path) -> dict:
    managed = data / "Managed"
    settings = data / "StreamingAssets" / "aa" / "settings.json"
    addressables = None
    if settings.exists():
        match = re.search(r'"m_AddressablesVersion":"([^"]+)"', settings.read_text(errors="ignore"))
        addressables = match.group(1) if match else None
    packages = {}
    for _, _, dlls in PACKAGES:
        for dll in dlls:
            path = managed / f"{dll}.dll"
            if path.exists():
                packages[dll] = types_of(path)
    return {
        "unity": unity_version(data),
        "addressables": addressables,
        "managed": sorted(p.name for p in managed.glob("*.dll")),
        "packages": packages,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("data", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--record")
    args = parser.parse_args()

    now = snapshot(args.data)
    if args.record:
        FINGERPRINTS.write_text(json.dumps({"version": args.record, **now}, indent=1) + "\n", newline="\n")
        print(f"baseline {args.record} -> {FINGERPRINTS}")
        return 0

    base = json.loads(FINGERPRINTS.read_text())
    checks = []

    def add(level, area, message):
        checks.append({"level": level, "area": area, "message": message})

    # Unity: the editor the whole pipeline is pinned to (kit.json)
    major = lambda v: ".".join((v or "").split(".")[:2])
    if now["unity"] == base["unity"]:
        add("ok", "unity", f"Unity {now['unity']} (as {base['version']})")
    elif major(now["unity"]) == major(base["unity"]):
        add("warn", "unity", f"Unity {base['unity']} -> {now['unity']}: a patch release; kit.json pins "
                             f"{base['unity']}, which usually still builds it")
    else:
        add("fail", "unity", f"Unity {base['unity']} -> {now['unity']}: a new editor; kit.json, the package versions "
                             f"and the Unity tooling need porting (as for 0.5.0)")

    # Addressables and the player catalog
    if now["addressables"] != base["addressables"]:
        add("warn", "addressables", f"Addressables {base['addressables']} -> {now['addressables']}: "
                                    f"pin it in package_swap.py and check the catalog format")
    catalog_bin = args.data / "StreamingAssets" / "aa" / "catalog.bin"
    catalog = catalog_bin if catalog_bin.exists() else args.data / "StreamingAssets" / "aa" / "catalog.json"
    try:
        raw = catalog.read_bytes()
        entries = (addressables_catalog.decode(json.loads(raw)) if raw[:1] == b"{"
                   else addressables_catalog.decode_binary(raw))
        bundles = {e["bundle"] for e in entries}
        level = "ok" if entries and None not in bundles else "fail"
        add(level, "addressables", f"{catalog.name}: {len(entries)} entries in {len(bundles)} bundles"
                                   + ("" if level == "ok" else ", some without a bundle"))
    except Exception as e:  # noqa: BLE001 - any failure here is the report's finding
        add("fail", "addressables", f"{catalog.name} does not decode: {type(e).__name__}: {e}")

    # Package DLLs the pipeline replaces with Unity packages
    for dll, types in sorted(now["packages"].items()):
        before = base["packages"].get(dll)
        if before is None:
            add("warn", "packages", f"{dll}: not in the baseline")
            continue
        added, removed = sorted(set(types) - set(before)), sorted(set(before) - set(types))
        if not added and not removed:
            continue
        sample = ", ".join((["+" + t for t in added] + ["-" + t for t in removed])[:8])
        add("warn", "packages", f"{dll}: {len(added)} types added, {len(removed)} removed ({sample}): a new package "
                                f"version; match and pin it in package_swap.py")
    if not any(c["area"] == "packages" for c in checks):
        add("ok", "packages", f"{len(now['packages'])} package DLLs unchanged")

    new_dlls = sorted(set(now["managed"]) - set(base["managed"]))
    gone_dlls = sorted(set(base["managed"]) - set(now["managed"]))
    if new_dlls or gone_dlls:
        add("warn", "managed", "DLLs " + ", ".join(["+" + d for d in new_dlls] + ["-" + d for d in gone_dlls]))
    else:
        add("ok", "managed", f"{len(now['managed'])} DLLs, same set")

    report = {"baseline": base["version"], "checks": checks,
              "facts": {"unity": now["unity"], "addressables": now["addressables"]}}
    text = json.dumps(report, indent=1)
    if args.out:
        args.out.write_text(text + "\n", newline="\n")
    for c in checks:
        print(f"{c['level'].upper():4} {c['area']}: {c['message']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

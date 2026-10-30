"""Fill in the chunk sizes of the WAV files AssetRipper writes.

AssetRipper 2.0.0 leaves the RIFF size and the data chunk size of every exported .wav at 0 (R.E.P.O.
0.5.0: all 3417 of them). Unity 2022.3 read such files to the end anyway; Unity 6's FSBTool refuses them ("Failed
decoding audio clip"), and the clips would be silent in the game. The sizes are set from the file length.
Usage: python scripts/fix_wav_headers.py <unity project>
"""

import struct
import sys
from pathlib import Path


def fix(path: Path) -> bool:
    data = bytearray(path.read_bytes())
    if len(data) < 12 or data[0:4] != b"RIFF" or data[8:12] != b"WAVE":
        return False
    changed = False
    if struct.unpack_from("<I", data, 4)[0] != len(data) - 8:
        struct.pack_into("<I", data, 4, len(data) - 8)
        changed = True
    pos = 12
    while pos + 8 <= len(data):
        chunk = bytes(data[pos:pos + 4])
        size = struct.unpack_from("<I", data, pos + 4)[0]
        if chunk == b"data":
            actual = len(data) - (pos + 8)
            if size != actual:
                struct.pack_into("<I", data, pos + 4, actual)
                changed = True
            break
        if size == 0 or pos + 8 + size > len(data):
            break
        pos += 8 + size + (size & 1)
    if changed:
        path.write_bytes(data)
    return changed


def main() -> int:
    assets = Path(sys.argv[1]) / "Assets"
    total = fixed = 0
    for path in assets.rglob("*.wav"):
        total += 1
        fixed += fix(path)
    print(f"WAV headers: {fixed} of {total} files fixed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

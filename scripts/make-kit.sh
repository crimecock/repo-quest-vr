#!/usr/bin/env bash
# The Quest builder's kit in work/kit: everything that turns a player's own copy of the game into the Quest project,
# except the game. builder/QuestBuilder.Core/Kit.cs reads it; scripts/release.sh embeds it into the builder.
#   scripts/make-kit.sh [version]      (default version: dev)
# Contents:
#   kit.json, python/requirements.lock      builder/ (pinned downloads, Unity version, Python packages)
#   scripts/, unity-tools/                  the pipeline's Python scripts and Unity tooling from this checkout
#   prebuilt/repoxr/RepoXR.dll              RepoXR v1.2.3 + patches/repoxr (scripts/prepare-repoxr.sh)
#   prebuilt/standalone/                    tools/RepoXR.Standalone
#   prebuilt/steam/                         tools/SteamShim (Facepunch.Steamworks.Win64) with SteamKit2, protobuf-net(.Core),
#                                           System.Collections.Immutable
#   prebuilt/android/libopus_egpv.so        scripts/build-opus-android.sh
#   prebuilt/repoxr-android/                RepoXR's assets for Android: from the current kit (build-mac.sh's VERSION), or
#                                           rebuilt with REBUILD_REPOXR_ASSETS=1 (scripts/build-repoxr-assets.sh: Unity
#                                           2022.3.62f3 and external/RepoXR-Unity; they only change with RepoXR-Unity)
#   licenses/, SOURCES.md                   licenses of what the kit carries and where its sources are
# The checks at the end refuse anything that looks like game files. Step by step: docs/build-kit.md.
#   GAME=<folder with REPO_Data>   the Windows game to compile against (default ~/RepoQuest/game)
#   NDK=<NDK bin folder>            for libopus (default: Unity 6000.3.17f1's, else 2022.3.62f3's)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
kit="$root/work/kit"
version="${1:-dev}"
dotnet="${DOTNET:-$HOME/.dotnet/dotnet}"
game="${GAME:-$HOME/RepoQuest/game}"
downloads="$root/work/downloads"
die() { echo "ERROR: $*" >&2; exit 1; }
sha256() { if command -v shasum >/dev/null; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d' ' -f1; }
[ -x "$dotnet" ] || dotnet="$(command -v dotnet || true)"
[ -n "$dotnet" ] || die "no dotnet: run scripts/build-mac.sh once (it installs the .NET 8 SDK into ~/.dotnet) or pass DOTNET="
[ -f "$game/REPO_Data/Managed/Assembly-CSharp.dll" ] || die "R.E.P.O. not found in $game: GAME=<folder with REPO_Data>"

# kit.json's pinned downloads: RepoXR 1.2.3 (its Unity 2022 XR libraries and BepInEx, which RepoXR.Standalone
# compiles against; the APK gets the same ones from the builder)
fetch() {  # fetch <kit.json key> <folder to unpack into>
    local url sha
    read -r url sha < <(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["downloads"][sys.argv[2]]; print(d["url"], d["sha256"])' \
        "$root/builder/kit.json" "$1")
    [ -d "$2" ] && [ "$(cat "$2/.sha" 2>/dev/null)" = "$sha" ] && return
    mkdir -p "$downloads"
    curl -fsSL "$url" -o "$downloads/$1.zip"
    [ "$(sha256 "$downloads/$1.zip")" = "$sha" ] || die "$url: SHA-256 does not match kit.json"
    rm -rf "$2" && mkdir -p "$2" && unzip -q -o "$downloads/$1.zip" -d "$2" && echo "$sha" > "$2/.sha"
}
fetch repoXR "$downloads/RepoXR-1.2.3"
fetch bepInEx "$downloads/BepInEx5"

"$root/scripts/prepare-repoxr.sh" >/dev/null
"$dotnet" build -c Release -v quiet -nologo -clp:ErrorsOnly -p:WarningLevel=0 "$root/tools/SteamShim" \
    || die "SteamShim did not build"
"$dotnet" build -c Release -v quiet -nologo -clp:ErrorsOnly -p:WarningLevel=0 "$root/tools/RepoXR.Standalone" \
    -p:GameManaged="$game/REPO_Data/Managed" || die "RepoXR.Standalone did not build"
[ -f "$root/work/opus-android/libopus_egpv.so" ] || "$root/scripts/build-opus-android.sh"

# RepoXR's Android assets take a Unity 2022 run and only change with RepoXR-Unity: taken from the current kit unless
# REBUILD_REPOXR_ASSETS=1
assets="$root/work/repoxr-android"
if [ "${REBUILD_REPOXR_ASSETS:-0}" = 1 ]; then
    stamp="$( (git -C "$root/external/RepoXR-Unity" rev-parse HEAD
               find "$root/unity-tools/RepoXRAssets" "$root/scripts/patch_repoxr_shaders.py" "$root/scripts/build-repoxr-assets.sh" \
                   -type f -exec shasum -a 256 {} \; | sed "s|$root/||" | sort) | shasum -a 256 | cut -d' ' -f1)"
    if [ ! -f "$assets/repoxrassets" ] || [ "$(cat "$assets/.stamp" 2>/dev/null)" != "$stamp" ]; then
        "$root/scripts/build-repoxr-assets.sh" >/dev/null
        echo "$stamp" > "$assets/.stamp"
    fi
else
    current="$(sed -n 's/^VERSION=//p' "$root/scripts/build-mac.sh")"
    current_sha="$(sed -n 's/^KIT_SHA="${KIT_SHA:-\(.*\)}"$/\1/p' "$root/scripts/build-mac.sh")"
    zip="$HOME/RepoQuest/downloads/repoquest-kit-$current.zip"
    if [ ! -f "$zip" ] || [ "$(sha256 "$zip")" != "$current_sha" ]; then
        zip="$downloads/repoquest-kit-$current.zip"
        [ -f "$zip" ] && [ "$(sha256 "$zip")" = "$current_sha" ] || {
            mkdir -p "$downloads"
            curl -fsSL "https://github.com/crimecock/repo-quest-vr/raw/kit/repoquest-kit-$current.zip" -o "$zip"
            [ "$(sha256 "$zip")" = "$current_sha" ] || die "kit $current: SHA-256 does not match scripts/build-mac.sh"
        }
    fi
    rm -rf "$assets" && mkdir -p "$assets"
    unzip -q -o "$zip" 'prebuilt/repoxr-android/*' -d "$assets.tmp"
    mv "$assets.tmp/prebuilt/repoxr-android/"* "$assets/" && rm -rf "$assets.tmp"
    echo "RepoXR's Android assets: from kit $current"
fi

rm -rf "$kit"
mkdir -p "$kit"/{scripts/lib,python,prebuilt/{repoxr,standalone,steam,android,repoxr-android},licenses}
python3 - "$root/builder/kit.json" "$kit/kit.json" "$version" <<'EOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
manifest["version"] = sys.argv[3]
open(sys.argv[2], "w").write(json.dumps(manifest, indent=2) + "\n")
EOF
cp "$root/builder/python/requirements.lock" "$kit/python/"
# Every pipeline script; not the Mac-only diagnostics, kit and release tooling
for script in "$root"/scripts/*.py; do
    case "$(basename "$script")" in
        inventory.py|shader_disasm.py|patch_repoxr_shaders.py|publish_check.py|package-thunderstore.py|github_stats.py) ;;
        *) cp "$script" "$kit/scripts/" ;;
    esac
done
cp "$root"/scripts/lib/*.py "$kit/scripts/lib/"
cp "$root/scripts/game_fingerprints.json" "$kit/scripts/"   # check_game.py's baseline (QuestBuilder.Cli check)
rsync -a --exclude RepoXRAssets --exclude .DS_Store "$root/unity-tools/" "$kit/unity-tools/"

cp "$root/work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll" "$kit/prebuilt/repoxr/"
cp "$root/tools/RepoXR.Standalone/bin/Release/netstandard2.1/RepoXR.Standalone.dll" "$kit/prebuilt/standalone/"
shim="$root/tools/SteamShim/bin/Release/netstandard2.1"
for dll in Facepunch.Steamworks.Win64 SteamKit2 protobuf-net protobuf-net.Core System.Collections.Immutable; do
    cp "$shim/$dll.dll" "$kit/prebuilt/steam/"
done
cp "$root/work/opus-android/libopus_egpv.so" "$kit/prebuilt/android/"
cp -R "$assets/repoxrassets" "$assets/Addressables" "$kit/prebuilt/repoxr-android/"

cp "$root/external/RepoXR/LICENSE" "$kit/licenses/GPL-3.0.txt"
cp "$root/work/downloads/opus-1.5.2/COPYING" "$kit/licenses/opus-BSD-3-Clause.txt"
cp "$root/builder/licenses/"* "$kit/licenses/" 2>/dev/null || true
[ -f "$root/builder/SOURCES.md" ] && cp "$root/builder/SOURCES.md" "$kit/"

# Checks: text written with "\n" on every OS (Windows Python would write "\r\n"), and nothing from the game
bad_writes="$(grep -nE 'write_text\(|open\([^)]*"w' "$kit"/scripts/*.py | grep -v 'newline=' || true)"
[ -z "$bad_writes" ] || { echo "kit scripts write text without newline=\"\\n\":" >&2; echo "$bad_writes" >&2; exit 1; }
suspicious="$(find "$kit" \( -name '*.assets' -o -name '*.resS' -o -name '*.resource' -o -name 'Assembly-CSharp*' \
    -o -name 'REPO_Data' -o -name 'globalgamemanagers*' -o -name 'level[0-9]*' \) -print)"
[ -z "$suspicious" ] || { echo "game files in the kit:" >&2; echo "$suspicious" >&2; exit 1; }
bundles="$(find "$kit" -name '*.bundle' -not -path "$kit/prebuilt/repoxr-android/*" -print)"
[ -z "$bundles" ] || { echo "unexpected asset bundles in the kit:" >&2; echo "$bundles" >&2; exit 1; }

echo "kit $version: $kit ($(du -sh "$kit" | cut -f1))"

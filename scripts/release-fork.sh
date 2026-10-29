#!/usr/bin/env bash
# A release of this fork: the kit, the version in the build scripts, the git tag, the kit branch and the GitHub release.
#
#   scripts/release-fork.sh <version> --dlls <dir> [--game <game folder> --game-name <v0.5.1>] [--prerelease] [--dry-run]
#
#   <version>      e.g. 1.0.7-qc2; CHANGELOG.md needs a "## <version>" section (the release notes)
#   --dlls <dir>   RepoXR.dll (patches/repoxr applied), RepoXR.Standalone.dll and Facepunch.Steamworks.Win64.dll
#                  (tools/SteamShim) built for this game version; the other prebuilt parts (RepoXR's Android assets,
#                  libopus, SteamKit2, licenses) come from the current kit
#   --game <dir>   the game version this release was built and tested with (the folder with REPO_Data): added to
#   --game-name    kit.json's tested versions, and recorded as the baseline of QuestBuilder.Cli check
#                  (scripts/game_fingerprints.json)
#   --base-kit <zip>  the kit to start from (default: the current one, downloaded from the kit branch)
#   --prerelease   mark the GitHub release as a pre-release (a build not tested on a headset yet)
#   --dry-run      build the kit and change the files, but commit, tag and push nothing
#
# Pushes with GITHUB_TOKEN when it is set (otherwise with git's own credentials); the GitHub release needs GITHUB_TOKEN.
# Uploading the kit as a release asset is tried too; where uploads.github.com is not reachable the release links to the
# kit on the kit branch, which is where the build scripts download it from anyway.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:?usage: scripts/release-fork.sh <version> --dlls <dir> [--game <dir> --game-name <name>] [--prerelease] [--dry-run]}"
shift
dlls="" game="" game_name="" base_kit="" prerelease=false dry=false
while [ $# -gt 0 ]; do
    case "$1" in
        --dlls) dlls="$2"; shift 2 ;;
        --game) game="$2"; shift 2 ;;
        --game-name) game_name="$2"; shift 2 ;;
        --base-kit) base_kit="$2"; shift 2 ;;
        --prerelease) prerelease=true; shift ;;
        --dry-run) dry=true; shift ;;
        *) echo "unknown option $1" >&2; exit 64 ;;
    esac
done
die() { echo "ERROR: $*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }
sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
python="${PYTHON:-python3}"

cd "$root"
branch="$(git rev-parse --abbrev-ref HEAD)"
[ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes"
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && die "tag v$version exists already"
notes="$(awk -v v="## $version" 'index($0, v) == 1 {on = 1; next} on && /^## / {exit} on' CHANGELOG.md)"
[ -n "$(echo "$notes" | tr -d '[:space:]')" ] || die "CHANGELOG.md has no \"## $version\" section"
[ -n "$dlls" ] || die "--dlls <dir> is required"
for dll in RepoXR.dll RepoXR.Standalone.dll Facepunch.Steamworks.Win64.dll; do
    [ -f "$dlls/$dll" ] || die "$dlls/$dll is missing"
done
[ -z "$game" ] || [ -n "$game_name" ] || die "--game needs --game-name"
remote="$(git remote get-url origin)"
slug="$(echo "$remote" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"

# The current kit is the base: whatever this release does not rebuild comes from it
old_url="$(sed -n 's/^KIT_URL="${KIT_URL:-\(.*\)}"$/\1/p' scripts/build-mac.sh)"
old_version="$(sed -n 's/^VERSION=//p' scripts/build-mac.sh)"
old_url="${old_url//\$VERSION/$old_version}"
work="$root/work/release-$version"
rm -rf "$work"; mkdir -p "$work/kit"

say "base: kit $old_version"
if [ -n "$base_kit" ]; then cp "$base_kit" "$work/base.zip"; else curl -fsSL "$old_url" -o "$work/base.zip"; fi
(cd "$work/kit" && unzip -q ../base.zip)

say "tested game"
if [ -n "$game" ]; then
    data="$game/REPO_Data"; [ -d "$data" ] || data="$game"
    hash="$(sha256 "$data/Managed/Assembly-CSharp.dll")"
    "$python" - builder/kit.json "$game_name" "$hash" <<'PY'
import json, sys
path, name, digest = sys.argv[1:]
manifest = json.load(open(path))
tested = manifest.setdefault("testedGames", [])
if not any(g["assemblyCSharp"] == digest for g in tested):
    tested.append({"name": name, "assemblyCSharp": digest})
open(path, "w", newline="\n").write(json.dumps(manifest, indent=2) + "\n")
PY
    "$python" scripts/check_game.py "$data" --record "$game_name"
    echo "   tested game $game_name ($hash); baseline recorded"
fi

say "kit $version"
kit="$work/kit"
"$python" - "$root/builder/kit.json" "$kit/kit.json" "$version" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
manifest["version"] = sys.argv[3]
open(sys.argv[2], "w", newline="\n").write(json.dumps(manifest, indent=4) + "\n")
PY
cp builder/python/requirements.lock "$kit/python/requirements.lock"
rm -rf "$kit/scripts" && mkdir -p "$kit/scripts/lib"
for script in scripts/*.py; do
    case "$(basename "$script")" in
        inventory.py|shader_disasm.py|patch_repoxr_shaders.py|publish_check.py|package-thunderstore.py|github_stats.py) ;;
        *) cp "$script" "$kit/scripts/" ;;
    esac
done
cp scripts/lib/*.py "$kit/scripts/lib/"
cp scripts/game_fingerprints.json "$kit/scripts/"
rm -rf "$kit/unity-tools" && mkdir -p "$kit/unity-tools"
(cd unity-tools && tar --exclude ./RepoXRAssets --exclude .DS_Store -cf - .) | tar -xf - -C "$kit/unity-tools"
cp "$dlls/RepoXR.dll" "$kit/prebuilt/repoxr/"
cp "$dlls/RepoXR.Standalone.dll" "$kit/prebuilt/standalone/"
cp "$dlls/Facepunch.Steamworks.Win64.dll" "$kit/prebuilt/steam/"
{
    echo "# What the kit carries and where its source is"
    echo
    echo "Kit $version of the R.E.P.O. 0.5.0 fork (github.com/$slug), built from tag v$version. RepoXR.dll is RepoXR 1.2.3"
    echo "with patches/repoxr; RepoXR.Standalone and SteamShim are built from tools/; scripts/ and unity-tools/ come from"
    echo "the tag. prebuilt/repoxr-android, libopus, SteamKit2 and its libraries are carried over from kit $old_version."
    echo
    sed -n '/^The kit is everything/,$p' builder/SOURCES.md
} > "$kit/SOURCES.md"
rm -f "$kit/.zip-sha" "$kit/.content-hash"
find "$kit" -name __pycache__ -prune -exec rm -rf {} +
suspicious="$(find "$kit" \( -name '*.assets' -o -name '*.resS' -o -name '*.resource' -o -name 'Assembly-CSharp*' \
    -o -name 'REPO_Data' -o -name 'globalgamemanagers*' -o -name 'level[0-9]*' \) -print)"
[ -z "$suspicious" ] || die "game files in the kit: $suspicious"

zip_name="repoquest-kit-$version.zip"
(cd "$kit" && zip -q -r -X "$work/$zip_name" .)
kit_sha="$(sha256 "$work/$zip_name")"
echo "   $work/$zip_name ($kit_sha)"

say "repository files"
sed -i.bak -E "s/^VERSION=.*/VERSION=$version/; s/^KIT_SHA=\"\\\$\{KIT_SHA:-[0-9a-f]*\}\"/KIT_SHA=\"\${KIT_SHA:-$kit_sha}\"/" scripts/build-mac.sh
sed -i.bak -E "s/^\\\$Version = \".*\"/\$Version = \"$version\"/; s/^\\\$KitSha = \".*\"/\$KitSha = \"$kit_sha\"/" scripts/build-windows.ps1
rm -f scripts/build-mac.sh.bak scripts/build-windows.ps1.bak
grep -q "^KIT_SHA=\"\${KIT_SHA:-$kit_sha}\"" scripts/build-mac.sh || die "build-mac.sh: KIT_SHA not updated"
grep -q "^\$KitSha = \"$kit_sha\"" scripts/build-windows.ps1 || die "build-windows.ps1: KitSha not updated"
git --no-pager diff --stat

if $dry; then
    echo "dry run: kit in $work/$zip_name; files changed, nothing committed"
    exit 0
fi

say "commit, tag, push"
auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-c "http.extraHeader=Authorization: Basic $(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')")
fi
git add -A scripts/build-mac.sh scripts/build-windows.ps1 builder/kit.json scripts/game_fingerprints.json
git commit -q -m "Release $version"
git tag -a "v$version" -m "Release $version"
git "${auth[@]}" push -q origin "$branch" "v$version"

say "kit branch"
kitrepo="$work/kit-branch"
git clone -q --branch kit --single-branch "$remote" "$kitrepo"
cp "$work/$zip_name" "$kitrepo/"
(cd "$kitrepo" && shasum -a 256 repoquest-kit-*.zip > SHA256SUMS)
git -C "$kitrepo" add -A
git -C "$kitrepo" commit -q -m "Kit $version"
git -C "$kitrepo" "${auth[@]}" push -q origin kit
kit_link="https://github.com/$slug/raw/kit/$zip_name"
curl -fsSL "$kit_link" -o "$work/check.zip" && [ "$(sha256 "$work/check.zip")" = "$kit_sha" ] || die "the kit on the kit branch does not match"
echo "   $kit_link"

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "no GITHUB_TOKEN: create the release for tag v$version on GitHub yourself (notes: CHANGELOG.md, kit: $kit_link)"
    exit 0
fi
say "GitHub release"
printf '%s\n' "$notes" > "$work/notes.md"
"$python" - "$version" "$kit_link" "$kit_sha" "$prerelease" "$branch" "$work/notes.md" > "$work/release.json" <<'PY'
import json, sys
version, link, sha, pre, branch, notes = sys.argv[1:]
body = open(notes).read().strip() + f"\n\n**Kit:** [repoquest-kit-{version}.zip]({link})  \nSHA-256: `{sha}`"
print(json.dumps({"tag_name": f"v{version}", "target_commitish": branch, "name": version, "body": body,
                  "prerelease": pre == "true"}))
PY
api="https://api.github.com/repos/$slug"
release="$(curl -fsS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
    "$api/releases" --data @"$work/release.json")"
id="$("$python" -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$release")"
if curl -fsS -m 300 -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/zip" \
    --data-binary @"$work/$zip_name" "https://uploads.github.com/repos/$slug/releases/$id/assets?name=$zip_name" >/dev/null; then
    echo "   kit attached to the release"
else
    echo "   uploads.github.com not reachable here: the release links to the kit branch"
fi
echo "released $version: https://github.com/$slug/releases/tag/v$version"

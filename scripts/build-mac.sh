#!/usr/bin/env bash
# R.E.P.O. 0.5.0 in VR on a Quest, standalone, built on a Mac from your own Steam copy of the game.
#
#   bash scripts/build-mac.sh                download what is missing, build, install on the headset
#   bash scripts/build-mac.sh --no-install   build only
#   GAME=<folder with REPO_Data> bash scripts/build-mac.sh   use a copy of the game you already have
#   FORCE=1 bash scripts/build-mac.sh        build even when the check of a new game version finds problems
#
# What it does (work folder ~/RepoQuest, an ASCII path: Unity and Gradle break on others; REPOQUEST_HOME changes it):
#   1. .NET 8 SDK into ~/.dotnet (Microsoft's dotnet-install.sh), if there is none yet
#   2. the kit (scripts, Unity tooling, prebuilt RepoXR/SteamShim/Standalone; no game files) from this fork (kit branch),
#      or KIT_ZIP=<zip> for a local one
#   3. the game: the Windows version of R.E.P.O. from Steam through steamcmd (asks for your Steam login once; your
#      password goes only to Steam)
#   4. the builder from this checkout (builder/QuestBuilder.Cli); a game version the kit was not tested with is checked
#      first (QuestBuilder.Cli check: patches, IL, references, packages; minutes, no Unity); then the build: AssetRipper export, RepoXR baked into
#      the game's code, Unity 6000.3.17f1 -> APK. First build 1-1.5 hours, later ones 20-40 minutes; about 60 GB
#   5. adb install on the headset (cable, developer mode)
# Do not share the APK: it contains the game's files.
set -euo pipefail
trap 'echo "build_repoquest.sh stopped at line $LINENO" >&2' ERR

SRC="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=1.0.7-qc1
KIT_URL="${KIT_URL:-https://github.com/crimecock/repo-quest-vr/raw/kit/repoquest-kit-$VERSION.zip}"
KIT_SHA="${KIT_SHA:-99c05912e15f7b301db4319d8215d4c8f97cdde0c333be5f266d33e9462bb3a7}"
BASE="${REPOQUEST_HOME:-$HOME/RepoQuest}"
GAME="${GAME:-$BASE/game}"
UNITY_VERSION=6000.3.17f1
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/$UNITY_VERSION}"
DOTNET_DIR="$HOME/.dotnet"
STEAM_APP=3241660
INSTALL=1
[ "${1:-}" = "--no-install" ] && INSTALL=0

say() { printf '\n== %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

case "$BASE" in *[!a-zA-Z0-9/._-]*) die "the work folder must be an ASCII path without spaces: $BASE (set REPOQUEST_HOME)";; esac
mkdir -p "$BASE"
free_gb="$(df -g "$BASE" | awk 'NR==2 {print $4}')"
[ "${free_gb:-0}" -ge 60 ] || echo "warning: only ${free_gb} GB free on this disk, the build needs about 60 GB"

say "Unity $UNITY_VERSION with Android"
if [ ! -x "$UNITY/Unity.app/Contents/MacOS/Unity" ]; then
    echo "   Unity $UNITY_VERSION is not installed: opening Unity Hub on it. Tick Android Build Support with OpenJDK and"
    echo "   Android SDK & NDK Tools, install, then run this script again"
    open "unityhub://$UNITY_VERSION/cf0352b38e81" 2>/dev/null || true
    die "Unity $UNITY_VERSION not found in $UNITY (or set UNITY=)"
fi
[ -d "$UNITY/PlaybackEngines/AndroidPlayer" ] || die "Unity has no Android Build Support: Unity Hub > Installs > $UNITY_VERSION > Add modules > Android Build Support (with SDK/NDK and OpenJDK)"
echo "   $UNITY"

say ".NET 8 SDK"
if ! "$DOTNET_DIR/dotnet" --list-sdks 2>/dev/null | grep -q '^8\.'; then
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$BASE/dotnet-install.sh"
    bash "$BASE/dotnet-install.sh" --channel 8.0 --install-dir "$DOTNET_DIR"
fi
export DOTNET_ROOT="$DOTNET_DIR" DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export PATH="$DOTNET_DIR:$PATH"
"$DOTNET_DIR/dotnet" --list-sdks | grep '^8\.' | tail -1

say "kit $VERSION"
KIT_ZIP="${KIT_ZIP:-$BASE/downloads/repoquest-kit-$VERSION.zip}"
if [ ! -f "$KIT_ZIP" ]; then
    mkdir -p "$(dirname "$KIT_ZIP")"
    curl -fL --progress-bar "$KIT_URL" -o "$KIT_ZIP.part" && mv "$KIT_ZIP.part" "$KIT_ZIP"
fi
got="$(shasum -a 256 "$KIT_ZIP" | cut -d' ' -f1)"
[ "$got" = "$KIT_SHA" ] || die "the kit zip is damaged (sha256 $got)"
KIT="$BASE/kit-$VERSION"
if [ ! -f "$KIT/kit.json" ] || [ "$(cat "$KIT/.zip-sha" 2>/dev/null)" != "$KIT_SHA" ]; then
    rm -rf "$KIT"; mkdir -p "$KIT"
    unzip -q "$KIT_ZIP" -d "$KIT"
    echo "$KIT_SHA" > "$KIT/.zip-sha"
fi
echo "   $KIT"

say "R.E.P.O. (Windows version, your Steam copy)"
if [ ! -f "$GAME/REPO_Data/Managed/Assembly-CSharp.dll" ]; then
    # steamcmd for macOS is an Intel program: Rosetta 2
    if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
        echo "   steamcmd needs Rosetta 2, installing it (macOS asks for your password)"
        softwareupdate --install-rosetta --agree-to-license
    fi
    if [ ! -x "$BASE/steamcmd/steamcmd.sh" ]; then
        mkdir -p "$BASE/steamcmd"
        curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz | tar -xz -C "$BASE/steamcmd"
    fi
    read -r -p "   Steam login (account name, not e-mail): " STEAM_USER
    [ -n "$STEAM_USER" ] || die "no Steam login"
    echo "   steamcmd will ask for your password and the Steam Guard code; the download is about 2-3 GB"
    mkdir -p "$GAME"
    # the first steamcmd run updates itself; a second try usually goes through
    for attempt in 1 2; do
        if "$BASE/steamcmd/steamcmd.sh" +@sSteamCmdForcePlatformType windows +force_install_dir "$GAME" \
            +login "$STEAM_USER" +app_update "$STEAM_APP" validate +quit; then
            [ -f "$GAME/REPO_Data/Managed/Assembly-CSharp.dll" ] && break
        fi
        echo "   steamcmd did not finish, trying again"
    done
    [ -f "$GAME/REPO_Data/Managed/Assembly-CSharp.dll" ] || die "R.E.P.O. did not download to $GAME (or pass GAME=<folder with REPO_Data>)"
fi
echo "   $GAME"

say "builder (QuestBuilder.Cli)"
"$DOTNET_DIR/dotnet" build -c Release -nologo -v quiet "$SRC/builder/QuestBuilder.Cli" | { grep -E " error |warning CS" || true; }
CLI="$SRC/builder/QuestBuilder.Cli/bin/Release/net8.0/QuestBuilder.Cli"
[ -x "$CLI" ] || die "the builder did not build (see the messages above)"

# A game version the kit was not tested with: check it first (a few minutes, no Unity) instead of finding out an hour
# into the build. FORCE=1 builds anyway
if ! "$CLI" check --quick --kit "$KIT" --game "$GAME" --workspace "$BASE/work" --unity "$UNITY"; then
    say "this game version is new to kit $VERSION: checking it first (a few minutes, no Unity)"
    if ! "$CLI" check --kit "$KIT" --game "$GAME" --workspace "$BASE/work" --unity "$UNITY"; then
        [ "${FORCE:-0}" = 1 ] || die "the check found problems with this game version (report: $BASE/work/check-report.md). Wait for an update of this repository, or FORCE=1 to build anyway"
        echo "   FORCE=1: building anyway"
    fi
fi

say "building the APK (first time about an hour; logs in $BASE/work/logs)"
caffeinate -i "$CLI" build --kit "$KIT" --game "$GAME" --workspace "$BASE/work" --unity "$UNITY" --headset quest
APK="$BASE/work/build/REPO-Quest.apk"
[ -f "$APK" ] || APK="$(ls -t "$BASE"/work/build/*.apk 2>/dev/null | head -1)"
[ -n "$APK" ] && [ -f "$APK" ] || die "no APK in $BASE/work/build (see $BASE/work/logs)"
echo "   APK: $APK"

if [ "$INSTALL" = 1 ]; then
    say "installing on the headset"
    ADB="$UNITY/PlaybackEngines/AndroidPlayer/SDK/platform-tools/adb"
    [ -x "$ADB" ] || ADB="$(command -v adb || true)"
    [ -n "$ADB" ] || die "adb not found; install the APK yourself: $APK"
    "$ADB" start-server >/dev/null 2>&1 || true
    if ! "$ADB" get-state >/dev/null 2>&1; then
        echo "   no headset: connect the Quest by cable, allow USB debugging in the headset, then run:"
        echo "   \"$ADB\" install -r \"$APK\""
        exit 0
    fi
    if ! "$ADB" install -r "$APK"; then
        echo "   install failed; if it says INSTALL_FAILED_UPDATE_INCOMPATIBLE (an older build with another signature):"
        echo "   \"$ADB\" uninstall io.repoxr.quest   (deletes the game's saves on the headset) and run this script again"
        exit 1
    fi
    echo "   done: in the headset, Library > Unknown Sources > R.E.P.O."
fi

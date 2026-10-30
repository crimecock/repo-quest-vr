# When R.E.P.O. updates

**English** · [Русский](updating.ru.md)

A game update can break the port in four ways, as 0.5.0 did:

1. **The game's code changed**: RepoXR's patches no longer find what they patch, or a transpiler lands in the wrong place.
2. **The game calls new Steam APIs** that SteamShim (the Steam client on the headset) does not have.
3. **Unity packages or the engine changed**: new package versions, a new Addressables catalog, a new Unity.
4. **AssetRipper exports something differently** (0.5.0: no PlayerSettings, WAVs without sizes).

The first three show up in minutes without Unity, with `QuestBuilder.Cli check`. The fourth needs an export and
a build.

## Updating to a newer build of this fork

A new kit (for example 1.0.7-qc21 → qc22) only changes code most of the time: build again with
`CODE_ONLY=1 scripts/build-mac.sh` (Windows: `scripts/build-windows.ps1 -CodeOnly`). Unity reuses the game data packed
by your last full build and rebuilds only the code: about 6 minutes instead of 30-35. The release notes say when a full
build is needed (assets, the export or the Python scripts changed). Install the new APK over the old one: your saves,
settings and Steam login stay ([install.md](install.md)).

## For players

Nothing to do by hand. When Steam has a game version the kit was not tested with, `scripts/build-mac.sh` and
`scripts/build-windows.ps1` run the check first:

- **no failures**: the build goes on (the new version most likely works);
- **failures**: the script stops and points to `work/check-report.md`. Wait for a new release of this fork (or open an
  issue with the report). `FORCE=1` (macOS) or `-Force` (Windows) builds anyway.

To keep a working version, build from a copy of the game that does not update by itself: the macOS script downloads
its own copy with `steamcmd`, which only updates when you delete it; on Windows, pass `-Game` with a copy of the game
folder, or set the game in Steam to update only when launched.

## For maintainers

### 1. Check

```bash
dotnet build -c Release builder/QuestBuilder.Cli
builder/QuestBuilder.Cli/bin/Release/net8.0/QuestBuilder.Cli check --kit <unzipped kit> --game <game folder> --workspace <work folder>
```

It bakes the patches into the new game code (leaving the build's bake step done) and writes `check-report.md`:

| Area | What it means | Where to fix |
|---|---|---|
| `bake` | Patch classes that failed (a method or field that is gone, an ambiguous overload) | a new RepoXR patch (2) |
| `il` | Invalid IL in a baked method (IL2CPP would refuse it 40 minutes into the build) | the transpiler that changed it (2) |
| `types` | A value of one class stored where the game keeps another (clang would refuse IL2CPP's C++) | the transpiler (2) |
| `patches` | A patched method that did not change (the patch matched nothing), or changed only at its end (a transpiler that lost its anchor) | the patch (2) |
| `anchors` | A transpiler search that found nothing (warning). Without `ThrowIfInvalid` the edits after it land at the end of the method, or in the middle of something else: on 0.5.0 this kept grabbing disabled. Loops that run out of matches are left out | the transpiler (2); when the missing code is optional, check it with `IsValid` |
| `refs` | A call between the game, RepoXR, RepoXR.Standalone and SteamShim that no longer resolves | SteamShim (`tools/SteamShim/Api.cs`) for Steam APIs, `tools/RepoXR.Standalone` for its overrides, RepoXR (2) |
| `unity` | A new Unity version | `builder/kit.json`, `scripts/lib/paths.py`, `scripts/make_lamp_shaders.py`, package versions, Unity tooling (see [repo-0.5.0.md](repo-0.5.0.md)) |
| `addressables` | A new Addressables version, or a catalog that does not decode | `scripts/addressables_catalog.py`, `scripts/package_swap.py` |
| `packages` | A package DLL with different types: a new package version | match it and pin it in `scripts/package_swap.py` (and `ProjectStep` for embedded packages) |
| `managed` | New or removed DLLs | new packages or libraries; usually nothing, sometimes a package to swap |

### 2. Fix RepoXR's patches

One patch per game version, on top of the existing ones:

```bash
git submodule update --init external/RepoXR
scripts/repoxr-patch.sh start          # work/repoxr-edit: RepoXR + every patch in patches/repoxr, as a git repo
# edit work/repoxr-edit/Source until the check is clean
scripts/repoxr-patch.sh save repo-0.5.1   # -> patches/repoxr/0010-repo-0.5.1.patch
```

List the new patch in the header of `scripts/prepare-repoxr.sh`. Build RepoXR against the new game code, then
RepoXR.Standalone and SteamShim, and run the check with those DLLs in the kit until it reports no failures.

### 3. Build and test

Build the APK (`scripts/build-mac.sh` or `scripts/build-windows.ps1`) and play it on the headset: menus,
singleplayer, a level, the shop, joining a friend on PC.

While fixing code (RepoXR patches, RepoXR.Standalone, SteamShim, the baker, `unity-tools` scripts) after one full
build, use code-only builds: `CODE_ONLY=1 scripts/build-mac.sh` or `-CodeOnly`. Unity reuses the last APK's packed
game data and only rebuilds the code, IL2CPP and Gradle: about 6 minutes instead of 35. Anything that changes assets
(the export, the Python scripts, shaders, RepoXR's asset bundle) needs a full build. On the headset, record the log
while the game starts: `adb logcat -c && adb logcat -s Unity AndroidRuntime CRASH > log.txt`
([playing.md](playing.md#when-something-is-wrong)); RepoXR's own lines start with `[RepoXR]`.

### 4. Release

Add a `## <version>` section to both changelogs, [CHANGELOG.md](../CHANGELOG.md) and [CHANGELOG.ru.md](../CHANGELOG.ru.md) (the release notes are made from both), commit, then:

```bash
GITHUB_TOKEN=... scripts/release-fork.sh 1.0.7-qc3 --dlls <folder with the three DLLs> \
    --game <the game folder you tested> --game-name v0.5.1
```

The script builds the kit (the current kit with this checkout's scripts, Unity tooling and the new DLLs), records the
game version as tested (`builder/kit.json`) and as the check's new baseline (`scripts/game_fingerprints.json`), updates
the version and checksum in both build scripts, tags the release, pushes the kit to the `kit` branch and creates the
GitHub release. `--dry-run` does everything but commit and push; `--prerelease` marks an untested build.

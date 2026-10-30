# Building the whole kit from scratch

**English** · [Русский](build-kit.ru.md)

**Players do not need this:** the build scripts download the kit. To change only RepoXR (the VR mod), use
[build-repoxr.md](build-repoxr.md) instead: it is shorter. This page makes every part of the kit from this repository
and its pinned downloads, as for a release of this fork.

## What is in the kit, and where each part comes from

| Part | Built from | By |
|---|---|---|
| `kit.json`, `python/requirements.lock` | `builder/` | copied; `kit.json` pins every download the builder makes (AssetRipper, Python, BepInEx, RepoXR 1.2.3, NuGet packages, Unity's shaders), each with its SHA-256 |
| `scripts/`, `unity-tools/` | this repository | copied: the pipeline's Python scripts and the Unity editor tooling |
| `prebuilt/repoxr/RepoXR.dll` | DaXcess's RepoXR 1.2.3 + `patches/repoxr` | `scripts/prepare-repoxr.sh` (.NET 10) |
| `prebuilt/standalone/RepoXR.Standalone.dll` | `tools/RepoXR.Standalone` | `dotnet build` (.NET 8): starts RepoXR without BepInEx, Android overrides, the Steam login menu |
| `prebuilt/steam/` | `tools/SteamShim` + SteamKit2 2.5.0 (NuGet) | `dotnet build` (.NET 8): `Facepunch.Steamworks.Win64.dll` that talks to Steam through SteamKit2 instead of `steam_api64` (which does not exist on Android) |
| `prebuilt/android/libopus_egpv.so` | libopus 1.5.2 (xiph.org) | `scripts/build-opus-android.sh` with Unity's Android NDK: the voice codec Photon Voice imports |
| `prebuilt/repoxr-android/` | DaXcess's RepoXR-Unity (`external/RepoXR-Unity`) | `scripts/build-repoxr-assets.sh` with Unity 2022.3.62f3, only with `REBUILD_REPOXR_ASSETS=1`; otherwise taken from the current kit (they only change with RepoXR-Unity) |
| `licenses/`, `SOURCES.md` | `builder/`, `external/RepoXR`, libopus | copied |

`scripts/make-kit.sh` runs all of these and refuses to finish if anything that looks like game files got into the kit.

## 1. What you need

- A Mac with `git`, `curl`, `unzip`, `rsync`, `python3` (`xcode-select --install`).
- **Unity 6000.3.17f1 with Android Build Support**, as for any build ([build-mac.md](build-mac.md)): its Android NDK
  compiles libopus. Another NDK: `NDK=<…/toolchains/llvm/prebuilt/<host>/bin>`.
- The **Windows version of R.E.P.O. 0.5.0**: run `scripts/build-mac.sh` once (it downloads it into `~/RepoQuest/game`),
  or `GAME=<folder with REPO_Data>`.
- The **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** (`~/.dotnet`, installed by `build-mac.sh`) for
  SteamShim and RepoXR.Standalone, and the **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** for
  RepoXR (installed into `~/.dotnet10` by `prepare-repoxr.sh` when missing).
- Internet: GitHub, NuGet, thunderstore.io (DaXcess's RepoXR 1.2.3), downloads.xiph.org (libopus).
- Only to rebuild RepoXR's Android assets: Unity 2022.3.62f3 with Android Build Support and
  `git submodule update --init external/RepoXR-Unity`.

## 2. Build the kit

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr && git submodule update --init external/RepoXR
```

```bash
bash scripts/make-kit.sh 1.0.7-mine
```

The kit is in `work/kit`, with `kit.json` saying version `1.0.7-mine`. The first run takes a few minutes (libopus
compiles); later runs reuse what did not change.

## 3. Build the APK with it

```bash
(cd work/kit && rm -f ../kit-mine.zip && zip -qr ../kit-mine.zip .)
```

```bash
KIT_ZIP=$PWD/work/kit-mine.zip KIT_SHA=$(shasum -a 256 work/kit-mine.zip | cut -d' ' -f1) bash scripts/build-mac.sh
```

`build-mac.sh` unpacks it into `~/RepoQuest/kit-<version of the official kit>` and builds as usual; the next build
without `KIT_ZIP` goes back to the official kit. A code-only build (`CODE_ONLY=1`) is enough when the Python scripts and
the Unity tooling did not change.

## 4. Publish it (maintainers)

`scripts/release-fork.sh` makes a release from such DLLs: the kit on the `kit` branch, the version and SHA-256 in
`scripts/build-mac.sh` and `scripts/build-windows.ps1`, the tag and the GitHub release
([updating.md](updating.md#for-maintainers)).

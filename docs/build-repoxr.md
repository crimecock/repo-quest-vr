# Building RepoXR.dll for the Quest from scratch

**English** · [Русский](build-repoxr.ru.md)

**Players do not need this.** `scripts/build-mac.sh` and `scripts/build-windows.ps1` download the kit, and the kit
already has RepoXR.dll in it. This page is for changing RepoXR (the VR mod itself) for the Quest build, or for checking
that the kit's DLL really comes from this repository's sources.

## How the pieces fit

```
DaXcess/RepoXR 1.2.3 (external/RepoXR, untouched)
  + patches/repoxr/0001–0033 (this port; 0033: build against the game folder)
        │  scripts/prepare-repoxr.sh: .NET 10, compiled against your Windows copy of R.E.P.O. 0.5.0
        ▼
RepoXR.dll  ─ the same code as the PC fork's release (github.com/crimecock/RepoXR, branch repo-0.5.0)
        │  into the kit as prebuilt/repoxr/RepoXR.dll (next to RepoXR.Standalone, SteamShim, RepoXR's Android
        │  assets, the scripts and Unity tooling; no game files)
        ▼
the kit zip
        │  scripts/build-mac.sh: .NET 8 builder, AssetRipper, RepoXR baked into the game's code, Unity 6000.3.17f1
        ▼
the APK on the Quest
```

The patches applied to DaXcess's RepoXR give exactly the PC fork's sources: the PC fork is where RepoXR is developed and
tested, and patch `00NN` is `git diff <previous> <new> -- Source` there. So the Quest's RepoXR.dll and the PC release's
RepoXR.dll have the same code (IL); only the PC zip adds BepInEx around it.

**Why it needs your copy of the game.** A mod is compiled against the game's own DLLs (its code, Unity, Photon,
Steamworks). DaXcess's RepoXR downloads them from NuGet, a package server for .NET, but NuGet only has R.E.P.O. 0.4.4
and Unity 2022. Patch 0033 makes RepoXR's project take them from your Windows copy of R.E.P.O. 0.5.0 instead, and the
XR libraries built for Unity 6 from the PC fork's release. From NuGet only BepInEx and two small build tools come.

## 1. What you need

- A Mac (or Linux) with `git`, `rsync`, `patch`, `curl`, `unzip`. On macOS, `xcode-select --install` gives git.
- The **Windows version of R.E.P.O. 0.5.0**: RepoXR compiles against its code. `scripts/build-mac.sh` downloads it into
  `~/RepoQuest/game` on its first run (see [build-mac.md](build-mac.md)); any other copy with `GAME=<folder with REPO_Data>`.
- The **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** for step 5 (the APK's builder): `scripts/build-mac.sh` installs it into `~/.dotnet` itself.
- The **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** for steps 3–4: RepoXR is written in C# 14 (.NET 8 stops with `CS0106`). If neither `~/.dotnet10` nor `~/.dotnet` has it, the script installs
  it into `~/.dotnet10` (the Quest builder keeps its .NET 8 in `~/.dotnet`). Or `DOTNET=<path to dotnet>`.
- Internet: NuGet (BepInEx, the publicizer), GitHub (the Unity 6 XR packages from the PC fork's alpha 6 release, checked
  by SHA-256), dot.net if the SDK has to be installed.

## 2. Get the code with DaXcess's RepoXR

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr && git submodule update --init external/RepoXR
```

`external/RepoXR` is DaXcess's RepoXR at 1.2.3 (commit 15b4aec), left as it is. (`external/RepoXR-Unity` is only needed to
rebuild RepoXR's Android assets, which takes Unity.)

## 3. Build RepoXR.dll

```bash
bash scripts/prepare-repoxr.sh
```

It copies `external/RepoXR` into `work/repoxr-src`, applies `patches/repoxr/*.patch` in order, downloads the Unity 6 XR
packages once into `work/downloads`, and builds with `-p:DebugSymbols=false` as the releases are built. The result:

```
work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll
```

Its code is the kit's `prebuilt/repoxr/RepoXR.dll` (checked for 1.0.7-qc27: every method's IL is the same). The bytes
match only with the very same .NET SDK version; a newer compiler may lay out a few methods differently.

## 4. Change RepoXR

Easiest in the PC fork, where you can also test it on a PC:

1. Clone [crimecock/RepoXR](https://github.com/crimecock/RepoXR) (branch `repo-0.5.0`), change `Source/`, build and test
   on PC ([COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)).
2. Make the next patch from your commits: `git diff <last commit in patches/repoxr> <yours> -- Source >
   patches/repoxr/00NN-what-it-does.patch` here, and describe it in `scripts/prepare-repoxr.sh`'s header.

Or here, without the PC fork: `scripts/repoxr-patch.sh start` gives `work/repoxr-edit` (RepoXR with every patch applied,
as a git repository), edit its `Source/`, then `scripts/repoxr-patch.sh save <name>` writes the next patch.

Then `bash scripts/prepare-repoxr.sh` again.

## 5. Build the APK with your DLL

```bash
REPOXR_DLL=$PWD/work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll CODE_ONLY=1 bash scripts/build-mac.sh
```

The script takes the current kit, copies it to `~/RepoQuest/kit-<version>-custom` with your RepoXR.dll in
`prebuilt/repoxr/`, and builds the APK from that copy. `CODE_ONLY=1` reuses the game data of your last full build
(about 10 minutes); without an earlier build it does a full one. The next build without `REPOXR_DLL` uses the kit's own
DLL again.

A whole new kit (all its parts rebuilt: RepoXR.Standalone, SteamShim, libopus, RepoXR's Android assets with Unity) is
`scripts/make-kit.sh`; a release of this fork (kit on the `kit` branch, versions in the build scripts, tag, GitHub
release) is `scripts/release-fork.sh` ([updating.md](updating.md#for-maintainers)).

## On Windows

`scripts/prepare-repoxr.sh` is a bash script. On Windows, build the same RepoXR.dll from the PC fork, then give it to the
Windows build script:

1. Install the [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0) and unpack the PC fork's all-in-one zip
   into your game folder (the build needs its Unity 6 XR libraries).
2. Build: `git clone https://github.com/crimecock/RepoXR.git -b repo-0.5.0`, then in that folder
   `dotnet build RepoXR.sln -c Release -p:DebugSymbols=false -p:GamePath="<your REPO folder>"`
   ([COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)). Change `Source/` there to change
   the mod.
3. Build the APK with it, in this repository's folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -CodeOnly -RepoXRDll <RepoXR folder>\bin\Release\netstandard2.1\RepoXR.dll
```

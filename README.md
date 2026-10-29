# R.E.P.O. VR on Quest, standalone — R.E.P.O. 0.5.0 (Unity 6) port

**English** · [Русский](README.ru.md)

This is a fork of **[repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr)** by [Dobutsu](https://github.com/Dobutsu),
which runs [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/) in VR on a Meta Quest without a PC, built on
**[RepoXR](https://github.com/DaXcess/RepoXR)** by [DaXcess](https://github.com/DaXcess).

The original port (1.0.7) supports R.E.P.O. **0.4.4.3**, which ran on Unity 2022.3. Steam now ships R.E.P.O. **0.5.0**,
which moved to **Unity 6000.3**, and the original builder stops at the export step. This fork carries the whole port
over to 0.5.0 and adds a few performance options.

> **Status: testing.** The pipeline builds a 0.5.0 APK end to end; testing on a real Quest 3 is in progress. Report
> problems with this fork [here](../../issues), not to Dobutsu or DaXcess.

The game is built **from your own copy of R.E.P.O.** on Steam. This repository and its releases contain no game files.
**Do not share the APK** you build: it contains the game's files.

## What this fork changes

**R.E.P.O. 0.5.0 support**
- **RepoXR** ([`patches/repoxr/0009-repo-0.5.0.patch`](patches/repoxr/0009-repo-0.5.0.patch), on top of RepoXR 1.2.3
  and the port's patches 0001–0008): 0.5.0 renamed or moved much of what RepoXR patches (new overloads, the text
  prompt page, `KeyType`, vehicle and snow bike heading, glyph tags, climbing). Menus now click through
  `InputKey.UIClick`, which is answered by the VR pointer's trigger.
- **Builder and Unity**: Unity 6000.3.17f1; player settings that AssetRipper cannot
  read from 0.5.0 are restored from the game's `globalgamemanagers` (gamma colour space, both input handlers, preloaded
  Input System and Localization settings).
- **Packages** matched to the game's DLLs: Input System 1.19.0, uGUI 2.0.0 (TextMeshPro included), Localization 1.5.12,
  Addressables 2.9.1, PostProcessing 3.5.4 and others.
- **Addressables 2.x binary catalog** (`catalog.bin`) decoder, so cosmetics and all languages are rebuilt for Android.
- **Audio**: AssetRipper 2.0.0 writes every WAV with zero chunk sizes, which Unity 6 cannot decode; the headers are fixed.
- **SteamShim**: the Steam APIs 0.5.0 calls on startup and in lobbies (`SteamApps.CurrentBetaName`, achievement
  progress, gamepad text input).
- **In-headset Steam login** uses 0.5.0's text prompt page.

**Performance** (the game is CPU-bound on the Quest)
- **Level culling**: small objects beyond 20 m and everything hidden by the fog are not drawn. Rendering only —
  objects keep running, multiplayer is unaffected. Settings in the game: *Settings → VR Settings → Rendering*
  (Level Culling, Small Object Distance, Room Distance).
- **IL2CPP Master** code generation.
- **CPU and GPU at SUSTAINED_HIGH** from the start of every session (`XR_EXT_performance_settings`).

Details: [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md). Controls: [`docs/controls.md`](docs/controls.md).

## How to build

You need R.E.P.O. 0.5.0 on Steam, **Unity 6000.3.17f1** with Android Build Support (OpenJDK, Android SDK & NDK), the
.NET 8 SDK, about 60 GB of free disk space and a Quest in developer mode with a USB cable.

### macOS

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
bash scripts/build-mac.sh
```

The script downloads the kit from this fork's [`kit` branch](../../tree/kit), the game through `steamcmd` (it asks for your
Steam login once; the password goes only to Steam), builds the builder and the APK, and installs it on the headset.
The first build takes 1–1.5 hours. Use `GAME=/path/to/REPO` for a copy you already have, `--no-install` to build only.

### Windows

The original Windows builder app embeds the 1.0.7 kit and cannot build 0.5.0. In PowerShell, in a folder with an
ASCII path without spaces:

```powershell
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

Step-by-step guide with the headset setup, options and troubleshooting: [`docs/build-windows.md`](docs/build-windows.md).

### Any OS with .NET 8

The command-line builder with the unzipped kit from the [`kit` branch](../../tree/kit):

```
dotnet run -c Release --project builder/QuestBuilder.Cli -- build --kit <unzipped kit> --game <folder with REPO_Data> --workspace <work folder> --unity <Unity 6000.3.17f1 folder> --headset quest
```

## When R.E.P.O. updates

The build scripts notice a game version the kit was not tested with and check it first, in minutes and without Unity
(`QuestBuilder.Cli check`): they stop with a report if RepoXR's patches, the Steam client or the packages no longer
fit. What maintainers do then, and how a release is made: [`docs/updating.md`](docs/updating.md). Releases:
[`CHANGELOG.md`](CHANGELOG.md).

## Steam in the headset

To play online, you log in to Steam inside the game, from the **Steam** button in the main menu. The headset then talks
to Steam directly through [SteamKit2](https://github.com/SteamRE/SteamKit), an unofficial Steam client. Steam's
Subscriber Agreement does not allow third-party clients. The risk to your account is small, but it is real.
Singleplayer works without logging in.

## How it works

```
your R.E.P.O. (Steam)
  └─ AssetRipper ──────────► Unity project (the game's scenes, prefabs, scripts as DLLs)
  └─ HarmonyBaker ─────────► RepoXR's Harmony patches baked into the game's assemblies (no runtime patching on IL2CPP)
  └─ scripts/ (Python) ────► fixes for the export: shaders, Addressables, audio, packages, halos
  └─ Unity 6000.3 (IL2CPP, OpenXR, Vulkan) ─► Android APK ─► Quest
```

See the original project's design notes in [`docs/`](docs) ([`feasibility.md`](docs/feasibility.md),
[`builder.md`](docs/builder.md)); they describe the 0.4.4.3 / Unity 2022.3 port, and
[`docs/repo-0.5.0.md`](docs/repo-0.5.0.md) what changed for 0.5.0.

## Legal

This is an unofficial fan project. It is not affiliated with or endorsed by semiwork (R.E.P.O.), DaXcess (RepoXR),
Dobutsu, Valve or Meta. R.E.P.O. and its assets belong to semiwork. The repository contains only the port's own code.
Every player builds the game from a copy they own.

Licensed under the **GNU GPL v3.0** (see [LICENSE](LICENSE)), like the original port and RepoXR. Third-party components
are listed in [`builder/SOURCES.md`](builder/SOURCES.md) and
[`builder/release/THIRD-PARTY-NOTICES.txt`](builder/release/THIRD-PARTY-NOTICES.txt).

## Credits

- **[Dobutsu](https://github.com/Dobutsu)**: [repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr), the standalone
  Quest port this fork is based on ([ko-fi](https://ko-fi.com/dobutsu)).
- **[DaXcess](https://github.com/DaXcess)**: [RepoXR](https://github.com/DaXcess/RepoXR) and
  [RepoXR-Unity](https://github.com/DaXcess/RepoXR-Unity), the VR mod everything is built on.
- **semiwork**: [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/)
- [SteamKit2](https://github.com/SteamRE/SteamKit), [AssetRipper](https://github.com/AssetRipper/AssetRipper),
  [BepInEx](https://github.com/BepInEx/BepInEx), [HarmonyX](https://github.com/BepInEx/HarmonyX),
  [Opus](https://opus-codec.org/), and the [needle-mirror](https://github.com/needle-mirror) package mirrors used to
  match package versions.
- 0.5.0 port by **[crimecock](https://github.com/crimecock)**, made with
  [Claude Code](https://claude.com/claude-code).

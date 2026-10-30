# R.E.P.O. VR on Quest, standalone — R.E.P.O. 0.5.0 (Unity 6) port

**English** · [Русский](README.ru.md)

This is a fork of **[repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr)** by [Dobutsu](https://github.com/Dobutsu),
which runs [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/) in VR on a Meta Quest without a PC, built on
**[RepoXR](https://github.com/DaXcess/RepoXR)** by [DaXcess](https://github.com/DaXcess).

The original port (1.0.7) supports R.E.P.O. **0.4.4.3**, which ran on Unity 2022.3. Steam now ships R.E.P.O. **0.5.0**,
which moved to **Unity 6000.3**, and the original builder stops at the export step. This fork carries the whole port
over to 0.5.0 and adds a few performance options.

> [!TIP]
> **Playing on PC?** The same RepoXR code, ported to 0.5.0, is a BepInEx mod for the Windows version of the game:
> **[crimecock/RepoXR](https://github.com/crimecock/RepoXR)** (branch `repo-0.5.0`) —
> [releases](https://github.com/crimecock/RepoXR/releases) (all-in-one zip), [install](https://github.com/crimecock/RepoXR#install-on-pc-repo-050--установка-на-пк),
> [controls on PC](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/controls.md).

## Credits

Thanks to the people whose work this port stands on:

- **[Dobutsu](https://github.com/Dobutsu)**: [repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr), the standalone
  Quest port this fork is based on ([ko-fi](https://ko-fi.com/dobutsu)).
- **[DaXcess](https://github.com/DaXcess)**: [RepoXR](https://github.com/DaXcess/RepoXR) and
  [RepoXR-Unity](https://github.com/DaXcess/RepoXR-Unity), the VR mod everything is built on.
- [SteamKit2](https://github.com/SteamRE/SteamKit), [AssetRipper](https://github.com/AssetRipper/AssetRipper),
  [BepInEx](https://github.com/BepInEx/BepInEx), [HarmonyX](https://github.com/BepInEx/HarmonyX),
  [Opus](https://opus-codec.org/), and the [needle-mirror](https://github.com/needle-mirror) package mirrors used to
  match package versions.
- 0.5.0 port by **[crimecock](https://github.com/crimecock)**, made with
  [Claude Code](https://claude.com/claude-code).

> **Status: everything works (1.0.7-qc27).** Menus and settings, the in-headset Steam login, lobby, levels, the shop,
> grabbing, guns, the whip, tumble climbing, vehicles, the expression wheel, the tutorial, the controls page with
> rebinding, multiplayer. Tested on PC, and the Quest builds the very same RepoXR code. What each version changed:
> [CHANGELOG.md](CHANGELOG.md). Report problems with this fork [here](../../issues), not to Dobutsu or DaXcess.

> **Updating:** over qc24 a code-only build is enough for qc27 (about 6 minutes; the game's data from your last full
> build is reused). Over the earlier public release qc2, make a full build — see [docs/updating.md](docs/updating.md#updating-to-a-newer-build-of-this-fork).

### Start here

| I want to… | Read |
|---|---|
| play on my Quest | [How to build](#how-to-build) (below), then [playing in the headset](docs/playing.md) and the [controls](docs/controls.md) |
| install a build by hand, or keep my saves when reinstalling | [docs/install.md](docs/install.md) |
| update to a newer version of this fork | [docs/updating.md](docs/updating.md#updating-to-a-newer-build-of-this-fork) |
| play on PC instead | [crimecock/RepoXR](https://github.com/crimecock/RepoXR) |
| change the VR mod (RepoXR.dll) and test it on the Quest | [docs/build-repoxr.md](docs/build-repoxr.md) |
| build every part of the kit myself | [docs/build-kit.md](docs/build-kit.md) |
| release a new version | [docs/releasing.md](docs/releasing.md) |
| know how the port works | [How it works](#how-it-works), [docs/repo-0.5.0.md](docs/repo-0.5.0.md) |

### Known issues

Everything works: tested on PC, and the Quest builds the same code. One small issue: **the language page** (*Settings → Language*) shows only Text to Speech in VR, because the language buttons land outside the menu. The fix is ready and comes with the next build. Good to know:

- **The shop mirror is hidden on the Quest, on purpose**: with single-pass rendering (the Quest's default) both eyes
  would share one reflection. It works with *VR Settings → Rendering → Render Mode* set to Multipass, at a frame rate
  cost ([details](docs/playing.md#the-shop-mirror)).
- The whip flings only once it has caught something; its sensitivity is in VR Settings → Input → *Whip Sideways /
  Crack Sensitivity*.

Details: [docs/playing.md](docs/playing.md#known-issues).

### Controls

| Quest controller | In game |
|---|---|
| Left stick · click · hold | Move · chat · expression wheel |
| Left trigger · left grip | Sprint · rotate the held object |
| **≡ (left menu button)** · X · Y | **Menu** · mute the microphone · reset height |
| Right stick left/right · up/down · click | Turn · push/pull, scroll · crouch |
| **Right trigger** | **Grab** (beam), click in menus, get on/off vehicles |
| Right grip | Interact, fire a gun, horn |
| A · B | Jump · tumble |

Map at the shoulder (grip), flashlight at the head, inventory, weapons, the whip, vehicles, tumble climbing:
[docs/controls.md](docs/controls.md). Rebind in *Settings → Controls*; free actions (Inventory 1–3, Expression 1–6,
Push To Talk) can get a button there.

The game is built **from your own copy of R.E.P.O.** on Steam. This repository and its releases contain no game files.
**Do not share the APK** you build: it contains the game's files.

## How to build

**Install these yourself, once:**

| What | Where | macOS | Windows |
|---|---|---|---|
| R.E.P.O. 0.5.0 | [Steam](https://store.steampowered.com/app/3241660/REPO/) | owning it is enough: the script downloads the Windows version with `steamcmd` | installed in Steam (the script finds it) |
| Unity Hub + a free Unity account | [unity.com/download](https://unity.com/download) | ✓ | ✓ |
| Unity **6000.3.17f1** with **Android Build Support** (tick **OpenJDK** and **Android SDK & NDK Tools**) | open `unityhub://6000.3.17f1/cf0352b38e81` in the browser: Unity Hub opens on this version (the scripts open it too when Unity is missing) | ✓ | ✓ |
| Git (or the code as a [ZIP](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip)) | macOS: `xcode-select --install`; Windows: [Git for Windows](https://git-scm.com/download/win) | ✓ | ✓ |
| Developer mode on the Quest | Meta Horizon app on the phone, see [Meta's guide](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/) | ✓ | ✓ |

Plus about 60 GB of free disk space and a USB-C cable that carries data.

**The scripts download the rest themselves:** the .NET 8 SDK (if missing), this fork's kit (checked by SHA-256),
on macOS `steamcmd` with Rosetta 2 and the game; the builder then fetches AssetRipper, Python and its packages, NuGet
packages and Unity's built-in shaders, each from its original source. `adb` for installing on the headset comes with
Unity's Android module.

**Which .NET:** building the APK needs only the **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** (the builder), and the scripts install it
themselves (macOS: `~/.dotnet`, Windows: `%LOCALAPPDATA%\Microsoft\dotnet`); an SDK you already have works too. The
**[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** is only for compiling RepoXR.dll yourself ([`docs/build-repoxr.md`](docs/build-repoxr.md)),
and `scripts/prepare-repoxr.sh` installs that one into `~/.dotnet10`.

### macOS

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
bash scripts/build-mac.sh
```

Without Git: unpack the [code ZIP](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) and run the script from the `repo-quest-vr-repo-0.5.0` folder.

The script downloads the kit from this fork's [`kit` branch](../../tree/kit), the game through `steamcmd` (it asks for your
Steam login once; the password goes only to Steam), builds the builder and the APK, and installs it on the headset.
The first build takes 1–1.5 hours. Use `GAME=/path/to/REPO` for a copy you already have, `--no-install` to build only.
`CODE_ONLY=1` rebuilds only the code into the last APK (a new kit that changes DLLs or patches, not assets): Unity
skips repacking the game's data, which is two thirds of a build, so it takes about 10 minutes instead of 35.

Step by step, with the options and troubleshooting: [`docs/build-mac.md`](docs/build-mac.md). If installing on the headset fails, or to install a build by hand: [`docs/install.md`](docs/install.md).

### Windows

The original Windows builder app embeds the 1.0.7 kit and cannot build 0.5.0. In PowerShell, in a folder with an
ASCII path without spaces:

```powershell
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

Without Git: unpack the [code ZIP](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) and run the script from the `repo-quest-vr-repo-0.5.0` folder.

Step-by-step guide with the headset setup, options and troubleshooting: [`docs/build-windows.md`](docs/build-windows.md).

### Any OS with .NET 8

The command-line builder with the unzipped kit from the [`kit` branch](../../tree/kit):

```
dotnet run -c Release --project builder/QuestBuilder.Cli -- build --kit <unzipped kit> --game <folder with REPO_Data> --workspace <work folder> --unity <Unity 6000.3.17f1 folder> --headset quest
```

### What gets built where

```
your Steam copy of R.E.P.O. 0.5.0 ─┐
the kit (kit branch): scripts,     ├─ scripts/build-mac.sh / build-windows.ps1 ─► APK on the Quest
  Unity tooling, ready-made DLLs  ─┘   (.NET 8 builder, AssetRipper, Unity 6000.3.17f1)
  RepoXR.dll, RepoXR.Standalone,
  SteamShim
```

You never compile RepoXR (the VR mod) to play: its DLL comes ready-made in the kit, and the scripts bake it into the
game's code. It is built from DaXcess's RepoXR 1.2.3 plus [`patches/repoxr`](patches/repoxr) with `scripts/prepare-repoxr.sh`
(.NET 10), and has the same code as the [PC fork](https://github.com/crimecock/RepoXR)'s release. To change it or
rebuild it yourself: [`docs/build-repoxr.md`](docs/build-repoxr.md); every part of the kit from scratch:
[`docs/build-kit.md`](docs/build-kit.md).

## What this fork changes

**R.E.P.O. 0.5.0 support** — what each new 0.5.0 feature does in VR (gamepad support, languages, cosmetics, the new
level, expression wheel, item auto hold, climbing, vehicles...) and its status: [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md#repo-050s-new-features-in-vr)
- **RepoXR** ([`patches/repoxr/0009-repo-0.5.0.patch`](patches/repoxr/0009-repo-0.5.0.patch), on top of RepoXR 1.2.3
  and the port's patches 0001–0008): 0.5.0 renamed or moved much of what RepoXR patches (new overloads, the text
  prompt page, `KeyType`, vehicle and snow bike heading, glyph tags, climbing). Menus now click through
  `InputKey.UIClick`, which is answered by the VR pointer's trigger, and patch
  [`0010`](patches/repoxr/0010-vr-menus-0.5.0.patch) keeps them in pointer mode (0.5.0's gamepad support would switch
  them to keyboard navigation for good). [`0011`](patches/repoxr/0011-menu-hover-scale-0.5.0.patch) sizes the buttons'
  hover areas for the world-space menu, [`0012`](patches/repoxr/0012-xr-ui-input-module.patch) makes the pointers'
  UI module the one the EventSystem runs. [`0019`](patches/repoxr/0019-grab-vehicles-menu-button-fps.patch) makes
  grabbing and vehicles work on 0.5.0, moves the pause menu to the left menu button (X mutes the microphone) and adds
  an FPS counter; [`0020`](patches/repoxr/0020-guns-and-grab-release-from-hand.patch) aims guns from the hand.
- **Grabbing** (works on the Quest and on PC): 0.5.0's *Item Unequip Auto Hold* moved the toggle-grab release from
  `PhysGrabber.Update` into `GrabInputActiveGet`. RepoXR's `ForceHoldPatch` lost its anchor and wrote into the grab
  cooldown instead, so the grab beam never switched on; `0019` patches the new method and fails if the anchor is gone
  (the builder's `check` now reports every lost anchor). `0020` takes forced grabs and the release after rotating an
  object from the hand (rotated objects used to jump), `0009` turns the reworked tumble climb with the hand
  (`ClimbTargetUpdate`; checked on PC). Table: [grabbing, what broke and how it was fixed](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/repo-0.5.0.md#grabbing-what-broke-and-how-it-was-fixed).
- **The whip, the shop, the news popup** ([`0029`](patches/repoxr/0029-whip-result-screen-aim-news-popup.patch),
  tested on PC): RepoXR skips the game's camera aim update, and with it the timer that ends the aim targets the game
  forces on the camera, so one stayed active for good and kept the whip's gestures off; now the timers run, and while
  you hold the whip its gestures read how fast your hand turns (snap back and forward to crack, also from over the
  shoulder; VR Settings → Input → *Whip Sideways/Crack Sensitivity*). In the scene handoff the old VR loading screen
  cleared the new one's reference, and level → shop hung on the result screen. The news popup grows from nothing and
  its words came out as solid bars; its texts are built again once it has grown.
- **Settings menus, the shop mirror, Quest 3 controls, tutorial texts** (the PC fork's alpha 4–6, tested there):
  [`0030`](patches/repoxr/0030-settings-menus-controller-icons-text-tags.patch) rebuilds the controller icon sheet that Unity 6's
  TextMeshPro reads without glyphs or material, takes the text tags from 0.5.0's `InputGlyphs` (no more `[move]`) and
  fixes the toggles and the *VR Settings* button; [`0031`](patches/repoxr/0031-shop-mirror-toggles.patch) makes the game's mirror
  camera render mono, once per eye from that eye's reflected pose (it rendered as a stereo camera, so the eye matrices
  replaced its view); hidden with single-pass rendering, where both eyes would share one reflection;
  [`0032`](patches/repoxr/0032-tutorial-texts-quest-controller-scheme-render-mode.patch) gives the Quest 3's Touch Plus controllers
  a control scheme (the controls page said *DISCONNECTED*), adds *Render Mode*, and shows RepoXR's VR tutorial texts in
  English. Each problem, its cause and the fix: [the PC fork's table](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/repo-0.5.0.md#what-changed-in-050-and-what-the-port-does).
- **Building RepoXR.dll** ([`0033`](patches/repoxr/0033-build-against-the-game-folder.patch)): NuGet only has R.E.P.O. 0.4.4 and
  Unity 2022, so RepoXR's project now compiles against your Windows copy of the game and the Unity 6 XR packages, with
  the .NET 10 SDK (RepoXR uses C# 14). [`docs/build-repoxr.md`](docs/build-repoxr.md).
- **Unity 6 engine methods**: Unity 6 turned engine methods such as `Camera.set_targetTexture` into managed code; the
  baker now hooks them at their call sites, as it did for the old externs. Without this the game kept rendering into
  its small render texture and the headset showed a black, smearing world.
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

Details: [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md). Playing in the headset (VR settings, multiplayer, files, what to send
when something is wrong): [`docs/playing.md`](docs/playing.md). Controls: [`docs/controls.md`](docs/controls.md).

## When R.E.P.O. updates

The build scripts notice a game version the kit was not tested with and check it first, in minutes and without Unity
(`QuestBuilder.Cli check`): they stop with a report if RepoXR's patches, the Steam client or the packages no longer
fit. What maintainers do then, and how a release is made: [`docs/updating.md`](docs/updating.md). Releases:
[`CHANGELOG.md`](CHANGELOG.md).

**Releasing a new version** (both this repository and the PC fork: where the version lives, what to change, in which
order): [`docs/releasing.md`](docs/releasing.md).

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

What changed for 0.5.0: [`docs/repo-0.5.0.md`](docs/repo-0.5.0.md). The original port for R.E.P.O. 0.4.4.3 / Unity
2022.3, with its own README and design notes: **[Dobutsu/repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr)**.

## Legal

This is an unofficial fan project. It is not affiliated with or endorsed by semiwork (R.E.P.O.), DaXcess (RepoXR),
Dobutsu, Valve or Meta. R.E.P.O. and its assets belong to semiwork. The repository contains only the port's own code.
Every player builds the game from a copy they own.

Licensed under the **GNU GPL v3.0** (see [LICENSE](LICENSE)), like the original port and RepoXR. Third-party components
are listed in [`builder/SOURCES.md`](builder/SOURCES.md) and
[`builder/release/THIRD-PARTY-NOTICES.txt`](builder/release/THIRD-PARTY-NOTICES.txt).

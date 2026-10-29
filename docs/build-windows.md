# Building on Windows

**English** · [Русский](build-windows.ru.md)

The original Windows app (RepoQuestBuilder 1.0.7 from Dobutsu's releases) embeds the 0.4.4.3 kit and cannot build
R.E.P.O. 0.5.0. This fork builds with the same pipeline from the command line: `scripts/build-windows.ps1` does
everything the app did, step by step.

> The Windows script follows the macOS one, which is the one tested so far. If something fails, open an
> [issue](https://github.com/crimecock/repo-quest-vr/issues) with `C:\RepoQuest\work\logs\builder.log` (and `unity-build.log` if Unity ran).

## What you need

- Windows 10/11 64-bit, 16 GB RAM, **about 60 GB free** on the drive with the work folder (`C:\RepoQuest` by default).
- **R.E.P.O. 0.5.0** installed in Steam (the builder finds it in your Steam libraries).
- A **Meta Quest** (made and tested on a Quest 3) in **developer mode**, and a USB cable.
- **Unity Hub** and a free Unity account.
- [Git for Windows](https://git-scm.com/download/win), or download the code as a ZIP (below).

The script installs the **.NET 8 SDK** itself if it is missing. The builder downloads everything else (AssetRipper,
Python with its packages, BepInEx, NuGet packages, Unity's built-in shaders), each from its original source.

## 1. Install Unity 6000.3.17f1 with Android

Open this link in the browser (Unity Hub opens on the right version):

```
unityhub://6000.3.17f1/cf0352b38e81
```

In the module list tick **Android Build Support** and inside it **OpenJDK** and **Android SDK & NDK Tools**, then
install (about 10 GB). Keep the default location (`C:\Program Files\Unity\Hub\Editor\6000.3.17f1`) or pass `-Unity`
to the script later.

## 2. Get the code

With Git, in PowerShell, in a folder whose path has only Latin letters and no spaces (for example `C:\src`):

```powershell
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
```

Without Git: on the repository page click **Code → Download ZIP**, unpack it to such a folder and open PowerShell there.

## 3. Prepare the headset

1. Enable **developer mode** for the headset in the Meta Horizon app on your phone.
2. Connect the Quest to the PC by USB and put it on: allow **USB debugging** (tick "always allow from this computer").

## 4. Build

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

The script:

1. checks Unity 6000.3.17f1 with Android (and opens Unity Hub on it if it is missing);
2. installs the .NET 8 SDK if needed;
3. downloads the kit from this fork's `kit` branch and checks its SHA-256;
4. builds the builder and runs it: AssetRipper export, RepoXR baked into the game, the Unity project, Unity → APK;
5. installs the APK on the headset.

The **first build takes 1–1.5 hours on a fast PC and 3–5 hours on a slower one** (Unity imports the game and compiles
its shaders once). Later builds reuse that work and take 20–40 minutes. Keep the PC awake; the builder blocks sleep
while it runs.

Options:

| Option | What it does |
|---|---|
| `-Game "D:\SteamLibrary\steamapps\common\REPO"` | Your game folder (the one with `REPO_Data`) if it is not found automatically |
| `-Unity "D:\Unity\6000.3.17f1"` | Unity folder (the one with `Editor\Unity.exe`) if it is elsewhere |
| `-Workspace D:\RepoQuest` | Another work folder (ASCII path without spaces) |
| `-NoInstall` | Build only; the APK is in `<work folder>\work\build` |

To speed it up, you can add the work folder to Windows Security exclusions (Virus & threat protection → Manage settings
→ Exclusions): Defender otherwise scans every one of the tens of thousands of files the build writes.

## 5. Play

In the headset: **Library → Unknown Sources → R.E.P.O.** Singleplayer works right away. For multiplayer, log in to
Steam from the **Steam** button in the main menu (see the README about the unofficial Steam client).

Settings for performance: *Settings → VR Settings → Rendering* (Level Culling and its distances, Pixel Lights, Lamp
Lighting, Post Processing). Controls: [controls.md](controls.md).

**Do not share the APK**: it contains the game's files. Everyone builds their own.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

When R.E.P.O. updates on Steam, the build may need changes in this repository first; check the issues.

## Troubleshooting

| Problem | What to do |
|---|---|
| `running scripts is disabled on this system` | Start the script exactly as above, with `powershell -ExecutionPolicy Bypass -File ...` |
| `Unity ... not found` | Install it (step 1) or pass `-Unity` |
| `the work folder must be an ASCII path` | Use `-Workspace` with a path like `D:\RepoQuest` |
| `no headset` after the build | Connect the cable, accept USB debugging in the headset, and run the `adb install` line the script printed |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | An older build signed differently is installed: `adb uninstall io.repoxr.quest` (removes the game's saves on the headset), then install again |
| The build stops with an error | Logs are in `C:\RepoQuest\work\logs`; run the script again after a fix, finished steps are skipped |

# Building on macOS

**English** · [Русский](build-mac.ru.md)

`scripts/build-mac.sh` builds R.E.P.O. 0.5.0 for the Quest from your own Steam copy of the game and installs it on the
headset. This is the script the port is built and tested with.

## What you need

- A Mac (Apple Silicon or Intel), 16 GB RAM, **about 60 GB free** on the disk with the work folder (`~/RepoQuest` by default).
- **R.E.P.O.** bought on [Steam](https://store.steampowered.com/app/3241660/REPO/). It does not have to be installed:
  the script downloads the Windows version of the game with `steamcmd`.
- A **Meta Quest** (made and tested on a Quest 3) in **developer mode**, and a USB-C cable that carries data.
- **Unity Hub** ([unity.com/download](https://unity.com/download)) and a free Unity account.
- **Git**: `xcode-select --install` in Terminal installs Apple's command line tools with it. Or download the code as a
  ZIP (below).

The script installs the **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** (into `~/.dotnet`; only .NET 8 is needed to build the APK), **steamcmd** and **Rosetta 2** (steamcmd is an Intel
program; macOS asks for your password) itself when they are missing. The builder downloads everything else
(AssetRipper, Python with its packages, NuGet packages, Unity's built-in shaders), each from its original source.

## 1. Install Unity 6000.3.17f1 with Android

Install [Unity Hub](https://unity.com/download) and sign in. Then open this link in the browser (Unity Hub opens on
the right version):

```
unityhub://6000.3.17f1/cf0352b38e81
```

In the module list tick **Android Build Support** and inside it **OpenJDK** and **Android SDK & NDK Tools**, then
install (about 10 GB). Keep the default location (`/Applications/Unity/Hub/Editor/6000.3.17f1`) or set `UNITY=` for
the script later.

## 2. Get the code

In Terminal:

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr
```

Without Git: download the code as a ZIP — [repo-quest-vr-repo-0.5.0.zip](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) (the same as **Code → Download ZIP** on the repository page; the code of this fork, no game files) — unpack it and `cd` into the `repo-quest-vr-repo-0.5.0` folder in Terminal. To update later, download it again (`git pull` needs a Git clone).

## 3. Prepare the headset

1. Enable **developer mode** for the headset in the Meta Horizon app on your phone: Devices → your Quest → Headset
   settings → Developer mode. Meta asks you to join or create a (free) developer organization first; details in
   [Meta's guide](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/).
2. Connect the Quest to the Mac by USB and put it on: allow **USB debugging** (tick "always allow from this computer").

## 4. Build

```bash
bash scripts/build-mac.sh
```

The script:

1. checks Unity 6000.3.17f1 with Android (and opens Unity Hub on it if it is missing);
2. installs the .NET 8 SDK if needed;
3. downloads the kit from this fork's `kit` branch and checks its SHA-256;
4. downloads the game with `steamcmd` into `~/RepoQuest/game`. It asks once for your Steam **account name** (not the
   e-mail), password and the Steam Guard code; they go only to Steam. About 2–3 GB. The first steamcmd run updates
   itself and sometimes stops: the script tries again;
5. builds the builder and runs it: AssetRipper export, RepoXR baked into the game, the Unity project, Unity → APK;
6. installs the APK on the headset.

The **first build takes 1–1.5 hours**; later builds reuse that work and take 20–40 minutes. The Mac does not sleep
while the build runs (`caffeinate`).

Options:

| Option | What it does |
|---|---|
| `GAME=/path/to/REPO bash scripts/build-mac.sh` | Use a copy of the game you already have (the folder with `REPO_Data`) |
| `UNITY=/path/to/6000.3.17f1 bash scripts/build-mac.sh` | Unity folder (the one with `Unity.app`) if it is elsewhere |
| `REPOQUEST_HOME=/path bash scripts/build-mac.sh` | Another work folder (ASCII path without spaces) |
| `bash scripts/build-mac.sh --no-install` | Build only; the APK is in `~/RepoQuest/work/build` |
| `CODE_ONLY=1 bash scripts/build-mac.sh` | Only the code changed (a new kit with new DLLs or patches): reuse the last APK's packed game data, about 10 minutes instead of 35. A full build when there is no earlier one |
| `FORCE=1 bash scripts/build-mac.sh` | Build even when the check of a new game version finds problems |

## 5. Play

In the headset: **Library → Unknown Sources → R.E.P.O.** Singleplayer works right away. For multiplayer, log in to
Steam from the **Steam** button in the main menu (see the README about the unofficial Steam client).

Settings, multiplayer, files in the headset: [playing.md](playing.md). Controls: [controls.md](controls.md).

**Do not share the APK**: it contains the game's files. Everyone builds their own.

## Updating

```bash
git pull
```

Without Git: download the [code ZIP](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) again and unpack it over the old folder (the work folder `~/RepoQuest` keeps the game and the earlier build).

```bash
CODE_ONLY=1 bash scripts/build-mac.sh
```

The copy of the game in `~/RepoQuest/game` does not update by itself, so a game update on Steam breaks nothing until
you delete it. More: [updating.md](updating.md).

## Troubleshooting

| Problem | What to do |
|---|---|
| `Unity ... not found` | Install it (step 1) or set `UNITY=` |
| `Unity has no Android Build Support` | Unity Hub → Installs → 6000.3.17f1 → Add modules → Android Build Support (with OpenJDK and Android SDK & NDK Tools) |
| `the work folder must be an ASCII path` | Set `REPOQUEST_HOME=` to a path like `~/RepoQuest` |
| `R.E.P.O. did not download` | Run the script again (steamcmd often needs a second try), or pass `GAME=` |
| `no headset` or `install failed` after the build | The APK is built; install it by hand: [install.md](install.md) (connection problems, `INSTALL_FAILED_…` errors, reinstalling without losing saves) |
| The build stops with an error | Logs are in `~/RepoQuest/work/logs`; run the script again after a fix, finished steps are skipped |

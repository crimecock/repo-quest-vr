# Installing the APK by hand

The build scripts install the APK themselves at the end. If that step failed, or you built with `--no-install` /
`-NoInstall`, install it as described here. The game itself does not have to be rebuilt.

Русская версия: [install.ru.md](install.ru.md).

## 1. Prepare the headset

1. Turn on **developer mode** for the headset in the Meta Horizon app on your phone: Devices → your Quest → Headset
   settings → Developer mode. You need it only once ([Meta's guide](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/): Meta asks you to join or create a free developer organization first).
2. Connect the Quest to the computer with a USB-C cable that carries data. Some charging cables carry power only.
3. Put the headset on. Allow **USB debugging** and tick "Always allow from this computer".
4. Keep the headset awake during the install. A sleeping Quest accepts the APK but does not install it until it wakes.

## 2. Find adb

adb comes with Unity's Android support. You do not need a separate install.

macOS:

```bash
ADB=/Applications/Unity/Hub/Editor/6000.3.17f1/PlaybackEngines/AndroidPlayer/SDK/platform-tools/adb
```

Windows (PowerShell):

```powershell
$adb = "C:\Program Files\Unity\Hub\Editor\6000.3.17f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe"
```

If you installed Unity in another folder, change the start of the path. `adb` from Android platform-tools or SideQuest
works too.

The APK is in the `work/build` folder of the workspace:
- macOS: `~/RepoQuest/work/build/REPO-Quest.apk`;
- Windows: `C:\RepoQuest\work\build\REPO-Quest.apk`.

The commands below are for macOS. On Windows, write `& $adb` instead of `"$ADB"`.

## 3. Check the connection

```bash
"$ADB" devices
```

The headset must be listed as `device`. See the table below if it is listed as `unauthorized` or `offline`, or
not listed at all.

## 4. Install

```bash
"$ADB" install -r ~/RepoQuest/work/build/REPO-Quest.apk
```

The APK is about 0.8 GB, so this takes one to three minutes. At the end adb prints `Success`. In the headset, open
**Library → Unknown Sources → R.E.P.O.** The first launch takes longer than later ones.

## If it fails

| What adb says | Why | What to do |
|---|---|---|
| Empty list in `adb devices` | The cable carries power only, developer mode is off, or adb did not see the headset | Try another cable or port. Check developer mode. Run `"$ADB" kill-server`, then `"$ADB" devices`. On Windows, install the "Oculus ADB Drivers" from Meta's developer site |
| `unauthorized` | USB debugging was not allowed in the headset | Put the headset on and accept the prompt. If there is no prompt, unplug and replug the cable |
| `offline` | The connection is stuck | Replug the cable, run `"$ADB" kill-server`, then `"$ADB" devices` |
| `more than one device/emulator` | A phone or another headset is connected too | Disconnect it, or add `-s <serial>` from `adb devices` after `"$ADB"` |
| Stays at `Performing Streamed Install` for minutes | The headset went to sleep | Wake it up (put it on, or `"$ADB" shell input keyevent KEYCODE_WAKEUP`) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` or `signatures do not match` | The installed build was signed by another computer: Android's debug keys differ per machine | Reinstall and keep the data, see below |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | The headset needs about 4 GB free | Remove something in the headset, then try again |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | The installed port version is newer | `"$ADB" install -r -d ~/RepoQuest/work/build/REPO-Quest.apk` |
| `Broken pipe`, `connection reset`, `failed to write` | The cable or port dropped during the copy | Use another cable or port, or install in two steps, see below |

### Reinstall and keep the data

`adb uninstall` deletes the game's data on the headset: saves, RepoXR settings, the Steam login and cosmetics. Copy
the data to the computer first and put it back after the install.

```bash
"$ADB" shell am force-stop io.repoxr.quest
```

```bash
mkdir -p ~/RepoQuest/quest-backup
```

```bash
"$ADB" pull /sdcard/Android/data/io.repoxr.quest/files ~/RepoQuest/quest-backup
```

Check that `~/RepoQuest/quest-backup/files` is not empty, then:

```bash
"$ADB" uninstall io.repoxr.quest
```

```bash
"$ADB" install ~/RepoQuest/work/build/REPO-Quest.apk
```

```bash
"$ADB" shell mkdir -p /sdcard/Android/data/io.repoxr.quest/files
```

```bash
"$ADB" push ~/RepoQuest/quest-backup/files/. /sdcard/Android/data/io.repoxr.quest/files
```

```bash
"$ADB" shell chmod -R 777 /sdcard/Android/data/io.repoxr.quest/files
```

The last command lets the game overwrite the restored files when it saves.

### Install in two steps

If the streamed install keeps breaking, copy the APK to the headset first and install it from there:

```bash
"$ADB" push ~/RepoQuest/work/build/REPO-Quest.apk /data/local/tmp/repo.apk
```

```bash
"$ADB" shell pm install -r /data/local/tmp/repo.apk
```

```bash
"$ADB" shell rm /data/local/tmp/repo.apk
```

## Without the command line

[SideQuest](https://sidequestvr.com) or Meta Quest Developer Hub can install an APK by drag and drop. They use adb
too, so the same errors and fixes apply.

**Do not share the APK**: it contains the game's files.

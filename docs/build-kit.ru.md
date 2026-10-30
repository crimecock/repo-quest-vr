# Сборка всего набора с нуля

[English](build-kit.md) · **Русский**

**Игрокам это не нужно:** скрипты сборки скачивают набор сами. Чтобы поменять только RepoXR (VR-мод), есть
[build-repoxr.ru.md](build-repoxr.ru.md) — он короче. Здесь все части набора собираются из этого репозитория и
закреплённых скачиваний, как для выпуска версии форка.

## Что в наборе и откуда каждая часть

| Часть | Из чего | Чем |
|---|---|---|
| `kit.json`, `python/requirements.lock` | `builder/` | копируется; `kit.json` закрепляет все скачивания сборщика (AssetRipper, Python, BepInEx, RepoXR 1.2.3, пакеты NuGet, шейдеры Unity) с их SHA-256 |
| `scripts/`, `unity-tools/` | этот репозиторий | копируются: Python-скрипты цепочки и инструменты для редактора Unity |
| `prebuilt/repoxr/RepoXR.dll` | RepoXR 1.2.3 от DaXcess + `patches/repoxr` | `scripts/prepare-repoxr.sh` (.NET 10) |
| `prebuilt/standalone/RepoXR.Standalone.dll` | `tools/RepoXR.Standalone` | `dotnet build` (.NET 8): запускает RepoXR без BepInEx, замены методов под Android, меню входа в Steam |
| `prebuilt/steam/` | `tools/SteamShim` + SteamKit2 2.5.0 (NuGet) | `dotnet build` (.NET 8): `Facepunch.Steamworks.Win64.dll`, которая говорит со Steam через SteamKit2 вместо `steam_api64` (на Android её нет) |
| `prebuilt/android/libopus_egpv.so` | libopus 1.5.2 (xiph.org) | `scripts/build-opus-android.sh` с Android NDK из Unity: голосовой кодек, который подключает Photon Voice |
| `prebuilt/repoxr-android/` | RepoXR-Unity от DaXcess (`external/RepoXR-Unity`) | `scripts/build-repoxr-assets.sh` в Unity 2022.3.62f3, только с `REBUILD_REPOXR_ASSETS=1`; иначе берутся из текущего набора (меняются только вместе с RepoXR-Unity) |
| `licenses/`, `SOURCES.md` | `builder/`, `external/RepoXR`, libopus | копируются |

`scripts/make-kit.sh` делает всё это и не завершится, если в набор попало что-то похожее на файлы игры.

## 1. Что нужно

- Mac с `git`, `curl`, `unzip`, `rsync`, `python3` (`xcode-select --install`).
- **Unity 6000.3.17f1 с Android Build Support**, как для любой сборки ([build-mac.ru.md](build-mac.ru.md)): её Android NDK
  компилирует libopus. Другой NDK — `NDK=<…/toolchains/llvm/prebuilt/<хост>/bin>`.
- **Windows-версия R.E.P.O. 0.5.0**: один раз запустите `scripts/build-mac.sh` (он скачает её в `~/RepoQuest/game`) или
  укажите `GAME=<папка с REPO_Data>`.
- **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** (`~/.dotnet`, ставит `build-mac.sh`) для SteamShim и
  RepoXR.Standalone и **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** для RepoXR (`prepare-repoxr.sh`
  поставит его в `~/.dotnet10`, если нет).
- Интернет: GitHub, NuGet, thunderstore.io (RepoXR 1.2.3 от DaXcess), downloads.xiph.org (libopus).
- Только чтобы пересобрать Android-ассеты RepoXR: Unity 2022.3.62f3 с Android Build Support и
  `git submodule update --init external/RepoXR-Unity`.

## 2. Соберите набор

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr && git submodule update --init external/RepoXR
```

```bash
bash scripts/make-kit.sh 1.0.7-mine
```

Набор — в `work/kit`, в `kit.json` версия `1.0.7-mine`. Первый запуск занимает несколько минут (компилируется libopus);
дальше переиспользуется то, что не поменялось.

## 3. Соберите с ним APK

```bash
(cd work/kit && rm -f ../kit-mine.zip && zip -qr ../kit-mine.zip .)
```

```bash
KIT_ZIP=$PWD/work/kit-mine.zip KIT_SHA=$(shasum -a 256 work/kit-mine.zip | cut -d' ' -f1) bash scripts/build-mac.sh
```

`build-mac.sh` распакует его в `~/RepoQuest/kit-<версия официального набора>` и соберёт как обычно; следующая сборка без
`KIT_ZIP` вернётся к официальному набору. Если Python-скрипты и Unity-инструменты не менялись, хватит сборки только кода
(`CODE_ONLY=1`).

## 4. Выпустить (для тех, кто поддерживает форк)

`scripts/release-fork.sh` делает выпуск из таких DLL: набор в ветку `kit`, версию и SHA-256 в `scripts/build-mac.sh` и
`scripts/build-windows.ps1`, тег и релиз на GitHub ([updating.ru.md](updating.ru.md#тем-кто-поддерживает-форк)).

# Сборка RepoXR.dll для Quest с нуля

[English](build-repoxr.md) · **Русский**

**Игрокам это не нужно.** `scripts/build-mac.sh` и `scripts/build-windows.ps1` скачивают набор, а в наборе RepoXR.dll
уже есть. Эта страница — чтобы поменять RepoXR (сам VR-мод) для сборки на Quest или проверить, что DLL в наборе
действительно собрана из исходников этого репозитория.

## Как всё связано

```
DaXcess/RepoXR 1.2.3 (external/RepoXR, без изменений)
  + patches/repoxr/0001–0033 (этот порт; 0033 — сборка по папке игры)
        │  scripts/prepare-repoxr.sh: .NET 10, компилируется по вашей Windows-копии R.E.P.O. 0.5.0
        ▼
RepoXR.dll  ─ тот же код, что в релизе ПК-форка (github.com/crimecock/RepoXR, ветка repo-0.5.0)
        │  в набор как prebuilt/repoxr/RepoXR.dll (рядом с RepoXR.Standalone, SteamShim, Android-ассетами
        │  RepoXR, скриптами и Unity-инструментами; файлов игры нет)
        ▼
zip набора
        │  scripts/build-mac.sh: сборщик на .NET 8, AssetRipper, RepoXR встраивается в код игры, Unity 6000.3.17f1
        ▼
APK на Quest
```

Патчи поверх RepoXR от DaXcess дают ровно исходники ПК-форка: в ПК-форке RepoXR разрабатывается и проверяется, а патч
`00NN` — это `git diff <предыдущий> <новый> -- Source` оттуда. Поэтому RepoXR.dll для Quest и RepoXR.dll из ПК-релиза —
один и тот же код (IL); ПК-архив только добавляет вокруг BepInEx.

**Зачем нужна ваша копия игры.** Мод компилируется по DLL самой игры (её код, Unity, Photon, Steamworks). RepoXR от
DaXcess скачивает их из NuGet (сервер пакетов для .NET), но там только R.E.P.O. 0.4.4 и Unity 2022. Патч 0033 переводит
проект RepoXR на вашу Windows-копию R.E.P.O. 0.5.0, а XR-библиотеки под Unity 6 берутся из релиза ПК-форка. Из NuGet
скачиваются только BepInEx и два маленьких инструмента сборки.

## 1. Что нужно

- Mac (или Linux) с `git`, `rsync`, `patch`, `curl`, `unzip`. На macOS git ставится командой `xcode-select --install`.
- **Windows-версия R.E.P.O. 0.5.0**: RepoXR компилируется по её коду. `scripts/build-mac.sh` при первом запуске
  скачивает её в `~/RepoQuest/game` (см. [build-mac.ru.md](build-mac.ru.md)); другая копия — `GAME=<папка с REPO_Data>`.
- **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** для шага 5 (сборщик APK): `scripts/build-mac.sh` сам ставит его в `~/.dotnet`.
- **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** для шагов 3–4: RepoXR написан на C# 14 (.NET 8 падает с `CS0106`). Если его нет ни в `~/.dotnet10`, ни в `~/.dotnet`, скрипт поставит его в
  `~/.dotnet10` (сборщик Quest держит свой .NET 8 в `~/.dotnet`). Или `DOTNET=<путь к dotnet>`.
- Интернет: NuGet (BepInEx, publicizer), GitHub (XR-пакеты Unity 6 из релиза alpha 6 ПК-форка, с проверкой SHA-256),
  dot.net, если SDK нужно поставить.

## 2. Код вместе с RepoXR от DaXcess

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr && git submodule update --init external/RepoXR
```

`external/RepoXR` — RepoXR от DaXcess версии 1.2.3 (коммит 15b4aec), как есть. (`external/RepoXR-Unity` нужен только
чтобы пересобрать Android-ассеты RepoXR, а для этого нужен Unity.)

## 3. Соберите RepoXR.dll

```bash
bash scripts/prepare-repoxr.sh
```

Скрипт копирует `external/RepoXR` в `work/repoxr-src`, по порядку накладывает `patches/repoxr/*.patch`, один раз
скачивает XR-пакеты Unity 6 в `work/downloads` и собирает с `-p:DebugSymbols=false`, как собираются релизы. Результат:

```
work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll
```

Её код совпадает с `prebuilt/repoxr/RepoXR.dll` из набора (для 1.0.7-qc27 проверено: IL всех методов одинаковый).
Побайтно файл совпадёт только на той же самой версии .NET SDK: новый компилятор может по-другому разложить пару методов.

## 4. Поменяйте RepoXR

Проще всего в ПК-форке — там же можно проверить на ПК:

1. Клонируйте [crimecock/RepoXR](https://github.com/crimecock/RepoXR) (ветка `repo-0.5.0`), поменяйте `Source/`, соберите
   и проверьте на ПК ([COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)).
2. Сделайте из своих коммитов следующий патч: `git diff <последний коммит из patches/repoxr> <ваш> -- Source >
   patches/repoxr/00NN-что-делает.patch` здесь и опишите его в шапке `scripts/prepare-repoxr.sh`.

Или прямо здесь, без ПК-форка: `scripts/repoxr-patch.sh start` даёт `work/repoxr-edit` (RepoXR со всеми патчами,
git-репозиторий), правите его `Source/`, потом `scripts/repoxr-patch.sh save <имя>` пишет следующий патч.

После этого снова `bash scripts/prepare-repoxr.sh`.

## 5. Соберите APK со своей DLL

```bash
REPOXR_DLL=$PWD/work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll CODE_ONLY=1 bash scripts/build-mac.sh
```

Скрипт берёт текущий набор, копирует его в `~/RepoQuest/kit-<версия>-custom` с вашей RepoXR.dll в `prebuilt/repoxr/` и
собирает APK из этой копии. `CODE_ONLY=1` берёт данные игры из вашей прошлой полной сборки (около 10 минут); если её не
было — сборка полная. Следующая сборка без `REPOXR_DLL` снова берёт DLL из набора.

Весь набор с нуля (ещё RepoXR.Standalone, SteamShim, libopus): [build-kit.ru.md](build-kit.ru.md).

## На Windows

`scripts/prepare-repoxr.sh` — bash-скрипт. На Windows ту же RepoXR.dll собирают из ПК-форка и отдают скрипту сборки:

1. Поставьте [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0) и распакуйте архив «всё в одном»
   ПК-форка в папку игры (сборке нужны его XR-библиотеки Unity 6).
2. Соберите: `git clone https://github.com/crimecock/RepoXR.git -b repo-0.5.0`, потом в этой папке
   `dotnet build RepoXR.sln -c Release -p:DebugSymbols=false -p:GamePath="<папка REPO>"`
   ([COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)). Мод правится там же, в `Source/`.
3. Соберите с ней APK, в папке этого репозитория:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -CodeOnly -RepoXRDll <папка RepoXR>\bin\Release\netstandard2.1\RepoXR.dll
```

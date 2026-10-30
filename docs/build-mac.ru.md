# Сборка на macOS

[English](build-mac.md) · **Русский**

`scripts/build-mac.sh` собирает R.E.P.O. 0.5.0 для Quest из вашей копии игры в Steam и ставит её в шлем. Этим скриптом
порт собирается и проверяется.

## Что нужно

- Mac (Apple Silicon или Intel), 16 ГБ ОЗУ, **около 60 ГБ свободного места** на диске с рабочей папкой (по умолчанию `~/RepoQuest`).
- **R.E.P.O.**, купленная в [Steam](https://store.steampowered.com/app/3241660/REPO/). Ставить её не нужно: скрипт
  скачает Windows-версию игры через `steamcmd`.
- **Meta Quest** (сделано и проверяется на Quest 3) в **режиме разработчика** и кабель USB-C с передачей данных.
- **Unity Hub** ([unity.com/download](https://unity.com/download)) и бесплатный аккаунт Unity.
- **Git**: `xcode-select --install` в Терминале ставит вместе с ним инструменты командной строки Apple. Или скачайте
  код ZIP-архивом (ниже).

**[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** (в `~/.dotnet`; для сборки APK нужен только .NET 8), **steamcmd** и **Rosetta 2** (steamcmd — программа для Intel; macOS спросит пароль)
скрипт поставит сам, если их нет. Всё остальное (AssetRipper, Python с пакетами, пакеты NuGet, встроенные шейдеры
Unity) сборщик скачает сам, каждое из первоисточника.

## 1. Установите Unity 6000.3.17f1 с Android

Поставьте [Unity Hub](https://unity.com/download) и войдите в аккаунт. Потом откройте в браузере ссылку (Unity Hub
откроется на нужной версии):

```
unityhub://6000.3.17f1/cf0352b38e81
```

В списке модулей отметьте **Android Build Support** и внутри него **OpenJDK** и **Android SDK & NDK Tools**, установите
(около 10 ГБ). Место установки оставьте по умолчанию (`/Applications/Unity/Hub/Editor/6000.3.17f1`) или потом укажите
скрипту `UNITY=`.

## 2. Скачайте код

В Терминале:

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
```

```bash
cd repo-quest-vr
```

Без Git: скачайте код ZIP-архивом — [repo-quest-vr-repo-0.5.0.zip](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) (то же, что **Code → Download ZIP** на странице репозитория; код этого форка, без файлов игры), распакуйте и перейдите в Терминале в папку `repo-quest-vr-repo-0.5.0` (`cd`). Обновиться потом — скачать архив заново (`git pull` работает только в клоне Git).

## 3. Подготовьте шлем

1. Включите **режим разработчика** для шлема в приложении Meta Horizon на телефоне: Устройства → ваш Quest → Настройки
   гарнитуры → Режим разработчика. Сначала Meta попросит вступить в организацию разработчика или создать свою
   (бесплатно); подробно — в [инструкции Meta](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/).
2. Подключите Quest к Маку по USB, наденьте шлем и разрешите **отладку по USB** (с галочкой «всегда разрешать с этого
   компьютера»).

## 4. Соберите

```bash
bash scripts/build-mac.sh
```

Скрипт:

1. проверяет Unity 6000.3.17f1 с Android (и открывает на ней Unity Hub, если её нет);
2. ставит .NET 8 SDK, если нужно;
3. скачивает набор порта из ветки `kit` этого форка и проверяет его SHA-256;
4. скачивает игру через `steamcmd` в `~/RepoQuest/game`. Один раз спросит **имя аккаунта** Steam (не почту), пароль и
   код Steam Guard — они уходят только в Steam. Около 2–3 ГБ. Первый запуск steamcmd обновляет сам себя и иногда
   останавливается — скрипт пробует ещё раз;
5. собирает сборщик и запускает его: распаковка AssetRipper, RepoXR встраивается в код игры, Unity-проект, Unity → APK;
6. ставит APK в шлем.

**Первая сборка — 1–1,5 часа**, следующие используют её работу и идут 20–40 минут. Пока идёт сборка, Мак не засыпает
(`caffeinate`).

Параметры:

| Параметр | Что делает |
|---|---|
| `GAME=/путь/к/REPO bash scripts/build-mac.sh` | Уже скачанная копия игры (папка с `REPO_Data`) |
| `UNITY=/путь/к/6000.3.17f1 bash scripts/build-mac.sh` | Папка Unity (с `Unity.app`), если она в другом месте |
| `REPOQUEST_HOME=/путь bash scripts/build-mac.sh` | Другая рабочая папка (путь латиницей без пробелов) |
| `bash scripts/build-mac.sh --no-install` | Только собрать; APK — в `~/RepoQuest/work/build` |
| `CODE_ONLY=1 bash scripts/build-mac.sh` | Поменялся только код (новый набор с новыми DLL или патчами): данные игры берутся из прошлого APK, около 10 минут вместо 35. Если прошлой сборки нет — полная |
| `REPOXR_DLL=<RepoXR.dll> bash scripts/build-mac.sh` | Своя RepoXR.dll вместо той, что в наборе ([build-repoxr.ru.md](build-repoxr.ru.md)) |
| `FORCE=1 bash scripts/build-mac.sh` | Собрать, даже если проверка новой версии игры нашла проблемы |

## 5. Играйте

В шлеме: **Библиотека → Неизвестные источники → R.E.P.O.** Одиночная игра работает сразу. Для мультиплеера войдите
в Steam кнопкой **Steam** в главном меню (про неофициальный клиент Steam — в README).

Настройки, мультиплеер, файлы в шлеме: [playing.ru.md](playing.ru.md). Управление: [controls.ru.md](controls.ru.md).

**Не делитесь APK**: в нём файлы игры. Каждый собирает свой.

## Обновление

```bash
git pull
```

Без Git: скачайте [код ZIP-архивом](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) заново и распакуйте поверх старой папки (рабочая папка `~/RepoQuest` с игрой и прошлой сборкой остаётся).

```bash
CODE_ONLY=1 bash scripts/build-mac.sh
```

Копия игры в `~/RepoQuest/game` сама не обновляется, так что обновление игры в Steam ничего не ломает, пока вы её не
удалите. Подробно: [updating.ru.md](updating.ru.md).

## Частые проблемы

| Проблема | Что делать |
|---|---|
| `Unity ... not found` | Установите её (шаг 1) или укажите `UNITY=` |
| `Unity has no Android Build Support` | Unity Hub → Installs → 6000.3.17f1 → Add modules → Android Build Support (с OpenJDK и Android SDK & NDK Tools) |
| `the work folder must be an ASCII path` | Укажите `REPOQUEST_HOME=` с путём вроде `~/RepoQuest` |
| `R.E.P.O. did not download` | Запустите скрипт ещё раз (steamcmd часто нужна вторая попытка) или укажите `GAME=` |
| `no headset` или `install failed` после сборки | APK собран, поставьте его вручную: [install.ru.md](install.ru.md) (подключение, ошибки `INSTALL_FAILED_…`, переустановка без потери сохранений) |
| Сборка остановилась с ошибкой | Логи — в `~/RepoQuest/work/logs`; после исправления запустите скрипт снова, готовые шаги пропускаются |

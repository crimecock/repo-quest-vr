# R.E.P.O. VR на Quest без ПК — перенос на R.E.P.O. 0.5.0 (Unity 6)

[English](README.md) · **Русский**

Это форк **[repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr)** от [Dobutsu](https://github.com/Dobutsu). Проект
запускает [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/) в VR прямо на Meta Quest, без компьютера, на
основе VR-мода **[RepoXR](https://github.com/DaXcess/RepoXR)** от [DaXcess](https://github.com/DaXcess).

Оригинальный порт (1.0.7) поддерживает R.E.P.O. **0.4.4.3** на Unity 2022.3. Steam сейчас раздаёт **0.5.0**, которая
перешла на **Unity 6000.3**, и сборщик автора останавливается на экспорте. Этот форк переносит весь порт на 0.5.0 и
добавляет настройки производительности.

> **Статус: тестирование.** Сборка 0.5.0 проходит от начала до APK, проверка на Quest 3 идёт. О проблемах этого форка
> пишите [сюда](../../issues), а не Dobutsu или DaXcess.

Игра собирается **из вашей собственной копии R.E.P.O.** из Steam. В репозитории и релизах нет файлов игры.
**Не делитесь собранным APK**: в нём файлы игры.

## Что меняет форк

**Поддержка R.E.P.O. 0.5.0**
- **RepoXR** ([`patches/repoxr/0009-repo-0.5.0.patch`](patches/repoxr/0009-repo-0.5.0.patch), поверх RepoXR 1.2.3 и
  патчей порта 0001–0008): в 0.5.0 переименовано или перенесено многое из того, что патчит RepoXR (новые перегрузки,
  страница ввода текста, `KeyType`, руление транспортом и снегоходом, теги глифов, лазание). Клики в меню теперь идут
  через `InputKey.UIClick`, на который отвечает курок VR-луча.
- **Сборщик и Unity**: Unity 6000.3.17f1; настройки плеера, которые AssetRipper
  не читает из 0.5.0, восстанавливаются из `globalgamemanagers` игры (гамма-цвет, оба обработчика ввода, предзагрузка
  настроек Input System и Localization).
- **Пакеты** подобраны по DLL игры: Input System 1.19.0, uGUI 2.0.0 (с TextMeshPro), Localization 1.5.12,
  Addressables 2.9.1, PostProcessing 3.5.4 и другие.
- **Бинарный каталог Addressables 2.x** (`catalog.bin`): косметика и все языки пересобираются под Android.
- **Звук**: AssetRipper 2.0.0 пишет все WAV с нулевыми размерами чанков, Unity 6 их не декодирует — заголовки
  исправляются.
- **SteamShim**: API Steam, которые 0.5.0 вызывает при запуске и в лобби (`SteamApps.CurrentBetaName`, прогресс
  достижений, клавиатура геймпада).
- **Вход в Steam в шлеме** — через страницу ввода текста из 0.5.0.

**Производительность** (на Quest игра упирается в процессор)
- **Отсечение отрисовки уровня**: мелочь дальше 20 м и всё, что скрыто туманом, не рисуется. Только картинка: объекты
  продолжают работать, мультиплеер не затронут. Настройки в игре: *Настройки → VR Settings → Rendering*
  (Level Culling, Small Object Distance, Room Distance).
- Генерация кода **IL2CPP Master**.
- **Процессор и видеочип на SUSTAINED_HIGH** с начала каждой сессии (`XR_EXT_performance_settings`).

Подробности: [`docs/repo-0.5.0.ru.md`](docs/repo-0.5.0.ru.md). Управление: [`docs/controls.ru.md`](docs/controls.ru.md).

## Как собрать

Нужны R.E.P.O. 0.5.0 в Steam, **Unity 6000.3.17f1** с Android Build Support (OpenJDK, Android SDK & NDK), .NET 8 SDK,
около 60 ГБ свободного места и Quest в режиме разработчика с USB-кабелем.

### macOS

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
bash scripts/build-mac.sh
```

Скрипт скачает набор порта из [ветки `kit`](../../tree/kit) этого форка, игру через `steamcmd` (один раз спросит логин
Steam; пароль уходит только в Steam), соберёт сборщик и APK и поставит его в шлем. Первая сборка — 1–1,5 часа.
`GAME=/путь/к/REPO` — для уже скачанной копии, `--no-install` — только собрать.

### Windows

Оконный сборщик автора содержит набор 1.0.7 и 0.5.0 собрать не может. В PowerShell, в папке с путём латиницей без
пробелов:

```powershell
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

Пошаговая инструкция — подготовка шлема, параметры, частые проблемы: [`docs/build-windows.ru.md`](docs/build-windows.ru.md).

### Любая ОС с .NET 8

Консольный сборщик и распакованный набор из [ветки `kit`](../../tree/kit):

```
dotnet run -c Release --project builder/QuestBuilder.Cli -- build --kit <распакованный набор> --game <папка с REPO_Data> --workspace <рабочая папка> --unity <папка Unity 6000.3.17f1> --headset quest
```

## Когда R.E.P.O. обновляется

Скрипты сборки замечают версию игры, с которой набор не проверялся, и сначала проверяют её — за минуты и без Unity
(`QuestBuilder.Cli check`): если патчи RepoXR, клиент Steam или пакеты больше не подходят, они останавливаются с
отчётом. Что делать дальше и как выпускается релиз: [`docs/updating.ru.md`](docs/updating.ru.md). Релизы:
[`CHANGELOG.md`](CHANGELOG.md).

## Steam в шлеме

Для игры по сети вход в Steam делается в самой игре, кнопкой **Steam** в главном меню. Шлем общается со Steam напрямую
через [SteamKit2](https://github.com/SteamRE/SteamKit) — неофициальный клиент Steam. Соглашение подписчика Steam не
разрешает сторонние клиенты. Риск для аккаунта небольшой, но он есть. Одиночная игра работает без входа.

## Лицензия и права

Неофициальный фанатский проект, не связанный с semiwork (R.E.P.O.), DaXcess (RepoXR), Dobutsu, Valve или Meta.
R.E.P.O. и её ассеты принадлежат semiwork. В репозитории только код порта; каждый собирает игру из своей копии.

Лицензия **GNU GPL v3.0** ([LICENSE](LICENSE)), как у оригинального порта и RepoXR.

## Благодарности

- **[Dobutsu](https://github.com/Dobutsu)** — [repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr), порт на Quest,
  на котором основан этот форк ([ko-fi](https://ko-fi.com/dobutsu)).
- **[DaXcess](https://github.com/DaXcess)** — [RepoXR](https://github.com/DaXcess/RepoXR) и
  [RepoXR-Unity](https://github.com/DaXcess/RepoXR-Unity), VR-мод, на котором построено всё.
- **semiwork** — [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/)
- [SteamKit2](https://github.com/SteamRE/SteamKit), [AssetRipper](https://github.com/AssetRipper/AssetRipper),
  [BepInEx](https://github.com/BepInEx/BepInEx), [HarmonyX](https://github.com/BepInEx/HarmonyX),
  [Opus](https://opus-codec.org/), зеркала пакетов [needle-mirror](https://github.com/needle-mirror).
- Перенос на 0.5.0 — **[crimecock](https://github.com/crimecock)**, сделано с
  [Claude Code](https://claude.com/claude-code).

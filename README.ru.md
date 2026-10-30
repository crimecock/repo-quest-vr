# R.E.P.O. VR на Quest без ПК — перенос на R.E.P.O. 0.5.0 (Unity 6)

[English](README.md) · **Русский**

Это форк **[repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr)** от [Dobutsu](https://github.com/Dobutsu). Проект
запускает [R.E.P.O.](https://store.steampowered.com/app/3241660/REPO/) в VR прямо на Meta Quest, без компьютера, на
основе VR-мода **[RepoXR](https://github.com/DaXcess/RepoXR)** от [DaXcess](https://github.com/DaXcess).

Оригинальный порт (1.0.7) поддерживает R.E.P.O. **0.4.4.3** на Unity 2022.3. Steam сейчас раздаёт **0.5.0**, которая
перешла на **Unity 6000.3**, и сборщик автора останавливается на экспорте. Этот форк переносит весь порт на 0.5.0 и
добавляет настройки производительности.

> [!TIP]
> **Играете на ПК?** Тот же код RepoXR, перенесённый на 0.5.0, — мод BepInEx для Windows-версии игры:
> **[crimecock/RepoXR](https://github.com/crimecock/RepoXR)** (ветка `repo-0.5.0`) —
> [релизы](https://github.com/crimecock/RepoXR/releases) (архив «всё в одном»), [установка](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/README.ru.md),
> [управление на ПК](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/controls.ru.md).

## Благодарности

Спасибо авторам, на чьей работе стоит этот порт:

- **[Dobutsu](https://github.com/Dobutsu)** — [repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr), порт на Quest,
  на котором основан этот форк ([ko-fi](https://ko-fi.com/dobutsu)).
- **[DaXcess](https://github.com/DaXcess)** — [RepoXR](https://github.com/DaXcess/RepoXR) и
  [RepoXR-Unity](https://github.com/DaXcess/RepoXR-Unity), VR-мод, на котором построено всё.
- [SteamKit2](https://github.com/SteamRE/SteamKit), [AssetRipper](https://github.com/AssetRipper/AssetRipper),
  [BepInEx](https://github.com/BepInEx/BepInEx), [HarmonyX](https://github.com/BepInEx/HarmonyX),
  [Opus](https://opus-codec.org/), зеркала пакетов [needle-mirror](https://github.com/needle-mirror).
- Перенос на 0.5.0 — **[crimecock](https://github.com/crimecock)**, сделано с
  [Claude Code](https://claude.com/claude-code).

> **Статус: всё работает (1.0.7-qc27).** Сборка 0.5.0 проходит от начала до APK. На Quest 3 сборка 1.0.7-qc21 играется: меню,
> вход в Steam в шлеме, одиночное лобби и уровни (трекинг головы, лучи, захват), и **мультиплеер работает**.
> 1.0.7-qc22 (патч [`0029`](patches/repoxr/0029-whip-result-screen-aim-news-popup.patch)) приносит исправления,
> проверенные на ПК: щелчок и бросок хлыстом взмахом контроллера, переход уровень → магазин больше не зависает на
> экране итогов, новость в главном меню больше не плашками. 1.0.7-qc23 (патч
> [`0030`](patches/repoxr/0030-settings-menus-controller-icons-text-tags.patch), alpha 4 ПК-форка) чинит меню настроек:
> значки контроллера вместо `?`, `[move]` в обучении, переключатели, кнопка *VR Settings*. 1.0.7-qc24 (патч
> [`0031`](patches/repoxr/0031-shop-mirror-toggles.patch), alpha 5) чинит зеркало в магазине и переключатели в VR
> Settings. На Quest зеркало по умолчанию скрыто ([почему](docs/playing.ru.md#зеркало-в-магазине)). 1.0.7-qc27 (патч
> [`0032`](patches/repoxr/0032-tutorial-texts-quest-controller-scheme-render-mode.patch), alpha 6): на Quest 3 работает
> страница управления (было *DISCONNECTED*), *Render Mode* в VR Settings → Rendering, VR-тексты обучения на английском. **Всё
> работает**: проверено на ПК, а Quest собирает тот же самый код RepoXR. О проблемах этого форка пишите [сюда](../../issues), а не Dobutsu или DaXcess.

> **Обновление:** поверх qc24 для qc27 хватит сборки только кода (около 6 минут, данные игры берутся из прошлой
> полной сборки). Поверх прошлого публичного релиза qc2 нужна полная сборка — см. [docs/updating.ru.md](docs/updating.ru.md#обновление-на-новую-сборку-форка).

### Известные проблемы

Всё работает: проверено на ПК, а Quest собирает тот же код. Одна мелочь: **страница «Язык»** (*Настройки → Язык*) в VR показывает только Text to Speech — кнопки языков оказываются за пределами меню. Исправление готово и придёт со следующей сборкой. Полезно знать:

- **Зеркало в магазине на Quest скрыто, так задумано**: при single-pass (по умолчанию на Quest) оба глаза делили бы
  одно отражение. С *VR Settings → Rendering → Render Mode* = Multipass работает, но ценой FPS ([подробно](docs/playing.ru.md#зеркало-в-магазине)).
- Хлыст бросает, только когда что-то поймал; чувствительность — в VR Settings → Input → *Whip Sideways / Crack
  Sensitivity*.

Подробности: [docs/playing.ru.md](docs/playing.ru.md#известные-проблемы).

### Управление

| Контроллер Quest | В игре |
|---|---|
| Левый стик · нажать · зажать | Ходьба · чат · колесо эмоций |
| Левый курок · левый grip | Бег · вращать предмет в руке |
| **≡ (кнопка меню слева)** · X · Y | **Меню** · выключить микрофон · сбросить рост |
| Правый стик влево/вправо · вверх/вниз · нажать | Поворот · оттолкнуть/притянуть, прокрутка · присесть |
| **Правый курок** | **Схватить** (луч), нажать в меню, сесть/слезть с техники |
| Правый grip | Взаимодействовать, выстрел, гудок |
| A · B | Прыжок · кувырок |

Карта у плеча (grip), фонарь у головы, инвентарь, оружие, хлыст, техника, лазание в кувырке:
[docs/controls.ru.md](docs/controls.ru.md). Переназначить — *Настройки → Управление*; там же можно дать кнопки
свободным действиям (Inventory 1–3, Expression 1–6, Push To Talk).

Игра собирается **из вашей собственной копии R.E.P.O.** из Steam. В репозитории и релизах нет файлов игры.
**Не делитесь собранным APK**: в нём файлы игры.

## Что меняет форк

**Поддержка R.E.P.O. 0.5.0** — что каждая новинка 0.5.0 делает в VR (геймпад, языки, косметика, новый уровень,
колесо эмоций, автоудержание предметов, лазание, техника...) и её статус: [`docs/repo-0.5.0.ru.md`](docs/repo-0.5.0.ru.md#новое-в-repo-050-и-как-оно-работает-в-vr)
- **RepoXR** ([`patches/repoxr/0009-repo-0.5.0.patch`](patches/repoxr/0009-repo-0.5.0.patch), поверх RepoXR 1.2.3 и
  патчей порта 0001–0008): в 0.5.0 переименовано или перенесено многое из того, что патчит RepoXR (новые перегрузки,
  страница ввода текста, `KeyType`, руление транспортом и снегоходом, теги глифов, лазание). Клики в меню теперь идут
  через `InputKey.UIClick`, на который отвечает курок VR-луча, а патч
  [`0010`](patches/repoxr/0010-vr-menus-0.5.0.patch) держит их в режиме указателя (поддержка геймпада в 0.5.0 иначе
  навсегда переводит их в навигацию с клавиатуры). [`0011`](patches/repoxr/0011-menu-hover-scale-0.5.0.patch) задаёт кнопкам
  зону наведения под мировое меню, [`0012`](patches/repoxr/0012-xr-ui-input-module.patch) делает модуль ввода лучей
  тем, который запускает EventSystem. [`0019`](patches/repoxr/0019-grab-vehicles-menu-button-fps.patch) чинит захват и
  технику на 0.5.0, переносит меню паузы на кнопку меню левого контроллера (X выключает микрофон) и добавляет
  счётчик FPS; [`0020`](patches/repoxr/0020-guns-and-grab-release-from-hand.patch) — прицеливание пушек от руки.
- **Захват** (работает на Quest и на ПК): *Item Unequip Auto Hold* из 0.5.0 перенёс отпускание захвата-переключателя
  из `PhysGrabber.Update` в `GrabInputActiveGet`. `ForceHoldPatch` RepoXR потерял якорь и вписывал вызов в задержку
  захвата — луч захвата не включался никогда; `0019` патчит новый метод и падает, если якоря нет (`check` сборщика
  теперь сообщает о каждом потерянном якоре). `0020` берёт принудительный захват и отпускание после вращения от руки
  (повёрнутый предмет раньше прыгал), `0009` поворачивает переделанное лазание в кувырке рукой (`ClimbTargetUpdate`;
  проверено на ПК). Таблица: [захват — что сломалось и как починили](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/docs/repo-0.5.0.ru.md#захват-что-сломалось-и-как-починили).
- **Хлыст, магазин, новость** ([`0029`](patches/repoxr/0029-whip-result-screen-aim-news-popup.patch), проверено на
  ПК): RepoXR пропускает обновление прицела камеры игры, а с ним и таймер, который снимает принудительный поворот
  камеры, — один такой оставался навсегда и выключал жесты хлыста; теперь таймеры идут, а пока держишь хлыст, жесты
  читают скорость поворота руки (резко назад и вперёд — щелчок, и из-за плеча тоже; VR Settings → Input → *Whip
  Sideways/Crack Sensitivity*). При передаче сцены старый VR-экран загрузки затирал ссылку на новый, и переход
  уровень → магазин зависал на экране итогов. Попап новости вырастает из нуля, и его слова выходили плашками; его
  тексты теперь перестраиваются, когда он вырос.
- **Методы движка Unity 6**: в Unity 6 методы движка вроде `Camera.set_targetTexture` стали управляемым кодом;
  встраиватель теперь перехватывает их в местах вызова, как раньше extern. Без этого игра рисовала в свою маленькую
  текстуру, а в шлеме был чёрный мир со шлейфами.
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

Подробности: [`docs/repo-0.5.0.ru.md`](docs/repo-0.5.0.ru.md). Игра в шлеме (настройки VR, мультиплеер, файлы, что
прислать, если что-то не так): [`docs/playing.ru.md`](docs/playing.ru.md). Управление: [`docs/controls.ru.md`](docs/controls.ru.md).

## Как собрать

**Поставить самому, один раз:**

| Что | Где | macOS | Windows |
|---|---|---|---|
| R.E.P.O. 0.5.0 | [Steam](https://store.steampowered.com/app/3241660/REPO/) | достаточно купить: Windows-версию скрипт скачает через `steamcmd` | установлена в Steam (скрипт найдёт её сам) |
| Unity Hub и бесплатный аккаунт Unity | [unity.com/download](https://unity.com/download) | ✓ | ✓ |
| Unity **6000.3.17f1** с **Android Build Support** (галочки **OpenJDK** и **Android SDK & NDK Tools**) | откройте в браузере `unityhub://6000.3.17f1/cf0352b38e81` — Unity Hub откроется на этой версии (скрипты тоже открывают его, если Unity нет) | ✓ | ✓ |
| Git (или код [ZIP-архивом](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip)) | macOS: `xcode-select --install`; Windows: [Git для Windows](https://git-scm.com/download/win) | ✓ | ✓ |
| Режим разработчика на Quest | приложение Meta Horizon на телефоне, см. [инструкцию Meta](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/) | ✓ | ✓ |

И ещё около 60 ГБ свободного места и кабель USB-C с передачей данных.

**Остальное скрипты скачают сами:** .NET 8 SDK (если его нет), набор порта из этого форка (с проверкой SHA-256), на
macOS — `steamcmd` с Rosetta 2 и саму игру; дальше сборщик скачивает AssetRipper, Python с пакетами, пакеты NuGet и
встроенные шейдеры Unity, каждое из первоисточника. `adb` для установки в шлем есть в Android-модуле Unity.

### macOS

```bash
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
bash scripts/build-mac.sh
```

Без Git: распакуйте [код ZIP-архивом](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) и запустите скрипт из папки `repo-quest-vr-repo-0.5.0`.

Скрипт скачает набор порта из [ветки `kit`](../../tree/kit) этого форка, игру через `steamcmd` (один раз спросит логин
Steam; пароль уходит только в Steam), соберёт сборщик и APK и поставит его в шлем. Первая сборка — 1–1,5 часа.
`GAME=/путь/к/REPO` — для уже скачанной копии, `--no-install` — только собрать.
`CODE_ONLY=1` пересобирает в последний APK только код (новый набор, где поменялись DLL или патчи, а не ассеты): Unity
не перепаковывает данные игры — это две трети сборки, — и выходит около 10 минут вместо 35.

По шагам, с параметрами и частыми проблемами: [`docs/build-mac.ru.md`](docs/build-mac.ru.md). Если установка в шлем не прошла или нужно поставить сборку вручную: [`docs/install.ru.md`](docs/install.ru.md).

### Windows

Оконный сборщик автора содержит набор 1.0.7 и 0.5.0 собрать не может. В PowerShell, в папке с путём латиницей без
пробелов:

```powershell
git clone https://github.com/crimecock/repo-quest-vr.git
cd repo-quest-vr
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

Без Git: распакуйте [код ZIP-архивом](https://github.com/crimecock/repo-quest-vr/archive/refs/heads/repo-0.5.0.zip) и запустите скрипт из папки `repo-quest-vr-repo-0.5.0`.

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
[`CHANGELOG.ru.md`](CHANGELOG.ru.md).

## Steam в шлеме

Для игры по сети вход в Steam делается в самой игре, кнопкой **Steam** в главном меню. Шлем общается со Steam напрямую
через [SteamKit2](https://github.com/SteamRE/SteamKit) — неофициальный клиент Steam. Соглашение подписчика Steam не
разрешает сторонние клиенты. Риск для аккаунта небольшой, но он есть. Одиночная игра работает без входа.

## Лицензия и права

Неофициальный фанатский проект, не связанный с semiwork (R.E.P.O.), DaXcess (RepoXR), Dobutsu, Valve или Meta.
R.E.P.O. и её ассеты принадлежат semiwork. В репозитории только код порта; каждый собирает игру из своей копии.

Лицензия **GNU GPL v3.0** ([LICENSE](LICENSE)), как у оригинального порта и RepoXR.

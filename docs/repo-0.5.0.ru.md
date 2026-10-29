# Перенос на R.E.P.O. 0.5.0 (Unity 6000.3)

[English](repo-0.5.0.md) · **Русский**

## Цепочка

Сборщик — `builder/QuestBuilder.Cli` (.NET 8). Он идёт по шагам и запоминает каждый в `state.json` рабочей папки: если входы шага не менялись, шаг повторно не выполняется.

1. **export** — AssetRipper 2.0.0 (без окна, через свой локальный веб-API) распаковывает игру в Unity-проект `work/export/ExportedProject`. Шейдеры в нём — заглушки, код игры — готовые DLL.
2. **bake** — HarmonyBaker встраивает Harmony-патчи RepoXR прямо в DLL игры (`work/baked`). Причина: на Quest код собирается IL2CPP в C++, а там патчить методы во время работы нельзя. Сюда же ложатся «замены» из RepoXR.Standalone (`[Replaces]`): Discord, окно, MetaManager.Start и другие.
3. **project** — Python-скрипты превращают экспорт в проект для Quest:
   - пакеты вместо DLL (`package_swap.py`);
   - переименование сборок игры в `REPO.Game`;
   - восстановление GUID и имён Resources;
   - рабочие шейдеры вместо заглушек (`shader_states.py` + `generate_shaders.py`);
   - XR-пакеты, правки исходников Input System, uGUI и PostProcessing (`patch_packages.py`);
   - лампы одним проходом;
   - RepoXR, SteamShim, libopus.
4. **unity** — два запуска Unity в batchmode: `QuestBuild.Prepare` (настройки, Addressables, XR), затем `QuestBuild.BuildApk` (контент Addressables, затем APK: IL2CPP ARM64, Vulkan, OpenXR).

## Что изменилось в R.E.P.O. 0.5.0 и что сделано

| Что в 0.5.0 | Последствие | Что сделали |
|---|---|---|
| Unity 6000.3.17f1 вместо 2022.3.62f3 | Проект нужно собирать в Unity 6 | `kit.json`: Unity 6000.3.17f1 (cf0352b38e81). Встроенные шейдеры Unity 6 качаются с CDN Unity без закреплённого хеша, хеш пишется в лог |
| AssetRipper не читает PlayerSettings («Read 944 but expected 948 for asset type 129») | Нет `ProjectSettings.asset`: сборщик считал экспорт неудачным («no project in the export folder»), а Unity создала бы настройки по умолчанию | Признак готового экспорта теперь `ProjectVersion.txt` + `TagManager.asset`. `QuestBuild.RestoreGameSettings` возвращает то, что прочитано из `globalgamemanagers`: semiwork/REPO, **гамма**-цвет, оба обработчика ввода (activeInputHandler 2), предзагрузку InputSystem_Actions, InputSystem.inputsettings и Localization Settings, профиль API .NET Framework |
| Новые версии пакетов | Код игры собран против них | Версии подобраны сравнением типов DLL игры с исходниками каждой версии (needle-mirror на GitHub) и мелкими отличиями между ними — список в `scripts/package_swap.py` |
| TextMeshPro внутри uGUI 2.0 (Unity 6) | Отдельного пакета TMP нет | `Unity.TextMeshPro.dll` и `Unity.InternalAPIEngineBridge.004.dll` заменяются встроенным uGUI 2.0.0. `patch_packages.py` находит `Button.cs` по новому пути |
| Addressables 2.9.1: каталог `catalog.bin` | `catalog.json` рядом — устаревший (1363 id против актуальных; нет косметики и половины языков) | Декодер `BinaryStorageBuffer` в `addressables_catalog.py`; `GameInstall.AddressablesCatalog` выбирает `catalog.bin`, если его называет `settings.json` |
| Addressables 2.x читает только бинарные каталоги | Каталог ассетов RepoXR (`catalog_0.1.json`, собран Addressables 1.x) не загрузится | Символ `ENABLE_JSON_CATALOG`: оба каталога в JSON |
| Косметика в бандлах по меткам (`cosmetics_assets_cosmetics-arms`) | — | `AddressablesRestore`: одна группа на метку |
| Платформенный слой: `SteamPlatform.Initialise` и лобби зовут `SteamApps.CurrentBetaName` | В SteamShim такого не было: исключение при старте и при создании лобби | SteamShim: `SteamApps` (`null`, как на основной ветке Steam), `SteamUserStats.IndicateAchievementProgress`, клавиатура геймпада Steam (говорит «нет клавиатуры», игра остаётся на своей) |
| Нет `MenuPageSavesRename` | Страница входа в Steam строилась из неё | `MenuTextPage` строится из `MenuPagePopUpTextInput` (`MenuPageIndex.PopUpTextInput`) |
| `MetaManager.Start` без `GenerateIcons` (иконки готовые, в Addressables) | — | `CosmeticsCloud.StartAfterSync` повторяет новый Start |
| `PlayerLocalCamera.OnPhotonSerializeView` хранит `CameraAim.Instance` в типизированной локальной переменной | Патч, отправляющий VR-камеру вместо прицела, клал туда `this` (PlayerLocalCamera); clang отказался компилировать C++ от IL2CPP | Локальная остаётся CameraAim, только два чтения transform берут transform PlayerLocalCamera |
| Меню кликают через `InputKey.UIClick`, а не `Input.GetMouseButtonDown` | Патчи мыши RepoXR в 5 методах меню ничего не находят: в VR кнопки не нажимались бы | `KeyDown`/`KeyHold`/`KeyUp` отвечают на UIClick курком VR-луча |
| Поворот лазания в кувырке перенесён из `GrabStateClimb` в `ClimbTargetUpdate` | Транспайлер испортил конец `GrabStateClimb`, IL2CPP отказался собирать | Патч перенесён в `ClimbTargetUpdate`, падает, если не нашёл место |
| AssetRipper 2.0.0 пишет WAV с нулевыми размерами чанков | Unity 6 не декодирует все 3417 звуков | `fix_wav_headers.py` после копии экспорта |
| `InputKey.Confirm` → `UIClick` и другие переименования | Патчи RepoXR не применялись (16 классов) | Патч `0009-repo-0.5.0.patch`, см. CODE-MAP |

## Оптимизация

Игра упирается в процессор (по замерам автора около 18 мс CPU против 12 мс GPU на кадр при 72 Гц), поэтому всё направлено на CPU:
- **IL2CPP Master** (`QuestBuild.ConfigurePlayer`): полная оптимизация C++ с LTO. Сборка идёт на несколько минут дольше;
- **SUSTAINED_HIGH** (`unity-tools/Runtime/PerfXr.cs`): OpenXR-фича с XR_EXT_performance_settings теперь добавляется при каждом запуске на Android. В `OnSessionBegin` она ставит CPU и GPU на SUSTAINED_HIGH. Выключить: пустой файл `perf-levels-off` в `/sdcard/Android/data/io.repoxr.quest/files/`. Результат пишется в logcat: `[RepoQuest] PerfXr: …`.

- **LevelCulling** (`unity-tools/Runtime/LevelCulling.cs`). R.E.P.O. собирает уровни из модулей во время игры, поэтому кроме пирамиды камеры ничего не отсекается: запечённого occlusion culling нет, дистанций отсечения нет. На встроенном пайплайне каждый нарисованный рендерер — работа потока рендера. После генерации уровня (`LevelGenerator.Generated`, через 2 с, чтобы успели появиться пропы и предметы) скрипт собирает MeshRenderer и SkinnedMeshRenderer модулей, остальных детей `LevelParent` и `ItemParent`. Врагов и игроков он не трогает. Каждый кадр он проверяет до 400 рендереров по их текущим границам:
  - мелочь (диагональ < `size`, 1,5 м) дальше `small` (20 м) прячется;
  - всё, что дальше `far` (0 = дистанция тумана по `RenderSettings`, где туман закрывает 254/255 цвета), прячется;
  - показывается снова на 1,5 м ближе (гистерезис);
  - раз в 4 кадра один корень пересканируется: появившееся, разбитое, унесённое.

  Используется только `forceRenderingOff`: GameObject активен, скрипты, физика и Photon работают, у других игроков ничего не меняется. Игра сама ставит этот флаг только щупальцам врагов. Уже выключенное игрой скрипт не трогает и включает только то, что выключил сам. Исключение в нём показывает всё обратно и выключает скрипт. Настройки — в меню игры (Настройки → VR Settings → Rendering): Level Culling, Small Object Distance (10–60 м), Room Distance (0–100 м, 0 = по туману). Это записи конфига RepoXR (патч 0009); `LevelCulling` читает их через reflection раз в секунду. `culling.txt` (`small=`, `size=`, `far=`, `off`) перекрывает их — для тестов.

  Дальше, после замеров: объединять неподвижную геометрию модулей (`StaticBatchingUtility.Combine`; меши модулей нужно делать Readable, это память) и отсечение по комнатам (`far=` поменьше).

От автора остались: multiview + симметричная проекция, без постобработки, лампы одним проходом, graphics jobs (Legacy), инкрементальный GC.

Не подходит:
- Application SpaceWarp: в Unity он только для URP, а игра на встроенном пайплайне;
- фовеальный рендеринг: разгружает только GPU.

Самое действенное без кода — быть клиентом у ПК-хоста.

## Чем проверено без Unity

Скрипты прогнаны на экспорте и данных 0.5.0:
- `addressables_catalog.py`: 712 записей, все пути есть в экспорте;
- `package_swap.py --dry-run` без uGUI: 496 классов, 24 шейдера, 12 compute, 0 неразрешённых ссылок;
- `shader_states.py`: 143 шейдера;
- `generate_shaders.py`: 82 шейдера;
- `restore_resource_names.py`: исправлен на одной пустой ссылке в 0.5.0.

Проверка ссылок (свой инструмент на Mono.Cecil) против DLL 0.5.0:
- Assembly-CSharp → новый SteamShim: 0 неразрешённых;
- RepoXR.Standalone: 0;
- результат встраивания: 0 (кроме CustomDiscoverStateLib, чью сборку инструмент не нашёл по имени файла).

Встраивание: 81 класс патчей, 1 пропущен, 0 ошибок; все 14 замен Standalone применены.

## Проверка встраивания без Unity

IL2CPP узнаёт о плохом IL только через 40 минут сборки, поэтому результат встраивания проверяется заранее инструментом `tools/IlCheck` (Mono.Cecil):
- `IlCheck stack <dll>...` — глубина стека по всем путям каждого метода, то, что IL2CPP называет «invalid IL»;
- `IlCheck diff <оригинал> <после встраивания>` — что поменялось в каждом методе относительно игры. Цель транспайлера без изменений — молча не сработавший патч; изменение в самом конце метода после `Advance(-N)` — подозрительно;
- `IlCheck types <dll>... --search <папка>` — значения-классы, которые кладутся в локальные переменные и поля, и `this` вызовов против объявленных типов. C++ от IL2CPP типизирован, и clang не пропускает то, что принял бы CLR.

## Риски

- **Unity-код** (`unity-tools/Editor`, `EditorXR`, `Runtime`) не компилировался: на Linux нет UnityEditor. Ошибки увидим в `unity-prepare.log`.
- **OpenXR 1.14.3 и XRI 2.6.4** под Unity 6.3 не проверены. RepoXR собран против этих версий, менять их нельзя без пересборки RepoXR.
- **Бандл ассетов RepoXR** (`prebuilt/repoxr-android`) собран в Unity 2022.3. Данные Unity 6 читает, шейдеры могут не подойти. Если руки, лучи или меню RepoXR невидимые или розовые — пересобрать бандл в Unity 6 (`scripts/build-repoxr-assets.sh` + RepoXR-Unity).
- Два ассета Localization Settings в экспорте (`Localization Settings.asset` и `_0`) отличаются PreloadBehavior и UseFallback. Берётся первый, как у автора.

# Выпуск новой версии (обе репы)

[English](releasing.md) · **Русский**

Для тех, кто поддерживает форк. RepoXR меняется и проверяется в ПК-форке ([crimecock/RepoXR](https://github.com/crimecock/RepoXR),
ветка `repo-0.5.0`) и приходит сюда патчем, поэтому обычный выпуск (исправление в RepoXR) затрагивает обе репы:
сначала ПК-релиз (alpha N), потом набор Quest (1.0.7-qcNN) с тем же кодом. Если поменялась только цепочка Quest
(скрипты, сборщик), часть A не нужна.

## Где живёт версия

| Что | ПК-форк | Эта репа (Quest) |
|---|---|---|
| Имя релиза и тег | `v1.2.3-repo0.5.0-alpha.N` | `v1.0.7-qcNN` |
| Журнал изменений | `CHANGELOG.md`: `# Unreleased` → `# 1.2.3-repo0.5.0-alpha.N (unofficial fork)` | `CHANGELOG.md` / `CHANGELOG.ru.md`: `## Unreleased` / `## Готовится` → `## 1.0.7-qcNN` |
| Что скачивают игроки | два архива релиза | ветка `kit`: `repoquest-kit-1.0.7-qcNN.zip`, `SHA256SUMS`, её README |
| Прописано в коде | README: прямая ссылка на архив «всё в одном» | `scripts/build-mac.sh` `VERSION`, `KIT_SHA`; `scripts/build-windows.ps1` `$Version`, `$KitSha` |
| Тексты о состоянии | README (таблица состояния, известные проблемы), `docs/repo-0.5.0` | README (статус, «Что меняет форк»), `docs/playing` (известные проблемы), `docs/updating` (пример) |
| Не меняется | `Plugin.PLUGIN_VERSION = "1.2.3"` (версия самого RepoXR) | `kit.json` в `builder/` (версию набор получает при сборке) |

## A. ПК-релиз (alpha N)

1. **Поменять и проверить**: правите `Source/`, собираете
   (`dotnet build RepoXR.sln -c Release -p:DebugSymbols=false -p:GamePath=…`, [COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)),
   кладёте DLL в игру и играете.
2. **Документация**: в `CHANGELOG.md` переименовать `# Unreleased` в `# 1.2.3-repo0.5.0-alpha.N (unofficial fork)`;
   обновить README (таблица состояния, известные проблемы, прямая ссылка на `…-alpha.N-all-in-one.zip`) и, если решена
   новая проблема, строку в таблице `docs/repo-0.5.0(.ru).md` (что изменилось в 0.5.0, что сломалось, как исправлено).
   Коммит и пуш.
3. **Архивы**: `python3 tools/package/make_release.py alpha.N` → `dist/RepoXR-repo0.5.0-alpha.N.zip` и
   `…-all-in-one.zip` ([что внутри](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md#the-release-zips--архивы-релиза)).
4. **Релиз**: на GitHub новый релиз с тегом `v1.2.3-repo0.5.0-alpha.N` на запушенный коммит, пометка pre-release,
   текст на английском и русском (шаблон — прошлый релиз: что нового, известные проблемы, установка, обновление,
   SHA-256 обоих архивов); приложить оба архива.

## B. Релиз Quest (1.0.7-qcNN)

1. **Патч**: `git diff <коммит ПК прошлого патча> <коммит ПК релиза> -- Source > patches/repoxr/00NN-что-делает.patch`
   (запускать в ПК-форке, сохранить сюда; `00NN` — следующий номер) и описать его в шапке `scripts/prepare-repoxr.sh`.
   Проверка: `bash scripts/prepare-repoxr.sh` собирается, а `work/repoxr-src/Source` после патчей совпадает с `Source`
   ПК-форка на этом коммите.
2. **Проверить в шлеме**: `REPOXR_DLL=$PWD/work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll CODE_ONLY=1 bash
   scripts/build-mac.sh` ([build-repoxr.ru.md](build-repoxr.ru.md)).
3. **Документация**: `## Unreleased` / `## Готовится` → `## 1.0.7-qcNN` в обоих журналах (из них делается текст релиза
   на GitHub); статус в README и «Что меняет форк» (ссылка на новый патч), известные проблемы в `docs/playing(.ru)`,
   пример в `docs/updating(.ru)` (`qcСТАРЫЙ → qcNN`). Коммит.
4. **Набор, скрипты, тег, релиз** — всё делает `scripts/release-fork.sh`:

   ```bash
   GITHUB_TOKEN=... scripts/release-fork.sh 1.0.7-qcNN --dlls <папка> --prerelease
   ```

   В `<папке>` — `RepoXR.dll` (`work/repoxr-src/bin/Release/netstandard2.1`), `RepoXR.Standalone.dll` и
   `Facepunch.Steamworks.Win64.dll` (`tools/*/bin/Release/netstandard2.1` после `scripts/make-kit.sh` или `prebuilt/`
   текущего набора, если они не менялись). Скрипт берёт текущий набор, кладёт в него скрипты и Unity-инструменты из
   этого клона и три DLL, ставит версию в `kit.json`, пишет `VERSION`/`KIT_SHA` в оба скрипта сборки, делает коммит и
   тег `v1.0.7-qcNN`, заливает набор в ветку `kit` (с `SHA256SUMS`), проверяет скачивание и создаёт релиз на GitHub.
   `--dry-run` останавливается до коммита. Проверенная версия игры — `--game <папка> --game-name v0.5.x`. После этого —
   поправить README ветки `kit`, если там поменялся диапазон патчей.

   Без скрипта (так выпускались 1.0.7-qc23–qc27): распаковать текущий набор, заменить `prebuilt/repoxr/RepoXR.dll`,
   поставить `version` в `kit.json`, снова запаковать; добавить его и строку в `SHA256SUMS` в ветку `kit`; вписать версию
   и SHA-256 в `scripts/build-mac.sh` и `scripts/build-windows.ps1`; запушить обе ветки вместе; поставить тег и создать
   релиз (текст из журналов, ссылка на набор и его SHA-256).
5. **Проверка**: чистый `git clone` + `bash scripts/build-mac.sh` скачивает новый набор (проверка SHA-256 проходит).

## Что нельзя сломать

- Скрипты сборки скачивают ровно тот набор из ветки `kit`, что в них прописан; релизы GitHub, пре-релизы или нет, для
  них ничего не меняют. Никогда не меняйте `VERSION`/`KIT_SHA` без набора в ветке `kit` и не удаляйте оттуда старые
  наборы: старые клоны всё ещё их называют.
- `scripts/prepare-repoxr.sh` (здесь) и `tools/package/make_release.py` (ПК-форк) берут XR-библиотеки Unity 6 из релиза
  alpha 6 ПК-форка по ссылке и SHA-256: этот релиз и его архивы не удалять.
- В наборах и APK нет файлов игры; `make-kit.sh` и `release-fork.sh` откажутся собирать такие. APK не публиковать никогда.

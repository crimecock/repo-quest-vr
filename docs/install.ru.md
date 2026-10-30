# Установка APK вручную

В конце сборки скрипты сами ставят APK в шлем. Если на этом шаге что-то сломалось или сборка шла с `--no-install` /
`-NoInstall`, поставьте APK по этой инструкции. Пересобирать игру не нужно.

English: [install.md](install.md).

## 1. Подготовьте шлем

1. Включите **режим разработчика** в приложении Meta Horizon на телефоне: Устройства → ваш Quest → Настройки
   гарнитуры → Режим разработчика. Это делается один раз.
2. Подключите Quest к компьютеру кабелем USB-C с передачей данных. Некоторые кабели от зарядок передают только питание.
3. Наденьте шлем. Разрешите **отладку по USB** и отметьте «Всегда разрешать с этого компьютера».
4. Не давайте шлему уснуть, пока идёт установка. Спящий Quest принимает APK, но ставит его, только когда проснётся.

## 2. Найдите adb

adb есть в Android-модуле Unity, отдельно ставить его не нужно.

macOS:

```bash
ADB=/Applications/Unity/Hub/Editor/6000.3.17f1/PlaybackEngines/AndroidPlayer/SDK/platform-tools/adb
```

Windows (PowerShell):

```powershell
$adb = "C:\Program Files\Unity\Hub\Editor\6000.3.17f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe"
```

Если Unity стоит в другой папке, поправьте начало пути. Подойдёт и `adb` из Android platform-tools или SideQuest.

APK лежит в папке `work/build` рабочей папки:
- macOS: `~/RepoQuest/work/build/REPO-Quest.apk`;
- Windows: `C:\RepoQuest\work\build\REPO-Quest.apk`.

Команды ниже — для macOS. На Windows вместо `"$ADB"` пишите `& $adb`.

## 3. Проверьте подключение

```bash
"$ADB" devices
```

Шлем должен быть в списке с пометкой `device`. Если там `unauthorized`, `offline` или шлема нет вовсе, смотрите таблицу
ниже.

## 4. Поставьте

```bash
"$ADB" install -r ~/RepoQuest/work/build/REPO-Quest.apk
```

APK весит около 0,8 ГБ, установка занимает одну-три минуты. В конце adb пишет `Success`. В шлеме откройте
**Библиотека → Неизвестные источники → R.E.P.O.** Первый запуск дольше следующих.

## Если не получилось

| Что пишет adb | Почему | Что делать |
|---|---|---|
| Пустой список в `adb devices` | Кабель без передачи данных, выключен режим разработчика или adb не увидел шлем | Попробуйте другой кабель или порт. Проверьте режим разработчика. Выполните `"$ADB" kill-server`, потом `"$ADB" devices`. На Windows поставьте драйвер «Oculus ADB Drivers» с сайта разработчиков Meta |
| `unauthorized` | В шлеме не разрешена отладка по USB | Наденьте шлем и подтвердите запрос. Если запроса нет, переподключите кабель |
| `offline` | Соединение зависло | Переподключите кабель, выполните `"$ADB" kill-server`, потом `"$ADB" devices` |
| `more than one device/emulator` | Подключён ещё телефон или второй шлем | Отключите его или добавьте после `"$ADB"` ключ `-s <серийник>` из `adb devices` |
| Минутами висит `Performing Streamed Install` | Шлем уснул | Разбудите его: наденьте или выполните `"$ADB" shell input keyevent KEYCODE_WAKEUP` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` или `signatures do not match` | Установленная сборка подписана на другом компьютере: отладочные ключи Android у каждого компьютера свои | Переустановите с сохранением данных, см. ниже |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | В шлеме нужно около 4 ГБ свободного места | Удалите что-нибудь в шлеме и повторите |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | Установлена более новая версия порта | `"$ADB" install -r -d ~/RepoQuest/work/build/REPO-Quest.apk` |
| `Broken pipe`, `connection reset`, `failed to write` | Кабель или порт отвалился во время копирования | Возьмите другой кабель или порт либо поставьте в два шага, см. ниже |

### Переустановка с сохранением данных

`adb uninstall` стирает данные игры в шлеме: сохранения, настройки RepoXR, вход в Steam и косметику. Поэтому сначала
скопируйте данные на компьютер, а после установки верните их.

```bash
"$ADB" shell am force-stop io.repoxr.quest
```

```bash
mkdir -p ~/RepoQuest/quest-backup
```

```bash
"$ADB" pull /sdcard/Android/data/io.repoxr.quest/files ~/RepoQuest/quest-backup
```

Проверьте, что папка `~/RepoQuest/quest-backup/files` не пустая, и продолжайте:

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

Последняя команда нужна, чтобы игра могла перезаписывать возвращённые файлы при сохранении.

### Установка в два шага

Если потоковая установка всё время обрывается, сначала скопируйте APK в шлем, а потом поставьте его оттуда:

```bash
"$ADB" push ~/RepoQuest/work/build/REPO-Quest.apk /data/local/tmp/repo.apk
```

```bash
"$ADB" shell pm install -r /data/local/tmp/repo.apk
```

```bash
"$ADB" shell rm /data/local/tmp/repo.apk
```

## Без командной строки

[SideQuest](https://sidequestvr.com) и Meta Quest Developer Hub ставят APK перетаскиванием. Внутри у них тот же adb,
поэтому ошибки и способы их исправить те же.

**Не делись APK**: в нём файлы игры.

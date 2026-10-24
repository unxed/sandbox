# FastStone под Wine: полная постановка и передача работы

Актуальность: 24 октября 2026 года. Этот документ — точка входа для нового
диалога. Он заменяет противоречащие ему старые статусы в `notes/`, но не
превращает гипотезы и написанные сценарии в результаты проверок.

## Что поручил пользователь

Добиться нормальной работы FastStone Image Viewer под исправленным Wine на
Linux. Основная версия — **5.6**, дополнительная — последняя доступная версия
(на момент исследования **8.5**). Версия **7.5** нужна для воспроизведения
конкретного бага подписей. При продолжении проверить, не появилась ли новая
версия, но сохранить закреплённые версии для воспроизводимости.

Нужна именно смотрелка изображений. Видео не обязательно: допустим понятный
отказ или отключение необязательного видеопровайдера, если быстро реализовать
его нельзя. Это не разрешение ломать просмотр, редактирование, сохранение
изображений, EXIF, навигацию или фокус окон.

Обязательно исследовать Wine bugs **5129, 59251, 48872**. Связанные проблемы:
**59609, 41438, 60301**. Исправления выбирать по фактическому воспроизведению,
сравнению с Windows/контрольной реализацией и проверке до/после. Не считать
исправлением случайное совпадение, успешную компиляцию или старый комментарий.

Особые требования пользователя:

- В fullscreen проверить возможности **каждого края**: сверху миниатюры,
  слева файловые и графические операции, справа свойства/EXIF, снизу управление;
  также документированный нижний правый угол для Windows Taskbar, учитывая
  различие между Wine и настоящим Windows desktop.
- Сверить полный список возможностей с документацией самих приложений.
  Основной источник — CHM, разделы Viewing Images / Mouse & Keyboard Use.
- Особенно проверить окна операций из левой всплывающей панели: Crop, Resize,
  Draw Board и вложенные окна текста, шрифта, цвета, параметров, сохранения.
  Исторически они или их подокна могли оказаться под изображением/родителем.
- Нужны настоящие E2E: движение к краю → щелчок по пункту → окно → вложенное
  окно → ввод → закрытие → возврат. Проверять видимость, foreground,
  active/focus, stacking относительно родителя/fullscreen и фактический ввод.
  Существование HWND, успешный горячий ключ или один скриншот недостаточны.
- Автотесты запускать максимально параллельно с отдельными дисплеями,
  профилями, копиями приложения и изменяемыми изображениями. Учитывать общий
  лимит VM, а не только лимиты каждого отдельного runner.
- Итог: патчи Wine в формате `git am`, по возможности ветки на GitHub;
  **по одному абзацу обычными словами на каждый тикет** с проверенной причиной
  и исправлением; **один исполняемый portable-файл** для Linux, содержащий
  исправленный Wine и запускающий FastStone.
- FastStone скачивать **только из закреплённых снимков Wayback**. Никогда
  напрямую с 2g0.ru. Не изменять `FSViewer.exe`.
- Для portable выбран first-run download/extract FastStone: приложение не
  вложено в публичный Wine payload. Разделять настройки/профили версий,
  поддержать offline archive, пробелы в путях, одновременный первый запуск.
- Часто сохранять изменения. Пользователь несколько раз просил немедленно
  отдать текущий патч при проблемах с push или перед остановкой.

## Репозитории и применение этого среза

Workbench расположен в https://github.com/unxed/sandbox, каталог `faststone/`.
База полного mbox-патча: **45c9a2d34e0123b6de52616eb7f8f1534911605e**.
Wine fork: https://github.com/unxed/wine, база исходников:
**840a939ee526137639665ff5f587224d6a36403f**, версия 11.20.

Этот файл входит в **кумулятивный** патч вместе с предыдущими checkpoint-
коммитами. Применять на чистую базу, не поверх уже применённого старого mbox:

```sh
mkdir faststone-work
cd faststone-work
git clone https://github.com/unxed/sandbox.git patch-export
git -C patch-export switch -c faststone-recovery 45c9a2d34e0123b6de52616eb7f8f1534911605e
git -C patch-export am /absolute/path/faststone-handoff-git-am.patch
git clone https://github.com/unxed/wine.git wine
git -C wine switch -c faststone-5.6-fixes 840a939ee526137639665ff5f587224d6a36403f
```

В shallow clone сначала сделать `git fetch --depth=1 origin HASH`. Команды
ниже выполнять из `faststone-work`, где рядом лежат `wine` и `patch-export`.
Большинство скриптов вычисляет workspace относительно расположения репозитория.
`vm/init.sh` пока явно ссылается на `/work/patch-export/faststone`: при другом
имени checkout поправить эту строку **до** упаковки initramfs.

Предполагались ветки `unxed/sandbox:faststone-5.6-validation` и
`unxed/wine:faststone-5.6-fixes`. Успешного push не было. Старый токен был
невалиден; секретов в патче нет. Плагин пользователь подключить не мог и
явно разрешил выдачу git-am патчей. Не требовать повторного подключения,
не обещать существование удалённых веток. Push делать только при реально
работающем доступе; для workflow нужны соответствующие права.

**Wine source не был изменён подтверждённым исправлением.** Вложенные
`patch-candidates/*.patch` — кандидаты, не готовая серия для отправки upstream.

## Что установлено по тикетам, а что остаётся проверить

Ссылки имеют вид `https://bugs.winehq.org/show_bug.cgi?id=59251`.
Историю читать до конца, в том числе свежие комментарии. При блокирующем
веб-интерфейсе работал `curl` к Wine Bugzilla REST:
`https://bugs.winehq.org/rest/bug/59251/comment`.

| Тикет | Рабочая картина и следующий проверяемый результат |
| --- | --- |
| 5129 | По январскому комментарию 2026 основной скроллинг окна уже не воспроизводился с Wine11/FastStone5.6; fullscreen-проблемы вынесены в59251. Самостоятельно подтвердить, не писать фиктивный новый fix. |
| 59251 | Отдельно воспроизвести отсутствие горизонтального wheel-scroll верхней полосы миниатюр и исчезновение миниатюр после смещения scrollbar дальше ширины экрана. Проверять изображения/индексы, а не только движение thumb. |
| 59609 | Предложение менять LISTVIEW_GetItemPosition глобально опасно: внутренние selection/navigation ждут client coordinates. Кандидат меняет только границу публичного LVM_GETITEMPOSITION для ICON/SMALLICON, вычитая origin. Измерить cc580/Windows, проверить скролл, Shift-selection и соседей до/после. |
| 48872 | Пропадающие имена в FastStone7.5. Проверить и5.6/8.5. MR10093 Maotong Zhang предлагал заменять пустую строку пробелом; Nikolay Sivov указал на лишний закрашенный прямоугольник selection. Нужны отдельно внешняя LVIR_LABEL geometry, internal painting, hit-test, focus/selection. Текущий label-кандидат непроверен. |
| 41438 | Исторически fullscreen→X открывал Crop под изображением. В январе2026 сообщали no-repro Wine11/FS5.6. Проверить регрессию и путь через щелчок левой панели, включая вложенные окна8.5. |
| 60301 | Удержание RMB должно временно увеличивать изображение; с11.17 описывался выход из fullscreen при отпускании. SendInput-only обходит X11 raw-input путь: нужен реальный XTEST down→удержание≈1.2s→скриншот→up. Возможная связь с XI2 duplicate events и60256/44a822d2374c71ee74fa8dc930b63f5a8e9ae256 — только гипотеза. |

Баг52179 про NFS к этому заданию не относится. Не выдавать его за FastStone.
Нативная cc580, запущенная внутри Wine, — контроль конкретной реализации
comctl32, **не полноценный запуск Windows**. Для окончательного native baseline
есть `.github/workflows/faststone-native.yml` x86/x64; workflow ещё не запускался.

## Честный статус на остановке

Рабочая песочница неоднократно сбрасывалась. Последний сброс обнаружен при
подготовке этой передачи. Из предыдущего сохранённого mbox восстановлен весь
workbench. Небольшие последние изменения runner/queue/diagnostics восстановлены
по текущему диалогу. **Сырые логи последнего прогона не сохранились**; ниже
записаны наблюдения, которые были прочитаны/сообщены до сброса. Повторить их
и сохранить новые доказательства прежде, чем выпускать исправление.

Подтверждённые в последнем запуске действия:

1. SHA-проверены архивы приложений, cc580, ядра и готового Wine. Собраны GUI
   PE32/PE64, Linux XTEST/snapshot helpers, API probes32/64 без warnings.
2. Offline QEMU TCG guest дошёл до `GUEST_WORKER_READY`; Xvfb/Openbox работали.
3. Оригинальный Kron4ek Wine11.20 падал139 сразу при wineboot. Debug вывел
   `host addr space limit: 0xffffffffffff0000`. Это также известная регрессия,
   явно отмеченная в release body самой сборки.
4. Пересобран только Unix `ntdll.so` из официального Wine11.20 tar с современными
   headers, заменён в prebuilt11.20. Сравнение показало302 одинаковых имён/типов
   Wine exports; отсутствие5 linker artifacts не доказывает структурный ABI.
   Такой **hybrid baseline** успешно завершил wineboot, exit0,
   `GOLDEN_PREFIX_READY`, профиль≈681MiB. Это не Wine bugfix release.
5. В native probe действительно загрузилась Microsoft DLL5.80.2614 из
   `Z:\work\test-bin\native\comctl32.dll`, а не Wine5.81.4704. Однако до
   измерений controls не дошло: CreateWindow(parent STATIC) вернул1400,
   ERROR_INVALID_WINDOW_HANDLE; первые ListView cases вернули2.
6. В label-прогоне видели `EGL_KHR_client_get_all_proc_addresses` missing,
   internal root context creation failure, затем `nodrv_CreateWindow` /
   `The explorer process failed to start`, также RpcSs errors. Вероятный
   блокер — неполная GLVND/Mesa среда минимального guest; причинная связь
   ещё не доказана. Это инфраструктурный fail, не измерение бага FastStone.
7. Initial4 GUI job были реально запущены:5.6/8.5 edges и5.6/8.5 lefttools.
   Дисплеи/WM поднялись, precloned profiles использованы. На последней проверке
   driver logs были пусты. Финальных успешных GUI assertions нет.
8. Полная сборка Wine840a939 с `--without-opengl` шла параллельно; completion,
   install и GUI-проверка не подтверждены. Объекты этой сборки потеряны.
9. Реальный portable hybrid-файл собран и **успешно сохранён отдельно**.
   На нём прошли7 групп packaging tests:4 simultaneous first starts, relocation
   и пробелы, Wine `--version`, offline prepare5.6/8.5 без изменения exe,
   отказ на неверный archive/payload, отсутствие DISPLAY. Это **не GUI pass**.

Ни одно из исправлений координат/колеса/подписей/фокуса пока не доказано.
Не писать в итоговом отчёте, что эти баги исправлены.

## Сохранённый portable checkpoint

Имя: `faststone-wine-hybrid-baseline.run`, размер **213306017** байт,
SHA256 **bb611d31ab79e016e2bb5144504b2988ebe4a9e17b7def47480c356bfcea563b**.

ChatGPT Library identity: `libfile_273239fb0cf88191ac2482ff68d4adec`,
file ID `file_00000000ab2c81f58e8964f07ceae028`, version0.
Ссылка: https://chatgpt.com/api/library/files/libfile_273239fb0cf88191ac2482ff68d4adec/download

Файл не вложен в git-патч. Если доступа к нему нет, собрать по исходникам;
задание не должно зависеть от ChatGPT Library. VM-toolkit checkpoint был
поручен, но подтверждения сохранения нет: **считать его отсутствующим**.

У `.run` есть `--self-test`, `--prepare`, `--prepare --latest`, `--wine ARGS`.
Для восстановления извлечённого Wine можно задать абсолютный
`FASTSTONE_CACHE_HOME`, выполнить `--self-test` и найти `<cache>/<payload>/wine`.
Проверить SHA перед использованием. Hybrid пригоден для диагностики, не для
финального заявления об исправленном/переносимом Wine.

## Закреплённые загрузки

Все загрузки писать во временный файл, проверять SHA и лишь затем переименовывать.
Загрузчик не должен автоматически переключаться на оригинальный FastStone host.

| Файл | SHA256 |
| --- | --- |
| FSViewerSetup56.exe | 1f6d5826d05046462ceec503812a89e8347a68bc382678db1d88baedc070c604 |
| FSViewerSetup75.exe | f252c71a29ac21aeeca498f79341b10f89028ec171048e62980a7568e2f1de48 |
| FSViewer85.zip | 685282a063b91daf4388b84be9e0daf3c5feed4073651137eb9fe9421cf39439 |
| CC32inst.exe | d68c0cca721870aed39f5f2efd80dfb74f3db66d5f9a49e7578b18279edfa4a7 |
| extracted comctl32.dll | 5353fdd5f9cd0fa265b52a8fe9fc206b146ac21c659086db1968086965a9f567 |
| Wine11.20 WoW64 archive | 482a493c755dcea776199b86560e0fb0f969bb0275c67d88120b0b35b0df34b9 |
| Wine11.19 WoW64 archive | a1fe858b45d12c9b16b91c7601d9b934f68430f7b6b95e240212ab6e2a198d8a |
| official wine-11.20.tar.xz | eac8ca448f9c0087f963026b4dc276d1e2b7fbb64056edc093e59bbb7e56fe28 |

URLs:

```text
https://web.archive.org/web/20261022225527id_/https://2g0.ru/fs/FSViewerSetup56.exe
https://web.archive.org/web/20210301234031id_/http://www.faststonesoft.net/DN/FSViewerSetup75.exe
https://web.archive.org/web/20260624231629id_/https://www.faststonesoft.net/DN/FSViewer85.zip
https://downloads.sourceforge.net/project/pocmin/Win%2095_98%20Controls/Win%2095_98%20Controls/CC32inst.exe
https://github.com/Kron4ek/Wine-Builds/releases/download/11.20/wine-11.20-amd64-wow64.tar.xz
https://github.com/Kron4ek/Wine-Builds/releases/download/11.19/wine-11.19-amd64-wow64.tar.xz
https://dl.winehq.org/wine/source/11.x/wine-11.20.tar.xz
```

Сверять provenance prebuilt с primary GitHub release/API, не полагаться на
поисковый сниппет. Original11.20 archive≈100025976bytes,11.19≈99272636bytes.
Из CC32inst последовательно извлекались `comctl32.exe`, затем
`x86/50ComUpd.Exe`, затем `comcnt.dll`; последнюю копировать как comctl32.dll.
При различающемся layout сначала `7z l`, не угадывать и не подменять DLL.
Оригинальную Microsoft DLL и FastStone binaries держать вне git.

## Восстановление Linux-инструментов

На обычном Ubuntu24.04 понадобятся root/пакеты или эквивалентный toolchain.
В конкретной песочнице apt sandbox user не работал, помогало
`-o APT::Sandbox::User=root`; postinst libibverbs/qemu/rdmacm мог вернуть ошибку,
хотя нужные executable уже были распакованы. Проверять фактические бинарники.

```sh
apt-get -o APT::Sandbox::User=root update
apt-get -o APT::Sandbox::User=root install --no-install-recommends \
  gcc-mingw-w64-i686-posix gcc-mingw-w64-x86-64-posix \
  g++-mingw-w64-i686-posix g++-mingw-w64-x86-64-posix flex bison \
  libx11-dev libfreetype-dev libxext-dev libxrender-dev libxi-dev \
  libxcursor-dev libxrandr-dev libxinerama-dev libxcomposite-dev \
  libxfixes-dev libfontconfig1-dev libgnutls28-dev libdbus-1-dev \
  libudev-dev libxkbcommon-dev libxtst-dev xvfb openbox p7zip-full \
  zstd patchelf busybox-static qemu-system-x86 seabios
```

Для fixtures нужен Python3+Pillow. Сначала проверить `socket(AF_UNIX)`.
Если разрешён, Wine/Xvfb/Openbox можно запускать на хосте без VM. Здесь вызов
возвращал EPERM. Эскалация была отклонена политикой окружения; не повторять
запросы на её обход. Рабочий путь — изолированная offline QEMU VM.

Собрать наш Wine:

```sh
mkdir -p evidence downloads test-bin
JOBS=6 sh patch-export/faststone/build-wine.sh
make -C wine-image-build install DESTDIR="$PWD/wine-stage"
```

Сохранять весь installed runtime сразу после завершения, не только код.
Build занимает много времени; git не сохраняет непроиндексированные объекты.
`build-wine.sh` отключает3D, GStreamer, audio и Wayland, но сохраняет статически
импортируемые Quartz/AVI/VFW/WinMM. Не удалять их вслепую по слову «видео».

Fast path с hybrid нужен только если полного Wine пока нет. В отдельном
out-of-tree каталоге сконфигурировать **официальный11.20 tar**, современный
Linux toolchain, `--enable-archs=i386,x86_64 --disable-tests`, затем
`make -j3 dlls/ntdll/ntdll.so`. Сравнить Wine exports с оригинальным Unix
ntdll, сохранить configure flags/config/compiler versions/hashes, заменить
только `lib/wine/x86_64-unix/ntdll.so` в отдельной копии prebuilt11.20.
Исходный prebuilt сохранить. Полные flags последнего fast build потеряны;
эти команды — рецепт повторения подхода, не обещание побитового совпадения.
SHA пересобранного тогда файла:
`b97b84543171c5f2b2b7f8d3c0815d358b970b0fc18723bead0874632b5cc398`.

Гипотеза startup139: старые bionic headers не определяют MAP_FIXED_NOREPLACE,
fallback anon_mmap_tryfixed даёт EEXIST при переносе mapping, новый
get_host_addr_space_limit трактует его как валидный огромный адрес. Modern
headers определяют0x100000. Успешный hybrid wineboot поддерживает гипотезу,
но для upstream fix нужны точный причинный тест и review. Сохранённый
`diagnostic-address-probe-shim.c` — ограниченный диагностический эксперимент
для48-bit guest, не общая заплатка и не часть конечного launcher.

## Компиляция тестов и fixtures

```sh
for pair in 'i686 32' 'x86_64 64'; do
  set -- $pair
  "$1-w64-mingw32-gcc" -O2 -Wall -Wextra -Werror \
    patch-export/faststone/listview-regression.c -o "test-bin/listview-regression$2.exe" -lgdi32 -luser32
  "$1-w64-mingw32-gcc" -O2 -Wall -Wextra -Werror \
    patch-export/faststone/label-regression.c -o "test-bin/label-regression$2.exe" -lcomctl32 -lgdi32 -luser32
done
i686-w64-mingw32-gcc -O2 -Wall -Wextra -Werror \
  patch-export/faststone/gui-suite.c -o test-bin/gui-suite.exe -lcomctl32 -lgdi32 -luser32
cc -O2 -Wall -Wextra -Werror patch-export/faststone/gui-suite-x11-bridge.c \
  -o test-bin/gui-suite-x11-bridge -lX11 -ldl
cc -O2 -Wall -Wextra -Werror patch-export/faststone/gui-suite-x11-snapshot.c \
  -o test-bin/gui-suite-x11-snapshot -lX11
python3 patch-export/faststone/gui-suite.py --fixtures-only test-fixtures
```

Создать `test-bin/native`, положить проверенную comctl32.dll и копию32-bit
label probe под именем `label-regression-cc580.exe`. Архивы распаковать7z в
`downloads/FastStone56`, `downloads/FastStone75`, `downloads/FastStone85`;
runner ждёт соответственно `FSViewer.exe`, `FSViewer.exe`,
`FSViewer85/FSViewer.exe`. 164 JPEG/EXIF fixtures и прочие форматы генерируются
скриптом, их не нужно хранить в патче.

`build-upstream-listview-test.sh` строит настоящий Wine ListView test32/64.
Его запуск **до** готового `libwinecrt0.a` завершился linker error, а не
провалом Wine tests. Повторить после полного build. Для более ранней сборки
сначала явно собрать нужный Wine crt target. Не считать это уже пройденным.

## VM с нуля

Закреплённое ядро Ubuntu6.8.0-138-generic:

```text
https://snapshot.ubuntu.com/ubuntu/20260828T000000Z/pool/main/l/linux-signed/linux-image-6.8.0-138-generic_6.8.0-138.138_amd64.deb
SHA2567093879c9dad61fb24bb5a0247d8dd1ea444c4854492a9b3669175624cd04bda
size14815182
https://snapshot.ubuntu.com/ubuntu/20260828T000000Z/pool/main/l/linux/linux-modules-6.8.0-138-generic_6.8.0-138.138_amd64.deb
SHA2562b6108dba87947e4cb7d79759fd85dfe39d431466d745d1b6ec75b4bdabe866d
size39127232
```

Извлечь оба deb в **новый** `vm-kernel-verified` через `dpkg-deb -x`.
vmlinuz должен иметь15055240bytes и SHA256
`d74be574189057a036866309fd5546724a92390a4f6ba086e93ddab2f6e0e01d`.
Раньше обрезанный apt-download kernel давал silent triple fault. Не доверять
одному успешному download message, не дописывать поверх повреждённого дерева.

```sh
VM_WINE_ROOT="$PWD/wine-image-build" python3 patch-export/faststone/vm/prepare.py
sh patch-export/faststone/vm/run.sh > evidence/guest-console.log 2>&1
```

Для installed runtime передать его путь в VM_WINE_ROOT вместо build tree.
prepare.py собирает busybox initramfs, Xvfb/Openbox, fonts, linked/SONAME libs,
модули9p; создаёт `vm-initrd-v2.gz`. Guest имеет4vCPU/3GiB, без сети, /work
соответствует выбранному workspace. **CPU qemu64**, не max: max вызывал
SMEP/IRET kernel oops в этом TCG окружении.

Гостевой `/tmp` — rootfs/tmpfs≈половина RAM. Wine prefix там заполнял диск
и давал error112. Все профили, включая golden и временные jobs, хранить в
`/work/guest-state`. Font caches writable, loopback UP обязательны.

Для быстрого golden сначала на хосте:

```sh
sh patch-export/faststone/vm/prepare-prefix-host.sh \
  "$PWD/wine-stage/opt/faststone-wine" "$PWD/guest-state/golden-prefix"
```

Затем в guest выполнить `vm/bootstrap-prefix.sh` с VM_WINE_ROOT=/work/... и
VM_GOLDEN_PREFIX=/work/guest-state/golden-prefix. Host seeding копирует только
Wine PE files; **не отменяет wineboot**. Дождаться exit0/.initialized и
остановленного wineserver. Только потом клонировать golden на хосте
`cp -a --reflink=auto` в отдельные preclone directories. Не копировать живые
registry и не запускать wineboot -u в каждой копии.

Queue: атомарно temp→`vm-queue-live/unique.request`, внутри shell script.
Guest пишет `.response`, `.exit`, `.done`. Для stop записать `stop` в control.
Не использовать stale STOP. При новой VM убрать незавершённые request из
прошлого запуска/использовать новые уникальные имена. Worker теперь имеет
mkdir `.claimed` guard и не исполняет request после failed mv. Эта защита
восстановлена после наблюдённых duplicate/stale entries, ещё требует прогона.
Для дорогих jobs дополнительно поставить атомарный mkdir once guard внутри
самого request. Не доверять одному queue.exit: проверять per-job результат.

### Текущий GUI-блокер и первый шаг продолжения

**Не запускать сразу десятки FastStone сценариев.** Сначала добиться успешного
создания простого STATIC окна и desktop/explorer с err logging на одном
дисплее. Проверить весь runtime X11/GDI, RpcSs и live screenshot/window tree.
Предпочтительный следующий baseline — завершённый source build с
`--without-opengl`, который устраняет зависимость этой конфигурации от GL.
Это пока ожидаемый путь, а не уже подтверждённое решение GUI-блокера.

Если использовать prebuilt с OpenGL, ldd/SONAME недостаточно: Mesa/GLVND
подгружает vendor JSON/DSO/DRI dynamically. Их минимальный guest не включал.
Не объявлять отсутствие одного EGL extension доказанной единственной
причиной. Xvfb сейчас запускается с `-extension GLX`; согласовать это с
выбранным backend. Тесты должны сохранять `err+all`, а не глушить ошибки
`WINEDEBUG=-all`. Сам X11 snapshot helper работает без Wine.

## Запуск минимальных настоящих тестов после устранения блокера

Все пути в этом разделе гостевые `/work/...`. Выбрать один законченный Wine
runtime и не смешивать его DLL с другими версиями. Для build tree Wine
executable=`/work/wine-image-build/wine`, server=`.../server/wineserver`;
для installed runtime — `bin/wine`, `bin/wineserver`.

GUI: `gui-suite-initial.sh` запускает4 job на дисплеях20..23. Задать
GUI_SUITE_WINE, GUI_SUITE_WINESERVER, GUI_SUITE_GOLDEN_PREFIX,
GUI_SUITE_RUN_TAG с новым именем. Для быстрых clones задать
GUI_SUITE_PRECLONED_PREFIX_ROOT с каталогами `5.6-edges`, `8.5-edges`,
`5.6-lefttools`, `8.5-lefttools` (каждый — готовый private prefix).
Runner переименует/потребит их. Проверять каждый driver.exit,
assertions.jsonl, screenshots/window trees; затем наблюдениями уточнить
owner-drawn controls и nested dialog plans. Не подменять неудачный click
горячей клавишей или выдуманными координатами.

ListView: `listview-suite-guest.sh`, WINE/WINE_SERVER/GOLDEN_PREFIX,
RUN_ID, MODE=all, MAX_JOBS=2. PREFIX_POOL содержит builtin64/builtin32/native32
preclones. Результаты ndjson, summary, loaded module/class identity,
program-exit. Полный baseline с воспроизведённым дефектом отличается от
infrastructure-failed. Native должен действительно быть5.80 с верным
HMODULE зарегистрированного класса. Не принимать старый builtin5.81 за native.

Label: `run-label-probes-guest.sh`, обязательные LABEL_WINE, LABEL_WINESERVER,
LABEL_GOLDEN, LABEL_PREFIX (новый), LABEL_OUTPUT, LABEL_PROBE32, LABEL_PROBE64,
LABEL_NATIVE_PROBE; LABEL_PRECLONED_PREFIX_SOURCE — готовая частная копия.
Начать icon/default (56cases), потом LABEL_VIEW=all/LABEL_FONT=all (448cases).
Сравнить `compare-label-records.py`, сначала discovery, после исправления
strict. Native override **per-executable AppDefaults**: глобальная подмена
comctl32 ломает Wine shell32/HIMAGELIST_QueryInterface. Одинаковый loaded DLL
path, class module и версия обязательны; GdiFlush нужен для paint oracle.

Координатная fixture сначала делает paint/pump, затем legacy
LVM_SETITEMPOSITION и resize381→380 для ranges. Без проверенной ручной сетки
результаты wheel/coordinates недействительны. Старый вариант перестраивал
иконки при первом paint. Возможный старый SMALLICON nearest-XY navigation
дефект не следует приписывать новому координатному патчу: сравнить before/after.

После реального baseline: применить кандидата **в отдельной Wine ветке**,
пересобрать comctl32 обеих разрядностей, повторить те же API/GUI и upstream
ListView tests. Отделить fix координат, wheel, label geometry/paint и прочие
причины по осмысленным коммитам. Не применять обе гипотезы одновременно без
возможности определить, что именно исправило/сломало результат.

После initial4 расширить матрицу из `docs/test-matrix.md`: thumbnail scrollbar
за экран, wheel fractions/axes, selection/navigation, все документированные
края/операции, форматные/Unicode/EXIF/многостраничные изображения, right-hold
через XTEST, вложенные Draw/font/color/save dialogs и возврат. Сверить
форматные возможности8.5 (включая PDF/SVG, если заявлены) с её документацией;
static import inspection не заменяет открытие файлов. Видео graceful failure
должно оставлять приложение пригодным для просмотра картинок.

## Portable, проверки и завершение задания

`bundle/build.py` принимает installed Wine prefix/source/config/revision,
busybox, patchelf и output. Пример есть в `docs/bundle.md`. RPATHv2 прописывает
relative DT_RPATH каждому ELF/DSO, резервирует PT_INTERP для своего loader и
не экспортирует global LD_LIBRARY_PATH/GCONV_PATH в host children (например
xdg-open). Не возвращать глобальную подмену libc-путей.

Запуск packaging tests:

```sh
python3 patch-export/faststone/bundle/test_bundle.py /absolute/file.run \
  --archive56 "$PWD/downloads/FSViewerSetup56.exe" \
  --archive85 "$PWD/downloads/FSViewer85.zip"
```

Затем нужны **GUI tests того самого portable**, а не только отдельно запущенного
Wine. Проверить Portable.db/settings isolation, несколько host baselines,
системный child launcher, X11/XWayland, clean first-run и offline. Нельзя
обещать «любой Linux»: x86_64 kernel и рабочий display остаются обязательными.

Сохранять по инкрементам: source commits+format-patch, raw evidence с точными
Wine/app hashes и command lines, installed runtime/.run сразу после сборки,
затем воспроизводимый VM toolkit. Не считать локальный sandbox долговечным.
Не сохранять credentials, персональные screenshots, proprietary binaries в
git. Для этой задачи использовать синтетические изображения и публичные API.

Условие завершения: воспроизведённые дефекты исправлены и проверены before/after;
остальные тикеты честно классифицированы no-repro/отдельный дефект; ключевой
viewer и E2E матрица пройдены на5.6 и последней версии;7.5 покрывает48872;
готов реальный portable с проверками; отданы git-am Wine patches, workbench
patch и краткие абзацы по тикетам. Сейчас эти условия ещё **не выполнены**.

## Короткое задание для следующего диалога

Продолжи `faststone/HANDOFF.md` из приложенного кумулятивного git-am патча для
unxed/sandbox. Сначала восстанови pinned Wine/FastStone и устрани общий GUI
bootstrap blocker (CreateWindow1400/nodrv/EGL в минимальной VM), получи одно
реальное окно. Затем измерь native cc580 vs Wine ListView/label, воспроизведи
59251/48872 и проверь связанные5129/59609/41438/60301; только по данным правь
Wine, повторяй before/after/upstream tests. Максимально параллельные E2E на
всех fullscreen edges и left-panel nested dialogs для5.6/последней версии,
7.5 для48872. Не менятьFSViewer.exe, FastStone только Wayback. Видео optional.
Доведи portable one-file с исправленным Wine и first-run downloader, сохраняй
артефакты немедленно. Отдай проверенные git-am patches и по абзацу на тикет;
готового подтверждённого Wine fix пока нет. Не принимать packaging pass или
написанные сценарии за GUI pass.

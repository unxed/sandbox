# f4 → Haiku OS port (sandbox)

**Статус на 2026-09-18: f4 собирается под `GOOS=haiku GOARCH=amd64` И РАБОТАЕТ в Haiku**
(nightly hrev60122 x86_64, QEMU/KVM внутри GitHub Actions): рисует панели в родном
Terminal, ходит по каталогам, создаёт папки (F7), исполняет команды из командной
строки через PTY-бэкенд (`pty_haiku.go`) — проверено скриншотами и логами, см.
раздел «Запуск в Haiku VM (vmlab)» ниже. Всё собирается и запускается только в
GitHub Actions этого репозитория, локально ничего не собирается («Правило песочницы»).

## Запуск в Haiku VM (vmlab) — как это устроено и что найдено

`vmlab/` (QEMU-драйвер, изначально сделан для Redox) адаптирован под Haiku:

- **`vmlab-haiku.yml`** — batch-workflow: KVM на раннере → загрузка Haiku (образ качается и
  распаковывается за ~20 с, до окна «Welcome» ~10 с) → сценарий `vmlab/scenarios/haiku-*.txt`.
  Не использует git-шину, поэтому не мешает чужим интерактивным сессиям. Запуск:
  `gh workflow run vmlab-haiku.yml -f scenario=haiku-smoke`.
- **Интерактивная сессия на своей шине.** `vmlab-session.yml` получил вход `bus`: шина команд
  теперь `<bus>-cmd`/`<bus>-out` (по умолчанию `vmlab` — как было). Для Haiku:
  ```bash
  export GH_TOKEN=... VMLAB_BUS=vmlab-haiku VMLAB_AGENT_EXT=sh
  python3 vmlab/ctl.py start --guest haiku --minutes 45 --scenario haiku-desktop
  python3 vmlab/ctl.py do "shot x" "click 330 400" "typeln ./f4"   # клавиатура/мышь/скриншоты
  python3 vmlab/ctl.py sh 'uname -a; ls /tmp'                      # команды через гостевого агента
  python3 vmlab/ctl.py put файл имя                                # положить файл в гостя
  python3 vmlab/ctl.py stop
  ```
  Сценарий `haiku-desktop` сам проходит Welcome → «Try Haiku» → Deskbar → Applications →
  Terminal и запускает `vmlab/guests/haiku-agent.sh` (аналог `redox-agent.ion`: опрашивает
  `http://10.0.2.2:8000/job.sh`, исполняет, заливает `job.out`; отклик ~8 с).
- **Что доставляется в гостя** (каталог payload раздаётся хостом на `10.0.2.2:8000`): свежий
  бинарник `f4-haiku-amd64` и `ptyrun-haiku` (PTY-харнесс из `vmlab/haiku/ptyrun`, собирается в
  том же job'е `f4-haiku` тем же тулчейном, артефакт `f4-haiku-tools`).
- **Инструменты разбора:** `vmlab/haiku/vtdump.py` (эмулятор терминала на stdlib: превращает
  снапшоты `ptyrun` в текст экрана, `--bg` — карта цветов фона), `sgrtest*.sh` (эксперименты с SGR).

**Практические грабли Haiku в VM:** Terminal использует раскладку US-International, поэтому
в `typeln` нельзя `'` `"` `~` `^` `` ` `` (мёртвые клавиши); шаг `stable` не работает (экран
постоянно меняется) — используйте `wait`; в образе нет `pkill` (только `kill PID`), а `kill -9 0`
убивает всю группу; `ps` выводит `имя PID потоки 0 0`; syslog ядра идёт в `serial.log`;
`f4` по умолчанию уходит в detached-сессию (`f4 --server …`, каталог `/tmp/f4-sessions-0`), из-за
чего повторный запуск переподключается к старому состоянию — для чистых тестов убивайте процессы
и удаляйте каталог сессий, либо запускайте `f4 --attached`.

### Найдено и исправлено при запуске в реальной Haiku

1. **PTY-бэкенд подтверждён.** Последовательность из исходников Haiku (`/dev/ptmx` →
   `B_IOCTL_GRANT_TTY` → `B_IOCTL_GET_TTY_INDEX` → `/dev/tt/p<N>`) работает: в госте есть
   `/dev/ptmx` и `/dev/tt/p0…`, шелл стартует, ввод/вывод идут, команда из командной строки f4
   (`echo hello-from-f4`) исполняется во встроенном терминале. Найден и исправлен изъян в
   `pty_haiku.go`: `ioctl` шёл сырым 3-аргументным `SYS_IOCTL`, а у Haiku `ioctl` берёт ещё и
   длину буфера — теперь через `unix.Ioctl*` из `korli/sys_haiku` (libroot), а `Fd()` заменён на
   `SyscallConn().Control` (не переводит мастер в блокирующий режим).
2. **Enter приходил как LF (Ctrl+J), ввод был построчным.** `vtinput` включает raw-режим через
   `golang.org/x/term.MakeRaw`, у которого нет порта под Haiku (`term_unsupported.go` → ошибка),
   поэтому терминал оставался в каноническом режиме. Патч `patches/xterm-haiku.patch` (как у
   `korli/term_haiku`): `term_unix_haiku.go` c `TCGETA`/`TCSETA`, подключён `go mod edit -replace`.
3. **Зелёные фоны строк каталогов/исполняемых файлов.** Причина — баг Haiku Terminal: в
   `TermParse.cpp` `#define NPARAM 10`, а vtui склеивает reset + стиль + fg + bg в одну
   SGR-последовательность (`0;38;2;R;G;B;48;2;R;G;B` — 11 параметров), лишние `;` игнорируются,
   цифры 11-го дописываются к 10-му. Найдено воспроизведением точного байтового потока f4 через
   `cat` в Terminal и тестами форм SGR. Патч `patches/vtui-haiku.patch` (только `GOOS=haiku`):
   `maxSGRParams = 10`, последовательности бьются на несколько CSI. Черновик отчёта в апстрим
   Haiku — `haiku-terminal-sgr-params.md`.
4. Прочее: `UPDATER ERROR: no suitable build found for your OS/Arch` в логе — ожидаемо (сервер
   обновлений не знает про Haiku); `f4 --tty --attached` под `ptyrun` раньше выходил сразу из-за п. 2.

5. **Стрелки не работали (читались как Ctrl+стрелка).** В отладочном логе f4 у обычной «вниз»
   было `Mods:Ctrl,Enhanced Src:legacy_ss3`. Haiku Terminal шлёт простые стрелки как SS3 —
   `ESC O A/B/C/D` (Home `ESC O H`, End `ESC O F`; с Shift `ESC O 2A`, с Ctrl `ESC O 5A`, см.
   `src/apps/terminal/VTkeymap.h`), а `vtinput.ParseLegacySS3` трактует голый `ESC O A..D` как
   Ctrl+стрелку (особенность PuTTY). Патч `patches/vtinput-haiku.patch`: переменная
   `bareSS3ArrowsAreCtrl` (по умолчанию `true` — поведение других платформ не меняется),
   `ss3_arrows_haiku.go` (`//go:build haiku`) выставляет `false`.

### Проверено в VM после этих исправлений (сборка 36320aa, скриншоты в артефактах vmlab)

Стрелки вверх/вниз, Home/End, PgDn; F3 (просмотр текста, выход по Esc), F4 (редактор: ввод и
сохранение F2 — файл на диске изменился), F5 (копирование в соседнюю панель — файл появился), F8
(диалог удаления, файл удалён), F6 (диалог переименования/переноса), F9 (меню, стрелки внутри
меню), Shift+↓ (выделение — `hmp sendkey shift-down`), клик мышью по строке панели, изменение размера
окна Terminal (f4 перерисовывается под новый размер: панели, key bar).

Заметки оттуда же:
* **Esc в панелях у f4 — переключатель панелей/терминала** (`Panel.Toggle`, `Esc:EscToggle`), это
  не баг порта; для закрытия диалогов Esc работает как обычно.
* **`f4` оставляет `f4 --server` после выхода клиента и не реагирует на `kill` (SIGTERM);** такие
  процессы держат блоки *удалённого* бинарника. Диск гостя всего 650 МиБ (из них ~31 МиБ свободно
  без f4, сам бинарник 107 МиБ) — удаление/перезалив бинарника при живом `--server` даёт
  `No space left on device` (проявляется как оборвавшийся `curl` на 32 МиБ и как ошибки записи в
  `/tmp/job.out`, после чего агент «молчит»). Перед перезаливом: `kill -9` всех `f4 --server` (ядро
  потом показывает окно краша — просто закрыть), либо запускать `f4 --attached`.
* **`f4 --gui=x11` в Haiku без `DISPLAY` сразу выходит с кодом 0 и ничего не показывает** — но
  X11-бэкенд f4 (чистый Go, без FFI) **работает по сети**: workflow `vmlab-haiku`, сценарий
  `haiku-x11`, поднимает на хосте Actions `Xvfb :1` (TCP 6001, `VMLAB_XVFB=1`), гость запускает
  `DISPLAY=10.0.2.2:1 f4 --gui=x11 --attached /boot/home/t`, окно f4 рисуется в Xvfb (шрифты,
  панели, key bar), ввод (`xclick`, `xkey Down`) доходит — `xshot` даёт скриншоты в артефакте.
  Нативного X-сервера в стандартной Haiku нет (есть только Xlibe — клиентская обёртка над
  app_server); нативный app_server-бэкенд остаётся отдельной задачей.
* `End`/`Home` в самом bash Terminal показывают `OF`/`OH` (bash не знает SS3 Haiku без inputrc) —
  к f4 не относится.

### Автоматический регресс

`vmlab-haiku` (workflow_run после каждой успешной сборки `f4-haiku`, а также по push в
`vmlab/scenarios/haiku-*.txt`, `vmlab/haiku/**` и вручную) грузит свежий бинарник в чистую Haiku VM и
прогоняет сценарий `haiku-regress` (стрелки, F3, F4+F2, F5, F6, F8, F9); `vmlab/haiku/regress-check.sh`
проверяет результат на диске и job падает при `RESULT FAIL`. Последний прогон: `RESULT PASS`.
Сценарий `haiku-x11` (вручную, `-f scenario=haiku-x11`) проверяет `--gui=x11` против Xvfb на хосте.
Загрузка Haiku в Actions плавает по времени — сценарии ждут диалог/Deskbar через OCR (`waittext`).

### Ещё не проверено / следующие шаги

Плагины и SQLite (`MmapPtr` в старом шиме была заглушкой — теперь настоящий `sys_haiku`, но рантайм
не проверен); сочетания Ctrl/Alt+стрелки, F-клавиши с модификаторами, Insert/Delete/PgUp;
автоматический регресс `vmlab-haiku` после каждой сборки (`workflow_run`); нативный
графический бэкенд (app_server); `-ldflags "-s -w"` для полезной нагрузки VM (меньше места на диске гостя).

## Обновление: переход на korli/go и korli/sys_haiku

В [korli/go#2](https://github.com/korli/go/pull/2) korli ответил: вместо
собственного шима для `golang.org/x/sys` надо использовать
[`github.com/korli/sys_haiku`](https://github.com/korli/sys_haiku) (ветка
`master-haiku`; так же сделано в рецепте HaikuPorts
`www-apps/hugo/hugo-*.recipe`: `go mod edit -replace
golang.org/x/sys=github.com/korli/sys_haiku@master-haiku`), а ветку
`golang-1.26-haiku` он сам догнал до апстрима (на момент записи —
`go1.26.8`, что выше требуемого f4 `go 1.26.6`). Поэтому PR #2 потерял смысл.
Что изменено в пайплайне:

- Тулчейн теперь клонируется прямо из `korli/go`, форк `unxed/go` больше не
  используется. Его единственные собственные коммиты (`syscall.FcntlInt`,
  `syscall.Getpgid`) нужны были только нашему шиму x/sys.
- Шим `xsys-unix-haiku.patch` удалён. Вместо него
  `go mod edit -replace golang.org/x/sys=github.com/korli/sys_haiku@<commit>`
  (закреплён коммит из `master-haiku`, а не сама ветка, чтобы прогоны CI
  были воспроизводимы; `GOPRIVATE=github.com/korli/*`, чтобы модули
  подтягивались напрямую с GitHub, минуя proxy/sumdb).
- `f4-haiku.patch`: в `pty_haiku.go` вызов `syscall.Getpgid` заменён на
  `unix.Getpgid` (в `korli/go` он не экспортируется, а в `sys_haiku` есть).
- Пункты про шим ниже («Карта репозитория», блокеры №2 и №4, пункты 2, 3, 5
  чек-листа) описывают прошлое состояние; `Mmap`/`Munmap`/`Mprotect`/`Poll`/
  `Flock`/`FcntlInt` теперь настоящие реализации из `sys_haiku` (через
  libroot), а не заглушки.
- Статус: **подтверждено прогоном CI**
  ([run 35393334534](https://github.com/unxed/sandbox/actions/runs/35393334534)):
  тулчейн `go1.26.8` из `korli/go`, `x/sys => korli/sys_haiku 819bfec32e8f`,
  `f4` собирается под `GOOS=haiku GOARCH=amd64`, бинарник — ELF с
  `interpreter /system/runtime_loader` (~107 МБ). В рантайме по-прежнему не
  запускался.

Этот файл — единственная точка входа: по нему можно продолжить работу (в
том числе в свежем диалоге/окружении) без переизучения истории чата.

## Что это и зачем (для нового диалога)

Пользователь (unxed) ведёт `github.com/unxed/f4` — кроссплатформенный
TUI-файловый менеджер на Go в духе Far Manager/far2l, уже кросс-компилируется
под десяток GOOS/GOARCH (linux, windows, darwin, freebsd, openbsd, netbsd,
dragonfly, illumos, solaris, android/termux, разные архитектуры). Задача —
добавить в этот список Haiku OS. Поскольку апстрим Go никогда не принимал
`GOOS=haiku` (golang/go#56224 закрыт как "not planned"), реальный тулчейн
живёт только в стороннем форке github.com/korli/go — соответственно, порт
f4 распадается на: (1) получить рабочий кросс-компилирующий тулчейн, (2)
залатать все места в самом f4 и его транзитивных зависимостях, которые
рассчитывают на существование `GOOS=haiku` там, где его на самом деле нет
(в первую очередь `golang.org/x/sys/unix`, у которого нет портa под Haiku
вообще).

**Правило песочницы (действует и дальше):** ничего не собирается и не
компилируется локально — ни `go build`, ни `make.bash`, ни любые другие
шаги тулчейна. Всё это только через workflow в GitHub Actions
(`.github/workflows/f4-haiku.yml`) в этом репозитории. Также: никакие
патчи не приколачивают `f4` или его зависимости к haiku-специфичным
форкам/версиям НИГДЕ, кроме собственно haiku-сборки — реальные репозитории
(`unxed/f4`, `unxed/vtui`, `unxed/zip` и т.д.) не меняются вообще, патчи
применяются только к эфемерным чекаутам внутри CI-джобы. Исключение — наш
собственный форк тулчейна `unxed/go`: туда мы пушим по-настоящему, т.к.
это неотъемлемая часть самого порта (см. ниже), и `master`/остальные ветки
там остаются синхронизированы с апстримом для удобства отправки PR назад.

## Карта репозитория / где что лежит

- **`.github/workflows/f4-haiku.yml`** (этот репозиторий) — весь пайплайн:
  собирает тулчейн из `unxed/go`, клонирует `f4` и восемь его зависимостей
  на версиях, закреплённых в `f4/go.mod`, применяет к каждой соответствующий
  `.patch` из `f4-haiku/patches/`, подключает через `go mod edit -replace`,
  собирает `GOOS=haiku GOARCH=amd64 ./cmd/f4`, кладёt лог и бинарник в
  артефакты.
- **`f4-haiku/patches/*.patch`** (этот репозиторий) — все патчи, unified
  diff, с подробными комментариями прямо в патчах и разбором ниже в этом
  файле. Ничего не тронуто в реальных репозиториях.
- **`github.com/unxed/go`**, ветка `golang-1.26-haiku` — наш форк
  `korli/go`. Здесь, в отличие от всего остального, изменения
  запушены по-настоящему (это и есть тулчейн, а не патч поверх чего-то).
  Два вида коммитов: (а) мердж `go1.26.6` из `golang/go`
  `release-branch.go1.26` (закрывает версионный разрыв
  `go.mod requires go >= 1.26.6`), (б) точечные добавления в
  `src/syscall/syscall_haiku.go`/`zsyscall_haiku_amd64.go` —
  экспортированные `FcntlInt` и `Getpgid`, которых в korli/go не было (см.
  пункт 8 в списке блокеров ниже).
- **PR [korli/go#2](https://github.com/korli/go/pull/2)** — мердж
  `go1.26.6`, отправлен апстриму, статус на момент записи: открыт, не
  смержен. `FcntlInt`/`Getpgid` в отдельный PR пока не отправлены (можно
  сделать тем же способом — форк уже есть, PR открывается вручную через
  веб-интерфейс GitHub, см. «Известные ограничения инструментов» ниже).

## Как воспроизвести/продолжить сборку

```bash
gh workflow run f4-haiku.yml -R unxed/sandbox
gh run list -R unxed/sandbox -L 1                    # найти запущенный run
gh run watch <run-id> -R unxed/sandbox --exit-status  # дождаться
gh run download <run-id> -R unxed/sandbox             # скачать артефакты:
  # toolchain-build-log/, f4-build-log/, f4-haiku-amd64/f4-haiku-amd64
```

Workflow также триггерится на `push` в пути `f4-haiku/**` и
`.github/workflows/f4-haiku.yml` — то есть просто закоммитить новый/
изменённый патч в этот репозиторий уже запускает пересборку.

Чтобы поправить что-то в существующем патче: смотреть комментарии внутри
самого `.patch`-файла (там же объяснение, откуда взяты все константы —
из реальных сгенерированных файлов `korli/go` или из исходников самой
Haiku, а не подобраны), поправить, регенерировать через `git diff` в
свежем чекауте соответствующего репозитория на нужном теге/коммите (см.
шаги клонирования в самом workflow — версия каждой зависимости берётся
динамически из `f4/go.mod` через `grep`).

## Тестирование под QEMU (следующий шаг)

Бинарник собирается, но не проверен в рантайме — этот раздел специально
для окружения, где есть QEMU/KVM.

1. **Образ Haiku.** Нужен именно **чистый 64-битный** nightly-образ (не
   `x86_gcc2_hybrid`, это 32-битный legacy-ABI вариант):
   ```
   https://download.haiku-os.org/nightly-images/x86_64/current-anyboot
   ```
   (anyboot-образ одновременно годится и как установочный диск, и как
   образ жёсткого диска — см. haiku-os.org/get-haiku). Ссылку и актуальность
   пути стоит перепроверить на момент использования (haiku-os.org, раздел
   Downloads) — на момент записи этого файла (2026-09-18) она была верна.

2. **Загрузка в QEMU** (варианты с discuss.haiku-os.org и
   haiku-os.org/guides/virtualizing/kvm — тоже стоит свериться с
   актуальной версией гайда):
   ```bash
   qemu-img create -f qcow2 haiku.qcow2 8G
   qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 \
     -drive file=haiku.qcow2,format=qcow2 \
     -cdrom haiku-nightly-x86_64-anyboot.iso -boot d
   # после установки на диск — грузить уже без -cdrom/-boot d
   ```

3. **Доставка бинарника в гостевую Haiku.** Самое простое — расшарить
   бинарник по сети (Haiku поддерживает обычный TCP/IP в QEMU user-mode
   networking, `wget`/`curl` в Haiku тоже есть) — например, положить
   `f4-haiku-amd64` на любой HTTP-хостинг (в т.ч. можно временно поднять
   `python3 -m http.server` на хосте и пробросить порт через
   `-netdev user,hostfwd=` или просто `curl` к хостовому IP `10.0.2.2` при
   стандартном QEMU user-networking) и скачать его изнутри гостя. Либо
   через `-hdb shared.img` (второй диск) с заранее записанным на него
   файлом, либо через 9p/virtfs, если конкретная версия Haiku его
   поддерживает — не проверено, начните с сетевого варианта как самого
   надёжного.

4. **Первый прогон.** `chmod +x f4-haiku-amd64 && ./f4-haiku-amd64` в
   Terminal самой Haiku. Ожидаемо интересны, в порядке убывания
   вероятности проблем (см. чек-лист ниже) — открытие терминальной
   PTY-сессии (`internal/terminal/pty_haiku.go` — самое непроверенное
   место во всём порте) и базовая навигация по панелям.

## Чек-лист: что в первую очередь проверять/чинить на реальной Haiku

Всё ниже — **скомпилировано и типобезопасно, но никогда не выполнялось**.
Порядок — по убыванию вероятности, что именно тут что-то не так.

1. **`internal/terminal/pty_haiku.go` — выделение PTY.** Дословно
   реализовано по исходнику Haiku (`src/system/libroot/posix/stdlib/pty.cpp`,
   `headers/private/drivers/tty.h`), но каждая ioctl-константа
   (`B_IOCTL_GRANT_TTY=0x8021`, `B_IOCTL_GET_TTY_INDEX=0x8020`) и схема
   имён слейва (`/dev/tt/<буква с 'p'+index/16><hex index%16>`) — из
   чтения C++ исходника, ни разу не исполнялись. Если f4 не может открыть
   терминал — начинать отсюда. Способ диагностики: временный `fmt.Println`
   в `pty_haiku.go` перед/после каждого `ioctl`, смотреть код ошибки.
2. **`golang.org/x/sys/unix`-шим, `Mprotect`** (`unix/haiku_amd64.go` в
   `xsys-unix-haiku.patch`) — аргументы `SYS_SET_MEMORY_PROTECTION`
   (адрес, размер, права) — по аналогии с POSIX `mprotect`, не
   подтверждено заголовками Haiku напрямую (не нашли, где эта функция
   документирована с сигнатурой). Если сработает — используется
   `ncruces/go-sqlite3` и потенциально `wazero`.
3. **`MmapPtr`/`MunmapPtr`** в том же шиме — **заведомо неполная**
   заглушка (адрес и `MAP_FIXED` игнорируются). Если f4 пытается открыть
   что-то через встроенный SQLite (плагин с базой?) — скорее всего
   сломается именно здесь. Настоящий фикс требует либо расширения
   `unxed/go` (новый экспортированный `mmap`-with-addr в
   `src/syscall`), либо переизобретения `sysvicall6`-подобного
   calling convention в самом x/sys-шиме.
4. **`--gui=x11`** — ожидаемо не подключится (у Haiku нет настоящего
   X11-сервера, только Xlibe — см. разбор в пункте 3 списка блокеров
   ниже) и должен тихо откатиться в терминальный режим. Если вместо
   отката будет падение — баг в обработке ошибки подключения, не в
   самой недоступности X11.
5. **Всё остальное** (`Poll`, `Flock`, `Open`/`Close`, `FcntlInt`,
   `Getpgid`, `Access`, `FcntlFlock`, rlimit) идёт либо через настоящие
   номера сисколов Haiku, либо напрямую делегирует в уже
   существовавшие(до нас) в korli/go функции — риск ниже, но тоже не
   проверено вживую.

## Известные ограничения инструментов (важно для следующей сессии)

- **Fine-grained GitHub PAT не может форкать/создавать репозитории** —
  для этого нужен отдельный account-level permission "Administration"
  (это НЕ то же самое, что repository-level Administration на уже
  существующих репозиториях). Форк `unxed/go` был создан пользователем
  вручную через веб-интерфейс.
- **Тот же токен не может открывать PR в чужой репозиторий** (`korli/go`)
  — fine-grained PAT в принципе не поддерживает запись в репозитории вне
  своего аккаунта. PR korli/go#2 тоже создан пользователем вручную; текст
  заголовка/описания для него был подготовлен в чате и передан пользователю
  для вставки.
- Оба ограничения не про эту задачу конкретно, а про сам тип токена —
  учитывать при планировании похожих задач (форк+PR в сторонний репозиторий)
  в будущем.

---

## Подробный разбор пройденных блокеров (полная история для справки)

Контекст ниже — то, как именно нашли и починили каждую проблему, с
доказательствами (откуда взято каждое значение). Полезно, если что-то
из чек-листа выше не сработает и нужно понять, почему было принято именно
такое решение.

### Тулчейн

У апстрим Go нет нативной поддержки `GOOS=haiku` (предложение
golang/go#56224 закрыто как "not planned"). Реальный порт жил в
`github.com/korli/go`, ветка `golang-1.26-haiku` — именно из него HaikuPorts
тянет исходники для пакета `golang` (см. `dev-lang/golang/golang-*.recipe` в
haikuports/haikuports). Тулчейн собирается кросс-компиляцией **на обычном
линуксовом раннере**: `make.bash` создаёт хостовые инструменты
(компилятор, линкер) под linux/amd64, но с поддержкой генерации кода под
`GOOS=haiku` в `src/runtime`/`src/syscall`. Прогонять результат на
настоящей Haiku не требовалось для того, чтобы "добиться сборки" — нужен
был успешный `go build` с `GOOS=haiku`. Сборка форсируется через
`GOTOOLCHAIN=local`, чтобы `go build` не попытался тихо скачать ванильный
(не-haiku) тулчейн поверх нашего.

### Список блокеров по мере появления в логах CI

1. **Пайплайн маскировал реальный провал.** `go build ... | tee log`
   возвращал код возврата `tee` (всегда 0), а не `go build`. Первый
   "зелёный" прогон был ложным. Исправлено: `set -o pipefail` во всех
   шагах со сборкой.
2. **`go.mod` требует `go >= 1.26.6`**, а ветка `golang-1.26-haiku`
   korli/go на момент работы была синхронизирована только с апстримным
   `go1.26.2`. Решено по-настоящему, а не хаком с переопределением
   `VERSION`: форкнули `korli/go` → **github.com/unxed/go**, в ветке
   `golang-1.26-haiku` смержили тег `go1.26.6` из `golang/go`
   `release-branch.go1.26` (чистый мердж, без конфликтов с
   haiku-специфичными коммитами — 50 апстримных коммитов, 132 файла,
   в основном `net/`, `os` (правки Root API), `runtime`, тестовые
   фикстуры). Ветка запушена в `unxed/go`, отправлен PR апстриму в
   `korli/go` (korli/go#2). CI клонирует `unxed/go`, а не `korli/go`,
   до мерджа PR.
3. **`github.com/unxed/vtui` тянет `goffi` (GPU/FFI без cgo) безусловно
   для haiku**, а `goffi/internal/fakecgo` (мост потоков/TLS без cgo)
   вообще не имеет реализации под Haiku — это отдельный, сравнимый по
   объёму с самим Go-портом, кусок работы. Обошли: в vtui GPU-бэкенд
   (`gogpu_*.go`) и связанные списки (`gui_font*.go`, `x11_*.go`,
   `gui_boxdraw*.go`) включают/выключают платформы по явному списку OS;
   haiku в них не было вообще (ни в allow-, ни в deny-списках) — из-за
   этого GPU-код **включался** по умолчанию (баг), а X11/шрифты
   **выключались** без запасного варианта (тоже баг, другого рода).
   Патч `patches/vtui-haiku.patch` ставит haiku ровно туда же, где уже
   стоят illumos/solaris в каждом из этих списков: без GPU-бэкенда
   (используется stub, как у прочих нишевых юниксов), но с
   *компилируемой* поддержкой X11 и инвентаризации шрифтов (там всё на
   чистом Go, без нативных зависимостей — как и у illumos/solaris).
   Патч применяется в CI к временному клону `vtui` на версии,
   закреплённой в `f4/go.mod` (сама версия в go.mod у f4 не трогается
   — просто `go mod edit -replace` на пропатченный локальный чекаут).

   **Важная оговорка про X11 на Haiku** (не техническая, а
   фактическая): нативный GUI Haiku — это `app_server`/`BWindow`/
   `BView` (наследие BeOS), не X11. У Haiku нет packaged X11-сервера
   — есть только "Xlibe", транслирующая вызовы Xlib-приложений прямо
   в native app_server, а не поднимающая сетевой X11-протокол поверх
   сокета. `internal/gui`'s X11-бэкенд у f4 говорит именно по
   протоколу (`jezek/xgb`, чистый Go), и ему нужен настоящий X-сервер
   на другом конце — которого на типичной установке Haiku нет. Поэтому
   `--gui=x11` на Haiku скомпилируется, но в рантайме просто не
   подключится и код откатится в терминальный режим — **точно так же,
   как уже происходит на headless Linux без X-сервера** (штатно
   поддерживаемый случай, не новая проблема). Родной бэкенд под
   `app_server`/`BWindow` — это отдельный, гораздо больший проект
   (взаимодействие с C++ API Haiku, скорее всего через cgo/небольшую
   C-обвязку), сознательно вне скоупа текущего прохода.

4. **`golang.org/x/sys/unix` вообще не знает про `GOOS=haiku`** — блокировало
   `unxed/vtinput` (чтение клавиатуры через `poll`), `wazero` и
   `ncruces/go-sqlite3` (`mmap`/`mprotect`), `google.golang.org/grpc`
   (`setsockopt`), плюс отдельно `syscall.EBADFD` в `spf13/afero` и
   два `undefined` в `pkg/sftp` (`fileStatFromInfoOs`, `lsLinksUIDGID`) —
   не из x/sys, а из собственных per-OS файлов этих пакетов.
   Решение — минимальный шим, не полный порт x/sys/unix:
   - `patches/xsys-unix-haiku.patch` — новый файл `unix/haiku_amd64.go`.
     `Poll` и `Mprotect` идут через настоящие номера сисколов Haiku
     (`SYS_POLL=127`, `SYS_SET_MEMORY_PROTECTION=206` — есть в
     `github.com/korli/go` `src/syscall/zsysnum_haiku_amd64.go`) через
     уже экспортированный `syscall.Syscall`. `Mmap`/`Munmap`/
     `SetsockoptInt` — тонкие обёртки над уже существующими
     `syscall.Mmap`/`Munmap`/`SetsockoptInt` (эти зовут `libroot.so`/
     `libnetwork.so` динамически — так на Haiku устроены сами эти
     вызовы, не сырые сисколы). Значения `PROT_*`/`MAP_*`/`SOL_SOCKET`/
     `SO_KEEPALIVE` скопированы из `zerrors_haiku_amd64.go` (реального,
     сгенерированного из хедеров Haiku), а не придуманы. `Getpagesize`
     захардкожен в 4096 (реальный page size Haiku/x86_64).
     Не проверено на живой Haiku только направление аргументов
     `SYS_SET_MEMORY_PROTECTION` (по аналогии с POSIX `mprotect`) — как
     и везде в этом проекте, риск чисто рантаймовый, не блокирует сборку.
     `Dup2` — тонкая обёртка над `syscall.Dup2` (уже есть в форке).
     `MmapPtr`/`MunmapPtr` (для `ncruces/go-sqlite3`) — честно слабее
     остального шима: реальный маппинг по конкретному адресу с
     `MAP_FIXED` требует того же динамического вызова через `libroot.so`
     (`sysvicall6`), до которого отсюда не дотянуться без дублирования
     чужого calling convention (см. отказ от `goffi/internal/fakecgo`
     выше). Сейчас это заглушка: адрес и `MAP_FIXED` игнорируются, идёт
     обычный `Mmap` — компилируется, но растущий mmap-регион SQLite
     (`MappedRegion`) при реальном запуске на Haiku, скорее всего,
     сломается. Помечено как известный, не просто непроверенный, пробел.
   - **Первая версия `patches/zip-haiku.patch` была ошибочной**: пыталась
     обойти `unix.Fchmodat`/`AT_SYMLINK_NOFOLLOW`/`unix.Lutimes` веткой
     `if runtime.GOOS == "haiku"` — но это runtime-проверка, а не build
     tag, и компилятор всё равно типизирует `else`-ветку целиком для
     любой ОС. Правильная версия: `lchmod`/`lchtimes` вынесены из
     `fs_unix.go` в `fs_chmod_unix.go` (`!windows && !haiku`, старое
     поведение без изменений) и `fs_chmod_haiku.go` (`haiku`,
     `os.Chmod`/`os.Chtimes` — Haiku, как и Linux, не различает права
     символьной ссылки и цели, так что no-op для симлинков плюс обычный
     `os.Chmod`/`os.Chtimes` эквивалентен старому поведению).
   - `patches/afero-haiku.patch` — haiku переставлен из
     `const_win_unix.go` (`syscall.EBADFD`, которого в haiku-порте нет) в
     `const_bsds.go` (`syscall.EBADF`, который есть) — так же, как уже
     сделано для aix/darwin/BSD.
   - `patches/sftp-haiku.patch` — haiku добавлен в allow-листы
     `attrs_unix.go`/`ls_unix.go` рядом с solaris (структура `Stat_t` в
     korli/go имеет нужные поля `Uid`/`Gid`).

5. **`syscall.Stat_t.Ino` в haiku-порте korli/go имеет тип `int64`**, а не
   `uint64`, как везде — ломает код, который кладёт `stat.Ino` в
   `uint64`-поле без явного приведения. Нашли два места:
   `patches/wazero-haiku.patch` (`internal/sysfs/ino_unix.go`,
   `sys.Inode` — это alias на `uint64`) и `patches/archives-haiku.patch`
   (`hardlink_unix.go`, свой репозиторий unxed/archives, закреплённый в
   go.mod по коммиту, а не тегу — клонируется и патчится тем же
   способом, без изменений в реальном репозитории). Оба патча — просто
   явное приведение `uint64(stat.Ino)`, безопасно для всех остальных ОС
   (там это no-op reinterpret того же размера).

6. **Дошли до кода самого f4** (`patches/f4-haiku.patch`, применяется к
   эфемерному CI-чекауту f4, реальный репозиторий не трогается):
   `vfs/os_vfs_posix_atim.go` (`fillPlatformTimes`),
   `vfs/rename_noreplace_unix.go` (`renameNoReplace`) и
   `plugins/cloudfox/store_lock_unix.go` (`tryAdvisoryFileLock`, через
   `unix.Flock`) — те же allow-листы по OS, что уже видели у
   vtui/sftp. Haiku добавлен во все три: поля `Atim`/`Ctim` у `Stat_t`
   в korli/go называются так же, как у
   linux/openbsd/dragonfly/solaris/illumos (проверено по
   `ztypes_haiku_amd64.go`), атомарного no-clobber rename у Haiku, как
   и у этой группы, тоже нет (тот же портативный
   `renameNoReplacePortable`, без build tag), а `flock(2)` — снова
   настоящий номер сисколла Haiku (`SYS_FLOCK=113`), добавлен в шим
   x/sys тем же способом, что `Poll`/`Mprotect`.
   Отдельно `patches/tar-haiku.patch` — у `unxed/tar` та же ошибка, что
   была у `zip` (`lchtimes` через `unix.Lutimes`/`NsecToTimeval`), тем
   же способом: вынесена в `sys_chtimes_unix.go`/`sys_chtimes_haiku.go`
   по build tag. Здесь `lchtimes` не различает симлинк/файл по сигнатуре
   (нет параметра `mode`), поэтому haiku-версия просто зовёт
   `os.Chtimes` — тот же нюанс "следует за симлинком", что уже отмечен
   у `zip`.

7. **Добавлены `unix.Access`/`unix.Errno`/`unix.Flock_t`/`unix.FcntlFlock`
   и коды ошибок** в тот же шим x/sys (нужны `ncruces/go-sqlite3/vfs`
   для advisory file locking) — все делегируют в уже существующие
   `syscall.Access`/`syscall.FcntlFlock`/`syscall.Flock_t` (продвинутый
   `fcntl` locking для Haiku в форке уже есть, реальный динамический вызов
   через `libroot.so`, тот же механизм, что у `mmap`/`setsockopt`).
   `R_OK`/`W_OK`/`X_OK`/`F_OK` — единственное в этом шиме, что не взято
   из сгенерированного `zerrors_haiku_amd64.go` (там их просто нет, они
   Go-рантайму не были нужны), а захардкожено как POSIX-стандартные
   значения — эти биты одинаковы буквально везде.

8. **Дошли до `internal/terminal`** — как и предполагалось с самого
   начала, ни один `pty_*.go` не подключался под haiku. По пути
   всплыли `unix.Rlimit`/`Getrlimit`/`RLIMIT_NOFILE` (в
   `pty_diag_unix.go`) и `unix.FcntlInt`/`F_SETFD`/`F_GETFL`/`F_SETFL`/
   `FD_CLOEXEC` (в `session_unix.go`, для close-on-exec и снятия
   `O_NONBLOCK` с унаследованных дескрипторов).
   - `Rlimit`/`Getrlimit`/`RLIMIT_NOFILE` — тонкие обёртки над уже
     существующими `syscall.*` (реальный динамический вызов, как и
     `Access`/`FcntlFlock`).
   - `FcntlInt` **не был доступен уже сгенерированным иначе** — в
     korli/go есть только приватная (нижний регистр) функция `fcntl`,
     а обёртки над ней для целого `int`-аргумента (в отличие от
     `FcntlFlock` для `*Flock_t`) просто не было. Раз это наш
     собственный форк (`unxed/go`), добавили туда экспортированную
     `FcntlInt` прямо в `src/syscall/syscall_haiku.go` (тривиальная
     обёртка над уже правильной приватной `fcntl`, тот же коммит можно
     будет предложить апстриму отдельным PR). Шим x/sys делегирует в
     неё; `SetNonblock` — просто `F_GETFL`+`F_SETFL` через ту же
     `FcntlInt`.
   - `Open`/`Close` — настоящие сисколы Haiku (`SYS_OPEN=107`,
     `SYS_CLOSE=151`), как `Poll`/`Mprotect`/`Flock`.
   - `TIOCGWINSZ`/`TIOCSWINSZ`/`TIOCGPGRP`/`TIOCSPGRP`/`TIOCSCTTY` —
     реальные значения из `headers/posix/termios.h` в исходниках самой
     Haiku (github.com/haiku/haiku), не догадка.
   - **`internal/terminal/pty_haiku.go`** (новый файл, добавлен в
     `patches/f4-haiku.patch`) реализует `NewPTY()`/`GetSystemShell()`
     по образцу `pty_linux.go`, но выделение PTY взято **дословно из
     реального исходника Haiku**
     `src/system/libroot/posix/stdlib/pty.cpp` (не придумано): открыть
     `/dev/ptmx`, `ioctl(fd, B_IOCTL_GRANT_TTY)`,
     `ioctl(fd, B_IOCTL_GET_TTY_INDEX, &index)`, слейв —
     `/dev/tt/<буква><hex-цифра>` (буква с `'p'+index/16`, цифра —
     `index%16`); `unlockpt` на Haiku — no-op, отдельного шага нет.
     Численные значения обоих кастомных ioctl'ов (`B_IOCTL_GET_TTY_INDEX`,
     `B_IOCTL_GRANT_TTY`) высчитаны из `headers/private/drivers/tty.h`
     (`TCGETA+32`, `TCGETA+33`) — тоже из реальных заголовков Haiku, а
     не подобраны. Также по пути обнаружилось и починено: `syscall.Getpgid`
     в korli/go не было вообще (был только `Setpgid`) — добавлено в
     `unxed/go` тем же способом, что `FcntlInt`.

9. **`internal/app/bootstrap.go` безусловно (без build tag) зовёт
   `gui.RunGui(...)`** — то есть какая-то реализация `RunGui` нужна
   под haiku в любом случае, вне зависимости от того, действительно ли
   там будет работать GUI. `internal/gui/run_unix.go` и
   `internal/gui/icon_unix.go` — те же allow-листы по OS, что уже
   видели много раз; haiku добавлен рядом с illumos/solaris.
   `internal/gui/backend_ffi.go`/`backend_stub.go` — тут отдельный,
   уже правильно устроенный allow/deny (FFI только под
   windows/{linux,darwin,freebsd}×{amd64,arm64}) — haiku и без правки
   уже корректно падает в `backend_stub.go`, т.е. GPU/FFI GUI на haiku
   не участвует вообще, только X11-путь через `run_unix.go`. Про то,
   почему X11 на Haiku не нативен и чего от него ожидать в рантайме —
   см. оговорку в пункте 3 выше.

**Финальный успешный прогон:**
[unxed/sandbox actions run 35353337728](https://github.com/unxed/sandbox/actions/runs/35353337728)
— все 9 патчей + два доп. коммита в `unxed/go` (`FcntlInt`, `Getpgid`),
job `build-toolchain-and-f4` зелёный, артефакт `f4-haiku-amd64` подтверждён
как настоящий Haiku ELF (`interpreter /system/runtime_loader`).

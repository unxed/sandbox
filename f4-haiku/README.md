# f4 → Haiku OS port (sandbox)

Цель: добиться сборки `github.com/unxed/f4` (кроссплатформенный TUI-файловый
менеджер на Go) под `GOOS=haiku GOARCH=amd64`.

Вся сборка выполняется **только в GitHub Actions** этого репозитория
(`.github/workflows/f4-haiku.yml`) — локально в рабочей среде ничего не
собирается и не компилируется, только правки исходников/патчей здесь и в
самом f4 (по договорённости).

## Контекст

- У апстрим Go нет нативной поддержки `GOOS=haiku` (предложение
  golang/go#56224 закрыто как "not planned"). Реальный порт живёт в форке
  **github.com/korli/go**, ветка `golang-1.26-haiku`, и именно из него
  HaikuPorts тянет исходники для пакета `golang` (см.
  `dev-lang/golang/golang-*.recipe` в haikuports/haikuports).
- Тулчейн собирается кросс-компиляцией **на обычном линуксовом раннере**:
  сборка `make.bash` создаёт хостовые инструменты (компилятор, линкер) под
  linux/amd64, но с поддержкой генерации кода под `GOOS=haiku` в
  `src/runtime`/`src/syscall`. Реально прогонять результат на настоящей
  Haiku не требуется для того, чтобы "добиться сборки" — нужен успешный
  `go build` с `GOOS=haiku`.
- Сборка форсируется через `GOTOOLCHAIN=local`, чтобы `go build` не
  попытался тихо скачать ванильный (не-haiku) тулчейн поверх нашего, если
  `go.mod` попросит версию новее той, что мы собрали.

## Пройденные блокеры (по логам реальных прогонов CI)

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
   `korli/go` (см. github.com/unxed/go/tree/golang-1.26-haiku). CI
   теперь клонирует `unxed/go`, а не `korli/go`, до мерджа PR.
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
   (используется stub, как у прочих нишевых юниксов), но с полной
   поддержкой X11 и инвентаризации шрифтов (там всё на чистом Go, без
   нативных зависимостей — как и у illumos/solaris). Патч применяется
   в CI к временному клону `vtui` на версии, закреплённой в `f4/go.mod`
   (сама версия в go.mod у f4 не трогается — просто `go mod edit
   -replace` на пропатченный локальный чекаут).

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

## Статус

Ждём лог прогона со всеми семью патчами (vtui, x/sys, zip, afero, sftp,
wazero, archives) поверх тулчейна `unxed/go`. Дальше — по тому же
принципу: реальная
ошибка компиляции → патч (в `patches/`, не напрямую в чужие
репозитории) → коммит → новый прогон. Ожидаем следующий блокер в
собственном коде f4 (`internal/terminal/pty_*.go` — ни один файл там
пока не подключается под `GOOS=haiku`, `NewPTY` будет undefined).

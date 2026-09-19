# sandbox: работа, которая собирается и проверяется только в GitHub Actions

Песочница для портирования Go и f4 на экзотические ОС. Локально ничего не собирается и не запускается:
сборка, запуск виртуалок и проверки идут в GitHub Actions (workflows в `.github/workflows/` и в `unxed/go`).

## Проекты

| Папка | Что это |
|---|---|
| `go-redox/` | Порт Go 1.26.6 под `GOOS=redox` (снимок ветки `golang-1.26-redox` из `unxed/go`: серия для `git am`, дифф, список проблем для апстрима; обновляется автоматически) |
| `f4-redox/` | f4 на Redox OS: сборка, запуск в консоли, в терминале Orbital и по X11 через сеть, скриншоты, сценарии; бинарник в релизе `f4-redox-latest` |
| `go-hurd/`, `f4-hurd/` | Порт Go под `GOOS=hurd` и f4 на GNU Hurd (снимки работы другой сессии) |
| `f4-haiku/` | f4 на Haiku OS |
| `vmlab/` | Инструмент и рецепт: тесты на разных ОС (в том числе с графикой) и разработка прямо в CI: сессия с виртуалкой, клики, клавиши, скриншоты, снимки состояния, сценарии |

## Патчи для апстрима (GitLab Redox), готовые к отправке

Каждая папка: патч в формате `git am` (`0001-*.patch`), `ISSUE.md` (текст issue) и `README.md`
(цифры проверки и ссылки на прогоны CI). Патчи проверены командой `git am` на базовом коммите апстрима,
каждый применяется на базу отдельно, серии целиком тоже. Открыть issue и MR на
`gitlab.redox-os.org` можно только с аккаунта владельца: у меня доступа туда нет.
Проверочные workflows: `redox-relibc-patches` и `redox-kernel-verify` в `unxed/go`.

**relibc** (https://gitlab.redox-os.org/redox-os/relibc, база `69bb008af1`), порядок для серии:

1. `relibc-sigentry-rcx/`: `sigentry` затирает RCX прерванного кода номером сигнала (другой файл, чем у остальных; ветка с тем же коммитом: `unxed/relibc`, `fix-sigentry-rcx-clobber`)
2. `relibc-spawn-cloexec/`: `posix_spawn` не закрывает close-on-exec дескрипторы в потомке
3. `relibc-poll-regular-files/`: `poll()` падает целиком, если среди fd есть обычный файл
4. `relibc-pthread-sigmask/`: новый поток стартует с пустой маской сигналов
5. `relibc-spawn-child-table-size/`: `posix_spawn` с `EMFILE` при параллельных дескрипторах
6. `relibc-spawn-clone-lock/`: `posix_spawn` должен брать `CLONE_LOCK`, как `fork` (зависания при параллельном spawn)

**ядро Redox** (https://gitlab.redox-os.org/redox-os/kernel, база `2d2eef7`), порядок для серии:

1. `kernel-forcekill-lost-wakeup/`: потерянное пробуждение ForceKill (зависания при выходе процесса), версия v3
2. `kernel-futex-cow-wake/`: `fork` с CoW теряет пробуждения futex
3. `kernel-try-stop-context-resurrect/`: `try_stop_context` воскрешает умерший контекст (паника в `exit_this_context`)

Как подать один патч:

    git clone https://gitlab.redox-os.org/redox-os/relibc && cd relibc   # или .../kernel
    git checkout -b fix-NAME 69bb008af1                                 # для ядра: 2d2eef7
    git am /путь/к/0001-*.patch
    git push <ваш форк> fix-NAME                                        # затем MR в GitLab; текст issue: ISSUE.md

Отозванных патчей в папках нет. Список всех найденных проблем (с тестами-репродьюсерами и статусами)
лежит в `go-redox/upstream-issues.md`.

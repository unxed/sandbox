# Go → Redox OS (снимок работы, сохранён в песочнице)

Порт Go 1.26.6 под `GOOS=redox GOARCH=amd64`. Живая ветка: https://github.com/unxed/go/tree/golang-1.26-redox
(форк korli/go; база — коммит `a91d0c4068b9a20cda0f92dff302321148856f53`, тот же, от которого отходит `golang-1.26-hurd`).
Собирается и проверяется только в GitHub Actions (workflow `redox-cross-build` и др. в unxed/go), локально ничего не собиралось.

Актуальная голова ветки и число коммитов записаны в `HEAD.txt` (файл обновляется автоматически вместе со снимком).

## Что здесь

- `golang-1.26-redox.mbox` — серия из 72 патчей для `git am` поверх `a91d0c4068b9a20cda0f92dff302321148856f53`:
  `git checkout -b redox a91d0c4068b9a20cda0f92dff302321148856f53 && git am golang-1.26-redox.mbox`
- `golang-1.26-redox.diff` — то же одним диффом.
- `upstream-issues.md` — копия списка найденных проблем relibc/ядра Redox (с репродьюсерами и прогонами CI).
- Обновляется автоматически: workflow `go-redox-snapshot` (раз в 3 часа и по запросу) пересобирает файлы из ветки
  и коммитит сюда, если ветка изменилась.

Связанное в этом репозитории: `relibc-sigentry-rcx/` и `kernel-forcekill-lost-wakeup/` (патчи для GitLab в формате `git am`),
`f4-redox/` (f4 на Redox), `vmlab/` (быстрый цикл с виртуалкой и скриншотами, инструкция — `vmlab/README.md`).

## Состояние

Работает на Redox под QEMU/KVM: fmt, os, горутины, GC, таймеры, файловый ввод-вывод, os/exec (через posix_spawn),
net (loopback TCP/UDP), os/signal, часовые пояса, encoding/json, cgo (redoxer gcc), стандартные тесты
strings/bytes/sort/container/list/json/sync/time. f4 запускается (консоль, терминал Orbital, X11 по сети).

Открыто: см. `upstream-issues.md` (паника ядра при параллельном posix_spawn, зависание p14_exec, time_preempt,
асинхронное вытеснение выключено из-за баги relibc sigentry до выхода исправленного образа).

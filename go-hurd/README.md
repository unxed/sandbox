# Go → GNU Hurd (снимок работы, сохранён в песочнице)

Нативный порт Go 1.26.6 под `GOOS=hurd GOARCH=amd64`. Живая ветка: https://github.com/unxed/go/tree/golang-1.26-hurd
(форк korli/go; база — коммит `a91d0c4068b9a20cda0f92dff302321148856f53`, тот же, от которого отходит `golang-1.26-redox`).
Песочница с образом Debian GNU/Hurd под QEMU: https://github.com/unxed/debian-hurd (бинарные тесты и f4 лежат в `poc/`).
Собирается и проверяется только в GitHub Actions (`hurd-cross-build`, `hurd-f4-build` в unxed/go; `run-hurd-poc` в unxed/debian-hurd), локально ничего не собиралось.

Снимок на 2026-09-19, голова ветки `d547d62ef631e332c163787ff69caae95026cbe1` (48 коммитов поверх базы).

## Что здесь

- `golang-1.26-hurd.mbox` — серия патчей для `git am` поверх базы:
  `git checkout -b hurd a91d0c4068b9a20cda0f92dff302321148856f53 && git am golang-1.26-hurd.mbox`
- `golang-1.26-hurd.diff` — то же одним диффом. `HEAD.txt` — голова ветки на момент снимка.
- `STATUS-HURD.md` — журнал: дизайн, измеренные на реальном Hurd факты, найденные баги.
- `tests/` — Go-программы, которые гоняются на Hurd (t_os, t_fmt, t_fs, t_rt, t_net, t_http, t_exec, t_sig, t_panic, t_threads).
- `probes/` — C-пробники и харнесс: `mkhurd.sh` + `mkztypes_hurd.c` (генерируют zerrors/ztypes в госте из реальных заголовков),
  `ctx_poc.c` (правки ucontext в обработчике сигнала), `pty_poc.c`, `thr_poc.c` (лимит потоков), `loop_tests.sh`, `run_poc.py`, `run-hurd-poc.yml`.

## Состояние (проверено на реальном Hurd под QEMU/KVM)

fmt, os, файлы/каталоги/pipe, горутины, таймеры, GC; net (TCP/UDP/unix-сокеты на loopback, дедлайны, net/http, чистый Go-резолвер);
os/exec (fork+exec из многопоточного процесса); os/signal; panic от аппаратных сбоев (nil, дикий адрес); `go build std` без ошибок.
f4 запускается (консоль: панели, встроенный терминал, выход) — см. `../f4-hurd/`.

## Известные ограничения и находки

- **Асинхронное вытеснение выключено** (`preemptMSupported = GOOS != "hurd"`): SIGURG-вытеснение давало плавающие сбои даже после
  исправлений. glibc Hurd (а) отдаёт обработчику *копию* ucontext, `__sigreturn` восстанавливает регистры из `struct sigcontext`
  (решено: `sigtrampgohurd` пишет изменения обратно), (б) выбирает альтернативный стек по флагу `SS_ONSTACK`, а не по SP
  (решено: тот же враппер подменяет сигнальный стек). Причина остаточных сбоев не найдена.
- Стек потока glibc по умолчанию — 8 МБ committed: ~236 потоков на 2 ГБ; рантайм задаёт 1 МБ.
- errno на Hurd — Mach-коды `0x4000xxxx`; `getdirentries()` = ENOSYS (каталоги через fdopendir/readdir_r); libc-адреса динамических
  импортов можно брать только в коде (не в таблицах данных) и только внутри пакета `syscall`.
- `golang.org/x/sys/unix` под gc/hurd нет — в `../f4-hurd/xsys-unix` временная подмена.

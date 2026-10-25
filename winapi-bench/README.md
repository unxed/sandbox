# winapi-bench

Измерение (не изменение): сколько стоит вызов экспорта Go-DLL из нативного не-Go потока на Windows
в сравнении с нативными вызовами Windows (user-mode, syscall, win32k).

Контекст: оценка осуществимости Win32-слоя на Go (общий Go-образ + тонкие PE-стабы). Если цена перехода
в Go сопоставима с ценой syscall/win32k, быстрый слой на ассемблере/Rust нужен только для самых горячих путей.

Запуск: `workflow_dispatch` или push в `winapi-bench/**`. Результат: лог шага Run и Job Summary.
Файлы: `lib.go` (экспорт `Nop`), `bench.c` (harness, `LoadLibrary` + `GetProcAddress`).

Не измерено (за рамками): PE-загрузчик, SEH, GC-паузы, вызовы из Go-созданных потоков.

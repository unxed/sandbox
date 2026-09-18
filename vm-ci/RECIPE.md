# Рецепт: тесты на разных ОС (в том числе с графикой) и разработка прямо в CI GitHub

Проверено 2026-09-18 на гостевой ОС Redox (образ desktop, ядро `2d2eef7`) в репозитории
`unxed/sandbox`. Инструмент — `vmlab/` (Python, только stdlib). Ничего не собирается и не
запускается локально: локально нужен только `GH_TOKEN` и HTTPS.

## Идея

Вместо «запушил → 5–10 минут CI → лог» держим в Actions **живую ВМ** и общаемся с ней
через git-ветки и GitHub API:

```
Claude / разработчик                     раннер GitHub Actions (job vmlab-session)
  vmlab/ctl.py  --PUT cmd/<run>/N.txt-->   ветка vmlab-cmd  --fetch раз в 1.5 с-->  vmlab.py
                <--GET out/N/* (blob API)-- ветка vmlab-out  <--push результата--    QEMU (KVM) + QMP
                                                                                     гость: Orbital, терминал, агент
```

* ВМ загружается **один раз** (или восстанавливается из снимка за ~3 с), потом получает
  команды: мышь, клавиатура, скриншоты, ожидание по OCR, выполнение команд в госте.
* Каждая отправленная команда дописывается в `vmlab-history.txt` — из удачного
  интерактивного прогона получается сценарий `vmlab/scenarios/<имя>.txt`, который
  воспроизводится без человека (`--scenario`).
* Итог: скриншоты (PNG) и текстовый вывод возвращаются за секунды, а не за минуты.

## Что нужно на раннере

* `ubuntu-latest` для публичного репозитория: 4 ядра, 15 ГБ ОЗУ, ~87 ГБ диска, **есть
  `/dev/kvm`**, но с правами `root:kvm 0660`. Делаем его доступным всем:

  ```yaml
  - run: |
      echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
      sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
      sudo apt-get update -qq
      sudo apt-get install -y -qq --no-install-recommends qemu-system-x86 qemu-utils tesseract-ocr zstd ovmf
  ```
* CPU на раннерах бывает разным (в наших прогонах — AMD EPYC 9V74); QEMU из apt — 8.2.
* Ограничения: job ≤ 6 ч (у нас `timeout-minutes: 60`, простой без команд 10 мин), кэш
  Actions ≤ 10 ГБ на репозиторий, репозиторий должен быть публичным (иначе минуты платные и
  KVM-раннеры могут быть недоступны).

## Файлы (в `unxed/sandbox`)

| Файл | Назначение |
|---|---|
| `vmlab/vmlab.py` | драйвер QEMU: запуск, QMP (скриншот, клавиши, мышь), шаги сценария, `savevm/loadvm`, HTTP для файлов, шина команд через git |
| `vmlab/ctl.py` | клиент: `start`, `do`, `sh`, `put`, `stop` (только HTTPS + `GH_TOKEN`) |
| `vmlab/guests/<имя>.json` | описание гостя: образ, машина, прошивка, CPU, USB, сеть |
| `vmlab/guests/redox-agent.ion` | гостевой агент (Redox): забирает `job.ion`, выполняет, загружает вывод |
| `vmlab/scenarios/*.txt` | записанные сценарии |
| `.github/workflows/vmlab-session.yml` | интерактивная сессия (workflow_dispatch; входы `guest`, `minutes`, `scenario`, `loadvm`) |
| `.github/workflows/vmlab-redox-boot.yml` | пакетный замер загрузки (KVM/TCG × BIOS/UEFI) со скриншотами в артефактах |

### Язык сценария (по строке на шаг)

`wait SEC`, `shot NAME`, `key CHORD…` (`key ctrl-alt-t`, `key ret`), `type TEXT`,
`typeln TEXT`, `click X Y [right|double]`, `move`, `drag X1 Y1 X2 Y2`,
`stable SEC [TIMEOUT]` (экран не менялся SEC секунд), `waittext REGEX [TIMEOUT]` (OCR),
`save NAME` / `load NAME` (снимок ВМ), `hmp CMD` (монитор QEMU),
`payload NAME BASE64` (положить файл для гостя), `waitupload NAME [TIMEOUT]`
(дождаться файла, загруженного гостем).

## Как пользоваться (со стороны разработчика или Claude)

```sh
export GH_TOKEN=...   # токен с правом записи в репозиторий
git clone https://github.com/unxed/sandbox && cd sandbox

python3 vmlab/ctl.py start --guest redox-uefi --minutes 60 --loadvm desk-agent   # тёплый старт из снимка
#   без снимка:  --scenario redox-desktop   (загрузка → вход → терминал → агент, ~25 с)

python3 vmlab/ctl.py sh "uname -a; ls /"                 # команда в госте, вывод текстом (без OCR), ~11 с
python3 vmlab/ctl.py put ./f4-redox-amd64 f4              # файл гостю: curl -so /tmp/f4 http://10.0.2.2:8000/f4
python3 vmlab/ctl.py do "click 120 775" "typeln /tmp/f4" "wait 3" "shot f4"   # мышь/клавиатура/скриншот
python3 vmlab/ctl.py stop
```

Скриншоты падают в `./vmlab-out/NNNN/*.png`. Файл, отправленный гостем
(`curl -T файл http://10.0.2.2:8000/имя`), приходит как `upload-имя` в каталоге результата.
Хост с точки зрения гостя — `10.0.2.2`.

Снимок создаётся шагом `save desk-agent` в живой сессии; по завершении job сам кладёт
`base.img`, `overlay.qcow2`, `OVMF_VARS.qcow2` в кэш Actions
(ключ `vmlab-snap-<гость>-<run_id>`, восстановление по префиксу — берётся новейший).

## Измерения (Redox desktop, KVM, раннер AMD EPYC 9V74)

| Что | Время |
|---|---|
| dispatch → job запущен | ~7 с |
| установка QEMU/tesseract/ovmf (apt) | ~12 с |
| загрузка образа `.zst` 146 МБ (первый раз) | секунды |
| после Enter в загрузчике → экран входа Orbital | ≤ 5 с (KVM), 5–10 с (TCG, шаг замера 5 с) |
| холодный старт: вход + терминал + агент (сценарий) | ~25 с |
| `save NAME` (снимок ВМ) | 1.3–3 с, кэш ≈ 274–306 МиБ |
| восстановление кэша + `-loadvm` | 5 с + 3 с |
| **dispatch → первая команда с текстовым ответом (тёплый старт)** | **≈ 36 с** |
| команда в уже идущей сессии: скриншот / `sh` | 4–8 с / ≈ 11 с |
| старый способ (`redoxer exec` в docker на TCG) | ≈ 1 мин на каждую загрузку |

Вывод: Redox грузится быстро даже без KVM; «минута на запуск» была накладными расходами
docker/сборки образа. KVM нужен для тяжёлых нагрузок внутри гостя (компиляция, GC-нагрузка,
таймеры), а не для загрузки.

Ввод в терминал Cosmic медленный (~20 символов/с): длинные команды не набираем, а
отправляем через `put`/`sh`.

## Грабли, на которые уже наступили

1. `static.redox-os.org` отвечает 403 на User-Agent `Python-urllib` (Cloudflare) — ставим
   `curl/8.5.0`.
2. `git fetch --depth 1 origin vmlab-cmd:refs/remotes/...` без `+`: после сдвига ветки
   fetch отвергается как non-fast-forward, исполнялась только первая команда сессии.
   Нужен refspec `+vmlab-cmd:...`.
3. Contents API репликуется с задержкой: свежий файл может 404-ить десятки секунд. Скачиваем
   по `git/blobs/<sha>` (sha берём из листинга каталога).
4. Ветки `vmlab-cmd`/`vmlab-out` рассчитаны на **одну сессию на шину**: вторая сессия при
   старте делает force-push в `vmlab-out` и затирает результаты первой. Для параллельных
   гостей есть переменная `VMLAB_BUS` (вход `bus` у workflow): у каждой шины свои ветки.
   `ctl.py` ждёт, пока `SESSION` в ветке результатов станет равен id своего запуска (иначе
   читал результаты предыдущей сессии).
5. UEFI: `savevm` падает с «Device 'pflash1' is writable but does not support snapshots» —
   переменные OVMF нужно держать в qcow2 (`qemu-img convert -O qcow2`, `format=qcow2`).
6. Снимок привязан к модели CPU: `-cpu host` переносим только между одинаковыми хостами.
   Задаём фиксированную модель в JSON гостя. Для Redox `Nehalem` **не подходит** (нет AVX2:
   `cosmic-term` не открывается, экран остаётся рабочим столом), берём `Haswell-noTSX`.
   Проверено на одном типе CPU; кросс-вендорное восстановление (Intel ↔ AMD) не проверялось.
7. Загрузчик Redox (и BIOS, и UEFI) ждёт Enter в меню разрешения — без `key ret` экран
   статичен и кажется «зависшей загрузкой».
8. Оболочка Redox — `ion`, не POSIX: `&>` для обоих потоков, нет `2>&1`; `curl` есть;
   `curl` в stderr шумит строками `TODO: setsockopt ... unknown option` — безвредно.
9. Redox: пользователь `user` с пустым паролем, `root`/`password`; USB-планшет
   (`qemu-xhci` + `usb-tablet`) работает в Orbital (абсолютные координаты), клавиатура — PS/2.
10. `hashFiles()` в GitHub Actions не видит файлы вне рабочего каталога — признак
    «снимок сохранён» передаём через `$GITHUB_OUTPUT`.
11. Образ Redox: `static.redox-os.org/img/x86_64/` хранит только текущую ночную сборку;
    имя файла ищется регуляркой по листингу (`image_index` + `image_regex` в JSON гостя).
    Для воспроизводимости снимков базовый образ кэшируется вместе с overlay.

## Безопасность канала управления

* Команды исполняются только от имени тех, кто может писать в репозиторий (запись в ветку
  `vmlab-cmd`, `workflow_dispatch`). Форки не могут запустить сессию.
* Токен job — `GITHUB_TOKEN` с `contents: write` (нужен для push в `vmlab-out`). Он лежит в
  окружении шага сессии, но **не в госте**: гость видит только `10.0.2.2:8000` (каталог
  `payload/` на чтение, `PUT` в каталог `upload/`).
* Шаг `hmp` даёт сырой монитор QEMU — считайте управление сессией эквивалентным доступом к
  раннеру; секретов в репозиторий/гостя не кладём.
* В публичном репозитории скриншоты и логи в `vmlab-out` читает кто угодно: ничего
  чувствительного в госте не вводить.

## Как подключить другую ОС (Haiku, Hurd и др.)

Достаточно нового `vmlab/guests/<имя>.json` (уже поддерживаются ключи `image_url` или
`image_index`+`image_regex`, `image_kind` = `zip`|`zst`|raw, `machine`, `firmware`
(`uefi`), `cpu`, `ram`, `smp`, `nic`, `usb`, `qemu_extra`).

* **Haiku** — уже есть `vmlab/guests/haiku.json` (nightly `anyboot.zip`, `pc-i440fx`, IDE).
  Сценарии и горячие клавиши записываются так же; вывод команд — через терминал Haiku и
  `curl -T` на `10.0.2.2:8000`, если в образе есть `curl`.
* **Hurd** — образы Debian GNU/Hurd (qcow2, i386/amd64) грузятся с текстовой консолью:
  скриншот полезен как контроль, а надёжнее читать serial-лог (`-serial file:` уже
  пишется в `/tmp/vmlab/serial.log`) и слать команды на консоль клавишами `typeln`.
  Нужен `image_kind` для qcow2 (достаточно raw-копирования, добавляется одной веткой в
  `fetch_image`), и, скорее всего, `machine: pc`, `disk_if`/`nic` как у образа.
* Для каждой новой ОС: подобрать `cpu` для переносимых снимков, проверить, что все
  устройства мигрируемы (`savevm` ругается на немигрируемые — тогда без снимка или с
  другим контроллером диска), записать сценарий загрузки, положить гостевой агент
  (у Redox — `.ion`; у POSIX-систем достаточно `sh`-цикла `curl` → `sh job` → `curl -T`).

## Что дальше можно улучшить

* Сравнить переносимость снимка между Intel и AMD раннерами.
* Кэш готового Go-тулчейна и сборок уже делает `f4-redox` (ключи `redox-go-<sha>`,
  `gobuild-f4redox-*`) — использовать оттуда, не дублировать.
* Несколько агентов на одном госте: сейчас одна сессия на шину (см. грабли №4); решение —
  путь результатов с id сессии вместо одной ветки результатов.

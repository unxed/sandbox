# vmlab: тесты на разных ОС (в том числе с графикой) и разработка прямо в CI GitHub

Проверено 2026-09-18 на гостевой ОС Redox (образ desktop, ядро `2d2eef7`) в репозитории
`unxed/sandbox`. Инструмент — этот каталог (Python, только stdlib). Ничего не собирается и не
запускается локально: локально нужен только `GH_TOKEN` и HTTPS. Все команды ниже выполняются из
корня репозитория. Раньше этот текст лежал в `vm-ci/RECIPE.md`; каталог `vm-ci/` убран, чтобы
код и инструкция к нему не жили в двух местах.

Гости, на которых это уже работало: **Redox** (рабочий стол Orbital, интерактивно и пакетно) и
**Haiku** (пакетный регресс f4 после каждой сборки, интерактивная сессия). Про Haiku подробнее —
в [`f4-haiku/README.md`](../f4-haiku/README.md), про Redox — в [`f4-redox/README.md`](../f4-redox/README.md).

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
| `vmlab/guests/haiku-agent.sh` | гостевой агент (Haiku): то же самое для `job.sh` |
| `vmlab/scenarios/*.txt` | записанные сценарии (`redox-*`, `f4-redox-*`, `haiku-*`) |
| `vmlab/haiku/` | гостевые скрипты и инструменты Haiku: `smoke.sh`, `regress-check.sh`, `ptyrun/` (PTY-харнесс), `vtdump.py`, `sgrtest*.sh` |
| `.github/workflows/vmlab-session.yml` | интерактивная сессия (workflow_dispatch; входы `guest`, `minutes`, `scenario`, `loadvm`, `bus`, `xvfb`) |
| `.github/workflows/vmlab-redox-boot.yml` | пакетный замер загрузки (KVM/TCG × BIOS/UEFI) со скриншотами в артефактах |
| `.github/workflows/vmlab-haiku.yml` | пакетный прогон сценария в Haiku без git-шины (`vmlab.py run`): регресс f4 после каждой успешной сборки `f4-haiku`, по push в `vmlab/scenarios/haiku-*.txt` и `vmlab/haiku/**` и вручную |

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
| второй способ (`redoxer exec` в docker, см. «Второй способ» ниже) | ≈ 1 мин на каждую загрузку |

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

## X11 для гостей без своего графического сервера (Xvfb на хосте)

Нужно, когда приложению в госте нужен X-сервер, а в самом госте его нет (Redox: клиент
`xgb` подключается по сети). Вход workflow `xvfb: true` (`ctl.py start --xvfb`) ставит
`xvfb x11-apps xdotool imagemagick x11-utils` и запускает на хосте
`Xvfb :1 -screen 0 1280x800x24 -listen tcp -ac` (слушает `0.0.0.0:6001`). Гость видит хост
как `10.0.2.2`, значит: `DISPLAY=10.0.2.2:1`. Шаги сценария (работают на хостовом дисплее):

| Шаг | Что делает |
|---|---|
| `xshot NAME` | скриншот корневого окна (`import -window root`) → PNG в каталоге результата |
| `xkey KEYS` | `xdotool key` (например `xkey ctrl+c Return`) |
| `xclick X Y [right\|middle\|double]` | подвести указатель и кликнуть |
| `xtype TEXT` | `xdotool type` |
| `xrun CMD` | запустить X-клиент на хосте в фоне (например `xrun xclock`) |
| `xsh CMD` | выполнить команду на хосте с `DISPLAY`, вывод попадает в лог шага (`xwininfo -root -tree`, `ss -ltn`) |

Проверено: Xvfb стартует, слушает TCP 6001, `xclock`/`xeyes` рисуются, `xclick` двигает
указатель (зрачки `xeyes` следуют), `xshot` отдаёт PNG. Соединение именно из гостя Redox к
`10.0.2.2:6001` отдельно не проверялось (обычная SLIRP-сеть, до `10.0.2.2:8000` гость
достаёт).

Осторожно: гостевой агент однопоточный. Зависшая команда (например `curl` без
работающего таймаута) блокирует агента: дальнейшие `ctl.py sh` ничего не вернут. Лечение —
`do "key ctrl-c"` в терминале гостя и повторный запуск агента (строка из сценария
`redox-desktop`) или новая сессия из снимка.

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

* **Haiku** — уже подключена: `vmlab/guests/haiku.json` (nightly `anyboot.zip`, `pc-i440fx`,
  IDE), агент `vmlab/guests/haiku-agent.sh`, сценарии `vmlab/scenarios/haiku-*.txt`. Интерактивная
  сессия идёт на своей шине, чтобы не мешать Redox (грабли №4):
  `export VMLAB_BUS=vmlab-haiku VMLAB_AGENT_EXT=sh`, затем
  `python3 vmlab/ctl.py start --guest haiku --minutes 45 --scenario haiku-desktop`. Пакетные прогоны —
  `vmlab-haiku.yml`. Устройство, найденные грабли Haiku в VM и результаты — в
  [`f4-haiku/README.md`](../f4-haiku/README.md).
* **Hurd** — образы Debian GNU/Hurd (qcow2, i386/amd64) грузятся с текстовой консолью:
  скриншот полезен как контроль, а надёжнее читать serial-лог (`-serial file:` уже
  пишется в `/tmp/vmlab/serial.log`) и слать команды на консоль клавишами `typeln`.
  Нужен `image_kind` для qcow2 (достаточно raw-копирования, добавляется одной веткой в
  `fetch_image`), и, скорее всего, `machine: pc`, `disk_if`/`nic` как у образа.
* Для каждой новой ОС: подобрать `cpu` для переносимых снимков, проверить, что все
  устройства мигрируемы (`savevm` ругается на немигрируемые — тогда без снимка или с
  другим контроллером диска), записать сценарий загрузки, положить гостевой агент
  (у Redox — `.ion`; у POSIX-систем достаточно `sh`-цикла `curl` → `sh job` → `curl -T`).

## Второй способ: `redoxer` в docker (`f4-redox/vm/`)

В репозитории есть и другой способ запускать Redox в CI, он **не заменён** vmlab и не дублирует его:

| | vmlab (этот каталог) | `f4-redox/vm/vm_run.sh` |
|---|---|---|
| Как запускается гость | собственный QEMU на раннере, образ Redox desktop / Haiku | образ `redoxos/redoxer` в docker, гость поднимает `redoxer exec` |
| Управление | живая сессия: мышь, клавиатура, скриншоты, OCR, снимки ВМ; либо сценарий | один пакетный прогон скрипта (`smoke.sh`), вывод в лог, без графики |
| Ядро | то, что в образе | можно подменить `/boot/kernel` в базовом образе `redoxer` своим (так `f4-redox.yml` проверяет патченое ядро) |
| Гость | Redox, Haiku, что угодно, что грузится в QEMU | только Redox |
| Цикл | ≈ 36 с до первой команды из снимка, потом секунды | ≈ 1 мин на каждую загрузку |

Когда что брать: нужна графика, интерактивная отладка или другая ОС — vmlab; нужно прогнать
скрипт на Redox с собственным ядром — `f4-redox/vm/`. Сюда `f4-redox/vm/` не переносится: он
тесно связан с `f4-redox.yml` (кэши, собранное там ядро, watchdog на зависание гостя).

## Что дальше можно улучшить

* Сравнить переносимость снимка между Intel и AMD раннерами.
* Кэш готового Go-тулчейна и сборок уже делает `f4-redox` (ключи `redox-go-<sha>`,
  `gobuild-f4redox-*`) — использовать оттуда, не дублировать.
* Несколько агентов на одном госте: сейчас одна сессия на шину (см. грабли №4); решение —
  путь результатов с id сессии вместо одной ветки результатов.

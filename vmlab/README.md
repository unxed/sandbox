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
| `.github/workflows/vmlab-haiku.yml` | пакетный прогон сценария в Haiku без git-шины, в том числе регресс f4 после каждой сборки (см. «Гость Haiku») |
| `vmlab/nested_check.py` | разовая диагностика: что `-cpu host` под KVM реально отдаёт L2-гостю (QMP `query-cpu-model-expansion`), без запуска какой-либо гостевой ОС |
| `.github/workflows/vmlab-windows-boot.yml` | пакетная проба загрузки Windows (см. «Гость Windows») + диагностика вложенной виртуализации |

### Язык сценария (по строке на шаг)

Полный список шагов (`wait`, `shot`, `key`, `type`/`typeln`, `click`/`move`/`drag`, `stable`,
`waittext` по OCR, `save`/`load` снимка ВМ, `hmp`, `payload`/`waitupload`, `x*` для хостового
X-дисплея) с аргументами описан в docstring в начале `vmlab/vmlab.py`; там он и поддерживается.
Те же шаги принимает `ctl.py do "шаг" "шаг"…` в интерактивной сессии.

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
как `10.0.2.2`, значит: `DISPLAY=10.0.2.2:1`. Шаги сценария `xshot`, `xkey`, `xclick`, `xtype`,
`xrun`, `xsh` работают на хостовом дисплее (описание — в docstring `vmlab/vmlab.py`; `xsh` удобен
для `xwininfo -root -tree` и `ss -ltn`).

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

* **Haiku** — уже подключена, см. «Гость Haiku» ниже.
* **Windows** — пока только пробный загрузочный образ, см. «Гость Windows» ниже; ключ
  `"boot": "cdrom"` в JSON гостя подключает `image_url`/`image_index` как read-only CD-ROM
  (El Torito) вместо обычного qcow2-оверлея на raw-бэкенде — годится для установочных/live ISO
  без установки на диск.
* **Hurd** — образы Debian GNU/Hurd (qcow2, i386/amd64) грузятся с текстовой консолью:
  скриншот полезен как контроль, а надёжнее читать serial-лог (`-serial file:` уже
  пишется в `/tmp/vmlab/serial.log`) и слать команды на консоль клавишами `typeln`.
  Нужен `image_kind` для qcow2 (достаточно raw-копирования, добавляется одной веткой в
  `fetch_image`), и, скорее всего, `machine: pc`, `disk_if`/`nic` как у образа.
* Для каждой новой ОС: подобрать `cpu` для переносимых снимков, проверить, что все
  устройства мигрируемы (`savevm` ругается на немигрируемые — тогда без снимка или с
  другим контроллером диска), записать сценарий загрузки, положить гостевой агент
  (у Redox — `.ion`; у POSIX-систем достаточно `sh`-цикла `curl` → `sh job` → `curl -T`).

## Гость Haiku

Гость описан в `vmlab/guests/haiku.json` (nightly `anyboot.zip`, `pc-i440fx`, IDE). Образ
качается и распаковывается за ~20 с, до окна «Welcome» ~10 с. Что найдено в самой Haiku при
запуске f4 (грабли VM, исправления порта, результаты проверок) — в
[`f4-haiku/README.md`](../f4-haiku/README.md); здесь только то, как гость устроен в vmlab.

* **Пакетный прогон** — `vmlab-haiku.yml`: KVM на раннере → загрузка Haiku → сценарий
  `vmlab/scenarios/haiku-*.txt` (режим `vmlab.py run`). Git-шину не использует, поэтому не мешает
  интерактивным сессиям. Вручную:
  `gh workflow run vmlab-haiku.yml -f scenario=haiku-smoke` (по умолчанию `haiku-regress`;
  `haiku-x11` проверяет `--gui=x11` против Xvfb на хосте). Сам запускается после каждой успешной
  сборки `f4-haiku` (регресс, итог проверяет `vmlab/haiku/regress-check.sh`, job падает при
  `RESULT FAIL`) и по push в `vmlab/scenarios/haiku-*.txt`, `vmlab/haiku/**`,
  `vmlab/guests/haiku.json`. Загрузка Haiku в Actions плавает по времени, поэтому сценарии ждут
  диалог/Deskbar по OCR (`waittext`), а не `wait`.
* **Интерактивная сессия на своей шине.** У `vmlab-session.yml` есть вход `bus`: шина команд —
  ветки `<bus>-cmd`/`<bus>-out` (по умолчанию `vmlab`), у каждого гостя своя (см. грабли №4):

  ```sh
  export GH_TOKEN=... VMLAB_BUS=vmlab-haiku VMLAB_AGENT_EXT=sh
  python3 vmlab/ctl.py start --guest haiku --minutes 45 --scenario haiku-desktop
  python3 vmlab/ctl.py do "shot x" "click 330 400" "typeln ./f4"   # клавиатура/мышь/скриншоты
  python3 vmlab/ctl.py sh 'uname -a; ls /tmp'                      # команды через гостевого агента
  python3 vmlab/ctl.py put файл имя                                # положить файл в гостя
  python3 vmlab/ctl.py stop
  ```

  Сценарий `haiku-desktop` сам проходит Welcome → «Try Haiku» → Deskbar → Applications → Terminal
  и запускает `vmlab/guests/haiku-agent.sh` (аналог `redox-agent.ion`: опрашивает
  `http://10.0.2.2:8000/job.sh`, исполняет, заливает `job.out`; отклик ~8 с).
* **Что доставляется в гостя** (каталог payload раздаётся хостом на `10.0.2.2:8000`): свежий
  бинарник `f4-haiku-amd64` и `ptyrun-haiku` (PTY-харнесс из `vmlab/haiku/ptyrun`, собирается в
  том же job'е `f4-haiku` тем же тулчейном, артефакт `f4-haiku-tools`).
* **Инструменты разбора:** `vmlab/haiku/vtdump.py` (эмулятор терминала на stdlib: превращает
  снапшоты `ptyrun` в текст экрана, `--bg` — карта цветов фона), `sgrtest*.sh` (эксперименты с SGR).

## Гость Windows (проба: загрузка есть, WSL2 внутри ещё не проверялся)

Мотивация — часть багов/фич f4 на Windows (ConPTY-specific поведение, `\\wsl.localhost\` vs
`wsl.exe`, см. f4#1494) можно проверить только на реальной Windows, а раннеры GitHub Windows
не дают ни выбора ConPTY, ни рабочего WSL2. Разово проверено (2026-09-26, AMD EPYC 9V74):

* **Грузится.** `vmlab/guests/windows-setup.json` указывает на оценочный ISO Windows Server
  2022 (`software-download.microsoft.com/.../SERVER_EVAL_x64FRE_en-us.iso`, анонимно доступен
  без регистрации на портале Evaluation Center — тот же URL годами используют шаблоны Packer).
  `"boot": "cdrom"`, диска нет: сценарий `vmlab/scenarios/windows-boot.txt`
  (`vmlab-windows-boot.yml`, KVM) за раз доходит до графического экрана Windows Setup
  («Microsoft Server Operating System Setup», выбор языка) — реальный скриншот с раннера,
  без TCG. Только загрузка/рендер; установка Windows не делалась (это отдельная, большая
  задача: автоматическая установка по ISO нужна была бы через `autounattend.xml`).
  Скачивание ISO (~5.2 ГБ, `software-download.microsoft.com`) заняло на пробе ~11 минут —
  дольше самой загрузки гостя; для повторных прогонов стоит кэшировать образ как это уже
  делает Haiku/Redox для снимков.
* **Вложенная виртуализация видна гостю.** `vmlab/nested_check.py` — разовая диагностика без
  установки Windows: поднимает пустой QEMU (`-cpu host`, `-S`, без диска/дисплея) и спрашивает
  через QMP `query-cpu-model-expansion`, что модель `host` реально отдаст L2-гостю. На раннере:
  `kvm_amd` собран с `nested=1` **по умолчанию** (перезагружать модуль не пришлось), и
  `-cpu host` отдаёт гостю `svm=True`, `npt=True` (AMD, поэтому `vmx=False` — на Intel-раннере
  ожидается обратное). Это необходимое условие для Hyper-V (и через него WSL2) внутри
  Windows-гостя, но не достаточное: реально поднять Hyper-V/WSL2 в L2-Windows и получить из
  него L3-гостя WSL2 не проверялось — для этого нужна полностью установленная Windows.
* **Чего не хватает для f4#1494.** Нужна установленная Windows (см. выше — не сделано в этой
  пробе), включённый Hyper-V/WSL2 внутри неё, и проверка, что L3-гость WSL2 реально стартует
  через два уровня вложенной виртуализации (раннер → KVM → наш QEMU/Windows → Hyper-V/WSL2).
  Само по себе `svm=True, npt=True` только снимает самый вероятный блокер (отсутствие
  аппаратной вложенной виртуализации), не доказывает работоспособность.

### Установка Windows без человека и пробег WSL2 (`vmlab-windows-install.yml`)

Следующий шаг после пробы: настоящая **неинтерактивная** установка Windows Server 2022 eval,
включение WSL2 внутри неё и прогон пробного скрипта f4#1494 (`wsl-distro-probe.ps1`,
сравнение `\\wsl.localhost\` с локальным `wsl.exe`). Файлы:

| Файл | Назначение |
|---|---|
| `vmlab/guests/windows-install.json` | тот же eval-ISO, но с `disk_gb` (настоящий диск для установки) и `allow_reboot` (гостю разрешено перезагружаться самому — иначе `-no-reboot` просто гасит QEMU) |
| `vmlab/guests/autounattend.xml` | answer-файл: один MBR-диск, `/IMAGE/NAME` = `Windows Server 2022 SERVERSTANDARD` (Desktop Experience, без продуктового ключа — eval-канал), `AutoLogon` от Administrator (`LogonCount` большой — переживает все наши перезагрузки), `FirstLogonCommands` из одной команды (`A:\bootstrap.ps1`) |
| `vmlab/guests/bootstrap.ps1`, `vmlab-agent.cmd`, `windows-agent.ps1` | тот же паттерн, что `haiku-agent.sh`/`redox-agent.ion`, но для Windows: `bootstrap.ps1` кладёт `windows-agent.ps1` в `C:\vmlab` и лончер в `%ProgramData%\...\StartUp`, дальше агент сам поднимается на каждом логоне (AutoLogon это гарантирует и после перезагрузок) и опрашивает `job.ps1`/`job.out` через `Invoke-WebRequest` |
| все четыре файла выше | лежат на **флоппи** (не на CD): Windows Setup сам находит `autounattend.xml` в корне съёмного носителя без какой-либо настройки, а флоппи всегда `A:` — в отличие от второго CD-ROM, чья буква диска непредсказуема |
| `vmlab/guests/win-jobs/*.ps1` | сама последовательность: `00-hello` (первый живой отклик агента после установки) → `01-enable-wsl-features` (два `dism`-фичи + перезагрузка, сам шлёт свой лог до перезагрузки — иначе ответ никогда не уйдёт) → `02-post-reboot-check` → `03-install-kernel` (msi с `wslstorestorage.blob.core.windows.net`, см. `learn.microsoft.com/windows/wsl/install-manual` — на Server нет Store, значит и `wsl --update` тем путём не работает) → `04-import-ubuntu` (`wsl --import` из `cloud-images.ubuntu.com/wsl/...rootfs.tar.gz` — тоже без Store и без интерактивного создания UNIX-пользователя) → `05-wsl-distro-probe.ps1` (весь скрипт sogonov из f4#1494, построчно как в тикете) |
| `vmlab/guests/windows-install-gen.py` | оборачивает каждый `win-jobs/*.ps1` в `payload job.ps1 <base64>` / `waitupload job.out` / `catupload job.out` / `shot` — тем же `job.$EXT`-протоколом, что и `ctl.py sh`, но статическим сценарием для `vmlab.py run` (батч, без git-шины); `--resume` пропускает загрузочную преамбулу и `00-hello` (для восстановления из снимка) |
| `.github/workflows/vmlab-windows-install.yml` | собирает флоппи (`mkfs.vfat`+`mtools`), кэширует ISO (стабильный ключ) и диск с post-install снимком (`vmlab-win-disk-*`, восстановление по префиксу) отдельно — если начиная с `02`/`03`/`04` что-то ломается, следующий прогон стартует не с установки Windows, а с `--loadvm postinstall` |

В `vmlab.py` для этого добавлено немного: `disk_gb` у гостя с `boot: cdrom` — постоянный qcow2-диск рядом с установочным ISO (индекс `1`); флоппи (`floppy.img`, если файл существует — тот же паттерн, что уже был у `payload.iso`); `allow_reboot` делает `-no-reboot` необязательным; `snapshot_names()` теперь смотрит и на `disk.qcow2`; шаг сценария `catupload NAME` — печатает файл, который гость положил на хост, прямо в лог шага (в батч-режиме нет сессионной шины, через которую можно забрать `out/`, поэтому результат должен быть виден в самом логе job'а).

Реальный прогон (что именно получилось — установка, включение WSL2, импорт Ubuntu, вывод пробного
скрипта) описывается отдельно после первого исполнения этого workflow; на момент написания этого
раздела механизм собран, но ещё не прогнан на раннере.

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

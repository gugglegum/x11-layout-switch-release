# X11 Layout Switch Release

[English](README.md) | [Русский](README_RU.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/gugglegum/x11-layout-switch-release/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/gugglegum/x11-layout-switch-release/actions/workflows/ci.yml)

Скрипты для Linux/X11, которые позволяют переключать раскладку клавиатуры не в момент нажатия `Alt+Shift` или `Ctrl+Shift`, а в момент отпускания клавиш.

## Что это такое

В обычной схеме XKB переключение раскладки по `Alt+Shift` или `Ctrl+Shift` срабатывает на нажатии. Это неудобно, если те же модификаторы участвуют в других сочетаниях клавиш, например:

- `Alt+Shift+Tab`
- `Ctrl+Shift+стрелка`
- любые собственные hotkey-комбинации, где `Alt+Shift` или `Ctrl+Shift` являются только частью сочетания

Этот проект решает проблему простым способом:

1. `xinput test` слушает события клавиатуры на уровне X11.
2. Скрипт распознаёт короткую последовательность нажатия и отпускания `Alt+Shift` или `Ctrl+Shift`.
3. После отпускания второй клавиши вызывается `xkb-switch -n`.

В результате переключение происходит именно на отпускании, а не на нажатии.

## Где это применимо

Эта реализация рассчитана на X11 и на окружения, где раскладка в основном живёт в XKB, без отдельного менеджера input sources поверх него. Поэтому она потенциально подходит для довольно широкого круга систем:

- Linux Mint
- LMDE
- Ubuntu
- Debian
- Fedora
- Arch Linux
- Manjaro
- openSUSE
- Linux Mint с MATE или Xfce
- MATE, Xfce, LXDE, Openbox и другие X11-окружения
- старые версии Cinnamon, где прямое переключение через XKB не расходится с состоянием панели

То есть на практике проект скорее привязан не к одному конкретному дистрибутиву, а к сочетанию:

- X11-сессии
- XKB как основного механизма переключения раскладки
- окружения рабочего стола, которое не держит отдельное состояние input sources поверх XKB

## Где это не подходит

- Wayland: `xinput` и прямое управление XKB там уже не являются надёжной моделью
- современные версии Cinnamon 6.6+:
  Cinnamon начал держать собственное состояние источников ввода, и прямое переключение через `xkb-switch` может расходиться с индикатором в панели и внутренним состоянием оболочки

Если у вас Linux Mint 22.3+ / Cinnamon 6.6+, лучше использовать отдельное решение для Cinnamon:

<https://github.com/gugglegum/cinnamon-layout-switch-release>

## Зависимости

Нужно, чтобы в системе были доступны:

- `bash`
- `xinput`
- `xkb-switch`

`xkb-switch` не входит в этот репозиторий и устанавливается отдельно.

## Предварительная установка `xkb-switch`

Upstream-проект:

<https://github.com/grwlf/xkb-switch>

Типичный способ установки на Debian/Ubuntu/Linux Mint:

```bash
sudo apt install cmake make g++ libxkbfile-dev
git clone https://github.com/grwlf/xkb-switch.git
cd xkb-switch
mkdir build
cd build
cmake ..
make
sudo make install
sudo ldconfig
```

После этого проверьте, что утилита доступна:

```bash
xkb-switch --help
```

Если `xkb-switch` установлен не в стандартную директорию, добавьте её в `PATH` так, чтобы утилита была доступна и в обычной shell-сессии, и в автозапуске графического окружения.

## Установка этого решения

Ниже основной сценарий установки.

### Шаг 1. Установите `xkb-switch`

Сначала установите `xkb-switch` по инструкции выше и проверьте, что команда доступна:

```bash
xkb-switch --help
```

### Шаг 2. Запустите установщик

По умолчанию установка пользовательская и не требует root-прав:

```bash
./install.sh
```

При установке по умолчанию это создаст:

- listener в `~/.local/bin/x11-layout-switch-release.sh`
- конфиг в `~/.config/x11-layout-switch-release.conf`
- автозапуск в `~/.config/autostart/x11-layout-switch-release.desktop`

Если конфиг уже существует, установщик не перезапишет его.

Дополнительные варианты:

```bash
./install.sh --system
./install.sh --bin-dir /some/path
./install.sh --interactive
```

`--system` устанавливает listener в `/usr/local/bin` и потребует `sudo`.
`--bin-dir` для пути внутри домашней директории обычно не требует root-прав. Если указать путь вне домашней директории, установка может потребовать `sudo`.

### Шаг 3. Отключите штатное переключение раскладки

Если в вашей оболочке уже включено стандартное переключение по `Alt+Shift` или `Ctrl+Shift`, его нужно отключить. Иначе получится двойное переключение:

- одно от среды рабочего стола
- второе от этого listener'а

Как именно это делается, зависит от используемой оболочки.

### Шаг 4. Перелогиньтесь или запустите listener вручную

После установки можно просто выйти из сеанса и войти снова. Автозапуск поднимет listener сам.

Если не хочется ждать, запустите его вручную:

```bash
~/.local/bin/x11-layout-switch-release.sh
```

Если вы устанавливали через `--system` или `--bin-dir`, используйте путь к listener'у из вывода `install.sh`.

### Шаг 5. Если автоопределение клавиатуры не сработало, поправьте конфиг

Файл `~/.config/x11-layout-switch-release.conf` создаётся автоматически при установке. Listener читает его и при ручном запуске, и при запуске через автозагрузку.

Если раскладка не переключается, сначала найдите нужный `keyboard id`:

```bash
xinput list --short
```

Потом откройте конфиг и укажите, например:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_ID=8
```

После правки перезапустите listener или просто перелогиньтесь.

## Что делает install.sh

- проверяет наличие `xkb-switch`
- проверяет наличие `xinput`
- копирует listener
- создаёт конфигурационный файл, если его ещё нет
- создаёт `.desktop` для автозапуска

Если `xkb-switch` не найден, установка прерывается с короткой инструкцией по сборке.

## Настройка клавиатуры

По умолчанию listener пытается найти клавиатуру так:

1. через `KB_LAYOUT_SWITCH_KEYBOARD_ID`, если он задан
2. по имени `AT Translated Set 2 keyboard`
3. по fallback-имени `Virtual core keyboard`

В виртуальных машинах идентификатор клавиатуры часто бывает небольшим числом вроде `8`, но это не универсальное правило. На другой системе `id` может быть другим.

Посмотреть список устройств можно так:

```bash
xinput list --short
```

Узнать `id` конкретной клавиатуры:

```bash
xinput list --id-only "AT Translated Set 2 keyboard"
```

Для постоянной настройки укажите это значение в:

```text
~/.config/x11-layout-switch-release.conf
```

Например:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_ID=8
```

Если имя клавиатуры другое, можно вместо `id` переопределить её имя:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_NAME='My USB Keyboard'
```

Listener читает этот файл и при автозапуске тоже, поэтому отдельная правка `.desktop` не нужна.

Переменные окружения по-прежнему можно использовать для временной ручной проверки, но для постоянной настройки лучше менять именно конфиг-файл.

## Как это работает

Скрипт реагирует на четыре короткие последовательности для `Alt+Shift` и четыре для `Ctrl+Shift`:

- `Alt_Down Shift_Down Alt_Up`
- `Alt_Down Shift_Down Shift_Up`
- `Shift_Down Alt_Down Alt_Up`
- `Shift_Down Alt_Down Shift_Up`
- `Ctrl_Down Shift_Down Ctrl_Up`
- `Ctrl_Down Shift_Down Shift_Up`
- `Shift_Down Ctrl_Down Ctrl_Up`
- `Shift_Down Ctrl_Down Shift_Up`

Как только одна из этих последовательностей распознана, выполняется:

```bash
xkb-switch -n
```

Если у вас настроено больше двух раскладок, будет происходить переход к следующей раскладке по кругу.

## Удаление

```bash
./uninstall.sh
```

Варианты удаления такие же, как у установки:

```bash
./uninstall.sh --system
./uninstall.sh --bin-dir /some/path
./uninstall.sh --purge-config
```

По умолчанию `uninstall.sh` удаляет listener и автозапуск, но оставляет `~/.config/x11-layout-switch-release.conf`. Это сделано специально, чтобы не терять пользовательские настройки. Если конфиг тоже нужно удалить, используйте `--purge-config`.

## Ограничения

- проект рассчитан именно на X11
- проект не пытается синхронизироваться с Wayland-композиторами
- на современных Cinnamon 6.6+ лучше использовать Cinnamon-специфичный backend
- listener использует `xkb-switch -n`, поэтому он листает раскладки по кругу, а не жёстко переключает только между двумя языками

## Лицензия

MIT, см. файл [LICENSE](LICENSE).

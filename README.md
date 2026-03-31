# X11 Layout Switch Release

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

- Linux Mint с MATE или Xfce
- MATE, Xfce, LXDE, Openbox и другие X11-окружения
- старые версии Cinnamon, где прямое переключение через XKB не расходится с состоянием панели

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

По умолчанию установка пользовательская и не требует root-прав:

```bash
./install.sh
```

Это установит listener в `~/.local/bin` и создаст автозапуск в `~/.config/autostart`.

Дополнительные варианты:

```bash
./install.sh --system
./install.sh --bin-dir /some/path
./install.sh --interactive
```

`--system` устанавливает listener в `/usr/local/bin` и потребует `sudo`.
`--bin-dir` для пути внутри домашней директории обычно не требует root-прав. Если указать путь вне домашней директории, установка может потребовать `sudo`.

## Что делает install.sh

- проверяет наличие `xkb-switch`
- проверяет наличие `xinput`
- копирует listener
- создаёт `.desktop` для автозапуска

Если `xkb-switch` не найден, установка прерывается с короткой инструкцией по сборке.

## Автозапуск

После установки создаётся файл:

```text
~/.config/autostart/x11-layout-switch-release.desktop
```

Если не хочется ждать следующего входа в систему, listener можно запустить вручную:

```bash
~/.local/bin/x11-layout-switch-release.sh
```

## Настройка клавиатуры

Скрипт пытается найти клавиатуру так:

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

Запуск с явным `id`:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_ID=8 ~/.local/bin/x11-layout-switch-release.sh
```

Если имя клавиатуры другое, можно переопределить его:

```bash
KB_LAYOUT_SWITCH_KEYBOARD_NAME="My USB Keyboard" ~/.local/bin/x11-layout-switch-release.sh
```

## Как работает переключение

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

## Важная настройка в окружении рабочего стола

Если в системе уже включены стандартные hotkey для переключения раскладки по `Alt+Shift` или `Ctrl+Shift`, их нужно отключить. Иначе будет двойное переключение:

- одно от среды рабочего стола
- второе от этого listener'а

Как именно это делается, зависит от используемой оболочки.

## Удаление

```bash
./uninstall.sh
```

Варианты удаления такие же, как у установки:

```bash
./uninstall.sh --system
./uninstall.sh --bin-dir /some/path
```

## Ограничения

- проект рассчитан именно на X11
- проект не пытается синхронизироваться с Wayland-композиторами
- на современных Cinnamon 6.6+ лучше использовать Cinnamon-специфичный backend
- listener использует `xkb-switch -n`, поэтому он листает раскладки по кругу, а не жёстко переключает только между двумя языками

## Лицензия

MIT, см. файл [LICENSE](LICENSE).

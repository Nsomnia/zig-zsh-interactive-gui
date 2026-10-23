# zui — zsh interactive GUI

`zui` is a terminal UI toolkit and a near-clone of [`gum`](https://github.com/charmbracelet/gum),
written entirely in **zsh** on top of the built-in **`zsh/curses`** module.
Prompts are framed like `dialog(1)` windows, every dialog can carry **any number of
buttons bound to actions**, and results stay pipeable: the UI is drawn on
`/dev/tty`, the answer is printed on stdout after the terminal is restored.

```
╭──────────────────────── Message ─────────────────────────╮
│  i  Disk almost full.                                     │
│                                                           │
│              [ OK ]    [ Details ]    [ Later ]           │
╰───────────────────────────────────────────────────────────╯
        ←→ buttons   ↑↓ scroll   Esc cancel
```

```
╭───────────────────────── Packages ────────────────────────╮
│  > [✓] ripgrep                                            │
│    [✓] fzf                                                │
│    [ ] zoxide                                             │
│    [ ] bat                                                │
│                                                           │
│                  [ Install ]    [ Cancel ]                │
╰───────────────────────────────────────────────────────────╯
      ↑↓ move   Space select   Enter confirm   Tab buttons
```

## Why

- **Only zsh.** No Go, Node, Python, or compiled artifacts. The only requirement is
  `zsh` with its `curses` module and a terminal.
- **dialog(1) look.** Bordered, shadowed windows with a title, icon, body, hint
  footer and a centred button row — not bare inline prompts.
- **Gum-style CLI.** `choose`, `confirm`, `input`, `write`, `filter`, `file`,
  `pager`, `spin`, `style`, `format`, `join`, `table`, `log`, plus a `dialog`
  family.
- **Action buttons.** Buttons are `Label=action` pairs. Add as many as you like;
  they wrap. Actions can accept the current value, print a string, exit with a
  status, or run a shell command after the UI closes.
- **Pipe-safe by design.** `name=$(zui input --header "Name")` works even though
  the UI needs a terminal.
- **Honest colour.** Auto-detects 256/16 colours, supports 256-colour palettes,
  degrades to attributes-only `mono`, and offers `--ascii` for terminals without
  UTF-8. Help text deliberately uses the portable 8/16-colour ANSI set plus
  bold/underline/dim so it survives every tty.
- **Tested.** 68 unit assertions and 30 pseudo-terminal integration tests drive
  the real UI with `zsh/zpty`.

The repository name is historical; the command is `zui` (zsh interface).

## Requirements

| Requirement | Notes |
|---|---|
| `zsh` 5.9+ | macOS `/bin/zsh` works as shipped. |
| `zsh/curses` | `zsh -fc 'zmodload zsh/curses && echo ok'` |
| ncurses + terminfo | Almost always present. |
| UTF-8 locale | Optional; use `--ascii` or `ZUI_ASCII=1` otherwise. |

Check the one hard requirement:

```sh
zsh -fc 'zmodload zsh/curses && echo "zcurses ready"'
```

## Install

```sh
git clone https://github.com/Nsomnia/zig-zsh-interactive-gui.git zui
cd zui
ln -s "$PWD/bin/zui" ~/.local/bin/zui     # or add ./bin to PATH
zui --version
```

Or install a copy with make:

```sh
make install PREFIX="$HOME/.local"
```

No build step is involved. `bin/zui` is the executable; `lib/` is the framework.

## Quick start

```sh
# pick one
printf 'alpha\nbeta\ngamma\n' | zui choose --header "Pick one"

# ask for text and capture it
name=$(zui input --header "Your name" --placeholder "Ada Lovelace")

# multiple selection
packages=$(zui choose --no-limit --header "Packages" ripgrep fzf zoxide bat)

# a dialog with three action buttons
zui msgbox --icon warn --message "Disk almost full." \
  --button 'OK=exit:0' \
  --button 'Details=run:df -h' \
  --button 'Later=exit:1'

# yes/no with visible output
zui confirm --show-output "Deploy to production?" && ./deploy.sh

# styled banner
zui style --border rounded --padding 1,3 --foreground 212 --bold "RELEASE 2.0"
```

Run `zui --help` for the command overview, or `zui <command> --help`
(equivalently `zui help <command>`) for every option, key binding, example and
note for that command. Help is generated from the live option definitions.

## Commands

### Interactive

| Command | Purpose |
|---|---|
| `choose` | Pick one item, or many with `--no-limit` / `--limit N`. |
| `confirm` | Yes/no question; exit 0 or 1. |
| `input` | Single-line editor with masking, limits and a block caret. |
| `write` | Multi-line editor with optional line numbers. |
| `filter` | Always-visible fuzzy filter over a list. |
| `file` | Browse directories; optional permissions and sizes. |
| `pager` | Scroll text with optional soft wrap; prints unchanged when piped. |
| `spin` | Framed spinner around a background command. |

### Presentation

| Command | Purpose |
|---|---|
| `style` | Borders, padding, margins, alignment, ANSI colour. |
| `format` | Templates, Markdown, emoji aliases and code passthrough. |
| `join` | Join blocks horizontally or vertically. |
| `table` | Parse CSV; pick a row interactively or `--print` a table. |
| `log` | Levelled text, logfmt or JSON logging. |

### Dialogs

| Command | Purpose |
|---|---|
| `msgbox` | Message plus any number of action buttons. |
| `yesno` | Two-button modal question. |
| `inputbox` | Message plus a framed text field and buttons. |
| `menu` | Single-select list with buttons. |
| `checklist` | Multi-select list with buttons. |
| `form` | Several labelled fields and a button row. |
| `gauge` | Progress bar, interactive or `--print`. |
| `infobox` | Buttonless notice; any key dismisses. |
| `dialog` | One flag-driven front end for every dialog type. |

### Utility

| Command | Purpose |
|---|---|
| `help [command]` | Colourful help with options, keys and examples. |
| `version` | Version string. |
| `completion zsh\|bash` | Shell completion script. |

### Gum and dialog(1) parity

The interactive commands accept the gum behaviour flags you expect: list
prefixes, `--input-delimiter` / `--output-delimiter`, `--label-delimiter`,
`--strip-ansi`, fuzzy controls, `--soft-wrap`, `--permissions` / `--size`,
`--formatter` / `--structured` and table `--lazy-quotes`,
`--fields-per-record` and `--return-column`. The dialog family also accepts the
practical `dialog(1)` common options (`--ok-label`, `--cancel-label`,
`--extra-button`, `--help-button`, `--no-cancel`, `--defaultno`,
`--default-item`, `--backtitle`, `--no-shadow`, `--quoted`, `--output-fd`, …).

Every per-part colour can be overridden with `--<part>.foreground` and
`--<part>.background`; the available parts are listed by
`zui <command> --help`. See [docs/DIALOGS.md](docs/DIALOGS.md) and
[docs/THEMES.md](docs/THEMES.md).

## Dialog buttons and actions

Buttons are passed with `--button 'Label=action'` and may be repeated.
`&` marks an accelerator: `'&Open=accept'` can also be triggered with `Alt-O`.

| Action | Effect |
|---|---|
| `exit:N` | Close and exit with status `N`. |
| `accept` | Close and print the widget's value (exit 0). |
| `cancel` | Close, print nothing, exit 1. |
| `print:TEXT` | Print `TEXT` and exit 0. |
| `run:CMD` | Close, run `CMD` in the restored shell; its status is returned. |
| `stay` | Do nothing (useful with custom key hooks). |

Without `--button`, dialogs use sensible defaults: msgbox has `OK`, input/menu/form
use `accept` and `cancel`, infobox has no buttons.

```sh
zui msgbox --title "Update" \
  --button 'Install=run:brew upgrade' \
  --button 'Later=exit:1' \
  "Install updates now?"

zui inputbox --message "Branch name:" --value main \
  --button 'Create=accept' \
  --button 'Cancel=cancel'
```

If a button's action is omitted, it exits with its zero-based index
(`'Close'` alone is `exit:1` as the second button). Prefer explicit actions.

See [docs/DIALOGS.md](docs/DIALOGS.md) for keys, layout and the full action model.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Accepted / success. |
| `1` | Cancelled, negative answer, or no selection. |
| `2` | Usage error (unknown option, bad value). |
| `3` | Interactive command without a usable terminal. |
| `124` | `--timeout` expired. |
| `130` | Ctrl-C / SIGINT abort. |

Results are printed **after** the alternate screen is left, so this is safe:

```sh
choice=$(zui choose a b c)          # stdout captured, UI on the tty
zui choose a b c > choice.txt       # UI still appears
zui choose a b c | cat              # works; result goes through the pipe
```

## Colour and themes

`zui` chooses a colour profile at runtime:

- **256 colours** when `ZCURSES_COLORS >= 256`
- **16 colours** on smaller terminals
- **none** with `NO_COLOR`, `--no-color`, `TERM=dumb`, or `--theme mono`

Borders fall back to ASCII when the locale is not UTF-8, when `--ascii` is set,
or `ZUI_ASCII=1`.

Built-in 256-colour palettes: `default`, `light`, `dracula`, `gruvbox`, `nord`,
`solarized`, `catppuccin`, `mono`.

```sh
ZUI_THEME=dracula zui choose one two
zui --theme nord confirm "Continue?"
zui --ascii --no-color msgbox "Plain and portable"
```

`style` accepts named colours, 256-colour indices (`0`–`255`) and `#rrggbb`:

```sh
zui style --foreground 212 --background 236 --padding 1,2 "hot pink"
zui style --foreground '#89b4fa' --border double "truecolour when supported"
```

See [docs/THEMES.md](docs/THEMES.md).

## Framework

The CLI is a thin layer over a small framework:

```zsh
#!/usr/bin/env zsh
source "$HOME/src/zui/lib/zui.zsh"

zui::begin
zui::widget input
zui::title "Host"
zui::message "Which host should we connect to?"
zui::value "localhost"
zui::button "Connect" accept
zui::button "Cancel" cancel

zui::run && print -r -- "connecting to $ZUI_OUT"
```

`zui::run` sets `ZUI_OUT` and `ZUI_CODE`. The same building blocks power list,
checklist, form, textarea and gauge dialogs. See
[docs/FRAMEWORK.md](docs/FRAMEWORK.md) for the full API and a custom key hook.

## Environment

| Variable | Effect |
|---|---|
| `NO_COLOR` | Disable colour. |
| `ZUI_THEME` | Default palette (`default`, `light`, `dracula`, …). |
| `ZUI_ASCII` | `1` forces ASCII borders and glyphs. |
| `ZUI_DEBUG` | `1` writes debug lines to stderr. |
| `ZUI_FORCE_COLOR` | Force ANSI in help/style output when piped. |

## Testing

```sh
make test          # unit + pty integration
zsh test/unit.zsh
zsh test/integration.zsh
```

The integration suite spawns real `zui` processes under `zsh/zpty`, sends
keystrokes, and checks both stdout and exit status. It covers editing, list
navigation, checklists, forms, files, pagers, timeouts, Ctrl-C, action buttons,
piped output and colour opt-in.

## Documentation

- [docs/COMMANDS.md](docs/COMMANDS.md) — command reference and examples
- [docs/DIALOGS.md](docs/DIALOGS.md) — buttons, actions, keys, layout
- [docs/FRAMEWORK.md](docs/FRAMEWORK.md) — public API
- [docs/THEMES.md](docs/THEMES.md) — palettes, colour profiles, borders
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — modules and event loop
- [docs/LIMITATIONS.md](docs/LIMITATIONS.md) — known constraints
- [doc/adr/0001-use-zcurses.md](doc/adr/0001-use-zcurses.md) — design decision

## License

MIT. See [LICENSE](LICENSE).

# Framework API

`lib/zui.zsh` exposes the dialog engine used by the CLI. Everything is pure zsh;
the only requirement is a terminal with `zsh/curses`.

```zsh
source /path/to/zui/lib/zui.zsh
```

## Lifecycle

```zsh
zui::begin                    # reset all dialog state
zui::widget input             # text (default), input, textarea, list, checklist, form, gauge
zui::title "Deploy"           # title bar
zui::message "Ship 2.0?"      # body text (wrapped)
zui::value "main"             # initial input value
zui::button "Deploy" accept   # Label, action
zui::button "Cancel" cancel
zui::run                      # draws the UI, blocks until done
print -r -- "code=$ZUI_CODE value=$ZUI_OUT"
```

`zui::run` returns the dialog status and sets **`ZUI_OUT`** (accepted value) and
**`ZUI_CODE`** (status). The UI is drawn on `/dev/tty`; stdout is restored before
`zui::run` returns, so printing or piping the result is safe.

## Configuration

| Function | Purpose |
|---|---|
| `zui::title TEXT` | Title bar text. |
| `zui::message TEXT` | Wrapped body/header text. |
| `zui::icon NAME` | `info`, `success`, `warn`, `error`, `question`. |
| `zui::width N` / `zui::height N` | Window size; `0` = automatic. |
| `zui::timeout DURATION` | `500ms`, `5s`, `2m`; timeout returns 124. |
| `zui::border STYLE` | `auto`, `rounded`, `sharp`, `double`, `thick`, `ascii`, `hidden`, `none`. |
| `zui::prompt TEXT` | Prefix inside an input row. |
| `zui::hints TEXT` | Override the hint footer. |
| `zui::default_button N` | Focused button, 1-based. |
| `zui::button LABEL [ACTION]` | Append a button; default action `exit:0`. |
| `zui::widget NAME` | Select the content widget. |

Widget-specific:

| Function | Widget | Purpose |
|---|---|---|
| `zui::items ITEM...` | list, checklist | Set items and rebuild the view. |
| `zui::multi [0\|1]` | list/checklist | Enable multi-selection. |
| `zui::limit N` | checklist | Maximum marks (`0` = unlimited). |
| `zui::ordered [0\|1]` | checklist | Return in selection order. |
| `zui::selected ITEM...` | list/checklist | Pre-select items. |
| `zui::list_height N` | list | Visible rows. |
| `zui::value TEXT [MASK]` | input | Initial value; `MASK=1` hides it. |
| `zui::placeholder TEXT` | input, textarea | Empty-state hint. |
| `zui::textarea TEXT` | textarea | Initial buffer. |
| `zui::textarea_height N` | textarea | Visible rows. |
| `zui::line_numbers [0\|1]` | textarea | Gutter. |
| `zui::form_field LABEL [VALUE]` | form | Append a field. |
| `zui::secret LABEL` | form | Mask a field by label. |
| `zui::gauge PERCENT [LABEL]` | gauge | Static percentage and caption. |

## Examples

### Input

```zsh
zui::begin
zui::widget input
zui::title "Repository"
zui::message "Clone which repository?"
zui::value "https://github.com/"
zui::placeholder "https://…"
zui::button "Clone" accept
zui::button "Cancel" cancel
if zui::run; then
  git clone -- "$ZUI_OUT"
fi
```

### Multi-select

```zsh
zui::begin
zui::widget checklist
zui::title "Features"
zui::items ui docs tests release
zui::selected docs
zui::multi 1
zui::limit 3
zui::ordered 1
zui::button "Keep" accept
zui::button "Cancel" cancel
zui::run
print -r -- "$ZUI_OUT"          # one item per line
```

### Form

```zsh
zui::begin
zui::widget form
zui::title "Account"
zui::form_field "User" "ada"
zui::form_field "Email"
zui::form_field "Password"
zui::secret "Password"
zui::button "Create" accept
zui::button "Cancel" cancel
zui::run
local -a values=("${(@f)ZUI_OUT}")
print -r -- "user=$values[1] email=$values[2]"
```

## Advanced: custom keys and hooks

The dialog spec is an associative array, `_zui_dlg`. These fields extend the
public API:

| Field | Meaning |
|---|---|
| `hints` | Replace the footer text. |
| `esc_code` | Status to return on Esc (default 1; infobox/gauge/pager use 0). |
| `no_cancel` | `1` ignores Esc. |
| `key_hook` | Function name called for widget keys before built-in handling. |
| `percent`, `label` | Gauge values. |
| `list_h`, `ta_h` | List / textarea viewport rows. |

A key hook returns 0 when it handled the key and 1 to let the dialog continue.
This is how the file browser navigates directories without closing:

```zsh
_zui_dlg[key_hook]=my_key_hook

my_key_hook() {
  case $KEY in
    (RIGHT)  open_directory; return 0 ;;
    (LEFT)   parent_directory; return 0 ;;
  esac
  return 1
}
```

`KEY` is set by `_zui_readkey` and holds `UP`, `DOWN`, `LEFT`, `RIGHT`, `HOME`,
`END`, `PGUP`, `PGDN`, `ENTER`, `TAB`, `BACKTAB`, `ESC`, `BACKSPACE`, `DELETE`,
`CTRL_<letter>` or the printable character/UTF-8 sequence itself.

## Lower-level pieces

The engine is assembled from small modules under `lib/zui/`:

- `render.zsh` — `_zui_put`, `_zui_fill`, `_zui_frame`, `_zui_wrap`
- `editor.zsh` — single-line and textarea editors
- `widgets.zsh` — buttons, list/checklist, form, gauge
- `dialog.zsh` — layout, focus, actions, event loop
- `keys.zsh` — byte-level CSI/SS3 decoding

They are internal but stable enough to reuse; see
[docs/ARCHITECTURE.md](ARCHITECTURE.md).

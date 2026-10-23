# Dialogs: buttons, actions, keys and layout

`zui`'s dialog engine is shared by `msgbox`, `yesno`, `inputbox`, `menu`,
`checklist`, `form`, `gauge`, `infobox` and the framework API. This page covers
the parts they have in common.

## Anatomy

```
╭──────────────────────── Title ─────────────────────────╮  ← title bar
│  icon  message text, wrapped to the window width        │  ← message / header
│                                                         │
│  widget area (list, field, textarea, gauge, …)          │  ← content
│                                                         │
│                  [ Button ]   [ Button ]                │  ← button row
╰─────────────────────────────────────────────────────────╯
      ←→ buttons   ↑↓ scroll   Esc cancel                  ← hint footer
```

The window is centred, gets a shadow when the border is visible, and shrinks to
fit the terminal. `--width` / `--height` accept cells; `0` means automatic.

## Buttons

Every dialog accepts `--button 'Label=action'`, repeatable:

```sh
zui msgbox --message "Deploy?" \
  --button 'Deploy=run:./deploy.sh' \
  --button 'Dry run=print:dry' \
  --button 'Cancel=cancel'
```

- Buttons wrap onto extra rows when they do not fit.
- `--default-button N` chooses which button has focus (1-based).
- Prefix a letter with `&` to bind `Alt-<letter>`: `--button '&Open=accept'`.
- A label without `=` closes with its zero-based index (`exit:0`, `exit:1`, …).
- No buttons is valid (`infobox`, `gauge`, pager): any key dismisses.

## dialog(1)-compatible options

Beyond `--button`, the dialog family accepts the practical `dialog(1)` common
options:

| Option | Effect |
|---|---|
| `--ok-label`, `--exit-label`, `--cancel-label` | Rename the accept/cancel buttons. |
| `--yes-label`, `--no-label` | Aliases for affirmative/negative labels on yes/no dialogs. |
| `--extra-button`, `--extra-label` | Add an extra button that exits 0. |
| `--help-button`, `--help-label` | Add a Help button that exits 0. |
| `--no-ok`, `--no-cancel` | Hide a button and (for cancel) ignore Esc. |
| `--defaultno`, `--default-item` | Focus the negative button, or a named item/field. |
| `--backtitle`, `--hline` | Replace or extend the bottom hint line. |
| `--no-shadow`, `--ascii-lines` | Drop the shadow or force ASCII borders. |
| `--max-input`, `--insecure` | Limit input length or mask it. |
| `--output-fd`, `--stderr`, `--stdout` | Choose where the result is written. |
| `--output-separator`, `--separate-output` | Control multi-value output. |
| `--quoted`, `--single-quoted` | Wrap each output value in quotes. |
| `--show-help`, `--no-show-help` | Show or hide the hint footer. |
| `--sleep`, `--beep`, `--beep-after` | Hold the final frame, or ring the bell. |

`--colors`, `--clear`, `--no-mouse`, `--item-help` and `--no-items` are accepted
for script compatibility. Style flags such as `--title.foreground`,
`--button.background` and `--selection-focus.foreground` are listed by
`zui <command> --help`.

## Actions

| Action | Behaviour | Output |
|---|---|---|
| `exit:N` | Close with status `N`. | none |
| `accept` | Close with status 0. | current widget value |
| `cancel` | Close with status 1. | none |
| `print:TEXT` | Close with status 0. | `TEXT` |
| `run:CMD` | Close, restore the terminal, then run `CMD`. | command output; status becomes zui's status |
| `stay` | Keep the dialog open. | none |

`accept` values by widget:

| Widget | Accepted value |
|---|---|
| `input` | the line as edited |
| `textarea` | the buffer, newlines preserved |
| `list` / `menu` | the focused item |
| `checklist` | marked items, one per line (focused item if none) |
| `form` | field values, one per line in declaration order |
| `text` / `gauge` | nothing; use `print:` or `exit:` |

`run:` executes with `eval` in the restored shell. **Never pass untrusted text as
a `run:` action.** Use `print:` for data and let the caller decide what to run.

## Keys

| Key | Effect |
|---|---|
| `Tab` / `Shift-Tab` | Move focus between the widget and the button row. |
| `←` / `→` | Move between buttons. |
| `↑` / `↓` | Scroll the message (text dialogs) or move the cursor/buttons. |
| `PgUp` / `PgDn` | Scroll five lines. |
| `Enter` | Activate the default button, or accept. |
| `Esc` | Cancel (status 1) unless the dialog overrides it. |
| `Alt-<letter>` | Activate an `&` accelerator button. |
| `Ctrl-C` | Abort with status 130. |

Widget-specific keys:

- **input**: Home/End, Ctrl-A/E, Ctrl-U/K, Ctrl-W, Alt-B/F, Backspace/Delete.
- **textarea**: Enter inserts a newline, Tab inserts two spaces, Ctrl-D submits,
  Ctrl-B focuses buttons.
- **list/checklist**: Space toggles (checklist), typing filters, `/` shows the
  filter line, Backspace edits it, Esc clears the filter before cancelling.
- **form**: Tab/Shift-Tab and Up/Down move between fields; Enter submits.

## Timeouts and status

`--timeout 5s` (also `500ms`, `2m`, `1h`) closes the dialog and returns **124**.
`Esc` returns 1; Ctrl-C returns 130. `Esc` inside a non-empty list filter clears
the filter first.

## Defaults per command

| Command | Buttons | Default focus |
|---|---|---|
| `msgbox` | `OK=exit:0` | buttons |
| `yesno` | affirmative `exit:0`, negative `exit:1` | yes |
| `inputbox` | `OK=accept`, `Cancel=cancel` | input |
| `menu` | `Select=accept`, `Cancel=cancel` | list |
| `checklist` | `OK=accept`, `Cancel=cancel` | list |
| `form` | `Submit=accept`, `Cancel=cancel` | first field |
| `infobox` | none | message |
| `gauge` | none | gauge |

## The `dialog` front end

`zui dialog` maps one flag set onto every type, which is convenient from scripts:

```sh
zui dialog --type msgbox   --title Saved   --message "Build finished."
zui dialog --type yesno    --message "Ship it?" --show-output
zui dialog --type inputbox --title Name    --message "Your name:"
zui dialog --type menu     --title Service api web worker
zui dialog --type checklist --selected docs --title Keep ui docs tests
zui dialog --type form     --field "Name=" --field "Email="
zui dialog --type gauge    --percent 60 --label Uploading
```

Unknown types exit 2 before touching the terminal.

## Examples

```sh
# Three actions, one of which runs a command
zui msgbox --title "Update" --icon question \
  --button 'Install=run:brew upgrade' \
  --button 'Release notes=print:https://example.com/notes' \
  --button 'Later=cancel' \
  "Install updates now?"

# Drag-free rename
new=$(zui inputbox --title "Rename" --message "New file name:" --value old.txt)

# Multi-select with a cap
picked=$(zui checklist --limit 3 --ordered --title "Top priorities" \
  docs tests perf security release)

# A form that masks one field
zui form --title "New account" \
  --field "User=" --field "Email=" --field "Password=" --secret Password \
  --button "Create=accept" --button "Cancel=cancel"
```

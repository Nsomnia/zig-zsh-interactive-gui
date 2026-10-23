# Architecture

```
bin/zui
  └─ lib/zui.zsh / lib/zui/core.zsh
       ├─ cli.zsh        option definitions, parser, dispatch
       ├─ help.zsh       ANSI help renderer
       ├─ theme.zsh      semantic styles, palettes, borders, ANSI
       ├─ render.zsh     drawing primitives on stdscr
       ├─ keys.zsh       CSI/SS3 byte decoder
       ├─ editor.zsh     line editor + textarea
       ├─ widgets.zsh    buttons, list, form, gauge
       ├─ dialog.zsh     layout, focus, actions, event loop
       └─ commands/*.zsh one file per command
```

## Startup

1. `bin/zui` resolves `ZUI_ROOT`, sources `core.zsh`, and calls `_zui_load`.
2. `_zui_load` sources the modules and command files once (`_ZUI_LOADED` guard).
3. `_zui_main` handles global flags, resolves the command, and parses its
   options against `_ZUI_OPTDEF_<command>`.
4. The command reads stdin (if piped) **before** the UI starts, then builds a
   dialog spec.

Startup is ~40 ms; module loading is the dominant cost, not the UI.

## Terminal lifecycle

`_zui_ui_begin`:

1. saves fd 0 and 1, reopens both on `/dev/tty`
2. `zcurses init` (alternate screen, cbreak, no echo)
3. detects the colour profile and applies the theme
4. hides the hardware cursor; the block caret is drawn as a cell
5. installs `INT`, `TERM`, `HUP` and `WINCH` traps

`_zui_ui_end` restores traps, calls `zcurses end`, shows the cursor, and puts the
saved descriptors back. Commands print results only after this point, which is
what makes `name=$(zui input)` work while the UI still needs a tty.

`bin/zui` also installs `TRAPEXIT` as a last-resort cleanup if a command exits
unexpectedly.

## Rendering

There is no off-screen cell matrix: ncurses owns the screen buffer, so `zui`
writes directly to `stdscr` and calls `zcurses refresh` once per frame. ncurses
diffs frames and emits only changed cells. This keeps zsh-level work down to
visible text and style runs.

- `_zui_put` moves, sets attributes and writes a clipped string.
- `_zui_fill` / `_zui_repeat` paint backgrounds and rules.
- `_zui_frame` draws a themed border and centres a truncated title.
- `_zui_wrap` greedily wraps at spaces, hard-breaking overlong words.
- `_zui_pad` aligns text for buttons, tables and list rows.

Every draw uses a **semantic style** (`_ZUI_STYLE[button_focus]`, etc.), so
palettes and the mono fallback do not leak into widget code.

## Focus and events

Each dialog has a **focus area** (`_zui_dlg_area`: widget or buttons) and a
**button index** (`_zui_dlg_focus`). This separation matters for three-button
dialogs: the index can be 2 or 3 without being confused with "widget focus".

The event loop polls with a 200 ms timeout so it can check dialog deadlines,
resize flags and signals. `_zui_readkey` decodes raw bytes:

- CSI (`ESC [`), SS3 (`ESC O`) and common `~` sequences → `UP`, `DOWN`, `PGUP`, …
- control bytes → `CTRL_A`, `CTRL_D`, …
- printable UTF-8 → the character itself

Decoding is deliberately manual: on several zsh builds, `zcurses input` with a
keypad parameter returns only `ESC` for arrow keys instead of the key name.
The decoder also gives a consistent vocabulary to custom key hooks.

## Widgets

- **Editor** keeps a value and an insertion index (1..len+1), draws a reverse
  block at the caret and scrolls horizontally.
- **Textarea** keeps lines, row/column and a vertical scroll offset; long lines
  scroll horizontally on the current row.
- **List** keeps raw items, a filtered view, parallel raw indices, a cursor,
  a filter string, marks and selection order. Fuzzy matching scores consecutive
  characters and bonuses at word start.
- **Form** loads the focused field into the line editor, saves on focus change,
  and scrolls by field.
- **Buttons** are laid out row by row until they exceed the content width, then
  wrapped. Focus styling is driven by index.

## Dialog layout

Height is derived from content: message lines + widget height + button rows +
padding. The window is clamped to the terminal, vertically centred and given a
shadow. The hint footer sits below the frame when there is room. Every frame
clears the screen, so stale cells from a larger layout cannot survive.

## Testing

- `test/unit.zsh` exercises pure helpers: parser, durations, wrapping, fuzzy
  matching, CSV, editors, list values, key decoding and command output.
- `test/integration.zsh` uses `zsh/zpty` to run real processes, sends arrow keys
  and control bytes, and asserts on stdout **after** the alternate-screen exit
  sequence. This catches the tty/pipe split, action buttons, timeouts and
  Ctrl-C handling.

# Colour, themes and borders

`zui` has three rendering surfaces:

1. **zcurses dialogs** — use semantic styles from a palette.
2. **Help and `style`** — emit ANSI escape sequences directly.
3. **Plain output** — no escapes when piped or when colour is disabled.

## Profiles

The profile is detected at runtime:

| Profile | When | Behaviour |
|---|---|---|
| `256` | `ZCURSES_COLORS >= 256` | Full 256-colour palettes. |
| `16` | 16–255 colours | Fixed ANSI palette, bold/reverse for emphasis. |
| `none` | `NO_COLOR`, `--no-color`, `TERM=dumb`, `--theme mono` | Attributes only; no colour pairs. |

`--theme` and `ZUI_THEME` select a palette. Unknown names fall back to `default`.

## Palettes

| Name | Character |
|---|---|
| `default` | Deep navy background, blue borders, cyan accents. |
| `light` | Light background, dark text, blue/teal accents. |
| `dracula` | Purple/pink, dark grey background. |
| `gruvbox` | Warm retro browns with orange and green. |
| `nord` | Cool blue-grey with frost accents. |
| `solarized` | Solarized dark, blue/cyan with orange highlights. |
| `catppuccin` | Mocha-like mauve, peach and teal. |
| `mono` | No colour at all; bold, underline, reverse and dim only. |

```sh
ZUI_THEME=dracula zui choose one two
zui --theme gruvbox msgbox "Warm."
zui --theme mono --ascii confirm "Works anywhere"
```

Semantic styles are defined per palette: `screen`, `frame`, `title`, `text`,
`muted`, `accent`, `input`, `input_focus`, `caret`, `button`, `button_focus`,
`selection`, `selection_focus`, `shadow`, `header`, `footer`, `success`, `warn`,
`danger`, `gauge`, `gauge_ok`, `icon`, `mark`, `scroll`.

## Borders

Dialogs accept `--border`:

| Value | Look |
|---|---|
| `auto` | `rounded` when UTF-8, `ascii` otherwise (default). |
| `rounded` | `╭ ╮ ╰ ╯ ─ │` |
| `sharp` | `┌ ┐ └ ┘ ─ │` |
| `double` | `╔ ╗ ╚ ╝ ═ ║` |
| `thick` | `┏ ┓ ┗ ┛ ━ ┃` |
| `ascii` | `+ + + + - |` |
| `hidden` | Spaces; keeps the shape without visible lines. |
| `none` | No frame or shadow. |

`style` adds `block` (`▛▜▙▟█▀`) and `normal` (same as `sharp`).

## `style` colours

`--foreground`, `--background`, `--border-foreground`,
`--border-background`, `--padding-background` and `--margin-background` accept:

- names: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`
- 256-colour indices: `0`–`255`
- hex: `#rrggbb` (emits truecolour; terminal support varies)

```sh
zui style --foreground 212 --background 236 --padding 1,2 "hot pink"
zui style --foreground '#89b4fa' --border double "blue"
```

When stdout is a pipe, `style` prints the text without escapes unless
`ZUI_FORCE_COLOR=1`.

## Terminal capability checks

```sh
zsh -fc 'zmodload zsh/curses; print $ZCURSES_COLORS $ZCURSES_COLOR_PAIRS'
```

`zsh/curses` caps colours at the terminal's advertised count. It cannot address
truecolour pairs; truecolour is only used by the ANSI writer (`style`, help).
On a 16-colour terminal the 16-colour palette avoids high indices.

## Accessibility and fallbacks

- `--ascii` replaces box drawing, check marks, arrows and icons with ASCII.
- `--theme mono` removes colour but keeps bold/reverse focus cues.
- `NO_COLOR` is honoured everywhere.
- There is no high-contrast theme yet; `light` and `mono` are the closest.

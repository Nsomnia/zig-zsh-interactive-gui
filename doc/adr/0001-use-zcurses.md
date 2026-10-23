# ADR 0001: Build on zsh and zsh/curses

- Status: accepted
- Date: 2026-10-23

## Context

The goal is a gum-like prompt toolkit with dialog(1)-style full-screen windows,
deep configurability, and no compiled dependency. The repository is a zsh
project: users should be able to clone it and run it with the shell they already
have.

## Decision

Implement the UI in zsh using the built-in `zsh/curses` module, with one small
module per concern (`render`, `keys`, `editor`, `widgets`, `dialog`, `theme`).
Ship the CLI as `bin/zui` and expose the engine through `lib/zui.zsh`.

Key consequences of choosing zcurses:

- ncurses provides alternate-screen handling, colour pairs, window state and
  efficient screen diffing; we do not reimplement a terminal emitter.
- We can support 256 colours and a real `dialog(1)` look while remaining a
  single-language, zero-build project.
- The `zcurses` keypad API is unreliable on some zsh builds, so `lib/zui/keys.zsh`
  decodes CSI/SS3 bytes itself.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Go + Bubble Tea (reimplement gum) | Adds a toolchain and a build step; defeats the zsh-native constraint. |
| Zig + ncurses | Fast, but requires a compiler and C interop; the project is meant to be shell-native. |
| Pure ANSI escape writer | Full control and truecolour, but reimplementing cell diffing, resize and input is a large, bug-prone surface. |
| zsh/zle widgets | Excellent for line editing, but not suited to modal multi-widget dialogs and arbitrary button rows. |
| `dialog(1)` binary wrapper | Closest visual match, but cannot provide gum-style filtering, fuzzy lists, forms or arbitrary widget composition. |

## Consequences

- Requires `zsh` 5.9+ with `zcurses`; acceptable on macOS and mainstream Linux.
- Colour is limited to the terminal's advertised count (typically 256).
- Character width is assumed to be one cell (see `docs/LIMITATIONS.md`).
- UI state is global to the process; one dialog at a time.
- The result-vs-UI split is handled by temporarily pointing stdin/stdout at
  `/dev/tty` and restoring them before printing, preserving pipelines.

## Follow-ups

- Add a Unicode width helper for CJK/emoji.
- Optional mouse support via `zcurses mouse`.
- Interactive `table` mode with row selection.

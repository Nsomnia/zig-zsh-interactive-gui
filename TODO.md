# Roadmap

- [ ] Unicode width table for CJK, emoji and combining characters.
- [ ] Mouse support (click buttons, scroll lists) via `zcurses mouse`.
- [ ] Horizontal scroll in interactive `table` mode.
- [ ] Stream `spin --show-output` live instead of after completion.
- [ ] Harden resize: re-init curses when `zcurses resize` is unavailable.
- [ ] More palettes and a high-contrast theme.
- [ ] Per-command man pages generated from the option definitions.
- [ ] CI matrix for macOS and Linux with `zcurses` checks.
- [ ] Completion of option names, not just commands.
- [ ] Optional `--json` output for forms and checklists.
- [ ] 256-colour help option (`--help-color 256`) and extra tty-safe attributes
      such as blink, in addition to the current portable 8/16-colour help.
- [ ] Honour gum `--padding` on prompt dialogs (the dialog family currently uses
      a fixed two-column inner gutter).
- [ ] Syntax highlighting for `format --type code` (respect `--language`), and a
      richer Markdown renderer that keeps inline emphasis.
- [ ] dialog(1) box-type aliases in `zui dialog` for `textbox`, `fselect`,
      `dselect`, `editbox`, `passwordbox`, `radiolist`, `pause`, `prgbox`,
      `programbox`, `progressbox`, `rangebox`, `mixedform`, `mixedgauge` and
      `tailbox`.
- [ ] Wire the accepted-only dialog flags (`--cr-wrap`, `--column-separator`,
      `--tab-len`, `--item-help` rendering, `--print-size`, `--print-maxsize`,
      `--trace`, `--input-fd`, `--hfile`) to real behaviour.

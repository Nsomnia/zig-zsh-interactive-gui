# Limitations

Known constraints, in rough order of practical impact.

1. **Character width is one cell per character.** zsh has no `wcwidth` binding;
   CJK, emoji and combining marks will misalign borders and carets. ASCII, Latin
   and most box-drawing glyphs are fine. A width table or a small helper module
   would fix this.
2. **No mouse support.** `zsh/curses` can report mouse events, but no widget
   handles them. All navigation is keyboard-driven.
3. **Resize is best effort.** `WINCH` triggers `zcurses resize`, but some
   terminals/terminfo combinations need a full re-init. If a resize looks wrong,
   close and reopen the dialog.
4. **zcurses is capped at the advertised colour count** (usually 256). Theme
   colours are indices; truecolour is only used by the ANSI writer (`style`,
   help).
5. **`table` is static.** It parses and prints the table; it does not scroll or
   select rows. This is deliberate so it is safe in pipelines.
6. **Durations are integer units**: `500ms`, `5s`, `2m`, `1h`. Decimal seconds
   such as `0.5s` are rejected; use `500ms`.
7. **`run:` actions are shell evaluation.** `zui` executes them after restoring
   the terminal. Never build a `run:` action from untrusted input; prefer
   `print:` and run the command in the caller.
8. **One UI per process.** Dialog state is global (`_zui_dlg`, list/editor
   globals). Nested dialogs are not supported; run them sequentially or in
   separate processes.
9. **Alt-screen required.** Dumb terminals, some CI consoles and terminals
   without alternate-screen support will not render dialogs. Non-interactive
   commands (`style`, `format`, `join`, `table`, `log`, piped `pager`) still work.
10. **No images, sixels or hyperlinks.**
11. **Screen readers** see the curses output, not a semantic widget tree.
    `--ascii` and `--theme mono` improve visibility but do not add accessibility
    metadata.
12. **POSIX shells only.** `zsh` is required. Windows users need WSL or a
    zsh-equipped environment; the curses module must be available.
13. **UTF-8 detection is locale-based.** If the locale lies, force the desired
    mode with `--ascii` or a UTF-8 `LANG`.
14. **Integration tests use timing sleeps.** They are stable locally but may
    need larger waits on a very slow CI runner.

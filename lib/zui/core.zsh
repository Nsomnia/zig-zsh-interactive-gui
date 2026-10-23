# zui core: terminal lifecycle, environment, signals.
# Requires zsh/curses and a tty.  All UI is drawn on stdscr after stdin/stdout
# are pointed at /dev/tty, so command output stays pipeable.

typeset -g  ZUI_VERSION="0.1.0"
typeset -g  ZUI_APP="zui"
typeset -g  ZUI_ROOT="${ZUI_ROOT:-${0:A:h:h:h}}"
typeset -gi ZUI_UI_ACTIVE=0
typeset -gi ZUI_DEBUG="${ZUI_DEBUG:-0}"
typeset -gi ZUI_ASCII="${ZUI_ASCII:-0}"
typeset -gi ZUI_NO_COLOR="${ZUI_NO_COLOR:-0}"
typeset -g  ZUI_THEME="${ZUI_THEME:-default}"
typeset -g  ZUI_PROFILE=""          # none | 16 | 256
typeset -gi ZUI_ROWS=24 ZUI_COLS=80
typeset -gi _ZUI_RESIZED=0
typeset -gi _ZUI_TIMEOUT_HIT=0
typeset -g  _ZUI_SI="" _ZUI_SO=""
typeset -gi _ZUI_UI_DEPTH=0
typeset -gi _ZUI_LOADED=0

_zui_load() {
  emulate -L zsh
  (( _ZUI_LOADED )) && return 0
  local m
  for m in theme render keys editor widgets dialog help cli; do
    source "$ZUI_ROOT/lib/zui/$m.zsh" || return 1
  done
  source "$ZUI_ROOT/lib/zui/commands/common.zsh" || return 1
  local -a cmds=(choose confirm input write filter file pager spin table style format join log dialog msgbox yesno inputbox menu checklist form gauge infobox)
  for m in $cmds; do
    source "$ZUI_ROOT/lib/zui/commands/$m.zsh" || return 1
  done
  source "$ZUI_ROOT/lib/zui/commands/misc.zsh" || return 1
  _ZUI_LOADED=1
}

_zui_log() {
  (( ZUI_DEBUG )) || return 0
  print -ru2 -- "[zui] $*"
}

_zui_die() {
  print -ru2 -- "zui: $1"
  exit ${2:-2}
}

_zui_err() {
  print -ru2 -- "zui: $*"
}

zui::version() {
  print -r -- "zui $ZUI_VERSION (zsh $ZSH_VERSION, zcurses)"
}

zui::has_tty() {
  [[ -t 0 && -t 1 ]] && return 0
  [[ -c /dev/tty ]] || return 1
  { : </dev/tty } 2>/dev/null || return 1
  { : >/dev/tty } 2>/dev/null || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Color profile
# ---------------------------------------------------------------------------
zui::detect_profile() {
  emulate -L zsh
  if (( ZUI_NO_COLOR )) || [[ -n ${NO_COLOR-} ]] || [[ ${TERM-} == dumb ]]; then
    ZUI_PROFILE=none
  elif [[ ${COLORTERM-} == (truecolor|24bit) && ${ZUI_FORCE_256-} != 1 ]]; then
    # zcurses can only address 256 pairs; truecolor is used by the ANSI writer.
    ZUI_PROFILE=256
  else
    zmodload -F zsh/terminfo b:terminfo 2>/dev/null
    local colors=${terminfo[colors]:-8}
    if (( colors >= 256 )); then
      ZUI_PROFILE=256
    elif (( colors >= 16 )); then
      ZUI_PROFILE=16
    elif (( colors >= 8 )); then
      ZUI_PROFILE=16
    else
      ZUI_PROFILE=none
    fi
  fi
  print -r -- "$ZUI_PROFILE"
}

_zui_utf8() {
  (( ZUI_ASCII )) && return 1
  local l=${(L)${LC_ALL:-${LC_CTYPE:-${LANG:-}}}}
  [[ $l == *utf-8* || $l == *utf8* ]]
}

# ---------------------------------------------------------------------------
# Terminal size
# ---------------------------------------------------------------------------
_zui_term_size() {
  emulate -L zsh
  if (( ZUI_UI_ACTIVE )); then
    local -a p
    zcurses position stdscr p 2>/dev/null
    if (( ${#p} >= 6 )); then
      ZUI_ROWS=$p[5]; ZUI_COLS=$p[6]
      return 0
    fi
  fi
  local -a sz
  sz=(${(s: :)${$(stty size 2>/dev/null):-24 80}})
  ZUI_ROWS=${sz[1]:-24}; ZUI_COLS=${sz[2]:-80}
}

_zui_handle_winch() {
  _ZUI_RESIZED=1
}

_zui_handle_int() {
  _ZUI_ABORT=130
}

# ---------------------------------------------------------------------------
# UI lifecycle.  Saves the real stdin/stdout, points both at /dev/tty for
# curses, and restores them before any result is printed.
# ---------------------------------------------------------------------------
_zui_ui_begin() {
  emulate -L zsh
  (( _ZUI_UI_DEPTH++ ))
  (( _ZUI_UI_DEPTH > 1 )) && return 0
  zmodload zsh/curses 2>/dev/null || { _ZUI_UI_DEPTH=0; _zui_die "the zsh/curses module is required" 3 }
  zui::has_tty || { _ZUI_UI_DEPTH=0; _zui_die "interactive mode needs a terminal" 3 }

  _ZUI_SI="" _ZUI_SO=""
  if [[ -e /dev/tty ]]; then
    exec {_ZUI_SI}<&0 {_ZUI_SO}>&1
    exec 0</dev/tty 1>/dev/tty || {
      exec 0<&$_ZUI_SI 1>&$_ZUI_SO; _ZUI_UI_DEPTH=0
      _zui_die "cannot open /dev/tty" 3
    }
  fi

  zcurses init || {
    [[ -n $_ZUI_SI ]] && exec 0<&$_ZUI_SI 1>&$_ZUI_SO
    _ZUI_UI_DEPTH=0
    _zui_die "curses could not start (TERM=${TERM:-unset})" 3
  }

  ZUI_UI_ACTIVE=1
  _ZUI_ABORT=0
  ZUI_PROFILE=$(_zui_theme_profile)
  _zui_theme_init "$ZUI_THEME" "$ZUI_PROFILE"
  _zui_term_size
  _zui_clear
  print -n '\e[?25l'   # caret is drawn as a cell; hide the hardware cursor
  trap '_zui_handle_int' INT
  trap '_zui_handle_int' TERM HUP
  trap '_zui_handle_winch' WINCH
}

_zui_ui_end() {
  emulate -L zsh
  (( _ZUI_UI_DEPTH > 0 )) || return 0
  (( _ZUI_UI_DEPTH-- ))
  (( _ZUI_UI_DEPTH > 0 )) && return 0
  (( ZUI_UI_ACTIVE )) || return 0
  trap - INT TERM HUP WINCH
  zcurses end
  print -n '\e[?25h'
  ZUI_UI_ACTIVE=0
  if [[ -n $_ZUI_SI ]]; then
    exec 0<&$_ZUI_SI 1>&$_ZUI_SO
    exec {_ZUI_SI}<&- {_ZUI_SO}>&-
    _ZUI_SI="" _ZUI_SO=""
  fi
}

# Resize without destroying the screen model.
_zui_check_resize() {
  emulate -L zsh
  (( _ZUI_RESIZED )) || return 0
  _ZUI_RESIZED=0
  local -a p
  zcurses position stdscr p 2>/dev/null
  (( ${#p} >= 6 )) || return 0
  if (( p[5] != ZUI_ROWS || p[6] != ZUI_COLS )); then
    zcurses resize $p[5] $p[6] endwin 2>/dev/null
    _zui_theme_reapply
  fi
  ZUI_ROWS=$p[5]; ZUI_COLS=$p[6]
}

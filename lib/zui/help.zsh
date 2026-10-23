# zui help: colourful, wrapped, pipe-safe help pages.

typeset -ga _ZUI_COMMANDS=(choose confirm input write filter file pager spin style format join table log dialog msgbox yesno inputbox menu checklist form gauge infobox version completion)
typeset -ga _ZUI_GROUPS=(interactive presentation dialog utility)
typeset -gA _ZUI_GROUP_TITLE=(
  interactive "INTERACTIVE"
  presentation "PRESENTATION"
  dialog "DIALOGS"
  utility "UTILITY"
)
typeset -gA _ZUI_CMD_DESC=() _ZUI_CMD_USAGE=() _ZUI_CMD_LONG=() _ZUI_CMD_GROUP=()
typeset -gA _ZUI_EXAMPLES=() _ZUI_NOTES=() _ZUI_KEYMAP=()

_ZUI_CMD_GROUP[choose]=interactive
_ZUI_CMD_GROUP[confirm]=interactive
_ZUI_CMD_GROUP[input]=interactive
_ZUI_CMD_GROUP[write]=interactive
_ZUI_CMD_GROUP[filter]=interactive
_ZUI_CMD_GROUP[file]=interactive
_ZUI_CMD_GROUP[pager]=interactive
_ZUI_CMD_GROUP[spin]=interactive
_ZUI_CMD_GROUP[style]=presentation
_ZUI_CMD_GROUP[format]=presentation
_ZUI_CMD_GROUP[join]=presentation
_ZUI_CMD_GROUP[table]=presentation
_ZUI_CMD_GROUP[log]=presentation
_ZUI_CMD_GROUP[dialog]=dialog
_ZUI_CMD_GROUP[msgbox]=dialog
_ZUI_CMD_GROUP[yesno]=dialog
_ZUI_CMD_GROUP[inputbox]=dialog
_ZUI_CMD_GROUP[menu]=dialog
_ZUI_CMD_GROUP[checklist]=dialog
_ZUI_CMD_GROUP[form]=dialog
_ZUI_CMD_GROUP[gauge]=dialog
_ZUI_CMD_GROUP[infobox]=dialog
_ZUI_CMD_GROUP[version]=utility
_ZUI_CMD_GROUP[completion]=utility

_ZUI_CMD_DESC[version]="Print version information."
_ZUI_CMD_DESC[completion]="Generate a shell completion script."
_ZUI_CMD_USAGE[version]="zui version"
_ZUI_CMD_USAGE[completion]="zui completion <zsh|bash>"

_zui_termw() {
  local w=${COLUMNS:-80}
  [[ $w == <-> ]] || w=80
  (( w <= 0 )) && w=80
  (( w < 40 )) && w=40
  (( w > 110 )) && w=110
  REPLY=$w
}

_zui_c() { # style text
  printf '%s%s%s' "$(_zui_ansi "$1")" "$2" "$(_zui_ansi reset)"
}

_zui_utf8_hint() { _zui_utf8; }

_zui_rule() {
  local w=$1
  local ch='─'; _zui_utf8 || ch='-'
  local line; _zui_repeat "$ch" "$w"; line=$REPLY
  printf '%s\n' "$(_zui_c dim "$line")"
}

_zui_h2() {
  local t=$1
  printf '\n%s\n' "$(_zui_c heading "$t")"
}

_zui_help_banner() {
  local w=$1
  local tl tr bl br h v
  if _zui_utf8; then tl='╭'; tr='╮'; bl='╰'; br='╯'; h='─'; v='│'; else tl='+'; tr='+'; bl='+'; br='+'; h='-'; v='|'; fi
  local inner=$(( w - 4 ))
  local left=" zui $ZUI_VERSION" right="zsh + zcurses "
  local pad=$(( inner - ${#left} - ${#right} ))
  (( pad < 1 )) && pad=1
  local hline; _zui_repeat "$h" "$inner"; hline=$REPLY
  print -r -- "$(_zui_c title "$tl$hline$tr")"
  print -r -- "$(_zui_c title "$v")$(_zui_c bold "$left")${(l:pad:: :)} $(_zui_c dim "$right")$(_zui_c title "$v")"
  local tag=" gum-style commands with a dialog(1) terminal UI."
  _zui_truncate "$tag" $inner
  print -r -- "$(_zui_c title "$v")$(_zui_c text "${(r:inner:: :)REPLY}")$(_zui_c title "$v")"
  local meta=" 256 colours · tty-safe · zcurses"
  _zui_truncate "$meta" $inner
  print -r -- "$(_zui_c title "$v")$(_zui_c dim "${(r:inner:: :)REPLY}")$(_zui_c title "$v")"
  print -r -- "$(_zui_c title "$bl$hline$br")"
}

_zui_help_row() { # left desc width
  local left=$1 desc=$2 w=$3
  local max=${_ZUI_ROWMAX:-28}
  local indent=$(( 2 + max + 2 ))
  local avail=$(( w - indent ))
  (( avail < 18 )) && avail=18
  _zui_wrap "$desc" $avail
  local -a lines=("${_ZUI_LINES[@]}")
  local i
  for (( i = 1; i <= ${#lines}; i++ )); do
    if (( i == 1 )); then
      printf '  %s%*s  %s\n' "$(_zui_c opt "$left")" $(( max - ${#left} )) "" "${lines[i]}"
    else
      printf '%*s%s\n' $indent "" "${lines[i]}"
    fi
  done
}

_zui_opt_left() { # short long type default -> REPLY
  local short=$1 long=$2 type=$3
  local l="    "
  [[ -n $short ]] && l="-$short, "
  l+="--$long"
  case $type in
    (str)   l+=" VALUE" ;;
    (int)   l+=" N" ;;
    (multi) l+=" VALUE" ;;
  esac
  REPLY=$l
}

_zui_help_options() { # cmd width
  local cmd=$1 w=$2
  local defvar="_ZUI_OPTDEF_$cmd"
  (( ${+parameters[$defvar]} )) || return 0
  local -a defs
  defs=("${(@P)defvar}")
  (( ${#defs} )) || return 0

  # Column width from the longest option signature.
  local def short long type desc defval left max=0
  for def in "${defs[@]}"; do
    IFS='|' read -r short long type desc defval <<< "$def"
    _zui_opt_left "$short" "$long" "$type"; left=$REPLY
    (( ${#left} > max )) && max=${#left}
  done
  (( max < 22 )) && max=22
  (( max > 34 )) && max=34
  typeset -g _ZUI_ROWMAX=$max

  _zui_h2 "OPTIONS"
  _zui_help_row "-h, --help" "Show this help page." $w
  local -a extra
  for def in "${defs[@]}"; do
    IFS='|' read -r short long type desc defval <<< "$def"
    _zui_opt_left "$short" "$long" "$type"; left=$REPLY
    if [[ $type != flag && -n $defval && $defval != 0 ]]; then
      desc+=" (default: $defval)"
    fi
    _zui_help_row "$left" "$desc" $w
  done
}

_zui_help_globals() {
  local w=$1
  _zui_h2 "GLOBAL OPTIONS"
  typeset -g _ZUI_ROWMAX=26
  _zui_help_row "-h, --help" "Show help for a command." $w
  _zui_help_row "-v, --version" "Print version information." $w
  _zui_help_row "--theme NAME" "Palette: default, light, dracula, gruvbox, nord, solarized, catppuccin, mono." $w
  _zui_help_row "--no-color" "Disable colour (also honours NO_COLOR)." $w
  _zui_help_row "--ascii" "ASCII borders and glyphs instead of Unicode." $w
  _zui_help_row "--debug" "Write debug information to stderr." $w
}

_zui_help_keys() { # cmd width
  local cmd=$1 w=$2
  local data=${_ZUI_KEYMAP[$cmd]:-}
  [[ -z $data ]] && return 0
  _zui_h2 "KEYS"
  local line k d
  for line in "${(@f)data}"; do
    k=${line%%|*}; d=${line#*|}
    _zui_help_row "$k" "$d" $w
  done
}

_zui_help_examples() { # cmd width
  local cmd=$1 w=$2
  local data=${_ZUI_EXAMPLES[$cmd]:-}
  [[ -z $data ]] && return 0
  _zui_h2 "EXAMPLES"
  local line
  for line in "${(@f)data}"; do
    [[ -z $line ]] && { print; continue; }
    printf '  %s %s\n' "$(_zui_c accent '❯')" "$line"
  done
}

_zui_help_notes() { # cmd
  local cmd=$1
  local data=${_ZUI_NOTES[$cmd]:-}
  [[ -z $data ]] && return 0
  _zui_h2 "NOTES"
  local line
  for line in "${(@f)data}"; do
    printf '  %s %s\n' "$(_zui_c dim '•')" "$line"
  done
}

_zui_help_cmd() { # cmd
  local cmd=$1
  _zui_termw; local w=$REPLY
  local desc=${_ZUI_CMD_DESC[$cmd]:-}
  local usage=${_ZUI_CMD_USAGE[$cmd]:-}
  local long=${_ZUI_CMD_LONG[$cmd]:-$desc}

  print
  printf '%s\n' "$(_zui_c title "zui $cmd")"
  [[ -n $desc ]] && printf '%s\n' "$(_zui_c dim "$desc")"
  _zui_rule $(( w - 2 ))

  _zui_h2 "USAGE"
  printf '  %s\n' "$(_zui_c cmd "$usage")"
  [[ -n $long ]] && printf '\n  %s\n' "$long"

  _zui_help_options "$cmd" $w
  _zui_help_keys "$cmd" $w
  _zui_help_examples "$cmd" $w
  _zui_help_notes "$cmd"

  print
  printf '  %s\n' "$(_zui_c dim 'Global: --theme NAME  --no-color  --ascii  --debug')"
  printf '%s\n' "$(_zui_c dim "Run 'zui help' for all commands, or 'zui help <command>' for another page.")"
  print
}

_zui_help_main() {
  _zui_termw; local w=$REPLY
  print
  _zui_help_banner $w
  print
  _zui_wrap 'A gum-compatible prompt toolkit rendered as dialog(1)-style terminal windows.' $(( w - 4 ))
  local tag
  for tag in "${_ZUI_LINES[@]}"; do printf '  %s\n' "$(_zui_c dim "$tag")"; done
  _zui_wrap 'Every interactive command is a small zcurses app; every dialog accepts any number of action buttons.' $(( w - 4 ))
  for tag in "${_ZUI_LINES[@]}"; do printf '  %s\n' "$(_zui_c dim "$tag")"; done

  _zui_h2 "USAGE"
  printf '  %s\n' "$(_zui_c cmd 'zui <command> [flags] [arguments...]')"
  printf '  %s\n' "$(_zui_c dim 'zui <command> --help')"

  local g cmd
  for g in "${_ZUI_GROUPS[@]}"; do
    _zui_h2 "${_ZUI_GROUP_TITLE[$g]}"
    typeset -g _ZUI_ROWMAX=16
    for cmd in "${_ZUI_COMMANDS[@]}"; do
      [[ ${_ZUI_CMD_GROUP[$cmd]:-} == "$g" ]] || continue
      _zui_help_row "$cmd" "${_ZUI_CMD_DESC[$cmd]:-}" $w
    done
  done

  _zui_help_globals $w

  _zui_h2 "EXAMPLES"
  printf '  %s %s\n' "$(_zui_c accent '❯')" "printf 'alpha\nbeta\ngamma' | zui choose --header 'Pick one'"
  printf '  %s %s\n' "$(_zui_c accent '❯')" "zui inputbox --title 'Name' --message 'What should we call you?'"
  printf '  %s %s\n' "$(_zui_c accent '❯')" "zui msgbox --icon warn --message 'Disk almost full.' --button 'OK=exit:0' --button 'Details=run:df -h'"
  printf '  %s %s\n' "$(_zui_c accent '❯')" "zui confirm --affirmative Deploy --negative Cancel && ./deploy.sh"
  printf '  %s %s\n' "$(_zui_c accent '❯')" "zui style --border rounded --padding 1,2 --foreground 212 'Hello'"

  _zui_h2 "DIALOG ACTIONS"
  printf '  Buttons are %s. Actions: %s %s %s %s %s\n' \
    "$(_zui_c text 'Label=action')" \
    "$(_zui_c cmd 'exit:N')" "$(_zui_c cmd 'accept')" "$(_zui_c cmd 'cancel')" \
    "$(_zui_c cmd 'print:TEXT')" "$(_zui_c cmd 'run:COMMAND')"

  _zui_h2 "ENVIRONMENT"
  _zui_help_row "NO_COLOR" "Disable colour when set." $w
  _zui_help_row "ZUI_THEME" "Default palette name." $w
  _zui_help_row "ZUI_ASCII" "Set to 1 for ASCII-only glyphs." $w

  print
  printf '%s\n' "$(_zui_c dim "Docs: README.md · docs/COMMANDS.md · docs/DIALOGS.md · docs/FRAMEWORK.md")"
  print
}

_zui_help() {
  [[ -z $ZUI_ANSI_PROFILE ]] && ZUI_ANSI_PROFILE=$(_zui_ansi_profile)
  local cmd=${1:-}
  if [[ -z $cmd ]]; then
    _zui_help_main
    return 0
  fi
  if [[ $cmd == help ]]; then _zui_help_main; return 0; fi
  if (( ! ${+_ZUI_CMD_DESC[$cmd]} )) && [[ $cmd != (version|completion) ]]; then
    print -ru2 -- "zui: no help for unknown command '$cmd'"
    return 2
  fi
  _zui_help_cmd "$cmd"
}

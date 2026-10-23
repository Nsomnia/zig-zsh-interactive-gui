# zui gauge

_ZUI_OPTDEF_gauge=(
  '|percent|int|Percentage to display (0-100)|0'
  '|title|str|Title shown in the title bar|Progress'
  '|message|str|Label drawn under the bar|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|timeout|str|Close after a duration|'
  '|print|flag|Print the gauge to stdout instead of opening a dialog|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[gauge]="Display a progress gauge, interactively or as plain output."
_ZUI_CMD_USAGE[gauge]="zui gauge [flags]"
_ZUI_CMD_LONG[gauge]="Shows a filled bar with a percentage. By default it opens a dialog and waits for a key; --print (or a non-terminal stdout) writes the bar directly, which is handy in scripts."
_ZUI_KEYMAP[gauge]=$'any key|Close the dialog\nEsc|Close the dialog'
_ZUI_EXAMPLES[gauge]=$'zui gauge --percent 42 --message "Uploading"\nzui gauge --print --percent 99 --width 30\nfor p in 0 25 50 75 100; do zui gauge --print --percent $p; done'
_ZUI_NOTES[gauge]=$'The interactive gauge is static: pass a new percentage to show a new value.\nThe bar assumes one cell per character.'

_zui_gauge_plain() { # percent width label
  local pct=$1 w=${2:-40} label=${3-}
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  (( w < 1 )) && w=1
  local filled=$(( w * pct / 100 )) empty=$(( w - filled ))
  local bar
  if _zui_utf8; then bar="${(l:filled::█:)}${(l:empty::░:)}"; else bar="${(l:filled::#:)}${(l:empty::.:)}"; fi
  local prefix="" suffix=""
  if [[ ${ZUI_ANSI_PROFILE:-none} != none ]]; then
    prefix=$(_zui_sgr 114 - bold); suffix=$'\e[0m'
  fi
  printf '%s[%s] %3d%%%s\n' "$prefix" "$bar" "$pct" "$suffix"
  [[ -n $label ]] && print -r -- "$label"
}

_zui_cmd_gauge() {
  local pct=${_ZUI_OPT[percent]:-0}
  [[ $pct == <-> ]] || pct=0
  local label=${_ZUI_OPT[message]:-}
  local w=${_ZUI_OPT[width]:-0}
  [[ $w == <-> ]] || w=0
  (( w > 0 )) || w=40

  if (( ${_ZUI_OPT[print]:-0} )) || [[ ! -t 1 ]]; then
    _zui_gauge_plain $pct $w "$label"
    return 0
  fi
  (( w > 6 )) && w=$(( w - 6 ))

  _zui_dialog_reset
  _zui_dlg[widget]=gauge
  _zui_dlg[percent]=$pct
  _zui_dlg[label]=$label
  _zui_dlg[message]=""
  _zui_dlg[icon]=""
  _zui_dlg[title]=${_ZUI_OPT[title]:-Progress}
  _zui_dlg[hints]="press any key to close"
  _zui_dlg[esc_code]=0
  _zui_dialog_common
  _zui_dlg[message]=""
  _zui_dlg[width]=$(( w + 8 ))
  _zui_dlg_buttons=()
  _zui_dialog_run
  return $?
}

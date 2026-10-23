# zui pager

_ZUI_OPTDEF_pager=(
  '|line-numbers|flag|Show line numbers|0'
  '|show-line-numbers|flag|Show line numbers (alias)|0'
  '|soft-wrap|flag|Wrap long lines at the window width|1'
  '|no-soft-wrap|flag|Truncate long lines instead of wrapping|0'
  '|header|str|Title shown in the dialog title bar|'
  '|height|int|Window height in rows (0 = fit the terminal)|0'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|foreground|str|Text foreground colour|'
  '|background|str|Text background colour|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_DIALOGDEF[@]}"
)

_ZUI_CMD_DESC[pager]="Scroll through text or a file in a framed window."
_ZUI_CMD_USAGE[pager]="zui pager [flags] [file]"
_ZUI_CMD_LONG[pager]="Reads a file, or stdin when no file is given. When stdout is not a terminal the content is printed unchanged; otherwise it is shown in a scrollable window. No text is written to stdout in interactive mode."
_ZUI_KEYMAP[pager]=$'↑/↓|Scroll one line\nPgUp/PgDn|Scroll five lines\nHome/End|Jump to the top or bottom\nq/Esc/Enter|Close'
_ZUI_EXAMPLES[pager]=$'zui pager README.md\nkubectl describe pod my-pod | zui pager --line-numbers\nzui pager --header "diff" < change.patch'
_ZUI_NOTES[pager]=$'Piping through zui pager is a no-op for non-interactive output, so it is safe in scripts.\nThe pager exits 0 when closed and 124 on timeout.'

_zui_cmd_pager() {
  local file=${_ZUI_ARGS[1]:-}
  local content
  if [[ -n $file ]]; then
    [[ -r $file ]] || { _zui_err "cannot read '$file'"; return 2; }
    content=$(<"$file")
  elif [[ -t 0 ]]; then
    _zui_err "no input (pass a file or pipe text)"
    return 2
  else
    content=$(cat)
  fi

  if [[ ! -t 1 ]]; then
    print -r -- "$content"
    return 0
  fi

  if (( ${_ZUI_OPT[line-numbers]:-0} || ${_ZUI_OPT[show-line-numbers]:-0} )); then
    local -a lines
    lines=("${(@f)content}")
    local i w=${#${#lines}}
    content=""
    for (( i = 1; i <= ${#lines}; i++ )); do
      printf -v REPLY "%${w}d  %s" $i "${lines[i]}"
      content+="$REPLY"$'\n'
    done
    content=${content%$'\n'}
  fi

  _zui_dialog_reset
  _zui_dlg[widget]=text
  _zui_dlg[message]=$content
  _zui_dlg[esc_code]=0
  _zui_dlg[hints]="↑↓ scroll  PgUp/PgDn  q quit"
  _zui_dialog_common
  _zui_dlg[nowrap]=$(( ${_ZUI_OPT[no-soft-wrap]:-0} || ! ${_ZUI_OPT[soft-wrap]:-1} ))
  _zui_dlg[message]=$content
  _zui_dlg[title]=${_ZUI_OPT[header]:-${file:t}}
  [[ -z ${_zui_dlg[title]} ]] && _zui_dlg[title]=Pager
  local h=${_ZUI_OPT[height]:-0}
  [[ $h == <-> ]] || h=0
  (( h > 0 && h > ZUI_ROWS - 4 )) && h=$(( ZUI_ROWS - 4 ))
  _zui_dlg[height]=$h
  _zui_dlg_buttons=()
  [[ -n ${_ZUI_OPT[foreground]:-} ]] && _ZUI_OPT[text.foreground]=${_ZUI_OPT[foreground]}
  [[ -n ${_ZUI_OPT[background]:-} ]] && _ZUI_OPT[text.background]=${_ZUI_OPT[background]}
  _zui_dialog_run
  return $?
}

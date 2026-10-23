# zui spin

_ZUI_OPTDEF_spin=(
  's|spinner|str|Spinner style: dot, line, minidot, jump, pulse, meter, ellipsis|dot'
  '|title|str|Label shown next to the spinner|Working...'
  'a|align|str|Label alignment: left, center, right|left'
  '|interval|int|Frame interval in milliseconds|80'
  '|show-output|flag|Print the command stdout and stderr when it finishes|0'
  '|show-stdout|flag|Print the command stdout when it finishes|0'
  '|show-error|flag|Print the command stderr when it finishes|0'
  '|show-stderr|flag|Print the command stderr when it finishes|0'
  '|show-help|flag|Show the key-hint footer|1'
  '|no-show-help|flag|Hide the key-hint footer|0'
  '|timeout|str|Abort the command and exit 124 after a duration|'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_PADDINGDEF[@]}"
)
_ZUI_CMD_DESC[spin]="Show a spinner while a command runs."
_ZUI_CMD_USAGE[spin]="zui spin [flags] -- command [args...]"
_ZUI_CMD_LONG[spin]="Runs a command in the background while drawing a framed spinner, then forwards the requested output. The command's exit status becomes zui's exit status. Esc or Ctrl-C stops the command and returns 130."
_ZUI_KEYMAP[spin]=$'Esc|Cancel the command (exit 130)\nCtrl-C|Cancel the command (exit 130)'
_ZUI_EXAMPLES[spin]=$'zui spin --title "Fetching..." -- git fetch --all\nzui spin --spinner pulse --show-error -- make -j8\nzui spin -- sleep 3 --show-output'
_ZUI_NOTES[spin]=$'The child command receives /dev/null as stdin so it cannot steal keystrokes.\nWhen stdout is not a terminal the command runs directly and its output is not suppressed.'

_zui_spinner_frames() { # name -> frames array in REPLY? sets _zui_frames
  local n=$1
  typeset -ga _zui_frames
  if ! _zui_utf8; then
    _zui_frames=('-' '\' '|' '/')
    return
  fi
  case $n in
    (line)    _zui_frames=('-' '\' '|' '/') ;;
    (minidot) _zui_frames=('⠐' '⠂' '⠈' '⠁' '⠈' '⠂') ;;
    (jump)    _zui_frames=('⢄' '⢂' '⢁' '⡁' '⡈' '⡐' '⡠') ;;
    (pulse)   _zui_frames=('▁' '▃' '▅' '▇' '▅' '▃') ;;
    (meter)   _zui_frames=('▱' '▰') ;;
    (ellipsis) _zui_frames=('.' '..' '...') ;;
    (*)       _zui_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') ;;
  esac
}

_zui_spin_draw() { # frame index start title align
  local i=$1 t0=$2 title=$3 align=$4
  local rows=$ZUI_ROWS cols=$ZUI_COLS
  (( ${#_zui_frames} )) || return 0
  local fr=${_zui_frames[$(( i % ${#_zui_frames} + 1 ))]}
  local elapsed
  printf -v elapsed '%.1fs' $(( EPOCHREALTIME - t0 ))
  local inner=$(( ${#title} + ${#elapsed} + 9 ))
  (( inner < 30 )) && inner=30
  (( inner > cols - 2 )) && inner=$(( cols - 2 ))
  local pt=0 pr=0 pb=0 pl=0
  if [[ -n ${_ZUI_OPT[padding]:-} ]] && _zui_style_pad "${_ZUI_OPT[padding]}"; then
    pt=$_ZUI_BOX[1]; pr=$_ZUI_BOX[2]; pb=$_ZUI_BOX[3]; pl=$_ZUI_BOX[4]
  fi
  local w=$(( inner + 2 + pl + pr )) h=$(( 3 + pt + pb ))
  local x=$(( (cols - w) / 2 )) y=$(( (rows - h) / 2 ))
  _zui_clear
  _zui_frame $y $x $h $w "" "${_ZUI_STYLE[title]}" "${_ZUI_STYLE[frame]}"
  local tx=$(( x + 2 + pl )) ty=$(( y + 1 + pt ))
  case $align in
    (center) tx=$(( x + (w - ${#title}) / 2 )) ;;
    (right)  tx=$(( x + w - 3 - pr - ${#title} )) ;;
  esac
  (( tx < x + 1 + pl )) && tx=$(( x + 1 + pl ))
  _zui_put $ty $(( x + 2 + pl )) "$fr" "${_ZUI_STYLE[accent]}"
  _zui_put $ty $tx "$title" "${_ZUI_STYLE[title]}"
  _zui_truncate "$elapsed" $(( w - 4 - pl - pr ))
  _zui_put $ty $(( x + w - 3 - pr - ${#REPLY} )) "$REPLY" "${_ZUI_STYLE[muted]}"
  _zui_present
}

_zui_cmd_spin() {
  local -a cmd=("${_ZUI_ARGS[@]}")
  if (( ${#cmd} == 0 )); then
    _zui_err "no command given; use: zui spin -- command [args...]"
    return 2
  fi

  if [[ ! -t 1 ]]; then
    "${cmd[@]}"
    return $?
  fi

  _zui_spinner_frames "${_ZUI_OPT[spinner]:-dot}"
  local interval=${_ZUI_OPT[interval]:-80}
  [[ $interval == <-> && $interval -ge 10 ]] || interval=80
  local title=${_ZUI_OPT[title]:-Working...}
  local align=${_ZUI_OPT[align]:-left}
  local timeout=0
  [[ -n ${_ZUI_OPT[timeout]:-} ]] && { _zui_duration "${_ZUI_OPT[timeout]}"; timeout=$REPLY; }
  local tmp=$(mktemp -d "${TMPDIR:-/tmp}/zui-spin.XXXXXX") || return 3
  local t0=$EPOCHREALTIME code=0 i=0

  _zui_ui_begin
  _zui_apply_style_opts
  _zui_border_set "${_ZUI_OPT[border]:-auto}"
  ( "${cmd[@]}" >"$tmp/out" 2>"$tmp/err" </dev/null; print -r -- $? >"$tmp/status" ) &
  local pid=$!

  while [[ ! -e $tmp/status ]]; do
    (( _ZUI_ABORT )) && { kill -TERM $pid 2>/dev/null; sleep 0.1; kill -KILL $pid 2>/dev/null; code=130; break; }
    if (( timeout > 0 && EPOCHREALTIME - t0 >= timeout )); then
      kill -TERM $pid 2>/dev/null; sleep 0.1; kill -KILL $pid 2>/dev/null
      code=124; break
    fi
    _zui_check_resize
    _zui_spin_draw $i $t0 "$title" "$align"
    (( i++ ))
    _zui_readkey $interval
    local kr=$?
    if (( kr == 2 )); then
      kill -TERM $pid 2>/dev/null
      sleep 0.1
      kill -KILL $pid 2>/dev/null
      code=130
      break
    fi
    if (( kr == 0 )) && [[ $KEY == (ESC|q) ]]; then
      kill -TERM $pid 2>/dev/null
      sleep 0.1
      kill -KILL $pid 2>/dev/null
      code=130
      break
    fi
  done
  wait $pid 2>/dev/null
  if (( code == 0 )) && [[ -r $tmp/status ]]; then
    code=$(<$tmp/status)
    [[ $code == <-> ]] || code=1
  fi
  _zui_ui_end

  (( ${_ZUI_OPT[show-output]:-0} || ${_ZUI_OPT[show-stdout]:-0} )) && [[ -s $tmp/out ]] && cat "$tmp/out"
  (( ${_ZUI_OPT[show-output]:-0} || ${_ZUI_OPT[show-error]:-0} || ${_ZUI_OPT[show-stderr]:-0} )) \
    && [[ -s $tmp/err ]] && cat "$tmp/err" >&2
  rm -rf "$tmp"
  return $code
}

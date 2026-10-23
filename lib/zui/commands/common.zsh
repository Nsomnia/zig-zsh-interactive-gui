# Shared helpers for command implementations.

typeset -ga _zui_items=() _zui_item_labels=()

# Padding is a gum prompt option, shared by the prompt-style commands.
_ZUI_PADDINGDEF=(
  '|padding|str|Inner padding: N or V,H or T,R,B,L|0'
)

# dialog(1) common options, shared by every dialog-family command.
_ZUI_DIALOGDEF=(
  '|ok-label|str|Accept button label (overrides the default OK label)|'
  '|cancel-label|str|Cancel button label (overrides the default Cancel label)|'
  '|extra-button|flag|Add an extra button that exits 0|0'
  '|extra-label|str|Label for the extra button|Extra'
  '|help-button|flag|Add a Help button that exits 0|0'
  '|help-label|str|Label for the help button|Help'
  '|exit-label|str|Accept button label (dialog alias for --ok-label)|'
  '|no-ok|flag|Hide the accept button|0'
  '|no-cancel|flag|Hide the cancel button and ignore Esc|0'
  '|no-items|flag|Do not read items from stdin|0'
  '|item-help|flag|Treat the value after --label-delimiter as help text|0'
  '|quoted|flag|Wrap each output value in double quotes|0'
  '|single-quoted|flag|Wrap each output value in single quotes|0'
  '|colors|flag|Enable colour (accepted; colour is automatic)|0'
  '|clear|flag|Clear the screen before drawing (accepted; always on)|0'
  '|no-mouse|flag|Ignore mouse events (accepted; mouse is not enabled)|0'
  '|defaultno|flag|Focus the negative button or second button|0'
  '|default-item|str|Item or field focused when the dialog opens|'
  '|backtitle|str|Text shown at the bottom of the dialog|'
  '|hline|str|Replace the generated hint line with this text|'
  '|no-shadow|flag|Do not draw a drop shadow|0'
  '|ascii-lines|flag|Use ASCII box-drawing characters|0'
  '|max-input|int|Maximum input length (0 = unlimited)|0'
  '|insecure|flag|Mask input as if --password were given|0'
  '|output-fd|int|Write the result to this file descriptor|1'
  '|stderr|flag|Write the result to stderr|0'
  '|stdout|flag|Write the result to stdout|0'
  '|output-separator|str|String placed between multiple output values|'
  '|separate-output|flag|Print multiple values one per line (the default)|0'
  '|show-help|flag|Show the hint footer|1'
  '|no-show-help|flag|Hide the hint footer|0'
  '|beep|flag|Ring the terminal bell after closing|0'
  '|beep-after|flag|Ring the terminal bell after closing (dialog alias)|0'
  '|sleep|str|Keep the final frame on screen for a duration|'
  '|yes-label|str|Label for the yes button (dialog alias)|'
  '|no-label|str|Label for the no button (dialog alias)|'
  '|aspect|str|Window aspect ratio (accepted)|'
  '|begin|str|Window position as "y x" (accepted)|'
  '|color-mode|str|Colour mode mask (accepted; colour is automatic)|'
  '|column-separator|str|Separator between list columns (accepted)|'
  '|cr-wrap|flag|Preserve carriage returns in wrapped text|0'
  '|cursor-off-label|str|Label for the cursor-off state (accepted)|'
  '|date-format|str|Date format for date widgets (accepted)|'
  '|erase-on-exit|flag|Erase the dialog on exit (always on)|0'
  '|help-status|flag|Return dialog state with the help button (accepted)|0'
  '|help-tags|flag|Include tags with help output (accepted)|0'
  '|hfile|str|Help file shown by the help button (accepted)|'
  '|ignore|flag|Ignore unknown keys instead of cancelling|0'
  '|input-fd|int|Read input from this file descriptor (accepted)|0'
  '|keep-tite|flag|Keep the terminal in tite mode (accepted)|0'
  '|keep-window|flag|Keep the window after exit (accepted)|0'
  '|last-key|flag|Print the last key pressed (accepted)|0'
  '|lines|flag|Draw separator lines (accepted)|1'
  '|no-lines|flag|Hide separator lines (accepted)|0'
  '|mouse|flag|Enable mouse events (accepted; not implemented)|0'
  '|nl-expand|flag|Expand newlines in the message (accepted)|0'
  '|no-nl-expand|flag|Do not expand newlines (accepted)|0'
  '|print-maxsize|flag|Print terminal size and exit (accepted)|0'
  '|print-size|flag|Print the window size and exit (accepted)|0'
  '|print-text-only|str|Measure text without drawing (accepted)|'
  '|print-text-size|str|Measure text without drawing (accepted)|'
  '|reorder|flag|Allow reordering list items (accepted)|0'
  '|scrollbar|flag|Draw a scrollbar (accepted)|0'
  '|separate-widget|str|Separator between widgets (accepted)|'
  '|shadow|flag|Draw the drop shadow|1'
  '|size-err|flag|Warn when the dialog does not fit (accepted)|0'
  '|tab-correct|flag|Correct tabs in the message|0'
  '|tab-len|int|Tab width for --tab-correct|8'
  '|time-format|str|Time format for time widgets (accepted)|'
  '|trace|str|Write a trace to this file (accepted)|'
  '|trim|flag|Trim whitespace from the message|0'
  '|visit-items|flag|Let the cursor visit list items (accepted)|0'
  '|week-start|str|First day of the week (accepted)|'
  '|hot-list|flag|Enable hot-list keys|1'
  '|no-hot-list|flag|Disable hot-list keys|0'
  '|kill|flag|Enable Esc-to-kill|1'
  '|no-kill|flag|Disable Esc-to-kill|0'
  '|tags|flag|Show item tags|1'
  '|no-tags|flag|Hide item tags|0'
  '|collapse|flag|Collapse empty lines|1'
  '|no-collapse|flag|Keep empty lines|0'
  '|items|flag|Read items from the widget arguments|1'
  '|and-widget|flag|Chain another dialog (accepted)|0'
  '|create-rc|str|Write a resource file (accepted)|'
)


# Value of an option, falling back to a default.
_zui_o() {
  local n=$1 d=${2-}
  local v=${_ZUI_OPT[$n]-}
  [[ -z $v ]] && v=$d
  REPLY=$v
}

# Split a multi-valued option into _ZUI_MULTI_ARR.
_zui_multi() {
  local n=$1
  typeset -ga _ZUI_MULTI_ARR
  local v=${_ZUI_OPT[$n]:-}
  [[ -z $v ]] && { _ZUI_MULTI_ARR=(); return 0; }
  _ZUI_MULTI_ARR=("${(@f)v}")
}

_zui_opt_int() { REPLY=${_ZUI_OPT[$1]:-0}; [[ $REPLY == <-> ]] || REPLY=0; }

_zui_build_buttons() { # fallback ok label, cancel label
  local ok=${1:-OK} cancel=${2:-Cancel}
  [[ -n ${_ZUI_OPT[ok-label]:-} ]] && ok=${_ZUI_OPT[ok-label]}
  [[ -n ${_ZUI_OPT[exit-label]:-} ]] && ok=${_ZUI_OPT[exit-label]}
  [[ -n ${_ZUI_OPT[cancel-label]:-} ]] && cancel=${_ZUI_OPT[cancel-label]}
  _zui_dlg_buttons=()
  (( ${_ZUI_OPT[no-ok]:-0} ))      || _zui_dlg_buttons+=("$ok=accept")
  (( ${_ZUI_OPT[no-cancel]:-0} ))  || _zui_dlg_buttons+=("$cancel=cancel")
  (( ${_ZUI_OPT[help-button]:-0} )) && _zui_dlg_buttons+=("${_ZUI_OPT[help-label]:-Help}=exit:0")
  (( ${_ZUI_OPT[extra-button]:-0} )) && _zui_dlg_buttons+=("${_ZUI_OPT[extra-label]:-Extra}=exit:0")
  local raw=${_ZUI_OPT[button]:-}
  if [[ -n $raw ]]; then
    _zui_dlg_buttons=("${(@f)raw}")
  fi
}

_zui_dialog_common() {
  local w h
  _zui_opt_int width; w=$REPLY
  _zui_opt_int height; h=$REPLY
  _zui_dlg[width]=$w
  _zui_dlg[height]=$h
  _zui_dlg[title]=${_ZUI_OPT[title]:-${_ZUI_OPT[header]:-}}
  _zui_dlg[message]=${_ZUI_OPT[message]:-}
  if (( ${_ZUI_OPT[trim]:-0} )) && [[ -n ${_zui_dlg[message]} ]]; then
    local -a ml=("${(@f)_zui_dlg[message]}") ml2=() mline
    for mline in "${ml[@]}"; do
      mline=${mline#"${mline%%[![:space:]]*}"}
      mline=${mline%"${mline##*[![:space:]]}"}
      ml2+=("$mline")
    done
    _zui_dlg[message]="${(pj:\n:)ml2}"
  fi
  _zui_dlg[icon]=${_ZUI_OPT[icon]:-}
  _zui_dlg[prompt]=${_ZUI_OPT[prompt]:-}
  _zui_dlg[border]=${_ZUI_OPT[border]:-auto}
  (( ${_ZUI_OPT[ascii-lines]:-0} )) && _zui_dlg[border]=ascii
  _zui_dlg[backtitle]=${_ZUI_OPT[backtitle]:-}
  _zui_dlg[hline]=${_ZUI_OPT[hline]:-}
  _zui_dlg[no_shadow]=${_ZUI_OPT[no-shadow]:-0}
  _zui_dlg[no_hints]=${_ZUI_OPT[no-show-help]:-0}
  (( ${_ZUI_OPT[show-help]:-1} )) || _zui_dlg[no_hints]=1
  _zui_dlg[no_cancel]=${_ZUI_OPT[no-cancel]:-0}
  _zui_dlg[pad_t]=0; _zui_dlg[pad_r]=0; _zui_dlg[pad_b]=0; _zui_dlg[pad_l]=0
  if [[ -n ${_ZUI_OPT[padding]:-} ]] && _zui_style_pad "${_ZUI_OPT[padding]}"; then
    _zui_dlg[pad_t]=$_ZUI_BOX[1]; _zui_dlg[pad_r]=$_ZUI_BOX[2]
    _zui_dlg[pad_b]=$_ZUI_BOX[3]; _zui_dlg[pad_l]=$_ZUI_BOX[4]
  fi
  local t=${_ZUI_OPT[timeout]:-}
  if [[ -n $t ]]; then
    if _zui_duration "$t"; then _zui_dlg[timeout]=$REPLY; else _zui_err "bad duration '$t'"; _zui_dlg[timeout]=0; fi
  fi
  local d=${_ZUI_OPT[default-button]:-${_ZUI_OPT[default]:-}}
  [[ $d == <-> ]] && _zui_dlg[default]=$d
  (( ${_ZUI_OPT[defaultno]:-0} )) && _zui_dlg[default]=2
}

_zui_message_from_args() {
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then
    msg="${(j: :)_ZUI_ARGS}"
  fi
  REPLY=$msg
}

# Turn a user-visible delimiter ("\n", "\t", ",") into its literal value.
_zui_delim() {
  local v=$1
  v=${v//\\n/$'\n'}; v=${v//\\t/$'\t'}; v=${v//\\r/$'\r'}
  REPLY=$v
}

_zui_items_from_args() {
  _zui_items=(); _zui_item_labels=()
  local -a raw=()
  if (( ${#_ZUI_ARGS} )); then
    raw=("${_ZUI_ARGS[@]}")
  elif (( ${_ZUI_OPT[no-items]:-0} )); then
    return 0
  else
    local idelim=${_ZUI_OPT[input-delimiter]:-}
    if [[ -n $idelim ]]; then
      _zui_delim "$idelim"; idelim=$REPLY
      local content
      content=$(cat)
      raw=("${(@ps:$idelim:)content}")
      (( ${#raw} )) && [[ -z ${raw[-1]} ]] && raw=("${(@)raw[1,-2]}")
    else
      _zui_slurp_stdin
      raw=("${_ZUI_STDIN[@]}")
    fi
  fi

  local ldelim=${_ZUI_OPT[label-delimiter]:-}
  [[ -n $ldelim ]] && _zui_delim "$ldelim" && ldelim=$REPLY
  local item label
  for item in "${raw[@]}"; do
    if (( ${_ZUI_OPT[strip-ansi]:-0} )); then
      _zui_strip_ansi "$item"; item=$REPLY
    fi
    if [[ -n $ldelim && $item == *$ldelim* ]]; then
      label=${item%%$ldelim*}; item=${item#*$ldelim}
    else
      label=$item
    fi
    _zui_items+=("$item")
    _zui_item_labels+=("$label")
  done
}

# Emit a dialog result, honouring output-delimiter, output-separator and fd flags.
_zui_emit_out() {
  (( _ZUI_EMIT )) || return 0
  local s=$1 sep fd=1
  if (( ${_ZUI_OPT[quoted]:-0} || ${_ZUI_OPT[single-quoted]:-0} )); then
    local -a ql=("${(@f)s}")
    local qi qch='"'
    (( ${_ZUI_OPT[single-quoted]:-0} )) && qch="'"
    for (( qi = 1; qi <= ${#ql}; qi++ )); do ql[qi]="${qch}${ql[qi]}${qch}"; done
    s="${(pj:\n:)ql}"
  fi
  sep=${_ZUI_OPT[output-separator]:-}
  [[ -z $sep ]] && sep=${_ZUI_OPT[output-delimiter]:-}
  if [[ -n $sep ]]; then
    _zui_delim "$sep"; s=${s//$'\n'/$REPLY}
  fi
  (( ${_ZUI_OPT[stderr]:-0} )) && fd=2
  local ofd=${_ZUI_OPT[output-fd]:-1}
  [[ $ofd == <-> ]] && (( ofd >= 0 )) && fd=$ofd
  print -ru $fd -- "$s"
}

_zui_need_items() {
  (( ${#_zui_items} )) || { _zui_err "no items provided (pass arguments or pipe lines on stdin)"; exit 2; }
}

_zui_seconds() { # option value -> REPLY seconds (or 0)
  local v=$1
  [[ -z $v ]] && { REPLY=0; return 0; }
  _zui_duration "$v" || { _zui_err "bad duration '$v'"; return 1; }
}

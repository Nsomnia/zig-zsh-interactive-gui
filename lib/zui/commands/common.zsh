# Shared helpers for command implementations.

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
  _zui_dlg_buttons=("$ok=accept" "$cancel=cancel")
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
  _zui_dlg[icon]=${_ZUI_OPT[icon]:-}
  _zui_dlg[prompt]=${_ZUI_OPT[prompt]:-}
  _zui_dlg[border]=${_ZUI_OPT[border]:-auto}
  local t=${_ZUI_OPT[timeout]:-}
  if [[ -n $t ]]; then
    if _zui_duration "$t"; then _zui_dlg[timeout]=$REPLY; else _zui_err "bad duration '$t'"; _zui_dlg[timeout]=0; fi
  fi
  local d=${_ZUI_OPT[default-button]:-${_ZUI_OPT[default]:-}}
  [[ $d == <-> ]] && _zui_dlg[default]=$d
}

_zui_message_from_args() {
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then
    msg="${(j: :)_ZUI_ARGS}"
  fi
  REPLY=$msg
}

_zui_items_from_args() {
  _zui_slurp_stdin
  if (( ${#_ZUI_ARGS} )); then
    _zui_items=("${_ZUI_ARGS[@]}")
  elif (( ${#_ZUI_STDIN} )); then
    _zui_items=("${_ZUI_STDIN[@]}")
  else
    _zui_items=()
  fi
}

_zui_need_items() {
  (( ${#_zui_items} )) || { _zui_err "no items provided (pass arguments or pipe lines on stdin)"; exit 2; }
}

_zui_seconds() { # option value -> REPLY seconds (or 0)
  local v=$1
  [[ -z $v ]] && { REPLY=0; return 0; }
  _zui_duration "$v" || { _zui_err "bad duration '$v'"; return 1; }
}

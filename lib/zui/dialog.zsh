# zui dialog: framed, dialog(1)-style window with any number of action buttons.

zmodload zsh/datetime 2>/dev/null

typeset -gA _zui_dlg=()
typeset -ga _zui_dlg_buttons=()
typeset -gi _zui_dlg_area=0 _zui_dlg_focus=1 _zui_dlg_scroll=0 _zui_dlg_done=0
typeset -gi _zui_dlg_msg_len=0 _zui_dlg_maxscroll=0
typeset -gi _ZUI_CODE=0 _ZUI_EMIT=0 _ZUI_DONE=0
typeset -g  _ZUI_OUT="" _ZUI_RUN="" _ZUI_ACTION=""
typeset -gF _ZUI_START=0

_zui_dialog_reset() {
  _zui_dlg=()
  _zui_dlg[widget]=text
  _zui_dlg[title]=""
  _zui_dlg[message]=""
  _zui_dlg[icon]=""
  _zui_dlg[width]=0
  _zui_dlg[height]=0
  _zui_dlg[timeout]=0
  _zui_dlg[default]=1
  _zui_dlg[border]=""
  _zui_dlg[prompt]=""
  _zui_dlg[list_h]=8
  _zui_dlg[ta_h]=8
  _zui_dlg[no_cancel]=0
  _zui_dlg[no_shadow]=0
  _zui_dlg[no_hints]=0
  _zui_dlg[nowrap]=0
  _zui_dlg[backtitle]=""
  _zui_dlg[hline]=""
  _zui_dlg[esc_code]=1
  _zui_dlg[key_hook]=""
  _zui_dlg[hints]=""
  _zui_dlg_buttons=()
  _zui_dlg_area=0
  _zui_dlg_focus=1
  _zui_dlg_scroll=0
  _zui_dlg_done=0
  _ZUI_OUT="" _ZUI_RUN="" _ZUI_ACTION=""
  _ZUI_CODE=0 _ZUI_EMIT=0 _ZUI_DONE=0
  _ZUI_TIMEOUT_HIT=0
}

zui::buttons() {
  _zui_dlg_buttons=("$@")
}

zui::dialog() { # associative spec is read from _zui_dlg
  _zui_dialog_run
}

_zui_dialog_autoheight() { # width -> REPLY total height
  emulate -L zsh
  local w=$1
  local cw=$(( w - 4 ))
  local msg_h=0 content=0
  (( cw < 1 )) && cw=1
  if [[ -n ${_zui_dlg[message]} ]]; then
    _zui_wrap "${_zui_dlg[message]}" "$cw"
    msg_h=${#_ZUI_LINES}
  fi
  case ${_zui_dlg[widget]} in
    (text)     content=$msg_h ;;
    (input)    content=$(( 1 + (msg_h ? msg_h + 1 : 0) )) ;;
    (textarea) content=$(( ${_zui_dlg[ta_h]:-8} + (msg_h ? msg_h + 1 : 0) )) ;;
    (list|checklist)
               content=$(( ${_zui_dlg[list_h]:-8} + (msg_h ? msg_h + 1 : 0) )) ;;
    (form)     content=$(( ${#_zui_form_labels} * 3 )) ;;
    (gauge)    content=$(( 2 + (msg_h ? msg_h + 1 : 0) )) ;;
  esac
  (( content < 1 )) && content=1
  local btn_h=0
  if (( ${#_zui_dlg_buttons} )); then
    _zui_btn_layout $(( w - 4 ))
    btn_h=$_zui_btn_height
  fi
  if (( btn_h )); then
    REPLY=$(( content + btn_h + 4 ))
  else
    REPLY=$(( content + 3 ))
  fi
}

_zui_dialog_hints() {
  emulate -L zsh
  local w=${_zui_dlg[widget]} h=""
  case $w in
    (textarea) h="Ctrl-D done" ;;
    (list|checklist)
      h="↑↓ move"
      (( _zui_list_multi )) && h+="  Space select"
      h+="  Enter confirm"
      (( ${#_zui_dlg_buttons} )) && h+="  Tab buttons" ;;
    (input) h="Enter confirm"
      (( ${#_zui_dlg_buttons} )) && h+="  Tab buttons" ;;
    (form) h="Tab next  Enter confirm"
      (( ${#_zui_dlg_buttons} )) && h+="  Tab buttons" ;;
    (text)
      h="↑↓ scroll"
      (( ${#_zui_dlg_buttons} )) && h="←→ buttons  ↑↓ scroll" ;;
    (*) (( ${#_zui_dlg_buttons} )) && h="←→ move  Enter select" ;;
  esac
  if (( ! ${_zui_dlg[no_cancel]} )); then
    [[ -n $h ]] && h+="  Esc cancel" || h="Esc cancel"
  fi
  if (( ${_zui_dlg[timeout]:-0} > 0 )); then
    local left=$(( ${_zui_dlg[timeout]:-0} - (EPOCHREALTIME - _ZUI_START) ))
    (( left < 0 )) && left=0
    h+="  ${left%.*}s"
  fi
  REPLY=$h
}

_zui_dialog_draw() {
  emulate -L zsh
  local rows=$ZUI_ROWS cols=$ZUI_COLS
  local w=${_zui_dlg[width]} h=${_zui_dlg[height]}
  local pad_t=${_zui_dlg[pad_t]:-0} pad_r=${_zui_dlg[pad_r]:-0}
  local pad_b=${_zui_dlg[pad_b]:-0} pad_l=${_zui_dlg[pad_l]:-0}
  if (( w <= 0 )); then
    case ${_zui_dlg[widget]} in
      (list|checklist|form) w=72 ;;
      (*) w=62 ;;
    esac
  fi
  (( w > cols - 2 )) && w=$(( cols - 2 ))
  (( w < 20 )) && w=20
  (( w > cols )) && w=$cols

  if (( h <= 0 )); then
    _zui_dialog_autoheight $w; h=$REPLY
  fi
  h=$(( h + pad_t + pad_b ))
  (( h > rows - 2 )) && h=$(( rows - 2 ))
  (( h < 6 )) && h=6

  local y=$(( (rows - h - 1) / 2 ))
  (( y < 0 )) && y=0
  local x=$(( (cols - w) / 2 ))
  (( x < 0 )) && x=0

  _zui_clear
  if [[ $_ZUI_BORDER != none ]] && (( ! ${_zui_dlg[no_shadow]:-0} )); then
    _zui_fill $(( y + 1 )) $(( x + 2 )) $h $w ' ' "${_ZUI_STYLE[shadow]}"
  fi
  local title=${_zui_dlg[title]}
  _zui_frame $y $x $h $w "$title" "${_ZUI_STYLE[title]}" "${_ZUI_STYLE[frame]}"

  local cw=$(( w - 4 - pad_l - pad_r ))
  (( cw < 1 )) && cw=1
  local btn_h=0
  if (( ${#_zui_dlg_buttons} )); then
    _zui_btn_layout $cw
    btn_h=$_zui_btn_height
  fi
  local btn_y=$(( y + h - 1 - btn_h - pad_b ))
  local content_y=$(( y + 2 + pad_t ))
  local content_h=$(( btn_y - content_y - (btn_h ? 1 : 0) ))
  (( content_h < 1 )) && content_h=1

  local mx=$(( x + 2 + pad_l )) mw=$cw
  local icon=${_zui_dlg[icon]}
  if [[ -n $icon && -n ${_zui_dlg[message]} ]]; then
    _zui_icon "$icon"
    _zui_put $content_y $mx "$REPLY" "$_zui_icon_style"
    mx=$(( mx + 2 )); mw=$(( mw - 2 ))
  fi

  local msg_h=0
  if [[ -n ${_zui_dlg[message]} ]]; then
    if (( ${_zui_dlg[nowrap]:-0} )); then
      typeset -ga _ZUI_LINES
      _ZUI_LINES=("${(@f)_zui_dlg[message]}")
    else
      _zui_wrap "${_zui_dlg[message]}" "$mw"
    fi
    _zui_dlg_msg_len=${#_ZUI_LINES}
    _zui_dlg_maxscroll=$(( _zui_dlg_msg_len - content_h ))
    (( _zui_dlg_maxscroll < 0 )) && _zui_dlg_maxscroll=0
    (( _zui_dlg_scroll > _zui_dlg_maxscroll )) && _zui_dlg_scroll=$_zui_dlg_maxscroll
    msg_h=${#_ZUI_LINES}
    (( msg_h > content_h )) && msg_h=$content_h
  fi

  # Message (shared by every widget).
  if (( msg_h )); then
    local i
    for (( i = 1; i <= msg_h; i++ )); do
      local off=$i
      if [[ ${_zui_dlg[widget]} == text ]]; then
        off=$(( i + _zui_dlg_scroll ))
        (( off > ${#_ZUI_LINES} )) && break
      fi
      _zui_put $(( content_y + i - 1 )) $mx "${_ZUI_LINES[off]}" "${_ZUI_STYLE[text]}"
    done
    if [[ ${_zui_dlg[widget]} == text && ${#_ZUI_LINES} -gt content_h ]]; then
      if (( _zui_dlg_scroll > 0 )); then
        _zui_put $content_y $(( x + w - 2 )) '↑' "${_ZUI_STYLE[scroll]}"
      fi
      if (( _zui_dlg_scroll + content_h < ${#_ZUI_LINES} )); then
        _zui_put $(( content_y + content_h - 1 )) $(( x + w - 2 )) '↓' "${_ZUI_STYLE[scroll]}"
      fi
    fi
  fi

  local wy=$content_y
  (( msg_h )) && wy=$(( content_y + msg_h + 1 ))

  case ${_zui_dlg[widget]} in
    (text) ;;
    (input)
      local prompt=${_zui_dlg[prompt]} ix=$(( x + 2 + pad_l )) iw=$cw
      if [[ -n $prompt ]]; then
        local ptxt="$prompt "
        _zui_put $wy $ix "$ptxt" "${_ZUI_STYLE[accent]}"
        ix=$(( ix + ${#ptxt} )); iw=$(( iw - ${#ptxt} ))
        (( iw < 5 )) && { ix=$(( x + 2 + pad_l )); iw=$cw; }
      fi
      _zui_ed_draw $wy $ix $iw $(( _zui_dlg_area == 0 )) ;;
    (textarea)
      local th=$(( content_h - msg_h - (msg_h ? 1 : 0) ))
      (( th < 1 )) && th=1
      _zui_ta_draw $wy $(( x + 2 + pad_l )) $cw $th $(( _zui_dlg_area == 0 )) ;;
    (list|checklist)
      local lh=$(( content_h - msg_h - (msg_h ? 1 : 0) ))
      (( lh < 1 )) && lh=1
      _zui_list_draw $wy $(( x + 2 + pad_l )) $cw $lh ;;
    (form)
      _zui_form_draw $wy $(( x + 2 + pad_l )) $cw \
        $(( content_h - msg_h - (msg_h ? 1 : 0) )) $(( _zui_dlg_area == 0 )) ;;
    (gauge)
      _zui_gauge_draw $wy $(( x + 2 + pad_l )) $cw "${_zui_dlg[percent]:-0}" "${_zui_dlg[label]:-}" ;;
  esac

  if (( btn_h )); then
    _zui_btn_draw $btn_y $(( x + 2 + pad_l )) $cw $(( _zui_dlg_area ? _zui_dlg_focus : 0 ))
  fi

  local hints=${_zui_dlg[hline]:-${_zui_dlg[hints]}}
  if [[ -z $hints ]] && (( ! ${_zui_dlg[no_hints]:-0} )); then
    _zui_dialog_hints; hints=$REPLY
  fi
  if [[ -n ${_zui_dlg[backtitle]} ]]; then
    hints="${hints:+$hints  ·  }${_zui_dlg[backtitle]}"
  fi
  if [[ -n $hints ]] && (( y + h < rows )); then
    _zui_truncate "$hints" $(( cols - 2 ))
    _zui_center $(( y + h )) 0 $cols "$REPLY" "${_ZUI_STYLE[footer]}"
  fi
  _zui_present
}

_zui_dialog_default() {
  local d=${_zui_dlg[default]:-1}
  (( d < 1 || d > ${#_zui_dlg_buttons} )) && d=1
  print -r -- $d
}

_zui_dialog_accept_value() {
  case ${_zui_dlg[widget]} in
    (input)    _ZUI_OUT=$_zui_ed_value ;;
    (textarea) _zui_ta_text; _ZUI_OUT=$REPLY ;;
    (list|checklist) _zui_list_value; _ZUI_OUT=$REPLY ;;
    (form)     _zui_form_value; _ZUI_OUT=$REPLY ;;
    (*)        _ZUI_OUT="" ;;
  esac
}

_zui_dialog_activate() { # button index
  local i=$1 action=${_zui_btn_actions[$1]}
  _ZUI_ACTION=$action
  case $action in
    (stay) return 1 ;;
    (accept)
      _zui_dialog_accept_value
      if [[ ${_zui_dlg[widget]} == (text|gauge) ]]; then _ZUI_EMIT=0; else _ZUI_EMIT=1; fi
      _ZUI_CODE=0; _zui_dlg_done=1 ;;
    (cancel)
      _ZUI_CODE=1; _ZUI_EMIT=0; _zui_dlg_done=1 ;;
    (exit:*)
      _ZUI_CODE=${action#exit:}
      [[ $_ZUI_CODE == <-> ]] || _ZUI_CODE=0
      _ZUI_EMIT=0; _zui_dlg_done=1 ;;
    (print:*)
      _ZUI_OUT=${action#print:}; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1 ;;
    (run:*)
      _ZUI_RUN=${action#run:}; _ZUI_EMIT=0; _ZUI_CODE=0; _zui_dlg_done=1 ;;
    (*)
      _ZUI_CODE=0; _ZUI_EMIT=0; _zui_dlg_done=1 ;;
  esac
  return 0
}

_zui_dialog_cycle_button() { # delta
  local n=${#_zui_dlg_buttons}
  (( n )) || return 1
  _zui_dlg_area=1
  _zui_dlg_focus=$(( _zui_dlg_focus + $1 ))
  (( _zui_dlg_focus < 1 )) && _zui_dlg_focus=$n
  (( _zui_dlg_focus > n )) && _zui_dlg_focus=1
}

_zui_dialog_key() { # returns 0 continue, 1 handled
  emulate -L zsh
  local w=${_zui_dlg[widget]} n=${#_zui_dlg_buttons}

  if (( _zui_dlg_area )); then
    case $KEY in
      (TAB|BACKTAB)
        if [[ $w != (text|gauge) ]]; then _zui_dlg_area=0; fi ;;
      (UP)
        if [[ $w == text ]]; then (( _zui_dlg_scroll > 0 )) && (( _zui_dlg_scroll-- )); else _zui_dialog_cycle_button -1; fi ;;
      (DOWN)
        if [[ $w == text ]]; then (( _zui_dlg_scroll < _zui_dlg_maxscroll )) && (( _zui_dlg_scroll++ )); else _zui_dialog_cycle_button 1; fi ;;
      (PGUP) (( _zui_dlg_scroll -= 5 )); (( _zui_dlg_scroll < 0 )) && _zui_dlg_scroll=0 ;;
      (PGDN) (( _zui_dlg_scroll += 5 )); (( _zui_dlg_scroll > _zui_dlg_maxscroll )) && _zui_dlg_scroll=$_zui_dlg_maxscroll ;;
      (LEFT)  _zui_dialog_cycle_button -1 ;;
      (RIGHT) _zui_dialog_cycle_button 1 ;;
      (HOME)      _zui_dlg_focus=1 ;;
      (END)       (( n )) && _zui_dlg_focus=$n ;;
      (ENTER|SPACE|' ') (( n )) && _zui_dialog_activate $_zui_dlg_focus ;;
      (ESC)
        if (( ! ${_zui_dlg[no_cancel]} )); then
          _ZUI_CODE=${_zui_dlg[esc_code]:-1}; _zui_dlg_done=1
        fi ;;
      (ALT-*)
        local c=${(L)${KEY#ALT-}} i
        for (( i = 1; i <= n; i++ )); do
          [[ ${_zui_btn_accel[i]} == "$c" ]] && { _zui_dlg_focus=$i; _zui_dialog_activate $i; break; }
        done ;;
    esac
    return 0
  fi

  if [[ -n ${_zui_dlg[key_hook]} ]]; then
    "${_zui_dlg[key_hook]}" && return 0
  fi

  # Form handles Tab itself so fields are visited before the buttons.
  if [[ $w == form && ( $KEY == TAB || $KEY == BACKTAB ) ]]; then
    _zui_form_handle
    local frc=$?
    if (( frc == 2 )); then
      (( n )) && _zui_dialog_activate $(_zui_dialog_default) || { _zui_form_value; _ZUI_OUT=$REPLY; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1; }
    elif (( frc == 3 )); then
      (( n )) && _zui_dlg_area=1
    fi
    return 0
  fi

  # Widget has focus.
  case $KEY in
    (TAB)
      if [[ $w == (text|gauge) ]]; then
        (( n )) && _zui_dlg_area=1
      elif [[ $w == textarea ]]; then
        _zui_ta_handle
      else
        (( n )) && _zui_dlg_area=1
      fi
      return 0 ;;
    (BACKTAB)
      (( n )) && _zui_dlg_area=1
      return 0 ;;
    (CTRL_B)
      (( n )) && _zui_dlg_area=1
      return 0 ;;
    (ESC)
      if [[ $w == (list|checklist) && -n $_zui_list_filter ]]; then
        _zui_list_filter=""; _zui_list_active_filter=0; _zui_list_build
        return 0
      fi
      if (( ! ${_zui_dlg[no_cancel]} )); then
        _ZUI_CODE=${_zui_dlg[esc_code]:-1}; _zui_dlg_done=1
      fi
      return 0 ;;
  esac

  case $w in
    (text)
      case $KEY in
        (UP)   (( _zui_dlg_scroll > 0 )) && (( _zui_dlg_scroll-- )) ;;
        (DOWN) (( _zui_dlg_scroll++ )) ;;
        (PGUP) (( _zui_dlg_scroll -= 5 )); (( _zui_dlg_scroll < 0 )) && _zui_dlg_scroll=0 ;;
        (PGDN) (( _zui_dlg_scroll += 5 )) ;;
        (HOME) _zui_dlg_scroll=0 ;;
        (END)  _zui_dlg_scroll=9999 ;;
        (ENTER|SPACE) _ZUI_CODE=0; _ZUI_EMIT=0; _zui_dlg_done=1 ;;
        (*)
          if (( ! n )); then _ZUI_CODE=0; _ZUI_EMIT=0; _zui_dlg_done=1
          else _zui_dlg_area=1; fi ;;
      esac ;;
    (input)
      case $KEY in
        (ENTER) (( n )) && _zui_dialog_activate $(_zui_dialog_default) || { _ZUI_CODE=0; _ZUI_EMIT=1; _zui_dialog_accept_value; _zui_dlg_done=1 } ;;
        (*) _zui_ed_handle ;;
      esac ;;
    (textarea)
      case $KEY in
        (CTRL_D|CTRL_S) (( n )) && _zui_dialog_activate $(_zui_dialog_default) || { _zui_dialog_accept_value; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1 } ;;
        (*) _zui_ta_handle ;;
      esac ;;
    (list|checklist)
      case $KEY in
        (ENTER)
          if (( ${#_zui_list_view} == 0 )); then
            if (( ! _zui_list_strict )) && [[ -n $_zui_list_filter ]]; then
              _ZUI_OUT=$_zui_list_filter; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1
            fi
            return 0
          fi
          if (( n )); then _zui_dialog_activate $(_zui_dialog_default)
          else _zui_list_value; _ZUI_OUT=$REPLY; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1; fi ;;
        (*)
          _zui_list_handle
          case $? in
            (3) (( n )) && _zui_dlg_area=1 ;;
          esac ;;
      esac ;;
    (form)
      _zui_form_handle
      local rc=$?
      if (( rc == 2 )); then
        (( n )) && _zui_dialog_activate $(_zui_dialog_default) || { _zui_form_value; _ZUI_OUT=$REPLY; _ZUI_EMIT=1; _ZUI_CODE=0; _zui_dlg_done=1; }
      elif (( rc == 3 )); then
        (( n )) && _zui_dlg_area=1
      fi ;;
    (gauge)
      _ZUI_CODE=0; _zui_dlg_done=1 ;;
  esac
  return 0
}

_zui_dialog_run() {
  emulate -L zsh
  _zui_dlg_done=0
  _ZUI_DONE=0
  _ZUI_START=$EPOCHREALTIME
  _zui_btn_parse "${_zui_dlg_buttons[@]}"
  [[ -z ${_zui_dlg[border]} ]] && _zui_dlg[border]=auto
  _zui_border_set "${_zui_dlg[border]}"

  _zui_ui_begin
  _zui_apply_style_opts
  # Initial focus: buttons for message-only/gauge, widget otherwise.
  case ${_zui_dlg[widget]} in
    (text|gauge) _zui_dlg_area=1 ;;
    (*)          _zui_dlg_area=0 ;;
  esac
  (( ${#_zui_dlg_buttons} == 0 )) && _zui_dlg_area=0
  case ${_zui_dlg[widget]} in
    (form) _zui_form_load ;;
  esac

  local rc
  while (( ! _zui_dlg_done )); do
    (( _ZUI_ABORT )) && { _ZUI_CODE=130; break; }
    _zui_check_resize
    _zui_dialog_draw
    _zui_readkey 200
    rc=$?
    if (( rc == 2 )); then _ZUI_CODE=130; break; fi
    if (( rc == 1 )); then
      # Timeout tick: dialog deadline, else nothing.
      if (( ${_zui_dlg[timeout]:-0} > 0 )) && (( EPOCHREALTIME - _ZUI_START >= ${_zui_dlg[timeout]:-0} )); then
        _ZUI_TIMEOUT_HIT=1
        _ZUI_CODE=124
        break
      fi
      continue
    fi
    _zui_dialog_key
  done

  if [[ -n ${_ZUI_OPT[sleep]:-} ]]; then
    local sl
    if _zui_duration "${_ZUI_OPT[sleep]}"; then sl=$REPLY; (( sl > 0 )) && sleep $sl; fi
  fi
  _zui_ui_end
  (( ${_ZUI_OPT[beep]:-0} || ${_ZUI_OPT[beep-after]:-0} )) && print -n $'\a' >/dev/tty 2>/dev/null
  if [[ -n $_ZUI_RUN ]]; then
    eval "$_ZUI_RUN"
    _ZUI_CODE=$?
    _ZUI_EMIT=0
  fi
  _ZUI_DONE=1
  return $_ZUI_CODE
}

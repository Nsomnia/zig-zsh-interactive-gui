# zui widgets: buttons, list/checklist, form, gauge.

# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------
typeset -ga _zui_btn_labels=() _zui_btn_actions=() _zui_btn_accel=()
typeset -gi _zui_btn_focus=1 _zui_btn_height=1

_zui_btn_parse() {
  emulate -L zsh
  _zui_btn_labels=(); _zui_btn_actions=(); _zui_btn_accel=()
  local spec label action acc i=0
  for spec in "$@"; do
    if [[ $spec == *=* ]]; then
      label=${spec%%=*}; action=${spec#*=}
    else
      label=$spec; action="exit:$i"
    fi
    acc=""
    if [[ $label == *'&'* ]]; then
      # &X underlines/activates X with Alt-X; strip the marker for display.
      acc=${${label#*&}[1,1]}
      label=${label//&/}
    fi
    _zui_btn_labels+=("$label")
    _zui_btn_actions+=("$action")
    _zui_btn_accel+=("${(L)acc}")
    (( i++ ))
  done
  _zui_btn_focus=1
}

_zui_btn_count() { REPLY=${#_zui_btn_labels} }

# Compute rows; sets _zui_btn_height and _zui_btn_row (1-based row per button)
_zui_btn_layout() { # width
  emulate -L zsh
  local w=$1 i bw cur=0 row=1
  typeset -ga _zui_btn_row
  _zui_btn_row=()
  for (( i = 1; i <= ${#_zui_btn_labels}; i++ )); do
    bw=$(( ${#_zui_btn_labels[i]} + 4 ))
    if (( cur > 0 && cur + 2 + bw > w )); then
      (( row++ )); cur=0
    fi
    _zui_btn_row[i]=$row
    (( cur += bw + (cur > 0 ? 2 : 0) ))
  done
  _zui_btn_height=$row
}

_zui_btn_draw() { # y x w focused
  emulate -L zsh
  local y=$1 x=$2 w=$3 focus=${4:-1}
  _zui_btn_layout $w
  local i row=0 r start cx bw label style
  # First pass: widths per row for centering.
  typeset -A rowwidth
  for (( i = 1; i <= ${#_zui_btn_labels}; i++ )); do
    r=${_zui_btn_row[i]}
    bw=$(( ${#_zui_btn_labels[i]} + 4 ))
    rowwidth[$r]=$(( ${rowwidth[$r]:-0} + bw + (${rowwidth[$r]:-0} > 0 ? 2 : 0) ))
  done
  typeset -A rowx rowcur
  for r in ${(k)rowwidth}; do
    rowx[$r]=$(( x + (w - rowwidth[$r]) / 2 ))
    (( ${rowx[$r]} < x )) && rowx[$r]=$x
    rowcur[$r]=${rowx[$r]}
  done
  for (( i = 1; i <= ${#_zui_btn_labels}; i++ )); do
    r=${_zui_btn_row[i]}
    label="[ ${_zui_btn_labels[i]} ]"
    bw=${#label}
    cx=${rowcur[$r]}
    if (( cx + bw > x + w )); then
      _zui_truncate "$label" $(( x + w - cx ))
      label=$REPLY
    fi
    if (( i == focus )); then style=${_ZUI_STYLE[button_focus]}; else style=${_ZUI_STYLE[button]}; fi
    _zui_put $(( y + r - 1 )) $cx "$label" "$style"
    rowcur[$r]=$(( cx + bw + 2 ))
  done
  REPLY=$_zui_btn_height
}

# ---------------------------------------------------------------------------
# List / checklist
# ---------------------------------------------------------------------------
typeset -ga _zui_list_items=() _zui_list_view=() _zui_list_view_raw=() _zui_list_order=()
typeset -gA _zui_list_marks=()
typeset -g  _zui_list_filter="" _zui_list_cursor_char="> " _zui_list_sel_char="✓"
typeset -g  _zui_list_unsel=" "
typeset -gi _zui_list_cursor=1 _zui_list_offset=0 _zui_list_multi=0
typeset -gi _zui_list_limit=0 _zui_list_ordered=0 _zui_list_fuzzy=1
typeset -gi _zui_list_show_filter=0 _zui_list_filter_pos=1
typeset -gi _zui_list_active_filter=0

_zui_list_reset_chars() {
  if _zui_utf8; then
    _zui_list_sel_char='✓'; _zui_list_up='↑'; _zui_list_down='↓'
  else
    _zui_list_sel_char='x'; _zui_list_up='^'; _zui_list_down='v'
  fi
}

_zui_list_reset() {
  _zui_list_filter=""; _zui_list_filter_pos=1; _zui_list_cursor=1
  _zui_list_offset=0; _zui_list_marks=(); _zui_list_order=()
  _zui_list_build
}

_zui_fuzzy() { # needle haystack -> REPLY score, 0 = no match
  emulate -L zsh
  local n=${(L)1} h=${(L)2}
  (( ${#n} == 0 )) && { REPLY=0; return 0; }
  local i=1 j=1 score=0 ni hi last=0
  while (( i <= ${#n} && j <= ${#h} )); do
    ni=${n[i]}; hi=${h[j]}
    if [[ $ni == "$hi" ]]; then
      (( score += 2 ))
      (( last == j - 1 )) && (( score += 3 ))
      (( j == 1 )) && (( score += 5 ))
      (( last=j, i++ ))
    else
      (( score-- ))
    fi
    (( j++ ))
  done
  if (( i > ${#n} )); then
    (( score > 0 )) || score=1
    REPLY=$score
  else
    REPLY=0
  fi
}

_zui_list_build() {
  emulate -L zsh
  _zui_list_reset_chars
  typeset -ga _zui_list_view _zui_list_view_raw _zui_list_scores
  _zui_list_view=(); _zui_list_view_raw=(); _zui_list_scores=()
  local i item score q=$_zui_list_filter
  for (( i = 1; i <= ${#_zui_list_items}; i++ )); do
    item=${_zui_list_items[i]}
    if [[ -z $q ]]; then
      score=0
    elif (( _zui_list_fuzzy )); then
      _zui_fuzzy "$q" "$item"; score=$REPLY
      (( score == 0 )) && continue
    else
      [[ ${(L)item} == *${(L)q}* ]] || continue
      score=0
    fi
    _zui_list_view+=("$item")
    _zui_list_view_raw+=($i)
    _zui_list_scores+=($score)
  done
  # Stable insertion sort by score, descending (fuzzy only).
  if (( _zui_list_fuzzy )) && [[ -n $q ]]; then
    local a b key keyraw keyscore
    for (( a = 2; a <= ${#_zui_list_view}; a++ )); do
      key=${_zui_list_view[a]}; keyraw=${_zui_list_view_raw[a]}; keyscore=${_zui_list_scores[a]}
      (( b = a - 1 ))
      while (( b >= 1 )) && (( ${_zui_list_scores[b]} < keyscore )); do
        _zui_list_view[b+1]=${_zui_list_view[b]}
        _zui_list_view_raw[b+1]=${_zui_list_view_raw[b]}
        _zui_list_scores[b+1]=${_zui_list_scores[b]}
        (( b-- ))
      done
      _zui_list_view[b+1]=$key; _zui_list_view_raw[b+1]=$keyraw; _zui_list_scores[b+1]=$keyscore
    done
  fi
  _zui_list_cursor=1
  _zui_list_offset=0
}

_zui_list_toggle() {
  (( _zui_list_multi )) || return 1
  local raw=${_zui_list_view_raw[_zui_list_cursor]}
  [[ -z $raw ]] && return 1
  if (( ${+_zui_list_marks[$raw]} )); then
    unset "_zui_list_marks[$raw]"
    _zui_list_order=("${(@)_zui_list_order:#$raw}")
  else
    if (( _zui_list_limit > 0 && ${#_zui_list_marks} >= _zui_list_limit )); then
      return 1
    fi
    _zui_list_marks[$raw]=1
    _zui_list_order+=($raw)
  fi
  return 0
}

_zui_list_move() { # delta
  local d=$1 max=${#_zui_list_view}
  (( max == 0 )) && return 1
  _zui_list_cursor=$(( _zui_list_cursor + d ))
  (( _zui_list_cursor < 1 )) && _zui_list_cursor=1
  (( _zui_list_cursor > max )) && _zui_list_cursor=$max
}

# Returns 0 handled, 1 no-op, 2 submit, 3 tab (leave widget)
_zui_list_handle() {
  emulate -L zsh
  local max=${#_zui_list_view}
  case $KEY in
    (UP|CTRL_P)   _zui_list_move -1 ;;
    (DOWN|CTRL_N) _zui_list_move 1 ;;
    (PGUP)        _zui_list_move -10 ;;
    (PGDN)        _zui_list_move 10 ;;
    (HOME)        _zui_list_cursor=1; (( max )) || _zui_list_cursor=0 ;;
    (END)         _zui_list_cursor=$max ;;
    (SPACE|' ')
      if (( _zui_list_multi )); then _zui_list_toggle; return 0; fi
      return 1 ;;
    (ENTER) return 2 ;;
    (TAB)   return 3 ;;
    (BACKSPACE)
      if [[ -n $_zui_list_filter ]]; then
        _zui_list_filter=${_zui_list_filter[1,-2]}
        _zui_list_active_filter=0; _zui_list_build
        return 0
      fi
      return 1 ;;
    (CTRL_U)
      _zui_list_filter=""; _zui_list_active_filter=0; _zui_list_build; return 0 ;;
    (/)
      _zui_list_active_filter=1; _zui_list_show_filter=1; return 0 ;;
    (ESC)
      if [[ -n $_zui_list_filter ]]; then
        _zui_list_filter=""; _zui_list_active_filter=0; _zui_list_build; return 0
      fi
      return 1 ;;
    (*)
      _zui_key_is_printable || return 1
      _zui_list_filter+=$KEY
      _zui_list_active_filter=1
      _zui_list_build
      return 0 ;;
  esac
  return 0
}

_zui_list_draw() { # y x w h
  emulate -L zsh
  local y=$1 x=$2 w=$3 h=$4
  local filter_h=0
  if (( _zui_list_show_filter || _zui_list_active_filter || ${#_zui_list_filter} )); then filter_h=2; fi
  local ih=$(( h - filter_h ))
  (( ih < 1 )) && { ih=1; filter_h=0 }

  if (( filter_h )); then
    _zui_put $y $x "/ " "${_ZUI_STYLE[accent]}"
    local q=$_zui_list_filter
    _zui_truncate "$q" $(( w - 2 ))
    _zui_put $y $(( x + 2 )) "$REPLY" "${_ZUI_STYLE[input]}"
    if (( _zui_list_show_filter || _zui_list_active_filter )); then
      local cx=$(( ${#q} + 2 ))
      (( cx > w - 1 )) && cx=$(( w - 1 ))
      _zui_put $y $(( x + cx )) ' ' "${_ZUI_STYLE[caret]}"
    fi
    _zui_put $(( y + 1 )) $x "" "${_ZUI_STYLE[text]}"
  fi

  local i row=0 max=${#_zui_list_view} raw mark style prefix text tw
  (( _zui_list_cursor < 1 && max > 0 )) && _zui_list_cursor=1
  if (( _zui_list_cursor > 0 )); then
    if (( _zui_list_cursor <= _zui_list_offset )); then
      _zui_list_offset=$(( _zui_list_cursor - 1 ))
    elif (( _zui_list_cursor > _zui_list_offset + ih )); then
      _zui_list_offset=$(( _zui_list_cursor - ih ))
    fi
  fi
  (( _zui_list_offset < 0 )) && _zui_list_offset=0

  tw=$(( w - 4 ))
  if (( _zui_list_multi )); then tw=$(( w - 6 )); fi
  (( tw < 1 )) && tw=1

  for (( i = _zui_list_offset + 1; i <= max && row < ih; i++, row++ )); do
    raw=${_zui_list_view_raw[i]}
    mark=0
    (( ${+_zui_list_marks[$raw]} )) && mark=1
    _zui_truncate "${_zui_list_view[i]}" "$tw"
    text=$REPLY
    if (( i == _zui_list_cursor )); then
      style=${_ZUI_STYLE[selection_focus]}
      if (( _zui_list_multi )); then
        (( mark )) && prefix="[${_zui_list_sel_char}] " || prefix="[ ] "
      else
        prefix=$_zui_list_cursor_char
      fi
      _zui_fill $(( y + filter_h + row )) $x 1 $w ' ' "$style"
      _zui_put $(( y + filter_h + row )) $x "$prefix$text" "$style"
    else
      style=${_ZUI_STYLE[text]}
      if (( _zui_list_multi )); then
        if (( mark )); then
          _zui_put $(( y + filter_h + row )) $x "[${_zui_list_sel_char}]" "${_ZUI_STYLE[mark]}"
          _zui_put $(( y + filter_h + row )) $(( x + 4 )) "$text" "${_ZUI_STYLE[selection]}"
        else
          _zui_put $(( y + filter_h + row )) $x "[ ] $text" "$style"
        fi
      else
        _zui_put $(( y + filter_h + row )) $x "  $text" "$style"
      fi
    fi
  done
  for (( ; row < ih; row++ )); do
    _zui_fill $(( y + filter_h + row )) $x 1 $w ' ' "${_ZUI_STYLE[text]}"
  done

  # Scroll indicators
  if (( _zui_list_offset > 0 )); then
    _zui_put $(( y + filter_h )) $(( x + w - 1 )) "$_zui_list_up" "${_ZUI_STYLE[scroll]}"
  fi
  if (( _zui_list_offset + ih < max )); then
    _zui_put $(( y + filter_h + ih - 1 )) $(( x + w - 1 )) "$_zui_list_down" "${_ZUI_STYLE[scroll]}"
  fi
  _zui_list_show_filter=0
}

_zui_list_value() { # sets REPLY
  local max=${#_zui_list_view}
  (( max == 0 )) && { REPLY=""; return 0; }
  if (( _zui_list_multi )); then
    local -a picked
    if (( ${#_zui_list_marks} )); then
      local raw i
      if (( _zui_list_ordered )); then
        for raw in "${_zui_list_order[@]}"; do
          picked+=("${_zui_list_items[raw]}")
        done
      else
        for (( i = 1; i <= ${#_zui_list_items}; i++ )); do
          (( ${+_zui_list_marks[$i]} )) && picked+=("${_zui_list_items[i]}")
        done
      fi
    else
      picked=("${_zui_list_view[_zui_list_cursor]}")
    fi
    REPLY="${(pj:\n:)picked}"
  else
    REPLY=${_zui_list_view[_zui_list_cursor]}
  fi
}

_zui_list_mark_initial() { # values...
  local v i
  for v in "$@"; do
    for (( i = 1; i <= ${#_zui_list_items}; i++ )); do
      if [[ ${_zui_list_items[i]} == "$v" ]]; then
        _zui_list_marks[$i]=1
        _zui_list_order+=($i)
        break
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# Form
# ---------------------------------------------------------------------------
typeset -ga _zui_form_labels=() _zui_form_values=() _zui_form_mask=()
typeset -gi _zui_form_focus=1 _zui_form_scroll=0 _zui_form_visible=1

_zui_form_load() {
  _zui_ed_reset "${_zui_form_values[_zui_form_focus]}" 0
  _zui_ed_mask=${_zui_form_mask[_zui_form_focus]:-0}
}

_zui_form_save() {
  _zui_form_values[_zui_form_focus]=$_zui_ed_value
}

_zui_form_draw() { # y x w h focus
  emulate -L zsh
  local y=$1 x=$2 w=$3 h=$4 focus=${5:-1}
  local n=${#_zui_form_labels} i row=0 lh=3
  # Scroll to the focused field.
  if (( _zui_form_focus <= _zui_form_scroll + 1 )); then
    _zui_form_scroll=$(( _zui_form_focus - 1 ))
  elif (( (_zui_form_focus - _zui_form_scroll) * lh > h )); then
    _zui_form_scroll=$(( _zui_form_focus - h / lh ))
  fi
  (( _zui_form_scroll < 0 )) && _zui_form_scroll=0

  for (( i = _zui_form_scroll + 1; i <= n && row + 2 <= h; i++, row += lh )); do
    _zui_put $(( y + row )) $x "${_zui_form_labels[i]}" "${_ZUI_STYLE[muted]}"
    if (( i == _zui_form_focus && focus )); then
      _zui_ed_draw $(( y + row + 1 )) $x $w 1
    else
      local v=${_zui_form_values[i]}
      if (( ${_zui_form_mask[i]:-0} )); then
        _zui_utf8 && v=${(l:${#v}::•:)} || v=${(l:${#v}::*:)}
      fi
      _zui_fill $(( y + row + 1 )) $x 1 $w ' ' "${_ZUI_STYLE[input]}"
      _zui_put $(( y + row + 1 )) $x "$v" "${_ZUI_STYLE[input]}"
    fi
  done
}

# 0 handled, 1 no-op, 2 submit, 3 leave (tab from last field)
_zui_form_handle() {
  local n=${#_zui_form_labels}
  case $KEY in
    (TAB)
      _zui_form_save
      if (( _zui_form_focus < n )); then
        (( _zui_form_focus++ )); _zui_form_load
      else
        return 3
      fi ;;
    (BACKTAB)
      _zui_form_save
      if (( _zui_form_focus > 1 )); then
        (( _zui_form_focus-- )); _zui_form_load
      else
        return 3
      fi ;;
    (UP)
      _zui_form_save
      if (( _zui_form_focus > 1 )); then (( _zui_form_focus-- )); _zui_form_load; fi ;;
    (DOWN)
      _zui_form_save
      if (( _zui_form_focus < n )); then (( _zui_form_focus++ )); _zui_form_load; fi ;;
    (ENTER) return 2 ;;
    (*)
      _zui_ed_handle || return 1 ;;
  esac
  return 0
}

_zui_form_value() {
  _zui_form_save
  REPLY="${(pj:\n:)_zui_form_values}"
}

# ---------------------------------------------------------------------------
# Gauge
# ---------------------------------------------------------------------------
_zui_gauge_draw() { # y x w percent [label]
  local y=$1 x=$2 w=$3 pct=$4 label=${5-}
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  local barw=$(( w - 8 ))
  (( barw < 1 )) && barw=1
  local filled=$(( barw * pct / 100 ))
  local empty=$(( barw - filled )) line
  if _zui_utf8; then
    line="${(l:filled::█:)}${(l:empty::░:)}"
  else
    line="${(l:filled::#:)}${(l:empty::.:)}"
  fi
  _zui_put $y $x "[" "${_ZUI_STYLE[gauge]}"
  _zui_put $y $(( x + 1 )) "${line[1,filled]}" "${_ZUI_STYLE[gauge_ok]}"
  _zui_put $y $(( x + 1 + filled )) "${line[filled+1,-1]}" "${_ZUI_STYLE[gauge]}"
  _zui_put $y $(( x + 1 + barw )) "]" "${_ZUI_STYLE[gauge]}"
  printf -v REPLY '%3d%%' $pct
  _zui_put $y $(( x + barw + 3 )) "$REPLY" "${_ZUI_STYLE[text]}"
  [[ -n $label ]] && _zui_put $(( y + 1 )) $x "$label" "${_ZUI_STYLE[muted]}"
}

_zui_icon() { # name -> REPLY char, _zui_icon_style
  local name=$1
  if _zui_utf8; then
    case $name in
      (success) REPLY='✓'; _zui_icon_style=${_ZUI_STYLE[success]} ;;
      (error)   REPLY='✗'; _zui_icon_style=${_ZUI_STYLE[danger]} ;;
      (warn)    REPLY='!'; _zui_icon_style=${_ZUI_STYLE[warn]} ;;
      (question) REPLY='?'; _zui_icon_style=${_ZUI_STYLE[accent]} ;;
      (*)       REPLY='i'; _zui_icon_style=${_ZUI_STYLE[accent]} ;;
    esac
  else
    case $name in
      (success) REPLY='+';; (error) REPLY='x';; (warn) REPLY='!';;
      (question) REPLY='?';; (*) REPLY='i';;
    esac
    _zui_icon_style=${_ZUI_STYLE[accent]}
  fi
}

_zui_list_select_value() { # value
  local v=$1 i
  for (( i = 1; i <= ${#_zui_list_view}; i++ )); do
    if [[ ${_zui_list_view[i]} == "$v" ]]; then
      _zui_list_cursor=$i
      return 0
    fi
  done
  return 1
}

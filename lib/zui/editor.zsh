# zui editor: single-line input and multi-line textarea.
# Multi-byte characters count as one cell; see docs/LIMITATIONS.md.

typeset -g  _zui_ed_value="" _zui_ed_placeholder="" _zui_ed_cursor_mode="blink"
typeset -gi _zui_ed_pos=1 _zui_ed_limit=0 _zui_ed_mask=0
typeset -gi _zui_ed_caret_x=0 _zui_ed_hoff=0
typeset -ga _zui_ta_lines=("")
typeset -gi _zui_ta_row=1 _zui_ta_col=1 _zui_ta_limit=0 _zui_ta_scroll=0
typeset -gi _zui_ta_numbers=0 _zui_ta_caret_y=0 _zui_ta_caret_x=0
typeset -g  _zui_ta_placeholder="" _zui_ta_prompt="" _zui_ta_cursor_mode="blink"
typeset -gi _zui_ta_max_lines=0 _zui_ta_highlight=0

_zui_ed_reset() {
  _zui_ed_value=$1
  _zui_ed_limit=${2:-0}
  _zui_ed_pos=$(( ${#_zui_ed_value} + 1 ))
  _zui_ed_hoff=0
}

_zui_ed_masked() {
  local v=$1
  if (( _zui_ed_mask )); then
    _zui_utf8 && REPLY=${(l:${#v}::•:)} || REPLY=${(l:${#v}::*:)}
  else
    REPLY=$v
  fi
}

_zui_ed_draw() { # y x w focused
  local y=$1 x=$2 w=$3 focus=${4:-1}
  local v
  _zui_ed_masked "$_zui_ed_value"; v=$REPLY
  local n=${#v}

  # Horizontal scroll so the insertion point stays visible.
  local off=0
  if (( _zui_ed_pos - 1 > w - 1 )); then
    off=$(( _zui_ed_pos - w ))
  fi
  (( off < 0 )) && off=0
  _zui_ed_hoff=$off
  local vis=${v[off+1,off+w]}

  _zui_fill $y $x 1 $w ' ' "${_ZUI_STYLE[input]}"
  if (( n == 0 )) && [[ -n $_zui_ed_placeholder ]]; then
    _zui_truncate " $_zui_ed_placeholder" "$w"
    _zui_put $y $x "$REPLY" "${_ZUI_STYLE[muted]}"
    (( focus )) && [[ $_zui_ed_cursor_mode != hide ]] && _zui_put $y $x ' ' "${_ZUI_STYLE[caret]}"
  else
    _zui_put $y $x "$vis" "${_ZUI_STYLE[input]}"
  fi

  if (( focus )) && [[ $_zui_ed_cursor_mode != hide ]]; then
    local cx=$(( _zui_ed_pos - 1 - off ))
    (( cx < 0 )) && cx=0
    (( cx > w - 1 )) && cx=$(( w - 1 ))
    local at=${vis[cx+1]}
    [[ -z $at ]] && at=' '
    _zui_put $y $(( x + cx )) "$at" "${_ZUI_STYLE[caret]}"
    _zui_ed_caret_x=$(( x + cx ))
  fi
}

_zui_ed_prev_word() {
  local v=$_zui_ed_value p=$_zui_ed_pos
  (( p > 1 )) && (( p-- ))
  while (( p > 1 )) && [[ ${v[p]:- } == ' ' ]]; do (( p-- )); done
  while (( p > 1 )) && [[ ${v[p-1]:- } != ' ' ]]; do (( p-- )); done
  (( p < 1 )) && p=1
  _zui_ed_pos=$p
}

_zui_ed_next_word() {
  local v=$_zui_ed_value p=$_zui_ed_pos n=${#v}
  while (( p <= n )) && [[ ${v[p]:- } != ' ' ]]; do (( p++ )); done
  while (( p <= n )) && [[ ${v[p]:- } == ' ' ]]; do (( p++ )); done
  (( p > n + 1 )) && p=$(( n + 1 ))
  _zui_ed_pos=$p
}

# Returns 0 when the value changed, 1 otherwise. Enter/Esc are handled by caller.
_zui_ed_handle() {
  local v=$_zui_ed_value n=${#v} p=$_zui_ed_pos
  case $KEY in
    (BACKSPACE)
      (( p > 1 )) || return 1
      _zui_ed_value=${v[1,p-2]}${v[p,-1]}
      _zui_ed_pos=$(( p - 1 )) ;;
    (DELETE|CTRL_D)
      (( p <= n )) || return 1
      _zui_ed_value=${v[1,p-1]}${v[p+1,-1]} ;;
    (LEFT)   (( p > 1 )) && _zui_ed_pos=$(( p - 1 )) || return 1 ;;
    (RIGHT)  (( p <= n )) && _zui_ed_pos=$(( p + 1 )) || return 1 ;;
    (HOME|CTRL_A) _zui_ed_pos=1 ;;
    (END|CTRL_E)  _zui_ed_pos=$(( n + 1 )) ;;
    (CTRL_U) _zui_ed_value=${v[p,-1]}; _zui_ed_pos=1 ;;
    (CTRL_K) _zui_ed_value=${v[1,p-1]} ;;
    (CTRL_W) _zui_ed_prev_word; local q=$_zui_ed_pos
             _zui_ed_value=${v[1,q-1]}${v[p,-1]}; _zui_ed_pos=$q ;;
    (ALT-b)  _zui_ed_prev_word ;;
    (ALT-f)  _zui_ed_next_word ;;
    (TAB)    return 1 ;;
    (*)
      _zui_key_is_printable || return 1
      if (( _zui_ed_limit > 0 && n >= _zui_ed_limit )); then return 1; fi
      _zui_ed_value=${v[1,p-1]}${KEY}${v[p,-1]}
      _zui_ed_pos=$(( p + ${#KEY} )) ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Textarea
# ---------------------------------------------------------------------------
_zui_ta_reset() {
  local v=$1
  _zui_ta_limit=${2:-0}
  _zui_ta_lines=("${(@f)v}")
  (( ${#_zui_ta_lines} == 0 )) && _zui_ta_lines=("")
  _zui_ta_row=1; _zui_ta_col=1; _zui_ta_scroll=0
}

_zui_ta_text() {
  REPLY="${(pj:\n:)_zui_ta_lines}"
}

_zui_ta_len() {
  local l total=0
  for l in "${_zui_ta_lines[@]}"; do (( total += ${#l} + 1 )); done
  (( total > 0 )) && (( total-- ))
  REPLY=$total
}

_zui_ta_draw() { # y x w h focused
  local y=$1 x=$2 w=$3 h=$4 focus=${5:-1}
  local tw=$w
  local gutter=0 gcount promptw=${#_zui_ta_prompt}
  if (( _zui_ta_numbers )); then
    printf -v gcount '%d' ${#_zui_ta_lines}
    gutter=${#gcount}
    (( gutter < 2 )) && gutter=2
    tw=$(( w - gutter - 1 ))
  fi
  tw=$(( tw - promptw ))
  (( tw < 1 )) && tw=1

  # Keep the cursor row visible.
  if (( _zui_ta_row <= _zui_ta_scroll )); then
    _zui_ta_scroll=$(( _zui_ta_row - 1 ))
  elif (( _zui_ta_row > _zui_ta_scroll + h )); then
    _zui_ta_scroll=$(( _zui_ta_row - h ))
  fi
  (( _zui_ta_scroll < 0 )) && _zui_ta_scroll=0

  local i row=0 line hoff vis cx
  for (( i = _zui_ta_scroll + 1; i <= ${#_zui_ta_lines} && row < h; i++, row++ )); do
    line=${_zui_ta_lines[i]}
    hoff=0
    if (( i == _zui_ta_row && _zui_ta_col - 1 > tw - 1 )); then
      hoff=$(( _zui_ta_col - tw ))
      (( hoff < 0 )) && hoff=0
    fi
    vis=${line[hoff+1,hoff+tw]}
    local tx=$x
    if (( _zui_ta_numbers )); then
      printf -v REPLY '%*d ' $gutter $i
      _zui_put $(( y + row )) $x "$REPLY" "${_ZUI_STYLE[muted]}"
      tx=$(( x + gutter + 1 ))
    fi
    if [[ -n $_zui_ta_prompt ]]; then
      _zui_put $(( y + row )) $tx "$_zui_ta_prompt" "${_ZUI_STYLE[muted]}"
      tx=$(( tx + promptw ))
    fi
    local lstyle=${_ZUI_STYLE[input]}
    (( _zui_ta_highlight && i == _zui_ta_row )) && lstyle=${_ZUI_STYLE[selection]}
    _zui_fill $(( y + row )) $tx 1 $tw ' ' "$lstyle"
    _zui_put $(( y + row )) $tx "$vis" "$lstyle"
    if (( focus && i == _zui_ta_row )) && [[ $_zui_ta_cursor_mode != hide ]]; then
      cx=$(( _zui_ta_col - 1 - hoff ))
      (( cx < 0 )) && cx=0
      (( cx > tw - 1 )) && cx=$(( tw - 1 ))
      _zui_put $(( y + row )) $(( tx + cx )) "${vis[cx+1]}" "${_ZUI_STYLE[caret]}"
      _zui_ta_caret_y=$(( y + row )); _zui_ta_caret_x=$(( tx + cx ))
    fi
  done
  for (( ; row < h; row++ )); do
    _zui_fill $(( y + row )) $x 1 $w ' ' "${_ZUI_STYLE[input]}"
  done
  if [[ -z ${_zui_ta_lines[1]} && ${#_zui_ta_lines} == 1 && -n $_zui_ta_placeholder ]]; then
    _zui_truncate " $_zui_ta_placeholder" "$tw"
    local px=$(( x + (gutter ? gutter + 1 : 0) + promptw ))
    _zui_put $y $px "$REPLY" "${_ZUI_STYLE[muted]}"
  fi
}

_zui_ta_handle() {
  local row=$_zui_ta_row col=$_zui_ta_col
  local line=${_zui_ta_lines[row]} n=${#line}
  local total
  _zui_ta_len; total=$REPLY
  case $KEY in
    (ENTER)
      if (( _zui_ta_limit > 0 && total >= _zui_ta_limit )); then return 1; fi
      if (( _zui_ta_max_lines > 0 && ${#_zui_ta_lines} >= _zui_ta_max_lines )); then return 1; fi
      local left=${line[1,col-1]} right=${line[col,-1]}
      _zui_ta_lines[row]=$left
      _zui_ta_lines=("${(@)_zui_ta_lines[1,row]}" "$right" "${(@)_zui_ta_lines[row+1,-1]}")
      _zui_ta_row=$(( row + 1 )); _zui_ta_col=1 ;;
    (BACKSPACE)
      if (( col > 1 )); then
        _zui_ta_lines[row]=${line[1,col-2]}${line[col,-1]}
        _zui_ta_col=$(( col - 1 ))
      elif (( row > 1 )); then
        local prev=${_zui_ta_lines[row-1]}
        _zui_ta_lines[row-1]=$prev$line
        _zui_ta_lines=("${(@)_zui_ta_lines[1,row-1]}" "${(@)_zui_ta_lines[row+1,-1]}")
        _zui_ta_row=$(( row - 1 )); _zui_ta_col=$(( ${#prev} + 1 ))
      else
        return 1
      fi ;;
    (DELETE|CTRL_D)
      if (( col <= n )); then
        _zui_ta_lines[row]=${line[1,col-1]}${line[col+1,-1]}
      elif (( row < ${#_zui_ta_lines} )); then
        _zui_ta_lines[row]=$line${_zui_ta_lines[row+1]}
        _zui_ta_lines=("${(@)_zui_ta_lines[1,row]}" "${(@)_zui_ta_lines[row+2,-1]}")
      else
        return 1
      fi ;;
    (LEFT)
      if (( col > 1 )); then _zui_ta_col=$(( col - 1 ))
      elif (( row > 1 )); then _zui_ta_row=$(( row - 1 )); _zui_ta_col=$(( ${#_zui_ta_lines[row-1]} + 1 ))
      else return 1; fi ;;
    (RIGHT)
      if (( col <= n )); then _zui_ta_col=$(( col + 1 ))
      elif (( row < ${#_zui_ta_lines} )); then _zui_ta_row=$(( row + 1 )); _zui_ta_col=1
      else return 1; fi ;;
    (UP)
      (( row > 1 )) || return 1
      _zui_ta_row=$(( row - 1 ))
      local pmax=$(( ${#_zui_ta_lines[row-1]} + 1 ))
      (( _zui_ta_col > pmax )) && _zui_ta_col=$pmax ;;
    (DOWN)
      (( row < ${#_zui_ta_lines} )) || return 1
      _zui_ta_row=$(( row + 1 ))
      local nmax=$(( ${#_zui_ta_lines[row+1]} + 1 ))
      (( _zui_ta_col > nmax )) && _zui_ta_col=$nmax ;;
    (HOME|CTRL_A) _zui_ta_col=1 ;;
    (END|CTRL_E)  _zui_ta_col=$(( n + 1 )) ;;
    (PGUP) (( _zui_ta_row > 5 )) && _zui_ta_row=$(( _zui_ta_row - 5 )) || _zui_ta_row=1 ;;
    (PGDN)
      local max=${#_zui_ta_lines}
      (( _zui_ta_row + 5 <= max )) && _zui_ta_row=$(( _zui_ta_row + 5 )) || _zui_ta_row=$max ;;
    (TAB)
      if (( _zui_ta_limit > 0 && total + 2 > _zui_ta_limit )); then return 1; fi
      _zui_ta_lines[row]=${line[1,col-1]}"  "${line[col,-1]}
      _zui_ta_col=$(( col + 2 )) ;;
    (*)
      _zui_key_is_printable || return 1
      if (( _zui_ta_limit > 0 && total + ${#KEY} > _zui_ta_limit )); then return 1; fi
      _zui_ta_lines[row]=${line[1,col-1]}${KEY}${line[col,-1]}
      _zui_ta_col=$(( col + ${#KEY} )) ;;
  esac
  return 0
}

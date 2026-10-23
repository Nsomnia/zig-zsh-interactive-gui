# zui style

_ZUI_OPTDEF_style=(
  '|foreground|str|Text colour: name, 0-255 or #rrggbb|'
  '|background|str|Background colour: name, 0-255 or #rrggbb|'
  '|border|str|Border: rounded, normal, thick, double, block, hidden, none|rounded'
  '|border-foreground|str|Border foreground colour|'
  '|border-background|str|Border background colour|'
  '|padding|str|Inner padding: N or V,H or T,R,B,L|0'
  '|padding-background|str|Padding background colour|'
  '|margin|str|Outer margin: N or V,H or T,R,B,L|0'
  '|margin-background|str|Margin background colour|'
  '|width|int|Content width in columns (0 = fit text)|0'
  '|height|int|Content height in rows (0 = fit text)|0'
  '|align|str|Horizontal alignment: left, center, right|left'
  '|bold|flag|Bold text|0'
  '|italic|flag|Italic text|0'
  '|underline|flag|Underlined text|0'
  '|strikethrough|flag|Struck-through text|0'
  '|faint|flag|Faint text|0'
  '|text|str|Text to style (also accepted as arguments)|'
)

_ZUI_CMD_DESC[style]="Wrap text in borders, padding, margins and ANSI colour."
_ZUI_CMD_USAGE[style]="zui style [flags] [text...]"
_ZUI_CMD_LONG[style]="A non-interactive styling primitive, useful for composing banners and status blocks. Colour accepts names (red, cyan, default), 256-colour indices (0-255) and hex values when the terminal supports truecolour."
_ZUI_EXAMPLES[style]=$'zui style --border rounded --padding 1,2 --foreground 212 "Hello"\nzui style --border double --border-foreground 81 --bold "RELEASE 2.0"\nzui style --background 236 --foreground 252 --padding 1,3 "quoted text"\nzui style --margin 1 --margin-background 234 --align center "centred"'
_ZUI_NOTES[style]=$'Padding and margin accept one value (all sides), two values (vertical,horizontal) or four values (top,right,bottom,left).\nWhen stdout is not a terminal, ANSI escapes are omitted.'

_zui_style_pad() { # spec -> _ZUI_BOX array t r b l
  local v=$1
  typeset -ga _ZUI_BOX
  if [[ -z $v || $v == 0 ]]; then _ZUI_BOX=(0 0 0 0); return; fi
  local -a p=("${(@s:,:)v}")
  local i
  for (( i = 1; i <= ${#p}; i++ )); do
    [[ ${p[i]} == <-> ]] || { _zui_err "bad box value '$v'"; return 1; }
  done
  case ${#p} in
    (1) _ZUI_BOX=($p[1] $p[1] $p[1] $p[1]) ;;
    (2) _ZUI_BOX=($p[1] $p[2] $p[1] $p[2]) ;;
    (4) _ZUI_BOX=($p[1] $p[2] $p[3] $p[4]) ;;
    (*) _zui_err "bad box value '$v'"; return 1 ;;
  esac
}

_zui_style_chars() {
  case $1 in
    (ascii)  _ZUI_TL='+' _ZUI_TR='+' _ZUI_BL='+' _ZUI_BR='+' _ZUI_H='-' _ZUI_V='|' ;;
    (normal) _ZUI_TL='┌' _ZUI_TR='┐' _ZUI_BL='└' _ZUI_BR='┘' _ZUI_H='─' _ZUI_V='│' ;;
    (thick)  _ZUI_TL='┏' _ZUI_TR='┓' _ZUI_BL='┗' _ZUI_BR='┛' _ZUI_H='━' _ZUI_V='┃' ;;
    (double) _ZUI_TL='╔' _ZUI_TR='╗' _ZUI_BL='╚' _ZUI_BR='╝' _ZUI_H='═' _ZUI_V='║' ;;
    (block)  _ZUI_TL='▛' _ZUI_TR='▜' _ZUI_BL='▙' _ZUI_BR='▟' _ZUI_H='▀' _ZUI_V='█' ;;
    (hidden) _ZUI_TL=' ' _ZUI_TR=' ' _ZUI_BL=' ' _ZUI_BR=' ' _ZUI_H=' ' _ZUI_V=' ' ;;
    (none)   _ZUI_TL='' _ZUI_TR='' _ZUI_BL='' _ZUI_BR='' _ZUI_H='' _ZUI_V='' ;;
    (*)      _ZUI_TL='╭' _ZUI_TR='╮' _ZUI_BL='╰' _ZUI_BR='╯' _ZUI_H='─' _ZUI_V='│' ;;
  esac
}

_zui_style_wrap() { # style text
  local s=$1 t=$2
  [[ -z $s ]] && { printf '%s' "$t"; return; }
  printf '%s%s\e[0m' "$s" "$t"
}

_zui_cmd_style() {
  local text=${_ZUI_OPT[text]:-}
  if [[ -z $text ]] && (( ${#_ZUI_ARGS} )); then text="${(j: :)_ZUI_ARGS}"; fi
  if [[ -z $text && ! -t 0 ]]; then text=$(cat); fi
  [[ -z $text ]] && { print -r -- ""; return 0; }

  local fg=${_ZUI_OPT[foreground]:-}
  local bg=${_ZUI_OPT[background]:-}
  local bfg=${_ZUI_OPT[border-foreground]:-$fg}
  local bbg=${_ZUI_OPT[border-background]:-$bg}
  local pbg=${_ZUI_OPT[padding-background]:-}
  local mbg=${_ZUI_OPT[margin-background]:-}
  local border=${_ZUI_OPT[border]:-rounded}
  if (( ZUI_ASCII )) && [[ $border == (rounded|normal|thick|double|block) ]]; then border=ascii; fi
  local align=${_ZUI_OPT[align]:-left}
  local width=${_ZUI_OPT[width]:-0}
  local height=${_ZUI_OPT[height]:-0}
  [[ $width == <-> ]] || width=0
  [[ $height == <-> ]] || height=0

  _zui_style_pad "${_ZUI_OPT[padding]:-0}" || return 2
  local pt=$_ZUI_BOX[1] pr=$_ZUI_BOX[2] pb=$_ZUI_BOX[3] pl=$_ZUI_BOX[4]
  _zui_style_pad "${_ZUI_OPT[margin]:-0}" || return 2
  local mt=$_ZUI_BOX[1] mr=$_ZUI_BOX[2] mb=$_ZUI_BOX[3] ml=$_ZUI_BOX[4]

  local -a attrs
  (( ${_ZUI_OPT[bold]:-0} )) && attrs+=(bold)
  (( ${_ZUI_OPT[italic]:-0} )) && attrs+=(italic)
  (( ${_ZUI_OPT[underline]:-0} )) && attrs+=(underline)
  (( ${_ZUI_OPT[strikethrough]:-0} )) && attrs+=(strikethrough)
  (( ${_ZUI_OPT[faint]:-0} )) && attrs+=(dim)

  local tstyle bstyle pstyle mstyle
  tstyle=$(_zui_sgr "$fg" "$bg" "${attrs[@]}")
  bstyle=$(_zui_sgr "$bfg" "$bbg")
  pstyle=""
  [[ -n $pbg ]] && pstyle=$(_zui_sgr "" "$pbg")
  mstyle=""
  [[ -n $mbg ]] && mstyle=$(_zui_sgr "" "$mbg")
  [[ -z $pstyle ]] && pstyle=$tstyle

  # Content lines and width.
  local -a lines
  if (( width > 0 )); then
    _zui_wrap "$text" $width
    lines=("${_ZUI_LINES[@]}")
  else
    lines=("${(@f)text}")
    local max=0 l
    for l in "${lines[@]}"; do (( ${#l} > max )) && max=${#l}; done
    width=$max
  fi
  (( width < 1 )) && width=1
  (( height > 0 )) && (( ${#lines} > height )) && lines=("${lines[1,height]}")
  (( height > 0 )) && while (( ${#lines} < height )); do lines+=(""); done

  _zui_style_chars "$border"
  local hasb=1; [[ $border == none ]] && hasb=0

  local inner=$(( width + pl + pr + (hasb ? 2 : 0) ))
  local full=$(( inner + ml + mr ))
  local -a out
  local i pad

  # Margin top/bottom.
  for (( i = 0; i < mt; i++ )); do
    pad=${(l:full:: :)}
    out+=("$( _zui_style_wrap "$mstyle" "$pad" )")
  done

  # Top border.
  if (( hasb )); then
    _zui_spaces $(( width + pl + pr )); pad=$REPLY
    local top="${_ZUI_TL}${pad// /$_ZUI_H}${_ZUI_TR}"
    local lmar=${(l:ml:: :)} rmar=${(l:mr:: :)}
    out+=("$(_zui_style_wrap "$mstyle" "$lmar")"$(_zui_style_wrap "$bstyle" "$top")"$(_zui_style_wrap "$mstyle" "$rmar")")
  fi

  # Body.
  for l in "${lines[@]}"; do
    _zui_pad "$l" $width "$align"; local cell=$REPLY
    local left=${(l:pl:: :)} right=${(l:pr:: :)}
    local body=""
    if (( hasb )); then body+=$( _zui_style_wrap "$bstyle" "$_ZUI_V" ); fi
    body+=$( _zui_style_wrap "$pstyle" "$left" )
    body+=$( _zui_style_wrap "$tstyle" "$cell" )
    body+=$( _zui_style_wrap "$pstyle" "$right" )
    if (( hasb )); then body+=$( _zui_style_wrap "$bstyle" "$_ZUI_V" ); fi
    local lmar=${(l:ml:: :)} rmar=${(l:mr:: :)}
    out+=("$(_zui_style_wrap "$mstyle" "$lmar")${body}$(_zui_style_wrap "$mstyle" "$rmar")")
  done

  # Bottom border.
  if (( hasb )); then
    _zui_spaces $(( width + pl + pr )); pad=$REPLY
    local bot="${_ZUI_BL}${pad// /$_ZUI_H}${_ZUI_BR}"
    local lmar=${(l:ml:: :)} rmar=${(l:mr:: :)}
    out+=("$(_zui_style_wrap "$mstyle" "$lmar")"$(_zui_style_wrap "$bstyle" "$bot")"$(_zui_style_wrap "$mstyle" "$rmar")")
  fi

  for (( i = 0; i < mb; i++ )); do
    pad=${(l:full:: :)}
    out+=("$( _zui_style_wrap "$mstyle" "$pad" )")
  done

  local o
  for o in "${out[@]}"; do print -r -- "$o"; done
  return 0
}

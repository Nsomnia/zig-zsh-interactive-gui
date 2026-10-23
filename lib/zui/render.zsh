# zui render: direct-to-curses drawing primitives.
# Widths assume one terminal cell per character (see docs/LIMITATIONS.md).

typeset -gi _zui_drawn=0
typeset -g  REPLY=""

_zui_attr() {
  local style=${1:-${_ZUI_STYLE[text]}}
  local -a a
  a=(${=style})
  (( ${#a} )) && zcurses attr stdscr "${a[@]}" 2>/dev/null
}

_zui_present() {
  zcurses refresh stdscr 2>/dev/null
  print -n '\e[?25l'
}

_zui_move() { zcurses move stdscr $1 $2 2>/dev/null }

_zui_clear() {
  local style=${1:-${_ZUI_STYLE[screen]}}
  _zui_fill 0 0 "$ZUI_ROWS" "$ZUI_COLS" ' ' "$style"
}

_zui_spaces() {
  local n=$1 out=""
  (( n > 0 )) && printf -v out '%*s' "$n" ''
  REPLY=$out
}

_zui_repeat() { # char count
  local n=$2 out=""
  (( n > 0 )) && printf -v out '%*s' "$n" ''
  REPLY=${out// /$1}
}

_zui_put() { # y x text style
  local y=$1 x=$2 text=$3 style=${4:-${_ZUI_STYLE[text]}}
  (( y < 0 || y >= ZUI_ROWS || x >= ZUI_COLS )) && return 0
  (( x < 0 )) && return 0
  text=${text//$'\n'/ }
  text=${text//$'\r'/}
  local avail=$(( ZUI_COLS - x ))
  (( ${#text} > avail )) && text=${text[1,avail]}
  (( ${#text} == 0 )) && return 0
  zcurses move stdscr $y $x 2>/dev/null
  _zui_attr "$style"
  zcurses string stdscr "$text" 2>/dev/null
}

_zui_fill() { # y x h w char style
  local y=$1 x=$2 h=$3 w=$4 ch=$5 style=${6:-${_ZUI_STYLE[text]}}
  (( h <= 0 || w <= 0 )) && return 0
  local line
  _zui_repeat "$ch" "$w"; line=$REPLY
  local i
  for (( i = 0; i < h; i++ )); do
    (( y + i >= ZUI_ROWS )) && break
    _zui_put $(( y + i )) $x "$line" "$style"
  done
}

_zui_hline() { # y x len char style
  local y=$1 x=$2 len=$3 ch=${4:-$_ZUI_H} style=${5:-${_ZUI_STYLE[frame]}}
  local line
  _zui_repeat "$ch" "$len"; line=$REPLY
  _zui_put $y $x "$line" "$style"
}

_zui_box() { # y x h w style
  local y=$1 x=$2 h=$3 w=$4 style=${5:-${_ZUI_STYLE[frame]}}
  (( h < 2 || w < 2 )) && return 0
  local inner=$(( w - 2 )) hline
  _zui_repeat "$_ZUI_H" "$inner"; hline=$REPLY
  _zui_put $y $x "$_ZUI_TL$hline$_ZUI_TR" "$style"
  _zui_put $(( y + h - 1 )) $x "$_ZUI_BL$hline$_ZUI_BR" "$style"
  local i
  for (( i = 1; i < h - 1; i++ )); do
    _zui_put $(( y + i )) $x "$_ZUI_V" "$style"
    _zui_put $(( y + i )) $(( x + w - 1 )) "$_ZUI_V" "$style"
  done
}

# Draw a frame and set the inner region in _ZUI_IY/_ZUI_IX/_ZUI_IH/_ZUI_IW.
_zui_frame() { # y x h w title [title_style] [border_style]
  emulate -L zsh
  local y=$1 x=$2 h=$3 w=$4 title=${5-}
  local tstyle=${6:-${_ZUI_STYLE[title]}} bstyle=${7:-${_ZUI_STYLE[frame]}}
  _zui_fill $y $x $h $w ' ' "${_ZUI_STYLE[text]}"
  if [[ $_ZUI_BORDER != none ]]; then
    _zui_box $y $x $h $w "$bstyle"
  fi
  if [[ -n $title ]]; then
    local t=$title
    (( ${#t} > w - 6 )) && t=${t[1,w-9]}'...'
    local tx=$(( x + (w - ${#t} - 2) / 2 ))
    (( tx < x + 1 )) && tx=$(( x + 1 ))
    _zui_put $y $tx " $t " "$tstyle"
  fi
  _ZUI_IY=$(( y + 1 )); _ZUI_IX=$(( x + 1 ))
  _ZUI_IH=$(( h - 2 )); _ZUI_IW=$(( w - 2 ))
}

_zui_truncate() { # text width [ellipsis]
  local t=$1 w=$2 e=${3:-…}
  _zui_utf8 || e='...'
  if (( ${#t} <= w )); then REPLY=$t; return; fi
  (( w <= ${#e} )) && { REPLY=${t[1,w]}; return; }
  REPLY=${t[1,w-${#e}]}$e
}

_zui_pad() { # text width align(left|center|right)
  local t=$1 w=$2 a=${3:-left} pad
  (( ${#t} > w )) && { _zui_truncate "$t" "$w"; t=$REPLY; }
  pad=$(( w - ${#t} ))
  (( pad < 0 )) && pad=0
  case $a in
    (right)  REPLY="${(l:pad:: :)}${t}" ;;
    (center) REPLY="${(l:$((pad/2)):: :)}${t}${(l:$((pad - pad/2)):: :)}" ;;
    (*)      REPLY="${t}${(l:pad:: :)}" ;;
  esac
}

# Split text into display lines of at most <width> cells.
_zui_wrap() { # text width  -> writes _ZUI_LINES array
  emulate -L zsh
  local text=$1 width=$2
  typeset -ga _ZUI_LINES
  _ZUI_LINES=()
  (( width < 1 )) && width=1
  text=${text//$'\t'/    }
  local -a raw
  raw=("${(@f)text}")
  (( ${#raw} == 0 )) && raw=('')
  local line rest cut
  for line in "${raw[@]}"; do
    line=${line%$'\r'}
    if (( ${#line} == 0 )); then _ZUI_LINES+=(""); continue; fi
    while (( ${#line} > width )); do
      rest=${line[1,width]}
      if [[ $rest == *' '* ]]; then
        cut=${rest% *}
        # Do not split on the first space when the word itself fits later.
        (( ${#cut} == 0 )) && cut=$rest
      else
        cut=$rest
      fi
      _ZUI_LINES+=("$cut")
      line=${line[${#cut}+1,-1]}
      line=${line# }
    done
    _ZUI_LINES+=("$line")
  done
}

_zui_draw_lines() { # y x w h array-name [style] [offset]
  local y=$1 x=$2 w=$3 h=$4 name=$5 style=${6:-${_ZUI_STYLE[text]}} off=${7:-0}
  local -a lines
  lines=("${(@P)name}")
  local i n=0
  for (( i = off + 1; i <= ${#lines} && n < h; i++, n++ )); do
    _zui_truncate "$lines[i]" "$w"
    _zui_put $(( y + n )) $x "$REPLY" "$style"
  done
  _zui_drawn=$n
}

_zui_text() { # y x w h text style [offset]
  _zui_wrap "$5" "$3"
  typeset -ga _ZUI_LINES
  _zui_draw_lines $1 $2 $3 $4 _ZUI_LINES "${6:-${_ZUI_STYLE[text]}}" "${7:-0}"
}

_zui_strip_ansi() {
  emulate -L zsh
  setopt localoptions extendedglob
  REPLY=${1//$'\e'\[[0-9;]#[A-Za-z]/}
  REPLY=${REPLY//$'\e'\[[0-9;]#[A-Za-z]/}
}

_zui_center() { # y x w text style
  local y=$1 x=$2 w=$3 t=$4 style=${5:-${_ZUI_STYLE[text]}}
  _zui_truncate "$t" "$w"
  local tx=$(( x + (w - ${#REPLY}) / 2 ))
  _zui_put $y $tx "$REPLY" "$style"
}

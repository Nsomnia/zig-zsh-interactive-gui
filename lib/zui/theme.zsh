# zui theme: semantic styles for curses and ANSI output.

typeset -gA _ZUI_STYLE=()
typeset -g  _ZUI_BORDER="rounded"
typeset -g  _ZUI_TL="╭" _ZUI_TR="╮" _ZUI_BL="╰" _ZUI_BR="╯"
typeset -g  _ZUI_H="─" _ZUI_V="│" _ZUI_BG_CHAR=" "
typeset -gi _ZUI_TRUE=0

_zui_theme_profile() {
  emulate -L zsh
  if (( ZUI_NO_COLOR )) || [[ -n ${NO_COLOR-} ]] || [[ ${TERM-} == dumb ]]; then
    print -r -- none; return
  fi
  local n=${ZCURSES_COLORS:-0}
  if (( n >= 256 )); then print -r -- 256
  elif (( n >= 16 )); then print -r -- 16
  elif (( n >= 8 )); then print -r -- 16
  else print -r -- none; fi
}

# style <key> <fg/bg> [attrs...]
_zui_style() {
  local key=$1 spec=$2; shift 2
  _ZUI_STYLE[$key]="$spec${*:+ $*}"
}

_zui_theme_init() {
  emulate -L zsh
  local name=${1:-default} profile=${2:-256}
  local fg bg
  [[ $name == mono ]] && profile=none
  _ZUI_STYLE=()

  if [[ $profile == none ]]; then
    _zui_style screen "default/default"
    _zui_style frame "default/default" bold
    _zui_style title "default/default" bold underline
    _zui_style text "default/default"
    _zui_style muted "default/default" dim
    _zui_style accent "default/default" bold
    _zui_style input "default/default" underline
    _zui_style input_focus "default/default" underline bold
    _zui_style caret "default/default" reverse
    _zui_style button "default/default"
    _zui_style button_focus "default/default" reverse bold
    _zui_style selection "default/default" reverse
    _zui_style selection_focus "default/default" reverse bold
    _zui_style shadow "default/default"
    _zui_style header "default/default" bold
    _zui_style footer "default/default" dim
    _zui_style success "default/default" bold
    _zui_style warn "default/default" bold underline
    _zui_style danger "default/default" bold reverse
    _zui_style gauge "default/default" reverse
    _zui_style gauge_ok "default/default" reverse bold
    _zui_style icon "default/default" bold
    _zui_style mark "default/default" bold
    _zui_style scroll "default/default" dim
    _zui_border_set "$_ZUI_BORDER"
    return
  fi

  if [[ $profile == 16 ]]; then
    _zui_style screen "default/default"
    _zui_style frame "4/default"
    _zui_style title "15/4" bold
    _zui_style text "default/default"
    _zui_style muted "8/default" dim
    _zui_style accent "6/default" bold
    _zui_style input "15/4" underline
    _zui_style input_focus "15/4" bold underline
    _zui_style caret "0/7" reverse
    _zui_style button "0/7"
    _zui_style button_focus "15/4" bold
    _zui_style selection "0/6"
    _zui_style selection_focus "0/6" bold reverse
    _zui_style shadow "0/8"
    _zui_style header "15/4" bold
    _zui_style footer "8/default" dim
    _zui_style success "2/default" bold
    _zui_style warn "3/default" bold
    _zui_style danger "1/default" bold
    _zui_style gauge "0/6"
    _zui_style gauge_ok "0/2" bold
    _zui_style icon "6/default" bold
    _zui_style mark "2/default" bold
    _zui_style scroll "8/default" dim
    _zui_border_set "$_ZUI_BORDER"
    return
  fi

  # 256-colour palettes.  Values are ncurses colour indices.
  local -A t
  case $name in
    (light)
      t=(bg 255 fg 235 frame 25 title 25 muted 243 accent 90
         input 232 inp_bg 254 caret_bg 25 button_bg 253
         focus_bg 25 focus_fg 255 sel_bg 153 sel_fg 232
         shadow 252 success 28 warn 130 danger 160 header 25
         footer 243 gauge 33 gauge_ok 28 icon 25 mark 28) ;;
    (dracula)
      t=(bg 236 fg 253 frame 141 title 212 muted 243 accent 212
         input 255 inp_bg 238 caret_bg 212 button_bg 238
         focus_bg 212 focus_fg 236 sel_bg 61 sel_fg 253
         shadow 234 success 84 warn 228 danger 203 header 141
         footer 243 gauge 117 gauge_ok 84 icon 212 mark 84) ;;
    (gruvbox)
      t=(bg 235 fg 223 frame 109 title 214 muted 245 accent 208
         input 229 inp_bg 237 caret_bg 208 button_bg 237
         focus_bg 208 focus_fg 235 sel_bg 239 sel_fg 223
         shadow 234 success 142 warn 214 danger 167 header 109
         footer 245 gauge 108 gauge_ok 142 icon 208 mark 142) ;;
    (nord)
      t=(bg 236 fg 252 frame 67 title 109 muted 244 accent 109
         input 255 inp_bg 238 caret_bg 67 button_bg 238
         focus_bg 67 focus_fg 236 sel_bg 60 sel_fg 252
         shadow 234 success 150 warn 222 danger 174 header 67
         footer 244 gauge 67 gauge_ok 150 icon 109 mark 150) ;;
    (solarized)
      t=(bg 234 fg 187 frame 33 title 37 muted 242 accent 136
         input 230 inp_bg 235 caret_bg 33 button_bg 235
         focus_bg 33 focus_fg 234 sel_bg 237 sel_fg 187
         shadow 233 success 64 warn 136 danger 160 header 33
         footer 242 gauge 37 gauge_ok 64 icon 136 mark 64) ;;
    (catppuccin)
      t=(bg 234 fg 189 frame 111 title 183 muted 243 accent 218
         input 255 inp_bg 236 caret_bg 183 button_bg 236
         focus_bg 183 focus_fg 234 sel_bg 60 sel_fg 189
         shadow 233 success 151 warn 223 danger 211 header 111
         footer 243 gauge 116 gauge_ok 151 icon 218 mark 151) ;;
    (*) # default
      t=(bg 234 fg 252 frame 39 title 81 muted 245 accent 213
         input 255 inp_bg 235 caret_bg 45 button_bg 236
         focus_bg 45 focus_fg 16 sel_bg 238 sel_fg 252
         shadow 236 success 114 warn 221 danger 203 header 81
         footer 244 gauge 45 gauge_ok 114 icon 213 mark 114) ;;
  esac
  _zui_style screen "$t[fg]/$t[bg]"
  _zui_style frame "$t[frame]/$t[bg]"
  _zui_style title "$t[title]/$t[bg]" bold
  _zui_style text "$t[fg]/$t[bg]"
  _zui_style muted "$t[muted]/$t[bg]"
  _zui_style accent "$t[accent]/$t[bg]" bold
  _zui_style input "$t[input]/$t[inp_bg]"
  _zui_style input_focus "$t[input]/$t[inp_bg]" bold
  _zui_style caret "$t[focus_fg]/$t[caret_bg]" bold
  _zui_style button "$t[fg]/$t[button_bg]"
  _zui_style button_focus "$t[focus_fg]/$t[focus_bg]" bold
  _zui_style selection "$t[sel_fg]/$t[sel_bg]"
  _zui_style selection_focus "$t[focus_fg]/$t[focus_bg]" bold
  _zui_style shadow "0/$t[shadow]"
  _zui_style header "$t[header]/$t[bg]" bold
  _zui_style footer "$t[footer]/$t[bg]"
  _zui_style success "$t[success]/$t[bg]" bold
  _zui_style warn "$t[warn]/$t[bg]" bold
  _zui_style danger "$t[danger]/$t[bg]" bold
  _zui_style gauge "$t[focus_fg]/$t[gauge]"
  _zui_style gauge_ok "$t[focus_fg]/$t[gauge_ok]" bold
  _zui_style icon "$t[icon]/$t[bg]" bold
  _zui_style mark "$t[mark]/$t[bg]" bold
  _zui_style scroll "$t[muted]/$t[bg]" dim
  _zui_border_set "$_ZUI_BORDER"
}

_zui_theme_reapply() {
  _zui_theme_init "$ZUI_THEME" "$ZUI_PROFILE"
  _zui_clear
}

# ---------------------------------------------------------------------------
# Borders
# ---------------------------------------------------------------------------
_zui_border_set() {
  local b=${1:-rounded}
  [[ $b == auto ]] && { _zui_utf8 && b=rounded || b=ascii }
  _ZUI_BORDER=$b
  case $b in
    (ascii)   _ZUI_TL='+' _ZUI_TR='+' _ZUI_BL='+' _ZUI_BR='+' _ZUI_H='-' _ZUI_V='|' ;;
    (sharp)   _ZUI_TL='┌' _ZUI_TR='┐' _ZUI_BL='└' _ZUI_BR='┘' _ZUI_H='─' _ZUI_V='│' ;;
    (double)  _ZUI_TL='╔' _ZUI_TR='╗' _ZUI_BL='╚' _ZUI_BR='╝' _ZUI_H='═' _ZUI_V='║' ;;
    (thick)   _ZUI_TL='┏' _ZUI_TR='┓' _ZUI_BL='┗' _ZUI_BR='┛' _ZUI_H='━' _ZUI_V='┃' ;;
    (none)    _ZUI_TL='' _ZUI_TR='' _ZUI_BL='' _ZUI_BR='' _ZUI_H=' ' _ZUI_V=' ' ;;
    (hidden)  _ZUI_TL=' ' _ZUI_TR=' ' _ZUI_BL=' ' _ZUI_BR=' ' _ZUI_H=' ' _ZUI_V=' ' ;;
    (*)       _zui_utf8 || _zui_border_set ascii; [[ $_ZUI_BORDER == ascii ]] && return
              _ZUI_TL='╭' _ZUI_TR='╮' _ZUI_BL='╰' _ZUI_BR='╯' _ZUI_H='─' _ZUI_V='│' ;;
  esac
}

# ---------------------------------------------------------------------------
# ANSI (non-curses) helpers
# ---------------------------------------------------------------------------
_zui_ansi_profile() {
  emulate -L zsh
  if (( ZUI_NO_COLOR )) || [[ -n ${NO_COLOR-} ]]; then print -r -- none; return; fi
  [[ -t 1 || ${ZUI_FORCE_COLOR-} == 1 ]] || { print -r -- none; return; }
  zmodload -F zsh/terminfo b:terminfo 2>/dev/null
  local colors=${terminfo[colors]:-8}
  if [[ ${COLORTERM-} == (truecolor|24bit) ]]; then print -r -- true
  elif (( colors >= 256 )); then print -r -- 256
  else print -r -- 16; fi
}

_zui_ansi_named16() {
  case ${1:l} in
    black) print -r -- 0;; red) print -r -- 1;; green) print -r -- 2;;
    yellow) print -r -- 3;; blue) print -r -- 4;; magenta) print -r -- 5;;
    cyan) print -r -- 6;; white) print -r -- 7;; *default*) print -r -- 9;;
    *) print -r -- -1;;
  esac
}

# _zui_sgr fg bg attrs...
_zui_sgr() {
  emulate -L zsh
  local fg=$1 bg=$2; shift 2
  local profile=${ZUI_ANSI_PROFILE:-none}
  [[ $profile == none ]] && { print -r -- ""; return; }
  local -a out
  local n hex r g b
  if [[ -n $fg && $fg != - && $fg != default ]]; then
    n=$(_zui_ansi_named16 "$fg")
    if (( n >= 0 )); then
      if [[ $profile == 16 ]]; then out+=($(( 30 + (n % 8) ))); else out+=(38 5 $n); fi
    elif [[ $fg == \#* ]]; then
      hex=${fg#\#}
      r=$(( 16#${hex[1,2]} )); g=$(( 16#${hex[3,4]} )); b=$(( 16#${hex[5,6]} ))
      out+=(38 2 $r $g $b)
    else
      out+=(38 5 $fg)
    fi
  fi
  if [[ -n $bg && $bg != - && $bg != default ]]; then
    n=$(_zui_ansi_named16 "$bg")
    if (( n >= 0 )); then
      if [[ $profile == 16 ]]; then out+=($(( 40 + (n % 8) ))); else out+=(48 5 $n); fi
    elif [[ $bg == \#* ]]; then
      hex=${bg#\#}
      r=$(( 16#${hex[1,2]} )); g=$(( 16#${hex[3,4]} )); b=$(( 16#${hex[5,6]} ))
      out+=(48 2 $r $g $b)
    else
      out+=(48 5 $bg)
    fi
  fi
  local a
  for a in "$@"; do
    case $a in
      (bold) out+=(1);; (dim) out+=(2);; (italic) out+=(3);;
      (underline) out+=(4);; (blink) out+=(5);; (reverse) out+=(7);;
      (strikethrough) out+=(9);;
    esac
  done
  (( ${#out} )) && print -r -- $'\e['"${(j:;:)out}"'m'
}

_zui_ansi() { # style semantic
  emulate -L zsh
  local s=$1 p=${ZUI_ANSI_PROFILE:-none}
  [[ $p == none ]] && return 0
  local fg="" bg="" attr=""
  if [[ $p == (256|true) ]]; then
    case $s in
      (title)     fg=81;  attr=bold ;;
      (heading)   fg=213; attr=bold ;;
      (cmd)       fg=114; attr=bold ;;
      (opt)       fg=117 ;;
      (metavar)   fg=180 ;;
      (dim|muted) fg=244 ;;
      (accent)    fg=213; attr=bold ;;
      (err)       fg=203; attr=bold ;;
      (ok)        fg=114; attr=bold ;;
      (warn)      fg=221; attr=bold ;;
      (bold)      attr=bold ;;
      (underline) attr=underline ;;
      (reset)     printf '\e[0m'; return ;;
      (*)         return ;;
    esac
  else
    case $s in
      (title)     fg=cyan; attr=bold ;;
      (heading)   fg=magenta; attr=bold ;;
      (cmd)       fg=green; attr=bold ;;
      (opt)       fg=blue ;;
      (metavar)   fg=yellow ;;
      (dim|muted) fg=white ;;
      (accent)    fg=magenta; attr=bold ;;
      (err)       fg=red; attr=bold ;;
      (ok)        fg=green; attr=bold ;;
      (warn)      fg=yellow; attr=bold ;;
      (bold)      attr=bold ;;
      (underline) attr=underline ;;
      (reset)     printf '\e[0m'; return ;;
      (*)         return ;;
    esac
  fi
  _zui_sgr "$fg" "$bg" $attr
}

_zui_color_reset() { [[ ${ZUI_ANSI_PROFILE:-none} != none ]] && printf '\e[0m'; }

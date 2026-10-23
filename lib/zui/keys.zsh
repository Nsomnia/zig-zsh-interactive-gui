# zui keys: byte-level key decoding.
# zcurses' keypad mode returns only the ESC byte for arrows on several zsh
# builds, so we decode CSI/SS3 sequences ourselves.  Works with any terminal.

typeset -g KEY=""
typeset -g _ZUI_LAST_MS=0

# _zui_readkey [timeout-ms] -> KEY; status 0 key, 1 timeout, 2 abort
_zui_readkey() {
  emulate -L zsh
  local ms=${1:-150} ch
  (( _ZUI_ABORT )) && return 2
  zcurses timeout stdscr $ms
  _ZUI_LAST_MS=$ms
  if ! zcurses input stdscr ch 2>/dev/null; then
    (( _ZUI_ABORT )) && return 2
    KEY=""
    return 1
  fi
  _zui_decode_key "$ch"
}

# Read one more byte quickly (used for escape sequences).
_zui_getch() {
  local ms=${1:-30} ch
  zcurses timeout stdscr $ms
  zcurses input stdscr ch 2>/dev/null || return 1
  REPLY=$ch
}

_zui_decode_key() {
  emulate -L zsh
  local ch=$1
  KEY=""

  if [[ -z $ch ]]; then return 1; fi

  case $ch in
    ($'\r'|$'\n') KEY=ENTER; return 0 ;;
    ($'\t')       KEY=TAB; return 0 ;;
    ($'\x7f'|$'\x08') KEY=BACKSPACE; return 0 ;;
    ($'\x03')     _ZUI_ABORT=130; return 2 ;;
    ($'\x1b')     _zui_decode_escape; return $? ;;
  esac

  local code=$(( #ch ))
  if (( code > 0 && code < 32 )); then
    local letter
    printf -v letter '%b' "\\x$(printf '%02x' $(( code + 64 )))"
    KEY="CTRL_$letter"
    return 0
  fi

  KEY=$ch
  return 0
}

_zui_decode_escape() {
  emulate -L zsh
  local seq="" c

  if ! _zui_getch 35; then KEY=ESC; return 0; fi
  c=$REPLY
  case $c in
    ('[')
      seq="["
      local i=0
      while (( i < 8 )); do
        if ! _zui_getch 35; then break; fi
        seq+=$REPLY
        # CSI final byte is 0x40-0x7e.
        if [[ $REPLY == [a-zA-Z~] ]]; then break; fi
        (( i++ ))
      done
      case $seq in
        ('[A') KEY=UP ;;
        ('[B') KEY=DOWN ;;
        ('[C') KEY=RIGHT ;;
        ('[D') KEY=LEFT ;;
        ('[H'|'[1~'|'[7~') KEY=HOME ;;
        ('[F'|'[4~'|'[8~') KEY=END ;;
        ('[Z') KEY=BACKTAB ;;
        ('[2~') KEY=INSERT ;;
        ('[3~') KEY=DELETE ;;
        ('[5~') KEY=PGUP ;;
        ('[6~') KEY=PGDN ;;
        ('[E') KEY=CENTER ;;
        ('[200~'|'[201~') KEY=PASTE ;;
        ('[<'*) KEY=MOUSE ;; # mouse report; ignored by widgets
        (*) KEY=UNKNOWN ;;
      esac
      return 0 ;;
    ('O')
      if ! _zui_getch 35; then KEY=ESC; return 0; fi
      case $REPLY in
        (A) KEY=UP;; (B) KEY=DOWN;; (C) KEY=RIGHT;; (D) KEY=LEFT;;
        (H) KEY=HOME;; (F) KEY=END;; (P) KEY=F1;; (Q) KEY=F2;;
        (R) KEY=F3;; (S) KEY=F4;; (*) KEY=UNKNOWN;;
      esac
      return 0 ;;
    ('\x1b')
      # ESC ESC: treat as a literal escape.
      KEY=ESC; return 0 ;;
    (*)
      KEY="ALT-$c"; return 0 ;;
  esac
}

_zui_key_is_printable() {
  [[ -n $KEY && ${#KEY} -le 4 && $KEY != (ENTER|TAB|BACKSPACE|ESC|UP|DOWN|LEFT|RIGHT|HOME|END|PGUP|PGDN|DELETE|INSERT|F1|F2|F3|F4|MOUSE|PASTE|UNKNOWN|CENTER|BACKTAB) && $KEY != CTRL_* && $KEY != ALT-* ]]
}

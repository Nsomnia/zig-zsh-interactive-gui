#!/usr/bin/env zsh
# Integration tests: drive real zui processes through a pseudo-terminal.
emulate -R zsh
setopt extendedglob
ZUI_ROOT=${0:A:h:h}
export ZUI_ROOT
zmodload zsh/zpty || exit 1

typeset -gi TESTS=0 FAILS=0
_T_RAW="" _T_OUT="" _T_RC=""

t_ok() {
  (( TESTS++ ))
  if [[ $1 == 1 ]]; then print -r -- "ok   $2"; else print -r -- "FAIL $2"; (( FAILS++ )); fi
}
t_eq() {
  (( TESTS++ ))
  if [[ $1 == "$2" ]]; then print -r -- "ok   $3"; else
    print -r -- "FAIL $3"; print -r -- "  expected: [$2]"; print -r -- "  actual:   [$1]"; (( FAILS++ ))
  fi
}

_zui_test_run() { # command, key, delay, key, delay...
  local cmd=$1; shift
  local name=zuitest$RANDOM$RANDOM
  _T_RAW="" _T_OUT="" _T_RC=""
  zpty -b $name "TERM=xterm-256color trap ':' INT; $cmd; print -r -- '__ZRC='\$?" || return 1
  sleep 0.8
  local key delay
  while (( $# >= 2 )); do
    key=$1 delay=$2; shift 2
    zpty -w -n $name "$key"
    sleep $delay
  done
  sleep ${_T_WAIT:-0}
  _T_WAIT=0
  local n=0 chunk
  while zpty -t $name 2>/dev/null && (( n < 80 )); do
    if zpty -r -t $name chunk 2>/dev/null; then _T_RAW+=$chunk; fi
    sleep 0.05; (( n++ ))
  done
  while zpty -r -t $name chunk 2>/dev/null; do _T_RAW+=$chunk; done
  if zpty -t $name 2>/dev/null; then
    zpty -d $name 2>/dev/null
    _T_RC="timeout"
    return 1
  fi
  zpty -d $name 2>/dev/null

  _T_RC=${${_T_RAW##*__ZRC=}%$'\n'*}
  _T_RC=${_T_RC%%[[:space:]]#}
  local result=${_T_RAW##*$'\e[?1049l'}
  _T_OUT=$(print -r -- "$result" | perl -pe 's/\e>//g; s/\e=//g; s/\e\[[0-9;?]*[A-Za-z]//g; s/\e\][^\a]*\a//g; s/\e[()][A-Za-z0-9]//g; s/\r//g; s/\x08//g; s/__ZRC=.*//g' | sed '/^$/d')
  return 0
}

# 1. input editing
_zui_test_run "$ZUI_ROOT/bin/zui input --value foo" 'bar' 0.3 $'\r' 0.4
t_eq "$_T_OUT" "foobar" "input accepts edited value"
t_eq "$_T_RC" 0 "input exits 0"

# 2. choose cursor
_zui_test_run "$ZUI_ROOT/bin/zui choose alpha beta gamma" $'\e[B' 0.3 $'\r' 0.4
t_eq "$_T_OUT" "beta" "choose moves down and returns item"

# 3. multi-select
_zui_test_run "$ZUI_ROOT/bin/zui choose --no-limit alpha beta gamma" ' ' 0.2 $'\e[B' 0.2 ' ' 0.2 $'\r' 0.4
t_eq "$_T_OUT" $'alpha\nbeta' "choose multi-select returns marked items"

# 4/5. confirm
_zui_test_run "$ZUI_ROOT/bin/zui confirm --show-output 'ok?'" $'\r' 0.4
t_eq "$_T_OUT" "true" "confirm default yes"
t_eq "$_T_RC" 0 "confirm yes exits 0"
_zui_test_run "$ZUI_ROOT/bin/zui confirm --show-output 'ok?'" $'\e[C' 0.3 $'\r' 0.4
t_eq "$_T_OUT" "false" "confirm no prints false"
t_eq "$_T_RC" 1 "confirm no exits 1"

# 6. any number of buttons
_zui_test_run "$ZUI_ROOT/bin/zui msgbox --message hi --button 'A=print:A' --button 'B=print:B' --button 'C=print:C'" $'\e[C' 0.2 $'\e[C' 0.2 $'\r' 0.4
t_eq "$_T_OUT" "C" "msgbox third button action"

# 7. checklist limit
_zui_test_run "$ZUI_ROOT/bin/zui checklist --limit 2 a b c" ' ' 0.2 $'\e[B' 0.2 ' ' 0.2 $'\e[B' 0.2 ' ' 0.2 $'\r' 0.4
t_eq "$_T_OUT" $'a\nb' "checklist enforces limit and preserves order"

# 8. form
_zui_test_run "$ZUI_ROOT/bin/zui form --field 'Name=Ada' --field 'City='" $'\t' 0.2 'Paris' 0.3 $'\r' 0.4
t_eq "$_T_OUT" $'Ada\nParis' "form tab and submit"

# 9. menu
_zui_test_run "$ZUI_ROOT/bin/zui menu one two three" $'\e[B' 0.3 $'\r' 0.4
t_eq "$_T_OUT" "two" "menu returns focused item"

# 10. generic dialog adapter
_zui_test_run "$ZUI_ROOT/bin/zui dialog --type inputbox --title Name --message 'Your name' --value Ada" $'\r' 0.4
t_eq "$_T_OUT" "Ada" "generic dialog dispatches to inputbox"

# 11. file browser
mkdir -p "$ZUI_ROOT/scratch/itest"
: > "$ZUI_ROOT/scratch/itest/aa.txt"
_zui_test_run "$ZUI_ROOT/bin/zui file $ZUI_ROOT/scratch/itest" $'\e[B' 0.3 $'\r' 0.4
t_eq "$_T_OUT" "$ZUI_ROOT/scratch/itest/aa.txt" "file returns absolute selection"

_zui_test_run "$ZUI_ROOT/bin/zui file --directory $ZUI_ROOT/scratch/itest" $'\r' 0.4
t_eq "$_T_OUT" "$ZUI_ROOT/scratch/itest" "file --directory selects the current directory"

# 12. pager
printf 'one\ntwo\n' > "$ZUI_ROOT/scratch/itest/page.txt"
_zui_test_run "$ZUI_ROOT/bin/zui pager $ZUI_ROOT/scratch/itest/page.txt" 'q' 0.4
t_eq "$_T_RC" 0 "pager quits with 0"
t_eq "$_T_OUT" "" "pager writes nothing to stdout"

# 12b. run: action executes after the terminal is restored
_zui_test_run "$ZUI_ROOT/bin/zui msgbox --message hi --button 'Later=exit:1' --button 'Run=run:print ran'" $'\e[C' 0.3 $'\r' 0.6
t_eq "$_T_OUT" "ran" "run action output reaches stdout"

# 12c. spin cancels its child
_zui_test_run "$ZUI_ROOT/bin/zui spin --title wait -- sleep 5" $'\e' 0.8
t_eq "$_T_RC" 130 "spin abort exits 130"

# 13. infobox
_zui_test_run "$ZUI_ROOT/bin/zui infobox hi" 'x' 0.4
t_eq "$_T_RC" 0 "infobox dismisses with any key"

# 14. gauge
_zui_test_run "$ZUI_ROOT/bin/zui gauge --percent 50" 'x' 0.4
t_eq "$_T_RC" 0 "gauge closes with any key"

# 15. timeout
_T_WAIT=1.6
_zui_test_run "$ZUI_ROOT/bin/zui confirm --timeout 1s --message wait"
t_eq "$_T_RC" 124 "confirm timeout exits 124"

# 16. abort
_zui_test_run "$ZUI_ROOT/bin/zui input --value x" $'\x03' 0.5
t_eq "$_T_RC" 130 "ctrl-c exits 130"

# 17. UI on the tty, result on a pipe
local tmpfile="$ZUI_ROOT/scratch/itest/result.txt"
_zui_test_run "$ZUI_ROOT/bin/zui input --value piped > $tmpfile" $'\r' 0.5
local piped; IFS= read -r piped < "$tmpfile"
t_eq "$piped" "piped" "result is written to redirected stdout"

# 18. colour is opt-in on a pipe
out=$("$ZUI_ROOT/bin/zui" help choose 2>/dev/null)
t_ok $(( ${out[(I)*$'\e'*]} == 0 )) "help has no ANSI when piped"
out=$(ZUI_FORCE_COLOR=1 "$ZUI_ROOT/bin/zui" help choose 2>/dev/null)
if [[ $out == *$'\e'* ]]; then ok=1; else ok=0; fi
t_ok $ok "help has ANSI with ZUI_FORCE_COLOR"

print
print -r -- "$(( TESTS - FAILS ))/$TESTS tests passed"
(( FAILS == 0 ))

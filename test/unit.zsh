#!/usr/bin/env zsh
# Unit tests for zui's pure helpers.  No terminal is required.
emulate -R zsh
setopt extendedglob
ZUI_ROOT=${0:A:h:h}
export ZUI_ROOT
source "$ZUI_ROOT/lib/zui/core.zsh" || exit 1
_zui_load || exit 1
ZUI_ANSI_PROFILE=none

typeset -gi TESTS=0 FAILS=0
t_ok() {
  (( TESTS++ ))
  if [[ $1 == 1 ]]; then print -r -- "ok   $2"; else print -r -- "FAIL $2"; (( FAILS++ )); fi
}
t_eq() { # actual expected label
  (( TESTS++ ))
  if [[ $1 == "$2" ]]; then print -r -- "ok   $3"; else
    print -r -- "FAIL $3"; print -r -- "  expected: [$2]"; print -r -- "  actual:   [$1]"; (( FAILS++ ))
  fi
}

# --- durations -------------------------------------------------------------
_zui_duration 500ms; t_eq "$REPLY" 1 "duration 500ms"
_zui_duration 10s;   t_eq "$REPLY" 10 "duration 10s"
_zui_duration 2m;    t_eq "$REPLY" 120 "duration 2m"
_zui_duration nope;  t_eq "$?" 1 "duration rejects garbage"

# --- wrapping / padding ----------------------------------------------------
_zui_wrap "hello world again" 7; t_eq "${(j:,:)_ZUI_LINES}" "hello,world,again" "wrap breaks on spaces"
_zui_wrap $'one\ntwo' 10; t_eq "${(j:,:)_ZUI_LINES}" "one,two" "wrap keeps explicit newlines"
_zui_truncate "abcdef" 4; t_eq "$REPLY" "abc…" "truncate adds ellipsis"
_zui_pad "ab" 5 center; t_eq "$REPLY" " ab  " "pad center"
_zui_pad "ab" 5 right; t_eq "$REPLY" "   ab" "pad right"

# --- fuzzy -----------------------------------------------------------------
_zui_fuzzy abc axbxc; t_ok $(( REPLY > 0 )) "fuzzy matches subsequence"
_zui_fuzzy abc xyz;   t_eq "$REPLY" 0 "fuzzy rejects non-match"
_zui_fuzzy '' abc;    t_eq "$REPLY" 0 "fuzzy empty needle matches all"

# --- parser ----------------------------------------------------------------
_zui_parse choose --limit 2 --no-limit alpha beta
t_eq "${_ZUI_OPT[limit]}" 2 "parser int"
t_eq "${_ZUI_OPT[no-limit]}" 1 "parser flag"
t_eq "${_ZUI_ARGS[*]}" "alpha beta" "parser positionals"

_zui_parse choose -l3 -o item
t_eq "${_ZUI_OPT[limit]}" 3 "parser short with attached value"
t_eq "${_ZUI_OPT[ordered]}" 1 "parser combined short flags"

_zui_parse msgbox --button 'A=1' --button 'B=2'
_zui_multi button
t_eq "${#_ZUI_MULTI_ARR}" 2 "parser multi count"
t_eq "${_ZUI_MULTI_ARR[2]}" "B=2" "parser multi value"

_zui_parse choose --no-limit=false x
t_eq "${_ZUI_OPT[no-limit]}" 0 "parser flag=false"

_zui_parse spin -- echo hi
t_eq "${_ZUI_ARGS[*]}" "echo hi" "parser -- passthrough"

# --- csv -------------------------------------------------------------------
_zui_csv_split 'a,"b,c",d' ','
t_eq "${#_ZUI_CSV_FIELDS}" 3 "csv field count"
t_eq "${_ZUI_CSV_FIELDS[2]}" "b,c" "csv quoted comma"
_zui_csv_split 'a,"b""c"' ','
t_eq "${_ZUI_CSV_FIELDS[2]}" 'b"c' "csv escaped quote"

# --- style / borders -------------------------------------------------------
_zui_style_pad 1,2
t_eq "${(j:,:)_ZUI_BOX}" "1,2,1,2" "style padding 2-value"
_zui_border_set ascii
t_eq "$_ZUI_TL$_ZUI_H$_ZUI_TR" "+-+" "ascii border"
_zui_border_set rounded
t_eq "$_ZUI_TL" "╭" "rounded border"

# --- buttons ---------------------------------------------------------------
_zui_btn_parse 'A=print:x' 'B=exit:1' '&C=stay'
t_eq "${_zui_btn_labels[*]}" "A B C" "button labels"
t_eq "${_zui_btn_actions[2]}" "exit:1" "button action"
t_eq "${_zui_btn_accel[3]}" "c" "button accelerator"

# --- editor ----------------------------------------------------------------
_zui_ed_reset "ac"; _zui_ed_pos=2; KEY=b; _zui_ed_handle
t_eq "$_zui_ed_value" "abc" "input insert"
_zui_ed_pos=4; KEY=BACKSPACE; _zui_ed_handle
t_eq "$_zui_ed_value" "ab" "input backspace"
KEY=HOME; _zui_ed_handle; t_eq "$_zui_ed_pos" 1 "input home"
KEY=CTRL_A; _zui_ed_handle; t_eq "$_zui_ed_pos" 1 "input ctrl-a"

_zui_ta_reset $'a\nb'
_zui_ta_row=2; _zui_ta_col=1; KEY=x; _zui_ta_handle
t_eq "${_zui_ta_lines[2]}" "xb" "textarea insert"
KEY=ENTER; _zui_ta_handle
t_eq "${#_zui_ta_lines}" 3 "textarea newline"
KEY=BACKSPACE; _zui_ta_handle
t_eq "${#_zui_ta_lines}" 2 "textarea merge on backspace"

# --- list ------------------------------------------------------------------
_zui_list_items=(alpha beta gamma)
_zui_list_build
_zui_list_cursor=2
_zui_list_value
t_eq "$REPLY" beta "list single value"
_zui_list_multi=1
_zui_list_marks=(); _zui_list_order=()
_zui_list_cursor=1; _zui_list_toggle
_zui_list_cursor=3; _zui_list_toggle
_zui_list_value
t_eq "$REPLY" $'alpha\ngamma' "list multi value"
_zui_list_filter=bet; _zui_list_build
t_eq "${#_zui_list_view}" 1 "list filter"

# --- key decoding (non-escape) --------------------------------------------
_zui_decode_key $'\t'; t_eq "$KEY" TAB "key tab"
_zui_decode_key $'\x7f'; t_eq "$KEY" BACKSPACE "key backspace"
_zui_decode_key $'\x04'; t_eq "$KEY" CTRL_D "key ctrl-d"
_zui_decode_key 'x'; t_eq "$KEY" x "key printable"

# --- command output --------------------------------------------------------
out=$(printf 'name,age\nAda,36\n' | "$ZUI_ROOT/bin/zui" table 2>/dev/null)
t_ok $(( ${out[(I)*Ada*]} > 0 )) "table renders data"

out=$("$ZUI_ROOT/bin/zui" format --template 'Hi {{.Name}}' Name=Ada 2>/dev/null)
t_eq "$out" "Hi Ada" "format substitution"
out=$("$ZUI_ROOT/bin/zui" format --template '{{.A}}' A='x&y' 2>/dev/null)
t_eq "$out" 'x&y' "format escapes ampersands"
"$ZUI_ROOT/bin/zui" format --strict --template '{{.A}}{{.B}}' A=x >/dev/null 2>&1
t_eq "$?" 2 "format strict rejects leftovers"

out=$(printf 'one\n---\ntwo\n' | "$ZUI_ROOT/bin/zui" join --vertical --padding 0 2>/dev/null)
t_eq "${out//$'\n'/,}" "one,two" "join vertical"

out=$("$ZUI_ROOT/bin/zui" log --level info --format json msg 2>/dev/null)
if [[ $out == *'"level":"info"'* ]]; then ok=1; else ok=0; fi
t_ok $ok "log json"
out=$("$ZUI_ROOT/bin/zui" log --level info --min-level error msg 2>/dev/null)
t_eq "$out" "" "log min-level filters"

# --- help / errors ---------------------------------------------------------
out=$("$ZUI_ROOT/bin/zui" help choose 2>/dev/null)
t_ok $(( ${out[(I)*OPTIONS*]} > 0 )) "help has options"
out=$("$ZUI_ROOT/bin/zui" help choose 2>/dev/null)
t_ok $(( ${out[(I)*$'\e'*]} == 0 )) "help is plain when piped"

"$ZUI_ROOT/bin/zui" choose --bogus >/dev/null 2>&1
t_eq "$?" 2 "unknown option exits 2"

print
print -r -- "$(( TESTS - FAILS ))/$TESTS tests passed"
(( FAILS == 0 ))

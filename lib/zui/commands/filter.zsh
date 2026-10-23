# zui filter

_ZUI_OPTDEF_filter=(
  '|height|int|Number of visible rows (0 = fit content)|0'
  '|header|str|Title shown in the dialog title bar|Filter'
  '|placeholder|str|Hint shown while the filter line is empty|'
  '|prompt|str|Prefix drawn before the filter line|> '
  '|value|str|Initial filter text|'
  '|indicator|str|Character used as the selection indicator|•'
  '|selected|multi|Item selected when the dialog opens (repeatable, * = all)|'
  '|selected-prefix|str|Prefix drawn before a selected row|◉ '
  '|unselected-prefix|str|Prefix drawn before an unselected row|○ '
  '|limit|int|Maximum number of items to select (1 = single)|1'
  '|no-limit|flag|Allow any number of selections|0'
  '|ordered|flag|Return selections in the order they were chosen|0'
  '|reverse|flag|Display the list from the bottom up|0'
  '|input-delimiter|str|Delimiter used when reading stdin (default: newline)|'
  '|output-delimiter|str|Delimiter placed between returned values|'
  '|label-delimiter|str|Split items into label and value on this delimiter|'
  '|strip-ansi|flag|Remove ANSI escapes from items read from stdin|0'
  '|show-help|flag|Show the key-hint footer|1'
  '|no-show-help|flag|Hide the key-hint footer|0'
  '|fuzzy|flag|Use fuzzy matching|1'
  '|no-fuzzy|flag|Use substring matching instead of fuzzy matching|0'
  '|fuzzy-sort|flag|Sort filtered rows by fuzzy score|1'
  '|select-if-one|flag|Return immediately when a single item remains|0'
  '|strict|flag|Only accept when at least one item matched|0'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_PADDINGDEF[@]}"
)
_ZUI_CMD_DESC[filter]="Fuzzy-filter a list and pick one line."
_ZUI_CMD_USAGE[filter]="zui filter [flags] [items...]"
_ZUI_CMD_LONG[filter]="Like choose, but the filter line is always visible and the list is re-ranked as you type. Useful for short commands, branches, hosts and files."
_ZUI_KEYMAP[filter]=$'type|Narrow the list\n↑/↓|Move the cursor\nEnter|Return the focused item\nEsc|Clear the filter, or cancel'
_ZUI_EXAMPLES[filter]=$'git branch --format="%(refname:short)" | zui filter --header "Checkout branch"\nprintf \'staging\\nproduction\\ndev\' | zui filter --select-if-one'
_ZUI_NOTES[filter]=$'Matching is fuzzy by default: characters only need to appear in order. With --no-fuzzy, a case-insensitive substring must match.'

_zui_cmd_filter() {
  _zui_dialog_reset
  _zui_items_from_args
  _zui_need_items
  if (( ${_ZUI_OPT[select-if-one]:-0} )) && (( ${#_zui_items} == 1 )); then
    _ZUI_EMIT=1
    _zui_emit_out "${_zui_items[1]}"
    return 0
  fi

  local limit=${_ZUI_OPT[limit]:-1}
  [[ $limit == <-> ]] || limit=1
  local multi=0
  (( ${_ZUI_OPT[no-limit]:-0} )) && { multi=1; limit=0; }
  (( limit > 1 )) && multi=1

  _zui_list_items=("${_zui_items[@]}")
  _zui_list_labels=("${_zui_item_labels[@]}")
  _zui_list_filter=${_ZUI_OPT[value]:-}
  _zui_list_filter_pos=$(( ${#_zui_list_filter} + 1 ))
  _zui_list_show_filter=1
  _zui_list_active_filter=1
  _zui_list_multi=$multi
  _zui_list_limit=$limit
  _zui_list_ordered=${_ZUI_OPT[ordered]:-0}
  _zui_list_fuzzy=$(( ${_ZUI_OPT[fuzzy]:-1} ))
  (( ${_ZUI_OPT[no-fuzzy]:-0} )) && _zui_list_fuzzy=0
  _zui_list_fuzzy_sort=${_ZUI_OPT[fuzzy-sort]:-1}
  _zui_list_reverse=${_ZUI_OPT[reverse]:-0}
  _zui_list_strict=${_ZUI_OPT[strict]:-0}
  _zui_list_placeholder=${_ZUI_OPT[placeholder]:-}
  _zui_list_prompt=${_ZUI_OPT[prompt]:-> }
  _zui_list_sel_char=${_ZUI_OPT[indicator]:-•}
  _zui_list_prefix_mode=1
  _zui_list_sel_prefix=${_ZUI_OPT[selected-prefix]:-◉ }
  _zui_list_unsel_prefix=${_ZUI_OPT[unselected-prefix]:-○ }
  _zui_list_build
  _zui_multi selected
  if (( ${#_ZUI_MULTI_ARR} )) && [[ ${_ZUI_MULTI_ARR[1]} == '*' ]]; then
    local i
    for (( i = 1; i <= ${#_zui_list_items}; i++ )); do _zui_list_marks[$i]=1; _zui_list_order+=($i); done
  elif (( ${#_ZUI_MULTI_ARR} )); then
    _zui_list_mark_initial "${_ZUI_MULTI_ARR[@]}"
  fi

  _zui_dlg[widget]=list
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[header]:-Filter}
  local lh=${_ZUI_OPT[height]:-0}
  (( lh > 0 )) || lh=$(( ${#_zui_items} < 10 ? ${#_zui_items} : 10 ))
  (( lh < 1 )) && lh=1
  _zui_dlg[list_h]=$lh
  _zui_dlg[hints]="type filter  ↑↓ move  Enter select  Esc cancel"
  _zui_build_buttons "Select" "Cancel"

  _zui_dialog_run
  local rc=$?
  _zui_emit_out "$_ZUI_OUT"
  return $rc
}

# zui choose

_ZUI_OPTDEF_choose=(
  'l|limit|int|Maximum number of items to select|1'
  '|no-limit|flag|Allow any number of selections|0'
  'o|ordered|flag|Return selections in the order they were chosen|0'
  '|height|int|Number of visible list rows (0 = fit content)|0'
  '|header|str|Title shown in the dialog title bar|Choose'
  '|cursor|str|Prefix drawn before the focused row|> '
  '|cursor-prefix|str|Prefix drawn before the focused row when selecting many|• '
  '|selected-prefix|str|Prefix drawn before a selected row|✓ '
  '|unselected-prefix|str|Prefix drawn before an unselected row|• '
  '|selected|multi|Item selected when the dialog opens (repeatable, * = all)|'
  '|select-if-one|flag|Return immediately when only one item exists|0'
  '|input-delimiter|str|Delimiter used when reading stdin (default: newline)|'
  '|output-delimiter|str|Delimiter placed between returned values|'
  '|label-delimiter|str|Split items into label and value on this delimiter|'
  '|strip-ansi|flag|Remove ANSI escapes from items read from stdin|0'
  '|show-help|flag|Show the key-hint footer|1'
  '|no-show-help|flag|Hide the key-hint footer|0'
  '|timeout|str|Close with exit 124 after a duration (e.g. 10s)|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|fuzzy|flag|Use fuzzy matching|1'
  '|no-fuzzy|flag|Use substring matching instead of fuzzy matching|0'
  '|fuzzy-sort|flag|Sort filtered rows by fuzzy score|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_PADDINGDEF[@]}"
)
_ZUI_CMD_DESC[choose]="Pick one item, or many with --no-limit/--limit."
_ZUI_CMD_USAGE[choose]="zui choose [flags] [items...]"
_ZUI_CMD_LONG[choose]="A scrollable selection window. Type to filter, use arrows to move, Space to mark items when multiple selection is enabled, and Enter to confirm. Items come from arguments or from stdin, one per line."
_ZUI_KEYMAP[choose]=$'↑/↓, k/j|Move the cursor\nPgUp/PgDn|Jump one screen\nSpace|Toggle the focused item (multi-select)\nEnter|Confirm the selection\nTab|Move focus to the buttons\n/|Focus the filter line\nEsc|Clear the filter, or cancel'
_ZUI_EXAMPLES[choose]=$'printf \'alpha\\nbeta\\ngamma\' | zui choose --header "Pick one"\nzui choose --no-limit --header "Packages" curl git zsh\nzui choose --limit 3 --ordered --selected git < packages.txt\nzui choose --select-if-one --header "Version" < versions.txt'
_ZUI_NOTES[choose]=$'With --limit greater than 1, Space marks items and Enter confirms. Without a mark, Enter accepts the focused item.\nEsc returns 1, Ctrl-C returns 130, and --timeout returns 124.'

_zui_cmd_choose() {
  _zui_dialog_reset
  _zui_items_from_args
  _zui_need_items

  local limit=${_ZUI_OPT[limit]:-1}
  [[ $limit == <-> ]] || limit=1
  local multi=0
  if (( ${_ZUI_OPT[no-limit]:-0} )); then multi=1; limit=0
  elif (( limit > 1 )); then multi=1; fi

  if (( ${_ZUI_OPT[select-if-one]:-0} )) && (( ${#_zui_items} == 1 )); then
    _ZUI_EMIT=1
    _zui_emit_out "${_zui_items[1]}"
    return 0
  fi

  _zui_list_reset
  _zui_list_items=("${_zui_items[@]}")
  _zui_list_labels=("${_zui_item_labels[@]}")
  _zui_list_multi=$multi
  _zui_list_limit=$limit
  _zui_list_ordered=${_ZUI_OPT[ordered]:-0}
  _zui_list_fuzzy=$(( ${_ZUI_OPT[fuzzy]:-1} ))
  (( ${_ZUI_OPT[no-fuzzy]:-0} )) && _zui_list_fuzzy=0
  _zui_list_fuzzy_sort=${_ZUI_OPT[fuzzy-sort]:-1}
  _zui_list_show_filter=0
  _zui_list_cursor_char=${_ZUI_OPT[cursor]:-> }
  _zui_list_cursor_prefix=${_ZUI_OPT[cursor-prefix]:-• }
  _zui_list_sel_prefix=${_ZUI_OPT[selected-prefix]:-✓ }
  _zui_list_unsel_prefix=${_ZUI_OPT[unselected-prefix]:-• }
  _zui_list_prefix_mode=$(( ${+_ZUI_OPT[cursor-prefix]} || ${+_ZUI_OPT[selected-prefix]} || ${+_ZUI_OPT[unselected-prefix]} ))
  _zui_list_build
  _zui_multi selected
  if (( ${#_ZUI_MULTI_ARR} )) && [[ ${_ZUI_MULTI_ARR[1]} == '*' ]]; then
    local i
    for (( i = 1; i <= ${#_zui_list_items}; i++ )); do _zui_list_marks[$i]=1; _zui_list_order+=($i); done
  elif (( ${#_ZUI_MULTI_ARR} )); then
    _zui_list_mark_initial "${_ZUI_MULTI_ARR[@]}"
  fi
  if (( ! multi )) && (( ${#_ZUI_MULTI_ARR} )); then
    _zui_list_select_value "${_ZUI_MULTI_ARR[1]}"
  fi

  _zui_dlg[widget]=list
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[header]:-Choose}
  local lh=${_ZUI_OPT[height]:-0}
  (( lh > 0 )) || lh=$(( ${#_zui_items} < 10 ? ${#_zui_items} : 10 ))
  (( lh < 1 )) && lh=1
  _zui_dlg[list_h]=$lh
  _zui_build_buttons "Select" "Cancel"

  _zui_dialog_run
  local rc=$?
  _zui_emit_out "$_ZUI_OUT"
  return $rc
}

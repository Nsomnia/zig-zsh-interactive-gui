# zui filter

_ZUI_OPTDEF_filter=(
  '|height|int|Number of visible rows (0 = fit content)|0'
  '|header|str|Title shown in the dialog title bar|Filter'
  '|placeholder|str|Hint for the filter line|'
  '|value|str|Initial filter text|'
  '|no-fuzzy|flag|Use substring matching instead of fuzzy matching|0'
  '|select-if-one|flag|Return immediately when a single item remains|0'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
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
    print -r -- "${_zui_items[1]}"
    return 0
  fi

  _zui_list_items=("${_zui_items[@]}")
  _zui_list_filter=${_ZUI_OPT[value]:-}
  _zui_list_filter_pos=$(( ${#_zui_list_filter} + 1 ))
  _zui_list_show_filter=1
  _zui_list_active_filter=1
  _zui_list_multi=0
  _zui_list_fuzzy=$(( 1 - ${_ZUI_OPT[no-fuzzy]:-0} ))
  _zui_list_build

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
  _zui_emit "$_ZUI_OUT"
  return $rc
}

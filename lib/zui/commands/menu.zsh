# zui menu

_ZUI_OPTDEF_menu=(
  '|title|str|Title shown in the title bar|Menu'
  '|message|str|Text shown above the list|'
  '|selected|str|Item to place the cursor on|'
  '|height|int|Number of visible rows (0 = fit content)|0'
  '|cursor|str|Prefix drawn before the focused row|> '
  '|button|multi|Button in Label=action form|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|default-button|int|Button triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[menu]="Pick one item from a list inside a dialog with buttons."
_ZUI_CMD_USAGE[menu]="zui menu [flags] [items...]"
_ZUI_CMD_LONG[menu]="A single-selection list with a message area and a button row. Items come from arguments or stdin. Type to filter, arrows to move, Enter to accept."
_ZUI_KEYMAP[menu]=$'↑/↓|Move the cursor\nEnter|Accept the focused item\nTab|Focus the buttons\ntype|Filter items\nEsc|Clear the filter, or cancel'
_ZUI_EXAMPLES[menu]=$'zui menu --title "Restart" --message "Which service?" api web worker\nprintf \'small\\nmedium\\nlarge\' | zui menu --title "Size"\nzui menu --button "Open=accept" --button "Copy=print:copied" --button "Cancel=cancel" one two'
_ZUI_NOTES[menu]=$'A custom accept button prints the focused item. print: and run: actions behave as in msgbox.'

_zui_cmd_menu() {
  _zui_dialog_reset
  _zui_items_from_args
  _zui_need_items
  _zui_list_items=("${_zui_items[@]}")
  _zui_list_multi=0
  _zui_list_build
  [[ -n ${_ZUI_OPT[selected]:-} ]] && _zui_list_select_value "${_ZUI_OPT[selected]}"
  _zui_list_cursor_char=${_ZUI_OPT[cursor]:-> }

  _zui_dlg[widget]=list
  _zui_dlg[message]=${_ZUI_OPT[message]:-}
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[title]:-Menu}
  local lh=${_ZUI_OPT[height]:-0}
  (( lh > 0 )) || lh=$(( ${#_zui_items} < 10 ? ${#_zui_items} : 10 ))
  (( lh < 1 )) && lh=1
  _zui_dlg[list_h]=$lh
  _zui_build_buttons Select Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

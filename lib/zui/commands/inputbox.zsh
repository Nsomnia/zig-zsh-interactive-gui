# zui inputbox

_ZUI_OPTDEF_inputbox=(
  '|title|str|Title shown in the title bar|Input'
  '|message|str|Label or prompt above the field|'
  '|value|str|Initial value|'
  '|placeholder|str|Hint shown while the field is empty|'
  '|prompt|str|Short prefix inside the field row|'
  '|password|flag|Mask the value|0'
  '|char-limit|int|Maximum characters (0 = unlimited)|0'
  '|button|multi|Button in Label=action form; repeat for more buttons|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|default-button|int|Button triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[inputbox]="A framed text-input dialog with buttons."
_ZUI_CMD_USAGE[inputbox]="zui inputbox [flags]"
_ZUI_CMD_LONG[inputbox]="Combines a message and a single-line editor in one dialog. By default the OK button accepts the value and prints it; custom buttons can print something else or run a command."
_ZUI_KEYMAP[inputbox]=$'←/→|Move the caret\nHome/End|Start or end\nEnter|Accept the value\nTab|Focus the buttons\nEsc|Cancel'
_ZUI_EXAMPLES[inputbox]=$'zui inputbox --title "Rename" --message "New name:" --value old.txt\nzui inputbox --password --title "Unlock" --message "Passphrase:"\nzui inputbox --button "Save=accept" --button "Clear=print:" --button "Cancel=cancel" "Value:"'
_ZUI_NOTES[inputbox]=$'The accepted value is printed to stdout after the UI closes.\nA custom button using print: emits its own value instead.'

_zui_cmd_inputbox() {
  _zui_dialog_reset
  local limit=${_ZUI_OPT[char-limit]:-0}
  [[ $limit == <-> ]] || limit=0
  _zui_ed_reset "${_ZUI_OPT[value]:-}" $limit
  _zui_ed_mask=${_ZUI_OPT[password]:-0}
  _zui_ed_placeholder=${_ZUI_OPT[placeholder]:-}

  _zui_dlg[widget]=input
  _zui_dlg[message]=${_ZUI_OPT[message]:-}
  _zui_dlg[icon]=question
  _zui_dialog_common
  _zui_dlg[title]=${_ZUI_OPT[title]:-Input}
  _zui_dlg[prompt]=${_ZUI_OPT[prompt]:-}
  _zui_build_buttons OK Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

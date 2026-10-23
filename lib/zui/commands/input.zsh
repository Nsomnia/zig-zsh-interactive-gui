# zui input

_ZUI_OPTDEF_input=(
  '|value|str|Initial value|'
  '|placeholder|str|Hint shown while the field is empty|'
  '|prompt|str|Short prefix drawn before the field|'
  '|password|flag|Mask the value with bullets|0'
  '|char-limit|int|Maximum number of characters (0 = unlimited)|0'
  '|header|str|Title shown in the dialog title bar|Input'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|timeout|str|Close with exit 124 after a duration|'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[input]="Read a single line of text in a framed input dialog."
_ZUI_CMD_USAGE[input]="zui input [flags]"
_ZUI_CMD_LONG[input]="A single-line editor with a block caret, horizontal scrolling, Home/End, word movement and optional password masking. Enter confirms, Esc cancels."
_ZUI_KEYMAP[input]=$'←/→|Move the caret\nHome/End|Jump to the start or end\nCtrl-A/Ctrl-E|Start or end\nCtrl-U/Ctrl-K|Delete before or after the caret\nCtrl-W, Alt-B/F|Delete or move by word\nEnter|Confirm\nEsc|Cancel'
_ZUI_EXAMPLES[input]=$'name=$(zui input --header "Your name" --placeholder "Ada Lovelace")\nzui input --password --header "Password"\nzui input --value main --prompt "branch:" --header "New branch"'
_ZUI_NOTES[input]=$'The value is printed on stdout after the UI is restored, so it is safe to capture with $(...).'

_zui_cmd_input() {
  _zui_dialog_reset
  local limit=${_ZUI_OPT[char-limit]:-0}
  [[ $limit == <-> ]] || limit=0
  _zui_ed_reset "${_ZUI_OPT[value]:-}" $limit
  _zui_ed_mask=${_ZUI_OPT[password]:-0}
  _zui_ed_placeholder=${_ZUI_OPT[placeholder]:-}

  _zui_dlg[widget]=input
  _zui_dialog_common
  _zui_dlg[title]=${_ZUI_OPT[header]:-Input}
  _zui_dlg[prompt]=${_ZUI_OPT[prompt]:-}
  _zui_dlg[message]=""
  _zui_build_buttons OK Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

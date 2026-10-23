# zui write

_ZUI_OPTDEF_write=(
  '|value|str|Initial text (use \\n for newlines)|'
  '|placeholder|str|Hint shown while the buffer is empty|'
  '|header|str|Title shown in the dialog title bar|Write'
  '|char-limit|int|Maximum number of characters (0 = unlimited)|0'
  '|show-line-numbers|flag|Show a line-number gutter|0'
  '|height|int|Text area height in rows|8'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|timeout|str|Close with exit 124 after a duration|'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[write]="Compose multi-line text in a scrollable text area."
_ZUI_CMD_USAGE[write]="zui write [flags]"
_ZUI_CMD_LONG[write]="A multi-line editor with wrapping-free horizontal scrolling, line numbers and an optional character limit. Ctrl-D or the Done button submits, Esc cancels."
_ZUI_KEYMAP[write]=$'Arrows|Move the caret\nHome/End|Start or end of line\nEnter|New line\nTab|Insert two spaces\nBackspace/Delete|Delete characters\nCtrl-D|Submit\nEsc|Cancel'
_ZUI_EXAMPLES[write]=$'body=$(zui write --header "Commit message" --show-line-numbers)\nzui write --placeholder "Type notes..." --height 12 > notes.txt'
_ZUI_NOTES[write]=$'For scripted newlines in --value use a literal $\\n in zsh: --value "one\\ntwo".\nThe final text is printed after the terminal is restored.'

_zui_cmd_write() {
  _zui_dialog_reset
  local limit=${_ZUI_OPT[char-limit]:-0}
  [[ $limit == <-> ]] || limit=0
  local val=${_ZUI_OPT[value]:-}
  val=${val//\\n/$'\n'}
  _zui_ta_reset "$val" $limit
  _zui_ta_placeholder=${_ZUI_OPT[placeholder]:-}
  _zui_ta_numbers=${_ZUI_OPT[show-line-numbers]:-0}

  _zui_dlg[widget]=textarea
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[header]:-Write}
  local th=${_ZUI_OPT[height]:-8}
  [[ $th == <-> ]] || th=8
  (( th < 2 )) && th=2
  _zui_dlg[ta_h]=$th
  _zui_build_buttons Done Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

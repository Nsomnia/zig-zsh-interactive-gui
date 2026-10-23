# zui infobox

_ZUI_OPTDEF_infobox=(
  '|title|str|Title shown in the title bar|Info'
  '|message|str|Body text (arguments are used when omitted)|'
  '|icon|str|Icon: info, success, warn, error, question|info'
  '|timeout|str|Close automatically after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_DIALOGDEF[@]}"
)

_ZUI_CMD_DESC[infobox]="Show a message with no buttons; any key or a timeout dismisses it."
_ZUI_CMD_USAGE[infobox]="zui infobox [flags] [message]"
_ZUI_CMD_LONG[infobox]="Useful for transient notifications. Esc never fails; the command exits 0 when dismissed and 124 when its timeout fires."
_ZUI_KEYMAP[infobox]=$'any key|Dismiss\nEsc|Dismiss'
_ZUI_EXAMPLES[infobox]=$'zui infobox "Deployment complete."\nzui infobox --icon success --timeout 2s "All tests passed."\nzui infobox --icon warn --title "Warning" "Certificate expires tomorrow."'
_ZUI_NOTES[infobox]=$'There are no buttons; use msgbox when the user must choose an action.\nA timeout returns 124, so scripts can distinguish automatic dismissal.'

_zui_cmd_infobox() {
  _zui_dialog_reset
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then msg="${(j: :)_ZUI_ARGS}"; fi
  [[ -z $msg ]] && { _zui_err "no message"; return 2; }

  _zui_dlg[widget]=text
  _zui_dlg[message]=$msg
  _zui_dlg[icon]=${_ZUI_OPT[icon]:-info}
  _zui_dlg[title]=${_ZUI_OPT[title]:-Info}
  _zui_dlg[hints]="press any key to dismiss"
  _zui_dlg[esc_code]=0
  _zui_dlg[no_cancel]=0
  _zui_dialog_common
  _zui_dlg[message]=$msg
  _zui_dlg_buttons=()
  _zui_dialog_run
  return $?
}

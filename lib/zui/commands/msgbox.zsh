# zui msgbox

_ZUI_OPTDEF_msgbox=(
  '|title|str|Title shown in the title bar|Message'
  '|message|str|Body text (arguments are used when omitted)|'
  '|icon|str|Icon: info, success, warn, error, question|info'
  '|button|multi|Button in Label=action form; repeat for more buttons|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|default-button|int|Button focused and triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[msgbox]="Show a message box with any number of action buttons."
_ZUI_CMD_USAGE[msgbox]="zui msgbox [flags] [message]"
_ZUI_CMD_LONG[msgbox]="The core dialog(1)-style window: a framed message, an icon, and a row of buttons. Buttons are Label=action pairs and can run shell commands, print a value, or exit with a chosen status. Without --button, a single OK button is shown."
_ZUI_KEYMAP[msgbox]=$'←/→, Tab|Move between buttons\nEnter|Run the focused button\nAlt-<letter>|Run an &accelerator button\nEsc|Cancel (exit 1)'
_ZUI_EXAMPLES[msgbox]=$'zui msgbox "Build finished."\nzui msgbox --icon warn --message "Disk almost full." --button "OK=exit:0" --button "Details=run:df -h"\nzui msgbox --title "Update" --button "Later=exit:1" --button "Install=run:brew upgrade" "Install updates now?"\nzui msgbox --timeout 5s "This closes on its own."'
_ZUI_NOTES[msgbox]=$'Any number of buttons is allowed; they wrap onto additional rows when needed.\nActions: exit:N, accept, cancel, print:TEXT, run:COMMAND (run executes after the terminal is restored).'

_zui_cmd_msgbox() {
  _zui_dialog_reset
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then msg="${(j: :)_ZUI_ARGS}"; fi
  [[ -z $msg ]] && { _zui_err "no message (pass text or --message)"; return 2; }

  _zui_dlg[widget]=text
  _zui_dlg[message]=$msg
  _zui_dlg[icon]=${_ZUI_OPT[icon]:-info}
  _zui_dialog_common
  _zui_dlg[title]=${_ZUI_OPT[title]:-Message}
  if [[ -n ${_ZUI_OPT[button]:-} ]]; then
    _zui_multi button
    _zui_dlg_buttons=("${_ZUI_MULTI_ARR[@]}")
  else
    _zui_dlg_buttons=("OK=exit:0")
  fi

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

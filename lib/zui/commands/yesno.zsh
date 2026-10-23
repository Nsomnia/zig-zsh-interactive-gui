# zui yesno

_ZUI_OPTDEF_yesno=(
  '|title|str|Title shown in the title bar|Question'
  '|message|str|Question text (arguments are used when omitted)|'
  '|affirmative|str|Label for the yes button|Yes'
  '|negative|str|Label for the no button|No'
  '|default-answer|str|Default answer: yes or no|yes'
  '|show-output|flag|Print true or false|0'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[yesno]="A modal yes/no dialog with named affirmative and negative buttons."
_ZUI_CMD_USAGE[yesno]="zui yesno [flags] [question]"
_ZUI_CMD_LONG[yesno]="The dialog(1) flavour of confirm: a framed question with two buttons. Exit status is 0 for yes, 1 for no, 130 for abort and 124 for timeout."
_ZUI_KEYMAP[yesno]=$'←/→|Move between buttons\nEnter|Choose the focused button\nEsc|Cancel'
_ZUI_EXAMPLES[yesno]=$'zui yesno "Restart the service?"\nzui yesno --affirmative Overwrite --negative Skip --default-answer no "Overwrite config?"\nzui yesno --show-output "Continue?"'
_ZUI_NOTES[yesno]=$'--show-output prints true or false. Esc prints nothing and exits 1.'

_zui_cmd_yesno() {
  _zui_dialog_reset
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then msg="${(j: :)_ZUI_ARGS}"; fi
  [[ -z $msg ]] && msg="Continue?"

  _zui_dlg[widget]=text
  _zui_dlg[message]=$msg
  _zui_dlg[icon]=question
  _zui_dialog_common
  _zui_dlg[title]=${_ZUI_OPT[title]:-Question}
  _zui_dlg_buttons=("${_ZUI_OPT[affirmative]:-Yes}=exit:0" "${_ZUI_OPT[negative]:-No}=exit:1")
  case ${(L)${_ZUI_OPT[default-answer]:-yes}} in
    (no|n|false|0) _zui_dlg[default]=2 ;;
    (*)            _zui_dlg[default]=1 ;;
  esac

  _zui_dialog_run
  local rc=$?
  if (( ${_ZUI_OPT[show-output]:-0} )) && [[ -n $_ZUI_ACTION ]]; then
    if (( rc == 0 )); then print -r -- true; else print -r -- false; fi
  fi
  return $rc
}

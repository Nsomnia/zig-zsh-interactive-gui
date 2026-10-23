# zui confirm

_ZUI_OPTDEF_confirm=(
  '|affirmative|str|Label for the yes button|Yes'
  '|negative|str|Label for the no button|No'
  '|default|str|Default answer: yes or no|yes'
  '|show-output|flag|Print true or false|0'
  '|message|str|Question text (arguments are used when omitted)|'
  '|header|str|Title shown in the dialog title bar|Confirm'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_DIALOGDEF[@]}"
  "${_ZUI_PADDINGDEF[@]}"
)
_ZUI_CMD_DESC[confirm]="Ask a yes/no question with two focused buttons."
_ZUI_CMD_USAGE[confirm]="zui confirm [flags] [question]"
_ZUI_CMD_LONG[confirm]="A two-button confirmation dialog. Enter triggers the default answer, arrows or Tab move between buttons, and Esc cancels. By default nothing is printed: use the exit status (0 yes, 1 no, 130 aborted, 124 timeout)."
_ZUI_KEYMAP[confirm]=$'←/→|Move between the buttons\nEnter|Choose the focused button\nTab|Cycle focus\nEsc|Cancel (exit 1)'
_ZUI_EXAMPLES[confirm]=$'zui confirm "Deploy to production?" && ./deploy.sh\nzui confirm --default no --affirmative Discard --negative Keep "Discard 3 files?"\nzui confirm --show-output "Enable telemetry?"'
_ZUI_NOTES[confirm]=$'--show-output prints true for Yes and false for No. Esc and Ctrl-C print nothing.'

_zui_cmd_confirm() {
  _zui_dialog_reset
  local msg=${_ZUI_OPT[message]:-}
  if [[ -z $msg ]] && (( ${#_ZUI_ARGS} )); then msg="${(j: :)_ZUI_ARGS}"; fi
  [[ -z $msg ]] && msg="Are you sure?"

  local yes=${_ZUI_OPT[affirmative]:-Yes}
  local no=${_ZUI_OPT[negative]:-No}
  [[ -n ${_ZUI_OPT[ok-label]:-} ]] && yes=${_ZUI_OPT[ok-label]}
  [[ -n ${_ZUI_OPT[cancel-label]:-} ]] && no=${_ZUI_OPT[cancel-label]}
  [[ -n ${_ZUI_OPT[yes-label]:-} ]] && yes=${_ZUI_OPT[yes-label]}
  [[ -n ${_ZUI_OPT[no-label]:-} ]] && no=${_ZUI_OPT[no-label]}
  local def=${(L)${_ZUI_OPT[default]:-yes}}

  _zui_dlg[widget]=text
  _zui_dlg[title]=${_ZUI_OPT[header]:-Confirm}
  _zui_dlg[message]=$msg
  _zui_dlg[icon]=question
  _zui_dialog_common
  _zui_dlg[buttons]=""
  _zui_dlg_buttons=("$yes=exit:0")
  (( ${_ZUI_OPT[no-cancel]:-0} )) || _zui_dlg_buttons+=("$no=exit:1")
  case $def in
    (no|n|false|0) _zui_dlg[default]=2 ;;
    (*)            _zui_dlg[default]=1 ;;
  esac
  (( ${_ZUI_OPT[defaultno]:-0} )) && _zui_dlg[default]=2

  _zui_dialog_run
  local rc=$?
  if (( ${_ZUI_OPT[show-output]:-0} )) && [[ -n $_ZUI_ACTION ]]; then
    _ZUI_EMIT=1
    if (( rc == 0 )); then _zui_emit_out true; else _zui_emit_out false; fi
  fi
  return $rc
}

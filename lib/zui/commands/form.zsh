# zui form

_ZUI_OPTDEF_form=(
  '|title|str|Title shown in the title bar|Form'
  '|message|str|Text shown above the fields|'
  '|field|multi|Field in Label=initial form; repeat for more fields|'
  '|secret|multi|Label of a field whose value is masked|'
  '|button|multi|Button in Label=action form|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|default-button|int|Button triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[form]="Fill several labelled fields, then confirm with a button."
_ZUI_CMD_USAGE[form]="zui form --field 'Label=value' [--field ...] [flags]"
_ZUI_CMD_LONG[form]="A compact form dialog. Tab and Shift-Tab move between fields; Enter activates the default button. Each field is declared as Label=initial and values are printed one per line in field order."
_ZUI_KEYMAP[form]=$'Tab/Shift-Tab|Next or previous field\n↑/↓|Previous or next field\nEnter|Confirm\n←/→|Move the caret\nEsc|Cancel'
_ZUI_EXAMPLES[form]=$'zui form --title "New user" --field "Name=" --field "Email="\nzui form --field "User=ada" --field "Password=" --secret Password --button "Create=accept" --button "Cancel=cancel"\nzui form --field "Host=localhost" --field "Port=8080" --field Width=80'
_ZUI_NOTES[form]=$'Fields without an = are treated as labels with empty values.\nValues are printed in declaration order, one per line; use read or an array to capture them.'

_zui_cmd_form() {
  _zui_dialog_reset
  _zui_multi field
  local -a fields=("${_ZUI_MULTI_ARR[@]}")
  if (( ${#fields} == 0 )) && (( ${#_ZUI_ARGS} )); then fields=("${_ZUI_ARGS[@]}"); fi
  if (( ${#fields} == 0 )); then
    _zui_err "no fields; use --field 'Label=value'"
    return 2
  fi

  _zui_form_labels=(); _zui_form_values=(); _zui_form_mask=()
  local f label val
  for f in "${fields[@]}"; do
    if [[ $f == *=* ]]; then
      label=${f%%=*}; val=${f#*=}
    else
      label=$f; val=""
    fi
    [[ -z $label ]] && label="Field"
    _zui_form_labels+=("$label")
    _zui_form_values+=("$val")
    _zui_form_mask+=(0)
  done

  _zui_multi secret
  local s i
  for s in "${_ZUI_MULTI_ARR[@]}"; do
    for (( i = 1; i <= ${#_zui_form_labels}; i++ )); do
      [[ ${_zui_form_labels[i]} == "$s" ]] && _zui_form_mask[i]=1
    done
  done

  _zui_form_focus=1; _zui_form_scroll=0
  _zui_form_load

  _zui_dlg[widget]=form
  _zui_dlg[message]=${_ZUI_OPT[message]:-}
  _zui_dialog_common
  _zui_dlg[title]=${_ZUI_OPT[title]:-Form}
  _zui_build_buttons Submit Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

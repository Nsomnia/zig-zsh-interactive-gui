# zui checklist

_ZUI_OPTDEF_checklist=(
  '|title|str|Title shown in the title bar|Checklist'
  '|message|str|Text shown above the list|'
  '|selected|multi|Items checked when the dialog opens|'
  '|limit|int|Maximum number of checked items (0 = unlimited)|0'
  '|no-limit|flag|Allow any number of checked items|0'
  '|ordered|flag|Return items in the order they were checked|0'
  '|height|int|Number of visible rows (0 = fit content)|0'
  '|button|multi|Button in Label=action form|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|default-button|int|Button triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
)

_ZUI_CMD_DESC[checklist]="Mark any number of items and confirm with a button."
_ZUI_CMD_USAGE[checklist]="zui checklist [flags] [items...]"
_ZUI_CMD_LONG[checklist]="A multi-select list. Space toggles the focused item; Enter activates the default button (usually OK). The accepted selection is printed one item per line."
_ZUI_KEYMAP[checklist]=$'↑/↓|Move the cursor\nSpace|Check or uncheck the focused item\nEnter|Confirm\nTab|Focus the buttons\ntype|Filter items\nEsc|Clear the filter, or cancel'
_ZUI_EXAMPLES[checklist]=$'selected=$(zui checklist --title "Features" ui docs tests)\nprintf \'a\\nb\\nc\' | zui checklist --limit 2 --ordered\nzui checklist --selected ui --selected docs --title "Keep" ui docs tests'
_ZUI_NOTES[checklist]=$'With no items marked, OK accepts the focused item.\n--ordered prints in selection order; otherwise list order is used.'

_zui_cmd_checklist() {
  _zui_dialog_reset
  _zui_items_from_args
  _zui_need_items
  _zui_list_items=("${_zui_items[@]}")
  _zui_list_multi=1
  _zui_list_limit=${_ZUI_OPT[limit]:-0}
  [[ ${_zui_list_limit} == <-> ]] || _zui_list_limit=0
  (( ${_ZUI_OPT[no-limit]:-0} )) && _zui_list_limit=0
  _zui_list_ordered=${_ZUI_OPT[ordered]:-0}
  _zui_list_build
  _zui_multi selected
  (( ${#_ZUI_MULTI_ARR} )) && _zui_list_mark_initial "${_ZUI_MULTI_ARR[@]}"

  _zui_dlg[widget]=checklist
  _zui_dlg[message]=${_ZUI_OPT[message]:-}
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[title]:-Checklist}
  local lh=${_ZUI_OPT[height]:-0}
  (( lh > 0 )) || lh=$(( ${#_zui_items} < 10 ? ${#_zui_items} : 10 ))
  (( lh < 1 )) && lh=1
  _zui_dlg[list_h]=$lh
  _zui_build_buttons OK Cancel

  _zui_dialog_run
  local rc=$?
  _zui_emit "$_ZUI_OUT"
  return $rc
}

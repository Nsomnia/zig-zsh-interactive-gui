# zui dialog: one flag-driven entry point for every dialog type.

_ZUI_OPTDEF_dialog=(
  '|type|str|Dialog type: msgbox, yesno, inputbox, menu, checklist, form, gauge, infobox|msgbox'
  '|title|str|Title shown in the title bar|'
  '|message|str|Body text or question|'
  '|icon|str|Icon: info, success, warn, error, question|info'
  '|button|multi|Button in Label=action form; repeat for more buttons|'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|height|int|Dialog height in rows (0 = automatic)|0'
  '|default-button|int|Button triggered by Enter|1'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  '|value|str|Initial value for inputbox|'
  '|placeholder|str|Placeholder for inputbox|'
  '|prompt|str|Prompt prefix for inputbox|'
  '|password|flag|Mask the inputbox value|0'
  '|char-limit|int|Inputbox character limit (0 = unlimited)|0'
  '|selected|multi|Initially selected item(s) or menu cursor|'
  '|limit|int|Checklist selection limit (0 = unlimited)|0'
  '|no-limit|flag|Allow unlimited checklist selections|0'
  '|ordered|flag|Return checklist items in selection order|0'
  '|field|multi|Form field in Label=value form|'
  '|secret|multi|Form field label to mask|'
  '|percent|int|Gauge percentage|0'
  '|label|str|Gauge label under the bar|'
  '|affirmative|str|Yes button label for yesno|Yes'
  '|negative|str|No button label for yesno|No'
  '|default-answer|str|Default answer for yesno: yes or no|yes'
  '|show-output|flag|Print true/false for yesno|0'
  '|print|flag|Print a gauge instead of opening a dialog|0'
  "${_ZUI_DIALOGDEF[@]}"
)

_ZUI_CMD_DESC[dialog]="Open any dialog type from one flag-driven command."
_ZUI_CMD_USAGE[dialog]="zui dialog --type TYPE [flags] [items...]"
_ZUI_CMD_LONG[dialog]="A programmatic front end for msgbox, yesno, inputbox, menu, checklist, form, gauge and infobox. Each type is forwarded to its dedicated command, so the flags and outputs are identical. Use the dedicated commands for discoverable per-type help."
_ZUI_EXAMPLES[dialog]=$'zui dialog --type msgbox --message "Saved."\nzui dialog --type yesno --message "Ship it?" --show-output\nzui dialog --type inputbox --title "Name" --message "Your name:"\nzui dialog --type checklist --selected docs "ui docs tests"\nzui dialog --type form --field "Name=" --field "Email="\nzui dialog --type gauge --percent 60 --label "Uploading"'
_ZUI_NOTES[dialog]=$'Types are validated before dispatch. Unknown types exit 2.\nRun zui help <type> for the complete option list of a dialog.'

_zui_cmd_dialog() {
  _zui_dialog_reset
  local type=${(L)${_ZUI_OPT[type]:-msgbox}}
  case $type in
    (messagebox) type=msgbox ;;
    (yes/no|confirm) type=yesno ;;
    (input) type=inputbox ;;
    (select) type=menu ;;
  esac
  case $type in
    (msgbox|yesno|inputbox|menu|checklist|form|gauge|infobox) ;;
    (*) _zui_err "unknown dialog type '$type'"; return 2 ;;
  esac

  local -a a=()
  [[ -n ${_ZUI_OPT[title]:-} ]] && a+=(--title "${_ZUI_OPT[title]}")
  [[ -n ${_ZUI_OPT[message]:-} ]] && a+=(--message "${_ZUI_OPT[message]}")
  [[ -n ${_ZUI_OPT[width]:-} ]] && a+=(--width "${_ZUI_OPT[width]}")
  [[ -n ${_ZUI_OPT[border]:-} ]] && a+=(--border "${_ZUI_OPT[border]}")
  [[ -n ${_ZUI_OPT[timeout]:-} ]] && a+=(--timeout "${_ZUI_OPT[timeout]}")
  [[ $type != yesno && -n ${_ZUI_OPT[height]:-} ]] && a+=(--height "${_ZUI_OPT[height]}")

  case $type in
    (msgbox|infobox)
      [[ -n ${_ZUI_OPT[icon]:-} ]] && a+=(--icon "${_ZUI_OPT[icon]}") ;;
  esac
  case $type in
    (msgbox|inputbox|menu|checklist|form)
      [[ -n ${_ZUI_OPT[default-button]:-} ]] && a+=(--default-button "${_ZUI_OPT[default-button]}")
      local b
      for b in "${(@f)_ZUI_OPT[button]}"; do [[ -n $b ]] && a+=(--button "$b"); done ;;
  esac

  case $type in
    (yesno)
      a+=(--affirmative "${_ZUI_OPT[affirmative]:-Yes}" --negative "${_ZUI_OPT[negative]:-No}")
      a+=(--default-answer "${_ZUI_OPT[default-answer]:-yes}")
      (( ${_ZUI_OPT[show-output]:-0} )) && a+=(--show-output) ;;
    (inputbox)
      [[ -n ${_ZUI_OPT[value]:-} ]] && a+=(--value "${_ZUI_OPT[value]}")
      [[ -n ${_ZUI_OPT[placeholder]:-} ]] && a+=(--placeholder "${_ZUI_OPT[placeholder]}")
      [[ -n ${_ZUI_OPT[prompt]:-} ]] && a+=(--prompt "${_ZUI_OPT[prompt]}")
      (( ${_ZUI_OPT[password]:-0} )) && a+=(--password)
      [[ -n ${_ZUI_OPT[char-limit]:-} ]] && a+=(--char-limit "${_ZUI_OPT[char-limit]}") ;;
    (checklist)
      [[ -n ${_ZUI_OPT[limit]:-} ]] && a+=(--limit "${_ZUI_OPT[limit]}")
      (( ${_ZUI_OPT[no-limit]:-0} )) && a+=(--no-limit)
      (( ${_ZUI_OPT[ordered]:-0} )) && a+=(--ordered) ;;
    (form)
      local f
      for f in "${(@f)_ZUI_OPT[field]}"; do [[ -n $f ]] && a+=(--field "$f"); done
      for f in "${(@f)_ZUI_OPT[secret]}"; do [[ -n $f ]] && a+=(--secret "$f"); done ;;
    (gauge)
      a+=(--percent "${_ZUI_OPT[percent]:-0}")
      [[ -n ${_ZUI_OPT[label]:-} ]] && a+=(--message "${_ZUI_OPT[label]}")
      (( ${_ZUI_OPT[print]:-0} )) && a+=(--print) ;;
  esac

  # selected is meaningful for menu (single) and checklist (many).
  if [[ $type == (menu|checklist) && -n ${_ZUI_OPT[selected]:-} ]]; then
    local s
    for s in "${(@f)_ZUI_OPT[selected]}"; do a+=(--selected "$s"); done
  fi

  # Forward every dialog(1)-common option that differs from its default.
  local d k val
  for d in "${_ZUI_DIALOGDEF[@]}"; do
    IFS='|' read -r _ k _ <<< "$d"
    [[ -n $k ]] || continue
    val=${_ZUI_OPT[$k]:-}
    [[ -n $val && $val != ${_ZUI_DEFAULTS[$k]:-} ]] || continue
    if [[ ${_ZUI_TYPES[$k]} == flag ]]; then a+=(--$k); else a+=(--$k "$val"); fi
  done

  _zui_main "$type" "${a[@]}" "${_ZUI_ARGS[@]}"
}

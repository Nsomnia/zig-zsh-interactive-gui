# Public framework entry point.
#
#   source /path/to/zui/lib/zui.zsh
#   zui::begin
#   zui::title "Deploy"
#   zui::message "Ship release 2.0?"
#   zui::button "Deploy" accept
#   zui::button "Cancel" cancel
#   zui::run && ./deploy.sh
#
# After zui::run, ZUI_OUT holds the accepted value (if any) and ZUI_CODE the
# exit status.  The CLI commands are thin wrappers around this API.

ZUI_ROOT="${ZUI_ROOT:-${0:A:h:h}}"
export ZUI_ROOT
source "$ZUI_ROOT/lib/zui/core.zsh"
_zui_load

zui::init() {
  _zui_load
  [[ -z $ZUI_ANSI_PROFILE ]] && ZUI_ANSI_PROFILE=$(_zui_ansi_profile)
}

zui::begin() {
  _zui_dialog_reset
  _zui_dlg_buttons=()
  _zui_ed_reset ""
  _zui_ta_reset ""
  _zui_form_labels=(); _zui_form_values=(); _zui_form_mask=()
  _zui_form_focus=1; _zui_form_scroll=0; _zui_form_limit=0
  _zui_ed_cursor_mode=blink
  _zui_ta_prompt=""; _zui_ta_cursor_mode=blink; _zui_ta_max_lines=0; _zui_ta_highlight=0
  _zui_list_items=()
  _zui_list_reset
  _zui_list_multi=0; _zui_list_limit=0; _zui_list_ordered=0
}

zui::title()   { _zui_dlg[title]=${1-} }
zui::message() { _zui_dlg[message]=${1-} }
zui::icon()    { _zui_dlg[icon]=${1-} }
zui::width()   { _zui_dlg[width]=${1:-0} }
zui::height()  { _zui_dlg[height]=${1:-0} }
zui::border()  { _zui_dlg[border]=${1:-auto} }
zui::prompt()  { _zui_dlg[prompt]=${1-} }
zui::hints()   { _zui_dlg[hints]=${1-} }

zui::timeout() { # seconds or 500ms
  local v=${1-}
  [[ -z $v ]] && return 0
  if _zui_duration "$v"; then _zui_dlg[timeout]=$REPLY; else _zui_err "bad duration '$v'"; fi
}

zui::button() { # label [action]
  local label=${1:?label required} action=${2:-exit:0}
  _zui_dlg_buttons+=("$label=$action")
}

zui::widget() {
  case $1 in
    (text|input|textarea|list|checklist|form|gauge) _zui_dlg[widget]=$1 ;;
    (*) _zui_err "unknown widget '$1'"; return 2 ;;
  esac
}

zui::items() {
  _zui_list_items=("$@")
  _zui_list_reset
}

zui::multi()  { _zui_list_multi=${1:-1} }
zui::limit()  { _zui_list_limit=${1:-0} }
zui::ordered() { _zui_list_ordered=${1:-1} }
zui::selected() {
  _zui_list_mark_initial "$@"
  (( _zui_list_multi )) || _zui_list_select_value "${1-}"
}

zui::value() { # initial input value and password flag
  _zui_ed_reset "${1-}" 0
  _zui_ed_mask=${2:-0}
}

zui::placeholder() { _zui_ed_placeholder=${1-}; _zui_ta_placeholder=${1-} }
zui::textarea()    { _zui_ta_reset "${1-}" 0 }
zui::line_numbers() { _zui_ta_numbers=${1:-1} }

zui::form_field() { # label [value]
  _zui_form_labels+=("${1:?label required}")
  _zui_form_values+=("${2-}")
  _zui_form_mask+=(0)
}
zui::secret() { # label
  local i
  for (( i = 1; i <= ${#_zui_form_labels}; i++ )); do
    [[ ${_zui_form_labels[i]} == "$1" ]] && _zui_form_mask[i]=1
  done
}
zui::gauge() { _zui_dlg[percent]=${1:-0}; _zui_dlg[label]=${2-} }

zui::list_height() { _zui_dlg[list_h]=${1:-8} }
zui::textarea_height() { _zui_dlg[ta_h]=${1:-8} }
zui::default_button() { _zui_dlg[default]=${1:-1} }

zui::run() {
  local w=${_zui_dlg[widget]}
  [[ $w == form ]] && { _zui_form_focus=1; _zui_form_scroll=0; _zui_form_load; }
  _zui_dialog_run
  local rc=$?
  ZUI_OUT=$_ZUI_OUT
  ZUI_CODE=$rc
  return $rc
}

zui::print() { print -r -- "$ZUI_OUT" }

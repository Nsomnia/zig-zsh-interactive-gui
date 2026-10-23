# zui misc: completion.

_ZUI_CMD_LONG[completion]="Emit a completion script for zsh or bash. Load it from your shell configuration, e.g. eval \"\$(zui completion zsh)\"."
_ZUI_EXAMPLES[completion]=$'eval "$(zui completion zsh)"\nzui completion bash > /etc/bash_completion.d/zui'
_ZUI_NOTES[completion]=$'The generated script completes command names and delegates file arguments to the shell. It intentionally does not complete every flag.'

_zui_cmd_completion() {
  local shell=${1:-}
  [[ -z $shell ]] && { _zui_err "usage: zui completion <zsh|bash>"; return 2; }
  case $shell in
    (zsh)
      cat <<'ZSH'
#compdef zui
# zui completion for zsh
_zui() {
  local -a commands
  commands=(
    'choose:Pick one or more items'
    'confirm:Ask a yes/no question'
    'input:Read a single line'
    'write:Compose multi-line text'
    'filter:Fuzzy-filter a list'
    'file:Browse for a file or directory'
    'pager:Scroll through text'
    'spin:Show a spinner while a command runs'
    'style:Apply borders, padding and colour'
    'format:Substitute template fields'
    'join:Join blocks of text'
    'table:Render CSV as a table'
    'log:Emit a structured log line'
    'dialog:Open any dialog type'
    'msgbox:Message box with action buttons'
    'yesno:Modal yes/no dialog'
    'inputbox:Text input dialog'
    'menu:Single-select menu dialog'
    'checklist:Multi-select checklist dialog'
    'form:Multi-field form dialog'
    'gauge:Progress gauge'
    'infobox:Buttonless notice'
    'version:Print version information'
    'completion:Generate a completion script'
  )
  if (( CURRENT == 2 )); then
    _describe -t commands 'zui command' commands
  elif (( CURRENT == 3 )) && [[ $words[2] == (help|completion) ]]; then
    if [[ $words[2] == help ]]; then
      _describe -t commands 'zui command' commands
    else
      _values 'shell' zsh bash
    fi
  else
    _files
  fi
}
if (( $+functions[compdef] )); then compdef _zui zui; else _zui "$@"; fi
ZSH
      ;;
    (bash)
      cat <<'BASH'
# zui completion for bash
_zui_complete() {
  local cur prev
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  local cmds="choose confirm input write filter file pager spin style format join table log dialog msgbox yesno inputbox menu checklist form gauge infobox version completion help"
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi
  if [[ $prev == completion || $prev == help ]]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi
  COMPREPLY=( $(compgen -f -- "$cur") )
}
complete -F _zui_complete zui
BASH
      ;;
    (*) _zui_err "unsupported shell '$shell' (use zsh or bash)"; return 2 ;;
  esac
}

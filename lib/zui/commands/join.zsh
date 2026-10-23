# zui join

_ZUI_OPTDEF_join=(
  '|direction|str|Join direction: horizontal or vertical|horizontal'
  '|align|str|Block alignment: left, center, right|left'
  '|padding|int|Spaces (horizontal) or blank lines (vertical) between blocks|1'
  '|horizontal|flag|Shorthand for --direction horizontal|0'
  '|vertical|flag|Shorthand for --direction vertical|0'
)

_ZUI_CMD_DESC[join]="Join blocks of text horizontally or vertically."
_ZUI_CMD_USAGE[join]="zui join [flags] [blocks...]"
_ZUI_CMD_LONG[join]="Blocks come from arguments, or from stdin split on lines containing only ---. Horizontal joins place blocks side by side, padding shorter blocks; vertical stacks them, padding narrower blocks."
_ZUI_EXAMPLES[join]=$'printf \'one\\ntwo\\n---\\nA\\nB\\nC\' | zui join --horizontal\nzui join --vertical --align center --padding 2 "left block" "a longer block"\nprintf \'x\\n---\\ny\' | zui join --direction vertical'
_ZUI_NOTES[join]=$'Alignment applies to each line inside its block.\nHorizontal joins trim trailing spaces from each output line.'

typeset -ga _zui_join_blocks=()

_zui_join_collect() {
  _zui_join_blocks=()
  if (( ${#_ZUI_ARGS} )); then
    _zui_join_blocks=("${_ZUI_ARGS[@]}")
    return
  fi
  _zui_slurp_stdin
  local -a lines
  lines=("${_ZUI_STDIN[@]}")
  if (( ${#lines} == 0 )); then return; fi
  local cur="" line
  for line in "${lines[@]}"; do
    if [[ $line == '---' ]]; then
      _zui_join_blocks+=("$cur")
      cur=""
    else
      [[ -n $cur ]] && cur+=$'\n'
      cur+=$line
    fi
  done
  _zui_join_blocks+=("$cur")
}

_zui_cmd_join() {
  emulate -L zsh
  setopt localoptions extendedglob
  _zui_join_collect
  (( ${#_zui_join_blocks} )) || return 0
  local dir=${_ZUI_OPT[direction]:-horizontal}
  (( ${_ZUI_OPT[horizontal]:-0} )) && dir=horizontal
  (( ${_ZUI_OPT[vertical]:-0} )) && dir=vertical
  local align=${_ZUI_OPT[align]:-left}
  local gap=${_ZUI_OPT[padding]:-1}
  [[ $gap == <-> ]] || gap=1

  local nb=${#_zui_join_blocks}
  local -a w h
  local i blk line max
  for (( i = 1; i <= nb; i++ )); do
    blk=${_zui_join_blocks[i]}
    local -a lines=("${(@f)blk}")
    h[i]=${#lines}
    max=0
    for line in "${lines[@]}"; do (( ${#line} > max )) && max=${#line}; done
    w[i]=$max
  done

  if [[ $dir == vertical ]]; then
    max=0
    for (( i = 1; i <= nb; i++ )); do (( w[i] > max )) && max=${w[i]}; done
    for (( i = 1; i <= nb; i++ )); do
      local -a lines=("${(@f)_zui_join_blocks[i]}")
      for line in "${lines[@]}"; do
        _zui_pad "$line" $max "$align"
        print -r -- "$REPLY"
      done
      if (( i < nb )); then
        local j; for (( j = 0; j < gap; j++ )); do print -r -- ""; done
      fi
    done
  else
    max=0
    for (( i = 1; i <= nb; i++ )); do (( h[i] > max )) && max=${h[i]}; done
    local r out cell
    for (( r = 1; r <= max; r++ )); do
      out=""
      for (( i = 1; i <= nb; i++ )); do
        local -a lines=("${(@f)_zui_join_blocks[i]}")
        cell=${lines[r]:-}
        _zui_pad "$cell" $(( w[i] )) "$align"; cell=$REPLY
        out+=$cell
        (( i < nb )) && out+="${(l:gap:: :)}"
      done
      out=${out%%[[:space:]]#}
      print -r -- "$out"
    done
  fi
}

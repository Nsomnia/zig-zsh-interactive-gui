# zui table

_ZUI_OPTDEF_table=(
  '|columns|str|Comma-separated header names (otherwise the first row is the header)|'
  '|widths|str|Comma-separated column widths|'
  '|separator|str|Field separator|,'
  '|file|str|Read CSV from a file instead of stdin|'
  '|border|str|Border: rounded, sharp, double, thick, ascii, none|rounded'
  '|print|flag|Print the table (default behaviour)|0'
  '|no-header|flag|Treat every row as data|0'
  '|height|int|Accepted for gum compatibility (tables are static)|0'
)

_ZUI_CMD_DESC[table]="Render CSV data as an aligned, bordered table."
_ZUI_CMD_USAGE[table]="zui table [flags]"
_ZUI_CMD_LONG[table]="Parses CSV (including quoted fields and escaped quotes) and prints a boxed table. The first row is used as the header unless --columns or --no-header is supplied. Column widths are computed from the content and clamped to the terminal width."
_ZUI_EXAMPLES[table]=$'printf \'name,age\\nAda,36\\nGrace,45\' | zui table\nzui table --file users.csv --columns "Name,Role" --widths 20,30\nzui table --separator "\\t" --file metrics.tsv'
_ZUI_NOTES[table]=$'This implementation renders a static table, which makes it safe in pipelines. Use --print explicitly if you prefer.\nWidths count characters; wide CJK glyphs may shift alignment.'

typeset -ga _ZUI_CSV_FIELDS=()
_zui_csv_split() { # line separator -> _ZUI_CSV_FIELDS
  emulate -L zsh
  local line=${1%$'\r'} sep=$2 ch cur="" inq=0 i
  typeset -ga _ZUI_CSV_FIELDS
  _ZUI_CSV_FIELDS=()
  for (( i = 1; i <= ${#line}; i++ )); do
    ch=${line[i]}
    if (( inq )); then
      if [[ $ch == '"' ]]; then
        if [[ ${line[i+1]} == '"' ]]; then cur+='"'; (( i++ )); else inq=0; fi
      else
        cur+=$ch
      fi
    else
      if [[ $ch == '"' ]]; then
        inq=1
      elif [[ $ch == "$sep" ]]; then
        _ZUI_CSV_FIELDS+=("$cur"); cur=""
      else
        cur+=$ch
      fi
    fi
  done
  _ZUI_CSV_FIELDS+=("$cur")
}

_zui_table_border() { # style -> variables
  case $1 in
    (ascii)  _ZUI_TL='+' _ZUI_TR='+' _ZUI_BL='+' _ZUI_BR='+' _ZUI_H='-' _ZUI_V='|'
             _ZUI_TT='+' _ZUI_BT='+' _ZUI_LT='+' _ZUI_RT='+' _ZUI_X='+' ;;
    (sharp)  _ZUI_TL='┌' _ZUI_TR='┐' _ZUI_BL='└' _ZUI_BR='┘' _ZUI_H='─' _ZUI_V='│'
             _ZUI_TT='┬' _ZUI_BT='┴' _ZUI_LT='├' _ZUI_RT='┤' _ZUI_X='┼' ;;
    (double) _ZUI_TL='╔' _ZUI_TR='╗' _ZUI_BL='╚' _ZUI_BR='╝' _ZUI_H='═' _ZUI_V='║'
             _ZUI_TT='╦' _ZUI_BT='╩' _ZUI_LT='╠' _ZUI_RT='╣' _ZUI_X='╬' ;;
    (thick)  _ZUI_TL='┏' _ZUI_TR='┓' _ZUI_BL='┗' _ZUI_BR='┛' _ZUI_H='━' _ZUI_V='┃'
             _ZUI_TT='┳' _ZUI_BT='┻' _ZUI_LT='┣' _ZUI_RT='┫' _ZUI_X='╋' ;;
    (none)   _ZUI_TL=' ' _ZUI_TR=' ' _ZUI_BL=' ' _ZUI_BR=' ' _ZUI_H=' ' _ZUI_V=' '
             _ZUI_TT=' ' _ZUI_BT=' ' _ZUI_LT=' ' _ZUI_RT=' ' _ZUI_X=' ' ;;
    (*)      _ZUI_TL='╭' _ZUI_TR='╮' _ZUI_BL='╰' _ZUI_BR='╯' _ZUI_H='─' _ZUI_V='│'
             _ZUI_TT='┬' _ZUI_BT='┴' _ZUI_LT='├' _ZUI_RT='┤' _ZUI_X='┼' ;;
  esac
}

_zui_table_rule() { # widths type(top|mid|bottom) prefix/suffix
  local type=$1 padw=$2
  shift 2
  local -a ws=("$@")
  local line="" i seg
  case $type in
    (top) line=$_ZUI_TL; seg=$_ZUI_TT ;;
    (mid) line=$_ZUI_LT; seg=$_ZUI_X ;;
    (*)   line=$_ZUI_BL; seg=$_ZUI_BT ;;
  esac
  local segline
  for (( i = 1; i <= ${#ws}; i++ )); do
    _zui_repeat "$_ZUI_H" $(( ws[i] + padw * 2 )); line+=$REPLY
    if (( i < ${#ws} )); then line+=$seg; else
      case $type in (top) line+=$_ZUI_TR;; (mid) line+=$_ZUI_RT;; (*) line+=$_ZUI_BR;; esac
    fi
  done
  REPLY=$line
}

_zui_cmd_table() {
  local sep=${_ZUI_OPT[separator]:-,}
  [[ $sep == '\t' ]] && sep=$'\t'
  (( ${#sep} == 1 )) || { _zui_err "--separator must be one character"; return 2; }
  local nohdr=${_ZUI_OPT[no-header]:-0}

  local -a raw
  if [[ -n ${_ZUI_OPT[file]:-} ]]; then
    [[ -r ${_ZUI_OPT[file]} ]] || { _zui_err "cannot read '${_ZUI_OPT[file]}'"; return 2; }
    raw=("${(@f)$(<${_ZUI_OPT[file]})}")
  else
    _zui_slurp_stdin
    raw=("${_ZUI_STDIN[@]}")
  fi
  (( ${#raw} )) || { print -r -- ""; return 0; }

  local -a header=()
  if [[ -n ${_ZUI_OPT[columns]:-} ]]; then
    _zui_csv_split "${_ZUI_OPT[columns]}" ','
    header=("${_ZUI_CSV_FIELDS[@]}")
  elif (( ! nohdr )); then
    _zui_csv_split "${raw[1]}" "$sep"
    header=("${_ZUI_CSV_FIELDS[@]}")
    shift raw
  fi

  local -a rows=("${raw[@]}")
  local line f

  local ncols=${#header}
  local -a widths=()
  if [[ -n ${_ZUI_OPT[widths]:-} ]]; then
    widths=("${(@s:,:)${_ZUI_OPT[widths]}}")
  fi
  local i fld cw
  for line in "${rows[@]}"; do
    _zui_csv_split "$line" "$sep"
    (( ${#_ZUI_CSV_FIELDS} > ncols )) && ncols=${#_ZUI_CSV_FIELDS}
  done
  (( ncols < 1 )) && ncols=1

  # Fill missing/invalid widths from content.
  for (( i = 1; i <= ncols; i++ )); do
    if (( ${#widths} < i )) || [[ ${widths[i]} != <-> ]] || (( widths[i] == 0 )); then
      cw=${#header[i]}
      for line in "${rows[@]}"; do
        _zui_csv_split "$line" "$sep"
        (( ${#_ZUI_CSV_FIELDS[i]} > cw )) && cw=${#_ZUI_CSV_FIELDS[i]}
      done
      widths[i]=$cw
    fi
    (( widths[i] < 3 )) && widths[i]=3
  done

  # Clamp total width to the terminal.
  local termw=${COLUMNS:-80}
  (( termw <= 0 )) && termw=80
  local maxw=$(( termw - ncols * 3 - 1 ))
  local total=0
  for (( i = 1; i <= ncols; i++ )); do (( total += widths[i] )); done
  while (( total > maxw )); do
    local big=1
    for (( i = 2; i <= ncols; i++ )); do (( widths[i] > widths[big] )) && big=$i; done
    (( widths[big] <= 3 )) && break
    (( widths[big]-- ))
    (( total-- ))
  done

  local bstyle=${_ZUI_OPT[border]:-rounded}
  if ! _zui_utf8 && [[ $bstyle == (rounded|sharp|double|thick) ]]; then bstyle=ascii; fi
  _zui_table_border "$bstyle"
  local pad=1 padw=$(( pad * 2 ))
  [[ $_ZUI_TL == ' ' ]] && { pad=0; padw=0; }
  local border_style="" header_style="" text_style=""
  if [[ -t 1 ]]; then
    border_style=$(_zui_sgr 240 -)
    header_style=$(_zui_sgr 81 - bold)
    text_style=""
  fi
  local reset=$'\e[0m'
  [[ -z $border_style ]] && reset=""

  local -a cells
  local showb=1; [[ ${_ZUI_OPT[border]:-rounded} == none ]] && showb=0
  if (( ${#header} )); then
    (( showb )) && { _zui_table_rule top $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
    line=""
    for (( i = 1; i <= ncols; i++ )); do
      _zui_pad "${header[i]}" ${widths[i]} left
      line+="${_ZUI_V} ${REPLY} "
    done
    print -r -- "${header_style:-$border_style}${line}${_ZUI_V}${reset}"
    (( showb )) && { _zui_table_rule mid $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
  elif (( showb )); then
    _zui_table_rule top $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"
  fi

  for line in "${rows[@]}"; do
    _zui_csv_split "$line" "$sep"
    f=("${_ZUI_CSV_FIELDS[@]}")
    local out=""
    for (( i = 1; i <= ncols; i++ )); do
      _zui_pad "${f[i]}" ${widths[i]} left
      out+="${_ZUI_V} ${REPLY} "
    done
    print -r -- "$out${_ZUI_V}"
  done
  (( showb )) && { _zui_table_rule bottom $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
  return 0
}

# zui table

_ZUI_OPTDEF_table=(
  'c|columns|str|Comma-separated header names (otherwise the first row is the header)|'
  'w|widths|str|Comma-separated column widths|'
  's|separator|str|Field separator|,'
  'f|file|str|Read CSV from a file instead of stdin|'
  'b|border|str|Border: rounded, sharp, double, thick, ascii, none|rounded'
  'p|print|flag|Print the table instead of opening the row picker|0'
  '|no-header|flag|Treat every row as data|0'
  '|height|int|Number of visible rows in interactive mode (0 = fit content)|0'
  '|show-help|flag|Show the key-hint footer|1'
  '|no-show-help|flag|Hide the key-hint footer|0'
  '|hide-count|flag|Hide the row count in the hint footer|0'
  '|lazy-quotes|flag|Accept bare quotes inside unquoted CSV fields|0'
  '|fields-per-record|int|Expected field count per row (0 = infer)|0'
  'r|return-column|int|Print this 1-based column instead of the whole row (0 = row)|0'
  '|timeout|str|Close the row picker with exit 124 after a duration|'
  '|padding|str|Cell padding in spaces (N or V,H)|1'
)

_ZUI_CMD_DESC[table]="Render CSV as a table, or pick a row interactively."
_ZUI_CMD_USAGE[table]="zui table [flags]"
_ZUI_CMD_LONG[table]="Parses CSV (including quoted fields and escaped quotes). On a terminal it opens a row picker and prints the chosen row; with --print, or when stdout is a pipe, it writes the full bordered table instead. The first row is used as the header unless --columns or --no-header is supplied."
_ZUI_EXAMPLES[table]=$'printf \'name,age\\nAda,36\\nGrace,45\' | zui table --print\nrow=$(zui table --return-column 1 < users.csv)\nzui table --file users.csv --columns "Name,Role" --widths 20,30\nzui table --separator "\\t" --file metrics.tsv --print'
_ZUI_NOTES[table]=$'Interactive mode exits 1 on cancel and 124 on --timeout. --return-column prints one field instead of the whole row.\nPiped output is always the static bordered table, so it stays safe in scripts.\nWidths count characters; wide CJK glyphs may shift alignment.'

typeset -ga _ZUI_CSV_FIELDS=()
_zui_csv_split() { # line separator [lazy] -> _ZUI_CSV_FIELDS
  emulate -L zsh
  local line=${1%$'\r'} sep=$2 lazy=${3:-0} ch cur="" inq=0 i
  typeset -ga _ZUI_CSV_FIELDS
  _ZUI_CSV_FIELDS=()
  for (( i = 1; i <= ${#line}; i++ )); do
    ch=${line[i]}
    if (( inq )); then
      if [[ $ch == '"' ]]; then
        if [[ ${line[i+1]} == '"' ]]; then
          cur+='"'; (( i++ ))
        elif (( lazy )) && [[ -n ${line[i+1]} && ${line[i+1]} != "$sep" ]]; then
          cur+='"'
        else
          inq=0
        fi
      else
        cur+=$ch
      fi
    else
      if [[ $ch == '"' && ${#cur} -eq 0 ]]; then
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

_zui_csv_fit() { # expected -> pad/truncate _ZUI_CSV_FIELDS
  local n=$1 i
  (( n > 0 )) || return 0
  for (( i = ${#_ZUI_CSV_FIELDS} + 1; i <= n; i++ )); do _ZUI_CSV_FIELDS+=(""); done
  (( ${#_ZUI_CSV_FIELDS} > n )) && _ZUI_CSV_FIELDS=("${(@)_ZUI_CSV_FIELDS[1,n]}")
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
  local lazy=${_ZUI_OPT[lazy-quotes]:-0}
  local fpr=${_ZUI_OPT[fields-per-record]:-0}
  [[ $fpr == <-> ]] || fpr=0

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
    _zui_csv_split "${_ZUI_OPT[columns]}" ',' "$lazy"
    header=("${_ZUI_CSV_FIELDS[@]}")
  elif (( ! nohdr )); then
    _zui_csv_split "${raw[1]}" "$sep" "$lazy"
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
    _zui_csv_split "$line" "$sep" "$lazy"; _zui_csv_fit $fpr
    (( ${#_ZUI_CSV_FIELDS} > ncols )) && ncols=${#_ZUI_CSV_FIELDS}
  done
  (( ncols < 1 )) && ncols=1

  # Fill missing/invalid widths from content.
  for (( i = 1; i <= ncols; i++ )); do
    if (( ${#widths} < i )) || [[ ${widths[i]} != <-> ]] || (( widths[i] == 0 )); then
      cw=${#header[i]}
      for line in "${rows[@]}"; do
        _zui_csv_split "$line" "$sep" "$lazy"; _zui_csv_fit $fpr
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

  # Interactive row picker on a terminal; --print (or a pipe) stays static.
  if [[ -t 1 ]] && (( ! ${_ZUI_OPT[print]:-0} )); then
    local -a disp=()
    local out
    for line in "${rows[@]}"; do
      _zui_csv_split "$line" "$sep" "$lazy"; _zui_csv_fit $fpr
      out=""
      for (( i = 1; i <= ncols; i++ )); do
        _zui_pad "${_ZUI_CSV_FIELDS[i]}" ${widths[i]} left
        out+="${REPLY}  "
      done
      disp+=("${out%  }")
    done
    local hdr=""
    for (( i = 1; i <= ncols; i++ )); do
      _zui_pad "${header[i]}" ${widths[i]} left
      hdr+="${REPLY}  "
    done
    hdr=${hdr%  }

    _zui_dialog_reset
    _zui_list_items=("${rows[@]}")
    _zui_list_labels=("${disp[@]}")
    _zui_list_multi=0
    _zui_list_build
    _zui_dlg[widget]=list
    _zui_dlg[message]=$hdr
    _zui_dialog_common
    _zui_dlg[title]=Table
    local lh=${_ZUI_OPT[height]:-0}
    [[ $lh == <-> ]] || lh=0
    (( lh > 0 )) || lh=$(( ${#rows} < 10 ? ${#rows} : 10 ))
    (( lh < 1 )) && lh=1
    _zui_dlg[list_h]=$lh
    local hint="↑↓ move  Enter select  Esc cancel"
    (( ${_ZUI_OPT[hide-count]:-0} )) || hint+="  ${#rows} rows"
    _zui_dlg[hints]=$hint
    _zui_build_buttons Select Cancel
    _zui_dialog_run
    local rc=$?
    if (( rc == 0 )) && [[ -n $_ZUI_OUT ]]; then
      local pick=$_ZUI_OUT col=${_ZUI_OPT[return-column]:-0}
      if [[ $col == <-> ]] && (( col > 0 )); then
        _zui_csv_split "$pick" "$sep" "$lazy"; _zui_csv_fit $fpr
        pick=${_ZUI_CSV_FIELDS[col]-}
      fi
      _ZUI_EMIT=1
      _zui_emit_out "$pick"
    fi
    return $rc
  fi

  local bstyle=${_ZUI_OPT[border]:-rounded}
  if ! _zui_utf8 && [[ $bstyle == (rounded|sharp|double|thick) ]]; then bstyle=ascii; fi
  _zui_table_border "$bstyle"
  local pad=1 pspec=${_ZUI_OPT[padding]:-1}
  pspec=${pspec%%,*}; pspec=${pspec%% *}
  [[ $pspec == <-> ]] && pad=$pspec
  local padw=$(( pad * 2 )) lpad=${(l:pad:: :)}
  [[ $_ZUI_TL == ' ' ]] && { pad=0; padw=0; }
  local border_style="" header_style="" cell_style=""
  if [[ -t 1 ]]; then
    border_style=$(_zui_sgr "${_ZUI_OPT[border.foreground]:-240}" -)
    header_style=$(_zui_sgr "${_ZUI_OPT[header.foreground]:-81}" - bold)
    [[ -n ${_ZUI_OPT[cell.foreground]:-} ]] && cell_style=$(_zui_sgr "${_ZUI_OPT[cell.foreground]}" -)
  fi
  local reset=$'\e[0m'
  [[ -z $border_style ]] && reset=""

  local showb=1; [[ ${_ZUI_OPT[border]:-rounded} == none ]] && showb=0
  if (( ${#header} )); then
    (( showb )) && { _zui_table_rule top $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
    line=""
    for (( i = 1; i <= ncols; i++ )); do
      _zui_pad "${header[i]}" ${widths[i]} left
      line+="${_ZUI_V}${lpad}${REPLY}${lpad}"
    done
    print -r -- "${header_style:-$border_style}${line}${_ZUI_V}${reset}"
    (( showb )) && { _zui_table_rule mid $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
  elif (( showb )); then
    _zui_table_rule top $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"
  fi

  for line in "${rows[@]}"; do
    _zui_csv_split "$line" "$sep" "$lazy"; _zui_csv_fit $fpr
    f=("${_ZUI_CSV_FIELDS[@]}")
    local out=""
    for (( i = 1; i <= ncols; i++ )); do
      _zui_pad "${f[i]}" ${widths[i]} left
      out+="${_ZUI_V}${lpad}${REPLY}${lpad}"
    done
    print -r -- "${cell_style}${out}${_ZUI_V}${reset}"
  done
  (( showb )) && { _zui_table_rule bottom $pad "${widths[@]}"; print -r -- "${border_style}${REPLY}${reset}"; }
  return 0
}

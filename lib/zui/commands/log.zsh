# zui log

_ZUI_OPTDEF_log=(
  'l|level|str|Message level: debug, info, warn, error, fatal|info'
  '|min-level|str|Suppress messages below this level|debug'
  '|prefix|str|Prefix placed before the level|'
  't|time|str|Timestamp format (strftime) or rfc3339|'
  'o|file|str|Append the log line to a file instead of stdout|'
  '|format|str|Output format: text, logfmt or json (alias for --formatter)|text'
  '|formatter|str|Output formatter: text, logfmt or json|'
  's|structured|flag|Use logfmt structured output|0'
)

_ZUI_CMD_DESC[log]="Emit a levelled, optionally structured log line."
_ZUI_CMD_USAGE[log]="zui log [flags] [message] [key=value...]"
_ZUI_CMD_LONG[log]="A small logger with coloured text output, logfmt and JSON. Positional key=value pairs become structured fields. Colours are disabled when writing to a file or when stdout is not a terminal."
_ZUI_EXAMPLES[log]=$'zui log --level info "server started" port=8080 env=dev\nzui log --level error --format json "request failed" status=500 path=/api\nzui log --time "%H:%M:%S" --prefix deploy "built image"\nzui log --file app.log --level warn "disk low" free=2%'
_ZUI_NOTES[log]=$'Levels are ordered debug < info < warn < error < fatal. --min-level filters messages below the threshold.\nJSON strings are escaped; logfmt values containing spaces are quoted.'

_zui_level_num() {
  case ${(L)1} in
    (debug) REPLY=0;; (info) REPLY=1;; (warn|warning) REPLY=2;;
    (error|err) REPLY=3;; (fatal|crit) REPLY=4;; (*) REPLY=-1;;
  esac
}

_zui_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  REPLY=$s
}

_zui_logfmt_quote() {
  local s=$1
  if [[ $s == *[[:space:]\"]* || -z $s ]]; then
    s=${s//\"/\\\"}
    REPLY="\"$s\""
  else
    REPLY=$s
  fi
}

_zui_cmd_log() {
  local level=${(L)${_ZUI_OPT[level]:-info}}
  local min=${(L)${_ZUI_OPT[min-level]:-debug}}
  _zui_level_num "$level"; local ln=$REPLY
  _zui_level_num "$min"; local mn=$REPLY
  if (( ln < 0 )); then _zui_err "unknown level '$level'"; return 2; fi
  if (( mn < 0 )); then mn=0; fi
  (( ln < mn )) && return 0

  local -a words fields
  local a msg=""
  for a in "${_ZUI_ARGS[@]}"; do
    if [[ $a == *=* ]]; then fields+=("$a"); else words+=("$a"); fi
  done
  # The message is the non-field words, in order.
  local w
  msg=""
  for w in "${words[@]}"; do msg+="${msg:+ }$w"; done

  local prefix=${_ZUI_OPT[prefix]:-}
  local tfmt=${_ZUI_OPT[time]:-}
  local stamp=""
  if [[ -n $tfmt ]]; then
    zmodload zsh/datetime 2>/dev/null
    if [[ $tfmt == rfc3339 ]]; then
      stamp=$(strftime '%Y-%m-%dT%H:%M:%S%z' $EPOCHSECONDS)
    else
      stamp=$(strftime "$tfmt" $EPOCHSECONDS)
    fi
  fi

  local format=${(L)${_ZUI_OPT[formatter]:-${_ZUI_OPT[format]:-text}}}
  (( ${_ZUI_OPT[structured]:-0} )) && format=logfmt
  local out=""
  local kv k v
  case $format in
    (json)
      out='{"level":'
      _zui_json_escape "$level"; out+="\"$REPLY\""
      [[ -n $stamp ]] && { _zui_json_escape "$stamp"; out+=",\"time\":\"$REPLY\""; }
      [[ -n $prefix ]] && { _zui_json_escape "$prefix"; out+=",\"prefix\":\"$REPLY\""; }
      _zui_json_escape "$msg"; out+=",\"msg\":\"$REPLY\""
      for kv in "${fields[@]}"; do
        k=${kv%%=*}; v=${kv#*=}
        _zui_json_escape "$k"; local jk=$REPLY
        _zui_json_escape "$v"; out+=",\"$jk\":\"$REPLY\""
      done
      out+='}' ;;
    (logfmt)
      out="level=$level"
      [[ -n $stamp ]] && out+=" time=\"$stamp\""
      [[ -n $prefix ]] && out+=" prefix=\"$prefix\""
      _zui_logfmt_quote "$msg"; out+=" msg=$REPLY"
      for kv in "${fields[@]}"; do
        k=${kv%%=*}; v=${kv#*=}
        _zui_logfmt_quote "$v"; out+=" $k=$REPLY"
      done ;;
    (*)
      local color="" reset=""
      if [[ -z ${_ZUI_OPT[file]:-} && -t 1 && ${ZUI_ANSI_PROFILE:-none} != none ]]; then
        reset=$'\e[0m'
        case $level in
          (debug) color=$(_zui_sgr 244 -) ;;
          (info)  color=$(_zui_sgr 81 - bold) ;;
          (warn)  color=$(_zui_sgr 221 - bold) ;;
          (error) color=$(_zui_sgr 203 - bold) ;;
          (fatal) color=$(_zui_sgr 231 160 bold) ;;
        esac
      fi
      [[ -n ${_ZUI_OPT[level.foreground]:-} ]] && color=$(_zui_sgr "${_ZUI_OPT[level.foreground]}" - bold)
      [[ -n $stamp ]] && out+="$(_zui_sgr "${_ZUI_OPT[time.foreground]:-244}" -)$stamp$reset "
      [[ -n $prefix ]] && out+="$(_zui_sgr "${_ZUI_OPT[prefix.foreground]:-213}" -)$prefix$reset "
      out+="${color}${(U)level}${reset}"
      [[ -n $msg ]] && out+=" $(_zui_sgr "${_ZUI_OPT[message.foreground]:-}" -)$msg$reset"
      for kv in "${fields[@]}"; do
        k=${kv%%=*}; v=${kv#*=}
        out+=" $(_zui_sgr "${_ZUI_OPT[key.foreground]:-244}" -)$k=$reset$(_zui_sgr "${_ZUI_OPT[value.foreground]:-}" -)$v$reset"
      done ;;
  esac

  if [[ -n ${_ZUI_OPT[file]:-} ]]; then
    print -r -- "$out" >> "${_ZUI_OPT[file]}" || { _zui_err "cannot write '${_ZUI_OPT[file]}'"; return 2; }
  else
    print -r -- "$out"
  fi
}

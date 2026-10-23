# zui cli: option parsing and command dispatch (pflag-flavoured).

typeset -g  _ZUI_CMD=""
typeset -gA _ZUI_OPT=() _ZUI_TYPES=() _ZUI_SHORTS=() _ZUI_DEFAULTS=()
typeset -ga _ZUI_ARGS=()
typeset -g  ZUI_ANSI_PROFILE=""
typeset -ga _ZUI_STDIN=()

_zui_usage_error() {
  local cmd=$1 msg=$2
  print -ru2 -- "zui: $msg"
  print -ru2 -- "Run 'zui help $cmd' for usage."
  exit 2
}

_zui_duration() { # "1s" "250ms" "2m" -> REPLY seconds
  emulate -L zsh
  local v=$1 n
  case $v in
    (*ms) n=${v%ms}; (( n = (n + 999) / 1000 )); REPLY=$n ;;
    (*s)  n=${v%s};  REPLY=$(( n )) ;;
    (*m)  n=${v%m};  REPLY=$(( n * 60 )) ;;
    (*h)  n=${v%h};  REPLY=$(( n * 3600 )) ;;
    (<->) REPLY=$v ;;
    (*)   REPLY=-1 ;;
  esac
  (( REPLY < 0 )) && return 1
  return 0
}

_zui_slurp_stdin() {
  _ZUI_STDIN=()
  [[ -t 0 ]] && return 0
  local line
  while IFS= read -r line; do line=${line%$'\r'}; _ZUI_STDIN+=("$line"); done
}

_zui_emit() {
  (( _ZUI_EMIT )) && print -r -- "$1"
}

# Parse options for <cmd>.  Returns 90 for help, 91 for version.
_zui_parse() {
  emulate -L zsh
  local cmd=$1; shift
  _ZUI_CMD=$cmd
  _ZUI_OPT=(); _ZUI_TYPES=(); _ZUI_SHORTS=(); _ZUI_DEFAULTS=(); _ZUI_ARGS=()
  local defvar="_ZUI_OPTDEF_$cmd"
  if (( ! ${+parameters[$defvar]} )); then
    _zui_usage_error "$cmd" "unknown command '$cmd'"
  fi
  local -a defs
  defs=("${(@P)defvar}")
  local def short long type desc defval
  for def in "${defs[@]}"; do
    IFS='|' read -r short long type desc defval <<< "$def"
    [[ -z $long ]] && continue
    _ZUI_TYPES[$long]=$type
    _ZUI_DEFAULTS[$long]=$defval
    _ZUI_OPT[$long]=$defval
    [[ -n $short ]] && _ZUI_SHORTS[$short]=$long
  done

  local arg name val hasval c
  while (( $# )); do
    arg=$1; shift
    case $arg in
      (--)
        _ZUI_ARGS+=("$@"); break ;;
      (--help|-h) return 90 ;;
      (--version|-v) zui::version; return 91 ;;
      (--no-color) ZUI_NO_COLOR=1 ;;
      (--ascii) ZUI_ASCII=1 ;;
      (--debug) ZUI_DEBUG=1 ;;
      (--theme)
        (( $# )) || _zui_usage_error "$cmd" "--theme needs a value"
        ZUI_THEME=$1; shift ;;
      (--theme=*) ZUI_THEME=${arg#--theme=} ;;
      (--*)
        name=${arg#--}; val=""; hasval=0
        if [[ $name == *=* ]]; then val=${name#*=}; name=${name%%=*}; hasval=1; fi
        # gum-style per-part colours: --cursor.foreground, --item.background, ...
        if (( ! ${+_ZUI_TYPES[$name]} )) && [[ $name == *.* ]] \
           && (( ${+_ZUI_STYLE_MAP[${name%%.*}]} )); then
          _ZUI_TYPES[$name]=str
        fi
        if (( ! ${+_ZUI_TYPES[$name]} )); then
          _zui_usage_error "$cmd" "unknown option '--$name'"
        fi
        type=${_ZUI_TYPES[$name]}
        if [[ $type == flag ]]; then
          if (( hasval )); then
            case ${(L)val} in
              (false|0|no|off) _ZUI_OPT[$name]=0 ;;
              (*) _ZUI_OPT[$name]=1 ;;
            esac
          else
            _ZUI_OPT[$name]=1
          fi
        else
          if (( ! hasval )); then
            (( $# )) || _zui_usage_error "$cmd" "--$name needs a value"
            val=$1; shift
          fi
          if [[ $type == int ]]; then
            [[ $val == <-> ]] || _zui_usage_error "$cmd" "--$name expects a number"
          fi
          if [[ $type == multi ]]; then
            if [[ -n ${_ZUI_OPT[$name]} ]]; then _ZUI_OPT[$name]+=$'\n'$val; else _ZUI_OPT[$name]=$val; fi
          else
            _ZUI_OPT[$name]=$val
          fi
        fi ;;
      (-?*)
        local s=${arg#-}
        while [[ -n $s ]]; do
          c=${s[1,1]}; s=${s[2,-1]}
          long=${_ZUI_SHORTS[$c]:-}
          [[ -z $long ]] && _zui_usage_error "$cmd" "unknown option '-$c'"
          type=${_ZUI_TYPES[$long]}
          if [[ $type == flag ]]; then
            _ZUI_OPT[$long]=1
          else
            val=$s
            if [[ -z $val ]]; then
              (( $# )) || _zui_usage_error "$cmd" "-$c needs a value"
              val=$1; shift
            fi
            if [[ $type == int ]]; then
              [[ $val == <-> ]] || _zui_usage_error "$cmd" "-$c expects a number"
            fi
            if [[ $type == multi ]]; then
              if [[ -n ${_ZUI_OPT[$long]} ]]; then _ZUI_OPT[$long]+=$'\n'$val; else _ZUI_OPT[$long]=$val; fi
            else
              _ZUI_OPT[$long]=$val
            fi
            s=""
          fi
        done ;;
      (*) _ZUI_ARGS+=("$arg") ;;
    esac
  done
  if (( ZUI_NO_COLOR )) || [[ -n ${NO_COLOR-} ]]; then ZUI_ANSI_PROFILE=none; fi
  [[ -z $ZUI_ANSI_PROFILE ]] && ZUI_ANSI_PROFILE=$(_zui_ansi_profile)
  return 0
}

_zui_main() {
  emulate -L zsh
  _zui_load

  while (( $# )); do
    case $1 in
      (--help|-h) _zui_help ""; return 0 ;;
      (--version|-v) zui::version; return 0 ;;
      (--no-color) ZUI_NO_COLOR=1; ZUI_ANSI_PROFILE=none; shift ;;
      (--ascii) ZUI_ASCII=1; shift ;;
      (--debug) ZUI_DEBUG=1; shift ;;
      (--theme) ZUI_THEME=${2:-default}; shift 2 ;;
      (--theme=*) ZUI_THEME=${1#--theme=}; shift ;;
      (--) shift; break ;;
      (-*) _zui_usage_error "" "unknown global option '$1'" ;;
      (*) break ;;
    esac
  done

  [[ -z $ZUI_ANSI_PROFILE ]] && ZUI_ANSI_PROFILE=$(_zui_ansi_profile)
  local cmd=${1:-}
  (( $# )) && shift
  if [[ -z $cmd || $cmd == help ]]; then
    _zui_help "${1-}"; return $?
  fi
  if [[ $cmd == version ]]; then
    if [[ ${1-} == (--help|-h) ]]; then _zui_help version; else zui::version; fi
    return 0
  fi
  if [[ $cmd == completion ]]; then _zui_cmd_completion "$@"; return $?; fi
  if [[ ${1-} == help ]] && (( ${+functions[_zui_cmd_$cmd]} )); then
    _zui_help "$cmd"; return $?
  fi
  if (( ! ${+functions[_zui_cmd_$cmd]} )); then
    print -ru2 -- "zui: unknown command '$cmd'"
    print -ru2 -- "Run 'zui help' for a list of commands."
    return 2
  fi

  _zui_parse "$cmd" "$@"
  local rc=$?
  (( rc == 90 )) && { _zui_help "$cmd"; return 0; }
  (( rc == 91 )) && return 0
  (( rc != 0 )) && return $rc
  _zui_cmd_$cmd
  return $?
}

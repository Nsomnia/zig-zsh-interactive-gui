# zui format

_ZUI_OPTDEF_format=(
  '|template|str|Template containing {{.Fields}}|'
  '|file|str|Read the template from a file|'
  '|strict|flag|Fail when a placeholder is left unresolved|0'
  't|type|str|Output type: template, markdown, code or emoji|template'
  'l|language|str|Language hint for --type code (accepted; output is plain)|'
  '|theme|str|Markdown theme name (accepted for gum compatibility)|pink'
  '|strip-ansi|flag|Remove ANSI escapes from the input|0'
  '|no-strip-ansi|flag|Keep ANSI escapes in the input|0'
)

_ZUI_CMD_DESC[format]="Format templates, Markdown, emoji aliases or code."
_ZUI_CMD_USAGE[format]="zui format [flags] [key=value...]"
_ZUI_CMD_LONG[format]="The default --type template substitutes Go-template fields such as {{.Name}} from key=value arguments. --type markdown strips Markdown markers and styles headings, --type emoji expands :shortcode: aliases, and --type code passes text through unchanged."
_ZUI_EXAMPLES[format]=$'zui format --template "Hello, {{.Name}}!" Name=Ada\nprintf \'{{.Project}} v{{.Version}}\' > tmpl; zui format --file tmpl Project=zui Version=0.1.0\nzui format --type markdown < README.md\nzui format --type emoji "ship :rocket:"'
_ZUI_NOTES[format]=$'With --strict, any {{...}} placeholder that remains after substitution is an error (exit 2).\nWhen no template is given, stdin is used.\n--language and --theme are accepted for gum compatibility; code is not syntax-highlighted yet.'

_zui_fmt_emoji() {
  local s=$1 k
  local -A e=(
    smile "😄" heart "❤️" tada "🎉" check "✅" x "❌"
    warning "⚠️" rocket "🚀" fire "🔥" bug "🐛" sparkles "✨"
    "+1" "👍" "-1" "👎" wave "👋" star "⭐" eyes "👀"
  )
  for k in "${(k)e[@]}"; do s=${s//:$k:/$e[$k]}; done
  REPLY=$s
}

_zui_fmt_markdown() {
  emulate -L zsh
  local s=$1 out="" line bold dim reset
  bold=$(_zui_sgr '' '' bold)
  dim=$(_zui_sgr '' '' dim)
  reset=$'\e[0m'
  [[ -z $bold ]] && reset=""
  for line in "${(@f)s}"; do
    # shortcut: inline markdown keeps markers' text but drops emphasis runs;
    # upgrade to a real renderer if block/inline fidelity matters.
    line=${line//\*\*/}
    line=${line//\`/}
    line=${line//\*/}
    line=${line//\*\*/}
    line=${line//_/}
    if [[ $line == '#'* ]]; then
      line="${bold}${line#"${line%%[! #]*}"}${reset}"
    elif [[ $line == '- '* ]]; then
      line="• ${line#- }"
    elif [[ $line == '> '* ]]; then
      line="│ ${line#> }"
    fi
    [[ -n $out ]] && out+=$'\n'
    out+=$line
  done
  REPLY=$out
}

_zui_fmt_code() {
  # shortcut: no syntax highlighter is bundled; pass code through unchanged.
  REPLY=$1
}

_zui_cmd_format() {
  local type=${(L)${_ZUI_OPT[type]:-template}}
  local tmpl=${_ZUI_OPT[template]:-}
  if [[ -z $tmpl && -n ${_ZUI_OPT[file]:-} ]]; then
    [[ -r ${_ZUI_OPT[file]} ]] || { _zui_err "cannot read '${_ZUI_OPT[file]}'"; return 2; }
    tmpl=$(<"${_ZUI_OPT[file]}")
  fi
  if [[ -z $tmpl && ! -t 0 ]]; then tmpl=$(cat); fi
  if [[ -z $tmpl && $type != template && ${#_ZUI_ARGS} ]]; then
    tmpl="${(j: :)_ZUI_ARGS}"
  fi
  [[ -z $tmpl ]] && { _zui_err "no template provided"; return 2; }
  if (( ${_ZUI_OPT[strip-ansi]:-0} )) && (( ! ${_ZUI_OPT[no-strip-ansi]:-0} )); then
    _zui_strip_ansi "$tmpl"; tmpl=$REPLY
  fi

  case $type in
    (emoji)
      _zui_fmt_emoji "$tmpl"; print -r -- "$REPLY"; return 0 ;;
    (markdown|md)
      _zui_fmt_markdown "$tmpl"; print -r -- "$REPLY"; return 0 ;;
    (code)
      _zui_fmt_code "$tmpl"; print -r -- "$REPLY"; return 0 ;;
    (template) ;;
    (*) _zui_err "unsupported --type '$type' (use template, markdown, code or emoji)"; return 2 ;;
  esac

  local -a args=("${_ZUI_ARGS[@]}")
  local kv k v rep
  for kv in "${args[@]}"; do
    if [[ $kv != *=* ]]; then
      _zui_err "expected key=value, got '$kv'"; return 2
    fi
    k=${kv%%=*}; v=${kv#*=}
    [[ -z $k ]] && { _zui_err "empty key in '$kv'"; return 2; }
    rep=$v
    tmpl=${tmpl//"{{.$k}}"/$rep}
    tmpl=${tmpl//"{{ .$k }}"/$rep}
    tmpl=${tmpl//"{{.$k }}"/$rep}
    tmpl=${tmpl//"{{ .$k}}"/$rep}
  done

  if (( ${_ZUI_OPT[strict]:-0} )) && [[ $tmpl == *'{{'*'}}'* ]]; then
    _zui_err "unresolved placeholder in template"
    return 2
  fi
  print -r -- "$tmpl"
}

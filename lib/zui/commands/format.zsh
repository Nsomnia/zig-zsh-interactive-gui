# zui format

_ZUI_OPTDEF_format=(
  '|template|str|Template containing {{.Fields}}|'
  '|file|str|Read the template from a file|'
  '|strict|flag|Fail when a placeholder is left unresolved|0'
)

_ZUI_CMD_DESC[format]="Substitute {{.Fields}} in a template."
_ZUI_CMD_USAGE[format]="zui format [flags] [key=value...]"
_ZUI_CMD_LONG[format]="A tiny, dependency-free template renderer for shell scripts.  Fields use Go-template spelling: {{.Name}} or {{ .Name }}.  Values are passed as key=value arguments, so no quoting surprises are introduced."
_ZUI_EXAMPLES[format]=$'zui format --template "Hello, {{.Name}}!" Name=Ada\nprintf \'{{.Project}} v{{.Version}}\' > tmpl; zui format --file tmpl Project=zui Version=0.1.0\nzui format --strict --template "{{.A}}{{.B}}" A=1'
_ZUI_NOTES[format]=$'With --strict, any {{...}} placeholder that remains after substitution is an error (exit 2).\nWhen no template is given, stdin is used.'

_zui_cmd_format() {
  local tmpl=${_ZUI_OPT[template]:-}
  if [[ -z $tmpl && -n ${_ZUI_OPT[file]:-} ]]; then
    [[ -r ${_ZUI_OPT[file]} ]] || { _zui_err "cannot read '${_ZUI_OPT[file]}'"; return 2; }
    tmpl=$(<"${_ZUI_OPT[file]}")
  fi
  if [[ -z $tmpl && ! -t 0 ]]; then tmpl=$(cat); fi
  [[ -z $tmpl ]] && { _zui_err "no template provided"; return 2; }

  local -a args=("${_ZUI_ARGS[@]}")
  local kv k v pat rep
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

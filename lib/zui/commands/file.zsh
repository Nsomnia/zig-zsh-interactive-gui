# zui file

_ZUI_OPTDEF_file=(
  '|path|str|Starting directory or file|'
  '|start|str|Starting directory or file (alias for --path)|'
  'c|cursor|str|Character drawn before the focused row|>'
  'a|all|flag|Show hidden entries|0'
  '|show-hidden|flag|Show hidden entries|0'
  'p|permissions|flag|Show file permissions|0'
  's|size|flag|Show file sizes|0'
  '|file|flag|Allow files to be selected|0'
  '|directory|flag|Allow directories to be selected|0'
  '|height|int|Number of visible rows (0 = fit content)|12'
  '|header|str|Title shown in the dialog title bar|File'
  '|timeout|str|Close with exit 124 after a duration|'
  '|width|int|Dialog width in columns (0 = automatic)|0'
  '|border|str|Border: auto, rounded, sharp, double, thick, ascii, none|auto'
  "${_ZUI_DIALOGDEF[@]}"
  "${_ZUI_PADDINGDEF[@]}"
)
_ZUI_CMD_DESC[file]="Browse directories and pick a file or directory."
_ZUI_CMD_USAGE[file]="zui file [flags] [start]"
_ZUI_CMD_LONG[file]="A directory browser. Enter opens directories and selects files; Right opens a directory and Left goes to the parent. With --directory, Enter selects the highlighted directory (use Right to descend). Hidden entries are skipped unless --all/--show-hidden is given; --permissions and --size add metadata to each row."
_ZUI_KEYMAP[file]=$'↑/↓|Move the cursor\nEnter|Open a directory or select an entry\nRight|Open the highlighted directory\nLeft|Go to the parent directory\ntype|Filter entries\nTab|Focus the buttons\nEsc|Cancel'
_ZUI_EXAMPLES[file]=$'file=$(zui file --header "Open project")\ndir=$(zui file --directory --header "Choose an output directory")\nzui file --all --path ~/Projects\nzui file --permissions --size --header "Pick a binary"'
_ZUI_NOTES[file]=$'The selected path is always printed as an absolute path, even when you started from a relative directory.\nBy default only files are selectable; --directory makes directories selectable too.\n--cursor sets the cursor glyph; --path sets the starting directory.'

typeset -g  _zui_file_dir=""
typeset -gi _zui_file_sel_dirs=0 _zui_file_sel_files=1
typeset -gi _zui_file_hidden=0 _zui_file_perms=0 _zui_file_size=0
typeset -ga _zui_file_names=() _zui_file_kinds=() _zui_file_labels=()

_zui_file_hsize() { # bytes -> REPLY 12K / 3.4M
  local n=$1
  if (( n >= 1048576 )); then printf -v REPLY '%.1fM' $(( n / 1048576.0 ))
  elif (( n >= 1024 )); then printf -v REPLY '%dK' $(( n / 1024 ))
  else REPLY=$n; fi
}

_zui_file_meta() { # path -> REPLY optional "mode size " prefix
  (( _zui_file_perms || _zui_file_size )) || { REPLY=""; return; }
  local -a f
  f=(${(s: :)${$(command ls -ld -- "$1" 2>/dev/null)[1]}})
  [[ -z ${f[1]:-} ]] && { REPLY=""; return; }
  local out=""
  (( _zui_file_perms )) && out="${f[1]}  "
  if (( _zui_file_size )); then
    _zui_file_hsize ${f[5]:-0}
    out+="${(l:5:: :)REPLY}  "
  fi
  REPLY=$out
}

_zui_file_show() {
  local d=$_zui_file_dir
  _zui_file_names=(); _zui_file_kinds=(); _zui_file_labels=()
  if (( _zui_file_sel_dirs )); then
    _zui_file_names+=("."); _zui_file_kinds+=("curr"); _zui_file_labels+=(".")
  fi
  if [[ $d != / ]]; then
    _zui_file_names+=(".."); _zui_file_kinds+=("up"); _zui_file_labels+=("..")
  fi
  local -a dirs files
  if (( _zui_file_hidden )); then
    dirs=("$d"/*(DN/))
    files=("$d"/*(DN))
  else
    dirs=("$d"/*(N/))
    files=("$d"/*(N))
  fi
  dirs=(${(o)dirs}); files=(${(o)files})
  local p n
  for p in "${dirs[@]}"; do
    n=${p:t}
    [[ $n == ('.'|'..') ]] && continue
    _zui_file_meta "$p"
    _zui_file_names+=("$n/"); _zui_file_kinds+=("dir")
    _zui_file_labels+=("$REPLY$n/")
  done
  for p in "${files[@]}"; do
    [[ -d $p ]] && continue
    n=${p:t}
    [[ $n == ('.'|'..') ]] && continue
    _zui_file_meta "$p"
    _zui_file_names+=("$n"); _zui_file_kinds+=("file")
    _zui_file_labels+=("$REPLY$n")
  done

  _zui_list_items=("${_zui_file_names[@]}")
  _zui_list_labels=("${_zui_file_labels[@]}")
  _zui_list_filter=""
  _zui_list_active_filter=0
  _zui_list_build
  _zui_list_cursor=1
  _zui_dlg[message]=$_zui_file_dir
  _zui_dlg[list_h]=$(( ${#_zui_file_names} < ${_zui_file_limit:-12} ? ${#_zui_file_names} : ${_zui_file_limit:-12} ))
  (( _zui_dlg[list_h] < 1 )) && _zui_dlg[list_h]=1
}

_zui_file_focused() { # sets REPLY name, _zui_file_kind
  local raw=${_zui_list_view_raw[_zui_list_cursor]:-}
  [[ -z $raw ]] && { REPLY=""; _zui_file_kind=""; return 1; }
  REPLY=${_zui_file_names[raw]}
  _zui_file_kind=${_zui_file_kinds[raw]}
}

_zui_file_go() { # path
  local p=$1
  [[ -d $p ]] || return 1
  _zui_file_dir=${p:A}
  _zui_file_show
  _zui_list_show_filter=0
  return 0
}

# Called from the dialog loop; 0 = handled, 1 = let the dialog act.
_zui_file_key_hook() {
  local name kind
  _zui_file_focused || return 1
  name=$REPLY kind=$_zui_file_kind
  case $KEY in
    (RIGHT)
      if [[ $kind == dir || $kind == up ]]; then
        [[ $kind == up ]] && _zui_file_go "${_zui_file_dir:h}" || _zui_file_go "${_zui_file_dir%/}/${name%/}"
        return 0
      fi ;;
    (LEFT|CTRL_H)
      _zui_file_go "${_zui_file_dir:h}"; return 0 ;;
    (ENTER)
      if [[ $kind == curr ]]; then return 1
      elif [[ $kind == up ]]; then
        _zui_file_go "${_zui_file_dir:h}"; return 0
      elif [[ $kind == dir ]]; then
        # With --directory the highlighted directory is selectable; Right opens it.
        if (( _zui_file_sel_dirs )); then return 1; fi
        _zui_file_go "${_zui_file_dir%/}/${name%/}"; return 0
      else
        (( _zui_file_sel_files )) && return 1
        return 0
      fi ;;
  esac
  return 1
}

_zui_file_path_of() { # display name -> REPLY absolute path
  local n=$1
  if [[ $n == '.' ]]; then
    REPLY=${_zui_file_dir:A}
  elif [[ $n == '..' ]]; then
    REPLY=${_zui_file_dir:A:h}
  elif [[ $n == */ ]]; then
    REPLY=${_zui_file_dir%/}/${n%/}
  else
    REPLY=${_zui_file_dir%/}/$n
  fi
  REPLY=${REPLY:A}
}

_zui_cmd_file() {
  _zui_dialog_reset
  local cursor=${_ZUI_OPT[cursor]:->}
  local start=${_ZUI_ARGS[1]:-${_ZUI_OPT[path]:-${_ZUI_OPT[start]:-}}}
  if [[ -z $start ]]; then
    start=.
    # Backwards compatibility: --cursor used to mean the starting path.
    if [[ -e ${_ZUI_OPT[cursor]:-} ]]; then start=${_ZUI_OPT[cursor]}; cursor=">"; fi
  fi
  _zui_file_hidden=0
  (( ${_ZUI_OPT[all]:-0} || ${_ZUI_OPT[show-hidden]:-0} )) && _zui_file_hidden=1
  _zui_file_perms=${_ZUI_OPT[permissions]:-0}
  _zui_file_size=${_ZUI_OPT[size]:-0}
  _zui_file_sel_dirs=${_ZUI_OPT[directory]:-0}
  _zui_file_sel_files=${_ZUI_OPT[file]:-0}
  # Default: files only.
  if (( ! _zui_file_sel_files && ! _zui_file_sel_dirs )); then _zui_file_sel_files=1; fi

  local select=""
  if [[ -d $start ]]; then
    _zui_file_dir=${start:A}
  elif [[ -e $start ]]; then
    _zui_file_dir=${start:A:h}
    select=${start:t}
  else
    _zui_file_dir=${PWD:A}
  fi

  local hl=${_ZUI_OPT[height]:-12}
  [[ $hl == <-> && $hl -gt 0 ]] || hl=12
  typeset -g _zui_file_limit=$hl

  _zui_file_show
  _zui_list_cursor_char=$cursor
  [[ -n $select ]] && { _zui_list_select_value "$select" || true; }
  [[ -n ${_ZUI_OPT[default-item]:-} ]] && { _zui_list_select_value "${_ZUI_OPT[default-item]}" || true; }

  _zui_dlg[widget]=list
  _zui_dialog_common
  _zui_dlg[height]=0
  _zui_dlg[title]=${_ZUI_OPT[header]:-File}
  _zui_dlg[message]=$_zui_file_dir
  _zui_dlg[hints]="↑↓ move  Enter open/select  ←→ dirs  Tab buttons"
  _zui_dlg[key_hook]=_zui_file_key_hook
  _zui_build_buttons "Select" "Cancel"

  _zui_dialog_run
  local rc=$?
  if (( rc == 0 && _ZUI_EMIT )) && [[ -n $_ZUI_OUT ]]; then
    _zui_file_path_of "$_ZUI_OUT"
    _zui_emit_out "$REPLY"
  fi
  return $rc
}

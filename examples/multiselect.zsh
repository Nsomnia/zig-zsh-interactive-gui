#!/usr/bin/env zsh
# Checklist with a selection limit, returned in selection order.
emulate -R zsh
source "${0:A:h:h}/lib/zui.zsh"

zui::begin
zui::widget checklist
zui::title "Release checklist"
zui::message "Pick up to three steps."
zui::items tests docs package publish announce
zui::selected docs
zui::multi 1
zui::limit 3
zui::ordered 1
zui::button "Run" accept
zui::button "Cancel" cancel

if zui::run; then
  print -r -- "selected:"
  print -r -- "$ZUI_OUT"
else
  print -r -- "aborted"
fi

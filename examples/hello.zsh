#!/usr/bin/env zsh
# Minimal framework example: a framed input plus two action buttons.
emulate -R zsh
source "${0:A:h:h}/lib/zui.zsh"

zui::begin
zui::widget input
zui::title "Hello"
zui::message "What should we call you?"
zui::value "${USER:-friend}"
zui::placeholder "Your name"
zui::button "Greet" accept
zui::button "Cancel" cancel

if zui::run; then
  print -r -- "Hello, $ZUI_OUT!"
else
  print -r -- "No greeting today."
fi

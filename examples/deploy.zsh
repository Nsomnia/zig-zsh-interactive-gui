#!/usr/bin/env zsh
# CLI composition: confirm, choose a target, then show a dialog on completion.
emulate -R zsh
ZUI=${ZUI:-${0:A:h:h}/bin/zui}

"$ZUI" confirm --affirmative Deploy --negative Cancel "Deploy now?" || exit 1
target=$("$ZUI" choose --header "Target" staging production) || exit 1

"$ZUI" spin --title "Deploying to $target" -- sleep 2
"$ZUI" msgbox --icon success --title "Deployed" \
  --button "Done=exit:0" \
  "Release is live on $target."

# config.tape — shared VHS settings. Include from any tape with:  Source config.tape
# Keeps every terminal demo visually consistent. Every `Set` must come BEFORE the
# first Type/Enter/output command, so `Source` this at the very top of a tape.
Set Shell zsh
Set FontFamily "JetBrains Mono"   # must be installed locally; brew install --cask font-jetbrains-mono
Set FontSize 22
Set Width 1200
Set Height 700
Set Padding 40
Set Theme "Catppuccin Mocha"
Set TypingSpeed 55ms
Set WindowBar Colorful
Set BorderRadius 10
Set WaitTimeout 30s
# Bare `Wait` defaults to matching a ">" prompt. Our demos set PS1='$ ', so tell
# Wait to match that prompt instead — otherwise a bare `Wait` times out.
Set WaitPattern /\$\s?$/

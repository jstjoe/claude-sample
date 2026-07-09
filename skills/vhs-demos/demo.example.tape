# demo.example.tape — template for a VHS terminal demo.
#
# Render it:  vhs demo.example.tape          (writes the Output files below)
# Validate:   vhs validate demo.example.tape (parse only, no render)
# Copy this into your project (e.g. demo/tour.tape), edit the Type lines, render.
#
# RULES THAT BITE:
#  - Every `Set` must come BEFORE the first Type/Enter/Output-producing command.
#    Only `Set TypingSpeed` may change mid-tape. `Source` a shared config first.
#  - Prefer `Wait` over guessed `Sleep` for anything nondeterministic (installs,
#    builds, network). Keep short Sleeps only for reading pace.
#  - The font in `Set FontFamily` must be installed locally or VHS silently
#    falls back to a different font.

Output demo.gif
Output demo.mp4

Source config.tape        # shared Set block (theme, size, font, typing speed)

# --- hidden setup: deterministic prompt + clean screen (not recorded) ---
Hide
Type "export PS1='$ '" Enter
Type "cd $(mktemp -d)" Enter
Type "clear" Enter
Show

# --- visible demo ---
Type "echo 'Widget CLI — quick tour'" Enter
Sleep 800ms

Type "widget --version" Enter
Sleep 600ms

Type@40ms "widget create --name demo --region us-east" Enter
Wait+Screen /created/           # wait for the tool to print success, not a fixed sleep
Sleep 1s

Screenshot created.png          # still frame for docs/Slack

Type "widget list" Enter
Sleep 2s

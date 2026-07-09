# demo/tour.tape — a short VHS tour of this repo's demo tooling.
# Render:  vhs demo/tour.tape   (run from the repo root)
Output demo-out/tour.gif
Output demo-out/tour.mp4

Source demo/config.tape        # shared look: Catppuccin Mocha, JetBrains Mono, WaitPattern for `$ `

# --- hidden setup: deterministic prompt + clean screen (not recorded) ---
Hide
Type "export PS1='$ '" Enter
Type "clear" Enter
Show

# --- visible demo ---
Type "echo 'claude-sample - demo tooling tour'" Enter
Sleep 800ms

Type "ls skills/" Enter
Wait
Sleep 1s

Type "vhs --version" Enter
Wait
Sleep 700ms

Screenshot demo-out/tour-frame.png     # grab a still mid-tape

Type "ls demo/" Enter
Wait
Sleep 1400ms

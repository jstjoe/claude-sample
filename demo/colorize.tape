# demo/colorize.tape — coloring & redaction in a VHS terminal demo.
#
# VHS has no highlighter of its own; it records whatever ANSI the shell prints.
# So we source the vhs-demos skill's mutate.sh (defines `hi`, `paint`, `redact`)
# and pipe output through it. Self-contained + deterministic (no network) — the
# lines are echoed, so it renders the same every time.
#
#   vhs demo/colorize.tape        -> demo-out/colorize.gif
Output demo-out/colorize.gif

Source demo/config.tape

# --- hidden setup: prompt, load the mutators, declare what's sensitive ---
Hide
Type "export PS1='$ '" Enter
Type "setopt interactive_comments" Enter                        # zsh: let `# …` narration be a comment, not a command
Type ". skills/vhs-demos/mutate.sh" Enter                       # defines hi / paint / redact
Type "export HL_SENSITIVE='Ada Lovelace|88213-A|metformin|500mg'" Enter   # raw PII -> red
Type "clear" Enter
Show

# --- raw record: the PII a downstream service would see (red) ---
Type "# raw record — sensitive values in red" Enter
Type@30ms `echo 'Patient Ada Lovelace, MRN 88213-A, on metformin 500mg.' | hi` Enter
Wait
Sleep 1500ms

# --- same record de-identified: [BRACKETED] tokens auto-highlight green ---
Enter
Type "# de-identified — [TOKENS] in green (HL_TOKENS default)" Enter
Type@30ms `echo 'Patient [NAME_a1b2], MRN [HEALTHCARE_NUMBER_c3d4], on [DRUG_e5f6] [DOSE_g7h8].' | hi` Enter
Wait
Sleep 1500ms

# --- redact a secret to block glyphs before the frame is shared ---
Enter
Type "# redact a secret on camera (████) — see demo-media for hard, post-hoc redaction" Enter
Type@30ms `echo 'export API_KEY=sk-live-4c9f2a7b91d0' | redact 'sk-[a-z0-9-]+'` Enter
Wait
Sleep 2500ms

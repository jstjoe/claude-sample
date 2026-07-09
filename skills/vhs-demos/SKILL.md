---
name: vhs-demos
description: >
  Record terminal demos as GIF/MP4/WebM from a declarative .tape script with VHS
  (charmbracelet/vhs). Use when the user wants a reproducible, scriptable
  terminal recording — a CLI walkthrough, a README GIF, a command-line tour — that
  re-renders identically instead of a one-take screen capture. Covers the full
  .tape language (Type, Enter, key combos, Sleep, Wait, Hide/Show, Screenshot,
  Set, Source, Output), themes, deterministic-output best practices, and the
  vhs CLI (render, new, record, validate, publish, themes). Ships a shared
  config.tape and a demo.example.tape template. Triggers on: "VHS", ".tape",
  "record a terminal demo", "terminal GIF", "CLI walkthrough GIF", "charmbracelet
  vhs", "scripted terminal recording", "README terminal demo".
metadata:
  tags: vhs, terminal, tape, gif, mp4, cli, demo, charmbracelet
---

# VHS terminal demos

VHS records a terminal session to **GIF / MP4 / WebM / PNG** from a declarative
`.tape` script — you write the keystrokes, VHS types them into a headless
terminal and encodes the frames. Unlike a live screen capture, a `.tape`
**re-renders identically** every time: perfect for README GIFs and CLI tours
that must stay in sync with the tool.

Verified against **VHS 0.11**. Pairs with **demo-media** (edit/convert the output)
and **playwright-demos** (the browser equivalent).

## Setup

```bash
brew install vhs            # pulls its runtime deps: ttyd + ffmpeg
brew install --cask font-jetbrains-mono   # the font this skill's config.tape uses
vhs --version               # verify
```

`ttyd` and `ffmpeg` must both be on `$PATH` (Homebrew installs them as deps). The
font named in `Set FontFamily` must be **installed locally** or VHS silently
falls back to another font — install it before recording.

## This skill ships two files

- **`config.tape`** — a shared `Set` block (shell, theme, size, font, typing speed,
  `WaitPattern`). `Source config.tape` at the top of any tape for a consistent look.
- **`demo.example.tape`** — a full template: sources config, hides deterministic
  setup, runs a multi-step CLI demo, grabs a screenshot. Copy it into your project.

```bash
cp ~/.claude/skills/vhs-demos/{config.tape,demo.example.tape} demo/
cd demo && $EDITOR demo.example.tape && vhs demo.example.tape
```

## The `.tape` language

One command per line; `#` starts a comment. **Every `Set` must come before the
first typing/output command** — only `Set TypingSpeed` may change mid-tape.

### Output & Require
```tape
Output demo.gif          # format inferred from extension: .gif .mp4 .webm .png
Output demo.mp4          # multiple Output lines → render several formats at once
Require git              # assert a binary is on PATH before running (put at top)
```
(`.ascii` / `.txt` outputs write plain-text golden files — handy for diffing in CI.)

### Set — the settings that matter
```tape
Set Shell zsh                     # default bash
Set FontFamily "JetBrains Mono"   # must be installed locally
Set FontSize 22
Set Width 1200                    # video width px
Set Height 700
Set Padding 40                    # inner padding
Set Theme "Catppuccin Mocha"      # name from `vhs themes`, or inline base16 JSON
Set TypingSpeed 55ms              # per-keystroke delay (the only Set changeable mid-tape)
Set PlaybackSpeed 1.0             # 0.5 slower / 2.0 faster output
Set WindowBar Colorful            # macOS-style titlebar: Colorful|ColorfulRight|Rings|RingsRight
Set BorderRadius 10
Set Framerate 60                  # capture fps (default 50)
Set LoopOffset 20%                # where the GIF loop starts
Set WaitTimeout 30s               # default timeout for `Wait`
Set WaitPattern /\$\s?$/          # default regex `Wait` matches (default matches a ">" prompt)
Set MarginFill "#6B50FF"          # margin color OR a background image path
```

### Typing & keys
```tape
Type "echo hello"                 # type a string
Type `git commit -m "msg"`        # backtick-quote to embed double quotes
Type@10ms "fast boilerplate"      # per-command typing speed override
Enter                             # named keys: Enter Backspace Delete Tab Space Escape
Enter 2                           # Up Down Left Right PageUp PageDown Insert
Backspace 18                      # optional repeat count
Tab@500ms 2                       # keys also take @time and count
Ctrl+R                            # modifiers: Ctrl+ Alt+ Shift+ (combinable: Ctrl+Alt+Shift+A)
ScrollDown@100ms 12               # ScrollUp / ScrollDown
```

### Timing, waiting, visibility
```tape
Sleep 500ms                       # fixed pause: ms | s (or bare seconds: Sleep 2)
Wait                              # wait for output to match WaitPattern (beats a guessed Sleep)
Wait+Screen@30s /Done/            # match anywhere on screen, custom timeout + regex
Hide                              # stop recording frames (setup still executes)
Show                              # resume recording
```

### Capture, clipboard, scripting
```tape
Screenshot frame.png              # capture the current frame to PNG mid-tape
Copy "text"                       # put text on the clipboard; Paste inserts it
Paste
Source config.tape                # include another tape (shared Set config)
Env KEY "value"                   # set an env var for the shell session
```

## CLI usage

```bash
vhs demo.tape                     # render its Output(s)
vhs demo.tape -o out.gif          # add/override an output path (repeatable -o)
cat demo.tape | vhs               # read tape from stdin
vhs new tour                      # scaffold tour.tape with commented examples
vhs record > tour.tape            # interactively record your keystrokes into a tape
vhs validate demo.tape            # parse only, don't render (fast CI check)
vhs themes                        # list every theme name
vhs publish demo.gif              # upload to vhs.charm.sh, print a shareable URL
```
(There is **no `vhs cat`** subcommand — use `cat file.tape`.)

Good dark themes for demos: **Catppuccin Mocha**, **Dracula**, **TokyoNight**,
**Nord**, **GitHub Dark**. Run `vhs themes` for the full list.

## Best practices for clean, deterministic demos

- **Fix the prompt in a `Hide`/`Show` block** so output is reproducible and setup
  stays off camera:
  ```tape
  Hide
  Type "export PS1='$ '" Enter
  Type "cd $(mktemp -d)" Enter
  Type "clear" Enter
  Show
  ```
  If you change the prompt like this, set `WaitPattern` to match it (this skill's
  `config.tape` sets `/\$\s?$/`) or a bare `Wait` will time out looking for `>`.
- **`Wait` beats a guessed `Sleep`** for anything nondeterministic — installs,
  builds, network. `Wait+Screen /Done/`. Keep short `Sleep`s only for reading pace.
- **Pin the frame**: `Source config.tape` so every demo shares width/height/theme/font.
- **Determinism**: pin tool versions, set `Env` for anything that affects output,
  disable spinners/timestamps. Commit a `.txt` `Output` as a golden file to catch drift.
- **`TypingSpeed`** ~50–100ms reads naturally; `Type@10ms` for long boilerplate.

## → Editing & branding

The MP4/GIF VHS emits is ready to share. For further trimming, cropping, speed
changes, or PII redaction use **demo-media**; to wrap it in branded titles/motion,
**remotion-best-practices**.

## Gotchas

- **Hard deps on `ttyd` + `ffmpeg`** — missing/incompatible versions are the #1
  failure. In CI use the official Docker image or `charmbracelet/vhs-action`.
- **Fonts must be installed** locally; `Set FontFamily` silently falls back otherwise.
- **`Set` ordering**: any `Set` except `TypingSpeed` after a non-`Set` command is
  ignored — keep all config at the top (or in a `Source`d config).
- **Bare `Wait` matches a `>` prompt by default** — set `WaitPattern` for other prompts.
- **`publish`/`serve` send data over the network** (vhs.charm.sh / your SSH server) —
  don't publish security-sensitive demos.
- Escape double quotes inside `Type` with backtick-quoted strings.

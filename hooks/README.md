# Personal hooks

Hooks that should run in **every** project, version-controlled here so they stay
in sync across machines. `../install.sh` symlinks each `*.sh` in this directory
into `~/.claude/hooks/`.

## Two homes, same as skills

- **`hooks/`** (this directory) — personal hooks linked into `~/.claude/hooks/`
  and wired up in your global `~/.claude/settings.json`. They apply everywhere.
- **`.claude/hooks/`** — hooks scoped to this repo only, wired up in
  `.claude/settings.json`. See [../.claude/hooks/README.md](../.claude/hooks/README.md)
  for how hooks work, the available events, and the exit-code contract.

## Wiring one up

The installer links the scripts but never edits your settings file, because a
hook runs a shell command on every matching event and that belongs to you. Add
the entry yourself in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/writing-style.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

## Hooks here

- **writing-style.sh** — a `UserPromptSubmit` hook that injects the core rules
  from the `writing-for-humans` skill into every turn. The skill holds the full
  guidance and examples, and the hook holds the short version that needs to be
  present whether or not the skill has been loaded.

# `.claude/` — project config for this repo

Everything in here configures Claude Code **when this repo is the working
directory**. It's committed and shared, so anyone who clones the repo (or opens
it in a cloud environment) gets the same setup.

This is separate from `~/.claude/` (your global, machine-wide config) and from
the repo's top-level [`skills/`](../skills/) directory (see below).

## Layout

```
.claude/
  settings.json          # shared project settings (committed) — permissions, hooks, env
  settings.local.json    # personal overrides (gitignored) — never committed
  commands/              # slash commands → /name          (one .md per command)
  agents/                # subagents the Agent tool can spawn (one .md per agent)
  hooks/                 # hook scripts, wired up in settings.json "hooks"
  skills/                # skills scoped to THIS project only
```

Each subdir has a `README.md` with the file format and a copy-paste template.

## Settings precedence (highest wins)

1. Enterprise managed policy
2. `.claude/settings.local.json`  ← your personal, per-machine overrides (gitignored)
3. `.claude/settings.json`         ← shared project settings (committed here)
4. `~/.claude/settings.json`       ← your global settings

## Skills: two homes, on purpose

- **Top-level [`skills/`](../skills/)** is the *canonical library* — personal
  skills version-controlled here and symlinked into `~/.claude/skills/` by
  `./install.sh` so they're live in **every** project on this machine.
- **`.claude/skills/`** is for skills that only make sense **inside this repo**.
  Claude Code auto-discovers these when working here, no install step.

Rule of thumb: reusable-everywhere → top-level `skills/`; repo-specific →
`.claude/skills/`.

## Adding things

- New command: drop `commands/foo.md` → run `/foo`.
- New agent: drop `agents/foo.md` → the Agent tool can spawn `foo`.
- New hook: add a script in `hooks/`, reference it from `settings.json` `"hooks"`.
- Change settings: edit `settings.json` (shared) or `settings.local.json` (just you).

A project `CLAUDE.md` at the repo root is the other half of project config —
run `/init` to generate one.

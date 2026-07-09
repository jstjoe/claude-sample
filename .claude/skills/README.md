# Project skills

Skills that only make sense **inside this repo**. Claude Code auto-discovers
them when this is the working directory — no install step, no symlink.

For skills you want live in **every** project on this machine, use the top-level
[`skills/`](../../skills/) library instead (it's symlinked into `~/.claude/skills/`
by `./install.sh`). See [`../README.md`](../README.md#skills-two-homes-on-purpose).

## Format

One directory per skill, holding a `SKILL.md` (plus any supporting files):

```
.claude/skills/
  my-skill/
    SKILL.md
    helper.sh        # optional supporting scripts/files
```

## `SKILL.md` frontmatter

```markdown
---
name: my-skill
description: >
  What it does + WHEN to use it. This is the trigger — pack it with the phrases
  and situations that should invoke the skill. Triggers on: "...", "...".
---

# My Skill

Instructions, recipes, and any commands. Point to supporting files by relative
path; keep the main file lean and push detail into references the model loads
on demand.
```

The `description` is everything — it decides whether the skill fires. Be
specific about the task and include concrete trigger phrases.

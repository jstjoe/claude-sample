# Slash commands

One `.md` file per command. `commands/deploy.md` → `/deploy`. Subdirs namespace:
`commands/db/reset.md` → `/db:reset`. The file **body is the prompt** Claude runs;
frontmatter is optional metadata.

## Frontmatter fields (all optional)

```markdown
---
description: One-line summary shown in the /help list and autocomplete
argument-hint: <branch> [--force]      # shown after the command name while typing
allowed-tools: Bash(git status:*), Read, Edit   # restrict what the command may call
model: claude-opus-4-8                 # override the model for this command
disable-model-invocation: false        # true = user-only, hide from the model
---
```

## Dynamic body

- `$ARGUMENTS` — everything typed after the command.
- `$1`, `$2`, … — positional args.
- `` !`command` `` — run a bash command and inline its output into the prompt
  (needs `allowed-tools` permission for that command).
- `@path/to/file` — inline a file's contents.

## Template — copy to `commands/<name>.md`

```markdown
---
description: Summarize what changed on the current branch vs main
argument-hint: "[base-branch]"
allowed-tools: Bash(git diff:*), Bash(git log:*)
---
Summarize the changes on this branch compared to `${1:-main}`.

Diff stat:
!`git diff --stat ${1:-main}...HEAD`

Give a tight bulleted summary grouped by area, then flag anything risky.
```

Invoke: `/name arg1 arg2`.

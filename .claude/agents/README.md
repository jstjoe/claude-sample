# Subagents

One `.md` file per agent. The Agent tool (and FleetView) can spawn these by name.
An agent runs in its **own context window** with its own system prompt and tool
set — use them to isolate big searches/reviews and keep the main thread clean.

## Frontmatter

```markdown
---
name: test-runner                 # the id used to spawn it (kebab-case)
description: >                    # WHEN to use it — this is how it gets auto-selected.
  Use PROACTIVELY after code changes to run the suite and triage failures.
  Include trigger phrases and example situations.
tools: Read, Bash, Grep, Glob     # optional; omit to inherit all tools
model: sonnet                     # optional: sonnet | opus | haiku | fable | inherit
---
```

The **body is the agent's system prompt** — role, method, output format, rules.

## Writing a good `description`

It's the trigger. Be concrete about *when* to reach for the agent and include
example situations; add "use PROACTIVELY" if it should fire without being asked.
A vague description means the agent never gets picked.

## Template — copy to `agents/<name>.md`

```markdown
---
name: pr-reviewer
description: >
  Review a diff for correctness bugs and risky changes. Use after finishing a
  feature and before opening a PR, or when the user asks for a code review.
tools: Read, Grep, Glob, Bash
model: inherit
---
You are a focused code reviewer. Given the current diff:

1. Read the changed files and enough surrounding code to judge correctness.
2. Report only high-confidence findings, most severe first.
3. For each: file:line, the concrete failure scenario, and a suggested fix.

Do not rewrite the code. Be terse. If nothing is wrong, say so.
```

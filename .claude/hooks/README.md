# Hooks

Hooks run **your** shell commands on Claude Code lifecycle events — the harness
executes them, not the model. Put the scripts here; wire them up in
`../settings.json` under `"hooks"`.

## Events

`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`,
`SessionStart`, `SessionEnd`, `PreCompact`, `Notification`.

## Wiring (in `.claude/settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/guard.sh\"" }
        ]
      }
    ]
  }
}
```

- `matcher` — tool name / regex the event must match (omit for events without tools).
- `$CLAUDE_PROJECT_DIR` — absolute repo root; use it so paths work from any cwd.
- The hook receives event JSON on **stdin**.

## Exit codes (PreToolUse)

- `0` — allow.
- `2` — **block** the tool call; stderr is shown to the model as feedback.
- other non-zero — non-blocking error.

JSON on stdout can also return structured decisions (`{"decision":"block","reason":"..."}`).

## Template — copy to `hooks/<name>.sh`, `chmod +x`

```bash
#!/usr/bin/env bash
# Block `rm -rf` in Bash tool calls.
set -euo pipefail
input="$(cat)"                                  # event JSON on stdin
cmd="$(printf '%s' "$input" | /usr/bin/python3 -c 'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"
if printf '%s' "$cmd" | grep -qE 'rm +-[a-z]*r[a-z]* +-?f?|rm +-rf'; then
  echo "Blocked: refusing rm -rf. Delete specific paths instead." >&2
  exit 2
fi
exit 0
```

The `update-config` skill can add/troubleshoot hooks for you ("when Claude stops, run X").

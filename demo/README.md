# demo/ — a worked Playwright browser demo

A self-contained example for the **playwright-demos** skill: a fake "Vault Console"
web app and a scripted flow that records a walkthrough of it.

```
demo/
  app.html    a single-file web app (no network) — search a customer, open the detail drawer
  flow.mjs    the scripted flow: browse → search → open record, with cursor glides + hovers
```

## Run it

```bash
# 1. serve the app (any static server; it listens on :8123, which flow.mjs targets)
python3 -m http.server 8123 --directory demo &

# 2. record — outputs land in ./demo-out/ (gitignored)
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --gif

# 3. stop the server
kill %1
```

Drop `--headless` for a real window; it defaults to headed. See
[`../skills/playwright-demos/SKILL.md`](../skills/playwright-demos/SKILL.md) for the
full recorder reference and [`../docs/automated-demos.md`](../docs/automated-demos.md)
for where this fits in the pipeline.

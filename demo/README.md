# demo/ — worked examples for the demo-recording skills

Self-contained examples for **playwright-demos** (browser) and **vhs-demos**
(terminal). All outputs land in `../demo-out/` (gitignored).

```text
demo/
  app.html         a single-file web app (no network) — search a customer, open the detail drawer
  flow.mjs         Playwright flow: browse → search → open record, with cursor glides + hovers
  config.tape      shared VHS look (Catppuccin Mocha, JetBrains Mono, WaitPattern for `$ `)
  tour.tape        VHS terminal tour of this repo's tooling (real commands, deterministic)
  curl-demo.tape   VHS proof it runs a real shell — a live `curl … | jq` over the network
```

## Browser demo (playwright-demos)

```bash
# 1. serve the app (any static server; it listens on :8123, which flow.mjs targets)
python3 -m http.server 8123 --directory demo &

# 2. record — outputs land in ./demo-out/ (gitignored)
node skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --gif

# 3. stop the server
kill %1
```

Drop `--headless` for a real window; it defaults to headed.

## Terminal demo (vhs-demos)

```bash
vhs demo/tour.tape        # → demo-out/tour.{gif,mp4}   (run from the repo root)
vhs demo/curl-demo.tape   # → demo-out/curl-demo.gif    (makes a live network call)
```

Run from the repo root so `Source demo/config.tape` and the `Output demo-out/…`
paths resolve. `curl-demo.tape` hits a live API, so its output changes run to run —
for a byte-identical README GIF, point a tape at a fixed fixture instead.

See [`../skills/playwright-demos/SKILL.md`](../skills/playwright-demos/SKILL.md) and
[`../skills/vhs-demos/SKILL.md`](../skills/vhs-demos/SKILL.md) for the full skill
references, and [`../docs/automated-demos.md`](../docs/automated-demos.md) for where
these fit in the pipeline.

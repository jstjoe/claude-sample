// flow.example.mjs — template for a playwright-record.mjs --flow module.
//
// Copy this into your project (e.g. demo/flow.mjs), edit the steps, then:
//   node ~/.claude/skills/playwright-demos/playwright-record.mjs --flow demo/flow.mjs --mp4 --gif
//
// The recorder default-imports this module and calls it with a context object:
//   page     Playwright Page (video is already recording)
//   context  BrowserContext
//   step     async (label, fn) => runs fn, logs the label, holds --pause after
//   chapter  async (title, {description, duration}) => full-screen narration card (screencast mode)
//   shot     async (name) => saves demo-out/<stamp>-<name>.png
//   move     async (locator | {x,y}) => glide the injected cursor to a target
//   log      (msg) => prints an indented progress line
//   args     the parsed CLI args (args.url, args.size, …)
//   devices  Playwright device descriptors
//
// The recorder injects an always-visible cursor (arrow + glide + click pulse) and
// per-action title overlays — you don't add those. But they only READ as a demo if
// the cursor visibly travels, so use move()/hover() to glide it and surface hover
// states before each click, rather than teleporting from click to click.
//
// Author steps by RECORDING them first, then pasting the generated selectors:
//   npx playwright codegen http://localhost:3000
// Prefer role/text/label locators (getByRole, getByText, getByLabel) over CSS —
// they survive restyles and read clearly in the recording.

export default async function demo({ page, step, chapter, shot, move, log, args }) {
  const url = args.url ?? 'http://localhost:3000';
  log(`Opening ${url}`);
  await page.goto(url, { waitUntil: 'networkidle' });

  await chapter('Widget Console', { description: 'Search, browse, drill in' });

  await step('Open the dashboard', async () => {
    const link = page.getByRole('link', { name: 'Dashboard' });
    await move(link);                 // cursor glides over before the click
    await link.click();
    await page.waitForLoadState('networkidle');
  });

  await step('Search for widgets', async () => {
    const q = page.getByPlaceholder('Search');
    await move(q);
    await q.fill('widgets');
    await page.keyboard.press('Enter');
    await page.getByText(/results/i).waitFor();       // wait on a real signal, not a fixed sleep
  });

  await shot('results');   // capture a still for docs/Slack alongside the video

  await step('Open the first result', async () => {
    const row = page.getByRole('row').nth(1);
    await row.hover();                // hover highlight, cursor visible on the row
    await row.click();
    await page.getByRole('heading').first().waitFor();
  });
}

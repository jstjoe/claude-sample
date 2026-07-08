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
//   log      (msg) => prints an indented progress line
//   args     the parsed CLI args (args.url, args.size, …)
//   devices  Playwright device descriptors
//
// In the default (screencast) recording mode the recorder already draws an
// animated cursor and a title overlay for each action — you don't add those.
//
// Author steps by RECORDING them first, then pasting the generated selectors:
//   npx playwright codegen http://localhost:3000
// Prefer role/text/label locators (getByRole, getByText, getByLabel) over CSS —
// they survive restyles and read clearly in the recording.

export default async function demo({ page, step, chapter, shot, log, args }) {
  const url = args.url ?? 'http://localhost:3000';
  log(`Opening ${url}`);
  await page.goto(url, { waitUntil: 'networkidle' });

  await chapter('Widget Console', { description: 'Search, browse, drill in' });

  await step('Open the dashboard', async () => {
    await page.getByRole('link', { name: 'Dashboard' }).click();
    await page.waitForLoadState('networkidle');
  });

  await step('Search for widgets', async () => {
    await page.getByPlaceholder('Search').fill('widgets');
    await page.keyboard.press('Enter');
    await page.getByText(/results/i).waitFor();       // wait on a real signal, not a fixed sleep
  });

  await shot('results');   // capture a still for docs/Slack alongside the video

  await step('Open the first result', async () => {
    await page.getByRole('row').nth(1).click();
    await page.getByRole('heading').first().waitFor();
  });
}

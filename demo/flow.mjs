// demo/flow.mjs — scripted walkthrough of the Vault Console demo app.
// Uses move() to glide the cursor + hover() to show hover states, so the
// pointer visibly travels around the page instead of teleporting to clicks.
export default async function demo({ page, step, chapter, shot, move }) {
  await page.goto('http://localhost:8123/app.html', { waitUntil: 'load' });

  await chapter('Vault Console', { description: 'Look up a customer, view tokenized data', duration: 1600 });

  await step('Browse the customer list', async () => {
    for (const name of ['Grace Hopper', 'Alan Turing']) {
      const row = page.getByRole('row', { name: new RegExp(name) });
      await row.hover();          // cursor glides over, hover highlight
      await page.waitForTimeout(350);
    }
  });

  await step('Search for a customer', async () => {
    const q = page.getByPlaceholder(/search customers/i);
    await move(q);
    await q.fill('Ada');
    const go = page.getByRole('button', { name: 'Search' });
    await go.hover();             // cursor glides across to the button
    await go.click();
    await page.getByText('1 customers').waitFor();
  });

  await step('Open the customer record', async () => {
    await page.getByText(/tok_4c1e/).hover();   // hover the tokenized card
    await page.waitForTimeout(300);
    const row = page.getByRole('row', { name: /Ada Lovelace/ });
    await row.click();                          // drawer slides in
    await page.getByRole('heading', { name: 'Ada Lovelace' }).waitFor();
  });

  await shot('customer-detail');
}

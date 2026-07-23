// Screenshot tool: renders the game at various states and saves PNGs to shots/.
// Usage: node tools/screenshot.mjs [scenario]
// Scenarios: title, create, game, dialogue, beat, all (default: all)
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = process.env.GAME_URL ?? 'http://127.0.0.1:4173/';
const OUT = 'shots';
mkdirSync(OUT, { recursive: true });

const scenario = process.argv[2] ?? 'all';

const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => {
  if (m.type() === 'error' || m.type() === 'warning') console.log(`[console.${m.type()}]`, m.text());
});
page.on('pageerror', (e) => console.log('[pageerror]', e.message));

await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(800);

async function shot(name) {
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log(`shot: ${OUT}/${name}.png`);
}

if (scenario === 'title' || scenario === 'all') {
  await shot('01_title');
}

if (scenario === 'create' || scenario === 'all') {
  await page.click('text=New Game');
  await page.waitForTimeout(500);
  await shot('02_create');
}

if (scenario === 'game' || scenario === 'all') {
  // Fill creation form
  if (scenario === 'all') {
    // already on create screen
  } else {
    await page.click('text=New Game');
    await page.waitForTimeout(400);
  }
  await page.fill('input.u-name-input', 'Alex Carter');
  await page.click('.u-id-card:first-child');
  await page.waitForTimeout(300);
  await shot('03_create_filled');
  await page.click('text=Arrive on campus');
  await page.waitForTimeout(1500);
  // The morning beat auto-presents
  await shot('04_first_beat');
  // Pick first choice
  await page.click('.u-choice:first-child');
  await page.waitForTimeout(500);
  await shot('05_reaction');
  await page.click('text=Continue');
  await page.waitForTimeout(1200);
  await shot('06_free_roam');
}

await browser.close();
console.log('done');

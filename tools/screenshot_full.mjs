// Full game flow screenshot tool
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = 'http://127.0.0.1:4173/';
const OUT = 'shots';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => { if (m.type() === 'error') console.log(`[err]`, m.text().slice(0, 120)); });

async function shot(name) {
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log(`  ${name}`);
}

console.log('Starting full game flow...');
await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(600);

// Title
await shot('01_title');

// Create
await page.click('text=New Game');
await page.waitForTimeout(400);
await shot('02_create');
await page.fill('input.u-name-input', 'Alex Carter');
await page.click('.u-id-card:first-child');
await page.waitForTimeout(200);
await shot('03_create_filled');
await page.click('text=Arrive on campus');
await page.waitForTimeout(1500);

// Beat 1 (morning)
await shot('04_morning_beat');
await page.click('.u-choice:first-child');
await page.waitForTimeout(400);
await shot('05_reaction');
await page.click('text=Continue');
await page.waitForTimeout(2000);

// Free roam (afternoon)
await shot('06_free_roam');

// Walk toward Jordan — press W for 1.5s to trigger proximity
await page.keyboard.down('KeyW');
await page.waitForTimeout(2200);
await page.keyboard.up('KeyW');
await page.waitForTimeout(400);
await shot('07_near_jordan');

// Auto-present beat 2
await page.waitForTimeout(4000);
await shot('08_afternoon_beat');
await page.click('.u-choice:first-child');
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(2000);

// Beat 3 (auto-presented)
await page.waitForTimeout(1500);
await shot('09_evening_beat');
await page.click('.u-choice:first-child');
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(2000);

// Beat 4 (auto-presented)
await page.waitForTimeout(1500);
await shot('10_night_beat');
await page.click('.u-choice:first-child');
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(2000);

// Tryout
await shot('11_tryout');

// Take shots
for (let i = 0; i < 5; i++) {
  await page.waitForTimeout(600);
  await page.click('text=SHOOT');
  await page.waitForTimeout(300);
}
await page.waitForTimeout(500);
await shot('12_recap');

await browser.close();
console.log('Done!');

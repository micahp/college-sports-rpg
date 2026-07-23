import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = 'http://127.0.0.1:4173/';
mkdirSync('shots', { recursive: true });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--disable-gpu-sandbox'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

async function s(n) {
  await page.screenshot({ path: `shots/${n}` });
  console.log(n);
}

await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);

// Create + play through fast
await page.click('text=New Game');
await page.waitForTimeout(300);
await page.fill('input.u-name-input', 'Alex');
await page.click('.u-id-card:first-child');
await page.waitForTimeout(100);
await page.click('text=Arrive on campus');
await page.waitForTimeout(1000);

const clickFirst = async () => {
  try { await page.click('.u-choice:first-child', { timeout: 3000 }); return true; } catch { return false; }
};

// Beat 1
await page.waitForTimeout(1200);
await clickFirst();
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(3000);

// Beat 2
await clickFirst();
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(3000);

// Beat 3
await clickFirst();
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(3000);

// Beat 4 (night)
await clickFirst();
await page.waitForTimeout(400);
await page.click('text=Continue');
await page.waitForTimeout(2000);

// Tryout!
await s('11_tryout.png');
console.log('Tryout captured');

// Click "Step to the line"
await page.click('text=Step to the line');
await page.waitForTimeout(600);

// Take 5 shots at random power levels
for (let i = 0; i < 5; i++) {
  await page.waitForTimeout(200 + Math.random() * 400);
  await page.click('text=SHOOT');
  await page.waitForTimeout(300);
}
await page.waitForTimeout(600);

// Recap
await s('12_recap.png');

await browser.close();
console.log('Done');

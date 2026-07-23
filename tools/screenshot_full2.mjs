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

async function waitBeat() {
  // Wait for a beat card to appear, up to 8s
  for (let i = 0; i < 16; i++) {
    const visible = await page.evaluate(() => {
      const el = document.querySelector('.u-choice');
      return el && window.getComputedStyle(el).display !== 'none';
    });
    if (visible) return;
    await page.waitForTimeout(500);
  }
  console.log('  (no beat appeared)');
}

async function clickFirstChoice() {
  const btn = page.locator('.u-choice').first();
  await btn.waitFor({ state: 'visible', timeout: 5000 });
  await btn.click();
}

async function clickContinue() {
  const btn = page.locator('text=Continue');
  await btn.waitFor({ state: 'visible', timeout: 5000 });
  await btn.click();
}

await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);

// Title
await s('01_title.png');

// Create
await page.click('text=New Game');
await page.waitForTimeout(400);
await s('02_create.png');
await page.fill('input.u-name-input', 'Alex');
await page.click('.u-id-card:first-child');
await page.waitForTimeout(100);
await s('03_create_filled.png');

// Start play
await page.click('text=Arrive on campus');
await page.waitForTimeout(800);

// Beat 1 appears shortly
await waitBeat();
await s('04_morning_beat.png');
await clickFirstChoice();
await page.waitForTimeout(300);
await s('05_reaction.png');
await clickContinue();
await page.waitForTimeout(500);

// Free roam (after period 1, afternoon)
await page.waitForTimeout(2500);
await s('06_free_roam.png');

// Beat 2 will auto-present after ~4s
await waitBeat();
await s('07_afternoon_beat.png');
await clickFirstChoice();
await page.waitForTimeout(300);
await clickContinue();
await page.waitForTimeout(500);

// Beat 3
await waitBeat();
await s('08_evening_beat.png');
await clickFirstChoice();
await page.waitForTimeout(300);
await clickContinue();
await page.waitForTimeout(500);

// Beat 4
await waitBeat();
await s('09_night_beat.png');
await clickFirstChoice();
await page.waitForTimeout(300);
await clickContinue();
await page.waitForTimeout(1000);

// Tryout!
await s('10_tryout.png');

// Start shooting
await page.click('text=Step to the line');
await page.waitForTimeout(800);

// Shoot 5 times
for (let i = 0; i < 5; i++) {
  await page.waitForTimeout(300 + Math.random() * 300);
  await page.click('text=SHOOT');
  await page.waitForTimeout(200);
}
await page.waitForTimeout(800);

// Recap
await s('11_recap.png');

await browser.close();
console.log('Done!');

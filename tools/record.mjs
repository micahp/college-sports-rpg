// Record a full playthrough video of The U using Playwright
import { chromium } from 'playwright';

const VIDEO_DIR = 'shots';
const BASE = 'http://127.0.0.1:4173/';

const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--disable-gpu-sandbox'],
});

const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  recordVideo: { dir: VIDEO_DIR, size: { width: 1280, height: 720 } },
});

const page = await context.newPage();

async function waitBeat() {
  for (let i = 0; i < 20; i++) {
    try {
      const visible = await page.evaluate(() => {
        const el = document.querySelector('.u-choice');
        return el && window.getComputedStyle(el).display !== 'none';
      });
      if (visible) return true;
    } catch {}
    await page.waitForTimeout(400);
  }
  return false;
}

async function clickChoice(n = 0) {
  const btns = page.locator('.u-choice');
  await btns.nth(n).waitFor({ state: 'visible', timeout: 5000 });
  await btns.nth(n).click();
}

async function clickContinue() {
  const btn = page.locator('text=Continue');
  await btn.waitFor({ state: 'visible', timeout: 5000 });
  await btn.click();
}

console.log('Navigating...');
await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(1200);

// Title screen — hold for a moment
console.log('Title screen');
await page.waitForTimeout(1500);

// New Game
await page.click('text=New Game');
await page.waitForTimeout(1000);

// Character creation
console.log('Character creation');
await page.waitForTimeout(600);
await page.fill('input.u-name-input', 'Alex Carter');
await page.waitForTimeout(400);
await page.click('.u-id-card:first-child');
await page.waitForTimeout(600);
await page.click('.u-id-card:nth-child(2)');
await page.waitForTimeout(800);
await page.click('.u-id-card:nth-child(1)');
await page.waitForTimeout(600);

// Start
await page.click('text=Arrive on campus');
console.log('Gameplay starting');
await page.waitForTimeout(1200);

// Beat 1: Morning — Move-In Day
await waitBeat();
await page.waitForTimeout(600);
await clickChoice(0);
await page.waitForTimeout(600);
await clickContinue();
await page.waitForTimeout(1000);

// Free roam — walk around a bit
console.log('Free roam');
await page.keyboard.down('KeyA');
await page.waitForTimeout(1200);
await page.keyboard.up('KeyA');
await page.keyboard.down('KeyD');
await page.waitForTimeout(2000);
await page.keyboard.up('KeyD');
await page.waitForTimeout(1500);

// Beat 2: Afternoon
await waitBeat();
await page.waitForTimeout(500);
await clickChoice(1); // open gym
await page.waitForTimeout(600);
await clickContinue();
await page.waitForTimeout(800);

// More walking
await page.keyboard.down('KeyW');
await page.waitForTimeout(1800);
await page.keyboard.up('KeyW');
await page.waitForTimeout(2500);

// Beat 3: Evening — Coach
await waitBeat();
await page.waitForTimeout(500);
await clickChoice(0);
await page.waitForTimeout(600);
await clickContinue();
await page.waitForTimeout(800);

// Walk toward Rec Center
await page.keyboard.down('KeyW');
await page.waitForTimeout(2000);
await page.keyboard.up('KeyW');
await page.waitForTimeout(2000);

// Beat 4: Night
await waitBeat();
await page.waitForTimeout(500);
await clickChoice(0);
await page.waitForTimeout(600);
await clickContinue();
await page.waitForTimeout(1500);

// Tryout!
console.log('Tryout');
await page.waitForTimeout(800);
await page.click('text=Step to the line');
await page.waitForTimeout(1000);

// Take 5 shots with varied timing
for (let i = 0; i < 5; i++) {
  await page.waitForTimeout(350 + Math.random() * 300);
  await page.click('text=SHOOT');
  await page.waitForTimeout(400);
}
await page.waitForTimeout(1200);

// Recap
console.log('Recap');
await page.waitForTimeout(1500);

await context.close();
await browser.close();
console.log('Video saved to shots/');

/**
 * Playwright verification for opacity fade-in entrance on 3D phone model.
 *
 * Verifies:
 *   1. Wrapper starts at opacity 0
 *   2. After model loads, wrapper fades to opacity 1
 *   3. Works correctly at multiple scroll positions (hero, mid, bottom)
 *
 * Run: node scripts/test-phone-opacity.mjs
 */

import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_URL = 'http://localhost:3002';
const SCREENSHOT_DIR = path.join(__dirname, '../tmp');

async function getWrapperOpacity(page) {
    return await page.evaluate(() => {
        const el = document.getElementById('phone-canvas-wrapper');
        if (!el) return null;
        return parseFloat(getComputedStyle(el).opacity);
    });
}

async function runTests() {
    const browser = await chromium.launch({ headless: true });
    const results = [];

    // ── TEST 1: Opacity starts at 0, fades to 1 at hero ──────────────────────
    console.log('\n[TEST 1] Opacity fade-in at hero (scroll=0)...');
    {
        const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
        const page = await ctx.newPage();
        await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('#phone-canvas-wrapper', { timeout: 10000 });

        const opacityBefore = await getWrapperOpacity(page);
        console.log('  Opacity immediately after mount:', opacityBefore);

        // Wait for model to load and animation to complete (model load + 0.2s delay + 0.9s tween)
        await page.waitForTimeout(7000);
        const opacityAfter = await getWrapperOpacity(page);
        console.log('  Opacity after 7s:', opacityAfter);

        await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'opacity-1-hero.png') });
        const pass = opacityBefore !== null && opacityBefore < 0.1 && opacityAfter !== null && opacityAfter > 0.9;
        results.push({ test: 'Hero fade-in', opacityBefore, opacityAfter, pass });
        await ctx.close();
    }

    // ── TEST 2: Works when loaded mid-scroll ─────────────────────────────────
    console.log('\n[TEST 2] Opacity fade-in loaded mid-scroll (MobileSection)...');
    {
        const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
        const page = await ctx.newPage();
        await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('#mobile-section', { timeout: 10000 });
        // Scroll into mobile section
        await page.evaluate(() => {
            const s = document.getElementById('mobile-section');
            if (s) window.scrollTo(0, s.offsetTop + window.innerHeight * 1.5);
        });
        const opacityBefore = await getWrapperOpacity(page);
        await page.waitForTimeout(7000);
        const opacityAfter = await getWrapperOpacity(page);
        console.log(`  Before: ${opacityBefore} | After: ${opacityAfter}`);
        await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'opacity-2-mid-scroll.png') });
        const pass = opacityAfter !== null && opacityAfter > 0.9;
        results.push({ test: 'Mid-scroll fade-in', opacityBefore, opacityAfter, pass });
        await ctx.close();
    }

    // ── TEST 3: Works when loaded at bottom of page ───────────────────────────
    console.log('\n[TEST 3] Opacity fade-in loaded at bottom of page...');
    {
        const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
        const page = await ctx.newPage();
        await page.addInitScript(() => { window.scrollTo(0, 999999); });
        await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
        await page.evaluate(() => window.scrollTo(0, 999999));
        const opacityBefore = await getWrapperOpacity(page);
        await page.waitForTimeout(7000);
        const opacityAfter = await getWrapperOpacity(page);
        console.log(`  Before: ${opacityBefore} | After: ${opacityAfter}`);
        await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'opacity-3-bottom.png') });
        const pass = opacityAfter !== null && opacityAfter > 0.9;
        results.push({ test: 'Bottom-of-page fade-in', opacityBefore, opacityAfter, pass });
        await ctx.close();
    }

    await browser.close();

    console.log('\n═══════════════════════════════════════════');
    console.log('TEST RESULTS');
    console.log('═══════════════════════════════════════════');
    let allPassed = true;
    results.forEach(r => {
        const status = r.pass ? '✅ PASS' : '❌ FAIL';
        console.log(`${status}  ${r.test}  (opacity: ${r.opacityBefore} → ${r.opacityAfter})`);
        if (!r.pass) allPassed = false;
    });
    console.log('═══════════════════════════════════════════');
    console.log(allPassed ? '✅ All tests passed' : '❌ Some tests FAILED');
    process.exit(allPassed ? 0 : 1);
}

runTests().catch(err => {
    console.error(err);
    process.exit(1);
});

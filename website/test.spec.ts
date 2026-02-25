import { test, expect } from '@playwright/test';

test('MobileSection and Hero animations check', async ({ page }) => {
    // Navigate to local dev server
    await page.goto('http://localhost:3000');
    // Wait for the 3D model and icons to load
    await page.waitForTimeout(4000);

    // Take screenshot of perfectly loaded Hero page
    await page.screenshot({ path: 'hero_final_check.png' });

    // Scroll Down halfway to trigger mobile section transition
    await page.evaluate(() => window.scrollTo(0, window.innerHeight * 1.5));

    // Wait for GSAP transitions and phone physics to settle
    await page.waitForTimeout(3000);

    // Take screenshot of midway transition
    await page.screenshot({ path: 'mobile_section_transition.png' });

    // Scroll further down into the Mobile Section
    await page.evaluate(() => window.scrollTo(0, window.innerHeight * 2.5));

    // Wait for animations to settle
    await page.waitForTimeout(2000);

    // Final settled state
    await page.screenshot({ path: 'mobile_section_settled.png' });
});

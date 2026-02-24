/**
 * Generates the phone screen texture with Zuralog logo centered on dark background.
 * Run with: node web/scripts/generate-screen-texture.mjs
 * Requires: npm install --save-dev sharp (in web/ directory)
 */
import sharp from 'sharp';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');

const WIDTH = 512;
const HEIGHT = 1024;

// Logo dimensions (centered, with padding)
const LOGO_WIDTH = 200;
const LOGO_X = (WIDTH - LOGO_WIDTH) / 2;
const LOGO_Y = (HEIGHT - LOGO_WIDTH) / 2; // roughly square logo, centered

// Create dark background with logo overlay
const svgContent = `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#050505"/>
</svg>`;

async function generate() {
  const logoPath = path.join(ROOT, 'public/logo.png');
  const outputPath = path.join(ROOT, 'public/models/phone/screen-logo.png');

  try {
    await sharp(Buffer.from(svgContent))
      .composite([{
        input: await sharp(logoPath)
          .resize(LOGO_WIDTH, null, { fit: 'inside' })
          .toBuffer(),
        gravity: 'centre',
      }])
      .png()
      .toFile(outputPath);
    console.log('✅ Screen texture generated:', outputPath);
  } catch (err) {
    console.error('❌ Error generating texture:', err.message);
    // Fallback: copy logo.png directly as screen-logo.png
    fs.copyFileSync(logoPath, outputPath);
    console.log('⚠️  Used logo.png as fallback screen texture');
  }
}

generate();

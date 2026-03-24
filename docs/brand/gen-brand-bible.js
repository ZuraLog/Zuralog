const fs = require('fs');
const path = require('path');

const dir = __dirname;
const imgBuf = fs.readFileSync(path.join(dir, 'brand-pattern.png'));
const dataUri = `data:image/png;base64,${imgBuf.toString('base64')}`;

// ── Helpers ──
const swatch = (color, label, sub = '') => `
  <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 10px;">
    <div style="width: 44px; height: 44px; border-radius: 10px; background: ${color}; border: 1px solid rgba(255,255,255,0.08); flex-shrink: 0;"></div>
    <div>
      <div style="font-size: 14px; font-weight: 600; color: #E8EDE0;">${label}</div>
      <div style="font-size: 12px; color: rgba(207,225,185,0.4); font-family: 'Outfit', monospace;">${color}${sub ? ' — ' + sub : ''}</div>
    </div>
  </div>`;

const sectionTitle = (num, title, subtitle = '') => `
  <div style="margin: 64px 0 28px; padding-top: 48px; border-top: 1px solid rgba(207,225,185,0.08);">
    <div style="font-size: 12px; font-weight: 600; color: rgba(207,225,185,0.3); letter-spacing: 2px; text-transform: uppercase; margin-bottom: 6px;">${num}</div>
    <div style="font-size: 32px; font-weight: 700; color: #CFE1B9; line-height: 1.1;">${title}</div>
    ${subtitle ? `<div style="font-size: 14px; color: rgba(207,225,185,0.45); margin-top: 6px;">${subtitle}</div>` : ''}
  </div>`;

const categories = [
  { name: 'Activity', color: '#30D158', rotation: 0 },
  { name: 'Sleep', color: '#5E5CE6', rotation: 140 },
  { name: 'Heart', color: '#FF375F', rotation: -120 },
  { name: 'Nutrition', color: '#FF9F0A', rotation: -90 },
  { name: 'Body', color: '#64D2FF', rotation: 60 },
  { name: 'Vitals', color: '#6AC4DC', rotation: 45 },
  { name: 'Wellness', color: '#BF5AF2', rotation: 160 },
  { name: 'Cycle', color: '#FF6482', rotation: -140 },
  { name: 'Mobility', color: '#FFD60A', rotation: -60 },
  { name: 'Environment', color: '#63E6BE', rotation: 15 },
];

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zuralog — Brand Bible v4.0</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html { background: #141E18; color: #E8EDE0; }
  body { font-family: 'Outfit', sans-serif; max-width: 960px; margin: 0 auto; padding: 40px 32px 120px; }
  ::selection { background: rgba(207,225,185,0.25); }
  .pat { background-image: url('${dataUri}'); background-size: cover; background-position: center; }
  .pat-text { -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
  .pat-overlay { mix-blend-mode: overlay; }
</style>
</head>
<body>

<!-- Hidden SVG defs for icon pattern fill -->
<svg width="0" height="0" style="position:absolute;">
  <defs>
    <pattern id="iconPat" patternUnits="userSpaceOnUse" width="200" height="200">
      <image href="${dataUri}" width="200" height="200"/>
    </pattern>
  </defs>
</svg>

<!-- ═══════════════════════════════════════════ -->
<!-- COVER                                       -->
<!-- ═══════════════════════════════════════════ -->

<div style="text-align: center; padding: 80px 0 40px;">
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.35); letter-spacing: 3px; text-transform: uppercase; margin-bottom: 16px;">Brand Bible</div>
  <div class="pat pat-text" style="font-size: 56px; font-weight: 700; line-height: 1; margin-bottom: 12px;">Zuralog</div>
  <div style="font-size: 18px; color: rgba(207,225,185,0.5); font-weight: 400;">Design System v4.0 — March 2026</div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 01. BRAND PATTERN                           -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('01', 'Brand Pattern', 'The topographic contour-line pattern is Zuralog\'s signature. One source image, infinite treatments.')}

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
  <!-- Raw pattern -->
  <div style="border-radius: 16px; overflow: hidden; position: relative; height: 200px;">
    <div style="position: absolute; inset: 0; " class="pat"></div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; padding: 10px 14px; background: linear-gradient(transparent, rgba(14,21,15,0.9));">
      <div style="font-size: 12px; color: rgba(207,225,185,0.6);">Original pattern — source file</div>
    </div>
  </div>

  <!-- Pattern on sage (overlay) -->
  <div style="border-radius: 16px; overflow: hidden; position: relative; height: 200px; background: #CFE1B9;">
    <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; padding: 10px 14px; background: linear-gradient(transparent, rgba(14,21,15,0.7));">
      <div style="font-size: 12px; color: rgba(207,225,185,0.8);">Sage + Overlay — signature treatment</div>
    </div>
  </div>
</div>

<!-- Pattern treatments showcase -->
<div style="margin-top: 20px; display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px;">
  <!-- Pattern text -->
  <div style="background: #141E18; border-radius: 12px; padding: 20px; text-align: center; border: 1px solid rgba(207,225,185,0.06);">
    <div class="pat pat-text" style="font-size: 48px; font-weight: 700; line-height: 1;">87</div>
    <div style="font-size: 10px; color: rgba(207,225,185,0.35); margin-top: 6px;">Pattern Text</div>
  </div>

  <!-- Top accent -->
  <div style="background: #1E2E24; border-radius: 12px; overflow: hidden; border: 1px solid rgba(207,225,185,0.06);">
    <div style="height: 3px; " class="pat"></div>
    <div style="padding: 16px 14px;">
      <div style="font-size: 11px; color: rgba(207,225,185,0.4);">Featured</div>
      <div style="font-size: 16px; font-weight: 600; color: #E8EDE0; margin-top: 4px;">Card Accent</div>
    </div>
    <div style="padding: 0 14px 10px;"><div style="font-size: 10px; color: rgba(207,225,185,0.35);">Top-edge strip</div></div>
  </div>

  <!-- Subtle texture -->
  <div style="border-radius: 12px; overflow: hidden; position: relative; border: 1px solid rgba(207,225,185,0.06);">
    <div style="position: absolute; inset: 0; background: #1E2E24;"></div>
    <div class="pat" style="position: absolute; inset: 0; opacity: 0.08;"></div>
    <div style="position: relative; padding: 16px 14px;">
      <div style="font-size: 11px; color: rgba(207,225,185,0.4);">Subtle</div>
      <div style="font-size: 16px; font-weight: 600; color: #E8EDE0; margin-top: 4px;">Texture</div>
    </div>
    <div style="position: relative; padding: 0 14px 10px;"><div style="font-size: 10px; color: rgba(207,225,185,0.35);">8% opacity</div></div>
  </div>

  <!-- Progress bar -->
  <div style="background: #141E18; border-radius: 12px; padding: 20px 14px; display: flex; flex-direction: column; justify-content: center; border: 1px solid rgba(207,225,185,0.06);">
    <div style="font-size: 11px; color: rgba(207,225,185,0.4); margin-bottom: 8px;">Steps: 68%</div>
    <div style="height: 8px; background: rgba(207,225,185,0.06); border-radius: 4px; overflow: hidden;">
      <div style="height: 100%; width: 68%; border-radius: 4px; " class="pat"></div>
    </div>
    <div style="font-size: 10px; color: rgba(207,225,185,0.35); margin-top: 8px;">Pattern Progress</div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 02. COLOR PALETTE                           -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('02', 'Color Palette', 'Two greens anchor everything. Category colors add life.')}

<div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 24px;">
  <!-- Brand colors -->
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Brand</div>
    ${swatch('#CFE1B9', 'Sage', 'Primary brand')}
    ${swatch('#344E41', 'Deep Forest', 'Secondary brand')}
    ${swatch('#141E18', 'Ink Green', 'Dark canvas')}
    ${swatch('#FAFAF5', 'Warm White', 'Light canvas')}
  </div>

  <!-- Surfaces dark -->
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Dark Surfaces</div>
    ${swatch('#141E18', 'Canvas', 'Level 0')}
    ${swatch('#1E2E24', 'Surface', 'Level 1 — Cards')}
    ${swatch('#253A2C', 'Raised', 'Level 2 — Popovers')}
    ${swatch('#2C4534', 'Overlay', 'Level 3 — Modals')}
  </div>

  <!-- Text + semantic -->
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Text (Dark Mode)</div>
    ${swatch('#E8EDE0', 'Primary', 'Headlines, values')}
    ${swatch('#CFE1B9', 'Secondary', 'Headings, accents')}
    ${swatch('rgba(207,225,185,0.40)', 'Muted', 'Labels, captions')}
  </div>
</div>

<!-- Semantic + light mode text + borders -->
<div style="margin-top: 20px; display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 24px;">
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Semantic</div>
    ${swatch('#34C759', 'Success', 'Connected, positive')}
    ${swatch('#FF9500', 'Warning', 'Caution, limits')}
    ${swatch('#FF3B30', 'Error', 'Destructive, alerts')}
    ${swatch('#007AFF', 'Syncing', 'Loading indicators')}
  </div>
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Text (Light Mode)</div>
    ${swatch('#1A2E22', 'Primary', 'Headlines, values')}
    ${swatch('#344E41', 'Secondary', 'Headings, accents')}
    ${swatch('rgba(52,78,65,0.45)', 'Muted', 'Labels, captions')}
  </div>
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Borders</div>
    <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 10px;">
      <div style="width: 44px; height: 24px; border-radius: 6px; background: #1E2E24; border: 1.5px solid rgba(207,225,185,0.06); flex-shrink: 0;"></div>
      <div><div style="font-size: 14px; font-weight: 600; color: #E8EDE0;">Default</div><div style="font-size: 12px; color: rgba(207,225,185,0.4);">Dark: 6% / Light: 8%</div></div>
    </div>
    <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 10px;">
      <div style="width: 44px; height: 24px; border-radius: 6px; background: #1E2E24; border: 1.5px solid rgba(207,225,185,0.12); flex-shrink: 0;"></div>
      <div><div style="font-size: 14px; font-weight: 600; color: #E8EDE0;">Strong</div><div style="font-size: 12px; color: rgba(207,225,185,0.4);">Dark: 12% / Light: 15%</div></div>
    </div>
  </div>
</div>

<!-- Category colors -->
<div style="margin-top: 28px;">
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Health Categories</div>
  <div style="display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px;">
    ${categories.map(c => `
      <div style="background: #141E18; border-radius: 12px; padding: 14px; text-align: center; border: 1px solid rgba(207,225,185,0.06);">
        <div style="width: 32px; height: 32px; border-radius: 8px; background: ${c.color}; margin: 0 auto 8px;"></div>
        <div style="font-size: 12px; font-weight: 600; color: ${c.color};">${c.name}</div>
        <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-top: 2px;">${c.color}</div>
      </div>
    `).join('')}
  </div>
</div>

<!-- Category tinting -->
<div style="margin-top: 28px;">
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 14px; letter-spacing: 1px; text-transform: uppercase;">Category Pattern Tinting</div>
  <div style="display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px;">
    ${categories.slice(0, 10).map(c => `
      <div style="border-radius: 12px; overflow: hidden; position: relative; height: 80px;">
        <div class="pat" style="position: absolute; inset: 0; filter: grayscale(1);"></div>
        <div style="position: absolute; inset: 0; background: ${c.color}; mix-blend-mode: color; opacity: 0.7;"></div>
        <div style="position: absolute; bottom: 0; left: 0; right: 0; padding: 6px 8px; background: linear-gradient(transparent, rgba(0,0,0,0.7));">
          <div style="font-size: 10px; color: rgba(255,255,255,0.7);">${c.name}</div>
        </div>
      </div>
    `).join('')}
  </div>
  <div style="font-size: 11px; color: rgba(207,225,185,0.3); margin-top: 8px;">Grayscale + color blend method shown. Hue-rotate and luminosity-on-color also available.</div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 03. TYPOGRAPHY                              -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('03', 'Typography', 'Outfit — Regular 400, Medium 500, SemiBold 600, Bold 700')}

<div style="background: #141E18; border-radius: 20px; padding: 32px; border: 1px solid rgba(207,225,185,0.06);">
  <div style="font-size: 34px; font-weight: 700; color: #E8EDE0; line-height: 1.1; margin-bottom: 4px;">displayLarge — 34pt Bold</div>
  <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-bottom: 20px;">Hero numbers, health score, screen titles</div>

  <div style="font-size: 28px; font-weight: 600; color: #E8EDE0; line-height: 1.15; margin-bottom: 4px;">displayMedium — 28pt SemiBold</div>
  <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-bottom: 20px;">Section headers, greeting text</div>

  <div style="font-size: 24px; font-weight: 600; color: #E8EDE0; line-height: 1.2; margin-bottom: 4px;">displaySmall — 24pt SemiBold</div>
  <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-bottom: 20px;">Card headlines, modal titles</div>

  <div style="font-size: 20px; font-weight: 500; color: #E8EDE0; line-height: 1.25; margin-bottom: 4px;">titleLarge — 20pt Medium</div>
  <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-bottom: 20px;">Card titles, dialog headers</div>

  <div style="font-size: 17px; font-weight: 500; color: #E8EDE0; line-height: 1.3; margin-bottom: 4px;">titleMedium — 17pt Medium</div>
  <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-bottom: 20px;">List item titles, navigation headers</div>

  <div style="font-size: 16px; font-weight: 400; color: #E8EDE0; line-height: 1.5; margin-bottom: 4px;">bodyLarge — 16pt Regular — Primary body text, AI chat messages</div>
  <div style="font-size: 14px; font-weight: 400; color: rgba(207,225,185,0.6); line-height: 1.45; margin-bottom: 4px;">bodyMedium — 14pt Regular — Secondary body, descriptions</div>
  <div style="font-size: 12px; font-weight: 400; color: rgba(207,225,185,0.45); line-height: 1.4; margin-bottom: 20px;">bodySmall — 12pt Regular — Captions, timestamps, metadata</div>

  <div style="display: flex; gap: 24px; margin-top: 8px;">
    <div><span style="font-size: 15px; font-weight: 600; color: #CFE1B9;">labelLarge — 15pt SemiBold</span><div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-top: 2px;">Buttons, actions</div></div>
    <div><span style="font-size: 13px; font-weight: 500; color: #CFE1B9;">labelMedium — 13pt Medium</span><div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-top: 2px;">Chips, tabs</div></div>
    <div><span style="font-size: 11px; font-weight: 500; color: #CFE1B9;">labelSmall — 11pt Medium</span><div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-top: 2px;">Badges, units</div></div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 04. SPACING                                 -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('04', 'Spacing', '4px base grid — 11 tokens from 2px to 64px')}

<div style="background: #141E18; border-radius: 20px; padding: 28px; border: 1px solid rgba(207,225,185,0.06);">
  ${[
    { name: '2xs', val: 2 }, { name: 'xs', val: 4 }, { name: 'sm', val: 8 },
    { name: 'md', val: 12 }, { name: 'base', val: 16 }, { name: 'lg', val: 20 },
    { name: 'xl', val: 24 }, { name: '2xl', val: 32 }, { name: '3xl', val: 40 },
    { name: '4xl', val: 48 }, { name: '5xl', val: 64 },
  ].map(s => `
    <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 8px;">
      <div style="width: 36px; font-size: 12px; color: rgba(207,225,185,0.4); text-align: right; font-variant-numeric: tabular-nums;">${s.val}px</div>
      <div style="width: ${s.val}px; height: 14px; background: #CFE1B9; border-radius: 3px; opacity: 0.5; min-width: 2px;"></div>
      <div style="font-size: 12px; color: rgba(207,225,185,0.6);">${s.name}</div>
    </div>
  `).join('')}
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 05. BORDER RADIUS                           -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('05', 'Border Radius', 'Soft & Rounded — organic, matches the topographic pattern')}

<div style="display: flex; gap: 16px; flex-wrap: wrap;">
  ${[
    { name: 'none', val: 0 }, { name: 'sm', val: 6 }, { name: 'md', val: 12 },
    { name: 'lg', val: 16 }, { name: 'xl', val: 20 }, { name: '2xl', val: 24 },
    { name: 'full', val: 100 },
  ].map(r => `
    <div style="text-align: center;">
      <div style="width: 64px; height: 64px; background: #1E2E24; border: 1.5px solid rgba(207,225,185,0.12); border-radius: ${r.val}px;"></div>
      <div style="font-size: 12px; color: #CFE1B9; margin-top: 6px;">${r.name}</div>
      <div style="font-size: 10px; color: rgba(207,225,185,0.3);">${r.val}px</div>
    </div>
  `).join('')}
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 06. ELEVATION                               -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('06', 'Elevation', 'Border Luminance — brighter surface + brighter border per level. No shadows on dark.')}

<div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px;">
  ${[
    { name: 'Canvas', level: 0, bg: '#141E18', border: 'rgba(207,225,185,0.04)' },
    { name: 'Surface', level: 1, bg: '#1E2E24', border: 'rgba(207,225,185,0.06)' },
    { name: 'Raised', level: 2, bg: '#253A2C', border: 'rgba(207,225,185,0.08)' },
    { name: 'Overlay', level: 3, bg: '#2C4534', border: 'rgba(207,225,185,0.10)' },
  ].map(l => `
    <div style="background: ${l.bg}; border: 1.5px solid ${l.border}; border-radius: 16px; padding: 20px;">
      <div style="font-size: 10px; color: rgba(207,225,185,0.35); margin-bottom: 4px;">Level ${l.level}</div>
      <div style="font-size: 15px; font-weight: 600; color: #E8EDE0;">${l.name}</div>
      <div style="font-size: 10px; color: rgba(207,225,185,0.3); margin-top: 6px;">${l.bg}</div>
    </div>
  `).join('')}
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 07. BUTTONS                                 -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('07', 'Buttons', 'Pill shape, 6 variants, 3 sizes. Primary carries the signature pattern.')}

<!-- Dark mode buttons -->
<div style="background: #141E18; border-radius: 20px; padding: 28px; border: 1px solid rgba(207,225,185,0.06); margin-bottom: 16px;">
  <div style="font-size: 11px; font-weight: 600; color: rgba(207,225,185,0.4); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 16px;">Dark Mode</div>
  <div style="display: flex; flex-wrap: wrap; gap: 12px; align-items: center;">
    <!-- Primary -->
    <div style="position: relative; overflow: hidden; border-radius: 100px;">
      <div style="background: #CFE1B9; padding: 14px 24px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative; font-size: 15px; font-weight: 600; color: #344E41;">Primary</div>
      </div>
    </div>
    <!-- Secondary -->
    <div style="background: #344E41; border-radius: 100px; padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: #CFE1B9;">Secondary</div>
    </div>
    <!-- Tertiary -->
    <div style="background: rgba(207,225,185,0.12); border-radius: 100px; padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: #CFE1B9;">Tertiary</div>
    </div>
    <!-- Ghost -->
    <div style="border: 1.5px solid rgba(207,225,185,0.30); border-radius: 100px; padding: 13px 23px;">
      <div style="font-size: 15px; font-weight: 600; color: #CFE1B9;">Ghost</div>
    </div>
    <!-- Text -->
    <div style="padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: rgba(207,225,185,0.60);">Text</div>
    </div>
    <!-- Destructive -->
    <div style="background: rgba(255,59,48,0.15); border-radius: 100px; padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: #FF3B30;">Destructive</div>
    </div>
  </div>

  <!-- Sizes -->
  <div style="display: flex; gap: 12px; align-items: center; margin-top: 20px;">
    <div style="position: relative; overflow: hidden; border-radius: 100px;">
      <div style="background: #CFE1B9; padding: 18px 28px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative; font-size: 16px; font-weight: 600; color: #344E41;">Large</div>
      </div>
    </div>
    <div style="position: relative; overflow: hidden; border-radius: 100px;">
      <div style="background: #CFE1B9; padding: 14px 24px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative; font-size: 15px; font-weight: 600; color: #344E41;">Default</div>
      </div>
    </div>
    <div style="position: relative; overflow: hidden; border-radius: 100px;">
      <div style="background: #CFE1B9; padding: 10px 18px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative; font-size: 13px; font-weight: 600; color: #344E41;">Small</div>
      </div>
    </div>
    <!-- Disabled -->
    <div style="position: relative; overflow: hidden; border-radius: 100px; opacity: 0.35;">
      <div style="background: #CFE1B9; padding: 14px 24px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative; font-size: 15px; font-weight: 600; color: #344E41;">Disabled</div>
      </div>
    </div>
  </div>
</div>

<!-- Light mode buttons -->
<div style="background: #FAFAF5; border-radius: 20px; padding: 28px; border: 1px solid rgba(52,78,65,0.08);">
  <div style="font-size: 11px; font-weight: 600; color: rgba(52,78,65,0.4); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 16px;">Light Mode</div>
  <div style="display: flex; flex-wrap: wrap; gap: 12px; align-items: center;">
    <div style="background: #344E41; border-radius: 100px; padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: #CFE1B9;">Primary</div>
    </div>
    <div style="background: rgba(52,78,65,0.08); border-radius: 100px; padding: 14px 24px;">
      <div style="font-size: 15px; font-weight: 600; color: #344E41;">Secondary</div>
    </div>
    <div style="border: 1.5px solid rgba(52,78,65,0.20); border-radius: 100px; padding: 13px 23px;">
      <div style="font-size: 15px; font-weight: 600; color: #344E41;">Ghost</div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 08. ICONS                                   -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('08', 'Icons', 'Lucide set — 1.5px stroke, round caps. Active = filled + pattern. Inactive = outlined.')}

<div style="background: #141E18; border-radius: 20px; padding: 28px; border: 1px solid rgba(207,225,185,0.06);">
  <div style="display: flex; gap: 32px; align-items: start;">

    <!-- Active icons -->
    <div>
      <div style="font-size: 11px; font-weight: 600; color: rgba(207,225,185,0.4); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px;">Active (Filled + Pattern)</div>
      <div style="display: flex; gap: 16px;">
        ${[
          '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14" fill="none" stroke="#344E41" stroke-width="2" stroke-linecap="round"/>',
          '<rect x="15" y="10" width="6" height="10" rx="1"/><rect x="9" y="4" width="6" height="16" rx="1"/><rect x="3" y="14" width="6" height="6" rx="1"/>',
          '<line x1="12" y1="5" x2="12" y2="19" stroke="#344E41" stroke-width="2"/><line x1="5" y1="12" x2="19" y2="12" stroke="#344E41" stroke-width="2"/>',
          '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
          '<circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>',
        ].map(p => `
          <div style="width: 48px; height: 48px; border-radius: 10px; display: flex; align-items: center; justify-content: center;">
            <svg width="36" height="36" viewBox="0 0 24 24" fill="url(#iconPat)" stroke="none">${p}</svg>
          </div>
        `).join('')}
      </div>
    </div>

    <!-- Inactive icons -->
    <div>
      <div style="font-size: 11px; font-weight: 600; color: rgba(207,225,185,0.4); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px;">Inactive (Outlined)</div>
      <div style="display: flex; gap: 16px;">
        ${[
          '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
          '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>',
          '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
          '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
          '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
        ].map(p => `
          <div style="width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="rgba(207,225,185,0.35)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${p}</svg>
          </div>
        `).join('')}
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 09. NAVIGATION                              -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('09', 'Navigation', 'Always-visible labels. No icon-only tabs, no floating pill.')}

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
  <!-- Dark nav -->
  <div style="background: #141E18; border-radius: 20px; overflow: hidden; border: 1px solid rgba(207,225,185,0.06);">
    <div style="padding: 16px; font-size: 11px; font-weight: 600; color: rgba(207,225,185,0.4); letter-spacing: 1.5px; text-transform: uppercase;">Dark Mode</div>
    <div style="border-top: 1px solid rgba(207,225,185,0.06); padding: 10px 16px 16px; display: flex; justify-content: space-around;">
      ${[
        { label: 'Today', active: true, filledPath: '<circle cx="12" cy="12" r="10" fill="#CFE1B9"/><polyline points="12 6 12 12 16 14" fill="none" stroke="#344E41" stroke-width="2" stroke-linecap="round"/>', outlinePath: '' },
        { label: 'Data', active: false, outlinePath: '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>' },
        { label: 'Log', active: false, outlinePath: '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>' },
        { label: 'Coach', active: false, outlinePath: '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>' },
        { label: 'Profile', active: false, outlinePath: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>' },
      ].map(t => t.active ?
        `<div style="display: flex; flex-direction: column; align-items: center; gap: 3px;">
          <svg width="22" height="22" viewBox="0 0 24 24">${t.filledPath}</svg>
          <div style="font-size: 10px; color: #CFE1B9; font-weight: 600;">${t.label}</div>
        </div>` :
        `<div style="display: flex; flex-direction: column; align-items: center; gap: 3px;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="rgba(207,225,185,0.35)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${t.outlinePath}</svg>
          <div style="font-size: 10px; color: rgba(207,225,185,0.35); font-weight: 400;">${t.label}</div>
        </div>`
      ).join('')}
    </div>
  </div>

  <!-- Light nav -->
  <div style="background: #FAFAF5; border-radius: 20px; overflow: hidden; border: 1px solid rgba(52,78,65,0.08);">
    <div style="padding: 16px; font-size: 11px; font-weight: 600; color: rgba(52,78,65,0.4); letter-spacing: 1.5px; text-transform: uppercase;">Light Mode</div>
    <div style="border-top: 1px solid rgba(52,78,65,0.08); padding: 10px 16px 16px; display: flex; justify-content: space-around;">
      ${[
        { label: 'Today', active: true, filledPath: '<circle cx="12" cy="12" r="10" fill="#344E41"/><polyline points="12 6 12 12 16 14" fill="none" stroke="#FAFAF5" stroke-width="2" stroke-linecap="round"/>' },
        { label: 'Data', active: false, outlinePath: '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>' },
        { label: 'Log', active: false, outlinePath: '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>' },
        { label: 'Coach', active: false, outlinePath: '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>' },
        { label: 'Profile', active: false, outlinePath: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>' },
      ].map(t => t.active ?
        `<div style="display: flex; flex-direction: column; align-items: center; gap: 3px;">
          <svg width="22" height="22" viewBox="0 0 24 24">${t.filledPath}</svg>
          <div style="font-size: 10px; color: #344E41; font-weight: 600;">${t.label}</div>
        </div>` :
        `<div style="display: flex; flex-direction: column; align-items: center; gap: 3px;">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="rgba(52,78,65,0.30)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${t.outlinePath}</svg>
          <div style="font-size: 10px; color: rgba(52,78,65,0.30); font-weight: 400;">${t.label}</div>
        </div>`
      ).join('')}
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 10. MOTION                                  -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('10', 'Motion & Animation', 'Gentle & Organic — expo-out easing, staggered entrances, shimmer loading')}

<div style="background: #141E18; border-radius: 20px; padding: 28px; border: 1px solid rgba(207,225,185,0.06);">
  <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px;">
    <div>
      <div style="font-size: 13px; font-weight: 600; color: #CFE1B9; margin-bottom: 8px;">Easing</div>
      <div style="font-size: 13px; color: rgba(207,225,185,0.5); line-height: 1.6;">cubic-bezier(0.16, 1, 0.3, 1)<br>Expo-out — fast start, gentle stop</div>
    </div>
    <div>
      <div style="font-size: 13px; font-weight: 600; color: #CFE1B9; margin-bottom: 8px;">Durations</div>
      <div style="font-size: 13px; color: rgba(207,225,185,0.5); line-height: 1.6;">200ms — micro (toggles, fades)<br>400ms — standard (transitions)<br>600ms — entrance (page load)</div>
    </div>
    <div>
      <div style="font-size: 13px; font-weight: 600; color: #CFE1B9; margin-bottom: 8px;">Stagger</div>
      <div style="font-size: 13px; color: rgba(207,225,185,0.5); line-height: 1.6;">60–80ms between siblings<br>opacity + translateY only<br>Respects reduced-motion</div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- 11. COMPONENTS                              -->
<!-- ═══════════════════════════════════════════ -->

${sectionTitle('11', 'Components', 'Cards, inputs, chips, toasts, badges, empty states')}

<!-- Cards -->
<div style="margin-bottom: 24px;">
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 12px; letter-spacing: 1px; text-transform: uppercase;">Cards — 4 Tiers</div>
  <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px;">
    <!-- Standard -->
    <div style="background: #1E2E24; border-radius: 16px; padding: 16px; border: 1px solid rgba(207,225,185,0.06);">
      <div style="font-size: 11px; color: rgba(207,225,185,0.4); margin-bottom: 4px;">Standard</div>
      <div style="font-size: 20px; font-weight: 700; color: #E8EDE0;">8,421</div>
      <div style="font-size: 11px; color: rgba(207,225,185,0.35); margin-top: 4px;">Default card</div>
    </div>
    <!-- Accent -->
    <div style="background: #1E2E24; border-radius: 16px; overflow: hidden; border: 1px solid rgba(207,225,185,0.06);">
      <div style="height: 3px; " class="pat"></div>
      <div style="padding: 14px 16px;">
        <div style="font-size: 11px; color: rgba(207,225,185,0.4); margin-bottom: 4px;">Accent</div>
        <div style="font-size: 20px; font-weight: 700; color: #E8EDE0;">8,421</div>
        <div style="font-size: 11px; color: rgba(207,225,185,0.35); margin-top: 4px;">Pattern top-edge</div>
      </div>
    </div>
    <!-- Sage -->
    <div style="position: relative; overflow: hidden; border-radius: 16px;">
      <div style="background: #CFE1B9; padding: 16px;">
        <div style="position: absolute; inset: 0; mix-blend-mode: overlay;" class="pat"></div>
        <div style="position: relative;">
          <div style="font-size: 11px; color: rgba(52,78,65,0.6); margin-bottom: 4px;">Sage</div>
          <div style="font-size: 20px; font-weight: 700; color: #344E41;">8,421</div>
          <div style="font-size: 11px; color: rgba(52,78,65,0.5); margin-top: 4px;">Pattern overlay</div>
        </div>
      </div>
    </div>
    <!-- Forest -->
    <div style="position: relative; overflow: hidden; border-radius: 16px;">
      <div style="background: #344E41; padding: 16px;">
        <div class="pat" style="position: absolute; inset: 0; opacity: 0.15;"></div>
        <div style="position: relative;">
          <div style="font-size: 11px; color: rgba(207,225,185,0.5); margin-bottom: 4px;">Forest</div>
          <div style="font-size: 20px; font-weight: 700; color: #CFE1B9;">8,421</div>
          <div style="font-size: 11px; color: rgba(207,225,185,0.4); margin-top: 4px;">15% texture</div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Chips + Badges -->
<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px;">
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 12px; letter-spacing: 1px; text-transform: uppercase;">Chips</div>
    <div style="background: #141E18; border-radius: 16px; padding: 16px; border: 1px solid rgba(207,225,185,0.06); display: flex; flex-wrap: wrap; gap: 8px;">
      <div style="background: rgba(207,225,185,0.12); border-radius: 100px; padding: 8px 14px; font-size: 12px; color: #CFE1B9; font-weight: 500;">Selected</div>
      <div style="border: 1px solid rgba(207,225,185,0.06); border-radius: 100px; padding: 8px 14px; font-size: 12px; color: rgba(207,225,185,0.5);">Default</div>
      <div style="background: rgba(48,209,88,0.15); border-radius: 100px; padding: 8px 14px; font-size: 12px; color: #30D158;">Activity</div>
      <div style="background: rgba(255,55,95,0.15); border-radius: 100px; padding: 8px 14px; font-size: 12px; color: #FF375F;">Heart</div>
    </div>
  </div>
  <div>
    <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 12px; letter-spacing: 1px; text-transform: uppercase;">Badges</div>
    <div style="background: #141E18; border-radius: 16px; padding: 16px; border: 1px solid rgba(207,225,185,0.06); display: flex; flex-wrap: wrap; gap: 8px; align-items: center;">
      <div style="background: rgba(207,225,185,0.15); border-radius: 100px; padding: 4px 10px; font-size: 11px; font-weight: 500; color: #CFE1B9;">Sage</div>
      <div style="background: rgba(52,199,89,0.15); border-radius: 100px; padding: 4px 10px; font-size: 11px; font-weight: 500; color: #34C759;">↑ 12%</div>
      <div style="background: rgba(255,59,48,0.15); border-radius: 100px; padding: 4px 10px; font-size: 11px; font-weight: 500; color: #FF3B30;">↓ 5%</div>
      <div style="background: rgba(94,92,230,0.15); border-radius: 100px; padding: 4px 10px; font-size: 11px; font-weight: 500; color: #5E5CE6;">Sleep</div>
    </div>
  </div>
</div>

<!-- Input -->
<div style="margin-bottom: 24px;">
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 12px; letter-spacing: 1px; text-transform: uppercase;">Input</div>
  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
    <div style="background: rgba(207,225,185,0.06); border: 1px solid rgba(207,225,185,0.06); border-radius: 12px; padding: 12px 16px; font-size: 14px; color: rgba(207,225,185,0.3);">Search metrics...</div>
    <div style="background: rgba(207,225,185,0.06); border: 1.5px solid rgba(207,225,185,0.12); border-radius: 12px; padding: 12px 16px; font-size: 14px; color: #E8EDE0;">Focused state</div>
  </div>
</div>

<!-- Toasts -->
<div>
  <div style="font-size: 13px; font-weight: 600; color: rgba(207,225,185,0.5); margin-bottom: 12px; letter-spacing: 1px; text-transform: uppercase;">Toasts</div>
  <div style="display: flex; flex-direction: column; gap: 10px; max-width: 400px;">
    <div style="background: #253A2C; border-radius: 16px; padding: 14px 18px; display: flex; align-items: center; gap: 12px; border: 1px solid rgba(207,225,185,0.08);">
      <div style="width: 24px; height: 24px; border-radius: 100px; background: rgba(52,199,89,0.2); display: flex; align-items: center; justify-content: center; font-size: 12px; color: #34C759; flex-shrink: 0;">✓</div>
      <div style="font-size: 14px; color: #E8EDE0;">Activity logged successfully</div>
    </div>
    <div style="background: #253A2C; border-radius: 16px; padding: 14px 18px; display: flex; align-items: center; gap: 12px; border: 1px solid rgba(207,225,185,0.08);">
      <div style="width: 24px; height: 24px; border-radius: 100px; background: rgba(255,59,48,0.2); display: flex; align-items: center; justify-content: center; font-size: 12px; color: #FF3B30; flex-shrink: 0;">✗</div>
      <div style="font-size: 14px; color: #E8EDE0;">Connection failed. Try again.</div>
    </div>
    <div style="background: #253A2C; border-radius: 16px; padding: 14px 18px; display: flex; align-items: center; gap: 12px; border: 1px solid rgba(207,225,185,0.08);">
      <div style="width: 24px; height: 24px; border-radius: 100px; background: rgba(207,225,185,0.15); display: flex; align-items: center; justify-content: center; font-size: 12px; color: #CFE1B9; flex-shrink: 0;">ℹ</div>
      <div style="font-size: 14px; color: #E8EDE0;">Syncing health data...</div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════ -->
<!-- FOOTER                                      -->
<!-- ═══════════════════════════════════════════ -->

<div style="margin-top: 80px; padding-top: 32px; border-top: 1px solid rgba(207,225,185,0.06); text-align: center;">
  <div class="pat pat-text" style="font-size: 24px; font-weight: 700; line-height: 1; margin-bottom: 8px;">Zuralog</div>
  <div style="font-size: 12px; color: rgba(207,225,185,0.3);">Brand Bible v4.0 — Grounded. Alive. Confident.</div>
</div>

</body>
</html>`;

fs.writeFileSync(path.join(dir, 'brand-bible.html'), html);
console.log('Done — brand-bible.html written');

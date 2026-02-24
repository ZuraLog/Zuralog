/**
 * screen-dashboard.ts — Draws a ZuraLog app dashboard onto an HTML Canvas.
 *
 * Used as a Three.js CanvasTexture for the phone screen in the hero scene.
 * All rendering is done via Canvas 2D API — no DOM elements or React needed.
 */

const W = 390;
const H = 844;

/* ─── Colors ─────────────────────────────────────────────────────────── */
const BG = "#0a0a0a";
const CARD_BG = "#161616";
const SAGE = "#CFE1B9";
const SAGE_DIM = "rgba(207,225,185,0.35)";
const SAGE_FAINT = "rgba(207,225,185,0.12)";
const WHITE = "#ffffff";
const WHITE_80 = "rgba(255,255,255,0.8)";
const WHITE_50 = "rgba(255,255,255,0.5)";
const WHITE_30 = "rgba(255,255,255,0.3)";
const ORANGE = "#FC4C02";
const ORANGE_DIM = "rgba(252,76,2,0.7)";

/* ─── Helpers ────────────────────────────────────────────────────────── */

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number, r: number,
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function drawPill(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number,
  fillColor: string,
) {
  roundRect(ctx, x, y, w, h, h / 2);
  ctx.fillStyle = fillColor;
  ctx.fill();
}

/* ─── Section Renderers ──────────────────────────────────────────────── */

function drawStatusBar(ctx: CanvasRenderingContext2D) {
  ctx.fillStyle = WHITE;
  ctx.font = "600 14px -apple-system, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("9:41", W / 2, 54);

  // Battery icon (right side)
  ctx.strokeStyle = WHITE_80;
  ctx.lineWidth = 1;
  roundRect(ctx, W - 52, 43, 24, 12, 3);
  ctx.stroke();
  ctx.fillStyle = SAGE;
  roundRect(ctx, W - 50, 45, 18, 8, 2);
  ctx.fill();
  // Battery nub
  ctx.fillStyle = WHITE_80;
  ctx.fillRect(W - 26, 47, 2, 4);

  // Signal dots (left side)
  for (let i = 0; i < 4; i++) {
    ctx.fillStyle = i < 3 ? WHITE_80 : WHITE_30;
    ctx.beginPath();
    ctx.arc(28 + i * 8, 49, 2.5, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawHeader(ctx: CanvasRenderingContext2D) {
  const y = 90;
  ctx.textAlign = "left";

  ctx.fillStyle = WHITE;
  ctx.font = "700 26px -apple-system, sans-serif";
  ctx.fillText("Good Morning", 24, y);

  ctx.fillStyle = WHITE_50;
  ctx.font = "400 13px -apple-system, sans-serif";
  ctx.fillText("Monday, Feb 24", 24, y + 22);

  // ZuraLog pill badge (top right)
  drawPill(ctx, W - 110, y - 20, 86, 28, SAGE_FAINT);
  ctx.fillStyle = SAGE;
  ctx.font = "600 11px -apple-system, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("ZuraLog", W - 67, y - 2);
}

function drawReadinessRing(ctx: CanvasRenderingContext2D) {
  const cx = W / 2;
  const cy = 210;
  const r = 62;

  // Background ring
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.strokeStyle = SAGE_FAINT;
  ctx.lineWidth = 8;
  ctx.stroke();

  // Filled arc (75%)
  ctx.beginPath();
  ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * 0.75);
  ctx.strokeStyle = SAGE;
  ctx.lineWidth = 8;
  ctx.lineCap = "round";
  ctx.stroke();
  ctx.lineCap = "butt";

  // Center text
  ctx.textAlign = "center";
  ctx.fillStyle = WHITE;
  ctx.font = "700 36px -apple-system, sans-serif";
  ctx.fillText("82", cx, cy + 8);

  ctx.fillStyle = WHITE_50;
  ctx.font = "500 11px -apple-system, sans-serif";
  ctx.fillText("HRV", cx, cy + 26);

  // Label below ring
  ctx.fillStyle = SAGE_DIM;
  ctx.font = "600 10px -apple-system, sans-serif";
  ctx.letterSpacing = "2px";
  ctx.fillText("READINESS", cx, cy + r + 24);

  // Score text
  ctx.fillStyle = SAGE;
  ctx.font = "700 14px -apple-system, sans-serif";
  ctx.fillText("75%", cx, cy + r + 42);
}

function drawMetricCards(ctx: CanvasRenderingContext2D) {
  const y = 320;
  const cardW = (W - 24 * 2 - 12) / 2;
  const cardH = 80;

  // Steps card
  roundRect(ctx, 24, y, cardW, cardH, 16);
  ctx.fillStyle = CARD_BG;
  ctx.fill();

  // Steps dot
  ctx.beginPath();
  ctx.arc(44, y + 24, 4, 0, Math.PI * 2);
  ctx.fillStyle = SAGE;
  ctx.fill();

  ctx.textAlign = "left";
  ctx.fillStyle = WHITE_50;
  ctx.font = "500 10px -apple-system, sans-serif";
  ctx.fillText("Steps", 56, y + 28);

  ctx.fillStyle = WHITE;
  ctx.font = "700 22px -apple-system, sans-serif";
  ctx.fillText("9,820", 36, y + 54);

  // Steps progress bar
  roundRect(ctx, 36, y + 62, cardW - 24, 4, 2);
  ctx.fillStyle = "rgba(255,255,255,0.08)";
  ctx.fill();
  roundRect(ctx, 36, y + 62, (cardW - 24) * 0.98, 4, 2);
  ctx.fillStyle = SAGE;
  ctx.fill();

  // Calories card
  const cx = 24 + cardW + 12;
  roundRect(ctx, cx, y, cardW, cardH, 16);
  ctx.fillStyle = CARD_BG;
  ctx.fill();

  // Cal dot
  ctx.beginPath();
  ctx.arc(cx + 20, y + 24, 4, 0, Math.PI * 2);
  ctx.fillStyle = ORANGE;
  ctx.fill();

  ctx.fillStyle = WHITE_50;
  ctx.font = "500 10px -apple-system, sans-serif";
  ctx.fillText("Calories", cx + 32, y + 28);

  ctx.fillStyle = WHITE;
  ctx.font = "700 22px -apple-system, sans-serif";
  ctx.fillText("1,840", cx + 12, y + 54);

  // Cal progress bar
  roundRect(ctx, cx + 12, y + 62, cardW - 24, 4, 2);
  ctx.fillStyle = "rgba(255,255,255,0.08)";
  ctx.fill();
  roundRect(ctx, cx + 12, y + 62, (cardW - 24) * 0.78, 4, 2);
  ctx.fillStyle = ORANGE_DIM;
  ctx.fill();
}

function drawWeeklyChart(ctx: CanvasRenderingContext2D) {
  const y = 420;
  const chartW = W - 48;
  const chartH = 140;

  // Card background
  roundRect(ctx, 24, y, chartW, chartH, 16);
  ctx.fillStyle = CARD_BG;
  ctx.fill();

  // Title
  ctx.textAlign = "left";
  ctx.fillStyle = WHITE_80;
  ctx.font = "600 13px -apple-system, sans-serif";
  ctx.fillText("Weekly Load", 42, y + 28);

  ctx.textAlign = "right";
  ctx.fillStyle = SAGE;
  ctx.font = "500 11px -apple-system, sans-serif";
  ctx.fillText("+12%", W - 42, y + 28);

  // Bars
  const days = ["M", "T", "W", "T", "F", "S", "S"];
  const pcts = [0.55, 0.80, 0.40, 0.90, 0.65, 0.30, 0.70];
  const barAreaTop = y + 42;
  const barAreaH = 60;
  const barW = 22;
  const gap = (chartW - 36 - days.length * barW) / (days.length - 1);

  ctx.textAlign = "center";

  for (let i = 0; i < days.length; i++) {
    const bx = 42 + i * (barW + gap);
    const barH = barAreaH * pcts[i];
    const by = barAreaTop + barAreaH - barH;
    const isActive = i === 6;

    roundRect(ctx, bx, by, barW, barH, 4);
    ctx.fillStyle = isActive ? SAGE : SAGE_DIM;
    ctx.fill();

    // Day label
    ctx.fillStyle = isActive ? SAGE : WHITE_30;
    ctx.font = "500 9px -apple-system, sans-serif";
    ctx.fillText(days[i], bx + barW / 2, barAreaTop + barAreaH + 16);
  }
}

function drawCoachCard(ctx: CanvasRenderingContext2D) {
  const y = 578;
  const cardW = W - 48;
  const cardH = 90;

  // Card background with sage tint
  roundRect(ctx, 24, y, cardW, cardH, 16);
  ctx.fillStyle = "rgba(11,23,11,0.92)";
  ctx.fill();
  ctx.strokeStyle = SAGE_FAINT;
  ctx.lineWidth = 1;
  roundRect(ctx, 24, y, cardW, cardH, 16);
  ctx.stroke();

  // AI dot + label
  ctx.beginPath();
  ctx.arc(46, y + 24, 5, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(207,225,185,0.2)";
  ctx.fill();
  ctx.beginPath();
  ctx.arc(46, y + 24, 2.5, 0, Math.PI * 2);
  ctx.fillStyle = SAGE;
  ctx.fill();

  ctx.textAlign = "left";
  ctx.fillStyle = SAGE_DIM;
  ctx.font = "600 9px -apple-system, sans-serif";
  ctx.fillText("ZURALOG AI", 58, y + 28);

  // Message text
  ctx.fillStyle = WHITE_80;
  ctx.font = "400 12px -apple-system, sans-serif";
  ctx.fillText("Rest day today — HRV dropped", 42, y + 50);
  ctx.fillText("14%. Light walk only.", 42, y + 66);

  // Action pills
  drawPill(ctx, 42, y + 74, 48, 20, SAGE_FAINT);
  ctx.fillStyle = SAGE;
  ctx.font = "500 9px -apple-system, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("Got it", 66, y + 87);

  drawPill(ctx, 96, y + 74, 52, 20, "rgba(255,255,255,0.05)");
  ctx.fillStyle = WHITE_30;
  ctx.fillText("Details", 122, y + 87);
}

function drawWorkoutCard(ctx: CanvasRenderingContext2D) {
  const y = 686;
  const cardW = W - 48;
  const cardH = 80;

  roundRect(ctx, 24, y, cardW, cardH, 16);
  ctx.fillStyle = CARD_BG;
  ctx.fill();

  // Workout icon
  roundRect(ctx, 40, y + 14, 24, 24, 6);
  ctx.fillStyle = "rgba(252,76,2,0.2)";
  ctx.fill();
  ctx.fillStyle = ORANGE;
  ctx.fillRect(47, y + 21, 10, 10);

  ctx.textAlign = "left";
  ctx.fillStyle = WHITE_80;
  ctx.font = "600 13px -apple-system, sans-serif";
  ctx.fillText("Morning Run", 74, y + 30);

  ctx.fillStyle = WHITE_30;
  ctx.font = "400 10px -apple-system, sans-serif";
  ctx.fillText("Today, 7:12 AM", 74, y + 46);

  // Stats row
  const stats = [
    { label: "8.2 km", color: WHITE },
    { label: "5:12 /km", color: WHITE },
    { label: "42:38", color: WHITE },
    { label: "156 bpm", color: ORANGE_DIM },
  ];
  const statStartX = 40;
  ctx.font = "600 10px -apple-system, sans-serif";
  ctx.textAlign = "left";
  for (let i = 0; i < stats.length; i++) {
    const sx = statStartX + i * 78;
    ctx.fillStyle = stats[i].color;
    ctx.fillText(stats[i].label, sx, y + 66);
  }
}

function drawBottomNav(ctx: CanvasRenderingContext2D) {
  const y = 798;

  // Nav bar background
  ctx.fillStyle = "#111111";
  ctx.fillRect(0, y, W, H - y);

  // Separator line
  ctx.fillStyle = "rgba(255,255,255,0.06)";
  ctx.fillRect(0, y, W, 1);

  // Nav items
  const items = ["Home", "Activity", "Coach", "Profile"];
  const iconW = W / items.length;

  ctx.textAlign = "center";
  for (let i = 0; i < items.length; i++) {
    const ix = iconW * i + iconW / 2;
    const isActive = i === 0;

    // Icon circle
    ctx.beginPath();
    ctx.arc(ix, y + 18, 10, 0, Math.PI * 2);
    ctx.fillStyle = isActive ? SAGE_FAINT : "rgba(255,255,255,0.05)";
    ctx.fill();

    // Icon dot
    ctx.beginPath();
    ctx.arc(ix, y + 18, 3, 0, Math.PI * 2);
    ctx.fillStyle = isActive ? SAGE : WHITE_30;
    ctx.fill();

    // Label
    ctx.fillStyle = isActive ? SAGE : WHITE_30;
    ctx.font = "500 9px -apple-system, sans-serif";
    ctx.fillText(items[i], ix, y + 38);
  }
}

/* ─── Main export ────────────────────────────────────────────────────── */

/**
 * Creates an HTMLCanvasElement with a ZuraLog dashboard drawn on it.
 * Used as a Three.js CanvasTexture for the phone screen.
 */
export function createDashboardCanvas(): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;

  const ctx = canvas.getContext("2d")!;

  // Background
  ctx.fillStyle = BG;
  ctx.fillRect(0, 0, W, H);

  drawStatusBar(ctx);
  drawHeader(ctx);
  drawReadinessRing(ctx);
  drawMetricCards(ctx);
  drawWeeklyChart(ctx);
  drawCoachCard(ctx);
  drawWorkoutCard(ctx);
  drawBottomNav(ctx);

  return canvas;
}

/**
 * Returns a data URL (PNG) of the dashboard canvas.
 * This can be loaded by drei's useTexture just like a regular image path.
 */
export function createDashboardDataURL(): string {
  const canvas = createDashboardCanvas();
  return canvas.toDataURL("image/png");
}

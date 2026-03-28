import confetti from "canvas-confetti";

/**
 * Plays a short celebratory C-major arpeggio (C5–E5–G5) using the
 * Web Audio API. Silently no-ops if the API is unavailable.
 */
function playConfettiChime() {
  try {
    const AudioCtx =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext })
        .webkitAudioContext;
    const ctx = new AudioCtx();
    const notes = [523.25, 659.25, 783.99]; // C5, E5, G5
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = "triangle";
      const t = ctx.currentTime + i * 0.09;
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0, t);
      gain.gain.linearRampToValueAtTime(0.18, t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.45);
      osc.start(t);
      osc.stop(t + 0.5);
    });
  } catch {
    // AudioContext not available — silent fallback
  }
}

/**
 * sageConfetti — fires a small burst of brand-colored confetti with
 * a matching celebratory chime.
 *
 * Automatically respects prefers-reduced-motion via the library's
 * built-in `disableForReducedMotion` flag.
 *
 * In light mode the palette switches to deep forest greens so particles
 * are visible against the warm-white canvas.
 */
export function sageConfetti() {
  const isLight =
    typeof document !== "undefined" &&
    !!document.querySelector('[data-theme="light"]');

  playConfettiChime();

  confetti({
    particleCount: 40,
    spread: 60,
    origin: { y: 0.7 },
    colors: isLight
      ? ["#344E41", "#2D4537", "#3D5C4A", "#4A6B58"]
      : ["#CFE1B9", "#b3d18f", "#9BC88A", "#F0EEE9"],
    gravity: 0.8,
    ticks: 150,
    disableForReducedMotion: true,
  });
}

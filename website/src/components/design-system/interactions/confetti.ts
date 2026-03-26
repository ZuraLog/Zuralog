import confetti from "canvas-confetti";

/**
 * sageConfetti — fires a small burst of brand-colored confetti.
 * Automatically respects prefers-reduced-motion via the library's
 * built-in `disableForReducedMotion` flag.
 */
export function sageConfetti() {
  confetti({
    particleCount: 40,
    spread: 60,
    origin: { y: 0.7 },
    colors: ["#CFE1B9", "#b3d18f", "#9BC88A", "#F0EEE9"],
    gravity: 0.8,
    ticks: 150,
    disableForReducedMotion: true,
  });
}

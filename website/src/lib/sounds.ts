/**
 * Premium UI sound system — synthesized via Web Audio API.
 *
 * Zero-latency, no external files. Generates subtle, satisfying
 * interaction sounds: soft ticks, clicks, whooshes.
 *
 * Respects user preference: sounds are off by default until
 * the first user interaction (click/tap) unlocks the AudioContext.
 */

let ctx: AudioContext | null = null;

function getCtx(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
  }
  return ctx;
}

/** Soft tick — nav link hover, subtle feedback */
export function playTick() {
  const ac = getCtx();
  if (!ac) return;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  osc.connect(gain);
  gain.connect(ac.destination);
  osc.frequency.setValueAtTime(3200, ac.currentTime);
  osc.frequency.exponentialRampToValueAtTime(1800, ac.currentTime + 0.03);
  osc.type = "sine";
  gain.gain.setValueAtTime(0.04, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.06);
  osc.start(ac.currentTime);
  osc.stop(ac.currentTime + 0.06);
}

/** Satisfying click — button press, CTA interaction */
export function playClick() {
  const ac = getCtx();
  if (!ac) return;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  osc.connect(gain);
  gain.connect(ac.destination);
  osc.frequency.setValueAtTime(800, ac.currentTime);
  osc.frequency.exponentialRampToValueAtTime(400, ac.currentTime + 0.08);
  osc.type = "sine";
  gain.gain.setValueAtTime(0.06, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.1);
  osc.start(ac.currentTime);
  osc.stop(ac.currentTime + 0.1);
}

/** Gentle whoosh — card hover, menu open */
export function playWhoosh() {
  const ac = getCtx();
  if (!ac) return;
  // Filtered noise burst
  const bufferSize = ac.sampleRate * 0.12;
  const buffer = ac.createBuffer(1, bufferSize, ac.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) {
    data[i] = (Math.random() * 2 - 1) * 0.5;
  }
  const noise = ac.createBufferSource();
  noise.buffer = buffer;
  const filter = ac.createBiquadFilter();
  filter.type = "bandpass";
  filter.frequency.setValueAtTime(2000, ac.currentTime);
  filter.frequency.exponentialRampToValueAtTime(600, ac.currentTime + 0.12);
  filter.Q.value = 1.5;
  const gain = ac.createGain();
  gain.gain.setValueAtTime(0.03, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.12);
  noise.connect(filter);
  filter.connect(gain);
  gain.connect(ac.destination);
  noise.start(ac.currentTime);
}

/** Rising tone — success, positive confirmation */
export function playRise() {
  const ac = getCtx();
  if (!ac) return;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  osc.connect(gain);
  gain.connect(ac.destination);
  osc.frequency.setValueAtTime(400, ac.currentTime);
  osc.frequency.exponentialRampToValueAtTime(900, ac.currentTime + 0.15);
  osc.type = "sine";
  gain.gain.setValueAtTime(0.04, ac.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.18);
  osc.start(ac.currentTime);
  osc.stop(ac.currentTime + 0.18);
}

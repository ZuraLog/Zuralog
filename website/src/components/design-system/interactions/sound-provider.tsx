"use client";

import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from "react";

/**
 * SoundProvider — synthesizes UI sounds using the Web Audio API.
 * No audio files needed. Each sound is a short tone generated on the fly.
 * Mute preference saved to localStorage.
 */

type SoundName =
  | "click"
  | "toggle-on"
  | "toggle-off"
  | "tick"
  | "whoosh-up"
  | "whoosh-down"
  | "pop"
  | "tab-click"
  | "chime"
  | "success"
  | "error"
  | "singing-bowl";

interface SoundContextType {
  muted: boolean;
  toggleMute: () => void;
  playSound: (sound: SoundName) => void;
}

const SoundContext = createContext<SoundContextType>({
  muted: true,
  toggleMute: () => {},
  playSound: () => {},
});

export function useSoundContext() {
  return useContext(SoundContext);
}

/* ------------------------------------------------------------------ */
/*  Synthesizer — each sound is a tiny function using Web Audio API    */
/* ------------------------------------------------------------------ */

function getAudioCtx(ref: React.MutableRefObject<AudioContext | null>): AudioContext {
  if (!ref.current) {
    ref.current = new AudioContext();
  }
  if (ref.current.state === "suspended") {
    ref.current.resume();
  }
  return ref.current;
}

function playTone(
  ctx: AudioContext,
  freq: number,
  duration: number,
  volume: number,
  type: OscillatorType = "sine",
  fadeOut = true,
) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.value = volume;
  if (fadeOut) {
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
  }
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start();
  osc.stop(ctx.currentTime + duration);
}

function playNoise(ctx: AudioContext, duration: number, volume: number) {
  const bufferSize = ctx.sampleRate * duration;
  const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) {
    data[i] = (Math.random() * 2 - 1) * 0.3;
  }
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  const gain = ctx.createGain();
  gain.gain.value = volume;
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
  const filter = ctx.createBiquadFilter();
  filter.type = "highpass";
  filter.frequency.value = 4000;
  source.connect(filter);
  filter.connect(gain);
  gain.connect(ctx.destination);
  source.start();
}

const SOUNDS: Record<SoundName, (ctx: AudioContext) => void> = {
  // Soft warm tap
  click: (ctx) => {
    playTone(ctx, 800, 0.06, 0.08, "sine");
    playNoise(ctx, 0.04, 0.03);
  },
  // Light ascending tone
  "toggle-on": (ctx) => {
    playTone(ctx, 600, 0.08, 0.07, "sine");
    setTimeout(() => playTone(ctx, 900, 0.06, 0.05, "sine"), 40);
  },
  // Light descending tone
  "toggle-off": (ctx) => {
    playTone(ctx, 700, 0.08, 0.06, "sine");
    setTimeout(() => playTone(ctx, 450, 0.06, 0.04, "sine"), 40);
  },
  // Crisp tick
  tick: (ctx) => {
    playTone(ctx, 1200, 0.03, 0.06, "square");
  },
  // Gentle upward whoosh
  "whoosh-up": (ctx) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = 200;
    osc.frequency.exponentialRampToValueAtTime(800, ctx.currentTime + 0.15);
    gain.gain.value = 0.04;
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.2);
    playNoise(ctx, 0.12, 0.02);
  },
  // Reverse whoosh
  "whoosh-down": (ctx) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = 600;
    osc.frequency.exponentialRampToValueAtTime(200, ctx.currentTime + 0.12);
    gain.gain.value = 0.03;
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.15);
  },
  // Bubble pop
  pop: (ctx) => {
    playTone(ctx, 1400, 0.03, 0.04, "sine");
  },
  // Soft click (lighter)
  "tab-click": (ctx) => {
    playTone(ctx, 1000, 0.04, 0.05, "sine");
  },
  // Quiet ambient chime
  chime: (ctx) => {
    playTone(ctx, 523, 0.3, 0.03, "sine");
    playTone(ctx, 659, 0.25, 0.02, "sine");
  },
  // Two-note ascending
  success: (ctx) => {
    playTone(ctx, 523, 0.15, 0.06, "sine");
    setTimeout(() => playTone(ctx, 784, 0.2, 0.05, "sine"), 100);
  },
  // Low buzz
  error: (ctx) => {
    playTone(ctx, 200, 0.15, 0.05, "sawtooth");
  },
  // Clean singing bowl fade
  "singing-bowl": (ctx) => {
    playTone(ctx, 396, 0.8, 0.04, "sine");
    playTone(ctx, 528, 0.6, 0.03, "sine");
  },
};

/* ------------------------------------------------------------------ */
/*  Provider                                                           */
/* ------------------------------------------------------------------ */

export function SoundProvider({ children }: { children: React.ReactNode }) {
  const [muted, setMuted] = useState(true);
  const audioCtxRef = useRef<AudioContext | null>(null);

  useEffect(() => {
    const saved = localStorage.getItem("zuralog-sound-muted");
    if (saved !== null) {
      setMuted(saved === "true");
    } else {
      const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      setMuted(prefersReduced);
    }
  }, []);

  const toggleMute = useCallback(() => {
    setMuted((prev) => {
      const next = !prev;
      localStorage.setItem("zuralog-sound-muted", String(next));
      return next;
    });
  }, []);

  const playSound = useCallback(
    (sound: SoundName) => {
      if (muted) return;
      try {
        const ctx = getAudioCtx(audioCtxRef);
        SOUNDS[sound]?.(ctx);
      } catch {
        // Web Audio API not available — fail silently
      }
    },
    [muted],
  );

  return (
    <SoundContext.Provider value={{ muted, toggleMute, playSound }}>
      {children}
    </SoundContext.Provider>
  );
}

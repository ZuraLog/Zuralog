"use client";

import React, { createContext, useContext, useState, useCallback, useEffect } from "react";

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

export function SoundProvider({ children }: { children: React.ReactNode }) {
  // Default to muted. Respect prefers-reduced-motion.
  const [muted, setMuted] = useState(true);

  useEffect(() => {
    // Load saved preference
    const saved = localStorage.getItem("zuralog-sound-muted");
    if (saved !== null) {
      setMuted(saved === "true");
    } else {
      // Default: muted if user prefers reduced motion, unmuted otherwise
      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;
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

  // Keep a cache of Audio elements so we only create each one once
  const audioCache = React.useRef<Map<string, HTMLAudioElement>>(new Map());

  const playSound = useCallback(
    (sound: SoundName) => {
      if (muted) return;

      let audio = audioCache.current.get(sound);
      if (!audio) {
        audio = new Audio(`/sounds/${sound}.mp3`);
        audio.volume = 0.2; // 20% — subtle, never jarring
        audioCache.current.set(sound, audio);
      }

      // Reset playback position and play (silently fail if file missing)
      audio.currentTime = 0;
      audio.play().catch(() => {});
    },
    [muted]
  );

  return (
    <SoundContext.Provider value={{ muted, toggleMute, playSound }}>
      {children}
    </SoundContext.Provider>
  );
}

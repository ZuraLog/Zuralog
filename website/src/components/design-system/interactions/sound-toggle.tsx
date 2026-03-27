"use client";

import { Volume2, VolumeX } from "lucide-react";
import { useSoundContext } from "./sound-provider";

export function SoundToggle() {
  const { muted, toggleMute, playSound } = useSoundContext();

  return (
    <button
      onClick={() => {
        toggleMute();
        if (muted) playSound("pop"); // Play a sound when unmuting
      }}
      className="fixed bottom-6 right-6 z-50 w-10 h-10 rounded-full bg-ds-surface-raised flex items-center justify-center text-ds-text-secondary hover:text-ds-sage transition-colors"
      aria-label={muted ? "Unmute sounds" : "Mute sounds"}
    >
      {muted ? <VolumeX size={18} /> : <Volume2 size={18} />}
    </button>
  );
}

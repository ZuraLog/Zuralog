"use client";

import { Sun, Moon } from "lucide-react";
import { useBrandBibleTheme } from "./brand-bible-theme";

export function ThemeToggle() {
  const { isDark, toggleTheme } = useBrandBibleTheme();

  return (
    <button
      onClick={toggleTheme}
      className="fixed bottom-6 right-20 z-50 w-10 h-10 rounded-full bg-ds-surface-raised flex items-center justify-center text-ds-text-secondary hover:text-ds-sage transition-colors"
      aria-label={isDark ? "Switch to light mode" : "Switch to dark mode"}
    >
      {isDark ? <Sun size={18} /> : <Moon size={18} />}
    </button>
  );
}

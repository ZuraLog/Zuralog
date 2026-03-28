"use client";

import React, { createContext, useContext, useState, useEffect } from "react";

/**
 * BrandBibleThemeProvider — manages dark/light theme state for the brand bible page.
 * Preference saved to localStorage.
 *
 * Sets data-theme="light" on BOTH the inner wrapper div AND document.body so that
 * Radix UI portals (Sheet, Popover, HoverCard, Select, Dialog) and Sonner toasts —
 * which all portal to document.body — inherit the CSS variable overrides.
 */

type BrandBibleTheme = "dark" | "light";

interface BrandBibleThemeContextType {
  theme: BrandBibleTheme;
  toggleTheme: () => void;
  isDark: boolean;
  isLight: boolean;
}

const STORAGE_KEY = "zuralog-brand-bible-theme";

const BrandBibleThemeContext = createContext<BrandBibleThemeContextType | null>(null);

// Strict hook — throws if used outside the provider. Use in ThemeToggle.
export function useBrandBibleTheme(): BrandBibleThemeContextType {
  const ctx = useContext(BrandBibleThemeContext);
  if (ctx === null) {
    throw new Error("useBrandBibleTheme must be used inside BrandBibleThemeProvider");
  }
  return ctx;
}

// Safe hook — returns null if used outside the provider. Use in Card.
export function useBrandBibleThemeOptional(): BrandBibleThemeContextType | null {
  return useContext(BrandBibleThemeContext);
}

// Provider
export function BrandBibleThemeProvider({ children }: { children: React.ReactNode }): React.JSX.Element {
  const [theme, setTheme] = useState<BrandBibleTheme>("dark");

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "light") {
      setTheme("light");
    }
  }, []);

  // Mirror data-theme onto document.body so portals (Radix, Sonner) inherit CSS vars
  useEffect(() => {
    if (theme === "light") {
      document.body.setAttribute("data-theme", "light");
    } else {
      document.body.removeAttribute("data-theme");
    }
    return () => {
      document.body.removeAttribute("data-theme");
    };
  }, [theme]);

  function toggleTheme() {
    setTheme((prev) => {
      const next: BrandBibleTheme = prev === "dark" ? "light" : "dark";
      localStorage.setItem(STORAGE_KEY, next);
      return next;
    });
  }

  const value: BrandBibleThemeContextType = {
    theme,
    toggleTheme,
    isDark: theme === "dark",
    isLight: theme === "light",
  };

  return (
    <BrandBibleThemeContext.Provider value={value}>
      <div className="contents" {...(theme === "light" ? { "data-theme": "light" } : {})}>
        {children}
      </div>
    </BrandBibleThemeContext.Provider>
  );
}

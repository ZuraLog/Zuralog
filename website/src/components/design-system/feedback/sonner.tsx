"use client";

import { useState, useEffect } from "react";
import { Toaster as SonnerToaster } from "sonner";
import { toast } from "sonner";

/* ------------------------------------------------------------------ */
/*  DSToaster — themed Sonner toaster for Zuralog                      */
/*                                                                      */
/*  Watches document.body for data-theme changes so it automatically   */
/*  adapts when BrandBibleThemeProvider sets light mode.               */
/* ------------------------------------------------------------------ */

export function DSToaster() {
  const [theme, setTheme] = useState<"dark" | "light">("dark");

  useEffect(() => {
    // Read initial value
    const read = () =>
      document.body.getAttribute("data-theme") === "light" ? "light" : "dark";
    setTheme(read());

    // Watch for changes (BrandBibleThemeProvider sets/removes data-theme on body)
    const observer = new MutationObserver(() => setTheme(read()));
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ["data-theme"],
    });
    return () => observer.disconnect();
  }, []);

  return (
    <SonnerToaster
      theme={theme}
      position="top-center"
      toastOptions={{
        className: "font-jakarta",
        style: {
          // CSS variable references cascade from [data-theme="light"] on body
          background: "var(--color-ds-surface-raised, #272729)",
          border: "1px solid var(--color-ds-border-subtle, rgba(240,238,233,0.06))",
          color: "var(--color-ds-text-primary, #F0EEE9)",
          borderRadius: "12px",
          fontSize: "0.875rem",
        },
      }}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  dsToast — convenience helpers for styled toast calls                */
/* ------------------------------------------------------------------ */

export const dsToast = {
  success: (msg: string) => toast.success(msg),
  error: (msg: string) => toast.error(msg),
  warning: (msg: string) => toast.warning(msg),
  info: (msg: string) => toast.info(msg),
  loading: (msg: string) => toast.loading(msg),
};

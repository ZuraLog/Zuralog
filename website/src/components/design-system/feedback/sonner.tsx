"use client";

import { Toaster as SonnerToaster } from "sonner";
import { toast } from "sonner";

/* ------------------------------------------------------------------ */
/*  DSToaster — themed Sonner toaster for Zuralog dark mode             */
/* ------------------------------------------------------------------ */

export function DSToaster() {
  return (
    <SonnerToaster
      theme="dark"
      position="top-center"
      toastOptions={{
        className: "font-jakarta",
        style: {
          background: "#272729",
          border: "1px solid rgba(240, 238, 233, 0.06)",
          color: "#F0EEE9",
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

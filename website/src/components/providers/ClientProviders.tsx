"use client";

import { SoundProvider } from "@/components/design-system";
import { PhoneProvider } from "@/components/phone/PhoneContext";

/**
 * ClientProviders — wraps the entire app with all client-side context providers.
 *
 * Provider order (outermost to innermost):
 *   SoundProvider   — audio context for button click sounds
 *   PhoneProvider   — shared DOM refs for the ScrollPhone overlay; must wrap
 *                     both ScrollPhone (which attaches refs to DOM nodes) and
 *                     page sections (which read refs to drive GSAP animations)
 */
export function ClientProviders({ children }: { children: React.ReactNode }) {
  return (
    <SoundProvider>
      <PhoneProvider>{children}</PhoneProvider>
    </SoundProvider>
  );
}

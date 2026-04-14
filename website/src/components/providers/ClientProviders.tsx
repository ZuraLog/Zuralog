"use client";

import { SoundProvider } from "@/components/design-system";

/**
 * ClientProviders — wraps the entire app with all client-side context providers.
 */
export function ClientProviders({ children }: { children: React.ReactNode }) {
  return <SoundProvider>{children}</SoundProvider>;
}

"use client";

import { SoundProvider } from "@/components/design-system";

export function ClientProviders({ children }: { children: React.ReactNode }) {
    return <SoundProvider>{children}</SoundProvider>;
}

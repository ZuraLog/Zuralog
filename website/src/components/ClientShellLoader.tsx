"use client";

/**
 * ClientShellLoader.tsx
 *
 * Thin client wrapper that dynamically imports ClientShell with ssr:false.
 * This must be a "use client" file because next/dynamic with ssr:false
 * cannot be used in Server Components.
 */

import dynamic from "next/dynamic";

const ClientShell = dynamic(
    () => import("@/components/ClientShell").then((m) => m.ClientShell),
    { ssr: false }
);

export function ClientShellLoader() {
    return <ClientShell />;
}

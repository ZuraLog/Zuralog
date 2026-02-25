"use client";

/**
 * ClientShellGate — conditionally loads the 3D phone experience.
 *
 * On mobile (< 768px), the 3D phone model is entirely skipped to:
 *   - Save ~2-5MB of GLTF + texture downloads
 *   - Avoid running Three.js / WebGL on low-power devices
 *   - Remove the loading screen dependency on 3D asset progress
 *
 * On desktop (>= 768px), renders ClientShellLoader which dynamically
 * imports the full 3D experience with ssr: false.
 *
 * Note: `useIsMobile` returns `false` on the initial SSR render, then
 * corrects to `true` on mobile after hydration. This brief FOUC is
 * acceptable because the SSR loading overlay covers the canvas anyway.
 * The fallback script in layout.tsx handles overlay dismissal on mobile
 * since LoadingScreen never mounts in that case.
 */

import { useIsMobile } from '@/hooks/use-is-mobile';
import { ClientShellLoader } from './ClientShellLoader';

export function ClientShellGate() {
    const isMobile = useIsMobile();

    if (isMobile) return null;

    return <ClientShellLoader />;
}

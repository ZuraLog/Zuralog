/**
 * HeroSceneLoader — client-side dynamic importer for 3D scenes.
 *
 * Three.js cannot run during SSR. This client component uses next/dynamic
 * with `ssr: false` to safely lazy-load any 3D Canvas component.
 *
 * Usage in Server Components:
 * ```tsx
 * import { HeroSceneLoader } from '@/components/3d/hero-scene-loader';
 * // In JSX:
 * <HeroSceneLoader />
 * ```
 */
'use client';

import dynamic from 'next/dynamic';

/** Lazy-load the test scene with no SSR. Shows a dark placeholder during load. */
const TestScene = dynamic(() => import('./test-scene'), {
  ssr: false,
  loading: () => <div className="h-full w-full bg-background" />,
});

/**
 * Renders the 3D test scene (safe for Server Component parents).
 */
export function HeroSceneLoader() {
  return <TestScene />;
}

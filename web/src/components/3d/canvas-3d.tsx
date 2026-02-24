/**
 * Canvas3D — reusable React Three Fiber Canvas wrapper.
 *
 * Provides sensible performance defaults for the Zuralog website:
 * - DPR clamped to max 2 (saves GPU on retina displays)
 * - Transparent background (composites over CSS)
 * - High-performance GPU hint
 * - Suspense boundary with null fallback for lazy-loaded assets
 * - Preload all assets before first render
 *
 * Always import via dynamic() with `ssr: false` to avoid SSR issues:
 * ```tsx
 * const HeroScene = dynamic(() => import('@/components/3d/canvas-3d'), { ssr: false });
 * ```
 */
'use client';

import { Canvas } from '@react-three/fiber';
import { Preload } from '@react-three/drei';
import { Suspense } from 'react';

interface Canvas3DProps {
  /** 3D scene children. */
  children: React.ReactNode;
  /** Optional CSS class for the canvas container. */
  className?: string;
}

/**
 * Wraps children in a configured R3F Canvas with performance defaults.
 *
 * @param props.children - Three.js scene objects.
 * @param props.className - Optional wrapper class.
 */
export function Canvas3D({ children, className }: Canvas3DProps) {
  return (
    <Canvas
      className={className}
      dpr={[1, Math.min(typeof window !== 'undefined' ? window.devicePixelRatio : 1, 2)]}
      gl={{
        antialias: true,
        alpha: true,
        powerPreference: 'high-performance',
      }}
      camera={{ position: [0, 0, 5], fov: 45 }}
    >
      <Suspense fallback={null}>
        {children}
        <Preload all />
      </Suspense>
    </Canvas>
  );
}

/**
 * HeroSceneLoader — SSR-safe dynamic loader for the 3D hero scene.
 *
 * Changes from previous version:
 *   - Loads real GLTF iPhone 17 Pro Max model (via hero-scene.tsx preload)
 *   - Adds Preload all for asset warming
 */
"use client";

import dynamic from "next/dynamic";
import { Canvas } from "@react-three/fiber";
import { Suspense } from "react";
import { Preload } from "@react-three/drei";
import { useDevice } from "@/hooks/use-device";

const HeroScene = dynamic(
  () => import("./hero-scene").then((m) => ({ default: m.HeroScene })),
  { ssr: false, loading: () => null },
);

export function HeroSceneLoader() {
  const { isMobile } = useDevice();

  return (
    <Suspense fallback={null}>
      <Canvas
        dpr={[1, isMobile ? 1.5 : 2]}
        gl={{
          antialias: !isMobile,
          alpha: true,
          powerPreference: "high-performance",
        }}
        camera={{ position: [0, 0, 5], fov: 50 }}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
        }}
      >
        <HeroScene isMobile={isMobile} />
        <Preload all />
      </Canvas>
    </Suspense>
  );
}

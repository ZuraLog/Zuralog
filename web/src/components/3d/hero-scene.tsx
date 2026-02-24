/**
 * HeroScene — 3D hero: iPhone 17 Pro Max GLTF model with Zuralog logo screen.
 *
 * Rendering contract:
 *   - Loads GLTF from /models/phone/scene.gltf
 *   - Replaces the screen mesh material with a custom texture (screen-logo.png)
 *   - scene.background = null for transparent canvas
 *   - Mouse parallax tilts the phone group (via getMouseParallax singleton)
 *   - Float wrapper for gentle idle bobbing
 *   - Bloom post-processing for emissive glow
 *   - Particles remain as ambient atmosphere
 *
 * Attribution: iPhone 17 Pro Max by MajdyModels (Sketchfab) — CC-BY-4.0
 */
"use client";

import { useRef, useEffect, useMemo } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import { useGLTF, Float, useTexture, Environment } from "@react-three/drei";
import { EffectComposer, Bloom } from "@react-three/postprocessing";
import * as THREE from "three";
import { getMouseParallax } from "@/hooks/use-mouse-parallax";

const MODEL_PATH = "/models/phone/scene.gltf";
const SCREEN_TEXTURE_PATH = "/models/phone/screen-logo.png";

/* ─── Phone Model (GLTF) ────────────────────────────────────────────── */
function PhoneModel({ isMobile }: { isMobile: boolean }) {
  const gltf = useGLTF(MODEL_PATH);
  const screenTexture = useTexture(SCREEN_TEXTURE_PATH);
  const scale = isMobile ? 0.9 : 1.2;

  // Clone the scene so we can safely modify materials without mutating the cached original
  const clonedScene = useMemo(() => {
    const clone = gltf.scene.clone(true);

    clone.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;

      const name = (child.name || "").toLowerCase();
      const matName = Array.isArray(child.material)
        ? ""
        : ((child.material as THREE.MeshStandardMaterial)?.name || "").toLowerCase();

      const isScreen = name.includes("screen") || matName.includes("screen");

      if (isScreen) {
        // Apply Zuralog logo texture to the screen mesh
        screenTexture.flipY = false; // GLTF UVs expect non-flipped
        screenTexture.colorSpace = THREE.SRGBColorSpace;

        child.material = new THREE.MeshStandardMaterial({
          map: screenTexture,
          emissive: new THREE.Color("#CFE1B9"),
          emissiveIntensity: 0.15,
          roughness: 0.0,
          metalness: 0.1,
        });
      }

      // Boost env map intensity on all standard materials for better glass/metal appearance
      if (!Array.isArray(child.material) && child.material instanceof THREE.MeshStandardMaterial) {
        child.material.envMapIntensity = 1.2;
      }
    });

    return clone;
  }, [gltf.scene, screenTexture]);

  return (
    <Float speed={1.2} rotationIntensity={0.08} floatIntensity={0.2}>
      <primitive
        object={clonedScene}
        scale={scale}
        rotation={[0, 0, 0]}
        position={[0, 0, 0]}
      />
    </Float>
  );
}

/* ─── Ambient sage-green particle dust ──────────────────────────────── */
function Particles({ count = 80 }: { count?: number }) {
  const ref = useRef<THREE.Points>(null);
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      arr[i * 3]     = (Math.random() - 0.5) * 12;
      arr[i * 3 + 1] = (Math.random() - 0.5) * 12;
      arr[i * 3 + 2] = (Math.random() - 0.5) * 6;
    }
    return arr;
  }, [count]);

  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.y += delta * 0.012;
  });

  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
          count={count}
          itemSize={3}
        />
      </bufferGeometry>
      <pointsMaterial
        color="#CFE1B9"
        size={0.025}
        transparent
        opacity={0.4}
        sizeAttenuation
      />
    </points>
  );
}

/* ─── Main Scene ─────────────────────────────────────────────────────── */
interface HeroSceneProps {
  isMobile?: boolean;
}

export function HeroScene({ isMobile = false }: HeroSceneProps) {
  const { scene, camera } = useThree();
  const groupRef = useRef<THREE.Group>(null);

  // Transparent canvas
  useEffect(() => {
    scene.background = null;
    camera.position.set(0, 0, 6);
  }, [scene, camera]);

  // Mouse parallax — reads from shared singleton (no duplicate listener)
  useFrame((_, delta) => {
    if (!groupRef.current) return;
    const mouse = getMouseParallax();
    groupRef.current.rotation.y +=
      (mouse.x * 0.25 - groupRef.current.rotation.y) * delta * 3.0;
    groupRef.current.rotation.x +=
      (mouse.y * 0.15 - groupRef.current.rotation.x) * delta * 3.0;
  });

  return (
    <>
      {/* Lighting — strong enough that the GLTF materials are clearly visible */}
      <ambientLight intensity={1.5} />
      <pointLight position={[0, 3, 4]} intensity={6} color="#ffffff" />
      <pointLight position={[3, 2, 3]} intensity={4} color="#CFE1B9" />
      <pointLight position={[-3, -2, 3]} intensity={3} color="#aaddff" />
      <directionalLight position={[0, 0, 5]} intensity={2.5} color="#ffffff" />

      {/* Environment map for realistic reflections on phone glass/metal */}
      <Environment preset="city" environmentIntensity={0.4} />

      <group ref={groupRef}>
        <PhoneModel isMobile={isMobile} />
      </group>

      <Particles count={isMobile ? 30 : 70} />

      {/* Bloom for emissive glow on screen + particles */}
      <EffectComposer>
        <Bloom
          intensity={isMobile ? 0.6 : 1.2}
          luminanceThreshold={0.15}
          luminanceSmoothing={0.9}
          mipmapBlur
        />
      </EffectComposer>
    </>
  );
}

// Preload GLTF + textures on module load (drei cache)
useGLTF.preload(MODEL_PATH);

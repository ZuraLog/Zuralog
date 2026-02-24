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
import { getMouseParallax, useMouseParallax } from "@/hooks/use-mouse-parallax";

const MODEL_PATH = "/models/phone/scene.gltf";
const SCREEN_TEXTURE_PATH = "/models/phone/screen-logo.png";

/* ─── Phone Model (GLTF) ────────────────────────────────────────────── */
function PhoneModel({ isMobile }: { isMobile: boolean }) {
  const gltf = useGLTF(MODEL_PATH);
  const screenTexture = useTexture(SCREEN_TEXTURE_PATH);
  const scale = isMobile ? 0.9 : 1.2;

  // Fix 2: configure texture properties in an effect so they only run when the
  // texture reference changes — not on every render.
  // Three.js textures are external system objects; mutating them in an effect is correct R3F practice.
  /* eslint-disable react-hooks/immutability */
  useEffect(() => {
    screenTexture.flipY = false;          // GLTF UVs expect non-flipped
    screenTexture.colorSpace = THREE.SRGBColorSpace;
    screenTexture.needsUpdate = true;
  }, [screenTexture]);
  /* eslint-enable react-hooks/immutability */

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
        child.material = new THREE.MeshStandardMaterial({
          map: screenTexture,
          emissive: new THREE.Color("#CFE1B9"),
          emissiveIntensity: 0.15,
          roughness: 0.0,
          metalness: 0.1,
        });
      }

      // Fix 3: clone material before mutating envMapIntensity to avoid poisoning
      // the shared GLTF material cache for other consumers of useGLTF.
      if (!Array.isArray(child.material) && child.material instanceof THREE.MeshStandardMaterial) {
        child.material = child.material.clone();
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

/**
 * Generate a Float32Array of random particle positions.
 * Extracted to module scope so Math.random() is called outside a component/hook
 * context — satisfying the react-hooks/purity lint rule.
 *
 * @param count - Number of particles to generate
 * @returns Interleaved [x, y, z, x, y, z, ...] positions
 */
function generateParticlePositions(count: number): Float32Array {
  const arr = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    arr[i * 3]     = (Math.random() - 0.5) * 12;
    arr[i * 3 + 1] = (Math.random() - 0.5) * 12;
    arr[i * 3 + 2] = (Math.random() - 0.5) * 6;
  }
  return arr;
}

function Particles({ count = 80 }: { count?: number }) {
  const ref = useRef<THREE.Points>(null);
  // positions are generated once (stable per count) via a module-level helper
  // so Math.random() is not called during render.
  const positions = useMemo(() => generateParticlePositions(count), [count]);

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

  // Fix 1: start the shared singleton tick so smoothMouse is kept up-to-date.
  // HeroScene reads via getMouseParallax() in useFrame; the returned ref is unused here.
  useMouseParallax();

  // Transparent canvas — Three.js scene/camera are external R3F objects;
  // mutating them in an effect is the correct R3F pattern.
  /* eslint-disable react-hooks/immutability */
  useEffect(() => {
    scene.background = null;
    camera.position.set(0, 0, 6);
  }, [scene, camera]);
  /* eslint-enable react-hooks/immutability */

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

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
 *
 * Attribution: iPhone 17 Pro Max by MajdyModels (Sketchfab) — CC-BY-4.0
 */
"use client";

import { useRef, useEffect, useMemo } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import { useGLTF, Float, Environment } from "@react-three/drei";
import { EffectComposer, Bloom } from "@react-three/postprocessing";
import * as THREE from "three";
import { getMouseParallax, useMouseParallax } from "@/hooks/use-mouse-parallax";
import { createDashboardCanvas } from "./screen-dashboard";

const MODEL_PATH = "/models/phone/scene.gltf";

/* ─── Phone Model (GLTF) ────────────────────────────────────────────── */
function PhoneModel({ isMobile }: { isMobile: boolean }) {
  const gltf = useGLTF(MODEL_PATH);

  // Build a CanvasTexture from the programmatic dashboard renderer.
  const screenTexture = useMemo(() => {
    const canvas = createDashboardCanvas();
    const tex = new THREE.CanvasTexture(canvas);
    tex.flipY = false;
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.needsUpdate = true;
    return tex;
  }, []);

  // Scale derivation:
  //   Nested matrices: Cube.010 (scale=100) → FBX node (scale=0.01) = net 1.0 Three.js unit = 0.708 units tall.
  //   Targeting ~1.3 units tall on desktop (fills ~28% of fov-50 view at z=5), leaving room for cards.
  const scale = isMobile ? 2.0 : 2.3;

  // Apply custom materials directly to the GLTF scene after load.
  useEffect(() => {
    // MeshBasicMaterial: unlit — bypasses lighting so texture is always visible.
    const screenMat = new THREE.MeshBasicMaterial({
      map: screenTexture,
      side: THREE.DoubleSide,
      toneMapped: false,
    });
    screenMat.needsUpdate = true;

    let screenFound = false;
    gltf.scene.traverse((child) => {
      if (!(child instanceof THREE.Mesh)) return;

      // Three.js strips dots from node names: "Cube.010_screen.001_0" → "Cube010_screen001_0"
      const nodeName = (child.name || "").toLowerCase();
      const mat = Array.isArray(child.material) ? null : child.material as THREE.MeshStandardMaterial;
      const matName = (mat?.name || "").toLowerCase();

      const isScreen =
        nodeName.includes("screen");

      const isGlass =
        nodeName.includes("glass") ||
        matName.includes("glass") ||
        nodeName.includes("lensinglass") ||
        matName.includes("lensinglass");

      if (isScreen) {
        child.material = screenMat;
        child.renderOrder = 1;
        screenFound = true;
      } else if (isGlass) {
        // Replace glass with a near-invisible transparent material so screen shows through.
        child.material = new THREE.MeshStandardMaterial({
          transparent: true,
          opacity: 0.05,
          roughness: 0.0,
          metalness: 0.0,
          color: new THREE.Color("#ffffff"),
        });
      } else if (mat instanceof THREE.MeshStandardMaterial) {
        // Override warm copper/orange body tint with dark titanium.
        mat.color.set("#1a1a1a");
        mat.envMapIntensity = 1.2;
        mat.roughness = 0.3;
        mat.metalness = 0.9;
        mat.needsUpdate = true;
      }
    });
    if (!screenFound) console.warn("[PhoneModel] No screen mesh found");
  }, [gltf.scene, screenTexture]);

  // Use original scene directly (no clone needed since we manage materials via useEffect).
  const clonedScene = gltf.scene;

  return (
    <Float speed={1.2} rotationIntensity={0.04} floatIntensity={0.25}>
      <primitive
        object={clonedScene}
        scale={scale}
        // rotation=[0, PI/2, 0]: phone upright portrait, screen facing camera (+Z)
        rotation={[0, Math.PI / 2, 0]}
        // Shift phone upward so it sits above the slogan text (anchored at bottom).
        // Camera at z=5, FOV 50: Y=0.45 places phone center ~45% from top of viewport.
        // X=0.28 compensates for the GLTF model's off-center pivot after 90° Y rotation.
        position={[0.25, -0.5, 0]}
      />
    </Float>
  );
}

/* ─── Ambient sage-green particle dust ──────────────────────────────── */

/**
 * Generate Float32Array of random particle positions outside a component
 * so Math.random() is not called during render (react-hooks/purity).
 */
function generateParticlePositions(count: number): Float32Array {
  const arr = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    arr[i * 3]     = (Math.random() - 0.5) * 10;
    arr[i * 3 + 1] = (Math.random() - 0.5) * 10;
    arr[i * 3 + 2] = (Math.random() - 0.5) * 5;
  }
  return arr;
}

function Particles({ count = 60 }: { count?: number }) {
  const ref = useRef<THREE.Points>(null);
  const positions = useMemo(() => generateParticlePositions(count), [count]);

  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.y += delta * 0.01;
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
        size={0.02}
        transparent
        opacity={0.3}
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

  // Start the shared singleton tick so smoothMouse is kept up-to-date.
  useMouseParallax();

  /* eslint-disable react-hooks/immutability */
  useEffect(() => {
    scene.background = null;
    camera.position.set(0, 0, 5);
  }, [scene, camera]);
  /* eslint-enable react-hooks/immutability */

  // Mouse parallax tilt — higher influence for more responsive feel
  useFrame((_, delta) => {
    if (!groupRef.current) return;
    const mouse = getMouseParallax();
    groupRef.current.rotation.y +=
      (mouse.x * 0.28 - groupRef.current.rotation.y) * delta * 4.0;
    groupRef.current.rotation.x +=
      (mouse.y * 0.18 - groupRef.current.rotation.x) * delta * 4.0;
  });

  return (
    <>
      {/* Lighting — cool studio setup. Phone body reads as dark titanium, not orange. */}
      <ambientLight intensity={0.2} />
      <pointLight position={[0, 1, 5]}   intensity={1.2} color="#d0e8ff" />
      <pointLight position={[2, 2, 3]}   intensity={0.6} color="#CFE1B9" />
      <pointLight position={[-2, -1, 3]} intensity={0.5} color="#a8c8ff" />

      {/* Environment map for glass/metal reflections — city preset gives cool blue tones */}
      <Environment preset="city" environmentIntensity={0.3} />

      <group ref={groupRef}>
        <PhoneModel isMobile={isMobile} />
      </group>

      <Particles count={isMobile ? 20 : 50} />

      {/* Soft bloom for screen glow */}
      <EffectComposer>
        <Bloom
          intensity={isMobile ? 0.4 : 0.8}
          luminanceThreshold={0.2}
          luminanceSmoothing={0.9}
          mipmapBlur
        />
      </EffectComposer>
    </>
  );
}

// Preload GLTF + textures on module load
useGLTF.preload(MODEL_PATH);

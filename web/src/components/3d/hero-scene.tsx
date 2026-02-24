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

  // The GLTF root node bakes a 90° X-axis rotation (Blender→GLTF axis correction).
  // Internally the phone is stored lying on its back pointing left.
  // We undo that baked rotation then orient the phone:
  //   - Stand it upright:    rotate X by +Math.PI/2 (un-bake the Blender correction)
  //   - Face screen forward: rotate Y by Math.PI    (flip 180° so screen faces +Z / camera)
  //
  // Scale derivation:
  //   The mesh sits inside nested matrices: Cube.010 (scale=100) → FBX node (scale=0.01)
  //   → Sketchfab_model (rotation only). Net scale of 1.0 in Three.js = 0.708 scene units tall.
  //   We target ~2.5 units tall so the phone fills ~55% of fov-50 view at camera z=5.
  //   Required scale = 2.5 / 0.708 ≈ 3.53.
  // Target phone to fill ~60% of the hero height — visible but not overwhelming.
  // 0.708 Three.js units = phone height at scale 1.0; targeting ~1.3 units = scale 1.83.
  const scale = isMobile ? 1.3 : 1.83;

  // Three.js textures are external system objects; mutating them in an effect is correct R3F practice.
  /* eslint-disable react-hooks/immutability */
  useEffect(() => {
    screenTexture.flipY = false;              // GLTF UVs are not flipped
    screenTexture.colorSpace = THREE.SRGBColorSpace;
    screenTexture.wrapS = THREE.ClampToEdgeWrapping;
    screenTexture.wrapT = THREE.ClampToEdgeWrapping;
    screenTexture.needsUpdate = true;
  }, [screenTexture]);
  /* eslint-enable react-hooks/immutability */

  // Clone the scene so we can safely modify materials without mutating the cached original.
  // useMemo re-runs only when gltf.scene or screenTexture changes.
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
        // Replace with Zuralog logo material — emissive so it glows
        child.material = new THREE.MeshStandardMaterial({
          map: screenTexture,
          emissive: new THREE.Color("#CFE1B9"),
          emissiveMap: screenTexture,
          emissiveIntensity: 0.5,
          roughness: 0.05,
          metalness: 0.0,
          toneMapped: false,
        });
      } else {
        // Clone all other materials to avoid polluting the shared cache.
        // Boost emissive slightly so the phone body is visible on dark bg.
        if (!Array.isArray(child.material) && child.material instanceof THREE.MeshStandardMaterial) {
          child.material = child.material.clone();
          child.material.envMapIntensity = 2.5;
        }
      }
    });

    return clone;
  }, [gltf.scene, screenTexture]);

  return (
      <Float speed={1.4} rotationIntensity={0.05} floatIntensity={0.3}>
      <primitive
        object={clonedScene}
        scale={scale}
        // Undo baked Blender 90° X correction, then face screen toward camera (+Z).
        // After undoing X, screen faces +X so we rotate -90° around Y to bring it to +Z.
        rotation={[0, Math.PI / 2, 0]}
        position={[0, -0.3, 0]}
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
    // Camera at z=5 with fov=50 gives a good framing for the enlarged phone
    camera.position.set(0, 0, 5);
  }, [scene, camera]);
  /* eslint-enable react-hooks/immutability */

  // Mouse parallax — gentle tilt, reads from shared singleton (no duplicate listener)
  useFrame((_, delta) => {
    if (!groupRef.current) return;
    const mouse = getMouseParallax();
    groupRef.current.rotation.y +=
      (mouse.x * 0.18 - groupRef.current.rotation.y) * delta * 2.5;
    groupRef.current.rotation.x +=
      (mouse.y * 0.10 - groupRef.current.rotation.x) * delta * 2.5;
  });

  return (
    <>
      {/* Lighting — cool-toned studio to contrast the warm CSS glow behind canvas */}
      <ambientLight intensity={0.3} />
      <pointLight position={[0, 1, 5]}   intensity={3.0} color="#e8f0ff" />
      <pointLight position={[3, 2, 3]}   intensity={1.5} color="#CFE1B9" />
      <pointLight position={[-3, -1, 4]} intensity={1.2} color="#b0d0ff" />
      <directionalLight position={[0, 1, 5]} intensity={1.5} color="#ddeeff" />

      {/* Environment map for realistic reflections on phone glass/metal */}
      <Environment preset="night" environmentIntensity={0.5} />

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

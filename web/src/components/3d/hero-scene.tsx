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

  // Scale derivation:
  //   Nested matrices: Cube.010 (scale=100) → FBX node (scale=0.01) = net 1.0 Three.js unit = 0.708 units tall.
  //   Targeting ~1.3 units tall on desktop (fills ~28% of fov-50 view at z=5), leaving room for cards.
  const scale = isMobile ? 1.0 : 1.3;

  // Configure texture synchronously in useMemo so it's ready before material creation.
  // GLTF spec: flipY = false (UVs already flipped in GLTF format).
  // eslint-disable-next-line react-hooks/immutability
  screenTexture.flipY = false;
  // eslint-disable-next-line react-hooks/immutability
  screenTexture.colorSpace = THREE.SRGBColorSpace;
  // eslint-disable-next-line react-hooks/immutability
  screenTexture.wrapS = THREE.ClampToEdgeWrapping;
  // eslint-disable-next-line react-hooks/immutability
  screenTexture.wrapT = THREE.ClampToEdgeWrapping;
  // eslint-disable-next-line react-hooks/immutability
  screenTexture.needsUpdate = true;

  // Clone scene so we can safely modify materials without mutating the cached original.
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
        // Screen: solid sage-green emissive so the screen visibly glows even if the texture map is dark.
        // Use a flat emissive colour (no emissiveMap) so the whole screen area lights up uniformly.
        // The diffuse map provides the ZuraLog logo pattern on top.
        child.material = new THREE.MeshStandardMaterial({
          map: screenTexture,
          emissive: new THREE.Color("#CFE1B9"),
          emissiveIntensity: 3.0,
          roughness: 0.0,
          metalness: 0.0,
          toneMapped: false,
        });
      } else {
        // Clone other materials; override the warm copper/orange hue with dark titanium grey.
        if (!Array.isArray(child.material) && child.material instanceof THREE.MeshStandardMaterial) {
          child.material = child.material.clone();
          // Force a near-black titanium colour regardless of original baked texture tint
          child.material.color.set("#1a1a1a");
          child.material.envMapIntensity = 1.2;
          child.material.roughness = 0.3;
          child.material.metalness = 0.9;
        }
      }
    });

    return clone;
  }, [gltf.scene, screenTexture]);

  return (
    <Float speed={1.2} rotationIntensity={0.04} floatIntensity={0.25}>
      <primitive
        object={clonedScene}
        scale={scale}
        // rotation=[0, PI/2, 0]: phone upright portrait, screen facing camera (+Z)
        rotation={[0, Math.PI / 2, 0]}
        // Centered — slight upward offset so the phone sits in the upper half of canvas
        position={[0, 0.1, 0]}
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

  // Gentle mouse parallax tilt
  useFrame((_, delta) => {
    if (!groupRef.current) return;
    const mouse = getMouseParallax();
    groupRef.current.rotation.y +=
      (mouse.x * 0.12 - groupRef.current.rotation.y) * delta * 2.5;
    groupRef.current.rotation.x +=
      (mouse.y * 0.07 - groupRef.current.rotation.x) * delta * 2.5;
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

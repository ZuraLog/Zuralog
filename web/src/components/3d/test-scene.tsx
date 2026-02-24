/**
 * TestScene — verification scene for the Three.js pipeline.
 *
 * Renders a floating Sage Green sphere with bloom glow to confirm:
 * - R3F Canvas renders correctly
 * - Drei Float animation works
 * - Postprocessing bloom is functional
 * - Transparent background composites over CSS
 *
 * Remove this file after Phase 3.2 when the real hero scene is built.
 */
'use client';

import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Float, Environment } from '@react-three/drei';
import { EffectComposer, Bloom } from '@react-three/postprocessing';
import type { Mesh } from 'three';
import { Canvas3D } from './canvas-3d';

/** Sage Green as a linear RGB value for Three.js materials. */
const SAGE_GREEN = '#CFE1B9';

/**
 * FloatingSphere — the animated sphere mesh inside the test scene.
 */
function FloatingSphere() {
  const meshRef = useRef<Mesh>(null);

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta * 0.3;
    }
  });

  return (
    <Float speed={2} rotationIntensity={0.5} floatIntensity={1}>
      <mesh ref={meshRef}>
        <sphereGeometry args={[1, 64, 64]} />
        <meshStandardMaterial
          color={SAGE_GREEN}
          roughness={0.2}
          metalness={0.1}
          emissive={SAGE_GREEN}
          emissiveIntensity={0.3}
        />
      </mesh>
    </Float>
  );
}

/**
 * TestScene — full scene with canvas, lighting, sphere, and bloom.
 * Dynamically imported in page.tsx with ssr: false.
 */
export default function TestScene() {
  return (
    <div className="h-screen w-full">
      <Canvas3D className="h-full w-full">
        <ambientLight intensity={0.5} />
        <pointLight position={[10, 10, 10]} intensity={1} />
        <FloatingSphere />
        <Environment preset="city" />
        <EffectComposer>
          <Bloom
            luminanceThreshold={0.5}
            luminanceSmoothing={0.9}
            intensity={0.8}
          />
        </EffectComposer>
      </Canvas3D>
    </div>
  );
}

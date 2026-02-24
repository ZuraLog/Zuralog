/**
 * HeroScene — main 3D scene for the hero section.
 *
 * Architecture:
 * - Phone body mesh (rounded rectangle) at center
 * - 5 app icon badges orbiting, then converging on scroll
 * - UI element planes animating onto phone screen
 * - Bloom postprocessing for glow effect
 * - Mouse parallax tilt (5-10 degrees)
 * - Float animation from Drei
 */
"use client";

import { useRef, useState, useEffect } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import { Float, Environment, MeshDistortMaterial, Sphere, RoundedBox } from "@react-three/drei";
import { EffectComposer, Bloom } from "@react-three/postprocessing";
import * as THREE from "three";

interface AppIconProps {
  position: [number, number, number];
  color: string;
  phase: number;
  converging: boolean;
  mobile?: boolean;
}

/**
 * Individual orbiting app icon sphere.
 */
function AppIcon({ position: initialPos, color, phase, converging, mobile = false }: AppIconProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const posRef = useRef(new THREE.Vector3(...initialPos));
  const targetRef = useRef(new THREE.Vector3(0, 0, 0.3));
  const time = useRef(0);
  const [opacity, setOpacity] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setOpacity(1), phase * 200);
    return () => clearTimeout(t);
  }, [phase]);

  useFrame((_, delta) => {
    if (!meshRef.current) return;
    time.current += delta;
    
    if (converging) {
      posRef.current.lerp(targetRef.current, delta * 2.5);
    } else {
      const orbitRadius = mobile ? 1.8 : 2.5;
      const orbitSpeed = 0.3 + phase * 0.05;
      const angle = time.current * orbitSpeed + phase;
      posRef.current.x = Math.cos(angle) * orbitRadius;
      posRef.current.y = Math.sin(angle * 0.7) * 0.8 + initialPos[1] * 0.3;
      posRef.current.z = Math.sin(angle) * 0.5;
    }

    meshRef.current.position.copy(posRef.current);
    meshRef.current.rotation.y += delta * 0.5;
  });

  return (
    <mesh ref={meshRef}>
      <boxGeometry args={[0.35, 0.35, 0.08]} />
      <meshStandardMaterial
        color={color}
        emissive={color}
        emissiveIntensity={1.2}
        transparent
        opacity={opacity}
        roughness={0.05}
        metalness={0.9}
      />
    </mesh>
  );
}

/**
 * Floating phone body with animated UI planes on screen.
 */
function PhoneModel({ isMobile }: { isMobile: boolean }) {
  const scale = isMobile ? 0.8 : 1;

  return (
    <Float speed={1.5} rotationIntensity={0.15} floatIntensity={0.3}>
      <group scale={scale}>
        {/* Phone body */}
        <RoundedBox args={[1.2, 2.4, 0.12]} radius={0.12} smoothness={6}>
          <meshStandardMaterial
            color="#1C1C1E"
            roughness={0.1}
            metalness={0.9}
          />
        </RoundedBox>

        {/* Screen */}
        <RoundedBox args={[1.0, 2.1, 0.02]} radius={0.08} smoothness={4} position={[0, 0, 0.065]}>
          <meshStandardMaterial
            color="#000000"
            emissive="#0a0a0a"
            emissiveIntensity={0.5}
            roughness={0.0}
          />
        </RoundedBox>

        {/* UI: Activity card */}
        <RoundedBox args={[0.55, 0.22, 0.01]} radius={0.04} smoothness={4} position={[-0.25, 0.4, 0.08]}>
          <meshStandardMaterial
            color="#1C1C1E"
            emissive="#CFE1B9"
            emissiveIntensity={0.12}
          />
        </RoundedBox>

        {/* UI: Metric value */}
        <RoundedBox args={[0.35, 0.14, 0.01]} radius={0.03} smoothness={4} position={[0.2, 0.1, 0.08]}>
          <meshStandardMaterial color="#2C2C2E" emissive="#CFE1B9" emissiveIntensity={0.08} />
        </RoundedBox>

        {/* UI: Chart bar 1 */}
        <mesh position={[-0.3, -0.35, 0.08]}>
          <boxGeometry args={[0.08, 0.4, 0.01]} />
          <meshStandardMaterial color="#CFE1B9" emissive="#CFE1B9" emissiveIntensity={0.6} />
        </mesh>
        {/* UI: Chart bar 2 */}
        <mesh position={[-0.15, -0.2, 0.08]}>
          <boxGeometry args={[0.08, 0.25, 0.01]} />
          <meshStandardMaterial color="#CFE1B9" emissive="#CFE1B9" emissiveIntensity={0.4} />
        </mesh>
        {/* UI: Chart bar 3 */}
        <mesh position={[0.0, -0.28, 0.08]}>
          <boxGeometry args={[0.08, 0.33, 0.01]} />
          <meshStandardMaterial color="#CFE1B9" emissive="#CFE1B9" emissiveIntensity={0.5} />
        </mesh>
        {/* UI: Chat bubble */}
        <RoundedBox args={[0.7, 0.18, 0.01]} radius={0.04} smoothness={4} position={[0, -0.7, 0.08]}>
          <meshStandardMaterial color="#2C2C2E" emissive="#ffffff" emissiveIntensity={0.03} />
        </RoundedBox>

        {/* Home indicator */}
        <RoundedBox args={[0.3, 0.04, 0.01]} radius={0.02} smoothness={4} position={[0, -1.1, 0.068]}>
          <meshStandardMaterial color="#48484A" />
        </RoundedBox>
      </group>
    </Float>
  );
}

interface AmbientParticlesProps {
  count?: number;
}

/**
 * Floating ambient particle field.
 */
function AmbientParticles({ count = 60 }: AmbientParticlesProps) {
  const meshRef = useRef<THREE.Points>(null);
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 8;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 8;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 4;
  }

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta * 0.02;
    }
  });

  return (
    <points ref={meshRef}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" count={count} array={positions} itemSize={3} args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial color="#CFE1B9" size={0.025} transparent opacity={0.35} sizeAttenuation />
    </points>
  );
}

const APP_ICONS = [
  { color: "#FC4C02", phase: 0, position: [2.5, 0.5, 0] as [number, number, number] },
  { color: "#1DB954", phase: 1, position: [-2.0, 0.8, 0.5] as [number, number, number] },
  { color: "#FF6B35", phase: 2, position: [1.5, -1.0, -0.3] as [number, number, number] },
  { color: "#FF3B30", phase: 3, position: [-1.8, -0.5, 0.2] as [number, number, number] },
  { color: "#5856D6", phase: 4, position: [0.5, 1.5, -0.5] as [number, number, number] },
];

interface HeroSceneProps {
  isMobile?: boolean;
}

/**
 * Main 3D hero scene with phone, orbiting icons, and effects.
 */
export function HeroScene({ isMobile = false }: HeroSceneProps) {
  const { camera } = useThree();
  const [converging, setConverging] = useState(false);
  const mouseRef = useRef({ x: 0, y: 0 });
  const groupRef = useRef<THREE.Group>(null);

  // Set camera position
  useEffect(() => {
    camera.position.set(0, 0, 5);
  }, [camera]);

  // Start convergence animation after 2s
  useEffect(() => {
    const t = setTimeout(() => setConverging(true), 2500);
    return () => clearTimeout(t);
  }, []);

  // Mouse parallax
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      mouseRef.current.x = (e.clientX / window.innerWidth - 0.5) * 2;
      mouseRef.current.y = -(e.clientY / window.innerHeight - 0.5) * 2;
    };
    window.addEventListener("mousemove", handler);
    return () => window.removeEventListener("mousemove", handler);
  }, []);

  useFrame((_, delta) => {
    if (groupRef.current) {
      groupRef.current.rotation.y += (mouseRef.current.x * 0.35 - groupRef.current.rotation.y) * delta * 4;
      groupRef.current.rotation.x += (mouseRef.current.y * 0.25 - groupRef.current.rotation.x) * delta * 4;
    }
  });

  const icons = isMobile ? APP_ICONS.slice(0, 3) : APP_ICONS;

  return (
    <>
      {/* Boosted lighting so the scene is clearly visible */}
      <ambientLight intensity={1.2} />
      <pointLight position={[3, 3, 3]} intensity={4} color="#CFE1B9" />
      <pointLight position={[-3, -2, 2]} intensity={2} color="#ffffff" />
      <pointLight position={[0, 0, 4]} intensity={2} color="#ffffff" />
      <Environment preset="city" />

      <group ref={groupRef}>
        <PhoneModel isMobile={isMobile} />
        {icons.map((icon, i) => (
          <AppIcon
            key={i}
            position={icon.position}
            color={icon.color}
            phase={icon.phase}
            converging={converging}
            mobile={isMobile}
          />
        ))}
      </group>

      {!isMobile && <AmbientParticles count={60} />}
      {!isMobile && (
        <EffectComposer>
          <Bloom intensity={1.2} luminanceThreshold={0.3} luminanceSmoothing={0.6} mipmapBlur />
        </EffectComposer>
      )}
    </>
  );
}

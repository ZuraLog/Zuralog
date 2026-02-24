/**
 * HeroScene — 3D hero scene: floating phone + orbiting app-colored icons.
 *
 * Rendering contract:
 *   - scene.background is set to null so the WebGL canvas is transparent
 *     and the CSS hero background (OLED black + sage glow) shows through.
 *   - All materials use high emissiveIntensity values so objects are clearly
 *     visible without relying on reflection/environment maps.
 *   - Mouse parallax rotates the whole group (X and Y axes).
 *   - App icons orbit for 3 s then converge into the phone center.
 */
"use client";

import { useRef, useState, useEffect } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import { Float, RoundedBox, Sphere } from "@react-three/drei";
import { EffectComposer, Bloom } from "@react-three/postprocessing";
import * as THREE from "three";

/* ─── App icon colours (brand-approximate) ──────────────────────────── */
const APP_ICONS: { color: string; phase: number; position: [number, number, number] }[] = [
  { color: "#FC4C02", phase: 0, position: [ 2.8,  0.6,  0.0] },  // Strava orange
  { color: "#1DB954", phase: 1, position: [-2.2,  0.9,  0.4] },  // Spotify green
  { color: "#007CC3", phase: 2, position: [ 1.8, -1.2, -0.2] },  // Garmin blue
  { color: "#FF3B30", phase: 3, position: [-2.0, -0.7,  0.3] },  // Apple Health red
  { color: "#9B8EFF", phase: 4, position: [ 0.4,  2.0, -0.4] },  // Oura purple
  { color: "#00B2FF", phase: 5, position: [-1.2, -2.0,  0.2] },  // Fitbit cyan
];

/* ─── Individual orbiting app icon ──────────────────────────────────── */
interface AppIconProps {
  position: [number, number, number];
  color: string;
  phase: number;
  converging: boolean;
  mobile?: boolean;
}

function AppIcon({ position: initPos, color, phase, converging, mobile = false }: AppIconProps) {
  const meshRef  = useRef<THREE.Mesh>(null);
  const posRef   = useRef(new THREE.Vector3(...initPos));
  const targetRef = useRef(new THREE.Vector3(0, 0, 0.4));
  const time     = useRef(phase * 1.3); // stagger start angles
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setVisible(true), phase * 180);
    return () => clearTimeout(t);
  }, [phase]);

  useFrame((_, delta) => {
    if (!meshRef.current) return;
    time.current += delta;

    if (converging) {
      posRef.current.lerp(targetRef.current, delta * 2.0);
    } else {
      const r     = mobile ? 1.9 : 2.6;
      const speed = 0.28 + phase * 0.04;
      const a     = time.current * speed;
      posRef.current.set(
        Math.cos(a) * r,
        Math.sin(a * 0.65) * 0.9 + initPos[1] * 0.25,
        Math.sin(a * 0.5)  * 0.6,
      );
    }

    meshRef.current.position.copy(posRef.current);
    meshRef.current.rotation.y += delta * 0.8;
    meshRef.current.rotation.x += delta * 0.3;
  });

  if (!visible) return null;

  return (
    <mesh ref={meshRef}>
      {/* Rounded square icon badge */}
      <boxGeometry args={[0.38, 0.38, 0.09]} />
      <meshStandardMaterial
        color={color}
        emissive={color}
        emissiveIntensity={2.5}
        roughness={0.1}
        metalness={0.5}
      />
    </mesh>
  );
}

/* ─── Phone body ─────────────────────────────────────────────────────── */
function PhoneModel({ isMobile }: { isMobile: boolean }) {
  const scale = isMobile ? 0.75 : 1;

  return (
    <Float speed={1.4} rotationIntensity={0.12} floatIntensity={0.25}>
      <group scale={scale}>
        {/* Body */}
        <RoundedBox args={[1.15, 2.35, 0.11]} radius={0.13} smoothness={6}>
          <meshStandardMaterial
            color="#2A2A2C"
            emissive="#1a1a1c"
            emissiveIntensity={0.4}
            roughness={0.15}
            metalness={0.85}
          />
        </RoundedBox>

        {/* Screen bezel */}
        <RoundedBox args={[0.98, 2.08, 0.015]} radius={0.09} smoothness={4} position={[0, 0, 0.062]}>
          <meshStandardMaterial
            color="#050505"
            emissive="#CFE1B9"
            emissiveIntensity={0.08}
            roughness={0.0}
            metalness={0.1}
          />
        </RoundedBox>

        {/* Screen content — sage UI bars */}
        {/* Chart bar group */}
        {[
          { x: -0.28, y: -0.30, h: 0.45 },
          { x: -0.13, y: -0.22, h: 0.30 },
          { x:  0.02, y: -0.27, h: 0.38 },
          { x:  0.17, y: -0.18, h: 0.22 },
          { x:  0.32, y: -0.24, h: 0.32 },
        ].map((bar, i) => (
          <mesh key={i} position={[bar.x, bar.y, 0.075]}>
            <boxGeometry args={[0.07, bar.h, 0.008]} />
            <meshStandardMaterial
              color="#CFE1B9"
              emissive="#CFE1B9"
              emissiveIntensity={1.8}
            />
          </mesh>
        ))}

        {/* Activity card */}
        <RoundedBox args={[0.72, 0.20, 0.008]} radius={0.04} smoothness={4} position={[0, 0.50, 0.075]}>
          <meshStandardMaterial color="#1C1C1E" emissive="#CFE1B9" emissiveIntensity={0.35} />
        </RoundedBox>

        {/* Metric pill */}
        <RoundedBox args={[0.42, 0.13, 0.008]} radius={0.04} smoothness={4} position={[0, 0.25, 0.075]}>
          <meshStandardMaterial color="#2C2C2E" emissive="#CFE1B9" emissiveIntensity={0.20} />
        </RoundedBox>

        {/* AI chat bubble */}
        <RoundedBox args={[0.70, 0.16, 0.008]} radius={0.05} smoothness={4} position={[0, -0.72, 0.075]}>
          <meshStandardMaterial color="#1C2E1C" emissive="#CFE1B9" emissiveIntensity={0.45} />
        </RoundedBox>

        {/* Home indicator */}
        <RoundedBox args={[0.28, 0.035, 0.006]} radius={0.02} smoothness={4} position={[0, -1.08, 0.065]}>
          <meshStandardMaterial color="#505055" emissive="#888888" emissiveIntensity={0.3} />
        </RoundedBox>
      </group>
    </Float>
  );
}

/* ─── Ambient sage-green particle dust ──────────────────────────────── */
function Particles({ count = 80 }: { count?: number }) {
  const ref = useRef<THREE.Points>(null);
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    positions[i * 3]     = (Math.random() - 0.5) * 10;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 10;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 5;
  }

  useFrame((_, delta) => {
    if (ref.current) ref.current.rotation.y += delta * 0.015;
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
      <pointsMaterial color="#CFE1B9" size={0.03} transparent opacity={0.5} sizeAttenuation />
    </points>
  );
}

/* ─── Main scene ─────────────────────────────────────────────────────── */
interface HeroSceneProps {
  isMobile?: boolean;
}

export function HeroScene({ isMobile = false }: HeroSceneProps) {
  const { scene, camera } = useThree();
  const groupRef  = useRef<THREE.Group>(null);
  const mouseRef  = useRef({ x: 0, y: 0 });
  const [converging, setConverging] = useState(false);

  /* Make canvas transparent — critical */
  useEffect(() => {
    scene.background = null;
    camera.position.set(0, 0, 6);
  }, [scene, camera]);

  /* Convergence trigger */
  useEffect(() => {
    const t = setTimeout(() => setConverging(true), 3000);
    return () => clearTimeout(t);
  }, []);

  /* Mouse parallax */
  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      mouseRef.current.x =  (e.clientX / window.innerWidth  - 0.5) * 2;
      mouseRef.current.y = -(e.clientY / window.innerHeight - 0.5) * 2;
    };
    window.addEventListener("mousemove", onMove, { passive: true });
    return () => window.removeEventListener("mousemove", onMove);
  }, []);

  useFrame((_, delta) => {
    if (!groupRef.current) return;
    groupRef.current.rotation.y +=
      (mouseRef.current.x * 0.3 - groupRef.current.rotation.y) * delta * 3.5;
    groupRef.current.rotation.x +=
      (mouseRef.current.y * 0.2 - groupRef.current.rotation.x) * delta * 3.5;
  });

  const icons = isMobile ? APP_ICONS.slice(0, 3) : APP_ICONS;

  return (
    <>
      {/* Strong directional lighting — scene must look lit, not black */}
      <ambientLight intensity={2.0} />
      <pointLight position={[0,  3,  4]} intensity={8}  color="#ffffff" />
      <pointLight position={[3,  2,  3]} intensity={6}  color="#CFE1B9" />
      <pointLight position={[-3, -2, 3]} intensity={4}  color="#aaddff" />
      <directionalLight position={[0, 0, 5]} intensity={3} color="#ffffff" />

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

      <Particles count={isMobile ? 40 : 80} />

      {/* Bloom — low threshold so emissive objects glow */}
      <EffectComposer>
        <Bloom
          intensity={isMobile ? 0.8 : 1.5}
          luminanceThreshold={0.1}
          luminanceSmoothing={0.9}
          mipmapBlur
        />
      </EffectComposer>
    </>
  );
}

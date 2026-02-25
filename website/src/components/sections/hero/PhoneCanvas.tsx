"use client";

import { useRef, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { PresentationControls, Environment, useGLTF } from '@react-three/drei';
import * as THREE from 'three';

function PhoneModel() {
    // Load the model from the local public path
    const { scene } = useGLTF('/model/phone/scene.gltf');
    const groupRef = useRef<THREE.Group>(null);

    // Apply material color CFE1B9 to the phone case
    useEffect(() => {
        if (scene) {
            scene.traverse((child) => {
                if ((child as THREE.Mesh).isMesh) {
                    const mesh = child as THREE.Mesh;
                    console.log("Mesh name:", mesh.name, "Material name:", (mesh.material as THREE.Material)?.name);

                    // Basic heuristic to color the case
                    const name = mesh.name.toLowerCase();
                    if (name.includes('basecolor') || name.includes('metalframe') || name.includes('backpanel')) {
                        if (mesh.material) {
                            (mesh.material as THREE.MeshStandardMaterial).color.set('#CFE1B9');
                        }
                    }
                }
            });
        }
    }, [scene]);

    // --- PHONE POSITION CONFIGURATION ---
    // Adjust [x, y, z] to center the phone horizontally, vertically, and depth.
    // X: move left/right (0 is center)
    // Y: move up/down (-2.5 is default base, increase to move higher into the text)
    // Z: move closer/further
    const phonePosition: [number, number, number] = [0.3, -3.2, 0];

    // Global mouse tracking instead of canvas-local tracking
    const mouseRef = useRef({ x: 0, y: 0 });
    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            mouseRef.current.x = (e.clientX / window.innerWidth) * 2 - 1;
            mouseRef.current.y = -(e.clientY / window.innerHeight) * 2 + 1;
        };
        window.addEventListener('mousemove', handleMouseMove);
        return () => window.removeEventListener('mousemove', handleMouseMove);
    }, []);

    // Subtle floating animation for the 3D model itself
    useFrame((state) => {
        if (groupRef.current) {
            // 1. Subtle up/down float
            const floatY = Math.sin(state.clock.elapsedTime) * 0.1;

            // 2. Global mouse parallax influence (scaled down for subtlety)
            const targetX = mouseRef.current.x * 0.15; // reduced intensity
            const targetY = mouseRef.current.y * 0.15; // reduced intensity

            // Interpolate rotation based on global mouse position (INVERTED)
            groupRef.current.rotation.x = THREE.MathUtils.lerp(groupRef.current.rotation.x, -targetY * 0.5, 0.05);
            groupRef.current.rotation.y = THREE.MathUtils.lerp(groupRef.current.rotation.y, (Math.PI / 2) - targetX * 0.5, 0.05);

            // Interpolate position based on global mouse position (INVERTED)
            groupRef.current.position.x = THREE.MathUtils.lerp(groupRef.current.position.x, phonePosition[0] - (targetX * 0.8), 0.05);
            groupRef.current.position.y = phonePosition[1] + floatY;
        }
    });

    return (
        <group ref={groupRef} position={phonePosition} rotation={[0, Math.PI / 2, 0]} scale={2.5}>
            <primitive object={scene} />
        </group>
    );
}

export function PhoneCanvas() {
    return (
        <div className="absolute bottom-0 w-full h-[60vh] z-10 pointer-events-none flex justify-center">
            {/* Container for the 3D canvas */}
            <div className="w-full max-w-[800px] h-full pointer-events-auto cursor-grab active:cursor-grabbing">
                <Canvas camera={{ position: [0, 0, 5], fov: 35 }}>
                    <ambientLight intensity={0.5} />
                    <directionalLight position={[10, 10, 5]} intensity={1} />

                    <PresentationControls
                        global
                        snap
                        rotation={[0, 0, 0]}
                        polar={[-0.1, 0.1]} // Limit vertical rotation
                        azimuth={[-0.4, 0.4]} // Limit horizontal rotation
                    >
                        <PhoneModel />
                    </PresentationControls>

                    <Environment preset="city" />
                </Canvas>
            </div>
        </div>
    );
}

// Preload the model to avoid pop-in
useGLTF.preload('/model/phone/scene.gltf');

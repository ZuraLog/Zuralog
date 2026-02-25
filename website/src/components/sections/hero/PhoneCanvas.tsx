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

    // Subtle floating animation for the 3D model itself
    useFrame((state) => {
        if (groupRef.current) {
            groupRef.current.position.y = Math.sin(state.clock.elapsedTime) * 0.1 - 2;
        }
    });

    return (
        <group ref={groupRef} position={[0, -2, 0]} rotation={[0, Math.PI / 2, 0]} scale={2.5}>
            <primitive object={scene} />
        </group>
    );
}

export function PhoneCanvas() {
    return (
        <div className="absolute bottom-0 w-full h-[60vh] z-20 pointer-events-none flex justify-center">
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

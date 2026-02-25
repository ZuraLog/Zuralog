"use client";

import { useRef, useEffect, useState, useCallback } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { PresentationControls, Environment, useGLTF, useTexture } from '@react-three/drei';
import * as THREE from 'three';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

/**
 * Number of content slides in MobileSection.
 * Must match SLIDE_COUNT in MobileSection.tsx.
 */
const SLIDE_COUNT = 4;

/**
 * Screen textures in order: hero screen, then one per slide.
 * Index 0 = hero (screen.png)
 * Index 1-4 = content slides
 */
const TEXTURE_PATHS = [
    '/model/phone/textures/screen.png',
    '/model/phone/textures/content_1.png',
    '/model/phone/textures/content_2.png',
    '/model/phone/textures/content_3.png',
    '/model/phone/textures/content_4.png',
];

/**
 * Custom shader material for vertical swipe transition between two textures.
 * Creates a sliding reveal effect as if the user swiped up on the phone screen.
 */
const SwipeTransitionShader = {
    uniforms: {
        texCurrent: { value: null as THREE.Texture | null },
        texNext: { value: null as THREE.Texture | null },
        progress: { value: 0.0 },
    },
    vertexShader: `
        varying vec2 vUv;
        void main() {
            vUv = uv;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
    `,
    fragmentShader: `
        uniform sampler2D texCurrent;
        uniform sampler2D texNext;
        uniform float progress;
        varying vec2 vUv;

        void main() {
            // Vertical swipe: next texture slides up from bottom
            float p = clamp(progress, 0.0, 1.0);

            // Current texture slides up and away
            vec2 uvCurrent = vUv + vec2(0.0, p);
            // Next texture slides in from below
            vec2 uvNext = vUv + vec2(0.0, p - 1.0);

            vec4 colCurrent = texture2D(texCurrent, uvCurrent);
            vec4 colNext = texture2D(texNext, uvNext);

            // Show current where UV is in range, next where it's in range
            if (vUv.y + p > 1.0) {
                // This area shows the next texture coming from bottom
                gl_FragColor = colNext;
            } else {
                gl_FragColor = colCurrent;
            }
        }
    `,
};

function PhoneModel() {
    // Load the model from the local public path
    const { scene } = useGLTF('/model/phone/scene.gltf');

    // Load all textures upfront
    const textures = useTexture(TEXTURE_PATHS);

    // Configure all textures
    useEffect(() => {
        textures.forEach((tex) => {
            tex.flipY = false;
        });
    }, [textures]);

    const groupRef = useRef<THREE.Group>(null);
    const screenMeshRef = useRef<THREE.Mesh | null>(null);
    const shaderMatRef = useRef<THREE.ShaderMaterial | null>(null);

    // Track which texture index is currently showing + transition progress
    const currentTextureIndex = useRef(0);
    const targetTextureIndex = useRef(0);

    // Initial base states - used by GSAP to scrub values across scroll
    const basePosition = useRef(new THREE.Vector3(0.3, -3.2, 0));
    const baseRotation = useRef(new THREE.Vector3(0, Math.PI / 2, 0));
    const baseScale = useRef(new THREE.Vector3(2.5, 2.5, 2.5));

    // Apply material color CFE1B9 to the phone case and set up swipe shader on screen
    useEffect(() => {
        if (!scene || textures.length === 0) return;

        const shaderMat = new THREE.ShaderMaterial({
            uniforms: {
                texCurrent: { value: textures[0] },
                texNext: { value: textures[1] },
                progress: { value: 0.0 },
            },
            vertexShader: SwipeTransitionShader.vertexShader,
            fragmentShader: SwipeTransitionShader.fragmentShader,
            side: THREE.DoubleSide,
            toneMapped: false,
        });
        shaderMatRef.current = shaderMat;

        scene.traverse((child) => {
            if (!(child instanceof THREE.Mesh)) return;

            const nodeName = (child.name || "").toLowerCase();
            const mat = Array.isArray(child.material) ? null : child.material as THREE.MeshStandardMaterial;
            const matName = (mat?.name || "").toLowerCase();

            const isScreen = nodeName === "cube010_screen001_0" || matName === "screen.001";
            const isGlass = nodeName === "cube010_glass002_0" || matName === "glass.002" || nodeName === "cube010_lensinglass_0" || matName === "lensinglass";

            if (isScreen) {
                child.material = shaderMat;
                child.renderOrder = 1;
                screenMeshRef.current = child;
            } else if (isGlass) {
                // Ensure front glass is functionally invisible so screen shows perfectly
                child.material = new THREE.MeshStandardMaterial({
                    transparent: true,
                    opacity: 0.05,
                    roughness: 0.0,
                    metalness: 0.0,
                    color: new THREE.Color("#ffffff"),
                });
            } else if (mat instanceof THREE.MeshStandardMaterial) {
                // Continue to tint the rest of the body
                if (nodeName.includes('basecolor') || nodeName.includes('metalframe') || nodeName.includes('backpanel')) {
                    mat.color.set('#CFE1B9');
                    mat.needsUpdate = true;
                }
            }
        });
    }, [scene, textures]);

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

    useGSAP(() => {
        // ──────────────────────────────────────────
        // Phase 1: Hero → MobileSection transition
        // Phone moves from hero position to centered
        // ──────────────────────────────────────────
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: '#mobile-section',
                start: 'top bottom', // Start when MobileSection enters from bottom
                end: 'top center', // Complete when MobileSection top reaches center
                scrub: true,
            }
        });

        // Target centered config for MobileSection (phone on the right side)
        tl.to(basePosition.current, {
            x: 1.2, // Position phone to the right side
            y: -0.1,
            z: 0,
            ease: "none",
        }, 0)
            .to(baseRotation.current, {
                x: 0,
                y: Math.PI / 2,
                z: 0,
                ease: "none",
            }, 0)
            .to(baseScale.current, {
                x: 1.5,
                y: 1.5,
                z: 1.5,
                ease: "none",
            }, 0);

        // ──────────────────────────────────────────
        // Phase 2: First texture swap (hero → content_1)
        // Happens as we enter the mobile section
        // ──────────────────────────────────────────
        ScrollTrigger.create({
            trigger: '#mobile-section',
            start: 'top 60%',
            end: 'top 20%',
            scrub: true,
            onUpdate: (self) => {
                if (!shaderMatRef.current) return;
                // Swap from screen.png (0) to content_1 (1)
                shaderMatRef.current.uniforms.texCurrent.value = textures[0];
                shaderMatRef.current.uniforms.texNext.value = textures[1];
                shaderMatRef.current.uniforms.progress.value = self.progress;
            },
            onLeave: () => {
                if (!shaderMatRef.current) return;
                currentTextureIndex.current = 1;
                // Snap to fully showing content_1
                shaderMatRef.current.uniforms.texCurrent.value = textures[1];
                shaderMatRef.current.uniforms.progress.value = 0;
            },
            onEnterBack: () => {
                currentTextureIndex.current = 0;
            },
        });

    }, { dependencies: [] });

    // Store smoothed mouse values separately so it doesn't interfere with GSAP scroll values
    const smoothMouse = useRef({ x: 0, y: 0 });

    // Subtle floating animation + GSAP base + mouse interactivity + texture swap polling
    useFrame((state) => {
        if (groupRef.current) {
            smoothMouse.current.x = THREE.MathUtils.lerp(smoothMouse.current.x, mouseRef.current.x, 0.05);
            smoothMouse.current.y = THREE.MathUtils.lerp(smoothMouse.current.y, mouseRef.current.y, 0.05);

            const floatY = Math.sin(state.clock.elapsedTime) * 0.1;
            const targetX = smoothMouse.current.x * 0.15;
            const targetY = smoothMouse.current.y * 0.15;

            // Apply base + mouse interactions cleanly
            groupRef.current.rotation.x = baseRotation.current.x - targetY * 0.5;
            groupRef.current.rotation.y = baseRotation.current.y + targetX * 0.5;
            groupRef.current.rotation.z = baseRotation.current.z;

            groupRef.current.position.x = basePosition.current.x + (targetX * 0.8);
            groupRef.current.position.y = basePosition.current.y + floatY;
            groupRef.current.position.z = basePosition.current.z;

            groupRef.current.scale.copy(baseScale.current);
        }

        // ──────────────────────────────────────────
        // Read CSS variable for scroll progress within the pinned section
        // and drive texture transitions between content slides
        // ──────────────────────────────────────────
        if (shaderMatRef.current && textures.length === TEXTURE_PATHS.length) {
            const rawProgress = parseFloat(
                getComputedStyle(document.documentElement)
                    .getPropertyValue('--mobile-scroll-progress') || '0'
            );

            // Map progress to slide transitions
            // Progress 0..1 maps across SLIDE_COUNT slides
            // Between slides we get a transition zone
            const slideDuration = 1 / SLIDE_COUNT;

            for (let i = 0; i < SLIDE_COUNT - 1; i++) {
                const transStart = (i + 1) * slideDuration - slideDuration * 0.3;
                const transEnd = (i + 1) * slideDuration + slideDuration * 0.1;

                if (rawProgress >= transStart && rawProgress <= transEnd) {
                    const transProgress = (rawProgress - transStart) / (transEnd - transStart);
                    // Texture index: content_1 is textures[1], content_2 is textures[2], etc.
                    const fromIdx = i + 1; // content slides start at textures[1]
                    const toIdx = i + 2;

                    if (toIdx < textures.length) {
                        shaderMatRef.current.uniforms.texCurrent.value = textures[fromIdx];
                        shaderMatRef.current.uniforms.texNext.value = textures[toIdx];
                        shaderMatRef.current.uniforms.progress.value = Math.min(transProgress, 1);
                    }
                    break;
                }

                // After the transition, snap to the new texture
                if (rawProgress > transEnd && i + 2 < textures.length) {
                    shaderMatRef.current.uniforms.texCurrent.value = textures[i + 2];
                    shaderMatRef.current.uniforms.progress.value = 0;
                }
            }

            // Update active dot indicators
            const activeSlide = Math.min(
                Math.floor(rawProgress * SLIDE_COUNT),
                SLIDE_COUNT - 1
            );
            document.querySelectorAll('.slide-dot').forEach((dot, i) => {
                if (i === activeSlide) {
                    (dot as HTMLElement).style.backgroundColor = 'rgba(0,0,0,0.7)';
                    (dot as HTMLElement).style.transform = 'scale(1.5)';
                } else {
                    (dot as HTMLElement).style.backgroundColor = 'rgba(0,0,0,0.2)';
                    (dot as HTMLElement).style.transform = 'scale(1)';
                }
            });
        }
    });

    return (
        <group ref={groupRef}>
            <primitive object={scene} />
        </group>
    );
}

export function PhoneCanvas() {
    return (
        <div className="w-full h-full pointer-events-none flex justify-center items-center">
            {/* Container for the 3D canvas */}
            <div className="w-full h-full pointer-events-auto cursor-grab active:cursor-grabbing">
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

// Preload all assets to avoid pop-in
useGLTF.preload('/model/phone/scene.gltf');
TEXTURE_PATHS.forEach((path) => useTexture.preload(path));

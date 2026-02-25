"use client";

import { useRef, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
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
 */
const SwipeTransitionShader = {
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
            float p = clamp(progress, 0.0, 1.0);
            vec2 uvCurrent = vUv + vec2(0.0, p);
            vec2 uvNext = vUv + vec2(0.0, p - 1.0);

            vec4 colCurrent = texture2D(texCurrent, uvCurrent);
            vec4 colNext = texture2D(texNext, uvNext);

            if (vUv.y + p > 1.0) {
                gl_FragColor = colNext;
            } else {
                gl_FragColor = colCurrent;
            }
        }
    `,
};

/**
 * Inner 3D phone model with shader-based screen texture transitions
 * and scroll-driven scale animation.
 *
 * CSS handles all screen-space positioning (fixed vs absolute).
 * This component only manages:
 *   - 3D scale transitions (hero -> MobileSection)
 *   - Mouse parallax tilt/drift
 *   - Idle float animation
 *   - Screen texture swapping via shader uniforms
 */
function PhoneModel() {
    const { scene } = useGLTF('/model/phone/scene.gltf');
    const textures = useTexture(TEXTURE_PATHS);

    useEffect(() => {
        textures.forEach((tex) => {
            tex.flipY = false;
        });
    }, [textures]);

    const groupRef = useRef<THREE.Group>(null);
    const shaderMatRef = useRef<THREE.ShaderMaterial | null>(null);

    /**
     * Base 3D states. Position is centered within the canvas.
     * Scale is animated by GSAP ScrollTrigger.
     */
    const basePosition = useRef(new THREE.Vector3(0, -0.3, 0));
    const baseRotation = useRef(new THREE.Vector3(0, Math.PI / 2, 0));
    const baseScale = useRef(new THREE.Vector3(2.2, 2.2, 2.2));

    /** Apply custom shader material to screen mesh and style body materials. */
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
            const isGlass = nodeName === "cube010_glass002_0" || matName === "glass.002"
                || nodeName === "cube010_lensinglass_0" || matName === "lensinglass";

            if (isScreen) {
                child.material = shaderMat;
                child.renderOrder = 1;
            } else if (isGlass) {
                child.material = new THREE.MeshStandardMaterial({
                    transparent: true,
                    opacity: 0.05,
                    roughness: 0.0,
                    metalness: 0.0,
                    color: new THREE.Color("#ffffff"),
                });
            } else if (mat instanceof THREE.MeshStandardMaterial) {
                if (nodeName.includes('basecolor') || nodeName.includes('metalframe') || nodeName.includes('backpanel')) {
                    mat.color.set('#CFE1B9');
                    mat.needsUpdate = true;
                }
            }
        });
    }, [scene, textures]);

    /** Track mouse position for parallax tilt. */
    const mouseRef = useRef({ x: 0, y: 0 });
    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            mouseRef.current.x = (e.clientX / window.innerWidth) * 2 - 1;
            mouseRef.current.y = -(e.clientY / window.innerHeight) * 2 + 1;
        };
        window.addEventListener('mousemove', handleMouseMove);
        return () => window.removeEventListener('mousemove', handleMouseMove);
    }, []);

    /**
     * GSAP scroll-driven scale animation.
     * Scale from 2.2 (hero) to 2.8 (MobileSection) as user scrolls.
     * Also handles the first texture swap (hero screen -> content_1).
     */
    useGSAP(() => {
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: '#mobile-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            }
        });

        tl.to(baseScale.current, { x: 2.8, y: 2.8, z: 2.8, ease: "none" }, 0);

        // First texture swap: hero screen -> content_1 during transition
        ScrollTrigger.create({
            trigger: '#mobile-section',
            start: 'top 60%',
            end: 'top 20%',
            scrub: true,
            onUpdate: (self) => {
                if (!shaderMatRef.current) return;
                shaderMatRef.current.uniforms.texCurrent.value = textures[0];
                shaderMatRef.current.uniforms.texNext.value = textures[1];
                shaderMatRef.current.uniforms.progress.value = self.progress;
            },
            onLeave: () => {
                if (!shaderMatRef.current) return;
                shaderMatRef.current.uniforms.texCurrent.value = textures[1];
                shaderMatRef.current.uniforms.progress.value = 0;
            },
        });
    }, { dependencies: [] });

    const smoothMouse = useRef({ x: 0, y: 0 });

    /** Per-frame updates: apply position, rotation, scale, and texture transitions. */
    useFrame((state) => {
        if (groupRef.current) {
            smoothMouse.current.x = THREE.MathUtils.lerp(smoothMouse.current.x, mouseRef.current.x, 0.05);
            smoothMouse.current.y = THREE.MathUtils.lerp(smoothMouse.current.y, mouseRef.current.y, 0.05);

            const floatY = Math.sin(state.clock.elapsedTime) * 0.08;
            const targetX = smoothMouse.current.x * 0.1;
            const targetY = smoothMouse.current.y * 0.1;

            groupRef.current.rotation.x = baseRotation.current.x - targetY * 0.4;
            groupRef.current.rotation.y = baseRotation.current.y + targetX * 0.4;
            groupRef.current.rotation.z = baseRotation.current.z;

            groupRef.current.position.x = basePosition.current.x + (targetX * 0.5);
            groupRef.current.position.y = basePosition.current.y + floatY;
            groupRef.current.position.z = basePosition.current.z;

            groupRef.current.scale.copy(baseScale.current);
        }

        // Drive texture transitions within MobileSection via CSS variable
        if (shaderMatRef.current && textures.length === TEXTURE_PATHS.length) {
            const rawProgress = parseFloat(
                getComputedStyle(document.documentElement)
                    .getPropertyValue('--mobile-scroll-progress') || '0'
            );

            const slideDuration = 1 / SLIDE_COUNT;

            for (let i = 0; i < SLIDE_COUNT - 1; i++) {
                const transStart = (i + 1) * slideDuration - slideDuration * 0.3;
                const transEnd = (i + 1) * slideDuration + slideDuration * 0.1;

                if (rawProgress >= transStart && rawProgress <= transEnd) {
                    const transProgress = (rawProgress - transStart) / (transEnd - transStart);
                    const fromIdx = i + 1;
                    const toIdx = i + 2;

                    if (toIdx < textures.length) {
                        shaderMatRef.current.uniforms.texCurrent.value = textures[fromIdx];
                        shaderMatRef.current.uniforms.texNext.value = textures[toIdx];
                        shaderMatRef.current.uniforms.progress.value = Math.min(transProgress, 1);
                    }
                    break;
                }

                if (rawProgress > transEnd && i + 2 < textures.length) {
                    shaderMatRef.current.uniforms.texCurrent.value = textures[i + 2];
                    shaderMatRef.current.uniforms.progress.value = 0;
                }
            }

            const activeSlide = Math.min(Math.floor(rawProgress * SLIDE_COUNT), SLIDE_COUNT - 1);
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

/**
 * PhoneCanvas: The 3D phone wrapper with scroll-driven CSS positioning.
 *
 * Uses a single persistent Canvas (never unmounts) and controls the wrapper
 * div's CSS `position` to achieve the scroll phases:
 *
 * Phase 1 - HERO (initial):
 *   position: fixed, centered in the right half of viewport,
 *   vertically placed so the phone top is just below the "Waitlist Now" CTA.
 *
 * Phase 2 - SCROLLING TO MOBILE:
 *   Still position: fixed. Phone follows the user on scroll.
 *   3D scale increases via GSAP.
 *
 * Phase 3 - MOBILE SECTION REACHED:
 *   position: absolute, placed inside MobileSection's pinned area.
 *   Phone anchors in the right panel (50% width, full height).
 *   It stays there while slides scroll through.
 *
 * Phase 4 - PAST MOBILE SECTION:
 *   Still position: absolute in MobileSection. Scrolls away naturally
 *   with the section as the user moves past.
 *
 * The trick: We use ScrollTrigger to detect when MobileSection's top
 * hits viewport top. At that moment, we switch from fixed to absolute
 * and calculate the correct top offset so there's no visual jump.
 */
export function PhoneCanvas() {
    const wrapperRef = useRef<HTMLDivElement>(null);

    useGSAP(() => {
        const wrapper = wrapperRef.current;
        if (!wrapper) return;

        /**
         * Phase A: As user scrolls from hero toward MobileSection,
         * animate the phone upward from its starting position (top: 55%)
         * to vertically centered (top: 15%) so it settles into the
         * right panel naturally.
         */
        gsap.to(wrapper, {
            top: '15%',
            ease: 'none',
            scrollTrigger: {
                trigger: '#mobile-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        });

        /**
         * Phase B: When MobileSection pin ENDS (user scrolls past all slides),
         * switch from fixed -> absolute so the phone stays at the bottom of
         * MobileSection and scrolls away with it.
         * The pin end = sectionTop + (SLIDE_COUNT * 100vh).
         */
        ScrollTrigger.create({
            trigger: '#mobile-section',
            // The pin lasts for SLIDE_COUNT * 100vh of scroll distance.
            // We switch to absolute at the very end of that pin.
            start: () => `top+=${window.innerHeight * SLIDE_COUNT} top`,
            end: () => `top+=${window.innerHeight * SLIDE_COUNT} top`,
            onEnter: () => {
                const mobileSection = document.getElementById('mobile-section');
                if (!mobileSection) return;
                // Place absolutely at the last screen's position within
                // MobileSection. The section height is (SLIDE_COUNT+1)*100vh.
                // The pinned area ends SLIDE_COUNT*100vh scrolled, placing
                // the visible viewport at the last screen-height of the section.
                const sectionTop = mobileSection.offsetTop;
                const absTop = sectionTop + (window.innerHeight * SLIDE_COUNT) + (window.innerHeight * 0.15);
                gsap.set(wrapper, {
                    position: 'absolute',
                    top: absTop,
                    right: '2%',
                    bottom: 'auto',
                    transform: 'none',
                    width: '48%',
                    height: '70vh',
                });
            },
            onLeaveBack: () => {
                // Revert to fixed (phone stays in viewport during pinned slides)
                gsap.set(wrapper, {
                    position: 'fixed',
                    top: '15%',
                    right: '2%',
                    bottom: 'auto',
                    transform: 'none',
                    width: '45vw',
                    height: '70vh',
                });
            },
        });

    }, { dependencies: [] });

    return (
        <div
            ref={wrapperRef}
            id="phone-canvas-wrapper"
            className="pointer-events-none"
            style={{
                // Initial state: fixed in right half, top aligned just
                // below the hero CTA button (~60% from viewport top).
                // The phone peeks into view from below.
                position: 'fixed',
                top: '55%',
                right: '2%',
                width: '45vw',
                maxWidth: '700px',
                height: '70vh',
                zIndex: 40,
            }}
        >
            <div className="w-full h-full pointer-events-auto cursor-grab active:cursor-grabbing">
                <Canvas camera={{ position: [0, 0, 5], fov: 35 }}>
                    <ambientLight intensity={0.5} />
                    <directionalLight position={[10, 10, 5]} intensity={1} />
                    <PresentationControls
                        global
                        snap
                        rotation={[0, 0, 0]}
                        polar={[-0.1, 0.1]}
                        azimuth={[-0.4, 0.4]}
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

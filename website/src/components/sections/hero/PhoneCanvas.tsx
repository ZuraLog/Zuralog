"use client";

import { useRef, useEffect, Suspense, type RefObject } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Environment, useGLTF, useTexture } from '@react-three/drei';
import { ProgressBridge } from '@/components/ProgressBridge';
import * as THREE from 'three';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';
import { mobileScrollProgress } from '@/lib/mobile-scroll-bridge';

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
 * Animated 3D values that GSAP will scrub.
 * Kept outside the component so GSAP can tween them by reference
 * and useFrame can read them every tick.
 *
 * posX: horizontal 3D offset (0 = center, positive = right in NDC-ish units)
 * posY: vertical 3D offset (negative = lower on screen)
 * scale: uniform scale multiplier
 */
const anim = {
    posX: 0.31,
    posY: -3.6,
    scale: 2.5,
};

/**
 * Inner 3D phone model with shader-based screen texture transitions
 * and scroll-driven 3D position/scale animation.
 *
 * The Canvas is full-viewport. This component positions the phone
 * within 3D space:
 *   - Hero: centered (posX=0), low (posY=-1.2) — sits below CTA
 *   - Transition: moves right (posX increases), up (posY increases), scales up
 *   - MobileSection: settled in right half (posX~1.8, posY~0), scale 2.8
 */
function PhoneModel({ wrapperRef }: { wrapperRef: RefObject<HTMLDivElement | null> }) {
    const { scene } = useGLTF('/model/phone/scene.gltf');
    const textures = useTexture(TEXTURE_PATHS);

    useEffect(() => {
        textures.forEach((tex) => {
            tex.flipY = false;
        });
    }, [textures]);

    /**
     * Opacity entrance fade: once the scene and all textures are ready,
     * fade the canvas wrapper from opacity 0 → 1.
     *
     * This is purely a CSS opacity tween on the wrapper div — it never
     * touches the 3D anim object, so it works correctly regardless of
     * what scroll position the page was loaded at.
     */
    useEffect(() => {
        if (!scene || textures.length === 0) return;
        const wrapper = wrapperRef.current;
        if (!wrapper) return;

        gsap.to(wrapper, {
            opacity: 1,
            duration: 2.4,
            delay: 0.2,
            ease: 'power1.inOut',
        });
    }, [scene, textures, wrapperRef]);

    const groupRef = useRef<THREE.Group>(null);
    const shaderMatRef = useRef<THREE.ShaderMaterial | null>(null);

    /** Base rotation for the phone (facing camera). */
    const baseRotation = useRef(new THREE.Vector3(0, Math.PI / 2, 0));

    /**
     * Cache the slide dot NodeList once after mount so we never call
     * document.querySelectorAll inside useFrame (which runs at ~60 fps).
     * We also track the last active slide to avoid redundant style writes.
     */
    const slideDotsCacheRef = useRef<NodeListOf<Element> | null>(null);
    const lastActiveSlideRef = useRef<number>(-1);

    useEffect(() => {
        // Cache dots after the section mounts. MobileSection renders them
        // as static markup, so the list won't change after first paint.
        slideDotsCacheRef.current = document.querySelectorAll('.slide-dot');
        return () => {
            slideDotsCacheRef.current = null;
        };
    }, []);

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
     * GSAP scroll-driven animations for the 3D model properties.
     *
     * Phase A (hero -> MobileSection approach):
     *   - posX: 0 -> 1.8 (center to right half)
     *   - posY: -1.2 -> 0 (below CTA to vertically centered)
     *   - scale: 2.2 -> 2.8
     *
     * Phase B (first texture swap: hero screen -> content_1):
     */
    useGSAP(() => {
        // Phase A: 3D position + scale transition as MobileSection approaches
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: '#mobile-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            }
        });

        tl.to(anim, {
            posX: 2,
            posY: 0,
            scale: 2,
            ease: "none",
        }, 0);

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

    /**
     * Per-frame updates: apply position, rotation, scale, and texture transitions.
     *
     * Performance notes:
     * - `mobileScrollProgress.value` is a plain JS object read — zero DOM/style cost.
     *   Previously this used getComputedStyle() which forces style recalculation
     *   on every frame and was the primary cause of scroll jank.
     * - Slide dot style updates are guarded by a lastActiveSlide check so DOM
     *   writes only happen when the active slide actually changes (~4 times total
     *   per scroll session) rather than on every frame.
     */
    useFrame((state) => {
        if (groupRef.current) {
            smoothMouse.current.x = THREE.MathUtils.lerp(smoothMouse.current.x, mouseRef.current.x, 0.05);
            smoothMouse.current.y = THREE.MathUtils.lerp(smoothMouse.current.y, mouseRef.current.y, 0.05);

            const floatY = Math.sin(state.clock.elapsedTime) * 0.06;
            const targetX = smoothMouse.current.x * 0.08;
            const targetY = smoothMouse.current.y * 0.08;

            groupRef.current.rotation.x = baseRotation.current.x - targetY * 0.3;
            groupRef.current.rotation.y = baseRotation.current.y + targetX * 0.3;
            groupRef.current.rotation.z = baseRotation.current.z;

            // Apply GSAP-driven position from the anim object
            groupRef.current.position.x = anim.posX + (targetX * 0.4);
            groupRef.current.position.y = anim.posY + floatY;
            groupRef.current.position.z = 0;

            // Apply GSAP-driven scale
            groupRef.current.scale.setScalar(anim.scale);
        }

        // Drive texture transitions within MobileSection via shared bridge ref.
        // This avoids the per-frame getComputedStyle() call that forced style
        // recalculation and caused measurable jank during pinned scroll.
        if (shaderMatRef.current && textures.length === TEXTURE_PATHS.length) {
            const rawProgress = mobileScrollProgress.value;

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

            // Only write to the DOM when the active slide index actually changes.
            // Previously this ran on every frame regardless of whether anything changed.
            const activeSlide = Math.min(Math.floor(rawProgress * SLIDE_COUNT), SLIDE_COUNT - 1);
            if (activeSlide !== lastActiveSlideRef.current) {
                lastActiveSlideRef.current = activeSlide;
                const dots = slideDotsCacheRef.current;
                if (dots) {
                    dots.forEach((dot, i) => {
                        const el = dot as HTMLElement;
                        if (i === activeSlide) {
                            el.style.backgroundColor = 'rgba(0,0,0,0.7)';
                            el.style.transform = 'scale(1.5)';
                        } else {
                            el.style.backgroundColor = 'rgba(0,0,0,0.2)';
                            el.style.transform = 'scale(1)';
                        }
                    });
                }
            }
        }
    });

    return (
        <group ref={groupRef}>
            <primitive object={scene} />
        </group>
    );
}

/**
 * PhoneCanvas: Full-viewport 3D overlay with scroll-driven transitions.
 *
 * The Canvas covers the entire viewport (100vw x 100vh) so the phone
 * model is NEVER clipped. The phone's position within 3D space is what
 * moves it from center (hero) to right-half (MobileSection).
 *
 * Phases:
 *   1. HERO: Canvas is position:fixed, full viewport. Phone is centered
 *      and low (below CTA button) via 3D posY offset.
 *   2. SCROLLING TO MOBILE: Still fixed. GSAP scrubs 3D posX (center->right),
 *      posY (low->center), and scale (2.2->2.8).
 *   3. MOBILE SECTION PINNED: Still fixed full viewport. Phone is in right
 *      half at full scale. Slide textures swap via shared bridge ref.
 *   4. PAST MOBILE SECTION: Canvas switches to position:absolute, anchored
 *      at the bottom of MobileSection. It scrolls away naturally.
 */
export function PhoneCanvas() {
    const wrapperRef = useRef<HTMLDivElement>(null);

    useGSAP(() => {
        const wrapper = wrapperRef.current;
        if (!wrapper) return;

        /**
         * When MobileSection pin ENDS (user scrolled past all slides),
         * switch from fixed -> absolute so the Canvas stays anchored
         * at the end of MobileSection and scrolls away with it.
         *
         * The pin duration is SLIDE_COUNT * 100vh of scroll distance.
         */
        ScrollTrigger.create({
            trigger: '#mobile-section',
            start: () => `top+=${window.innerHeight * SLIDE_COUNT} top`,
            end: () => `top+=${window.innerHeight * SLIDE_COUNT} top`,
            onEnter: () => {
                const mobileSection = document.getElementById('mobile-section');
                if (!mobileSection) return;

                // Anchor the full-viewport canvas at the scroll position
                // where the pin ended. This is sectionTop + pinDuration.
                const sectionTop = mobileSection.offsetTop;
                const absTop = sectionTop + (window.innerHeight * SLIDE_COUNT);

                gsap.set(wrapper, {
                    position: 'absolute',
                    top: absTop,
                    left: 0,
                    right: 0,
                    width: '100%',
                    height: '100vh',
                });
            },
            onLeaveBack: () => {
                // Revert to fixed full-viewport overlay
                gsap.set(wrapper, {
                    position: 'fixed',
                    top: 0,
                    left: 0,
                    right: 0,
                    width: '100%',
                    height: '100vh',
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
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                width: '100%',
                height: '100vh',
                zIndex: 40,
                pointerEvents: 'none',
                opacity: 0,
            }}
        >
            {/* pointerEvents: 'none' is set inline on both the wrapper and the Canvas
                because R3F injects the <canvas> with its own event handling and does
                not reliably inherit pointer-events from a CSS class on a parent div. */}
            <div className="w-full h-full pointer-events-none" style={{ pointerEvents: 'none' }}>
                <Canvas camera={{ position: [0, 0, 5], fov: 45 }} style={{ pointerEvents: 'none' }}>
                    <ambientLight intensity={0.5} />
                    <directionalLight position={[10, 10, 5]} intensity={1} />
                    {/* Bridge: reads useProgress inside Canvas, writes to loadingBridge singleton */}
                    <ProgressBridge />
                    {/* Suspense boundary so useProgress tracks GLTF + texture loads */}
                    <Suspense fallback={null}>
                        <PhoneModel wrapperRef={wrapperRef} />
                        <Environment preset="city" />
                    </Suspense>
                </Canvas>
            </div>
        </div>
    );
}

// NOTE: preload calls removed intentionally.
// Preloading fires before LoadingScreen mounts, which means useProgress
// never sees the load happen and the bar stays at 0. Assets are loaded
// inside the <Suspense> boundary in PhoneCanvas so useProgress tracks them.

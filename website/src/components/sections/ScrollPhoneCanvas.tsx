"use client";

import { useRef, useEffect, Suspense, type RefObject } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Environment, useGLTF, useTexture } from '@react-three/drei';
import * as THREE from 'three';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// Module-level anim object — GSAP mutates these, useFrame reads them.
const anim = {
    posX: 0,
    posY: -3.5,
    scale: 0.8,
    rotX: 0,
    rotY: 0,
    rotZ: 0,
    texSlide: 0,
};

// Suppresses the idle float bob while the coach mouse is actively tracking,
// so the phone stays pixel-aligned to the cursor.
let coachTracking = false;

// Set to true once the user reaches TrendsSection.
// Blocks the coach-idle handler from snapping posX back to 0 after the phone
// has been handed off to TrendsSection's fixed right-column position.
let trendsActive = false;

// Camera constants — must match the <Canvas camera> props below.
const CAM_Z = 5;
const CAM_FOV = 45; // degrees

const _q1 = new THREE.Quaternion();
const _q2 = new THREE.Quaternion();
const _q3 = new THREE.Quaternion();
const _AX = new THREE.Vector3(1, 0, 0);
const _AY = new THREE.Vector3(0, 1, 0);
const _AZ = new THREE.Vector3(0, 0, 1);

/**
 * Slide transition shader.
 * iphone16.gltf screen mesh UVs are a clean [0,1]×[0,1] — no normalisation needed.
 */
const SlideTransitionShader = {
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

        vec4 gaussianBlur(sampler2D tex, vec2 uv, float r) {
            // 3x3 Gaussian kernel: weights sum to 1.0
            // [ 0.0625  0.125  0.0625 ]
            // [ 0.125   0.25   0.125  ]
            // [ 0.0625  0.125  0.0625 ]
            vec2 o = vec2(r);
            return
                texture2D(tex, clamp(uv + vec2(-o.x, -o.y), 0.0, 1.0)) * 0.0625 +
                texture2D(tex, clamp(uv + vec2( 0.0, -o.y), 0.0, 1.0)) * 0.125  +
                texture2D(tex, clamp(uv + vec2( o.x, -o.y), 0.0, 1.0)) * 0.0625 +
                texture2D(tex, clamp(uv + vec2(-o.x,  0.0), 0.0, 1.0)) * 0.125  +
                texture2D(tex, uv)                                       * 0.25   +
                texture2D(tex, clamp(uv + vec2( o.x,  0.0), 0.0, 1.0)) * 0.125  +
                texture2D(tex, clamp(uv + vec2(-o.x,  o.y), 0.0, 1.0)) * 0.0625 +
                texture2D(tex, clamp(uv + vec2( 0.0,  o.y), 0.0, 1.0)) * 0.125  +
                texture2D(tex, clamp(uv + vec2( o.x,  o.y), 0.0, 1.0)) * 0.0625;
        }

        void main() {
            float p = clamp(progress, 0.0, 1.0);

            // Blur radius peaks at mid-transition (p = 0.5), zero at both ends.
            float r = sin(p * 3.14159265) * 0.018;

            vec4 colCur = gaussianBlur(texCurrent, vUv, r);
            vec4 colNxt = gaussianBlur(texNext,    vUv, r);

            // Smooth cross-fade
            gl_FragColor = mix(colCur, colNxt, smoothstep(0.0, 1.0, p));
        }
    `,
};

// ─── Fine-tune these to adjust the phone's appearance ────────────────────────
// posX / posY / scale live in the `anim` object above (search "Module-level anim").
// Colors use standard CSS hex strings.
const COLOR_BORDER = '#2E5C47'; // metal frame — mid forest green (brighter than body)
const COLOR_BODY = '#1B3328'; // back panel  — same dark forest green
const COLOR_DARK = '#0A0A0A'; // screen border, dynamic island
// ─────────────────────────────────────────────────────────────────────────────

// Shared materials (created once, reused across the scene).
const matBorder = () => new THREE.MeshStandardMaterial({ color: COLOR_BORDER, roughness: 0.3, metalness: 0.6 });
const matBody = () => new THREE.MeshStandardMaterial({ color: COLOR_BODY, roughness: 0.45, metalness: 0.2 });
const matDark = () => new THREE.MeshStandardMaterial({ color: COLOR_DARK, roughness: 0.5, metalness: 0.1 });
const matGlass = () => new THREE.MeshStandardMaterial({ color: '#ffffff', transparent: true, opacity: 0.06, roughness: 0, metalness: 0 });
const matCameraLens = () => new THREE.MeshStandardMaterial({ color: '#111111', roughness: 0.1, metalness: 0.9 });

function applyMaterials(scene: THREE.Group, shaderMat: THREE.ShaderMaterial) {
    // NOTE: Three.js sanitizeNodeName() replaces spaces → underscores.
    // "Screen Border" → "Screen_Border", "Back Side" → "Back_Side", etc.

    // Cache materials — allocate once, reuse across all meshes.
    const border = matBorder();
    const body = matBody();
    const dark = matDark();
    const glass = matGlass();
    const lens = matCameraLens();

    scene.traverse((child) => {
        if (!(child instanceof THREE.Mesh)) return;
        const name = child.name;

        if (name === 'Screen') {
            child.material = shaderMat;
            child.renderOrder = 1;
        } else if (name === 'Screen_Border') {
            child.material = dark;
        } else if (name === 'Metal_Border') {
            child.material = border;
        } else if (name === 'Back_Side') {
            child.material = body;
        } else if (name === 'Button') {
            child.material = border;
        } else if (
            // Dynamic Island: the group itself has no mesh; its children do.
            child.parent?.name === 'Dynamic_Island' ||
            child.parent?.parent?.name === 'Dynamic_Island'
        ) {
            child.material = dark;
        } else if (
            // Camera lens rings — live under Cam1/Cam2 parent nodes.
            child.parent?.name?.startsWith('Cam') ||
            child.parent?.parent?.name?.startsWith('Cam')
        ) {
            child.material = lens;
        } else if (name === 'Light') {
            child.material = glass;
        } else {
            // Connectors, speaker grilles, buttons, decorative ellipses — all metal.
            child.material = border;
        }
    });
}

function PhoneModel({ wrapperRef }: { wrapperRef: RefObject<HTMLDivElement | null> }) {
    const { scene } = useGLTF('/model/iphone16.gltf');

    const textures = useTexture(
        [
            '/model/phone/textures/brand-forest-green.jpg',  // 0  — hero
            '/model/phone/textures/unified.jpeg',             // 1  — integrations
            '/model/phone/textures/today-morning.jpg',        // 2  — today beat 1
            '/model/phone/textures/quick-log-poster.jpg',     // 3  — today beat 2 (quick log)
            '/model/phone/textures/ai-insight-poster.jpg',    // 4  — today beat 3 (ai insights)
            '/model/phone/textures/data-poster.jpg',          // 5  — data section
            '/model/phone/textures/brand-forest-green.jpg',   // 6  — coach section
            '/model/phone/textures/streak.jpg',               // 7  — progress: streak
            '/model/phone/textures/goals.jpg',                // 8  — progress: goals
            '/model/phone/textures/journal.jpg',              // 9  — progress: journal
            '/model/phone/textures/awards.jpg',               // 10 — progress: achievements
            '/model/phone/textures/trends.jpg',               // 11 — trends section
        ],
        (loaded) => {
            const arr = Array.isArray(loaded) ? loaded : [loaded];
            arr.forEach((t) => {
                t.flipY = true;
                t.wrapS = THREE.ClampToEdgeWrapping;
                t.wrapT = THREE.ClampToEdgeWrapping;
            });
        },
    );

    // Fade the canvas in once assets are ready.
    // gsap.set() claims ownership of opacity before gsap.to() runs,
    // so React re-renders cannot reset it back to the CSS initial value.
    useEffect(() => {
        if (!scene) return;
        const wrapper = wrapperRef.current;
        if (!wrapper) return;
        gsap.set(wrapper, { opacity: 0 });
        gsap.to(wrapper, { opacity: 1, duration: 2.4, delay: 0.2, ease: 'power1.inOut' });
    }, [scene, wrapperRef]);

    const groupRef = useRef<THREE.Group>(null);
    const shaderMatRef = useRef<THREE.ShaderMaterial | null>(null);

    useEffect(() => {
        if (!scene || textures.length < 2) return;

        const shaderMat = new THREE.ShaderMaterial({
            uniforms: {
                texCurrent: { value: textures[0] },
                texNext: { value: textures[1] },
                progress: { value: 0.0 },
            },
            vertexShader: SlideTransitionShader.vertexShader,
            fragmentShader: SlideTransitionShader.fragmentShader,
            side: THREE.FrontSide,
            toneMapped: false,
        });
        shaderMatRef.current = shaderMat;

        applyMaterials(scene as unknown as THREE.Group, shaderMat);
    }, [scene, textures]);

    // Mouse parallax.
    const mouseRef = useRef({ x: 0, y: 0 });
    useEffect(() => {
        const onMove = (e: MouseEvent) => {
            mouseRef.current.x = (e.clientX / window.innerWidth) * 2 - 1;
            mouseRef.current.y = -(e.clientY / window.innerHeight) * 2 + 1;
        };
        window.addEventListener('mousemove', onMove);
        return () => window.removeEventListener('mousemove', onMove);
    }, []);

    // Scroll-driven animations.
    useGSAP(() => {
        // Hero → IntegrationsSection: phone rotates to landscape.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#next-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: 0.1,
            posY: 0.1,
            scale: 0.8,
            rotX: 0,
            rotY: 0,
            rotZ: Math.PI / 2,
            texSlide: 1,
            ease: 'none',
        });

        // IntegrationsSection → TodaySection Beat 1: phone returns to portrait, docks right 30%.
        // Camera fov=45 at z=5 → viewport half-width ≈ 2.071 units.
        // Right 30% centre ≈ x = 1.45 world units.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#today-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: 2.5,
            posY: 0,
            scale: 0.6,
            rotX: 0,
            rotY: -0.3,
            rotZ: 0,
            texSlide: 2,
            ease: 'none',
        });

        // TodaySection Beat 1 → Beat 2 (Quick Log): texture swaps to quick-log-poster.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#beat2',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            texSlide: 3,
            ease: 'none',
        });

        // TodaySection Beat 2 → Beat 3 (AI Insights): phone returns to center, texture swaps.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#beat3',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: 0,
            posY: -0.1,
            scale: 0.65,
            rotX: 0,
            rotY: 0,
            rotZ: 0,
            texSlide: 4,
            ease: 'none',
        });

        // DataSection: phone slides to the left 20% column, texture swaps to data-poster.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#data-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: -2.6,
            posY: 0,
            scale: 0.65,
            rotX: 0,
            rotY: 0.25,
            rotZ: 0,
            texSlide: 5,
            ease: 'none',
        });

        // CoachSection: phone transitions to center, texture swaps to brand-forest-green.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#coach-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: 0,
            posY: 0,
            scale: 0.35,
            rotX: 0,
            rotY: 0,
            rotZ: 0,
            texSlide: 6,
            ease: 'none',
        });

        // ProgressSection enter: rotate phone to landscape, texture arrives at streak.
        // refreshPriority: -1 — same reason as ProgressSection's own trigger.
        // CoachSection's async pin spacer must be in place before this trigger
        // calculates where #progress-section actually sits on the page.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#progress-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
                refreshPriority: -1,
            },
        }).to(anim, {
            posX: 0,
            posY: 0,
            scale: 0.85,
            rotX: 0,
            rotY: 0,
            rotZ: Math.PI / 2,
            texSlide: 7,
            ease: 'none',
        });

        // ProgressSection internal: cycle through streak → goals → journal → achievements
        // as the section's 4800px pin scrolls through each color panel.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#progress-section',
                start: 'top top',
                end: '+=4800',
                scrub: true,
                refreshPriority: -1,
            },
        }).to(anim, {
            texSlide: 10,
            ease: 'none',
        });

        // TrendsSection: phone moves to right 25%, returns to portrait, texture swaps to trends.
        // posX: 1.7 — camera z=5, fov=45 → half-width ≈ 2.07 world units,
        // so 1.7 sits the phone centred in the right 50% column.
        // refreshPriority: -3 — must fire AFTER TrendsSection's own pin spacer
        // (refreshPriority -2) is settled, so this trigger reads the correct
        // scroll position for #trends-section.
        // onEnter/onLeaveBack — set trendsActive so the coach-idle handler
        // cannot snap posX back to 0 while the phone belongs to TrendsSection.
        gsap.timeline({
            scrollTrigger: {
                trigger: '#trends-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
                refreshPriority: -3,
                onEnter: () => { trendsActive = true; },
                onLeaveBack: () => { trendsActive = false; },
            },
        }).to(anim, {
            posX: 0.8,
            posY: 0,
            scale: 0.7,
            rotX: 0,
            rotY: -0.1,
            rotZ: 0,
            texSlide: 11,
            ease: 'none',
        });

        // WaitlistSection: phone slides off the top as the section enters.
        // Camera half-height ≈ 2.07 world units — posY 6 clears the phone fully.
        // scrub reverses naturally when the user scrolls back up into TrendsSection.
        // refreshPriority: -4 — after all pin spacers (CoachSection 0,
        // ProgressSection -1, TrendsSection -2, TrendsSection phone trigger -3).
        gsap.timeline({
            scrollTrigger: {
                trigger: '#waitlist',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
                refreshPriority: -4,
            },
        }).to(anim, {
            posY: 6,
            ease: 'none',
        });

        // -- Coach section mouse tracking --
        let coachIdleTimer: ReturnType<typeof setTimeout> | null = null;

        const handleCoachMouse = (e: Event) => {
            const { clientX, clientY } = (e as CustomEvent<{ clientX: number; clientY: number }>).detail;

            // Derive exact world-space extents from camera FOV and distance.
            // Camera: position z=CAM_Z, fov=CAM_FOV degrees.
            // half-height (world) = tan(fov/2) * CAM_Z
            // half-width  (world) = halfH * aspect
            const halfH = Math.tan((CAM_FOV / 2) * (Math.PI / 180)) * CAM_Z;
            const halfW = halfH * (window.innerWidth / window.innerHeight);

            const normalX = (clientX / window.innerWidth - 0.5) * 2; // -1 … +1
            const normalY = -(clientY / window.innerHeight - 0.5) * 2; // flipped Y

            coachTracking = true;
            gsap.to(anim, {
                posX: normalX * halfW,
                posY: normalY * halfH,
                rotY: -normalX * 0.6,  // tilt inward: left cursor → face right, right cursor → face left
                duration: 0.45,
                ease: 'power2.out',
                overwrite: 'auto',
            });
            if (coachIdleTimer) clearTimeout(coachIdleTimer);
        };

        const handleCoachIdle = () => {
            coachTracking = false;

            // TrendsSection (or later) owns the phone — do not reset posX to 0.
            if (trendsActive) return;

            // Idle position: dead center (posX:0, posY:0 = camera look-at origin).
            gsap.to(anim, {
                posX: 0,
                posY: 0,
                rotY: 0,
                duration: 1.4,
                ease: 'power3.inOut',
            });
        };

        window.addEventListener('zuralog:coach:mouse', handleCoachMouse);
        window.addEventListener('zuralog:coach:idle', handleCoachIdle);

        return () => {
            window.removeEventListener('zuralog:coach:mouse', handleCoachMouse);
            window.removeEventListener('zuralog:coach:idle', handleCoachIdle);
            if (coachIdleTimer) clearTimeout(coachIdleTimer);
        };
    }, { dependencies: [] });

    const smoothMouse = useRef({ x: 0, y: 0 });

    useFrame((state) => {
        if (!groupRef.current) return;

        smoothMouse.current.x = THREE.MathUtils.lerp(smoothMouse.current.x, mouseRef.current.x, 0.05);
        smoothMouse.current.y = THREE.MathUtils.lerp(smoothMouse.current.y, mouseRef.current.y, 0.05);

        const tx = smoothMouse.current.x * 0.08;
        const ty = smoothMouse.current.y * 0.08;

        // Suppress float and parallax nudge while coach mouse is tracking —
        // they offset the phone away from the cursor position.
        const floatY = coachTracking ? 0 : Math.sin(state.clock.elapsedTime) * 0.06;
        const nudgeX = coachTracking ? 0 : tx * 0.4;

        _q1.setFromAxisAngle(_AY, anim.rotY - tx * 0.3);
        _q2.setFromAxisAngle(_AX, anim.rotX + ty * 0.3);
        _q3.setFromAxisAngle(_AZ, anim.rotZ);
        groupRef.current.quaternion.copy(_q3).multiply(_q2).multiply(_q1);

        groupRef.current.position.x = anim.posX + nudgeX;
        groupRef.current.position.y = anim.posY + floatY;
        groupRef.current.position.z = 0;

        groupRef.current.scale.setScalar(anim.scale);

        if (shaderMatRef.current) {
            const fromIdx = Math.min(Math.floor(anim.texSlide), textures.length - 1);
            const toIdx = Math.min(Math.floor(anim.texSlide) + 1, textures.length - 1);
            shaderMatRef.current.uniforms.texCurrent.value = textures[fromIdx];
            shaderMatRef.current.uniforms.texNext.value = textures[toIdx];
            shaderMatRef.current.uniforms.progress.value = anim.texSlide - Math.floor(anim.texSlide);
        }
    });

    return (
        <group ref={groupRef}>
            <primitive object={scene} />
        </group>
    );
}

export function ScrollPhoneCanvas() {
    const wrapperRef = useRef<HTMLDivElement>(null);

    return (
        <div
            ref={wrapperRef}
            aria-hidden="true"
            className="pointer-events-none opacity-0"
            style={{
                position: 'fixed',
                top: 0,
                left: 0,
                width: '100%',
                height: '100vh',
                zIndex: 40,
            }}
        >
            <Canvas
                camera={{ position: [0, 0, 5], fov: 45 }}
                style={{ pointerEvents: 'none' }}
            >
                <ambientLight intensity={0.6} />
                <directionalLight position={[5, 10, 5]} intensity={1.2} />
                <directionalLight position={[-5, -5, 5]} intensity={0.3} />
                <Suspense fallback={null}>
                    <PhoneModel wrapperRef={wrapperRef} />
                    <Environment preset="city" />
                </Suspense>
            </Canvas>
        </div>
    );
}

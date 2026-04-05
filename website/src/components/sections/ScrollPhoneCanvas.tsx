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
    texProgress: 0,
};

// Suppresses the idle float bob while the coach mouse is actively tracking,
// so the phone stays pixel-aligned to the cursor.
let coachTracking = false;

// Camera constants — must match the <Canvas camera> props below.
const CAM_Z   = 5;
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

        void main() {
            float p = clamp(progress, 0.0, 1.0);

            // Slide wipe: current exits left, next enters from right.
            // Wipe line at vUv.x = (1.0 - p), sweeping leftward as p → 1.
            vec2 uvCur = vec2(vUv.x + p,       vUv.y);
            vec2 uvNxt = vec2(vUv.x + p - 1.0, vUv.y);

            vec4 colCur = texture2D(texCurrent, uvCur);
            vec4 colNxt = texture2D(texNext,    uvNxt);

            gl_FragColor = vUv.x > (1.0 - p) ? colNxt : colCur;
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
            '/model/phone/textures/brand-forest-green.jpg',  // hero section screen
            '/model/phone/textures/unified.jpeg',             // next section screen
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
    useEffect(() => {
        if (!scene) return;
        const wrapper = wrapperRef.current;
        if (!wrapper) return;
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
            texProgress: 1,
            ease: 'none',
        });

        // IntegrationsSection → TodaySection: phone returns to portrait, docks right 30%.
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
            posX: 3,
            posY: 0,
            scale: 0.6,
            rotX: 0,
            rotY: 0,
            rotZ: 0,
            ease: 'none',
        });

        // TodaySection (Beat 3): phone returns exactly to the center of the viewport
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
            ease: 'none',
        });

        // DataSection: phone slides to the left 20% column
        gsap.timeline({
            scrollTrigger: {
                trigger: '#data-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: -2.8,
            posY: 0,
            scale: 0.55,
            rotX: 0,
            rotY: 8,
            rotZ: 0,
            ease: 'none',
        });

        // CoachSection: phone transitions to center, scaled to fit inside the text-warp rectangle
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
            ease: 'none',
        });

        // ProgressSection: rotate phone to landscape, center it.
        // Fires as the section scrolls into view (top bottom → top top).
        gsap.timeline({
            scrollTrigger: {
                trigger: '#progress-section',
                start: 'top bottom',
                end: 'top top',
                scrub: true,
            },
        }).to(anim, {
            posX: 0,
            posY: 0,
            scale: 0.85,
            rotX: 0,
            rotY: 0,
            rotZ: Math.PI / 2,
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

            const normalX =  (clientX / window.innerWidth  - 0.5) * 2; // -1 … +1
            const normalY = -(clientY / window.innerHeight - 0.5) * 2; // flipped Y

            coachTracking = true;
            gsap.to(anim, {
                posX: normalX * halfW,
                posY: normalY * halfH,
                duration: 0.45,
                ease: 'power2.out',
                overwrite: 'auto',
            });
            if (coachIdleTimer) clearTimeout(coachIdleTimer);
        };

        const handleCoachIdle = () => {
            coachTracking = false;

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
        window.addEventListener('zuralog:coach:idle',  handleCoachIdle);

        return () => {
            window.removeEventListener('zuralog:coach:mouse', handleCoachMouse);
            window.removeEventListener('zuralog:coach:idle',  handleCoachIdle);
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

        _q1.setFromAxisAngle(_AY, anim.rotY + tx * 0.3);
        _q2.setFromAxisAngle(_AX, anim.rotX - ty * 0.3);
        _q3.setFromAxisAngle(_AZ, anim.rotZ);
        groupRef.current.quaternion.copy(_q3).multiply(_q2).multiply(_q1);

        groupRef.current.position.x = anim.posX + nudgeX;
        groupRef.current.position.y = anim.posY + floatY;
        groupRef.current.position.z = 0;

        groupRef.current.scale.setScalar(anim.scale);

        if (shaderMatRef.current) {
            shaderMatRef.current.uniforms.progress.value = anim.texProgress;
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
            className="pointer-events-none"
            style={{
                position: 'fixed',
                top: 0,
                left: 0,
                width: '100%',
                height: '100vh',
                zIndex: 40,
                opacity: 0,
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

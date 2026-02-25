"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { FaHeartbeat, FaRunning, FaDumbbell, FaApple, FaStrava, FaGoogle } from 'react-icons/fa';

// Add new apps here to dynamically render them
const APPS = [
    { id: 'fit', Icon: FaGoogle, color: '#EA4335', x: 32, y: 32 },
    { id: 'apple', Icon: FaApple, color: '#000000', x: 26, y: 50 },
    { id: 'strava', Icon: FaStrava, color: '#FC4C02', x: 32, y: 68 },
    { id: 'heart', Icon: FaHeartbeat, color: '#E91E63', x: 68, y: 32 },
    { id: 'run', Icon: FaRunning, color: '#FF9800', x: 74, y: 50 },
    { id: 'gym', Icon: FaDumbbell, color: '#9E9E9E', x: 68, y: 68 },
];

export function FloatingIcons() {
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        let handleMouseMove: (e: MouseEvent) => void;

        const ctx = gsap.context(() => {
            // Setup initial appear animation
            gsap.fromTo('.app-icon-wrapper',
                { opacity: 0, scale: 0, rotation: () => Math.random() * 20 - 10 },
                { opacity: 1, scale: 1, duration: 0.8, stagger: 0.1, ease: 'back.out(1.5)', delay: 1 }
            );

            // Continuous floating animation
            gsap.utils.toArray('.app-icon-wrapper').forEach((el: unknown, i) => {
                const element = el as Element;
                gsap.to(element, {
                    y: '+=20',
                    x: '+=10',
                    rotation: '+=5',
                    duration: 3 + Math.random() * 2,
                    repeat: -1,
                    yoyo: true,
                    ease: 'sine.inOut',
                    delay: 2.5 + i * 0.2 // Wait for entrance animation to finish completely
                });
            });

            // Mouse parallax configuration
            handleMouseMove = (e: MouseEvent) => {
                const mx = (e.clientX / window.innerWidth - 0.5) * 2;
                const my = (e.clientY / window.innerHeight - 0.5) * 2;

                gsap.utils.toArray('.parallax-wrapper').forEach((el: unknown, i) => {
                    const element = el as Element;
                    const depth = (i % 3) + 1; // Variable depth for chaotic feel
                    gsap.to(element, {
                        x: mx * 30 * depth,
                        y: my * 30 * depth,
                        duration: 1,
                        ease: 'power2.out',
                        overwrite: 'auto'
                    });
                });
            };
            window.addEventListener('mousemove', handleMouseMove);
        }, containerRef);

        return () => {
            if (handleMouseMove) window.removeEventListener('mousemove', handleMouseMove);
            ctx.revert();
        };
    }, []);

    return (
        <div ref={containerRef} className="absolute inset-0 pointer-events-none overflow-hidden z-20">
            {APPS.map((app) => (
                <div key={app.id} className="parallax-wrapper absolute" style={{ left: `${app.x}%`, top: `${app.y}%` }}>
                    <div
                        className="app-icon-wrapper bg-white p-4 rounded-2xl shadow-xl flex items-center justify-center pointer-events-auto hover:scale-110 transition-transform cursor-pointer"
                    >
                        <app.Icon size={32} color={app.color} />
                    </div>
                </div>
            ))}
        </div>
    );
}

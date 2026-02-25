"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { FaHeartbeat, FaRunning, FaDumbbell, FaApple, FaStrava, FaGoogle } from 'react-icons/fa';

// Add new apps here to dynamically render them
const APPS = [
    { id: 'fit', Icon: FaGoogle, color: '#EA4335', x: 20, y: 30 },
    { id: 'apple', Icon: FaApple, color: '#000000', x: 5, y: 50 },
    { id: 'strava', Icon: FaStrava, color: '#FC4C02', x: 15, y: 70 },
    { id: 'heart', Icon: FaHeartbeat, color: '#E91E63', x: 80, y: 30 },
    { id: 'run', Icon: FaRunning, color: '#FF9800', x: 95, y: 50 },
    { id: 'gym', Icon: FaDumbbell, color: '#9E9E9E', x: 85, y: 70 },
];

export function FloatingIcons() {
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
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
                    delay: i * 0.2
                });
            });
        }, containerRef);

        return () => ctx.revert();
    }, []);

    return (
        <div ref={containerRef} className="absolute inset-0 pointer-events-none overflow-hidden z-0">
            {APPS.map((app) => (
                <div
                    key={app.id}
                    className="app-icon-wrapper absolute bg-white p-4 rounded-2xl shadow-xl flex items-center justify-center pointer-events-auto hover:scale-110 transition-transform cursor-pointer"
                    style={{
                        left: `${app.x}%`,
                        top: `${app.y}%`
                    }}
                >
                    <app.Icon size={32} color={app.color} />
                </div>
            ))}
        </div>
    );
}

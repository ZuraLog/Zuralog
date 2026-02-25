"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { FaApple, FaStrava, FaHeartbeat, FaRunning, FaDumbbell, FaWalking, FaSwimmer, FaBicycle } from 'react-icons/fa';
import { FcGoogle } from 'react-icons/fc';
import { MdWaterDrop, MdSelfImprovement, MdNightlight, MdMonitorHeart, MdSportsScore } from 'react-icons/md';
import { GiMeditation, GiFruitBowl, GiRunningShoe } from 'react-icons/gi';
import { IoIosFitness } from 'react-icons/io';
import { TbTreadmill } from 'react-icons/tb';

// Top 20 fitness and health apps organically spread
const APPS = [
    { id: 'google', Icon: FcGoogle, color: '', x: 25, y: 20 },
    { id: 'apple', Icon: FaApple, color: '#000000', x: 18, y: 40 },
    { id: 'strava', Icon: FaStrava, color: '#FC4C02', x: 28, y: 55 },
    { id: 'heart', Icon: FaHeartbeat, color: '#E91E63', x: 20, y: 75 },
    { id: 'run', Icon: FaRunning, color: '#FF9800', x: 35, y: 80 },
    { id: 'gym', Icon: FaDumbbell, color: '#9E9E9E', x: 12, y: 60 },
    { id: 'walk', Icon: FaWalking, color: '#4CAF50', x: 75, y: 25 },
    { id: 'swim', Icon: FaSwimmer, color: '#03A9F4', x: 82, y: 45 },
    { id: 'bike', Icon: FaBicycle, color: '#F44336', x: 72, y: 65 },
    { id: 'water', Icon: MdWaterDrop, color: '#2196F3', x: 40, y: 15 },
    { id: 'yoga', Icon: MdSelfImprovement, color: '#9C27B0', x: 60, y: 12 },
    { id: 'sleep', Icon: MdNightlight, color: '#3F51B5', x: 88, y: 28 },
    { id: 'pulse', Icon: MdMonitorHeart, color: '#E53935', x: 10, y: 30 },
    { id: 'meditation', Icon: GiMeditation, color: '#009688', x: 65, y: 85 },
    { id: 'diet', Icon: GiFruitBowl, color: '#8BC34A', x: 50, y: 90 },
    { id: 'shoes', Icon: GiRunningShoe, color: '#FF5722', x: 90, y: 60 },
    { id: 'fitness', Icon: IoIosFitness, color: '#FFC107', x: 15, y: 15 },
    { id: 'treadmill', Icon: TbTreadmill, color: '#795548', x: 5, y: 50 },
    { id: 'score', Icon: MdSportsScore, color: '#FFEB3B', x: 80, y: 80 },
    { id: 'weight', Icon: FaDumbbell, color: '#607D8B', x: 85, y: 15 },
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
                    const depth = 1.5; // Equal depth for all icons
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

/**
 * GSAP registration and plugin setup.
 *
 * Import from this module (not directly from 'gsap') to ensure
 * ScrollTrigger is always registered before use.
 *
 * Usage:
 *   import { gsap, ScrollTrigger, useGSAP } from '@/lib/gsap';
 */
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

// Register plugins once at module level
gsap.registerPlugin(ScrollTrigger, useGSAP);

export { gsap, ScrollTrigger, useGSAP };

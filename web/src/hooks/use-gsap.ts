/**
 * Re-export of the @gsap/react useGSAP hook with GSAP plugins pre-registered.
 *
 * Always import from this module — it guarantees ScrollTrigger is registered.
 *
 * @example
 * ```tsx
 * import { useGSAP } from '@/hooks/use-gsap';
 * import { gsap } from '@/lib/gsap';
 *
 * function MyComponent() {
 *   const containerRef = useRef<HTMLDivElement>(null);
 *   useGSAP(() => {
 *     gsap.from('.item', { opacity: 0, y: 20, stagger: 0.1 });
 *   }, { scope: containerRef });
 *   return <div ref={containerRef}><span className="item">Hi</span></div>;
 * }
 * ```
 */
export { useGSAP } from '@/lib/gsap';

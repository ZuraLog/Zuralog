"use client";
import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
}

// 3.5 timeline units × ~857 px per unit ≈ 3 000 px of pinned scroll.
// Last animation starts at 2.5, runs 0.4, plus 0.6 hold = 3.5 units total.
const TOTAL_SCROLL = 3000;

const CREAM = '#F0EEE9';

interface LineConfig {
    text: string;
    fontSize: string;
    fontWeight: number;
    isPatterned: boolean;
}

const LINES: LineConfig[] = [
    { text: 'your',           fontSize: 'clamp(28px, 3.8vw, 54px)',   fontWeight: 500, isPatterned: false },
    { text: 'habits',         fontSize: 'clamp(82px, 11.2vw, 160px)', fontWeight: 800, isPatterned: true  },
    { text: 'are connected.', fontSize: 'clamp(38px, 5.1vw, 73px)',   fontWeight: 700, isPatterned: false },
    { text: 'Trends',         fontSize: 'clamp(92px, 12.6vw, 180px)', fontWeight: 800, isPatterned: true  },
    { text: 'shows you',      fontSize: 'clamp(52px, 7.1vw, 101px)',  fontWeight: 700, isPatterned: false },
    { text: 'how.',           fontSize: 'clamp(78px, 10.6vw, 152px)', fontWeight: 800, isPatterned: true  },
];

// One unique GSAP "from" state per line
const ANIMATIONS = [
    { opacity: 0, y: 40 },                   // "your"           — fade up
    { opacity: 0, letterSpacing: '0.25em' },  // "habits"         — collapse from wide
    { opacity: 0, filter: 'blur(12px)' },     // "are connected." — blur reveal
    { opacity: 0, scale: 0.88 },              // "Trends"         — scale up
    { opacity: 0, x: 60 },                    // "shows you"      — slide from right
    { opacity: 0, y: -40 },                   // "how."           — drop from above
];

export function TrendsSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const lineRefs = useRef<(HTMLSpanElement | null)[]>([]);

    useEffect(() => {
        if (!sectionRef.current) return;

        // Reduced-motion guard
        const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
        if (mq.matches) {
            gsap.set(lineRefs.current.filter(Boolean), { opacity: 1 });
            return;
        }

        gsap.set(lineRefs.current.filter(Boolean), { opacity: 0 });

        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: sectionRef.current,
                pin: true,
                start: 'top top',
                end: `+=${TOTAL_SCROLL}`,
                scrub: 1,
                refreshPriority: -2,
            },
        });

        LINES.forEach((_, i) => {
            const el = lineRefs.current[i];
            if (!el) return;
            tl.fromTo(
                el,
                { ...ANIMATIONS[i] },
                {
                    opacity: 1,
                    y: 0,
                    x: 0,
                    scale: 1,
                    filter: 'blur(0px)',
                    letterSpacing: '-0.045em',
                    duration: 0.4,
                    ease: 'power3.out',
                },
                i * 0.5,
            );
        });

        tl.to({}, { duration: 0.6 }, 2.9);

        return () => {
            tl.scrollTrigger?.kill();
            tl.kill();
        };
    }, []);

    return (
        <section
            ref={sectionRef}
            id="trends-section"
            className="relative w-full"
            style={{ height: '100vh', backgroundColor: CREAM }}
        >
            <div
                style={{
                    display: 'grid',
                    gridTemplateColumns: '50% 50%',
                    height: '100%',
                    alignItems: 'center',
                }}
            >
                {/* Left column: right-aligned text */}
                <div style={{ paddingRight: '3vw', overflow: 'hidden' }}>
                    {LINES.map((line, i) => (
                        <span
                            key={line.text}
                            ref={(el) => { lineRefs.current[i] = el; }}
                            className={line.isPatterned ? 'ds-pattern-text' : undefined}
                            style={{
                                display: 'block',
                                textAlign: 'right',
                                fontFamily: '"Plus Jakarta Sans", sans-serif',
                                fontSize: line.fontSize,
                                fontWeight: line.fontWeight,
                                lineHeight: 0.90,
                                letterSpacing: '-0.045em',
                                whiteSpace: 'nowrap',
                                ...(line.isPatterned
                                    ? { backgroundImage: 'var(--ds-pattern-sage)' }
                                    : { color: '#141E18' }),
                            }}
                        >
                            {line.text}
                        </span>
                    ))}
                </div>

                {/* Right column: empty — phone occupies via ScrollPhoneCanvas fixed overlay */}
                <div />
            </div>
        </section>
    );
}

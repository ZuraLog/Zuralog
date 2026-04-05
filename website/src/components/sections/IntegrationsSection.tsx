"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { SplitText } from 'gsap/SplitText';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(SplitText, ScrollTrigger);
}

const TOP_TEXT =
    'Apple Health · Google Health Connect · and every fitness app you already use';

const BOTTOM_TEXT =
    'All in ZuraLog · One Dashboard · Zero Switching · Every Metric';

export function IntegrationsSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const topTextRef = useRef<HTMLHeadingElement>(null);
    const botTextRef = useRef<HTMLHeadingElement>(null);

    useEffect(() => {
        const section = sectionRef.current;
        const topEl = topTextRef.current;
        const botEl = botTextRef.current;
        if (!section || !topEl || !botEl) return;

        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        const topSplit = SplitText.create(topEl, { type: 'chars, words' });
        const botSplit = SplitText.create(botEl, { type: 'chars, words' });

        // SplitText moves all text into child spans, which breaks background-clip:text
        // on the parent. Apply the forest-green pattern directly to every char span.
        const applyPattern = (chars: Element[]) => {
            (chars as HTMLElement[]).forEach((char) => {
                char.style.display = 'inline-block'; // required for background-clip on inline
                char.style.backgroundImage = "url('/patterns/original.png')";
                char.style.backgroundSize = '300px auto';
                char.style.backgroundRepeat = 'repeat';
                char.style.backgroundClip = 'text';
                (char.style as CSSStyleDeclaration & { webkitBackgroundClip: string }).webkitBackgroundClip = 'text';
                char.style.color = 'transparent';
                char.style.animation = 'dsPatternDrift 45s linear infinite';
            });
        };

        applyPattern(topSplit.chars as Element[]);
        applyPattern(botSplit.chars as Element[]);

        // Start the bottom text off-screen to the LEFT.
        // Must be measured after SplitText has run (it can change layout).
        const botWidth = botEl.scrollWidth;
        gsap.set(botEl, { x: -botWidth });

        /**
         * ONE timeline → ONE ScrollTrigger with pin.
         * Both text animations run at the same progress (position 0),
         * so they are perfectly in sync and share the same pin spacer.
         */
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                pin: true,
                end: '+=3000px',
                scrub: true,
            },
        });

        // TOP: right → left (xPercent: -100 moves element left by its own width)
        tl.to(topEl, { xPercent: -100, ease: 'none' }, 0);

        // BOTTOM: left → right (from -botWidth to +innerWidth so the full text crosses)
        tl.to(botEl, { x: window.innerWidth, ease: 'none' }, 0);

        /**
         * Char entrance animations via containerAnimation.
         * Both reference the master timeline so their progress tracks
         * with the shared scroll.
         */
        const charKills: Array<() => void> = [];

        (topSplit.chars as HTMLElement[]).forEach((char) => {
            const t = gsap.from(char, {
                yPercent: gsap.utils.random(-200, 200),
                rotation: gsap.utils.random(-20, 20),
                ease: 'back.out(1.2)',
                scrollTrigger: {
                    trigger: char,
                    containerAnimation: tl,
                    start: 'left 100%',
                    end: 'left 30%',
                    scrub: 1,
                },
            });
            charKills.push(() => { t.scrollTrigger?.kill(); t.kill(); });
        });

        (botSplit.chars as HTMLElement[]).forEach((char) => {
            const t = gsap.from(char, {
                yPercent: gsap.utils.random(-200, 200),
                rotation: gsap.utils.random(-20, 20),
                ease: 'back.out(1.2)',
                scrollTrigger: {
                    trigger: char,
                    containerAnimation: tl,
                    start: 'right 0%',
                    end: 'right 60%',
                    scrub: 1,
                },
            });
            charKills.push(() => { t.scrollTrigger?.kill(); t.kill(); });
        });

        return () => {
            charKills.forEach((kill) => kill());
            tl.scrollTrigger?.kill();
            tl.kill();
            topSplit.revert();
            botSplit.revert();
        };
    }, []);

    return (
        <section
            ref={sectionRef}
            id="next-section"
            className="relative w-full overflow-hidden bg-ds-canvas"
            style={{ height: '100vh' }}
        >
            {/* Thin sage divider at the 50% line */}
            <div
                aria-hidden="true"
                className="absolute inset-x-0 pointer-events-none"
                style={{
                    top: '50%',
                    height: '1px',
                    background:
                        'linear-gradient(to right, transparent 0%, var(--color-ds-border-strong) 20%, var(--color-ds-sage) 50%, var(--color-ds-border-strong) 80%, transparent 100%)',
                    opacity: 0.5,
                    zIndex: 10,
                }}
            />

            {/* TOP HALF — right to left */}
            <div
                className="absolute inset-x-0 top-0 flex items-center overflow-hidden"
                style={{ height: '50%' }}
            >
                <h2
                    ref={topTextRef}
                    className="whitespace-nowrap font-jakarta font-bold"
                    style={{
                        fontSize: 'clamp(3rem, 42vh, 55vh)',
                        paddingLeft: '100vw',
                        width: 'max-content',
                        lineHeight: 1.05,
                        letterSpacing: '-0.03em',
                    }}
                >
                    {TOP_TEXT}
                </h2>
            </div>

            {/* BOTTOM HALF — left to right */}
            <div
                className="absolute inset-x-0 bottom-0 flex items-center overflow-hidden"
                style={{ height: '50%' }}
            >
                <h2
                    ref={botTextRef}
                    className="whitespace-nowrap font-jakarta font-bold"
                    style={{
                        fontSize: 'clamp(3rem, 42vh, 55vh)',
                        width: 'max-content',
                        lineHeight: 1.05,
                        letterSpacing: '-0.03em',
                    }}
                >
                    {BOTTOM_TEXT}
                </h2>
            </div>
        </section>
    );
}

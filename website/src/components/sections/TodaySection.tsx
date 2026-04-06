"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { SplitText } from 'gsap/SplitText';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';
import { Card, Text } from '@/components/design-system';
import { Moon, Zap, Heart, Activity, Droplet, Coffee } from 'lucide-react';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(SplitText, ScrollTrigger);
}

const LOG_ITEMS = [
    { emoji: '👟', name: 'Steps',              color: '#30D158', image: '/images/quick-log/steps.jpg' },
    { emoji: '📍', name: 'Distance',           color: '#30D158', image: '/images/quick-log/distance.jpg' },
    { emoji: '🔥', name: 'Active Calories',    color: '#FF9F0A', image: '/images/quick-log/active-calories.jpg' },
    { emoji: '🏢', name: 'Floors Climbed',     color: '#64D2FF', image: '/images/quick-log/floors-climbed.jpg' },
    { emoji: '🏋️', name: 'Workout',            color: '#30D158', image: '/images/quick-log/workout.jpg' },
    { emoji: '🚶', name: 'Walking Speed',      color: '#30D158', image: '/images/quick-log/walking-speed.jpg' },
    { emoji: '🏃', name: 'Running Pace',       color: '#FF9F0A', image: '/images/quick-log/running-pace.jpg' },
    { emoji: '😴', name: 'Sleep Duration',     color: '#5E5CE6', image: '/images/quick-log/sleep-duration.jpg' },
    { emoji: '🌙', name: 'Sleep Quality',      color: '#5E5CE6', image: '/images/quick-log/sleep-quality.jpg' },
    { emoji: '❤️', name: 'Resting Heart Rate', color: '#FF375F', image: '/images/quick-log/resting-heart-rate.jpg' },
    { emoji: '📉', name: 'HRV',                color: '#FF375F', image: '/images/quick-log/hrv.jpg' },
    { emoji: '🩸', name: 'Blood Pressure',     color: '#FF375F', image: '/images/quick-log/blood-pressure.jpg' },
    { emoji: '🫁', name: 'VO2 Max',            color: '#64D2FF', image: '/images/quick-log/vo2-max.jpg' },
    { emoji: '⚖️', name: 'Body Weight',        color: '#64D2FF', image: '/images/quick-log/body-weight.jpg' },
    { emoji: '📊', name: 'Body Fat',           color: '#64D2FF', image: '/images/quick-log/body-fat.jpg' },
    { emoji: '🌡️', name: 'Body Temperature',   color: '#FF9F0A', image: '/images/quick-log/body-temperature.jpg' },
    { emoji: '🫧', name: 'Blood Oxygen',       color: '#64D2FF', image: '/images/quick-log/blood-oxygen.jpg' },
    { emoji: '💨', name: 'Respiratory Rate',   color: '#64D2FF', image: '/images/quick-log/respiratory-rate.jpg' },
    { emoji: '💧', name: 'Water Intake',       color: '#64D2FF', image: '/images/quick-log/water-intake.jpg' },
    { emoji: '🍽️', name: 'Calories Consumed',  color: '#FF9F0A', image: '/images/quick-log/calories-consumed.jpg' },
    { emoji: '🥩', name: 'Macros',             color: '#FF9F0A', image: '/images/quick-log/macros.jpg' },
    { emoji: '😊', name: 'Mood',               color: '#BF5AF2', image: '/images/quick-log/mood.jpg' },
    { emoji: '☀️', name: 'Energy Level',       color: '#FFD60A', image: '/images/quick-log/energy-level.jpg' },
    { emoji: '🧘', name: 'Stress Level',       color: '#FFD60A', image: '/images/quick-log/stress-level.jpg' },
    { emoji: '🌸', name: 'Cycle Tracking',     color: '#BF5AF2', image: '/images/quick-log/cycle-tracking.jpg' },
].map((item, i) => ({ ...item, uniqueId: `${item.name}-${i}` }));

export function TodaySection() {
    const sectionRef    = useRef<HTMLElement>(null);

    // Typography refs (Beat 1)
    const beat1Ref      = useRef<HTMLDivElement>(null);
    const headlineRef   = useRef<HTMLHeadingElement>(null);
    const botGroupRef   = useRef<HTMLDivElement>(null);
    const decoLineRef   = useRef<HTMLDivElement>(null);

    // Accordion refs (Beat 2)
    const beat2Ref = useRef<HTMLDivElement>(null);
    const accordionRowRef = useRef<HTMLDivElement>(null);
    const cardsRef = useRef<(HTMLDivElement | null)[]>([]);

    // Insights refs (Beat 3)
    const beat3Ref = useRef<HTMLDivElement>(null);
    const card1Ref = useRef<HTMLDivElement>(null);
    const card2Ref = useRef<HTMLDivElement>(null);
    const card3Ref = useRef<HTMLDivElement>(null);
    const card4Ref = useRef<HTMLDivElement>(null);
    const card5Ref = useRef<HTMLDivElement>(null);
    const card6Ref = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const section   = sectionRef.current;
        const headEl    = headlineRef.current;
        const botGroup  = botGroupRef.current;
        const beat1El   = beat1Ref.current;
        const decoLine  = decoLineRef.current;
        const beat2El   = beat2Ref.current;
        const row       = accordionRowRef.current;
        const beat3El   = beat3Ref.current;
        const c1 = card1Ref.current;
        const c2 = card2Ref.current;
        const c3 = card3Ref.current;
        const c4 = card4Ref.current;
        const c5 = card5Ref.current;
        const c6 = card6Ref.current;

        if (!section || !headEl || !botGroup || !beat1El || !decoLine || !beat2El || !row) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        // ── Beat 1: scroll-pinned cinematic entrance ──
        const split = SplitText.create(headEl, { type: 'lines', mask: 'lines' });
        const lines = split.lines as HTMLElement[];

        gsap.set(lines, { yPercent: 110, rotateX: 8 });
        gsap.set(headEl, { transformPerspective: 900 });

        const beat1Tl = gsap.timeline({
            scrollTrigger: {
                trigger: beat1El,
                pin: true,
                start: 'top top',
                end: '+=800',
                scrub: 1,
            },
        });

        beat1Tl
            // Phase 0: decorative line draws in
            .fromTo(decoLine,
                { width: '0px', opacity: 0 },
                { width: '120px', opacity: 1, duration: 0.2, ease: 'power2.out' },
                0,
            )
            // Phase 1: headline lines tip up from below their masks, staggered
            .to(lines, {
                yPercent: 0,
                rotateX: 0,
                duration: 0.5,
                stagger: 0.08,
                ease: 'power4.out',
            }, 0.1)
            // Phase 2: subtext blurs and fades in
            .fromTo(botGroup,
                { opacity: 0, y: 28, filter: 'blur(6px)' },
                { opacity: 1, y: 0,  filter: 'blur(0px)', duration: 0.3, ease: 'power3.out' },
                0.55,
            )
            // Hold fully-revealed state before unpin
            .to({}, { duration: 0.15 });

        // ── Beat 2 Accordion Flipbook Timeline ──
        const STRIP_WIDTH = 64;
        const EXPANDED_WIDTH = window.innerWidth * 0.30; // 30vw for portrait column
        const totalItems = cardsRef.current.length;
        const containerWidth = window.innerWidth * 0.65; // User's red box boundary
        
        const virtualTotalWidth = (totalItems * STRIP_WIDTH) - STRIP_WIDTH + EXPANDED_WIDTH;
        // The distance we need to drag the container leftwards to see the final card
        const slideDistance = Math.max(0, virtualTotalWidth - containerWidth + 96); 

        if (cardsRef.current[0]) {
            gsap.set(cardsRef.current[0], { width: EXPANDED_WIDTH });
            const firstImg = cardsRef.current[0].querySelector('img');
            if (firstImg) gsap.set(firstImg, { scale: 1, filter: 'grayscale(0%)' });
        }

        const accordionTl = gsap.timeline({
            scrollTrigger: {
                trigger: beat2El,
                pin: true,
                start: 'top top',
                // Adjusted end to make 1 scroll physically closer to 1 card tick
                end: `+=${totalItems * 120}`,
                scrub: 1,
            },
        });

        // Reserve the last 15% of the scrolling distance just to "hold" the final card on screen
        const SLIDE_DURATION = 0.85; 
        const interval = SLIDE_DURATION / (totalItems - 1);

        // Continuous horizontal scroll binding that spans exactly the SLIDE_DURATION
        accordionTl.fromTo(row, 
            { x: 0 }, 
            { x: -slideDistance, duration: SLIDE_DURATION, ease: 'none'}, 
            0
        );
        
        cardsRef.current.forEach((card, i) => {
            if (!card) return;
            const peakTime = i * interval;
            const label = card.querySelector('.accordion-label');
            const img = card.querySelector('img');
            
            if (i > 0) {
                // Instantly expand current card i
                accordionTl.set(card, { width: EXPANDED_WIDTH }, peakTime);
                if (label) accordionTl.set(label, { opacity: 1 }, peakTime);
                if (img) accordionTl.set(img, { scale: 1, filter: 'grayscale(0%)' }, peakTime);

                // Instantly shrink previous card i-1
                const prevCard = cardsRef.current[i-1];
                if (prevCard) {
                   accordionTl.set(prevCard, { width: STRIP_WIDTH }, peakTime);
                   const prevLabel = prevCard.querySelector('.accordion-label');
                   if (prevLabel) accordionTl.set(prevLabel, { opacity: 0.25 }, peakTime);
                   const prevImg = prevCard.querySelector('img');
                   if (prevImg) accordionTl.set(prevImg, { scale: 1.15, filter: 'grayscale(100%)' }, peakTime);
                }
            }
        });

        // CRITICAL BUG FIX: Force timeline to be exactly 1.0 unit long. 
        // Without this, GSAP truncates the timeline at 0.85, negating the 15% buffer
        // and causing the Pin to release exactly as the final card animates.
        accordionTl.to({}, { duration: 1.0 - SLIDE_DURATION }, SLIDE_DURATION);

        // ── Beat 3: AI Insights Sequence ──
        let beat3Tl: gsap.core.Timeline | undefined;
        if (beat3El && c1 && c2 && c3 && c4 && c5 && c6) {
            // Setup initial states
            gsap.set([c1, c2, c3, c4, c5, c6], { opacity: 0, y: 30 });

            beat3Tl = gsap.timeline({
                scrollTrigger: {
                    trigger: beat3El,
                    pin: true,
                    start: 'top top',
                    end: '+=2500', // Pinned duration increased for 6 sequential scrubs
                    scrub: 1,
                },
            });

            // Sequential stagger fade-ins via timeline
            beat3Tl.to(c1, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 0)
                   .to(c2, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 0.5)
                   .to(c3, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 1.0)
                   .to(c4, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 1.5)
                   .to(c5, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 2.0)
                   .to(c6, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 2.5)
                   .to({}, { duration: 1 }); // hold state at end before unpinning
        }

        return () => {
            beat1Tl.scrollTrigger?.kill();
            beat1Tl.kill();
            accordionTl.scrollTrigger?.kill();
            accordionTl.kill();
            if (beat3Tl) {
                beat3Tl.scrollTrigger?.kill();
                beat3Tl.kill();
            }
            split.revert();
        };
    }, []);

    return (
        <section
            ref={sectionRef}
            id="today-section"
            className="w-full bg-[#F0EEE9]"
        >

            {/* ════════════════════════════════════════
                BEAT 1 — Introduction
            ════════════════════════════════════════ */}
            <div
                ref={beat1Ref}
                style={{
                    height: '100vh',
                    position: 'relative',
                    display: 'grid',
                    gridTemplateColumns: '70% 30%',
                }}
            >
                {/* LEFT — content, vertically centered */}
                <div
                    style={{
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'center',
                        gap: '40px',
                        padding: '64px 32px 64px 96px',
                    }}
                >
                    {/* DECORATIVE LINE */}
                    <div
                        ref={decoLineRef}
                        style={{
                            width: '0px',
                            height: '1px',
                            backgroundColor: '#344E41',
                            opacity: 0,
                        }}
                    />

                    {/* HEADLINE */}
                    <h2
                        ref={headlineRef}
                        className="font-jakarta font-extrabold"
                        style={{ fontSize: 'clamp(76px, 9vw, 130px)', lineHeight: 0.95, letterSpacing: '-0.04em', color: '#141E18' }}
                    >
                        See{' '}
                        <em className="not-italic ds-pattern-text" style={{ backgroundImage: 'var(--ds-pattern-sage)' }}>everything</em>{' '}
                        about your day —{' '}
                        <em className="not-italic ds-pattern-text" style={{ backgroundImage: 'var(--ds-pattern-sage)' }}>all at a glance.</em>
                    </h2>

                    {/* SUBTEXT */}
                    <div ref={botGroupRef} style={{ opacity: 0 }}>
                        <p
                            className="font-jakarta"
                            style={{ fontSize: '18px', fontWeight: 400, lineHeight: 1.65, maxWidth: '480px', color: '#6B6864' }}
                        >
                            Every metric you care about — steps, sleep, heart rate, calories —
                            pulled from all your apps and unified in one glanceable view.
                        </p>
                    </div>
                </div>

                {/* RIGHT — 30% reserved for the phone */}
                <div />
            </div>



            {/* ════════════════════════════════════════
                BEAT 2 — Full Bleed Accordion Columns
            ════════════════════════════════════════ */}
            <div
                id="beat2"
                ref={beat2Ref}
                style={{ height: '100vh', display: 'flex', flexDirection: 'column', backgroundColor: 'transparent' }}
                className="z-10 relative"
            >
                {/* Accordion Row (Full Height) */}
                <div style={{ flex: 1, overflow: 'hidden', width: '65vw' }}>
                    <div
                        ref={accordionRowRef}
                        style={{ display: 'flex', height: '100%', alignItems: 'stretch', width: 'max-content' }}
                    >
                        {LOG_ITEMS.map((item, index) => {
                            const isFirst = index === 0;
                            const isLast = index === LOG_ITEMS.length - 1;
                            return (
                                <div
                                    key={item.uniqueId}
                                    ref={(el: HTMLDivElement | null) => {
                                       if (el) cardsRef.current[index] = el;
                                    }}
                                    className="relative shrink-0 flex items-center justify-start overflow-hidden"
                                    style={{
                                        width: isFirst ? '30vw' : '64px',
                                        height: '100%',
                                        backgroundColor: '#F0EEE9', // Canvas Light
                                    }}
                                >
                                    {/* Gradient right divider line */}
                                    {!isLast && (
                                        <div 
                                            className="absolute right-0 top-0 w-[1px] h-full"
                                            style={{
                                                background: 'linear-gradient(to bottom, rgba(107, 104, 100, 0) 15%, rgba(107, 104, 100, 0.4) 50%, rgba(107, 104, 100, 0) 85%)',
                                                zIndex: 10
                                            }}
                                        />
                                    )}
                                    {/* 1. Inner Expanded Content Portrait Col */}
                                    <div
                                        className="absolute overflow-hidden rounded-[16px]"
                                        style={{ 
                                            top: '40px', 
                                            bottom: '40px', 
                                            left: '88px', 
                                            width: 'calc(30vw - 120px)',
                                            boxShadow: '0 12px 48px rgba(40, 50, 40, 0.05)'
                                        }}
                                    >
                                        <div className="w-full h-full overflow-hidden relative bg-[#DEDAD4]">
                                            <img
                                                src={item.image}
                                                alt={item.name}
                                                className="w-full h-full object-cover"
                                                style={{
                                                    transform: isFirst ? 'scale(1)' : 'scale(1.15)',
                                                    filter: isFirst ? 'grayscale(0%)' : 'grayscale(100%)',
                                                }}
                                            />
                                        </div>
                                    </div>

                                    {/* 2. Strategy Vertical Label Overlays */}
                                    <div
                                        className="absolute top-0 left-0 h-full w-[64px] flex flex-col items-center justify-end py-12"
                                    >

                                        {/* Bottom Item Name */}
                                        <span
                                            className="accordion-label ds-pattern-text font-jakarta whitespace-nowrap uppercase tracking-widest font-semibold"
                                            style={{
                                                writingMode: 'vertical-rl',
                                                transform: 'rotate(180deg)',
                                                fontSize: '13px',
                                                backgroundImage: 'var(--ds-pattern-sage)',
                                                opacity: isFirst ? 1 : 0.25,
                                            }}
                                        >
                                            {item.name}
                                        </span>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>
            </div>

            {/* ════════════════════════════════════════
                BEAT 3 — AI Insights Surround
            ════════════════════════════════════════ */}
            <div
                id="beat3"
                ref={beat3Ref}
                style={{ height: '100vh', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', backgroundColor: '#F0EEE9' }}
                className="z-10 relative p-6 gap-4"
            >
                {/* Left Column (Area 1, 3, 5) */}
                <div className="flex flex-col justify-center gap-4 h-full">
                    
                    {/* INSIGHT CARD 1 (GREEN) */}
                    <div ref={card1Ref} className="w-full">
                        <Card elevation="feature" category="activity" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Moon size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Sleep Quality</Text>
                            </div>
                            <Text variant="display-lg" color="sage" pattern="sage" className="mt-1 text-6xl tracking-tighter">92</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                Your deep sleep spiked significantly after avoiding late meals. Keep up the 8pm block.
                            </Text>
                        </Card>
                    </div>

                    {/* INSIGHT CARD 3 (YELLOW) */}
                    <div ref={card3Ref} className="w-full">
                        <Card elevation="feature" category="mobility" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Zap size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Pacing Protocol</Text>
                            </div>
                            <Text variant="display-lg" color="warning" pattern="amber" className="mt-1 text-[#FF9500] text-5xl tracking-tighter">Warning</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                You are pushing your limits too aggressively. HR metrics suggest CNS fatigue.
                            </Text>
                        </Card>
                    </div>

                    {/* INSIGHT CARD 5 (RED) */}
                    <div ref={card5Ref} className="w-full">
                        <Card elevation="feature" category="heart" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Droplet size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Hydration</Text>
                            </div>
                            <Text variant="display-lg" color="primary" pattern="original" className="mt-1 text-[#007AFF] text-6xl tracking-tighter">100%</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                Perfect hydration level attained by 2 PM. This directly fueled your crash-free afternoon.
                            </Text>
                        </Card>
                    </div>

                </div>

                {/* Center Column - Reserved for Phone Container */}
                <div></div>

                {/* Right Column (Area 2, 4, 6) */}
                <div className="flex flex-col justify-center gap-4 h-full">
                    
                    {/* INSIGHT CARD 2 (RED) */}
                    <div ref={card2Ref} className="w-full">
                        <Card elevation="feature" category="heart" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Heart size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Resting Heart Rate</Text>
                            </div>
                            <Text variant="display-lg" color="sage" pattern="sage" className="mt-1 text-5xl tracking-tight">58 bpm</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                Lowest average RHR in 30 days. Cardiovascular strain has officially stabilized.
                            </Text>
                        </Card>
                    </div>

                    {/* INSIGHT CARD 4 (GREEN) */}
                    <div ref={card4Ref} className="w-full">
                        <Card elevation="feature" category="activity" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Activity size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Daily Activity</Text>
                            </div>
                            <Text variant="display-lg" color="sage" pattern="sage" className="mt-1 text-6xl tracking-tighter">8,432</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                Consistent movement tracking automatically synchronized via Apple Health integration.
                            </Text>
                        </Card>
                    </div>

                    {/* INSIGHT CARD 6 (YELLOW) */}
                    <div ref={card6Ref} className="w-full">
                        <Card elevation="feature" category="mobility" className="w-full flex flex-col justify-center px-6 py-5">
                            <div className="flex items-center gap-3 mb-4">
                                <Coffee size={24} className="text-ds-text-secondary" />
                                <Text variant="label-lg" color="secondary">Caffeine Intake</Text>
                            </div>
                            <Text variant="display-lg" color="sage" pattern="sage" className="mt-1 text-5xl tracking-tighter">0 mg</Text>
                            <Text variant="body-lg" color="secondary" className="mt-4 leading-snug">
                                Late night stimulant intake was successfully avoided. Excellent adherence to the protocol.
                            </Text>
                        </Card>
                    </div>

                </div>
            </div>

        </section>
    );
}

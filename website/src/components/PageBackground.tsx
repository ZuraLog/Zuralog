"use client";

/**
 * PageBackground.tsx
 *
 * Single fixed full-viewport background layer that drives the page's ambient
 * color for the ENTIRE page via scroll position. Sections are transparent.
 *
 * Color journey:
 *   Hero                  → #FAFAF5  (cream)
 *   MobileSection slide 1 → #CFE1B9  (sage green)
 *   MobileSection slide 2 → #DAEEF7  (blue)
 *   MobileSection slide 3 → #F7DAE4  (pink)
 *   MobileSection slide 4 → #D6F0E0  (light green)
 *   BentoSection          → #2D2D2D  (dark charcoal)
 *   WaitlistSection       → #FAFAF5  (cream)
 *
 * For MobileSection the waypoints are evenly distributed across its scroll
 * height (SLIDE_COUNT × 100vh of pinned scroll). For other sections the
 * transition completes over the first 40% of the section's height.
 */

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

const SLIDE_COUNT = 4;

/** Mobile section slide colors — must match MobileSection.tsx SLIDES array */
const MOBILE_COLORS = [
    { bgFrom: "#CFE1B9", bgTo: "#DAEEF7" },
    { bgFrom: "#DAEEF7", bgTo: "#F7DAE4" },
    { bgFrom: "#F7DAE4", bgTo: "#FDF0E0" },
    { bgFrom: "#FDF0E0", bgTo: "#D6F0E0" },
];

/** Starting color — matches HeroSection bg-cream */
const HERO_COLOR = "#FAFAF5";

export function PageBackground() {
    const bgRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const el = bgRef.current;
        if (!el) return;

        el.style.backgroundColor = HERO_COLOR;

        // ── Build waypoint list ──────────────────────────────────────────────
        // Each waypoint: { scrollY, color }
        // scrollY is the scroll position at which this color is fully reached.

        const getWaypoints = () => {
            const waypoints: Array<{ scrollY: number; color: string }> = [
                { scrollY: 0, color: HERO_COLOR },
            ];

            // ── MobileSection waypoints ──
            const mobileSection = document.getElementById("mobile-section");
            if (mobileSection) {
                const mobileTop = mobileSection.offsetTop;
                // Total scroll distance for the pinned animation = SLIDE_COUNT × vh
                const mobilePinHeight = SLIDE_COUNT * window.innerHeight;

                MOBILE_COLORS.forEach((slide, i) => {
                    // Each slide occupies 1/SLIDE_COUNT of the total pin scroll
                    const sliceHeight = mobilePinHeight / SLIDE_COUNT;
                    // Midpoint of each slide is where the blend completes
                    waypoints.push({
                        scrollY: mobileTop + i * sliceHeight + sliceHeight * 0.5,
                        color: slide.bgFrom,
                    });
                });

                // After last slide, hold final color
                waypoints.push({
                    scrollY: mobileTop + mobilePinHeight,
                    color: MOBILE_COLORS[MOBILE_COLORS.length - 1].bgTo,
                });
            }

            // ── BentoSection waypoint ──
            const bentoSection = document.getElementById("bento-section");
            if (bentoSection) {
                const bentoTop = bentoSection.offsetTop;
                const bentoHeight = bentoSection.offsetHeight;
                waypoints.push({
                    scrollY: bentoTop + bentoHeight * 0.4,
                    color: "#2D2D2D",
                });
            }

            // ── WaitlistSection waypoint ──
            const waitlistSection = document.getElementById("waitlist");
            if (waitlistSection) {
                const waitlistTop = waitlistSection.offsetTop;
                const waitlistHeight = waitlistSection.offsetHeight;
                waypoints.push({
                    scrollY: waitlistTop + waitlistHeight * 0.4,
                    color: HERO_COLOR,
                });
            }

            // Sort ascending by scrollY
            waypoints.sort((a, b) => a.scrollY - b.scrollY);
            return waypoints;
        };

        let waypoints = getWaypoints();

        // Recompute on resize (section heights change)
        const onResize = () => {
            waypoints = getWaypoints();
        };
        window.addEventListener("resize", onResize);

        // ── Single master ScrollTrigger ──────────────────────────────────────
        const masterTrigger = ScrollTrigger.create({
            trigger: document.body,
            start: "top top",
            end: "bottom bottom",
            scrub: true,
            onUpdate() {
                const scrollY = window.scrollY;

                // Find the segment we're in
                let fromWP = waypoints[0];
                let toWP = waypoints[0];

                for (let i = 0; i < waypoints.length - 1; i++) {
                    if (scrollY <= waypoints[i + 1].scrollY) {
                        fromWP = waypoints[i];
                        toWP = waypoints[i + 1];
                        break;
                    }
                    // Past all waypoints — hold last color
                    fromWP = waypoints[waypoints.length - 1];
                    toWP = waypoints[waypoints.length - 1];
                }

                const segmentLength = toWP.scrollY - fromWP.scrollY;
                const progress =
                    segmentLength <= 0
                        ? 1
                        : Math.min(1, Math.max(0, (scrollY - fromWP.scrollY) / segmentLength));

                const interpolated = gsap.utils.interpolate(
                    fromWP.color,
                    toWP.color,
                    progress
                ) as string;

                el.style.backgroundColor = interpolated;
            },
        });

        return () => {
            masterTrigger.kill();
            window.removeEventListener("resize", onResize);
        };
    }, []);

    return (
        <div
            ref={bgRef}
            aria-hidden="true"
            className="fixed inset-0 -z-10 pointer-events-none"
            style={{ backgroundColor: HERO_COLOR }}
        />
    );
}

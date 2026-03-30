"use client";

/**
 * PageBackground.tsx
 *
 * Single fixed full-viewport background layer driving the page's ambient
 * color for the ENTIRE page via scroll position. Sections are transparent.
 *
 * Premium dark redesign color journey:
 *   Hero                  → #161618  (dark canvas)
 *   MobileSection         → #1A1C1F  (very subtle warm lift — the "breathing" zone)
 *   HowItWorksSection     → #161618  (back to canvas)
 *   BentoSection          → #161618  (dark canvas)
 *   PhoneMockupSection    → #161618  (dark canvas)
 *   WaitlistSection       → #161618  (dark canvas)
 */

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

const SLIDE_COUNT = 4;

/** Dark canvas — the page base */
const DARK_CANVAS = "#161618";
/** Subtle warm dark lift for the MobileSection "breathing" zone */
const DARK_LIFT = "#1A1C1F";
/** Slightly lighter dark for transitions */
const DARK_MID = "#18181A";

/** Mobile section — subtle dark variations (keeps the "breathing" feel) */
const MOBILE_COLORS = [
    { bgFrom: DARK_CANVAS, bgTo: DARK_LIFT },
    { bgFrom: DARK_LIFT, bgTo: DARK_MID },
    { bgFrom: DARK_MID, bgTo: DARK_LIFT },
    { bgFrom: DARK_LIFT, bgTo: DARK_CANVAS },
];

export function PageBackground() {
    const bgRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const el = bgRef.current;
        if (!el) return;

        el.style.backgroundColor = DARK_CANVAS;

        const getWaypoints = () => {
            const waypoints: Array<{ scrollY: number; color: string }> = [
                { scrollY: 0, color: DARK_CANVAS },
            ];

            // ── MobileSection waypoints ──
            const mobileSection = document.getElementById("mobile-section");
            if (mobileSection) {
                const mobileTop = mobileSection.offsetTop;
                const mobilePinHeight = SLIDE_COUNT * window.innerHeight;

                MOBILE_COLORS.forEach((slide, i) => {
                    const sliceHeight = mobilePinHeight / SLIDE_COUNT;
                    waypoints.push({
                        scrollY: mobileTop + i * sliceHeight + sliceHeight * 0.5,
                        color: slide.bgFrom,
                    });
                });

                waypoints.push({
                    scrollY: mobileTop + mobilePinHeight,
                    color: DARK_CANVAS,
                });
            }

            // ── HowItWorksSection ── (stay on canvas dark)
            const howSection = document.getElementById("how-it-works-section");
            if (howSection) {
                const howTop = howSection.offsetTop;
                const howHeight = howSection.offsetHeight;
                waypoints.push({ scrollY: howTop + howHeight * 0.5, color: DARK_CANVAS });
                waypoints.push({ scrollY: howTop + howHeight * 0.95, color: DARK_CANVAS });
            }

            // ── BentoSection ── (stay on canvas dark)
            const bentoSection = document.getElementById("bento-section");
            if (bentoSection) {
                const bentoTop = bentoSection.offsetTop;
                const bentoHeight = bentoSection.offsetHeight;
                waypoints.push({ scrollY: bentoTop + bentoHeight * 0.5, color: DARK_CANVAS });
                waypoints.push({ scrollY: bentoTop + bentoHeight * 0.95, color: DARK_CANVAS });
            }

            // ── PhoneMockupSection ── (stay on canvas dark)
            const phoneSection = document.getElementById("phone-mockup-section");
            if (phoneSection) {
                const phoneTop = phoneSection.offsetTop;
                const phoneHeight = phoneSection.offsetHeight;
                waypoints.push({ scrollY: phoneTop + phoneHeight * 0.5, color: DARK_CANVAS });
                waypoints.push({ scrollY: phoneTop + phoneHeight * 0.95, color: DARK_CANVAS });
            }

            // ── WaitlistSection ── (stay on canvas dark)
            const waitlistSection = document.getElementById("waitlist");
            if (waitlistSection) {
                const waitlistTop = waitlistSection.offsetTop;
                const waitlistHeight = waitlistSection.offsetHeight;
                waypoints.push({
                    scrollY: waitlistTop + waitlistHeight * 0.4,
                    color: DARK_CANVAS,
                });
            }

            waypoints.sort((a, b) => a.scrollY - b.scrollY);
            return waypoints;
        };

        let waypoints = getWaypoints();

        const onResize = () => {
            waypoints = getWaypoints();
        };
        window.addEventListener("resize", onResize);

        const masterTrigger = ScrollTrigger.create({
            trigger: document.body,
            start: "top top",
            end: "bottom bottom",
            scrub: true,
            onUpdate() {
                const scrollY = window.scrollY;

                let fromWP = waypoints[0];
                let toWP = waypoints[0];

                for (let i = 0; i < waypoints.length - 1; i++) {
                    if (scrollY <= waypoints[i + 1].scrollY) {
                        fromWP = waypoints[i];
                        toWP = waypoints[i + 1];
                        break;
                    }
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
            style={{ backgroundColor: DARK_CANVAS }}
        />
    );
}

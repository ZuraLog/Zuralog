"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import type { LayoutCursor, PreparedTextWithSegments, LayoutLine } from "@chenglou/pretext";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// Phone default position for this section — read by ScrollPhoneCanvas.
export const COACH_DEFAULT = { posX: 0, posY: 0, scale: 0.35, rotY: 0 };

// ── Types ─────────────────────────────────────────────────────────────────────
type BlockType = "hero" | "pull-large" | "pull-medium" | "body";

// ── Content (trimmed ~20%) ────────────────────────────────────────────────────
const BLOCKS: { type: BlockType; text: string }[] = [
    { type: "hero", text: "Meet Zura." },
    {
        type: "body",
        text: "Zura is your personal health assistant inside ZuraLog. It has access to everything you have ever logged and synced — every step, every night of sleep, every workout, every meal, every heart rate reading. All of it lives in one place and all of it is available to Zura the moment you open a conversation. Most health apps put your data on a screen and leave it there, waiting for you to make sense of it yourself. Zura does something different. It helps you understand what those numbers actually mean for your life, your energy, your goals, and your body. It answers the question most apps never try to answer — not what happened, but why it happened and what you should do next. Zura is not another dashboard. It is the thing that makes every dashboard finally useful. Think of it as having a doctor, a nutritionist, a personal trainer, and a sleep specialist all in one place, all of them already familiar with your complete history. No matter how fragmented your data is across devices and apps, Zura pulls it all together into one coherent conversation.",
    },
    { type: "pull-large", text: "It does not just talk. It acts." },
    {
        type: "body",
        text: "Tell Zura to log your morning run and it logs it for you, right there in the conversation. Tell it you want to lose ten pounds before summer and it builds that goal, sets up the tracking, and follows your progress every single day. Ask it to put together a meal plan for the week and it creates one grounded in what you have already been eating, your calorie targets, and your current training load. Ask it to schedule a reminder for your medication or your evening walk, and it does it immediately. You do not have to navigate through menus or remember where a feature lives inside the app. You just have a conversation, the way you would talk to a real coach who already has your full file open in front of them, and Zura takes care of everything on your behalf. No forms. No friction. Just ask, and it is done. Every interaction feels more like talking to someone who genuinely knows your health story than operating a piece of software.",
    },
    { type: "pull-medium", text: "Your data. Correlated. Understood." },
    {
        type: "body",
        text: "Zura connects patterns across every source of data you have. It does not look at your sleep in isolation or your workouts without considering your recovery. It sees your whole health picture at once and draws its conclusions from that full picture. It sees that your sleep quality falls on nights when you exercise after eight in the evening. It sees that your heart rate variability dips two days after your hardest training sessions. It sees that your afternoon energy slumps are tied to how little protein you had at breakfast. It sees that your recovery time after long runs has been shortening month over month, which means your body is adapting in exactly the right direction. These are the kinds of connections that would take months of self-observation to notice on your own. Zura notices them in seconds, because it has access to all of your data simultaneously and never stops looking for what your numbers are trying to tell you. It is the kind of comprehensive analysis no single specialist can provide, because no single specialist has your complete health picture the way Zura does.",
    },
    { type: "pull-large", text: "Ask it anything. Get a real answer." },
    {
        type: "body",
        text: "Why have I been so tired this week even though I am sleeping enough? Should I take a rest day today or stick to my training schedule? What should I eat before my long run on Saturday? Is my resting heart rate higher than it should be for my fitness level? Am I eating enough to support the training volume I have been putting in lately? These are not rhetorical questions. Zura gives you real answers, grounded in your actual data and your own personal health history. It has already read through your last thirty days of metrics before you finish composing the question. It is reading your specific numbers, your individual trends, your recurring patterns, and your unique health context. Every answer is personal because every piece of evidence it draws on is entirely yours. The quality of the answer depends on the quality of the data, and because ZuraLog is where all your health data lives, Zura always has everything it needs to give you a genuinely useful response.",
    },
    { type: "pull-medium", text: "The longer you use it, the better it knows you." },
    {
        type: "body",
        text: "Zura builds a detailed memory of who you are over time and gets smarter the longer you use it. It remembers every goal you have told it about, what has worked for your body, what has had no meaningful effect, and what has made things worse. The longer you use Zura, the more precisely it understands you as an individual, because it is continuously building a picture of your health specific to you alone. And it always talks to you the way you actually want to be talked to. If you need a coach who is direct and holds you accountable, you can have that. If you need someone patient and encouraging who celebrates every small win, you can have that instead. You decide how it speaks to you. It is not a product you learn to use. It is a relationship that grows with you. Over time, Zura becomes less of a tool and more of a companion — one that remembers, adapts, and improves alongside you every single day.",
    },
    { type: "hero", text: "Your health, finally understood." },
];

// ── Per-type visual config ────────────────────────────────────────────────────
const TYPE_CONFIG: Record<
    BlockType,
    {
        fontWeight: number;
        resolveFontSize: (vw: number) => number;
        lineHeightPx: number;
        blockGapPx: number;
    }
> = {
    "hero": { fontWeight: 800, resolveFontSize: vw => Math.min(Math.max(44, vw * 0.055), 82), lineHeightPx: 86, blockGapPx: 32 },
    "pull-large": { fontWeight: 700, resolveFontSize: vw => Math.min(Math.max(24, vw * 0.030), 42), lineHeightPx: 44, blockGapPx: 24 },
    "pull-medium": { fontWeight: 600, resolveFontSize: vw => Math.min(Math.max(16, vw * 0.018), 22), lineHeightPx: 27, blockGapPx: 20 },
    "body": { fontWeight: 400, resolveFontSize: () => 13, lineHeightPx: 21, blockGapPx: 16 },
};

const LETTER_SPACING: Record<BlockType, string> = {
    "hero": "-0.04em",
    "pull-large": "-0.025em",
    "pull-medium": "-0.015em",
    "body": "normal",
};

// ── Layout constants ──────────────────────────────────────────────────────────
const SIDE_PADDING = 88;
const COL_GAP = 40;
const NUM_COLS = 3;
const TOP_PADDING = 96;

const PHONE_W = 230;
const PHONE_H = 430;
const PHONE_PAD = 14;
// Minimum usable slot width — slots narrower than this are skipped.
// Phone+pad = 258px; col ≈ 394px → max ~136px available per side.
// Keep at 80 so wrapping fires whenever there is a meaningful gap on either side.
const MIN_SLOT_WIDTH = 80;
// Maximum width of the 3-column text layout. Beyond this the newspaper
// columns become too wide to read comfortably.
const MAX_CONTENT_W = 1440;

// ── Default / idle position ────────────────────────────────────────────────────
// Dead-center of the content area — respects MAX_CONTENT_W at ultrawide sizes.
function getIdlePhonePos(sectionWidth: number) {
    const contentW = Math.min(sectionWidth, MAX_CONTENT_W);
    const contentLeft = (sectionWidth - contentW) / 2;
    return {
        x: contentLeft + (contentW - PHONE_W) / 2,
        y: (window.innerHeight - PHONE_H) / 2,
    };
}

const POOL_SIZE = 600;

// ── Per-block prepared data ───────────────────────────────────────────────────
interface BlockInfo {
    blockIdx: number;
    type: BlockType;
    prepared: PreparedTextWithSegments;
    fontSize: number;
}

// ── Component ─────────────────────────────────────────────────────────────────
export function CoachSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const contentWrapRef = useRef<HTMLDivElement>(null);
    const phoneElRef = useRef<HTMLDivElement>(null);
    const colRefs = useRef<(HTMLDivElement | null)[]>([null, null, null]);

    const spanPoolsRef = useRef<HTMLSpanElement[][]>([[], [], []]);
    const spanTypeRef = useRef<(BlockType | null)[][]>([[], [], []]);

    // All blocks in order — text flows across columns continuously
    const allBlocksRef = useRef<BlockInfo[]>([]);
    const colGeomRef = useRef<{ left: number; width: number }[]>([]);

    const phonePosRef = useRef({ x: -9999, y: -9999 });
    const rafRef = useRef(0);
    const readyRef = useRef(false);
    const inSectionRef = useRef(false);

    const layoutNextLineRef = useRef<
        ((p: PreparedTextWithSegments, c: LayoutCursor, w: number) => LayoutLine | null) | null
    >(null);

    // ── Span helper ───────────────────────────────────────────────────────────
    function placeSpan(
        span: HTMLSpanElement,
        types: (BlockType | null)[],
        idx: number,
        text: string,
        left: number,
        top: number,
        width: number,
        bInfo: BlockInfo,
        isPattern: boolean,
        lh: number,
        cfg: typeof TYPE_CONFIG[BlockType],
    ) {
        span.textContent = text;
        span.style.display = "block";
        span.style.position = "absolute";
        span.style.top = `${top}px`;
        span.style.left = `${left}px`;
        span.style.width = `${width}px`;
        span.style.whiteSpace = "nowrap";
        span.style.overflow = "hidden";
        span.style.fontFamily = '"Plus Jakarta Sans", sans-serif';
        span.style.fontWeight = String(cfg.fontWeight);
        span.style.fontSize = `${bInfo.fontSize}px`;
        span.style.lineHeight = `${lh}px`;
        span.style.letterSpacing = LETTER_SPACING[bInfo.type];
        span.dataset.blockType = bInfo.type;

        if (types[idx] !== bInfo.type) {
            if (isPattern) {
                span.className = "ds-pattern-text";
                span.style.backgroundImage = "var(--ds-pattern-sage)";
                span.style.color = "transparent";
            } else {
                span.className = "";
                span.style.backgroundImage = "";
                span.style.color = "#6B6864";
            }
            types[idx] = bInfo.type;
        }
    }

    // ── Layout pass ───────────────────────────────────────────────────────────
    //
    // Text flows continuously across all three columns — like a newspaper.
    // When a column is full, text picks up at the top of the next column.
    // The phone obstacle splits lines within whichever column it overlaps.

    function doLayout(phoneX: number, phoneY: number) {
        const nextLine = layoutNextLineRef.current;
        if (!nextLine || !readyRef.current) return;

        const pL = phoneX - PHONE_PAD;
        const pR = phoneX + PHONE_W + PHONE_PAD;
        const pT = phoneY - PHONE_PAD;
        const pB = phoneY + PHONE_H + PHONE_PAD;

        if (phoneElRef.current) {
            phoneElRef.current.style.left = `${phoneX}px`;
            phoneElRef.current.style.top = `${phoneY}px`;
        }

        const colHeight = window.innerHeight - TOP_PADDING * 2;

        let ci = 0;        // current column
        let y = 0;        // y within current column container
        const spanIdx = [0, 0, 0];

        for (const bInfo of allBlocksRef.current) {
            if (ci >= NUM_COLS) break;

            const cfg = TYPE_CONFIG[bInfo.type];
            const lh = cfg.lineHeightPx;
            const isPattern = bInfo.type !== "body";

            let cursor: LayoutCursor = { segmentIndex: 0, graphemeIndex: 0 };

            let guard = 0;
            while (guard++ < 1200) {
                // Advance to next column if the current one is full
                while (ci < NUM_COLS && y + lh > colHeight) {
                    ci++;
                    y = 0;
                }
                if (ci >= NUM_COLS) break;

                const geom = colGeomRef.current[ci];
                const spans = spanPoolsRef.current[ci];
                const types = spanTypeRef.current[ci];

                if (spanIdx[ci] >= POOL_SIZE - 1) break;

                const bandT = y + TOP_PADDING;
                const bandB = bandT + lh;
                const colL = geom.left;
                const colR = geom.left + geom.width;

                const phoneInBand = pB > bandT && pT < bandB;

                if (phoneInBand) {
                    const iL = Math.max(colL, pL);
                    const iR = Math.min(colR, pR);

                    if (iL < iR) {
                        const leftW = iL - colL;
                        const rightW = colR - iR;
                        const rightX = iR - colL;
                        let filled = false;

                        if (leftW >= MIN_SLOT_WIDTH) {
                            const line = nextLine(bInfo.prepared, cursor, leftW);
                            if (!line) break;
                            placeSpan(spans[spanIdx[ci]], types, spanIdx[ci], line.text, 0, y, leftW, bInfo, isPattern, lh, cfg);
                            cursor = line.end;
                            spanIdx[ci]++;
                            filled = true;
                        }

                        if (rightW >= MIN_SLOT_WIDTH && spanIdx[ci] < POOL_SIZE) {
                            const line = nextLine(bInfo.prepared, cursor, rightW);
                            if (line) {
                                placeSpan(spans[spanIdx[ci]], types, spanIdx[ci], line.text, rightX, y, rightW, bInfo, isPattern, lh, cfg);
                                cursor = line.end;
                                spanIdx[ci]++;
                                filled = true;
                            }
                        }

                        if (!filled) {
                            const probe = nextLine(bInfo.prepared, cursor, geom.width);
                            if (!probe) break;
                            cursor = probe.end;
                        }

                        y += lh;
                        continue;
                    }
                }

                // Normal full-width line
                const line = nextLine(bInfo.prepared, cursor, geom.width);
                if (!line) break; // block exhausted
                placeSpan(spans[spanIdx[ci]], types, spanIdx[ci], line.text, 0, y, geom.width, bInfo, isPattern, lh, cfg);
                cursor = line.end;
                spanIdx[ci]++;
                y += lh;
            }

            // Gap after block — advance y (may push into next column)
            y += cfg.blockGapPx;
        }

        // Hide unused spans in all columns
        for (let c = 0; c < NUM_COLS; c++) {
            for (let i = spanIdx[c]; i < spanPoolsRef.current[c].length; i++) {
                spanPoolsRef.current[c][i].style.display = "none";
            }
        }
    }

    // ── Init ──────────────────────────────────────────────────────────────────
    useEffect(() => {
        let cancelled = false;

        const init = async () => {
            await document.fonts.ready;
            if (cancelled) return;

            const { prepareWithSegments, layoutNextLine } =
                await import("@chenglou/pretext");
            if (cancelled) return;

            layoutNextLineRef.current = layoutNextLine;

            const sectionWidth = sectionRef.current?.offsetWidth ?? window.innerWidth;
            const vw = sectionWidth;  // font sizes scale with section width, consistent with column geometry
            // Cap at MAX_CONTENT_W so columns stay readable at ultrawide widths.
            const contentW = Math.min(sectionWidth, MAX_CONTENT_W);
            // Horizontal offset from the section's left edge to the content container's left edge.
            const contentLeft = (sectionWidth - contentW) / 2;
            const colWidth = (contentW - SIDE_PADDING * 2 - COL_GAP * (NUM_COLS - 1)) / NUM_COLS;

            colGeomRef.current = Array.from({ length: NUM_COLS }, (_, i) => ({
                left: contentLeft + SIDE_PADDING + i * (colWidth + COL_GAP),
                width: colWidth,
            }));

            // Prepare all blocks as a single ordered stream
            allBlocksRef.current = BLOCKS.map((block, idx) => {
                const cfg = TYPE_CONFIG[block.type];
                const fontSize = cfg.resolveFontSize(vw);
                const fontStr = `${cfg.fontWeight} ${fontSize}px Plus Jakarta Sans`;
                return {
                    blockIdx: idx,
                    type: block.type,
                    prepared: prepareWithSegments(block.text, fontStr),
                    fontSize,
                };
            });

            if (cancelled) return;

            // Build span pools
            const pools: HTMLSpanElement[][] = [[], [], []];
            const typeTrack: (BlockType | null)[][] = [[], [], []];

            for (let ci = 0; ci < NUM_COLS; ci++) {
                const container = colRefs.current[ci];
                if (!container) continue;
                container.innerHTML = "";

                const pool: HTMLSpanElement[] = [];
                const types: (BlockType | null)[] = [];

                for (let i = 0; i < POOL_SIZE; i++) {
                    const span = document.createElement("span");
                    span.style.display = "none";
                    span.style.opacity = "0";
                    container.appendChild(span);
                    pool.push(span);
                    types.push(null);
                }

                pools[ci] = pool;
                typeTrack[ci] = types;
            }

            spanPoolsRef.current = pools;
            spanTypeRef.current = typeTrack;
            readyRef.current = true;

            // Keep the rectangle off-screen at init — onEnter places it once
            // the ScrollTrigger pin activates.  This prevents it from appearing
            // while the section is still scrolling into view.
            doLayout(-9999, -9999);

            if (cancelled) return;

            // All 1800 pool spans — display:none spans get opacity:1 from GSAP
            // but stay invisible, so it is safe to animate the whole flat pool.
            const liveSpans = pools.flat();
            liveSpans.forEach(s => { s.style.opacity = "0"; });

            const section = sectionRef.current;
            if (!section) return;

            // ── Pre-compute layout with phone at idle to get span groups ─────────
            // Run doLayout with phone visible so we can read which spans are active
            // and tag them by block type before the section ever enters view.
            const idlePos = getIdlePhonePos(sectionWidth);
            phonePosRef.current.x = idlePos.x;
            phonePosRef.current.y = idlePos.y;
            doLayout(idlePos.x, idlePos.y);

            // Collect all visible spans and sort top-to-bottom for the burst reveal.
            const allSpans: HTMLSpanElement[] = liveSpans
                .filter(s => s.style.display !== "none")
                .sort((a, b) => parseFloat(a.style.top || "0") - parseFloat(b.style.top || "0"));

            // Reset phone off-screen — onEnter brings it back.
            phonePosRef.current.x = -9999;
            phonePosRef.current.y = -9999;
            doLayout(-9999, -9999);
            liveSpans.forEach(s => { s.style.opacity = "0"; });

            // ── Pre-pin entrance: content fades + deblurs as section scrolls into view ─
            // The section background (#F0EEE9) is always solid — only the content animates.
            const contentWrap = contentWrapRef.current;
            if (!contentWrap) return;

            const entranceST = ScrollTrigger.create({
                trigger: section,
                start: "top 90%",
                end: "top top",
                scrub: 1,
                onUpdate: (self) => {
                    gsap.set(contentWrap, {
                        opacity: self.progress,
                        filter: `blur(${(1 - self.progress) * 10}px)`,
                    });
                },
                onLeave:     () => gsap.set(contentWrap, { opacity: 1, filter: "blur(0px)" }),
                onEnterBack: () => gsap.set(contentWrap, { opacity: 1, filter: "blur(0px)" }),
                onLeaveBack: () => gsap.set(contentWrap, { opacity: 0, filter: "blur(10px)" }),
            });

            // ── Phone initial state — timeline scales it in ───────────────────────
            const phoneEl = phoneElRef.current;
            if (phoneEl) gsap.set(phoneEl, { scale: 0, filter: "blur(8px)", opacity: 0 });

            // ── Main pinned timeline ──────────────────────────────────────────────
            const SCROLL_BUDGET = Math.max(window.innerHeight * 3, 3000);

            const tl = gsap.timeline({
                scrollTrigger: {
                    trigger: section,
                    pin: true,
                    start: "top top",
                    end: `+=${SCROLL_BUDGET}`,
                    scrub: 1,
                    onEnter: () => {
                        inSectionRef.current = true;
                        const sw = sectionRef.current?.offsetWidth ?? window.innerWidth;
                        const pos = getIdlePhonePos(sw);
                        phonePosRef.current.x = pos.x;
                        phonePosRef.current.y = pos.y;
                        doLayout(pos.x, pos.y);
                    },
                    onEnterBack: () => {
                        inSectionRef.current = true;
                        const sw = sectionRef.current?.offsetWidth ?? window.innerWidth;
                        const pos = getIdlePhonePos(sw);
                        phonePosRef.current.x = pos.x;
                        phonePosRef.current.y = pos.y;
                        doLayout(pos.x, pos.y);
                    },
                    onLeave: () => {
                        inSectionRef.current = false;
                        gsap.killTweensOf(phonePosRef.current);
                        doLayout(-9999, -9999);
                    },
                    onLeaveBack: () => {
                        inSectionRef.current = false;
                        gsap.killTweensOf(phonePosRef.current);
                        doLayout(-9999, -9999);
                    },
                },
            });

            // Phase 0 — Phone materialises from nothing (0 → 1.2s)
            if (phoneEl) {
                tl.fromTo(phoneEl,
                    { scale: 0, filter: "blur(8px)", opacity: 0 },
                    { scale: 1, filter: "blur(0px)", opacity: 1, duration: 1.2, ease: "power2.out" },
                    0,
                );
            }

            // Phase 1 — All spans burst in top-to-bottom simultaneously (0.6s → end)
            if (allSpans.length > 0) {
                tl.fromTo(allSpans,
                    { opacity: 0, y: 8 },
                    { opacity: 1, y: 0, duration: 0.4, stagger: { each: 0.005, from: "start" }, ease: "power2.out" },
                    0.6,
                );
            }

            section.addEventListener("destroy-coach-tl", () => {
                entranceST.kill();
                tl.scrollTrigger?.kill();
                tl.kill();
            }, { once: true });
        };

        init();

        return () => {
            cancelled = true;
            sectionRef.current?.dispatchEvent(new Event("destroy-coach-tl"));
        };
    }, []);

    // ── Mouse tracking ────────────────────────────────────────────────────────
    useEffect(() => {
        const section = sectionRef.current;
        if (!section) return;

        const handleMouseMove = (e: MouseEvent) => {
            const rect = section.getBoundingClientRect();
            const vh = window.innerHeight;

            // Section is pinned (position:fixed, fills viewport) — track cursor
            if (rect.top <= 4 && rect.bottom >= vh - 4) {
                window.dispatchEvent(
                    new CustomEvent("zuralog:coach:mouse", {
                        detail: { clientX: e.clientX, clientY: e.clientY },
                    }),
                );
            }

            const sectionW = rect.width;
            const contentW = Math.min(sectionW, MAX_CONTENT_W);
            const contentLeft = (sectionW - contentW) / 2;

            const rawX = e.clientX - rect.left - PHONE_W / 2;
            const rawY = e.clientY - rect.top  - PHONE_H / 2;
            // Clamp phone obstacle within content bounds (not full section width at ultrawide).
            const targetX = Math.max(contentLeft, Math.min(contentLeft + contentW - PHONE_W, rawX));
            const targetY = Math.max(0, Math.min(rect.height - PHONE_H, rawY));

            gsap.to(phonePosRef.current, {
                x: targetX,
                y: targetY,
                duration: 0.45,
                ease: "power2.out",
                overwrite: "auto",
                onUpdate: () => doLayout(phonePosRef.current.x, phonePosRef.current.y),
            });
        };

        window.addEventListener("mousemove", handleMouseMove, { passive: true });

        return () => {
            window.removeEventListener("mousemove", handleMouseMove);
            cancelAnimationFrame(rafRef.current);
            gsap.killTweensOf(phonePosRef.current);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // ── Render ────────────────────────────────────────────────────────────────
    return (
        <section
            id="coach-section"
            ref={sectionRef}
            style={{
                height: "100vh",
                backgroundColor: "#F0EEE9",
                overflow: "hidden",
                position: "relative",
            }}
        >
            {/* Content wrapper — entrance animation targets this, not the section */}
            <div
                ref={contentWrapRef}
                style={{ position: "relative", height: "100%", opacity: 0 }}
            >
                {/* Phone obstacle */}
                <div
                    ref={phoneElRef}
                    aria-hidden
                    style={{
                        position: "absolute",
                        left: "-9999px",
                        top: "-9999px",
                        width: `${PHONE_W}px`,
                        height: `${PHONE_H}px`,
                        borderRadius: "16px",
                        background: "transparent",
                        border: "none",
                        pointerEvents: "none",
                        opacity: 0,
                        zIndex: 20,
                    }}
                />

                {/* Three column containers — spans appended imperatively */}
                <div
                    style={{
                        display: "grid",
                        gridTemplateColumns: "1fr 1fr 1fr",
                        gap: `${COL_GAP}px`,
                        padding: `${TOP_PADDING}px ${SIDE_PADDING}px`,
                        height: "100%",
                        overflow: "hidden",
                        boxSizing: "border-box",
                        maxWidth: `${MAX_CONTENT_W}px`,
                        margin: "0 auto",
                    }}
                >
                    {[0, 1, 2].map(ci => (
                        <div
                            key={ci}
                            ref={el => { colRefs.current[ci] = el; }}
                            style={{ position: "relative", overflow: "hidden" }}
                        />
                    ))}
                </div>
            </div>
        </section>
    );
}

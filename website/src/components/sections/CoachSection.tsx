"use client";

import { useRef, useEffect, useCallback } from "react";
import {
    prepareWithSegments,
    layoutNextLine,
    type PreparedTextWithSegments,
    type LayoutCursor,
} from "@chenglou/pretext";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// Phone default position for this section — read by ScrollPhoneCanvas.
export const COACH_DEFAULT = { posX: 0.4, posY: 0.1, scale: 0.58, rotY: -0.05 };

// ── Content ───────────────────────────────────────────────────────────────────
type BlockType = "hero" | "hero-closing" | "pull-large" | "pull-medium" | "body";

const BLOCKS: { type: BlockType; text: string }[] = [
    { type: "hero", text: "Meet Zura." },
    {
        type: "body",
        text: "Zura is your personal health assistant inside ZuraLog. It has access to everything you have ever logged and synced. Every step you have taken, every night of sleep you have tracked, every workout you have completed, every meal you have recorded, every heart rate reading your device has ever captured. All of it lives in one place and all of it is available to Zura the moment you open a conversation. Most health apps exist to show you numbers. They put your data on a screen and leave it there, waiting for you to make sense of it yourself. Zura does something different. Zura helps you understand what those numbers actually mean for your life, your energy, your goals, and your body. It answers the question most apps never try to answer, which is not what happened but why it happened and what you should do next. The difference between those two things is not a small one. It is the entire difference between having a drawer full of information and actually knowing what to do with your own health. Zura is not another dashboard. It is the thing that makes every dashboard finally useful. Think of it as having a doctor, a nutritionist, a personal trainer, and a sleep specialist all in one place, all of them already familiar with your complete history, all of them available the moment you have a question.",
    },
    { type: "pull-large", text: "It does not just talk. It acts." },
    {
        type: "body",
        text: "Tell Zura to log your morning run and it logs it for you, right there in the conversation. Tell it you want to lose ten pounds before summer and it builds that goal, sets up the tracking, and follows your progress toward it every single day without you ever having to check in on it manually. Ask it to put together a meal plan for the week and it creates one grounded in what you have already been eating, your calorie targets, your nutritional gaps, and your current training load. Ask it to schedule a reminder for your medication, your evening walk, or your weekly weigh-in, and it does it immediately. You do not have to learn how any of it works. You do not have to navigate through menus or remember where a feature lives inside the app. You do not have to open a separate screen, tap through a form, or remember to update anything by hand. You just have a conversation, the way you would talk to a real coach who already has your full file open in front of them, and Zura takes care of everything on your behalf. That is what it actually means to have a health assistant that assists. No forms. No friction. No forgetting. Just ask, and it is done.",
    },
    { type: "pull-medium", text: "Your data. Correlated. Understood." },
    {
        type: "body",
        text: "Zura connects patterns across every source of data you have. It does not look at your sleep in isolation. It does not examine your workouts without also considering how well you recovered from the previous one. It does not think about your nutrition without referencing how much energy you actually burned that day. It sees your whole health picture at once and draws its conclusions from that full picture, not from any single metric on its own. It sees that your sleep quality falls significantly on nights when you exercise after eight in the evening. It sees that your heart rate variability dips two days after your hardest training sessions. It sees that your afternoon energy slumps are closely tied to how little protein you had at breakfast. It sees that your step count during weekdays is much lower in the weeks when your stress scores are elevated. It sees that your recovery time after long runs has been shortening month over month, which means your body is actually adapting in exactly the right direction. These are the kinds of connections that would take months of careful self-observation to notice on your own. Zura notices them in seconds, because it has access to all of your data simultaneously and it never stops looking for what your numbers are trying to tell you. It works constantly, even when you are not thinking about your health at all.",
    },
    { type: "pull-large", text: "Ask it anything. Get a real answer." },
    {
        type: "body",
        text: "Why have I been so tired this week even though I am sleeping enough hours? Should I take a rest day today or stick to my training schedule? What should I eat the night before my long run on Saturday morning? Is my resting heart rate higher than it should be for my current fitness level? How has my sleep quality actually changed over the last three months compared to the three months before that? Is there a meaningful pattern between my mood scores and how much I moved during the day? Am I eating enough to support the training volume I have been putting in lately? These are not rhetorical questions. Zura gives you real answers, grounded in your actual data and drawn from your own personal health history. It has already read through your last thirty days of metrics before you even finish composing the question. It is not reaching into a generic health database somewhere on the internet. It is reading your specific numbers, your individual trends, your recurring patterns, and your unique health context, and it is responding to exactly what it finds there. Every answer Zura gives you is personal because every piece of evidence it draws on is entirely yours. No two people get the same answer, because no two people have the same data.",
    },
    { type: "pull-medium", text: "The longer you use it, the better it knows you." },
    {
        type: "body",
        text: "Zura builds a detailed memory of who you are over time and it gets smarter the longer you use it. It remembers every goal you have told it about. It remembers things you shared with it three weeks ago that you may have forgotten yourself. It remembers what has worked for your body, what has had no meaningful effect, and what has made things worse. It remembers your schedule, your preferences, your history, and the full context behind your health numbers. The longer you use Zura, the more precisely it understands you as an individual, because it is continuously building a picture of your health that is specific to you and nobody else in the world. And it always talks to you the way you actually want to be talked to. If you need a coach who is direct, blunt, and holds you accountable to your commitments, you can have that. If you need someone patient and encouraging who celebrates every small win and stays positive through the hard stretches, you can have that instead. You decide how it speaks to you. You decide how much it volunteers versus how much it waits to be asked. You set the tone and Zura adapts to suit your life, not the other way around. It is not a product you learn to use. It is a relationship that grows with you.",
    },
    { type: "hero-closing", text: "Your health, finally understood." },
];

// ── Flat word list — one entry per word, in render order ─────────────────────
const WORD_LIST = BLOCKS.flatMap((block, blockIdx) =>
    block.text
        .split(" ")
        .filter((w) => w.length > 0)
        .map((word) => ({
            word,
            type: block.type,
            isClosing: blockIdx === BLOCKS.length - 1,
        })),
);

// ── Per-word inline styles (replaces block-level divs) ───────────────────────
const WORD_STYLE: Record<BlockType, React.CSSProperties> = {
    "hero": {
        fontFamily: '"Plus Jakarta Sans", sans-serif',
        fontWeight: 800,
        fontSize: "clamp(44px, 5.5vw, 82px)",
        lineHeight: 0.93,
        letterSpacing: "-0.04em",
        color: "var(--color-ds-text-primary)",
    },
    "hero-closing": {
        fontFamily: '"Plus Jakarta Sans", sans-serif',
        fontWeight: 800,
        fontSize: "clamp(32px, 3.8vw, 48px)",
        lineHeight: 0.93,
        letterSpacing: "-0.04em",
        color: "var(--color-ds-text-primary)",
    },
    "pull-large": {
        fontFamily: '"Plus Jakarta Sans", sans-serif',
        fontWeight: 700,
        fontSize: "clamp(24px, 3vw, 42px)",
        lineHeight: 1.04,
        letterSpacing: "-0.025em",
        color: "#1E3A2F",
    },
    "pull-medium": {
        fontFamily: '"Plus Jakarta Sans", sans-serif',
        fontWeight: 600,
        fontSize: "clamp(16px, 1.8vw, 22px)",
        lineHeight: 1.2,
        letterSpacing: "-0.015em",
        color: "var(--color-ds-text-primary)",
    },
    "body": {
        fontFamily: '"Plus Jakarta Sans", sans-serif',
        fontWeight: 400,
        fontSize: "13px",
        lineHeight: 1.6,
        color: "var(--color-ds-text-secondary)",
    },
};

// ── Layout constants ──────────────────────────────────────────────────────────
const PAD_X  = 88;
const PAD_Y  = 96;
const COL_GAP = 40;    // 2.5rem in px
const NUM_COLS = 3;
// Phone calibration at scale=1.0 (derived from aura: 215×415 at scale 0.58).
const PHONE_BASE_W = 371;  // 215 / 0.58
const PHONE_BASE_H = 716;  // 415 / 0.58
// Camera constants — must match ScrollPhoneCanvas exactly.
const CAM_Z       = 5;
const HALF_FOV_Y  = Math.tan((Math.PI / 180) * 22.5); // fov=45 → half-angle=22.5°

// ── Font spec (JS mirror of WORD_STYLE clamp values) ─────────────────────────
type FontSpec = {
    fontSize: number;
    lineHeight: number;
    fontWeight: number;
    marginTop: number;
    marginBottom: number;
};

function resolveFontSpec(type: BlockType, vw: number): FontSpec {
    const cl = (a: number, b: number, c: number) => Math.min(Math.max(a, vw * b / 100), c);
    switch (type) {
        case "hero": {
            const s = cl(44, 5.5, 82);
            return { fontSize: s, lineHeight: s * 0.93, fontWeight: 800, marginTop: 0, marginBottom: s * 0.45 };
        }
        case "hero-closing": {
            const s = cl(32, 3.8, 48);
            return { fontSize: s, lineHeight: s * 0.93, fontWeight: 800, marginTop: s * 0.3, marginBottom: 0 };
        }
        case "pull-large": {
            const s = cl(24, 3, 42);
            return { fontSize: s, lineHeight: s * 1.04, fontWeight: 700, marginTop: s * 0.3, marginBottom: s * 0.4 };
        }
        case "pull-medium": {
            const s = cl(16, 1.8, 22);
            return { fontSize: s, lineHeight: s * 1.2, fontWeight: 600, marginTop: s * 0.25, marginBottom: s * 0.35 };
        }
        case "body":
            return { fontSize: 13, lineHeight: 13 * 1.6, fontWeight: 400, marginTop: 0, marginBottom: 13 * 0.55 };
    }
}

// ── Phone bounding box → viewport pixels ─────────────────────────────────────
// When the section is pinned by GSAP it fills the full viewport (position:fixed,
// top:0, left:0, 100vw×100vh), so viewport coords == container coords.
type PhoneAnim = { posX: number; posY: number; scale: number };
type BBox      = { left: number; top: number; right: number; bottom: number; centerX: number };

function computePhoneBBox(phone: PhoneAnim): BBox {
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const halfWorldH = HALF_FOV_Y * CAM_Z;
    const halfWorldW = halfWorldH * (vw / vh);

    // 3D world → viewport pixels.
    const screenX = (phone.posX / halfWorldW + 1) * 0.5 * vw;
    const screenY = (-phone.posY / halfWorldH + 1) * 0.5 * vh;

    const pw = PHONE_BASE_W * phone.scale;
    const ph = PHONE_BASE_H * phone.scale;

    return {
        left:    screenX - pw / 2,
        top:     screenY - ph / 2,
        right:   screenX + pw / 2,
        bottom:  screenY + ph / 2,
        centerX: screenX,
    };
}

// ── Layout engine ─────────────────────────────────────────────────────────────
// Pure function — no DOM reads or writes.
// Returns one (x, y) per word, in WORD_LIST order.
//
// Strategy: the LAST block (closing hero) is pulled OUT of the 3-column flow
// and placed centered at the bottom of the section. This gives it guaranteed
// visibility and a cinematic reveal regardless of how long the column content is.
type WordPos = { x: number; y: number };
const INIT_CURSOR: LayoutCursor = { segmentIndex: 0, graphemeIndex: 0 };

const MAIN_BLOCK_COUNT = BLOCKS.length - 1; // all except closing hero

function runLayout(
    containerW: number,
    phoneBBox: BBox | null,
    prepared: PreparedTextWithSegments[],
    measureCtx: OffscreenCanvasRenderingContext2D,
): WordPos[] {
    const vw  = window.innerWidth;
    const vh  = window.innerHeight;
    const colW = (containerW - 2 * PAD_X - (NUM_COLS - 1) * COL_GAP) / NUM_COLS;

    // ── Pass 1: measure total content height (main blocks only).
    let totalH = 0;
    for (let b = 0; b < MAIN_BLOCK_COUNT; b++) {
        const spec = resolveFontSpec(BLOCKS[b].type, vw);
        let cursor: LayoutCursor = { ...INIT_CURSOR };
        let lineCount = 0;
        while (true) {
            const line = layoutNextLine(prepared[b], cursor, colW);
            if (!line) break;
            lineCount++;
            cursor = line.end;
        }
        totalH += spec.marginTop + lineCount * spec.lineHeight + spec.marginBottom;
    }
    const targetColH = totalH / NUM_COLS;

    // ── Pass 2: full column layout with phone exclusion (main blocks only).
    const positions: WordPos[] = [];
    let col  = 0;
    let colY = 0;

    for (let b = 0; b < MAIN_BLOCK_COUNT; b++) {
        const block = BLOCKS[b];
        const spec  = resolveFontSpec(block.type, vw);

        const blockWords = block.text.split(" ").filter((w) => w.length > 0);
        let wordPtr = 0;

        measureCtx.font = `${spec.fontWeight} ${spec.fontSize}px "Plus Jakarta Sans"`;
        colY += spec.marginTop;

        let cursor: LayoutCursor = { ...INIT_CURSOR };

        while (true) {
            const colLeft    = PAD_X + col * (colW + COL_GAP);
            const lineTop    = PAD_Y + colY;
            const lineBottom = lineTop + spec.lineHeight;

            let lineMaxW = colW;
            let lineOffX = 0;

            if (phoneBBox) {
                const colRight = colLeft + colW;
                const xOverlap = phoneBBox.left < colRight  && phoneBBox.right  > colLeft;
                const yOverlap = phoneBBox.top  < lineBottom && phoneBBox.bottom > lineTop;

                if (xOverlap && yOverlap) {
                    const localL = Math.max(0,    phoneBBox.left  - colLeft);
                    const localR = Math.min(colW, phoneBBox.right - colLeft);

                    if (phoneBBox.centerX < colLeft + colW / 2) {
                        lineOffX = localR + 16;
                        lineMaxW = colW - lineOffX;
                    } else {
                        lineOffX = 0;
                        lineMaxW = Math.max(0, localL - 16);
                    }
                }
            }

            const layoutW   = lineMaxW < 40 ? colW : lineMaxW;
            const layoutOff = lineMaxW < 40 ? 0    : lineOffX;

            const line = layoutNextLine(prepared[b], cursor, layoutW);
            if (!line) break;

            const wordsOnLine = line.text.trim().split(/\s+/).filter(Boolean).length;
            let wordX = 0;
            for (let w = 0; w < wordsOnLine && wordPtr < blockWords.length; w++, wordPtr++) {
                positions.push({ x: colLeft + layoutOff + wordX, y: lineTop });
                wordX += measureCtx.measureText(blockWords[wordPtr] + " ").width;
            }

            colY  += spec.lineHeight;
            cursor = line.end;

            if (colY > targetColH && col < NUM_COLS - 1) {
                col++;
                colY = 0;
            }
        }

        colY += spec.marginBottom;
    }

    // ── Closing hero: centered horizontally, pinned to the bottom of the section.
    //    All 4 words land on one line so each scroll click reveals the next word
    //    in a cinematic left-to-right sweep.
    const closingBlock = BLOCKS[BLOCKS.length - 1];
    const closingSpec  = resolveFontSpec(closingBlock.type, vw);
    measureCtx.font = `${closingSpec.fontWeight} ${closingSpec.fontSize}px "Plus Jakarta Sans"`;

    const closingWords = closingBlock.text.split(" ").filter(Boolean);
    // Measure total line width so we can center it.
    let totalClosingW = 0;
    closingWords.forEach((w) => { totalClosingW += measureCtx.measureText(w + " ").width; });

    const closingY = vh - PAD_Y - closingSpec.lineHeight; // bottom-aligned, matching top padding
    let closingX   = Math.max(PAD_X, (containerW - totalClosingW) / 2);

    closingWords.forEach((word) => {
        positions.push({ x: closingX, y: closingY });
        closingX += measureCtx.measureText(word + " ").width;
    });

    return positions;
}

// ── Component ─────────────────────────────────────────────────────────────────
export function CoachSection() {
    const sectionRef   = useRef<HTMLElement>(null);
    const containerRef = useRef<HTMLDivElement>(null);
    const wordRefs     = useRef<(HTMLSpanElement | null)[]>([]);
    const preparedRef  = useRef<PreparedTextWithSegments[]>([]);
    const ctxRef       = useRef<OffscreenCanvasRenderingContext2D | null>(null);
    // Tracks the animated phone position (matches ScrollPhoneCanvas's anim object).
    const phoneRef     = useRef<PhoneAnim>({ posX: 0.4, posY: 0.1, scale: 0.58 });
    const layoutRafRef = useRef<number | null>(null);
    const idleRef      = useRef<ReturnType<typeof setTimeout> | null>(null);
    const inSectionRef = useRef(false);

    // ── Apply computed positions to DOM spans ─────────────────────────────────
    const applyLayout = useCallback(() => {
        const container = containerRef.current;
        if (!container || !preparedRef.current.length || !ctxRef.current) return;

        const rect      = container.getBoundingClientRect();
        const phoneBBox = computePhoneBBox(phoneRef.current);
        const positions = runLayout(rect.width, phoneBBox, preparedRef.current, ctxRef.current);

        const spans = wordRefs.current;
        for (let i = 0; i < positions.length && i < spans.length; i++) {
            const span = spans[i];
            if (!span) continue;
            span.style.left = positions[i].x + "px";
            span.style.top  = positions[i].y + "px";
        }
    }, []);

    const scheduleLayout = useCallback(() => {
        if (layoutRafRef.current) cancelAnimationFrame(layoutRafRef.current);
        layoutRafRef.current = requestAnimationFrame(applyLayout);
    }, [applyLayout]);

    // ── Initialise pretext + OffscreenCanvas after fonts are loaded ───────────
    useEffect(() => {
        const init = async () => {
            await document.fonts.ready;

            ctxRef.current = new OffscreenCanvas(1, 1).getContext("2d")!;

            const buildPrepared = () =>
                BLOCKS.map((block) => {
                    const spec = resolveFontSpec(block.type, window.innerWidth);
                    return prepareWithSegments(
                        block.text,
                        `${spec.fontWeight} ${spec.fontSize}px "Plus Jakarta Sans"`,
                    );
                });

            preparedRef.current = buildPrepared();
            applyLayout();

            // Re-prepare and re-layout on resize (clamp values change with vw).
            const onResize = () => {
                preparedRef.current = buildPrepared();
                scheduleLayout();
            };
            window.addEventListener("resize", onResize);
            return () => window.removeEventListener("resize", onResize);
        };

        init();
    }, [applyLayout, scheduleLayout]);

    // ── Mouse tracking → dispatch phone events + trigger re-layout ───────────
    useEffect(() => {
        const section = sectionRef.current;
        if (!section) return;

        const st = ScrollTrigger.create({
            trigger: section,
            start: "top 60%",
            end: "bottom 40%",
            onEnter:     () => { inSectionRef.current = true;  scheduleLayout(); },
            onLeave:     () => { inSectionRef.current = false; },
            onEnterBack: () => { inSectionRef.current = true;  scheduleLayout(); },
            onLeaveBack: () => { inSectionRef.current = false; },
        });

        const returnToDefault = () => {
            // Ease back to default — mirrors ScrollPhoneCanvas's idle handler.
            gsap.to(phoneRef.current, {
                posX: 0.4,
                posY: 0.1,
                duration: 1.4,
                ease: "power3.inOut",
                onUpdate: scheduleLayout,
            });
            window.dispatchEvent(new CustomEvent("zuralog:coach:idle"));
        };

        const handleMouseMove = (e: MouseEvent) => {
            if (!inSectionRef.current) return;

            const vw = window.innerWidth;
            const vh = window.innerHeight;
            const normalX =  (e.clientX / vw - 0.5) * 2;
            const normalY = -(e.clientY / vh - 0.5) * 2;

            // Animate phoneRef to match ScrollPhoneCanvas's eased position.
            gsap.to(phoneRef.current, {
                posX: normalX * 2.8,
                posY: normalY * 2.0 + 0.1,
                duration: 0.55,
                ease: "power2.out",
                overwrite: "auto",
                onUpdate: scheduleLayout,
            });

            // Tell the 3D phone in ScrollPhoneCanvas to follow too.
            window.dispatchEvent(
                new CustomEvent("zuralog:coach:mouse", {
                    detail: { clientX: e.clientX, clientY: e.clientY },
                }),
            );

            if (idleRef.current) clearTimeout(idleRef.current);
            idleRef.current = setTimeout(returnToDefault, 5000);
        };

        window.addEventListener("mousemove", handleMouseMove, { passive: true });

        return () => {
            window.removeEventListener("mousemove", handleMouseMove);
            if (idleRef.current) clearTimeout(idleRef.current);
            if (layoutRafRef.current) cancelAnimationFrame(layoutRafRef.current);
            st.kill();
        };
    }, [scheduleLayout]);

    // ── ScrollTrigger word streaming ──────────────────────────────────────────
    useEffect(() => {
        const section = sectionRef.current;
        if (!section) return;

        const raf = requestAnimationFrame(() => {
            const allWords     = section.querySelectorAll<HTMLSpanElement>("[data-coach-word]");
            const mainWords    = section.querySelectorAll<HTMLSpanElement>("[data-coach-word]:not([data-coach-closing])");
            const closingWords = section.querySelectorAll<HTMLSpanElement>("[data-coach-closing]");
            if (!allWords.length) return;

            const PX_MAIN    = 4;
            const PX_CLOSING = 100;
            const mainDur    = mainWords.length * PX_MAIN;
            const closingDur = closingWords.length * PX_CLOSING;

            gsap.set(allWords, { opacity: 0 });

            const tl = gsap.timeline({
                scrollTrigger: {
                    trigger: section,
                    pin: true,
                    start: "top top",
                    end: `+=${mainDur + closingDur}`,
                    scrub: 0.1,
                },
            });

            tl.to(mainWords,    { opacity: 1, stagger: PX_MAIN,    duration: 0.5, ease: "none" }, 0);
            tl.to(closingWords, { opacity: 1, stagger: PX_CLOSING,  duration: 1,   ease: "none" }, mainDur);

            section.addEventListener("destroy-coach-tl", () => {
                tl.scrollTrigger?.kill();
                tl.kill();
            }, { once: true });
        });

        return () => {
            cancelAnimationFrame(raf);
            sectionRef.current?.dispatchEvent(new Event("destroy-coach-tl"));
        };
    }, []);

    return (
        <section
            id="coach-section"
            ref={sectionRef}
            className="relative w-full overflow-hidden"
            style={{ height: "100vh", backgroundColor: "#F0EEE9" }}
        >
            {/* All words are absolutely positioned by the layout engine.      */}
            {/* Their (left, top) coordinates are computed by runLayout(), which */}
            {/* accounts for the phone's bounding box on every mouse move.       */}
            <div
                ref={containerRef}
                className="absolute inset-0"
                style={{ overflow: "hidden" }}
            >
                {WORD_LIST.map((item, i) => (
                    <span
                        key={i}
                        ref={(el) => { wordRefs.current[i] = el; }}
                        data-coach-word=""
                        {...(item.isClosing ? { "data-coach-closing": "" } : {})}
                        style={{
                            ...WORD_STYLE[item.type],
                            position: "absolute",
                            left: 0,
                            top: 0,
                            opacity: 0,
                            whiteSpace: "nowrap",
                        }}
                    >
                        {item.word}
                    </span>
                ))}
            </div>
        </section>
    );
}

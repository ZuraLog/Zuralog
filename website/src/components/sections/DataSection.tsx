"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { Text, CHART_COLORS, DS_CHART_THEME, DSChartTooltip, PatternOverlay } from "@/components/design-system";
import {
    AreaChart,
    Area,
    BarChart,
    Bar,
    LineChart,
    Line,
    XAxis,
    YAxis,
    CartesianGrid,
    ResponsiveContainer,
    Tooltip,
    Legend,
} from "recharts";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

/* ── Light-mode chart theme ------------------------------------------------ */
const chartTheme = {
    sage: "#344E41",
    activity: CHART_COLORS.activity,
    heart: CHART_COLORS.heart,
    sleep: CHART_COLORS.sleep,
    nutrition: CHART_COLORS.nutrition,
    body: CHART_COLORS.body,
    gridColor: "rgba(22, 22, 24, 0.06)",
    textColor: "#6B6864",
    fontSize: DS_CHART_THEME.fontSize,
    fontFamily: DS_CHART_THEME.fontFamily,
};

/* ── Sample data ----------------------------------------------------------- */
const weeklySteps = [
    { day: "Mon", steps: 6200 },
    { day: "Tue", steps: 8100 },
    { day: "Wed", steps: 7400 },
    { day: "Thu", steps: 9200 },
    { day: "Fri", steps: 8432 },
    { day: "Sat", steps: 5600 },
    { day: "Sun", steps: 4200 },
];

const multiSeries = [
    { day: "Mon", heartRate: 64, hrv: 42 },
    { day: "Tue", heartRate: 61, hrv: 51 },
    { day: "Wed", heartRate: 67, hrv: 38 },
    { day: "Thu", heartRate: 59, hrv: 58 },
    { day: "Fri", heartRate: 62, hrv: 48 },
    { day: "Sat", heartRate: 65, hrv: 44 },
    { day: "Sun", heartRate: 60, hrv: 55 },
];

const calorieData = [
    { day: "Mon", active: 420, resting: 1320 },
    { day: "Tue", active: 680, resting: 1420 },
    { day: "Wed", active: 510, resting: 1410 },
    { day: "Thu", active: 840, resting: 1500 },
    { day: "Fri", active: 620, resting: 1420 },
    { day: "Sat", active: 720, resting: 1290 },
    { day: "Sun", active: 380, resting: 1270 },
];

const sleepSparkData = weeklySteps.map(d => ({ day: d.day, val: Math.round(d.steps / 1000 * 8.5) }));

const axisTick = {
    fill: chartTheme.textColor,
    fontSize: chartTheme.fontSize,
    fontFamily: chartTheme.fontFamily,
};

/* ── Bento Cell wrapper ---------------------------------------------------- */
// Using plain divs instead of Card so the flex height chain reaches
// the ResponsiveContainer correctly. Pattern overlay is added manually.
function BentoCell({
    children,
    pattern,
    className = "",
    style = {},
}: {
    children: React.ReactNode;
    pattern: React.ComponentProps<typeof PatternOverlay>["variant"];
    className?: string;
    style?: React.CSSProperties;
}) {
    return (
        <div
            className={`relative overflow-hidden bg-ds-surface rounded-[16px] flex flex-col ${className}`}
            style={style}
        >
            <PatternOverlay variant={pattern} opacity={0.15} blend="color-burn" />
            {/* This z-10 div must also be flex-col h-full so children can use flex-1 */}
            <div className="relative z-10 flex flex-col h-full w-full p-5">
                {children}
            </div>
        </div>
    );
}

/* ── Component ------------------------------------------------------------- */
export function DataSection() {
    const sectionRef   = useRef<HTMLElement>(null);
    const cellGreenRef = useRef<HTMLDivElement>(null);
    const cellBlueRef  = useRef<HTMLDivElement>(null);
    const cellMagRef   = useRef<HTMLDivElement>(null);
    const cellYelRef   = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const section = sectionRef.current;
        const cGreen  = cellGreenRef.current;
        const cBlue   = cellBlueRef.current;
        const cMag    = cellMagRef.current;
        const cYel    = cellYelRef.current;
        if (!section || !cGreen || !cBlue || !cMag || !cYel) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        // Start all cells hidden
        gsap.set([cGreen, cBlue, cMag, cYel], { opacity: 0, y: 24 });

        // Pinned timeline — each scroll step reveals one cell
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                pin: true,
                start: 'top top',
                end: '+=2000',
                scrub: 1,
            },
        });

        // Top row: green first, then blue
        tl.to(cGreen, { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 0)
          .to(cBlue,  { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 0.6)
          // Bottom rows: magenta, then yellow
          .to(cMag,   { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 1.4)
          .to(cYel,   { opacity: 1, y: 0, duration: 1, ease: 'power2.out' }, 2.0)
          .to({}, { duration: 0.8 }); // hold at end before unpinning

        return () => { ScrollTrigger.getAll().forEach(t => t.kill()); };
    }, []);
    return (
        <section
            id="data-section"
            ref={sectionRef}
            className="relative w-full"
            style={{
                height: "100vh",
                display: "grid",
                gridTemplateColumns: "30% 70%",
                backgroundColor: "#F0EEE9",
                overflow: "hidden",
            }}
        >
            {/* Left 20%: empty — phone is rendered by ScrollPhoneCanvas */}
            <div className="h-full" />

            {/* Right 80%: Bento Grid — 3 columns × 3 rows */}
            <div
                className="h-full px-6 py-[80px] gap-4"
                style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr 1fr",
                    gridTemplateRows: "1fr 1fr 1fr",
                }}
            >
                {/* GREEN 2×1 — Weekly Steps Area Chart */}
                <div ref={cellGreenRef} style={{ gridColumn: "1 / 3", gridRow: "1 / 2" }} className="h-full">
                    <BentoCell pattern="green" className="h-full">
                        <Text variant="label-md" color="secondary" className="mb-3 shrink-0">Weekly Steps</Text>
                        <div className="flex-1 min-h-0">
                            <ResponsiveContainer width="100%" height="100%">
                                <AreaChart data={weeklySteps} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
                                    <defs>
                                        <linearGradient id="stepsGradient" x1="0" y1="0" x2="0" y2="1">
                                            <stop offset="5%" stopColor={chartTheme.activity} stopOpacity={0.35} />
                                            <stop offset="95%" stopColor={chartTheme.activity} stopOpacity={0} />
                                        </linearGradient>
                                    </defs>
                                    <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.gridColor} />
                                    <XAxis dataKey="day" tick={axisTick} axisLine={false} tickLine={false} />
                                    <YAxis tick={axisTick} axisLine={false} tickLine={false} />
                                    <Tooltip content={<DSChartTooltip valueFormatter={(v) => `${Number(v).toLocaleString()} steps`} />} />
                                    <Area type="monotone" dataKey="steps" name="Steps" stroke={chartTheme.activity} strokeWidth={2} fill="url(#stepsGradient)" />
                                </AreaChart>
                            </ResponsiveContainer>
                        </div>
                    </BentoCell>
                </div>

                {/* BLUE 1×1 — Sleep Score + Sparkbar */}
                <div ref={cellBlueRef} style={{ gridColumn: "3 / 4", gridRow: "1 / 2" }} className="h-full">
                    <BentoCell pattern="periwinkle" className="h-full">
                        <Text variant="label-md" color="secondary" className="shrink-0">Sleep Score</Text>
                        <p className="mt-1 font-jakarta shrink-0" style={{ fontSize: "2.75rem", lineHeight: 1, color: chartTheme.sleep, letterSpacing: "-0.03em" }}>84</p>
                        <Text variant="body-sm" color="secondary" className="mt-1 shrink-0">7h 24m avg · Up 8%</Text>
                        <div className="flex-1 min-h-0 mt-3">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={sleepSparkData} margin={{ top: 0, right: 0, left: -30, bottom: 0 }}>
                                    <Bar dataKey="val" fill={chartTheme.sleep} radius={[3, 3, 0, 0]} opacity={0.8} />
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </BentoCell>
                </div>

                {/* MAGENTA 2×2 — Heart Rate & HRV Multi-line Chart */}
                <div ref={cellMagRef} style={{ gridColumn: "1 / 3", gridRow: "2 / 4" }} className="h-full">
                    <BentoCell pattern="rose" className="h-full">
                        <Text variant="label-md" color="secondary" className="mb-3 shrink-0">Heart Rate &amp; HRV — 7 Day Trend</Text>
                        <div className="flex-1 min-h-0">
                            <ResponsiveContainer width="100%" height="100%">
                                <LineChart data={multiSeries} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.gridColor} />
                                    <XAxis dataKey="day" tick={axisTick} axisLine={false} tickLine={false} />
                                    <YAxis tick={axisTick} axisLine={false} tickLine={false} />
                                    <Tooltip content={<DSChartTooltip />} />
                                    <Legend iconType="circle" iconSize={7} wrapperStyle={{ fontSize: 11, fontFamily: chartTheme.fontFamily, color: chartTheme.textColor }} />
                                    <Line type="monotone" dataKey="heartRate" name="Heart Rate (bpm)" stroke={chartTheme.heart} strokeWidth={2} dot={false} activeDot={{ r: 4 }} />
                                    <Line type="monotone" dataKey="hrv" name="HRV (ms)" stroke={chartTheme.body} strokeWidth={2} dot={false} activeDot={{ r: 4 }} />
                                </LineChart>
                            </ResponsiveContainer>
                        </div>
                    </BentoCell>
                </div>

                {/* YELLOW 1×2 — Horizontal Stacked Calories Bar Chart */}
                <div ref={cellYelRef} style={{ gridColumn: "3 / 4", gridRow: "2 / 4" }} className="h-full">
                    <BentoCell pattern="amber" className="h-full">
                        <Text variant="label-md" color="secondary" className="mb-3 shrink-0">Calories Burned</Text>
                        <div className="flex-1 min-h-0">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={calorieData} layout="vertical" margin={{ top: 4, right: 8, left: 8, bottom: 0 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.gridColor} horizontal={false} />
                                    <XAxis type="number" tick={axisTick} axisLine={false} tickLine={false} />
                                    <YAxis type="category" dataKey="day" tick={axisTick} axisLine={false} tickLine={false} width={28} />
                                    <Tooltip content={<DSChartTooltip valueFormatter={(v) => `${Number(v).toLocaleString()} kcal`} />} />
                                    <Bar dataKey="active" name="Active" stackId="a" fill={chartTheme.nutrition} />
                                    <Bar dataKey="resting" name="Resting" stackId="a" fill={`${chartTheme.nutrition}66`} radius={[0, 3, 3, 0]} />
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </BentoCell>
                </div>
            </div>
        </section>
    );
}

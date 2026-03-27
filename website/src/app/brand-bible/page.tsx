"use client";

import { useState, type ReactNode } from "react";
import {
  PatternOverlay,
  Text,
  DSButton,
  Card,
  TextField,
  Toggle,
  DSCheckbox,
  DSSlider,
  DSRadioGroup,
  RadioItem,
  Chip,
  Divider,
  Avatar,
  Badge,
  DSAccordion,
  DSAccordionItem,
  DSAccordionTrigger,
  DSAccordionContent,
  DSTabs,
  DSTabsList,
  DSTabsTrigger,
  DSTabsContent,
  DSTooltip,
  DSTooltipTrigger,
  DSTooltipContent,
  DSDialog,
  DSDialogTrigger,
  DSDialogContent,
  DSDialogTitle,
  DSDialogDescription,
  DSDialogClose,
  /* ── New imports ───────────────────────────────────────────────── */
  DSChartContainer,
  DSChartTooltip,
  CHART_COLORS,
  DS_CHART_THEME,
  DSTable,
  DSTableHeader,
  DSTableBody,
  DSTableHead,
  DSTableRow,
  DSTableCell,
  DSSelect,
  DSSelectTrigger,
  DSSelectContent,
  DSSelectItem,
  DSSelectValue,
  DSTextarea,
  DSToggleGroup,
  DSCalendar,
  DSInputOTP,
  DSInputOTPGroup,
  DSInputOTPSlot,
  DSInputOTPSeparator,
  DSSheet,
  DSSheetTrigger,
  DSSheetContent,
  DSSheetHeader,
  DSSheetTitle,
  DSSheetDescription,
  DSPopover,
  DSPopoverTrigger,
  DSPopoverContent,
  DSHoverCard,
  DSHoverCardTrigger,
  DSHoverCardContent,
  DSCommand,
  DSCommandInput,
  DSCommandList,
  DSCommandEmpty,
  DSCommandGroup,
  DSCommandItem,
  DSBreadcrumb,
  DSBreadcrumbList,
  DSBreadcrumbItem,
  DSBreadcrumbLink,
  DSBreadcrumbPage,
  DSBreadcrumbSeparator,
  DSPagination,
  DSPaginationContent,
  DSPaginationItem,
  DSPaginationLink,
  DSPaginationPrevious,
  DSPaginationNext,
  DSPaginationEllipsis,
  DSCollapsible,
  DSCollapsibleTrigger,
  DSCollapsibleContent,
  DSScrollArea,
  DSContextMenu,
  DSContextMenuTrigger,
  DSContextMenuContent,
  DSContextMenuItem,
  DSContextMenuSeparator,
  DSProgress,
  DSSkeleton,
  DSAlert,
  dsToast,
  MorphSvgDemo,
  FooterBouncDemo,
  FlipFilterDemo,
  ShapeOverlayDemo,
  MorphCurveDemo,
  RollingTextDemo,
  ContainerTextDemo,
} from "@/components/design-system";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
} from "recharts";
import {
  Bell,
  Palette,
  Lock,
  Leaf,
  Droplet,
  Smile,
  Zap,
  Search,
  Plus,
  Moon,
  Heart,
  Activity,
  Home,
  BarChart3,
  Settings,
  User,
  ChevronDown,
  Copy,
  Trash2,
  Share2,
  AlertCircle,
  CheckCircle2,
  AlertTriangle,
  Info,
} from "lucide-react";
import { useScrollReveal } from "@/hooks/use-scroll-reveal";
import { useScrambleNumber } from "@/hooks/use-scramble-number";
import { ScrollDivider } from "@/components/design-system/interactions/scroll-divider";
import { TypingText } from "@/components/design-system/interactions/typing-text";
import { sageConfetti } from "@/components/design-system/interactions/confetti";

/* ── Chart sample data ──────────────────────────────────────────────── */

const chartData = [
  { day: "Mon", steps: 6200, sleep: 7.2 },
  { day: "Tue", steps: 8100, sleep: 6.8 },
  { day: "Wed", steps: 7400, sleep: 7.5 },
  { day: "Thu", steps: 9200, sleep: 8.1 },
  { day: "Fri", steps: 8432, sleep: 7.0 },
  { day: "Sat", steps: 5600, sleep: 8.5 },
  { day: "Sun", steps: 4200, sleep: 9.0 },
];

/* ── Table sample data ──────────────────────────────────────────────── */

const tableData = [
  { metric: "Steps", value: "8,432", change: "+12%", status: "On track" },
  { metric: "Sleep", value: "7h 24m", change: "+8%", status: "Improving" },
  { metric: "Heart Rate", value: "62 bpm", change: "-3%", status: "Optimal" },
  { metric: "Calories", value: "1,840", change: "+5%", status: "On track" },
];

/* ── Scroll-reveal section wrapper ───────────────────────────────────── */

function RevealSection({
  children,
  className,
  stagger = 0.06,
}: {
  children: ReactNode;
  className?: string;
  stagger?: number;
}) {
  const ref = useScrollReveal<HTMLElement>({ stagger });
  return (
    <section ref={ref} className={className}>
      {children}
    </section>
  );
}

/* ── Section helpers ─────────────────────────────────────────────────── */

function SectionTitle({ children }: { children: string }) {
  return (
    <Text variant="display-md" color="sage" pattern="sage">
      {children}
    </Text>
  );
}

function SectionSub({ children }: { children: string }) {
  return (
    <Text variant="body-md" color="secondary" className="mt-2 mb-8 max-w-xl">
      {children}
    </Text>
  );
}

function Label({ children }: { children: string }) {
  return (
    <Text variant="label-sm" color="secondary" className="mb-1">
      {children}
    </Text>
  );
}

/* ── Data ────────────────────────────────────────────────────────────── */

const typographyRows = [
  { variant: "display-lg" as const, sample: "78", meta: "34px / Bold" },
  { variant: "display-md" as const, sample: "Good morning, Alex", meta: "28px / Semibold" },
  { variant: "display-sm" as const, sample: "Health Score", meta: "24px / Semibold" },
  { variant: "title-lg" as const, sample: "Sleep Duration", meta: "20px / Medium" },
  { variant: "title-md" as const, sample: "Morning Briefing", meta: "17px / Medium" },
  { variant: "body-lg" as const, sample: "Your HRV is 18% higher after 7+ hours of sleep.", meta: "16px / Normal" },
  { variant: "body-md" as const, sample: "On nights with deep sleep above 90 minutes, recovery improves.", meta: "14px / Normal" },
  { variant: "body-sm" as const, sample: "Last updated 2 hours ago", meta: "12px / Normal" },
  { variant: "label-lg" as const, sample: "Log Activity", meta: "15px / Semibold" },
  { variant: "label-md" as const, sample: "All  Sleep  Activity  Heart", meta: "13px / Medium" },
  { variant: "label-sm" as const, sample: "BPM  STEPS  KCAL", meta: "11px / Medium" },
];

const categoryColors = [
  { name: "Activity", token: "ds-cat-activity", hex: "#30D158", key: "activity" },
  { name: "Sleep", token: "ds-cat-sleep", hex: "#5E5CE6", key: "sleep" },
  { name: "Heart", token: "ds-cat-heart", hex: "#FF375F", key: "heart" },
  { name: "Nutrition", token: "ds-cat-nutrition", hex: "#FF9F0A", key: "nutrition" },
  { name: "Body", token: "ds-cat-body", hex: "#64D2FF", key: "body" },
  { name: "Vitals", token: "ds-cat-vitals", hex: "#6AC4DC", key: "vitals" },
  { name: "Wellness", token: "ds-cat-wellness", hex: "#BF5AF2", key: "wellness" },
  { name: "Cycle", token: "ds-cat-cycle", hex: "#FF6482", key: "cycle" },
  { name: "Mobility", token: "ds-cat-mobility", hex: "#FFD60A", key: "mobility" },
  { name: "Environment", token: "ds-cat-environment", hex: "#63E6BE", key: "environment" },
];

const spacingScale = [
  { name: "xxs", px: 2 },
  { name: "xs", px: 4 },
  { name: "sm", px: 8 },
  { name: "md", px: 16 },
  { name: "md+", px: 20 },
  { name: "lg", px: 24 },
  { name: "xl", px: 32 },
  { name: "xxl", px: 48 },
];

const radiusScale = [
  { name: "XS", px: 8, token: "rounded-ds-xs" },
  { name: "SM", px: 12, token: "rounded-ds-sm" },
  { name: "MD", px: 16, token: "rounded-ds-md" },
  { name: "LG", px: 20, token: "rounded-ds-lg" },
  { name: "XL", px: 28, token: "rounded-ds-xl" },
  { name: "Pill", px: 100, token: "rounded-ds-pill" },
];

const patternTable = [
  { component: "DSButton (primary)", pattern: "sage", blend: "color-burn" },
  { component: "DSButton (destructive)", pattern: "crimson", blend: "color-burn" },
  { component: "Card (hero)", pattern: "original", blend: "screen" },
  { component: "Card (feature)", pattern: "category color", blend: "screen" },
  { component: "Toggle (on)", pattern: "sage", blend: "color-burn" },
  { component: "DSCheckbox (checked)", pattern: "sage", blend: "color-burn" },
  { component: "DSSlider (fill)", pattern: "sage", blend: "color-burn" },
  { component: "Chip (active)", pattern: "original", blend: "screen" },
  { component: "Avatar (fallback)", pattern: "original", blend: "screen" },
  { component: "DSTabsList", pattern: "original", blend: "screen" },
  { component: "FAB", pattern: "sage", blend: "color-burn" },
];

/* ── Page ────────────────────────────────────────────────────────────── */

export default function BrandBiblePage() {
  /* ── Text animation refs ─────────────────────────────────────── */
  const heroScoreRef = useScrambleNumber<HTMLSpanElement>({ finalValue: "78", duration: 1.2 });
  const stepsRef = useScrambleNumber<HTMLSpanElement>({ finalValue: "8,432", duration: 1.0 });

  /* ── Controlled state for new demos ─────────────────────────── */
  const [calendarDate, setCalendarDate] = useState<Date | undefined>(new Date());
  const [toggleGroupValue, setToggleGroupValue] = useState("day");
  const [commandOpen, setCommandOpen] = useState(false);
  const [collapsibleOpen, setCollapsibleOpen] = useState(false);

  return (
    <main className="max-w-[960px] mx-auto px-6 py-12 pb-24">
      {/* ── 1. Header ──────────────────────────────────────────────── */}
      <header>
        <Text variant="display-lg" color="sage" pattern="sage" as="h1">
          Zuralog Design System
        </Text>
        <Text variant="body-lg" color="secondary" className="mt-3 max-w-2xl">
          A living reference of every design token, component, and pattern.
          Dark canvas, warm typography, topographic texture on every interactive surface.
        </Text>
      </header>

      {/* ── 2. Canvas & Elevation ──────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Canvas &amp; Elevation</SectionTitle>
        <SectionSub>Four surface levels create depth without drop shadows. Every layer lifts content closer to the user.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { name: "Canvas", token: "bg-ds-canvas", hex: "#161618", usage: "Page background" },
            { name: "Surface", token: "bg-ds-surface", hex: "#1E1E20", usage: "Cards, inputs" },
            { name: "Surface Raised", token: "bg-ds-surface-raised", hex: "#272729", usage: "Hover, toggles" },
            { name: "Surface Overlay", token: "bg-ds-surface-overlay", hex: "#313133", usage: "Modals, dialogs" },
          ].map((swatch) => (
            <Card elevation="data" key={swatch.name}>
              <div
                className={`h-20 rounded-ds-sm mb-3 ${swatch.token}`}
                style={swatch.name === "Canvas" ? { border: "1px solid rgba(240,238,233,0.06)" } : undefined}
              />
              <Text variant="label-md" color="primary">{swatch.name}</Text>
              <Text variant="body-sm" color="secondary" className="mt-0.5">{swatch.usage}</Text>
              <Text variant="label-sm" color="secondary" className="mt-1 font-mono">{swatch.hex}</Text>
            </Card>
          ))}
        </div>
      </RevealSection>

      {/* ── 3. Typography ──────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Typography</SectionTitle>
        <SectionSub>Plus Jakarta Sans across all sizes. Metric numbers for health data, warm weight for readability.</SectionSub>

        <Card elevation="standard">
          <div className="flex flex-col gap-5">
            {typographyRows.map((row) => (
              <div key={row.variant} className="flex items-baseline justify-between gap-4 flex-wrap">
                <div className="shrink-0 w-40">
                  <Text variant="label-sm" color="sage">{row.variant}</Text>
                  <Text variant="body-sm" color="secondary">{row.meta}</Text>
                </div>
                <div className="flex-1 min-w-0">
                  <Text variant={row.variant} color="primary">{row.sample}</Text>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </RevealSection>

      {/* ── 3b. Pattern Typography ──────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Pattern Typography</SectionTitle>
        <SectionSub>Bold display text gets a drifting topographic fill. Semibold headings get a static fill. Body text stays solid.</SectionSub>

        <div className="grid gap-6">
          <Card elevation="standard">
            <Label>Bold (animated drift)</Label>
            <Text variant="display-lg" pattern="sage">Health Score: 78</Text>
          </Card>

          <Card elevation="standard">
            <Label>Semibold (static pattern)</Label>
            <Text variant="display-md" pattern="sage">Good morning, Alex</Text>
            <Text variant="display-sm" pattern="sage" className="mt-3">Sleep Duration</Text>
          </Card>

          <Card elevation="standard">
            <Label>Pattern colors</Label>
            <div className="flex flex-col gap-3">
              <Text variant="display-md" pattern="sage">Sage pattern</Text>
              <Text variant="display-md" pattern="crimson">Crimson pattern</Text>
              <Text variant="display-md" pattern="amber">Amber pattern</Text>
              <Text variant="display-md" pattern="original">Original pattern</Text>
            </div>
          </Card>

          <Card elevation="standard">
            <Label>Solid text (no pattern)</Label>
            <Text variant="display-md" color="sage">Solid sage heading</Text>
            <Text variant="body-lg" color="primary" className="mt-2">Body text always stays solid and readable — patterns only appear on display-size headings where the letterforms are large enough to show the texture.</Text>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 4. Accent Colors ───────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Accent Colors</SectionTitle>
        <SectionSub>Two accent colors anchor the entire palette. Sage for actions, Warm White for navigation.</SectionSub>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Card elevation="standard" className="!bg-ds-sage h-32 flex items-end !p-5">
            <PatternOverlay variant="sage" opacity={0.15} blend="color-burn" />
            <div className="relative z-10">
              <Text variant="title-md" color="on-sage">Sage</Text>
              <Text variant="body-sm" color="on-sage" className="opacity-70">
                #CFE1B9 — Primary actions, buttons, toggles, links
              </Text>
            </div>
          </Card>
          <Card elevation="standard" className="!bg-ds-warm-white h-32 flex items-end !p-5">
            <div className="relative z-10">
              <Text variant="title-md" color="on-warm-white">Warm White</Text>
              <Text variant="body-sm" color="on-warm-white" className="opacity-70">
                #F0EEE9 — Navigation, tabs, segmented controls
              </Text>
            </div>
          </Card>
        </div>
      </RevealSection>

      {/* ── 5. Text Colors ─────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Text Colors</SectionTitle>
        <SectionSub>Four text roles mapped to surface context. Always use the right pairing for contrast.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { name: "Text Primary", color: "text-ds-text-primary", bg: "!bg-ds-surface", hex: "#F0EEE9" },
            { name: "Text Secondary", color: "text-ds-text-secondary", bg: "!bg-ds-surface", hex: "#9B9894" },
            { name: "On Sage", color: "text-ds-text-on-sage", bg: "!bg-ds-sage", hex: "#1A2E22" },
            { name: "On Warm White", color: "text-ds-text-on-warm-white", bg: "!bg-ds-warm-white", hex: "#161618" },
          ].map((item) => (
            <Card key={item.name} elevation="data" className={item.bg}>
              <span className={`${item.color} font-jakarta text-[1rem] font-medium block`}>Aa</span>
              <Text variant="label-sm" color="secondary" className="mt-2">{item.name}</Text>
              <Text variant="label-sm" color="secondary" className="font-mono">{item.hex}</Text>
            </Card>
          ))}
        </div>
      </RevealSection>

      {/* ── 6. Health Category Colors ──────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Health Categories</SectionTitle>
        <SectionSub>Ten distinct hues, one per health domain. Each category gets its own pattern tint on feature cards.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-8">
          {categoryColors.map((cat) => (
            <Card key={cat.key} elevation="data" className="flex items-center gap-3">
              <div
                className="w-8 h-8 rounded-full shrink-0"
                style={{ backgroundColor: cat.hex }}
              />
              <div className="min-w-0">
                <Text variant="label-sm" color="primary">{cat.name}</Text>
                <Text variant="label-sm" color="secondary" className="font-mono">{cat.hex}</Text>
              </div>
            </Card>
          ))}
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {(
            [
              { category: "sleep" as const, icon: <Moon size={20} />, title: "Sleep", metric: "7h 42m", sub: "Deep 1h 18m" },
              { category: "heart" as const, icon: <Heart size={20} />, title: "Heart Rate", metric: "62 bpm", sub: "Resting average" },
              { category: "activity" as const, icon: <Activity size={20} />, title: "Activity", metric: "8,432", sub: "Steps today" },
              { category: "nutrition" as const, icon: <Droplet size={20} />, title: "Nutrition", metric: "1,840", sub: "Calories logged" },
              { category: "wellness" as const, icon: <Smile size={20} />, title: "Wellness", metric: "8/10", sub: "Mood score" },
              { category: "body" as const, icon: <Zap size={20} />, title: "Body", metric: "72.4 kg", sub: "This morning" },
            ]
          ).map((card) => (
            <Card elevation="feature" category={card.category} key={card.category}>
              <div className="flex items-center gap-2 mb-2 text-ds-text-secondary">
                {card.icon}
                <Text variant="label-md" color="secondary">{card.title}</Text>
              </div>
              <Text variant="display-sm" color="primary">{card.metric}</Text>
              <Text variant="body-sm" color="secondary" className="mt-0.5">{card.sub}</Text>
            </Card>
          ))}
        </div>
      </RevealSection>

      {/* ── 7. Semantic / Status Colors ────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Status Colors</SectionTitle>
        <SectionSub>Semantic signals for success, warning, error, and sync states.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { name: "Success", hex: "#34C759", pattern: "sage" },
            { name: "Warning", hex: "#FF9500", pattern: "amber" },
            { name: "Error", hex: "#FF3B30", pattern: "crimson" },
            { name: "Syncing", hex: "#007AFF", pattern: "sky-blue" },
          ].map((status) => (
            <div key={status.name} className="flex items-center gap-3">
              <div
                className="w-4 h-4 rounded-full ds-pattern-drift"
                style={{ backgroundImage: `url('/patterns/${status.pattern}.png')` }}
              />
              <div>
                <Text variant="label-md" color="primary">{status.name}</Text>
                <Text variant="label-sm" color="secondary" className="font-mono">{status.hex}</Text>
              </div>
            </div>
          ))}
        </div>
      </RevealSection>

      {/* ── 8. Spacing ─────────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Spacing</SectionTitle>
        <SectionSub>Consistent spacing tokens from 2px to 48px. Every margin and padding uses this scale.</SectionSub>

        <Card elevation="standard">
          <div className="flex flex-col gap-3">
            {spacingScale.map((s) => (
              <div key={s.name} className="flex items-center gap-4">
                <Text variant="label-sm" color="secondary" className="w-8 text-right font-mono">{s.px}</Text>
                <div
                  className="h-3 rounded-full bg-ds-sage/30"
                  style={{ width: `${Math.max(s.px * 3, 6)}px` }}
                />
                <Text variant="label-sm" color="primary">{s.name}</Text>
              </div>
            ))}
          </div>
        </Card>
      </RevealSection>

      {/* ── 9. Shape (Border Radius) ───────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Shape</SectionTitle>
        <SectionSub>Six radius tokens from sharp to pill. Cards use LG, buttons use Pill, inputs use SM.</SectionSub>

        <div className="flex flex-wrap gap-4">
          {radiusScale.map((r) => (
            <div key={r.name} className="flex flex-col items-center gap-2">
              <div
                className="w-16 h-16 bg-ds-surface-raised border border-[rgba(240,238,233,0.06)]"
                style={{ borderRadius: `${r.px}px` }}
              />
              <Text variant="label-sm" color="primary">{r.name}</Text>
              <Text variant="label-sm" color="secondary" className="font-mono">{r.px}px</Text>
            </div>
          ))}
        </div>
      </RevealSection>

      {/* ── 10. Buttons ────────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Buttons</SectionTitle>
        <SectionSub>Four intents, three sizes. Primary and destructive get the topographic pattern overlay.</SectionSub>

        <Card elevation="standard">
          <Label>Intents</Label>
          <div className="flex flex-wrap items-center gap-3 mb-6">
            <DSButton intent="primary">Primary</DSButton>
            <DSButton intent="destructive">Destructive</DSButton>
            <DSButton intent="secondary">Secondary</DSButton>
            <DSButton intent="text">Text Button &rarr;</DSButton>
          </div>

          <Label>Sizes (primary)</Label>
          <div className="flex flex-wrap items-center gap-3 mb-6">
            <DSButton intent="primary" size="lg">Large</DSButton>
            <DSButton intent="primary" size="md">Medium</DSButton>
            <DSButton intent="primary" size="sm">Small</DSButton>
          </div>

          <Label>With icons</Label>
          <div className="flex flex-wrap items-center gap-3 mb-6">
            <DSButton intent="primary" leftIcon={<Plus size={16} />}>Add Entry</DSButton>
            <DSButton intent="secondary" leftIcon={<Search size={16} />}>Search</DSButton>
          </div>

          <Label>States</Label>
          <div className="flex flex-wrap items-center gap-3">
            <DSButton intent="primary" disabled>Disabled</DSButton>
            <DSButton intent="primary" loading>Loading</DSButton>
            <DSButton intent="destructive" disabled>Disabled</DSButton>
          </div>
        </Card>
      </RevealSection>

      <ScrollDivider />

      {/* ── 11. Cards ──────────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Cards</SectionTitle>
        <SectionSub>Three elevation levels plus category feature cards. Hero and feature cards get pattern overlays.</SectionSub>

        <div className="grid gap-4">
          <Card elevation="hero">
            <Text variant="body-sm" color="secondary">Health Score</Text>
            <Text ref={heroScoreRef} variant="display-lg" color="sage" pattern="sage" className="mt-1">78</Text>
            <Text variant="body-md" color="secondary" className="mt-1">
              Your overall health is trending up this week.
            </Text>
          </Card>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Card elevation="feature">
              <div className="flex items-center gap-2 mb-2">
                <Leaf size={16} className="text-ds-sage" />
                <Text variant="label-md" color="sage">AI Insight</Text>
              </div>
              <Text variant="body-md" color="primary">
                <TypingText
                  text="Your HRV is 18% higher on nights with 7+ hours of sleep. Try a consistent 10:30pm bedtime."
                  speed={25}
                />
              </Text>
            </Card>

            <Card elevation="data">
              <Text variant="label-md" color="secondary">Steps</Text>
              <Text ref={stepsRef} variant="display-md" color="primary" className="mt-1">8,432</Text>
              <Text variant="body-sm" color="secondary" className="mt-0.5">67% of daily goal</Text>
            </Card>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <Card elevation="feature" category="sleep">
              <Text variant="label-md" color="secondary">Sleep</Text>
              <Text variant="title-lg" color="primary" className="mt-1">7h 42m</Text>
            </Card>
            <Card elevation="feature" category="heart">
              <Text variant="label-md" color="secondary">Heart</Text>
              <Text variant="title-lg" color="primary" className="mt-1">62 bpm</Text>
            </Card>
            <Card elevation="feature" category="activity">
              <Text variant="label-md" color="secondary">Activity</Text>
              <Text variant="title-lg" color="primary" className="mt-1">8,432</Text>
            </Card>
          </div>
        </div>
      </RevealSection>

      {/* ── 12. Inputs & Selection ─────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Inputs &amp; Selection</SectionTitle>
        <SectionSub>Every form control uses the surface-raised palette with sage accents on interaction.</SectionSub>

        <div className="grid gap-6">
          {/* Text field */}
          <Card elevation="standard">
            <Label>Text Field</Label>
            <div className="max-w-xs">
              <TextField label="Display Name" defaultValue="Alex Johnson" />
            </div>
            <div className="max-w-xs mt-4">
              <TextField label="Email" placeholder="alex@example.com" />
            </div>
            <div className="max-w-xs mt-4">
              <TextField label="With Error" defaultValue="bad input" error="This field is required." />
            </div>
          </Card>

          {/* Toggles */}
          <Card elevation="standard">
            <Label>Toggle</Label>
            <div className="flex flex-col gap-4">
              <Toggle label="Morning Briefing" defaultChecked />
              <Toggle label="Smart Reminders" />
              <Toggle label="Disabled" disabled defaultChecked />
            </div>
          </Card>

          {/* Checkboxes */}
          <Card elevation="standard">
            <Label>Checkbox</Label>
            <div className="flex flex-wrap gap-6">
              <DSCheckbox label="Checked" defaultChecked />
              <DSCheckbox label="Unchecked" />
              <DSCheckbox label="Disabled" disabled defaultChecked />
            </div>
          </Card>

          {/* Slider */}
          <Card elevation="standard">
            <Label>Slider</Label>
            <div className="max-w-sm">
              <div className="flex justify-between mb-2">
                <Text variant="body-sm" color="secondary">Target sleep</Text>
                <Text variant="body-sm" color="sage">6.5h</Text>
              </div>
              <DSSlider defaultValue={[65]} />
            </div>
          </Card>

          {/* Radio group */}
          <Card elevation="standard">
            <Label>Radio Group</Label>
            <DSRadioGroup defaultValue="balanced">
              <RadioItem value="aggressive" label="Aggressive" />
              <RadioItem value="balanced" label="Balanced" />
              <RadioItem value="conservative" label="Conservative" />
            </DSRadioGroup>
          </Card>

          {/* Tabs */}
          <Card elevation="standard">
            <Label>Segmented Control (Tabs)</Label>
            <DSTabs defaultValue="all">
              <DSTabsList>
                <DSTabsTrigger value="all">All</DSTabsTrigger>
                <DSTabsTrigger value="sleep">Sleep</DSTabsTrigger>
                <DSTabsTrigger value="activity">Activity</DSTabsTrigger>
                <DSTabsTrigger value="heart">Heart</DSTabsTrigger>
              </DSTabsList>
              <DSTabsContent value="all">
                <Text variant="body-md" color="secondary">Showing all health data categories.</Text>
              </DSTabsContent>
              <DSTabsContent value="sleep">
                <Text variant="body-md" color="secondary">Sleep metrics and trends.</Text>
              </DSTabsContent>
              <DSTabsContent value="activity">
                <Text variant="body-md" color="secondary">Activity and exercise data.</Text>
              </DSTabsContent>
              <DSTabsContent value="heart">
                <Text variant="body-md" color="secondary">Heart rate and HRV readings.</Text>
              </DSTabsContent>
            </DSTabs>
          </Card>

          {/* Chips */}
          <Card elevation="standard">
            <Label>Chips</Label>
            <div className="flex flex-wrap gap-2">
              <Chip active>All</Chip>
              <Chip>Sleep</Chip>
              <Chip>Activity</Chip>
              <Chip>Heart</Chip>
              <Chip>Nutrition</Chip>
            </div>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 13. Feedback ───────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Feedback</SectionTitle>
        <SectionSub>Toasts, dialogs, badges, tooltips, and loading states give the user clear signals.</SectionSub>

        <div className="grid gap-6">
          {/* Toast mockups (inline — no toast component yet) */}
          <Card elevation="standard">
            <Label>Toast Mockups</Label>
            <div className="flex flex-col gap-3 max-w-sm">
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div
                  className="w-2 h-2 rounded-full ds-pattern-drift shrink-0"
                  style={{ backgroundImage: "url('/patterns/sage.png')" }}
                />
                <Text variant="body-sm" color="primary">Activity logged successfully.</Text>
              </div>
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div
                  className="w-2 h-2 rounded-full ds-pattern-drift shrink-0"
                  style={{ backgroundImage: "url('/patterns/crimson.png')" }}
                />
                <Text variant="body-sm" color="primary">Failed to sync. Tap to retry.</Text>
              </div>
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div
                  className="w-2 h-2 rounded-full ds-pattern-drift shrink-0"
                  style={{ backgroundImage: "url('/patterns/amber.png')" }}
                />
                <Text variant="body-sm" color="primary">Health data permissions required.</Text>
              </div>
            </div>
          </Card>

          {/* Dialog */}
          <Card elevation="standard">
            <Label>Dialog</Label>
            <div className="mt-3">
            <DSDialog>
              <DSDialogTrigger>
                <DSButton intent="destructive" size="sm">Delete Entry</DSButton>
              </DSDialogTrigger>
              <DSDialogContent>
                <DSDialogTitle>Delete this entry?</DSDialogTitle>
                <DSDialogDescription className="mt-2">
                  This action cannot be undone. The entry and all its data will be permanently removed.
                </DSDialogDescription>
                <div className="flex justify-end gap-3 mt-6">
                  <DSDialogClose>
                    <DSButton intent="secondary" size="sm">Cancel</DSButton>
                  </DSDialogClose>
                  <DSDialogClose>
                    <DSButton intent="destructive" size="sm">Delete</DSButton>
                  </DSDialogClose>
                </div>
              </DSDialogContent>
            </DSDialog>
            </div>
          </Card>

          {/* Badges */}
          <Card elevation="standard">
            <Label>Badges</Label>
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex items-center gap-2">
                <Badge variant="error">3</Badge>
                <Text variant="body-sm" color="secondary">Error / notification count</Text>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="sage">New</Badge>
                <Text variant="body-sm" color="secondary">New feature / label</Text>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant="neutral">12</Badge>
                <Text variant="body-sm" color="secondary">Neutral count</Text>
              </div>
            </div>
          </Card>

          {/* Tooltip */}
          <Card elevation="standard">
            <Label>Tooltip</Label>
            <div className="mt-3">
            <DSTooltip>
              <DSTooltipTrigger>
                <DSButton intent="secondary" size="sm">Hover me</DSButton>
              </DSTooltipTrigger>
              <DSTooltipContent>
                This is a tooltip with helpful context.
              </DSTooltipContent>
            </DSTooltip>
            </div>
          </Card>

          {/* Skeleton loader (inline — no component) */}
          <Card elevation="standard">
            <Label>Skeleton Loader</Label>
            <div className="flex flex-col gap-3 max-w-xs">
              <div className="h-5 w-24 bg-ds-surface-raised rounded-ds-sm animate-pulse" />
              <div className="h-8 w-40 bg-ds-surface-raised rounded-ds-sm animate-pulse" />
              <div className="h-4 w-32 bg-ds-surface-raised rounded-ds-sm animate-pulse" />
            </div>
          </Card>

          {/* Progress bar (inline — no component) */}
          <Card elevation="standard">
            <Label>Progress Bar</Label>
            <div className="max-w-sm">
              <div className="flex justify-between mb-1.5">
                <Text variant="body-sm" color="secondary">Daily goal</Text>
                <Text variant="body-sm" color="sage">67%</Text>
              </div>
              <div className="h-2 bg-ds-surface-raised rounded-full overflow-hidden">
                <div
                  className="relative h-full w-[67%] bg-ds-sage rounded-full overflow-hidden ds-pattern-drift"
                  style={{ backgroundImage: "url('/patterns/sage.png')" }}
                />
              </div>
            </div>
          </Card>
        </div>
      </RevealSection>

      {/* ── 14. Display Components ─────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Display Components</SectionTitle>
        <SectionSub>List items, avatars, dividers, and accordions for structuring content.</SectionSub>

        <div className="grid gap-6">
          {/* List items */}
          <Card elevation="standard">
            <Label>List Items</Label>
            <div className="flex flex-col">
              {[
                { icon: <Bell size={20} />, title: "Notifications", sub: "Push, email, in-app" },
                { icon: <Palette size={20} />, title: "Appearance", sub: "Theme, display settings" },
                { icon: <Lock size={20} />, title: "Privacy", sub: "Data sharing, permissions" },
              ].map((item, i) => (
                <div key={item.title}>
                  <div className="flex items-center gap-4 py-3">
                    <div className="relative overflow-hidden w-9 h-9 rounded-ds-sm bg-ds-surface-raised flex items-center justify-center shrink-0">
                      <PatternOverlay variant="original" opacity={0.12} blend="screen" />
                      <span className="relative z-10 text-ds-sage">{item.icon}</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <Text variant="body-md" color="primary">{item.title}</Text>
                      <Text variant="body-sm" color="secondary">{item.sub}</Text>
                    </div>
                  </div>
                  {i < 2 && <Divider />}
                </div>
              ))}
            </div>
          </Card>

          {/* Avatars */}
          <Card elevation="standard">
            <Label>Avatars</Label>
            <div className="flex items-center gap-4">
              <Avatar initials="AJ" size="lg" />
              <Avatar initials="AJ" size="md" />
              <Avatar initials="AJ" size="sm" />
            </div>
          </Card>

          {/* Divider */}
          <Card elevation="standard">
            <Label>Divider</Label>
            <Text variant="body-sm" color="secondary" className="mb-3">Content above</Text>
            <Divider />
            <Text variant="body-sm" color="secondary" className="mt-3">Content below</Text>
            <div className="mt-4">
              <Text variant="body-sm" color="secondary" className="mb-3">With inset</Text>
              <Divider inset />
              <Text variant="body-sm" color="secondary" className="mt-3">Indented for list contexts</Text>
            </div>
          </Card>

          {/* Accordion */}
          <Card elevation="standard">
            <Label>Accordion</Label>
            <DSAccordion>
              <DSAccordionItem value="sleep-details">
                <DSAccordionTrigger>Sleep Details</DSAccordionTrigger>
                <DSAccordionContent>
                  <div className="flex flex-col gap-2">
                    <div className="flex justify-between">
                      <Text variant="body-sm" color="secondary">Deep Sleep</Text>
                      <Text variant="body-sm" color="primary">1h 18m</Text>
                    </div>
                    <div className="flex justify-between">
                      <Text variant="body-sm" color="secondary">REM Sleep</Text>
                      <Text variant="body-sm" color="primary">2h 05m</Text>
                    </div>
                    <div className="flex justify-between">
                      <Text variant="body-sm" color="secondary">Light Sleep</Text>
                      <Text variant="body-sm" color="primary">4h 19m</Text>
                    </div>
                  </div>
                </DSAccordionContent>
              </DSAccordionItem>
              <DSAccordionItem value="hrv-details">
                <DSAccordionTrigger>HRV Trends</DSAccordionTrigger>
                <DSAccordionContent>
                  <Text variant="body-sm" color="secondary">
                    Your heart rate variability averaged 48ms this week, up 12% from last week.
                  </Text>
                </DSAccordionContent>
              </DSAccordionItem>
            </DSAccordion>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 15. Data Visualization ──────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Data Visualization</SectionTitle>
        <SectionSub>Charts and graphs styled for the dark canvas, using the Zuralog color palette.</SectionSub>

        <Card elevation="standard">
          <Label>Weekly Steps — Area Chart</Label>
          <DSChartContainer className="mt-3">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
                <defs>
                  <linearGradient id="stepsGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={CHART_COLORS.sage} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={CHART_COLORS.sage} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke={DS_CHART_THEME.gridColor} />
                <XAxis
                  dataKey="day"
                  tick={{ fill: DS_CHART_THEME.textColor, fontSize: DS_CHART_THEME.fontSize }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: DS_CHART_THEME.textColor, fontSize: DS_CHART_THEME.fontSize }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip content={<DSChartTooltip valueFormatter={(v) => `${v.toLocaleString()} steps`} />} />
                <Area
                  type="monotone"
                  dataKey="steps"
                  stroke={CHART_COLORS.sage}
                  strokeWidth={2}
                  fill="url(#stepsGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </DSChartContainer>
        </Card>
      </RevealSection>

      <ScrollDivider />

      {/* ── 16. Tables ──────────────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Tables</SectionTitle>
        <SectionSub>Structured data presented in the dark-canvas table style with hover states.</SectionSub>

        <Card elevation="standard">
          <Label>Health Summary</Label>
          <div className="mt-3">
            <DSTable>
              <DSTableHeader>
                <DSTableRow>
                  <DSTableHead>Metric</DSTableHead>
                  <DSTableHead>Value</DSTableHead>
                  <DSTableHead>Change</DSTableHead>
                  <DSTableHead>Status</DSTableHead>
                </DSTableRow>
              </DSTableHeader>
              <DSTableBody>
                {tableData.map((row) => (
                  <DSTableRow key={row.metric}>
                    <DSTableCell className="font-medium">{row.metric}</DSTableCell>
                    <DSTableCell>{row.value}</DSTableCell>
                    <DSTableCell>
                      <span className={row.change.startsWith("+") ? "text-ds-success" : "text-ds-error"}>
                        {row.change}
                      </span>
                    </DSTableCell>
                    <DSTableCell>{row.status}</DSTableCell>
                  </DSTableRow>
                ))}
              </DSTableBody>
            </DSTable>
          </div>
        </Card>
      </RevealSection>

      <ScrollDivider />

      {/* ── 17. Advanced Inputs ─────────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Advanced Inputs</SectionTitle>
        <SectionSub>Dropdowns, text areas, toggle groups, calendars, and one-time-password fields.</SectionSub>

        <div className="grid gap-6 md:grid-cols-2">
          {/* Select */}
          <Card elevation="standard">
            <Label>Select</Label>
            <DSSelect>
              <DSSelectTrigger className="mt-2">
                <DSSelectValue placeholder="Choose time range" />
              </DSSelectTrigger>
              <DSSelectContent>
                <DSSelectItem value="daily">Daily</DSSelectItem>
                <DSSelectItem value="weekly">Weekly</DSSelectItem>
                <DSSelectItem value="monthly">Monthly</DSSelectItem>
                <DSSelectItem value="yearly">Yearly</DSSelectItem>
              </DSSelectContent>
            </DSSelect>
          </Card>

          {/* Textarea */}
          <Card elevation="standard">
            <Label>Textarea</Label>
            <DSTextarea
              className="mt-2"
              placeholder="How are you feeling today? Log a note about your workout, sleep, or mood..."
              rows={3}
            />
          </Card>

          {/* Toggle Group */}
          <Card elevation="standard">
            <Label>Toggle Group</Label>
            <div className="mt-2">
              <DSToggleGroup
                value={toggleGroupValue}
                onValueChange={setToggleGroupValue}
                items={[
                  { value: "day", label: "Day" },
                  { value: "week", label: "Week" },
                  { value: "month", label: "Month" },
                ]}
              />
            </div>
          </Card>

          {/* Input OTP */}
          <Card elevation="standard">
            <Label>One-Time Password</Label>
            <div className="mt-2">
              <DSInputOTP maxLength={6}>
                <DSInputOTPGroup>
                  <DSInputOTPSlot index={0} />
                  <DSInputOTPSlot index={1} />
                  <DSInputOTPSlot index={2} />
                </DSInputOTPGroup>
                <DSInputOTPSeparator />
                <DSInputOTPGroup>
                  <DSInputOTPSlot index={3} />
                  <DSInputOTPSlot index={4} />
                  <DSInputOTPSlot index={5} />
                </DSInputOTPGroup>
              </DSInputOTP>
            </div>
          </Card>

          {/* Calendar */}
          <Card elevation="standard" className="md:col-span-2">
            <Label>Calendar</Label>
            <div className="mt-2 flex justify-center">
              <DSCalendar
                mode="single"
                selected={calendarDate}
                onSelect={setCalendarDate}
              />
            </div>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 18. Overlays & Panels ──────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Overlays &amp; Panels</SectionTitle>
        <SectionSub>Sheets, popovers, hover cards, and command palettes that float above the canvas.</SectionSub>

        <div className="grid gap-6 md:grid-cols-2">
          {/* Sheet */}
          <Card elevation="standard">
            <Label>Sheet (Bottom Panel)</Label>
            <div className="mt-2">
              <DSSheet>
                <DSSheetTrigger className="inline-flex items-center justify-center rounded-ds-sm bg-ds-surface-raised px-4 py-2 text-sm font-medium text-ds-text-primary hover:bg-ds-surface-overlay transition-colors">
                  Open Sheet
                </DSSheetTrigger>
                <DSSheetContent side="bottom">
                  <DSSheetHeader>
                    <DSSheetTitle>Log Activity</DSSheetTitle>
                    <DSSheetDescription>
                      Choose an activity type and enter your details below.
                    </DSSheetDescription>
                  </DSSheetHeader>
                  <div className="py-6 px-4">
                    <Text variant="body-md" color="secondary">
                      This panel slides up from the bottom, perfect for mobile-friendly forms
                      and quick actions.
                    </Text>
                  </div>
                </DSSheetContent>
              </DSSheet>
            </div>
          </Card>

          {/* Popover */}
          <Card elevation="standard">
            <Label>Popover</Label>
            <div className="mt-2">
              <DSPopover>
                <DSPopoverTrigger className="inline-flex items-center justify-center rounded-ds-sm bg-ds-surface-raised px-4 py-2 text-sm font-medium text-ds-text-primary hover:bg-ds-surface-overlay transition-colors">
                  Show Popover
                </DSPopoverTrigger>
                <DSPopoverContent className="w-72">
                  <div className="flex flex-col gap-2">
                    <Text variant="title-md" color="primary">Quick Stats</Text>
                    <Text variant="body-sm" color="secondary">
                      You have walked 8,432 steps today — that is 84% of your daily goal.
                    </Text>
                  </div>
                </DSPopoverContent>
              </DSPopover>
            </div>
          </Card>

          {/* Hover Card */}
          <Card elevation="standard">
            <Label>Hover Card</Label>
            <div className="mt-2">
              <DSHoverCard>
                <DSHoverCardTrigger className="text-ds-sage underline underline-offset-4 cursor-pointer text-sm font-medium">
                  @zuralog
                </DSHoverCardTrigger>
                <DSHoverCardContent className="w-72">
                  <div className="flex items-center gap-3">
                    <Avatar initials="ZL" size="md" />
                    <div>
                      <Text variant="body-md" color="primary">Zuralog</Text>
                      <Text variant="body-sm" color="secondary">Your personal health hub</Text>
                    </div>
                  </div>
                  <Text variant="body-sm" color="secondary" className="mt-2">
                    Bringing together data from all your devices into one clear picture of your well-being.
                  </Text>
                </DSHoverCardContent>
              </DSHoverCard>
            </div>
          </Card>

          {/* Command Palette */}
          <Card elevation="standard">
            <Label>Command Palette</Label>
            <div className="mt-2">
              <DSButton intent="secondary" size="sm" onClick={() => setCommandOpen(true)}>
                Open Command Palette
              </DSButton>
              <DSDialog open={commandOpen} onOpenChange={setCommandOpen}>
                <DSDialogContent className="!p-0 !max-w-lg overflow-hidden">
                  <DSCommand>
                    <DSCommandInput placeholder="Search actions..." />
                    <DSCommandList>
                      <DSCommandEmpty>No results found.</DSCommandEmpty>
                      <DSCommandGroup heading="Actions">
                        <DSCommandItem>
                          <Activity className="mr-2 h-4 w-4" /> Log Activity
                        </DSCommandItem>
                        <DSCommandItem>
                          <Heart className="mr-2 h-4 w-4" /> Check Heart Rate
                        </DSCommandItem>
                        <DSCommandItem>
                          <Moon className="mr-2 h-4 w-4" /> Sleep Summary
                        </DSCommandItem>
                      </DSCommandGroup>
                      <DSCommandGroup heading="Navigation">
                        <DSCommandItem>
                          <Home className="mr-2 h-4 w-4" /> Dashboard
                        </DSCommandItem>
                        <DSCommandItem>
                          <Settings className="mr-2 h-4 w-4" /> Settings
                        </DSCommandItem>
                      </DSCommandGroup>
                    </DSCommandList>
                  </DSCommand>
                </DSDialogContent>
              </DSDialog>
            </div>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 19. Navigation & Structure ─────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Navigation &amp; Structure</SectionTitle>
        <SectionSub>Breadcrumbs, pagination, collapsible sections, scroll areas, and context menus for organizing content.</SectionSub>

        <div className="grid gap-6">
          {/* Breadcrumb */}
          <Card elevation="standard">
            <Label>Breadcrumb</Label>
            <div className="mt-2">
              <DSBreadcrumb>
                <DSBreadcrumbList>
                  <DSBreadcrumbItem>
                    <DSBreadcrumbLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>Home</DSBreadcrumbLink>
                  </DSBreadcrumbItem>
                  <DSBreadcrumbSeparator />
                  <DSBreadcrumbItem>
                    <DSBreadcrumbLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>Health</DSBreadcrumbLink>
                  </DSBreadcrumbItem>
                  <DSBreadcrumbSeparator />
                  <DSBreadcrumbItem>
                    <DSBreadcrumbLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>Sleep</DSBreadcrumbLink>
                  </DSBreadcrumbItem>
                  <DSBreadcrumbSeparator />
                  <DSBreadcrumbItem>
                    <DSBreadcrumbPage>Details</DSBreadcrumbPage>
                  </DSBreadcrumbItem>
                </DSBreadcrumbList>
              </DSBreadcrumb>
            </div>
          </Card>

          {/* Pagination */}
          <Card elevation="standard">
            <Label>Pagination</Label>
            <div className="mt-2">
              <DSPagination>
                <DSPaginationContent>
                  <DSPaginationItem>
                    <DSPaginationPrevious href="" onClick={(e: React.MouseEvent) => e.preventDefault()} />
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationLink href="" isActive onClick={(e: React.MouseEvent) => e.preventDefault()}>1</DSPaginationLink>
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>2</DSPaginationLink>
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>3</DSPaginationLink>
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationEllipsis />
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationLink href="" onClick={(e: React.MouseEvent) => e.preventDefault()}>10</DSPaginationLink>
                  </DSPaginationItem>
                  <DSPaginationItem>
                    <DSPaginationNext href="" onClick={(e: React.MouseEvent) => e.preventDefault()} />
                  </DSPaginationItem>
                </DSPaginationContent>
              </DSPagination>
            </div>
          </Card>

          {/* Collapsible */}
          <Card elevation="standard">
            <Label>Collapsible</Label>
            <div className="mt-2">
              <DSCollapsible open={collapsibleOpen} onOpenChange={setCollapsibleOpen}>
                <DSCollapsibleTrigger className="inline-flex items-center justify-center rounded-ds-sm bg-ds-surface-raised px-4 py-2 text-sm font-medium text-ds-text-primary hover:bg-ds-surface-overlay transition-colors">
                  <ChevronDown className={`h-4 w-4 mr-1 transition-transform ${collapsibleOpen ? "rotate-180" : ""}`} />
                  {collapsibleOpen ? "Hide" : "Show"} weekly breakdown
                </DSCollapsibleTrigger>
                <DSCollapsibleContent>
                  <div className="mt-3 flex flex-col gap-2 pl-1">
                    {["Monday: 6,200 steps", "Tuesday: 8,100 steps", "Wednesday: 7,400 steps", "Thursday: 9,200 steps"].map((day) => (
                      <Text key={day} variant="body-sm" color="secondary">{day}</Text>
                    ))}
                  </div>
                </DSCollapsibleContent>
              </DSCollapsible>
            </div>
          </Card>

          {/* Scroll Area */}
          <Card elevation="standard">
            <Label>Scroll Area</Label>
            <DSScrollArea className="h-40 mt-2 rounded-ds-sm bg-ds-surface p-3">
              <div className="flex flex-col gap-2">
                {[
                  "Morning walk — 2,400 steps",
                  "Yoga session — 45 min",
                  "Lunch break walk — 1,800 steps",
                  "Afternoon cycling — 30 min",
                  "Evening run — 3,200 steps",
                  "Stretching — 15 min",
                  "Post-dinner walk — 1,500 steps",
                  "Meditation — 10 min",
                  "Sleep logged — 7h 24m",
                  "Water intake — 2.4L",
                ].map((item) => (
                  <div key={item} className="flex items-center gap-2 py-1 border-b border-[rgba(240,238,233,0.04)] last:border-0">
                    <Activity size={14} className="text-ds-sage shrink-0" />
                    <Text variant="body-sm" color="primary">{item}</Text>
                  </div>
                ))}
              </div>
            </DSScrollArea>
          </Card>

          {/* Context Menu */}
          <Card elevation="standard">
            <Label>Context Menu</Label>
            <div className="mt-2">
              <DSContextMenu>
                <DSContextMenuTrigger>
                  <div className="flex items-center justify-center h-24 rounded-ds-sm border border-dashed border-[rgba(240,238,233,0.12)] bg-ds-surface">
                    <Text variant="body-sm" color="secondary">Right-click here</Text>
                  </div>
                </DSContextMenuTrigger>
                <DSContextMenuContent>
                  <DSContextMenuItem>
                    <Copy className="mr-2 h-4 w-4" /> Copy Data
                  </DSContextMenuItem>
                  <DSContextMenuItem>
                    <Share2 className="mr-2 h-4 w-4" /> Share Summary
                  </DSContextMenuItem>
                  <DSContextMenuSeparator />
                  <DSContextMenuItem className="text-ds-error [&_svg]:!text-ds-error focus:!text-ds-error focus:[&_svg]:!text-ds-error focus:!bg-[rgba(255,59,48,0.08)]">
                    <Trash2 className="mr-2 h-4 w-4" /> Delete Entry
                  </DSContextMenuItem>
                </DSContextMenuContent>
              </DSContextMenu>
            </div>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 20. Loading & Feedback ─────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Loading &amp; Feedback</SectionTitle>
        <SectionSub>Progress indicators, loading skeletons, alert banners, and toast notifications.</SectionSub>

        <div className="grid gap-6">
          {/* Progress bars */}
          <Card elevation="standard">
            <Label>Progress</Label>
            <div className="mt-2 flex flex-col gap-4">
              <DSProgress value={25} label="Steps Goal" showValue />
              <DSProgress value={67} label="Sleep Target" showValue />
              <DSProgress value={100} label="Water Intake" showValue />
            </div>
          </Card>

          {/* Skeleton */}
          <Card elevation="standard">
            <Label>Skeleton (Loading State)</Label>
            <div className="mt-2 flex flex-col gap-3">
              <div className="flex items-center gap-3">
                <DSSkeleton width="40px" height="40px" className="rounded-full" />
                <div className="flex-1 flex flex-col gap-2">
                  <DSSkeleton width="60%" height="14px" />
                  <DSSkeleton width="40%" height="12px" />
                </div>
              </div>
              <DSSkeleton width="100%" height="120px" />
              <div className="flex gap-3">
                <DSSkeleton width="33%" height="32px" />
                <DSSkeleton width="33%" height="32px" />
                <DSSkeleton width="33%" height="32px" />
              </div>
            </div>
          </Card>

          {/* Alerts */}
          <Card elevation="standard">
            <Label>Alerts</Label>
            <div className="mt-2 flex flex-col gap-3">
              <DSAlert
                variant="default"
                icon={<Info size={18} className="text-ds-text-secondary" />}
                title="Sync in progress"
                description="Your health data is being updated from connected devices."
              />
              <DSAlert
                variant="success"
                icon={<CheckCircle2 size={18} className="text-ds-success" />}
                title="Goal reached!"
                description="You hit your 10,000 steps target for today."
              />
              <DSAlert
                variant="warning"
                icon={<AlertTriangle size={18} className="text-ds-warning" />}
                title="Low battery"
                description="Your connected watch is below 15% — charge it to keep syncing."
              />
              <DSAlert
                variant="error"
                icon={<AlertCircle size={18} className="text-ds-error" />}
                title="Sync failed"
                description="Could not reach your Fitbit account. Check your connection and try again."
              />
            </div>
          </Card>

          {/* Toast */}
          <Card elevation="standard">
            <Label>Toast Notification</Label>
            <div className="mt-2">
              <DSButton
                intent="primary"
                size="sm"
                onClick={() => dsToast.success("Activity logged!")}
              >
                Show Toast
              </DSButton>
            </div>
          </Card>
        </div>
      </RevealSection>

      <ScrollDivider />

      {/* ── 21. Special Surfaces ───────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Special Surfaces</SectionTitle>
        <SectionSub>Empty states, onboarding, and floating actions use patterned surfaces to draw attention.</SectionSub>

        <div className="grid gap-4">
          {/* Empty state */}
          <Card elevation="feature">
            <div className="flex flex-col items-center text-center py-6">
              <div className="relative overflow-hidden w-12 h-12 rounded-full bg-ds-surface-raised flex items-center justify-center mb-4">
                <PatternOverlay variant="original" opacity={0.12} blend="screen" />
                <Moon size={24} className="text-ds-sage relative z-10" />
              </div>
              <Text variant="title-md" color="primary">No sleep data yet</Text>
              <Text variant="body-sm" color="secondary" className="mt-1 max-w-xs">
                Connect your wearable or log manually to start tracking your sleep patterns.
              </Text>
              <DSButton intent="primary" size="sm" className="mt-4">
                Connect Device
              </DSButton>
            </div>
          </Card>

          {/* Onboarding card */}
          <Card elevation="hero">
            <div className="py-2">
              <Text variant="display-sm" color="sage" pattern="sage">Welcome to Zuralog</Text>
              <Text variant="body-md" color="secondary" className="mt-2 max-w-md">
                Your personal health hub. We bring together data from all your devices
                and give you one clear picture of your well-being.
              </Text>
              <DSButton intent="primary" size="md" className="mt-4">
                Get Started
              </DSButton>
            </div>
          </Card>

          {/* FAB mockup (inline — no component) */}
          <Card elevation="standard">
            <Label>Floating Action Button</Label>
            <div className="mt-4">
            <div
              className="relative inline-flex items-center justify-center w-14 h-14 rounded-full overflow-hidden ds-pattern-drift"
              style={{ backgroundImage: "url('/patterns/sage.png')" }}
            >
              <Plus size={24} className="text-ds-text-on-sage relative z-[2]" />
            </div>
            </div>
          </Card>
        </div>
      </RevealSection>

      {/* ── 16. Navigation Mockup ──────────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Navigation</SectionTitle>
        <SectionSub>Top bar with avatar, bottom nav with pill-shaped active indicator.</SectionSub>

        <div className="max-w-sm mx-auto">
          {/* Top bar */}
          <div className="flex items-center justify-between bg-ds-surface rounded-t-ds-lg px-4 py-3">
            <Text variant="title-lg" color="primary">Today</Text>
            <Avatar initials="AJ" size="sm" />
          </div>

          {/* Content placeholder */}
          <div className="bg-ds-canvas h-24 flex items-center justify-center border-x border-[rgba(240,238,233,0.06)]">
            <Text variant="body-sm" color="secondary">Screen content</Text>
          </div>

          {/* Bottom nav */}
          <div className="flex items-center justify-around bg-ds-surface rounded-b-ds-lg px-2 py-2">
            {[
              { icon: <Home size={20} />, label: "Home", active: true },
              { icon: <BarChart3 size={20} />, label: "Trends", active: false },
              { icon: <Search size={20} />, label: "Explore", active: false },
              { icon: <Settings size={20} />, label: "Settings", active: false },
            ].map((tab) => (
              <div
                key={tab.label}
                className={`flex flex-col items-center gap-0.5 px-4 py-1.5 rounded-ds-pill ${
                  tab.active
                    ? "bg-[rgba(207,225,185,0.12)] text-ds-sage"
                    : "text-ds-text-secondary"
                }`}
              >
                {tab.icon}
                <span className="text-[0.625rem] font-medium">{tab.label}</span>
              </div>
            ))}
          </div>
        </div>
      </RevealSection>

      {/* ── 17. GSAP Effects Showcase ──────────────────────────────── */}
      <ScrollDivider />

      <RevealSection className="mt-16">
        <SectionTitle>Effects Showcase</SectionTitle>
        <SectionSub>Interactive animation effects built with GSAP — reusable across the product. Each demo integrates our Sage pattern.</SectionSub>
      </RevealSection>

      {/* 17a. MorphSVG */}
      <RevealSection className="mt-10">
        <Label>MorphSVG — Shape Morphing</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          Smooth transitions between completely different SVG shapes. The Sage
          pattern fills each shape as it morphs. Auto-cycles every 3 seconds
          or click any shape to jump directly.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <MorphSvgDemo />
          </div>
        </Card>
      </RevealSection>

      {/* 17b. Footer Bounce */}
      <RevealSection className="mt-10">
        <Label>Footer Bounce — Scroll-Velocity Wave</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          The wave edge at the top of this footer bounces when you scroll to
          it. The faster you scroll, the bigger the elastic bounce. Uses
          GSAP ScrollTrigger velocity detection paired with MorphSVG.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <FooterBouncDemo />
          </div>
        </Card>
      </RevealSection>

      {/* 17c. Flip Filter */}
      <RevealSection className="mt-10">
        <Label>Smooth Filtering — GSAP Flip</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          Health metric tiles laid out in a flex grid. Click any category to
          filter — matching tiles smoothly reposition while others fade out.
          No jarring layout jumps.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <FlipFilterDemo />
          </div>
        </Card>
      </RevealSection>

      {/* 17d. Shape Overlay */}
      <RevealSection className="mt-10">
        <Label>Shape Overlay — Page Transitions</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          A Sage-patterned SVG shape wipes across the container, covering
          content during transitions and revealing new content underneath.
          Perfect for page or section transitions.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <ShapeOverlayDemo />
          </div>
        </Card>
      </RevealSection>

      {/* 17e. MorphSVG Curve */}
      <RevealSection className="mt-10">
        <Label>MorphSVG Curve — Click Reveal</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          Click the container to toggle a curved SVG shape. The shape bows
          upward as it sweeps in, then flattens to cover the surface. Click
          again to reverse.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <MorphCurveDemo />
          </div>
        </Card>
      </RevealSection>

      {/* 17f. Rolling Text */}
      <RevealSection className="mt-10">
        <Label>Rolling Text — SplitText 3D</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          Each character rotates on a 3D cylinder, staggered per letter and
          per line. Uses GSAP SplitText for character-level control.
        </Text>
        <Card elevation="standard">
          <div className="p-6">
            <RollingTextDemo />
          </div>
        </Card>
      </RevealSection>

      {/* ── 18. Scroll-Driven Effects ──────────────────────────────── */}
      <ScrollDivider />

      <RevealSection className="mt-16">
        <SectionTitle>Scroll-Driven Effects</SectionTitle>
        <SectionSub>These effects are driven by the page scroll — they activate as you scroll through them.</SectionSub>
      </RevealSection>

      {/* 18a. Container Animation SplitText */}
      <RevealSection className="mt-6">
        <Label>Container Animation — Horizontal SplitText</Label>
        <Text variant="body-sm" color="secondary" className="mb-4 max-w-lg">
          Text scrolls horizontally as you scroll down. Each character
          tumbles in from a random position and rotation, driven by
          ScrollTrigger containerAnimation.
        </Text>
      </RevealSection>

      {/* Break out of max-width so the horizontal scroll spans full viewport */}
      <div className="-mx-6" style={{ width: "100vw", position: "relative", left: "50%", marginLeft: "-50vw" }}>
        <ContainerTextDemo />
      </div>

      {/* ── 19. Pattern Reference Table ────────────────────────────── */}
      <RevealSection className="mt-16">
        <SectionTitle>Pattern Reference</SectionTitle>
        <SectionSub>Every component that gets the topographic pattern treatment, with its variant and blend mode.</SectionSub>

        <Card elevation="standard">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-[rgba(240,238,233,0.06)]">
                  <th className="text-left py-2 pr-4">
                    <Text variant="label-sm" color="sage" as="span">Component</Text>
                  </th>
                  <th className="text-left py-2 pr-4">
                    <Text variant="label-sm" color="sage" as="span">Pattern</Text>
                  </th>
                  <th className="text-left py-2">
                    <Text variant="label-sm" color="sage" as="span">Blend Mode</Text>
                  </th>
                </tr>
              </thead>
              <tbody>
                {patternTable.map((row) => (
                  <tr key={row.component} className="border-b border-[rgba(240,238,233,0.03)]">
                    <td className="py-2 pr-4">
                      <Text variant="body-sm" color="primary" as="span">{row.component}</Text>
                    </td>
                    <td className="py-2 pr-4">
                      <Text variant="body-sm" color="secondary" as="span">{row.pattern}</Text>
                    </td>
                    <td className="py-2">
                      <Text variant="body-sm" color="secondary" as="span">{row.blend}</Text>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </RevealSection>

      {/* ── 18. Confetti Demo ────────────────────────────────────────── */}
      <RevealSection className="mt-16 text-center">
        <Text variant="body-md" color="secondary" className="mb-4">
          That&rsquo;s the full system. Celebrate finishing the tour.
        </Text>
        <DSButton intent="primary" size="md" onClick={() => sageConfetti()}>
          Try Confetti
        </DSButton>
      </RevealSection>

      {/* ── 19. Footer ─────────────────────────────────────────────── */}
      <footer className="mt-16 text-center">
        <Divider className="mb-6" />
        <Text variant="body-sm" color="secondary">
          Zuralog Design System &middot; 2026
        </Text>
      </footer>
    </main>
  );
}

"use client";

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
} from "@/components/design-system";
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
} from "lucide-react";

/* ── Section helpers ─────────────────────────────────────────────────── */

function SectionTitle({ children }: { children: string }) {
  return (
    <Text variant="display-md" color="sage">
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
  return (
    <main className="max-w-[960px] mx-auto px-6 py-12 pb-24">
      {/* ── 1. Header ──────────────────────────────────────────────── */}
      <header>
        <Text variant="display-lg" color="sage" as="h1">
          Zuralog Design System
        </Text>
        <Text variant="body-lg" color="secondary" className="mt-3 max-w-2xl">
          A living reference of every design token, component, and pattern.
          Dark canvas, warm typography, topographic texture on every interactive surface.
        </Text>
      </header>

      {/* ── 2. Canvas & Elevation ──────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 3. Typography ──────────────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 4. Accent Colors ───────────────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Accent Colors</SectionTitle>
        <SectionSub>Two accent colors anchor the entire palette. Sage for actions, Warm White for navigation.</SectionSub>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="relative overflow-hidden rounded-ds-lg h-32 bg-ds-sage flex items-end p-5">
            <PatternOverlay variant="sage" opacity={0.15} blend="color-burn" />
            <div className="relative z-10">
              <Text variant="title-md" color="on-sage">Sage</Text>
              <Text variant="body-sm" color="on-sage" className="opacity-70">
                #CFE1B9 — Primary actions, buttons, toggles, links
              </Text>
            </div>
          </div>
          <div className="relative overflow-hidden rounded-ds-lg h-32 bg-ds-warm-white flex items-end p-5">
            <div className="relative z-10">
              <Text variant="title-md" color="on-warm-white">Warm White</Text>
              <Text variant="body-sm" color="on-warm-white" className="opacity-70">
                #F0EEE9 — Navigation, tabs, segmented controls
              </Text>
            </div>
          </div>
        </div>
      </section>

      {/* ── 5. Text Colors ─────────────────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Text Colors</SectionTitle>
        <SectionSub>Four text roles mapped to surface context. Always use the right pairing for contrast.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { name: "Text Primary", color: "text-ds-text-primary", bg: "bg-ds-surface", hex: "#F0EEE9" },
            { name: "Text Secondary", color: "text-ds-text-secondary", bg: "bg-ds-surface", hex: "#9B9894" },
            { name: "On Sage", color: "text-ds-text-on-sage", bg: "bg-ds-sage", hex: "#1A2E22" },
            { name: "On Warm White", color: "text-ds-text-on-warm-white", bg: "bg-ds-warm-white", hex: "#161618" },
          ].map((item) => (
            <div key={item.name} className={`${item.bg} rounded-ds-md p-4`}>
              <span className={`${item.color} font-jakarta text-[1rem] font-medium block`}>Aa</span>
              <Text variant="label-sm" color="secondary" className="mt-2">{item.name}</Text>
              <Text variant="label-sm" color="secondary" className="font-mono">{item.hex}</Text>
            </div>
          ))}
        </div>
      </section>

      {/* ── 6. Health Category Colors ──────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Health Categories</SectionTitle>
        <SectionSub>Ten distinct hues, one per health domain. Each category gets its own pattern tint on feature cards.</SectionSub>

        <div className="grid grid-cols-5 sm:grid-cols-10 gap-3 mb-8">
          {categoryColors.map((cat) => (
            <div key={cat.key} className="flex flex-col items-center gap-1.5">
              <div
                className="w-10 h-10 rounded-full"
                style={{ backgroundColor: cat.hex }}
              />
              <Text variant="label-sm" color="primary">{cat.name}</Text>
              <Text variant="label-sm" color="secondary" className="font-mono">{cat.hex}</Text>
            </div>
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
      </section>

      {/* ── 7. Semantic / Status Colors ────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Status Colors</SectionTitle>
        <SectionSub>Semantic signals for success, warning, error, and sync states.</SectionSub>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { name: "Success", hex: "#34C759", bg: "bg-ds-success" },
            { name: "Warning", hex: "#FF9500", bg: "bg-ds-warning" },
            { name: "Error", hex: "#FF3B30", bg: "bg-ds-error" },
            { name: "Syncing", hex: "#007AFF", bg: "bg-ds-syncing" },
          ].map((status) => (
            <div key={status.name} className="flex items-center gap-3">
              <div className={`w-4 h-4 rounded-full ${status.bg}`} />
              <div>
                <Text variant="label-md" color="primary">{status.name}</Text>
                <Text variant="label-sm" color="secondary" className="font-mono">{status.hex}</Text>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── 8. Spacing ─────────────────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 9. Shape (Border Radius) ───────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 10. Buttons ────────────────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 11. Cards ──────────────────────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Cards</SectionTitle>
        <SectionSub>Three elevation levels plus category feature cards. Hero and feature cards get pattern overlays.</SectionSub>

        <div className="grid gap-4">
          <Card elevation="hero">
            <Text variant="body-sm" color="secondary">Health Score</Text>
            <Text variant="display-lg" color="sage" className="mt-1">78</Text>
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
                Your HRV is 18% higher on nights with 7+ hours of sleep. Try a consistent 10:30pm bedtime.
              </Text>
            </Card>

            <Card elevation="data">
              <Text variant="label-md" color="secondary">Steps</Text>
              <Text variant="display-md" color="primary" className="mt-1">8,432</Text>
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
      </section>

      {/* ── 12. Inputs & Selection ─────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 13. Feedback ───────────────────────────────────────────── */}
      <section className="mt-16">
        <SectionTitle>Feedback</SectionTitle>
        <SectionSub>Toasts, dialogs, badges, tooltips, and loading states give the user clear signals.</SectionSub>

        <div className="grid gap-6">
          {/* Toast mockups (inline — no toast component yet) */}
          <Card elevation="standard">
            <Label>Toast Mockups</Label>
            <div className="flex flex-col gap-3 max-w-sm">
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div className="w-2 h-2 rounded-full bg-ds-success shrink-0" />
                <Text variant="body-sm" color="primary">Activity logged successfully.</Text>
              </div>
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div className="w-2 h-2 rounded-full bg-ds-error shrink-0" />
                <Text variant="body-sm" color="primary">Failed to sync. Tap to retry.</Text>
              </div>
              <div className="flex items-center gap-3 bg-ds-surface-raised rounded-ds-sm px-4 py-3">
                <div className="w-2 h-2 rounded-full bg-ds-warning shrink-0" />
                <Text variant="body-sm" color="primary">Health data permissions required.</Text>
              </div>
            </div>
          </Card>

          {/* Dialog */}
          <Card elevation="standard">
            <Label>Dialog</Label>
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
            <DSTooltip>
              <DSTooltipTrigger>
                <DSButton intent="secondary" size="sm">Hover me</DSButton>
              </DSTooltipTrigger>
              <DSTooltipContent>
                This is a tooltip with helpful context.
              </DSTooltipContent>
            </DSTooltip>
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
                <div className="relative h-full w-[67%] bg-ds-sage rounded-full overflow-hidden">
                  <PatternOverlay variant="sage" opacity={0.12} blend="color-burn" />
                </div>
              </div>
            </div>
          </Card>
        </div>
      </section>

      {/* ── 14. Display Components ─────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 15. Special Surfaces ───────────────────────────────────── */}
      <section className="mt-16">
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
              <Text variant="display-sm" color="sage">Welcome to Zuralog</Text>
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
          <div>
            <Label>Floating Action Button</Label>
            <div className="relative inline-flex items-center justify-center w-14 h-14 rounded-full bg-ds-sage overflow-hidden mt-2">
              <PatternOverlay variant="sage" opacity={0.15} blend="color-burn" />
              <Plus size={24} className="text-ds-text-on-sage relative z-10" />
            </div>
          </div>
        </div>
      </section>

      {/* ── 16. Navigation Mockup ──────────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 17. Pattern Reference Table ────────────────────────────── */}
      <section className="mt-16">
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
      </section>

      {/* ── 18. Footer ─────────────────────────────────────────────── */}
      <footer className="mt-16 text-center">
        <Divider className="mb-6" />
        <Text variant="body-sm" color="secondary">
          Zuralog Design System &middot; 2026
        </Text>
      </footer>
    </main>
  );
}

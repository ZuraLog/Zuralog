"use client";

import { useRef, useState, useCallback, useEffect } from "react";
import gsap from "gsap";
import { Flip } from "gsap/dist/Flip";
import { PatternOverlay } from "../primitives/pattern-overlay";

if (typeof window !== "undefined") {
  gsap.registerPlugin(Flip);
}

/* ── Health categories used as filterable tiles ─────────────────────── */

interface HealthTile {
  id: string;
  label: string;
  category: string;
  /** Pattern color variant matching the design system category mapping */
  pattern: string;
  /** Background accent color */
  accent: string;
  icon: string;
}

const tiles: HealthTile[] = [
  { id: "steps",      label: "Steps",        category: "activity",   pattern: "green",      accent: "bg-[#4CAF50]/15", icon: "🏃" },
  { id: "run",        label: "Running",      category: "activity",   pattern: "green",      accent: "bg-[#4CAF50]/15", icon: "👟" },
  { id: "sleep",      label: "Sleep",        category: "sleep",      pattern: "periwinkle", accent: "bg-[#7C8FD4]/15", icon: "😴" },
  { id: "nap",        label: "Nap",          category: "sleep",      pattern: "periwinkle", accent: "bg-[#7C8FD4]/15", icon: "💤" },
  { id: "bpm",        label: "Heart Rate",   category: "heart",      pattern: "rose",       accent: "bg-[#E57373]/15", icon: "❤️" },
  { id: "hrv",        label: "HRV",          category: "heart",      pattern: "rose",       accent: "bg-[#E57373]/15", icon: "💓" },
  { id: "calories",   label: "Calories",     category: "nutrition",  pattern: "amber",      accent: "bg-[#FFB74D]/15", icon: "🍎" },
  { id: "water",      label: "Water",        category: "nutrition",  pattern: "amber",      accent: "bg-[#FFB74D]/15", icon: "💧" },
  { id: "weight",     label: "Weight",       category: "body",       pattern: "sky-blue",   accent: "bg-[#64B5F6]/15", icon: "⚖️" },
  { id: "bmi",        label: "BMI",          category: "body",       pattern: "sky-blue",   accent: "bg-[#64B5F6]/15", icon: "📊" },
  { id: "spo2",       label: "SpO₂",        category: "vitals",     pattern: "teal",       accent: "bg-[#4DB6AC]/15", icon: "🫁" },
  { id: "temp",       label: "Temperature",  category: "vitals",     pattern: "teal",       accent: "bg-[#4DB6AC]/15", icon: "🌡️" },
];

const categories = [
  { id: "all",       label: "All",        color: "bg-ds-sage/20 text-ds-sage ring-ds-sage/30" },
  { id: "activity",  label: "Activity",   color: "bg-[#4CAF50]/20 text-[#4CAF50] ring-[#4CAF50]/30" },
  { id: "sleep",     label: "Sleep",      color: "bg-[#7C8FD4]/20 text-[#7C8FD4] ring-[#7C8FD4]/30" },
  { id: "heart",     label: "Heart",      color: "bg-[#E57373]/20 text-[#E57373] ring-[#E57373]/30" },
  { id: "nutrition", label: "Nutrition",  color: "bg-[#FFB74D]/20 text-[#FFB74D] ring-[#FFB74D]/30" },
  { id: "body",      label: "Body",       color: "bg-[#64B5F6]/20 text-[#64B5F6] ring-[#64B5F6]/30" },
  { id: "vitals",    label: "Vitals",     color: "bg-[#4DB6AC]/20 text-[#4DB6AC] ring-[#4DB6AC]/30" },
];

/**
 * Smooth flexbox filtering powered by GSAP Flip.
 *
 * Health metric tiles are laid out in a flex-wrap grid. Clicking a
 * category filter hides non-matching tiles and smoothly repositions the
 * remaining ones — no jarring layout jumps. Each tile carries its
 * category's pattern overlay.
 */
export function FlipFilterDemo() {
  const gridRef = useRef<HTMLDivElement>(null);
  const [activeFilter, setActiveFilter] = useState("all");
  const tilesRef = useRef<HTMLDivElement[]>([]);

  /* Collect tile refs */
  const setTileRef = useCallback(
    (el: HTMLDivElement | null, idx: number) => {
      if (el) tilesRef.current[idx] = el;
    },
    [],
  );

  const handleFilter = useCallback(
    (category: string) => {
      if (category === activeFilter) return;

      const allTiles = tilesRef.current.filter(Boolean);
      if (allTiles.length === 0) return;

      // 1. Snapshot current positions
      const state = Flip.getState(allTiles);

      // 2. Toggle visibility
      allTiles.forEach((tile) => {
        const cat = tile.dataset.category;
        tile.style.display =
          category === "all" || cat === category ? "flex" : "none";
      });

      // 3. Animate from snapshot to new layout
      Flip.from(state, {
        duration: 0.6,
        scale: true,
        absolute: true,
        ease: "power1.inOut",
        onEnter: (elements) =>
          gsap.fromTo(
            elements,
            { opacity: 0, scale: 0 },
            { opacity: 1, scale: 1, duration: 0.6 },
          ),
        onLeave: (elements) =>
          gsap.to(elements, { opacity: 0, scale: 0, duration: 0.6 }),
      });

      setActiveFilter(category);
    },
    [activeFilter],
  );

  /* Set data-flip-id on mount for Flip tracking */
  useEffect(() => {
    tilesRef.current.forEach((tile, i) => {
      if (tile) tile.dataset.flipId = tiles[i].id;
    });
  }, []);

  return (
    <div className="flex flex-col gap-6" style={{ minHeight: 240 }}>
      {/* Category filter bar */}
      <div className="flex flex-wrap gap-2">
        {categories.map((cat) => (
          <button
            key={cat.id}
            onClick={() => handleFilter(cat.id)}
            className={`
              px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200
              ${
                activeFilter === cat.id
                  ? `${cat.color} ring-1`
                  : "bg-ds-elevated text-ds-secondary hover:text-ds-primary hover:bg-ds-elevated/80"
              }
            `}
          >
            {cat.label}
          </button>
        ))}
      </div>

      {/* Tile grid */}
      <div
        ref={gridRef}
        className="flex flex-wrap gap-3"
      >
        {tiles.map((tile, idx) => (
          <div
            key={tile.id}
            ref={(el) => setTileRef(el, idx)}
            data-category={tile.category}
            data-flip-id={tile.id}
            className={`
              relative flex items-center gap-2.5 px-4 py-3 rounded-xl
              overflow-hidden ${tile.accent} min-w-[140px]
            `}
          >
            {/* Pattern overlay for visual texture */}
            <PatternOverlay
              variant={tile.pattern as "sage"}
              blend="screen"
              opacity={0.4}
            />

            <span className="text-lg relative z-10">{tile.icon}</span>
            <span className="text-sm font-medium text-ds-primary relative z-10">
              {tile.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

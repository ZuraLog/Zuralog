"use client";

import { useRef, useState, useCallback, useEffect } from "react";
import gsap from "gsap";

/* ── Config ─────────────────────────────────────────────────────────── */

const NUM_POINTS = 10;
const LAYERS_PER_TRANSITION = 2;
const DELAY_POINTS_MAX = 0.3;
const DELAY_PER_PATH = 0.25;

/**
 * Color palettes for each scene — cycles through these.
 * Each palette defines a gradient per layer: [topColor, bottomColor].
 * Layers go from lighter (first) to more opaque (last).
 */
const SCENE_PALETTES = [
  // Sage
  {
    title: "Your Health, Unified",
    subtitle: "All your data in one place",
    layers: [
      ["rgba(207,225,185,0.45)", "rgba(140,161,130,0.2)"],
      ["#CFE1B9", "#8CA182"],
    ],
  },
  // Periwinkle / Sleep
  {
    title: "Sleep Insights",
    subtitle: "Understand your rest patterns",
    layers: [
      ["rgba(94,92,230,0.4)", "rgba(124,143,212,0.2)"],
      ["#5E5CE6", "#7C8FD4"],
    ],
  },
  // Green / Activity
  {
    title: "Activity Tracking",
    subtitle: "Every step counts",
    layers: [
      ["rgba(48,209,88,0.4)", "rgba(76,175,80,0.2)"],
      ["#30D158", "#4CAF50"],
    ],
  },
  // Rose / Heart
  {
    title: "Heart Health",
    subtitle: "Monitor what matters most",
    layers: [
      ["rgba(255,55,95,0.4)", "rgba(229,115,115,0.2)"],
      ["#FF375F", "#E57373"],
    ],
  },
];

/** How many full transitions deep before we prune buried layers */
const PRUNE_AFTER = 3;

/* ── Types ──────────────────────────────────────────────────────────── */

interface LayerState {
  /** Unique key for React & gradient ID */
  id: string;
  /** Gradient top stop color */
  top: string;
  /** Gradient bottom stop color */
  bottom: string;
  /** The tween-able point array (NUM_POINTS values, 0–100) */
  points: number[];
  /** Which transition batch this belongs to */
  batch: number;
}

let layerCounter = 0;

/**
 * SVG shape overlay transition.
 *
 * Each click adds new wave layers on top of previous ones. Old layers
 * stay visible underneath — the effect builds up like paint. After 3
 * full transitions, the oldest buried layers get pruned.
 */
export function ShapeOverlayDemo() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [sceneIdx, setSceneIdx] = useState(0);
  const [transitioning, setTransitioning] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  const tlRef = useRef<gsap.core.Timeline | null>(null);

  // All accumulated layers — oldest first
  const layersRef = useRef<LayerState[]>([]);
  // Track current batch number
  const batchRef = useRef(0);
  // Force re-render when layers change (paths are in the DOM)
  const [, forceRender] = useState(0);

  useEffect(() => {
    return () => {
      tlRef.current?.kill();
    };
  }, []);

  /** Render all layer paths from their current point values */
  const renderPaths = useCallback(() => {
    const svg = svgRef.current;
    if (!svg) return;

    for (const layer of layersRef.current) {
      const path = svg.querySelector<SVGPathElement>(
        `[data-layer-id="${layer.id}"]`,
      );
      if (!path) continue;

      const pts = layer.points;
      let d = `M 0 ${pts[0]} C`;
      for (let j = 0; j < NUM_POINTS - 1; j++) {
        const p = ((j + 1) / (NUM_POINTS - 1)) * 100;
        const cp = p - (1 / (NUM_POINTS - 1)) * 100 / 2;
        d += ` ${cp} ${pts[j]} ${cp} ${pts[j + 1]} ${p} ${pts[j + 1]}`;
      }
      d += ` V 100 H 0`;
      path.setAttribute("d", d);
    }
  }, []);

  const transition = useCallback(() => {
    const content = contentRef.current;
    if (!content || transitioning) return;

    setTransitioning(true);
    const nextIdx = (sceneIdx + 1) % SCENE_PALETTES.length;
    const palette = SCENE_PALETTES[nextIdx];
    const batch = batchRef.current + 1;
    batchRef.current = batch;

    tlRef.current?.kill();

    // Prune layers that are buried (older than PRUNE_AFTER batches)
    layersRef.current = layersRef.current.filter(
      (l) => batch - l.batch < PRUNE_AFTER,
    );

    // Create new layers for this transition
    const newLayers: LayerState[] = palette.layers.map(([top, bottom]) => {
      const id = `layer-${++layerCounter}`;
      const points: number[] = [];
      for (let j = 0; j < NUM_POINTS; j++) points.push(100);
      return { id, top, bottom, points, batch };
    });

    layersRef.current.push(...newLayers);

    // Trigger React re-render so new <path> + <linearGradient> elements exist
    forceRender((n) => n + 1);

    // Wait one frame for DOM to update, then animate
    requestAnimationFrame(() => {
      const pointsDelay: number[] = [];
      for (let i = 0; i < NUM_POINTS; i++) {
        pointsDelay[i] = Math.random() * DELAY_POINTS_MAX;
      }

      const tl = gsap.timeline({
        onUpdate: renderPaths,
        defaults: { ease: "power2.inOut", duration: 0.9 },
      });
      tlRef.current = tl;

      // Fade out content
      tl.to(content, { opacity: 0, duration: 0.3, ease: "power2.in" }, 0);

      // Animate each new layer's points 100 → 0 (bottom → top)
      for (let i = 0; i < newLayers.length; i++) {
        const pts = newLayers[i].points;
        const pathDelay = DELAY_PER_PATH * i;
        for (let j = 0; j < NUM_POINTS; j++) {
          tl.to(pts, { [j]: 0 }, pointsDelay[j] + pathDelay);
        }
      }

      const totalDuration =
        DELAY_POINTS_MAX +
        DELAY_PER_PATH * (newLayers.length - 1) +
        0.9;

      // Swap content
      tl.call(() => setSceneIdx(nextIdx), [], totalDuration);

      // Fade in new content on top of all layers
      tl.to(
        content,
        {
          opacity: 1,
          duration: 0.4,
          ease: "power2.out",
          onComplete: () => setTransitioning(false),
        },
        totalDuration + 0.1,
      );
    });
  }, [sceneIdx, transitioning, renderPaths]);

  const scene = SCENE_PALETTES[sceneIdx];

  return (
    <div className="flex flex-col gap-4">
      <div
        className="relative rounded-xl overflow-hidden bg-ds-canvas"
        style={{ minHeight: 240 }}
      >
        {/* Scene content */}
        <div
          ref={contentRef}
          className="relative flex flex-col items-center justify-center h-full py-12 px-6 text-center"
          style={{ minHeight: 240, zIndex: 30 }}
        >
          <p className="text-2xl font-semibold text-ds-primary mb-2">
            {scene.title}
          </p>
          <p className="text-sm text-ds-secondary">{scene.subtitle}</p>
          <div className="mt-4 flex gap-2">
            {SCENE_PALETTES.map((_, i) => (
              <div
                key={i}
                className={`w-2 h-2 rounded-full transition-all duration-300 ${
                  i === sceneIdx
                    ? "bg-ds-sage scale-125"
                    : "bg-[rgba(240,238,233,0.25)]"
                }`}
              />
            ))}
          </div>
        </div>

        {/* SVG overlay — layers accumulate here */}
        <svg
          ref={svgRef}
          viewBox="0 0 100 100"
          preserveAspectRatio="none"
          className="absolute inset-0 w-full h-full pointer-events-none"
          style={{ zIndex: 20 }}
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            {layersRef.current.map((layer) => (
              <linearGradient
                key={layer.id}
                id={`grad-${layer.id}`}
                x1="0%"
                y1="0%"
                x2="0%"
                y2="100%"
              >
                <stop offset="0%" stopColor={layer.top} />
                <stop offset="100%" stopColor={layer.bottom} />
              </linearGradient>
            ))}
          </defs>
          {layersRef.current.map((layer) => (
            <path
              key={layer.id}
              data-layer-id={layer.id}
              fill={`url(#grad-${layer.id})`}
              d=""
            />
          ))}
        </svg>
      </div>

      <button
        onClick={transition}
        disabled={transitioning}
        className={`
          self-center px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200
          ${
            transitioning
              ? "bg-ds-elevated/50 text-ds-secondary/50 cursor-not-allowed"
              : "bg-ds-elevated text-ds-secondary hover:text-ds-primary hover:bg-ds-elevated/80"
          }
        `}
      >
        {transitioning ? "Transitioning…" : "Next Scene →"}
      </button>
    </div>
  );
}

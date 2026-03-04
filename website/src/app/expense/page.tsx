// ADMIN ONLY — Password protected, not linked in public navigation.
// Do not add to sitemap.xml. Internal use only.
"use client";

import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Text, RoundedBox, Float, Sphere, Torus } from "@react-three/drei";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import * as THREE from "three";

/* ─────────────────────────────────────────────────────────────
   Types
───────────────────────────────────────────────────────────── */

interface ActiveExpense {
  service: string;
  category: string;
  assignedTo: string;
  monthly: number;
  note?: string;
}

type PipelineStatus = "plan" | "on-hold" | "active";

interface PipelineExpense {
  service: string;
  category: string;
  estMonthly: number;
  priority: "HIGH" | "MED" | "LOW";
  status: PipelineStatus;
}

/* ─────────────────────────────────────────────────────────────
   Default data
───────────────────────────────────────────────────────────── */

const DEFAULT_ACTIVE: ActiveExpense[] = [];

const DEFAULT_PIPELINE: PipelineExpense[] = [];

const AUTH_KEY = "zuralog_expense_auth";
const STORAGE_KEY_ACTIVE = "zuralog_expenses_active";
const STORAGE_KEY_PIPELINE = "zuralog_expenses_pipeline";
const PASSWORD = "ZFtemp#1!";

const CATEGORIES = [
  "AI / LLM", "Dev Tools", "Backend / DB", "Vector DB", "Payments",
  "App Stores", "Hosting", "Monitoring", "Comms", "Productivity",
];

/* ─────────────────────────────────────────────────────────────
   Persistence helpers
───────────────────────────────────────────────────────────── */

function loadActive(): ActiveExpense[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY_ACTIVE);
    return raw ? JSON.parse(raw) : DEFAULT_ACTIVE;
  } catch { return DEFAULT_ACTIVE; }
}

function loadPipeline(): PipelineExpense[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY_PIPELINE);
    if (!raw) return DEFAULT_PIPELINE;
    const parsed = JSON.parse(raw) as PipelineExpense[];
    // Migrate legacy data that might not have status
    return parsed.map((e) => ({ ...e, status: e.status || "plan" }));
  } catch { return DEFAULT_PIPELINE; }
}

function saveActive(data: ActiveExpense[]) {
  localStorage.setItem(STORAGE_KEY_ACTIVE, JSON.stringify(data));
}

function savePipeline(data: PipelineExpense[]) {
  localStorage.setItem(STORAGE_KEY_PIPELINE, JSON.stringify(data));
}

/* ─────────────────────────────────────────────────────────────
   KPI helpers
───────────────────────────────────────────────────────────── */

function computeKPIs(active: ActiveExpense[], pipeline: PipelineExpense[]) {
  const totalMonthly = active.reduce((s, e) => s + e.monthly, 0);
  const fernando = active.filter((e) => e.assignedTo === "Fernando").reduce((s, e) => s + e.monthly, 0);
  const hyowon = active.filter((e) => e.assignedTo === "Hyowon").reduce((s, e) => s + e.monthly, 0);
  const pipelineTotal = pipeline.reduce((s, e) => s + e.estMonthly, 0);
  const paidServices = active.filter((e) => e.monthly > 0).length;
  const freeServices = active.filter((e) => e.monthly === 0).length;
  return { totalMonthly, totalAnnual: totalMonthly * 12, fernando, hyowon, pipelineTotal, paidServices, freeServices };
}

/* ─────────────────────────────────────────────────────────────
   Animation variants
───────────────────────────────────────────────────────────── */

const fadeUp = {
  hidden: { opacity: 0, y: 20 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.06, duration: 0.4, ease: "easeOut" } }),
};

const staggerContainer = {
  hidden: {},
  show: { transition: { staggerChildren: 0.04 } },
};

const tableRow = {
  hidden: { opacity: 0, x: -12 },
  show: { opacity: 1, x: 0, transition: { duration: 0.3, ease: "easeOut" } },
};

const scaleIn = {
  hidden: { opacity: 0, scale: 0.9 },
  show: { opacity: 1, scale: 1, transition: { duration: 0.4, ease: "easeOut" } },
};

/* ─────────────────────────────────────────────────────────────
   Animated counter hook
───────────────────────────────────────────────────────────── */

function useAnimatedValue(target: number, duration = 800) {
  const [display, setDisplay] = useState(0);
  const frameRef = useRef<number>(0);

  useEffect(() => {
    const start = performance.now();
    const from = 0;
    const tick = (now: number) => {
      const t = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      setDisplay(Math.round(from + (target - from) * eased));
      if (t < 1) frameRef.current = requestAnimationFrame(tick);
    };
    frameRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameRef.current);
  }, [target, duration]);

  return display;
}

/* ─────────────────────────────────────────────────────────────
   Shared 3D constants & helpers
───────────────────────────────────────────────────────────── */

const CHART_COLORS: Record<string, string> = {
  "AI / LLM": "#CFE1B9",
  "Dev Tools": "#E8F5A8",
  "Backend / DB": "#b3d18f",
  "Vector DB": "#A8D5BA",
  "Payments": "#D4F291",
  "App Stores": "#F5E6A8",
  "Hosting": "#A8C5E2",
  "Monitoring": "#E2A8C5",
  "Comms": "#C5A8E2",
  "Productivity": "#A8E2D5",
};

const PERSON_COLORS: Record<string, string> = {
  Fernando: "#CFE1B9",
  Hyowon: "#E8F5A8",
  ZuraLog: "#b3d18f",
  "ZuraLog Backend": "#A8D5BA",
  "ZuraLog App": "#D4F291",
  "ZuraLog Marketing": "#F5E6A8",
};

const PRIORITY_COLORS = { HIGH: "#f87171", MED: "#fbbf24", LOW: "#a3a3a3" };

function ChartCard({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <motion.div
      variants={scaleIn}
      initial="hidden"
      animate="show"
      className={`overflow-hidden rounded-xl border border-black/6 bg-cream shadow-sm ${className}`}
    >
      {children}
    </motion.div>
  );
}

function GridFloor() {
  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.01, 0]}>
      <planeGeometry args={[30, 30]} />
      <meshStandardMaterial color="#FAFAF5" roughness={1} />
    </mesh>
  );
}

function StandardLights() {
  return (
    <>
      <ambientLight intensity={0.6} />
      <directionalLight position={[5, 8, 5]} intensity={0.8} />
      <directionalLight position={[-3, 5, -3]} intensity={0.3} />
    </>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 1 — 3D Bar Chart (Spend by Category)
───────────────────────────────────────────────────────────── */

function Bar3D({ position, height, color, label, value }: {
  position: [number, number, number];
  height: number;
  color: string;
  label: string;
  value: number;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const targetH = useRef(height);
  const currentH = useRef(0.01);
  const [hovered, setHovered] = useState(false);
  targetH.current = height;

  useFrame(() => {
    if (!meshRef.current) return;
    currentH.current += (targetH.current - currentH.current) * 0.06;
    meshRef.current.scale.y = Math.max(currentH.current, 0.01);
    meshRef.current.position.y = currentH.current * 0.5;
  });

  return (
    <group position={position}>
      <RoundedBox ref={meshRef} args={[0.6, 1, 0.6]} radius={0.05} smoothness={4} scale={[1, 0.01, 1]}
        onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}>
        <meshStandardMaterial color={hovered ? "#ffffff" : color} roughness={0.3} metalness={0.1}
          emissive={color} emissiveIntensity={hovered ? 0.3 : 0.05} />
      </RoundedBox>
      <Text position={[0, -0.3, 0]} fontSize={0.15} color="#666" anchorX="center" anchorY="top"
        rotation={[-Math.PI / 6, 0, 0]} maxWidth={1}>{label}</Text>
      {value > 0 && (
        <Float speed={2} rotationIntensity={0} floatIntensity={0.3}>
          <Text position={[0, Math.max(height, 0.2) + 0.25, 0]} fontSize={0.18} fontWeight={700}
            color="#2D2D2D" anchorX="center" anchorY="bottom">${value}</Text>
        </Float>
      )}
    </group>
  );
}

function CategoryBarChart({ expenses }: { expenses: ActiveExpense[] }) {
  const data = useMemo(() => {
    const m = new Map<string, number>();
    expenses.forEach((e) => m.set(e.category, (m.get(e.category) || 0) + e.monthly));
    return Array.from(m.entries()).map(([l, v]) => ({ label: l, value: v })).filter((d) => d.value > 0).sort((a, b) => b.value - a.value);
  }, [expenses]);

  if (!data.length) return <EmptyChart text="No paid expenses to chart." />;
  const maxVal = Math.max(...data.map((d) => d.value), 1);

  return (
    <ChartCard className="h-[340px] sm:h-[380px]">
      <Canvas camera={{ position: [0, 3, 6], fov: 40 }}>
        <StandardLights />
        <GridFloor />
        {data.map((d, i) => (
          <Bar3D key={d.label} position={[(i - (data.length - 1) / 2) * 1.1, 0, 0]}
            height={(d.value / maxVal) * 3} color={CHART_COLORS[d.label] || "#CFE1B9"}
            label={d.label} value={d.value} />
        ))}
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 6}
          maxPolarAngle={Math.PI / 2.5} autoRotate autoRotateSpeed={0.5} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 2 — 3D Donut (Spend by Person)
───────────────────────────────────────────────────────────── */

function DonutSegment({ startAngle, endAngle, color, innerR, outerR, label }: {
  startAngle: number; endAngle: number; color: string;
  innerR: number; outerR: number; label: string;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);

  const shape = useMemo(() => {
    const s = new THREE.Shape();
    const seg = 32;
    for (let i = 0; i <= seg; i++) {
      const a = startAngle + (endAngle - startAngle) * (i / seg);
      const fn = i === 0 ? "moveTo" : "lineTo";
      s[fn](Math.cos(a) * outerR, Math.sin(a) * outerR);
    }
    for (let i = seg; i >= 0; i--) {
      const a = startAngle + (endAngle - startAngle) * (i / seg);
      s.lineTo(Math.cos(a) * innerR, Math.sin(a) * innerR);
    }
    s.closePath();
    return s;
  }, [startAngle, endAngle, innerR, outerR]);

  useFrame(() => {
    if (!meshRef.current) return;
    meshRef.current.position.z += ((hovered ? 0.15 : 0) - meshRef.current.position.z) * 0.1;
  });

  const mid = (startAngle + endAngle) / 2;
  const lr = (innerR + outerR) / 2;

  return (
    <group>
      <mesh ref={meshRef} rotation={[-Math.PI / 2, 0, 0]}
        onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}>
        <extrudeGeometry args={[shape, { depth: 0.3, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.03, bevelSegments: 3 }]} />
        <meshStandardMaterial color={color} roughness={0.35} metalness={0.1}
          emissive={color} emissiveIntensity={hovered ? 0.4 : 0.05} />
      </mesh>
      <Text position={[Math.cos(mid) * lr, 0.45, -Math.sin(mid) * lr]}
        fontSize={0.14} fontWeight={700} color="#2D2D2D" anchorX="center" anchorY="middle">{label}</Text>
    </group>
  );
}

function PersonDonutChart({ expenses }: { expenses: ActiveExpense[] }) {
  const data = useMemo(() => {
    const m = new Map<string, number>();
    expenses.forEach((e) => { if (e.monthly > 0) m.set(e.assignedTo, (m.get(e.assignedTo) || 0) + e.monthly); });
    return Array.from(m.entries()).map(([l, v]) => ({ label: l, value: v })).sort((a, b) => b.value - a.value);
  }, [expenses]);

  if (!data.length) return <EmptyChart text="No paid expenses to chart." />;
  const total = data.reduce((s, d) => s + d.value, 0);
  let angle = 0;

  return (
    <ChartCard className="h-[340px] sm:h-[380px]">
      <Canvas camera={{ position: [0, 2.5, 3.5], fov: 40 }}>
        <ambientLight intensity={0.7} />
        <directionalLight position={[3, 6, 4]} intensity={0.6} />
        {data.map((d) => {
          const s = angle;
          const slice = (d.value / total) * Math.PI * 2;
          angle += slice;
          return <DonutSegment key={d.label} startAngle={s} endAngle={s + slice}
            color={PERSON_COLORS[d.label] || "#CFE1B9"} innerR={0.6} outerR={1.3}
            label={`${d.label}\n$${d.value}`} />;
        })}
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 6}
          maxPolarAngle={Math.PI / 2.2} autoRotate autoRotateSpeed={0.8} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 3 — 3D Floating Bubble Cloud (each service = sphere)
───────────────────────────────────────────────────────────── */

function BubbleNode({ position, radius, color, label }: {
  position: [number, number, number]; radius: number; color: string; label: string;
}) {
  const ref = useRef<THREE.Group>(null);
  const [hovered, setHovered] = useState(false);
  const seed = useMemo(() => Math.random() * 100, []);

  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime + seed;
    ref.current.position.y = position[1] + Math.sin(t * 0.6) * 0.15;
    ref.current.position.x = position[0] + Math.sin(t * 0.4) * 0.08;
  });

  return (
    <group ref={ref} position={position}>
      <Sphere args={[radius, 24, 24]}
        onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}>
        <meshStandardMaterial color={color} roughness={0.2} metalness={0.15}
          emissive={color} emissiveIntensity={hovered ? 0.5 : 0.1} transparent opacity={hovered ? 1 : 0.85} />
      </Sphere>
      {(hovered || radius > 0.25) && (
        <Text position={[0, radius + 0.15, 0]} fontSize={0.12} fontWeight={700}
          color="#2D2D2D" anchorX="center" anchorY="bottom">{label}</Text>
      )}
    </group>
  );
}

function BubbleCloudChart({ expenses }: { expenses: ActiveExpense[] }) {
  const bubbles = useMemo(() => {
    const paid = expenses.filter((e) => e.monthly > 0);
    if (!paid.length) return [];
    const maxV = Math.max(...paid.map((e) => e.monthly));
    const positions: [number, number, number][] = [];
    // Fibonacci sphere distribution
    const n = paid.length;
    return paid.map((e, i) => {
      const phi = Math.acos(1 - (2 * (i + 0.5)) / n);
      const theta = Math.PI * (1 + Math.sqrt(5)) * i;
      const spread = 2;
      const pos: [number, number, number] = [
        spread * Math.sin(phi) * Math.cos(theta),
        spread * Math.cos(phi) * 0.5 + 0.5,
        spread * Math.sin(phi) * Math.sin(theta),
      ];
      positions.push(pos);
      const r = 0.15 + (e.monthly / maxV) * 0.45;
      return { ...e, pos, radius: r, color: CHART_COLORS[e.category] || "#CFE1B9" };
    });
  }, [expenses]);

  if (!bubbles.length) return <EmptyChart text="No paid services to visualize." />;

  return (
    <ChartCard className="h-[380px] sm:h-[420px]">
      <Canvas camera={{ position: [0, 1.5, 5], fov: 45 }}>
        <StandardLights />
        <pointLight position={[0, 4, 0]} intensity={0.4} color="#E8F5A8" />
        {bubbles.map((b, i) => (
          <BubbleNode key={`${b.service}-${b.assignedTo}-${i}`} position={b.pos} radius={b.radius}
            color={b.color} label={`${b.service} $${b.monthly}`} />
        ))}
        <OrbitControls enableZoom={false} enablePan={false} autoRotate autoRotateSpeed={0.4} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 4 — 3D Treemap (proportional blocks on a grid)
───────────────────────────────────────────────────────────── */

function TreemapBlock({ position, width, depth, height, color, label, value }: {
  position: [number, number, number]; width: number; depth: number;
  height: number; color: string; label: string; value: number;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const currentH = useRef(0.01);
  const [hovered, setHovered] = useState(false);

  useFrame(() => {
    if (!meshRef.current) return;
    currentH.current += (height - currentH.current) * 0.05;
    meshRef.current.scale.y = Math.max(currentH.current, 0.01);
    meshRef.current.position.y = currentH.current * 0.5;
  });

  return (
    <group position={position}>
      <RoundedBox ref={meshRef} args={[width * 0.9, 1, depth * 0.9]} radius={0.04} smoothness={4}
        scale={[1, 0.01, 1]} onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}>
        <meshStandardMaterial color={hovered ? "#fff" : color} roughness={0.25} metalness={0.1}
          emissive={color} emissiveIntensity={hovered ? 0.4 : 0.08} />
      </RoundedBox>
      <Text position={[0, height + 0.15, 0]} fontSize={0.1} fontWeight={700} color="#2D2D2D"
        anchorX="center" anchorY="bottom" maxWidth={width}>{label}{"\n"}${value}</Text>
    </group>
  );
}

function TreemapChart({ expenses }: { expenses: ActiveExpense[] }) {
  const blocks = useMemo(() => {
    const paid = expenses.filter((e) => e.monthly > 0).sort((a, b) => b.monthly - a.monthly);
    if (!paid.length) return [];
    const maxV = Math.max(...paid.map((e) => e.monthly));
    const cols = Math.ceil(Math.sqrt(paid.length));
    return paid.map((e, i) => {
      const row = Math.floor(i / cols);
      const col = i % cols;
      const size = 0.6 + (e.monthly / maxV) * 0.8;
      return {
        ...e, size,
        pos: [(col - (cols - 1) / 2) * 1.5, 0, (row - Math.floor(paid.length / cols) / 2) * 1.5] as [number, number, number],
        height: 0.3 + (e.monthly / maxV) * 2,
        color: CHART_COLORS[e.category] || "#CFE1B9",
      };
    });
  }, [expenses]);

  if (!blocks.length) return <EmptyChart text="No paid services." />;

  return (
    <ChartCard className="h-[380px] sm:h-[420px]">
      <Canvas camera={{ position: [0, 4, 5], fov: 45 }}>
        <StandardLights />
        <GridFloor />
        {blocks.map((b, i) => (
          <TreemapBlock key={`${b.service}-${b.assignedTo}-${i}`} position={b.pos}
            width={b.size} depth={b.size} height={b.height}
            color={b.color} label={b.service} value={b.monthly} />
        ))}
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 8}
          maxPolarAngle={Math.PI / 2.5} autoRotate autoRotateSpeed={0.6} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 5 — 3D Stacked Bars (Active vs Pipeline per category)
───────────────────────────────────────────────────────────── */

function StackedBar({ position, activeH, pipelineH, color, label }: {
  position: [number, number, number]; activeH: number; pipelineH: number;
  color: string; label: string;
}) {
  const activeRef = useRef<THREE.Mesh>(null);
  const pipeRef = useRef<THREE.Mesh>(null);
  const curA = useRef(0.01);
  const curP = useRef(0.01);
  const [hovered, setHovered] = useState(false);

  useFrame(() => {
    curA.current += (activeH - curA.current) * 0.05;
    curP.current += (pipelineH - curP.current) * 0.05;
    if (activeRef.current) {
      activeRef.current.scale.y = Math.max(curA.current, 0.01);
      activeRef.current.position.y = curA.current * 0.5;
    }
    if (pipeRef.current) {
      pipeRef.current.scale.y = Math.max(curP.current, 0.01);
      pipeRef.current.position.y = curA.current + curP.current * 0.5;
    }
  });

  return (
    <group position={position} onPointerOver={() => setHovered(true)} onPointerOut={() => setHovered(false)}>
      <RoundedBox ref={activeRef} args={[0.5, 1, 0.5]} radius={0.04} smoothness={4} scale={[1, 0.01, 1]}>
        <meshStandardMaterial color={color} roughness={0.3} metalness={0.1}
          emissive={color} emissiveIntensity={hovered ? 0.3 : 0.05} />
      </RoundedBox>
      {pipelineH > 0.01 && (
        <RoundedBox ref={pipeRef} args={[0.5, 1, 0.5]} radius={0.04} smoothness={4} scale={[1, 0.01, 1]}>
          <meshStandardMaterial color={color} roughness={0.3} metalness={0.1}
            transparent opacity={0.4} emissive={color} emissiveIntensity={0.1} />
        </RoundedBox>
      )}
      <Text position={[0, -0.25, 0]} fontSize={0.12} color="#666" anchorX="center" anchorY="top"
        rotation={[-Math.PI / 6, 0, 0]} maxWidth={1}>{label}</Text>
      {hovered && (
        <Text position={[0, Math.max(activeH + pipelineH, 0.2) + 0.2, 0]} fontSize={0.13}
          fontWeight={700} color="#2D2D2D" anchorX="center" anchorY="bottom">
          {`Active: $${Math.round(activeH * 100)}\nPipeline: $${Math.round(pipelineH * 100)}`}
        </Text>
      )}
    </group>
  );
}

function StackedComparisonChart({ active, pipeline }: { active: ActiveExpense[]; pipeline: PipelineExpense[] }) {
  const data = useMemo(() => {
    const cats = new Set<string>();
    active.forEach((e) => cats.add(e.category));
    pipeline.forEach((e) => cats.add(e.category));
    const maxAll = Math.max(
      ...Array.from(cats).map((c) => {
        const a = active.filter((e) => e.category === c).reduce((s, e) => s + e.monthly, 0);
        const p = pipeline.filter((e) => e.category === c).reduce((s, e) => s + e.estMonthly, 0);
        return a + p;
      }),
      1,
    );
    return Array.from(cats).map((c) => ({
      category: c,
      activeVal: active.filter((e) => e.category === c).reduce((s, e) => s + e.monthly, 0),
      pipeVal: pipeline.filter((e) => e.category === c).reduce((s, e) => s + e.estMonthly, 0),
      maxAll,
    })).filter((d) => d.activeVal > 0 || d.pipeVal > 0).sort((a, b) => (b.activeVal + b.pipeVal) - (a.activeVal + a.pipeVal));
  }, [active, pipeline]);

  if (!data.length) return <EmptyChart text="No data to compare." />;

  return (
    <ChartCard className="h-[380px] sm:h-[420px]">
      <Canvas camera={{ position: [0, 3.5, 6], fov: 40 }}>
        <StandardLights />
        <GridFloor />
        {data.map((d, i) => (
          <StackedBar key={d.category}
            position={[(i - (data.length - 1) / 2) * 1.1, 0, 0]}
            activeH={(d.activeVal / d.maxAll) * 3}
            pipelineH={(d.pipeVal / d.maxAll) * 3}
            color={CHART_COLORS[d.category] || "#CFE1B9"}
            label={d.category} />
        ))}
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 6}
          maxPolarAngle={Math.PI / 2.5} autoRotate autoRotateSpeed={0.5} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 6 — 3D Priority Towers (Pipeline grouped by priority)
───────────────────────────────────────────────────────────── */

function PriorityTower({ position, items, color, label, maxVal }: {
  position: [number, number, number]; items: PipelineExpense[];
  color: string; label: string; maxVal: number;
}) {
  return (
    <group position={position}>
      {items.map((item, i) => {
        const h = (item.estMonthly / maxVal) * 2.5;
        const yOffset = items.slice(0, i).reduce((s, it) => s + (it.estMonthly / maxVal) * 2.5, 0);
        return (
          <Float key={item.service} speed={1.5} rotationIntensity={0} floatIntensity={0.05}>
            <RoundedBox args={[0.8, Math.max(h, 0.05), 0.8]} radius={0.04} smoothness={4}
              position={[0, yOffset + h / 2, 0]}>
              <meshStandardMaterial color={color} roughness={0.3} metalness={0.1}
                emissive={color} emissiveIntensity={0.1} transparent opacity={0.7 + i * 0.1} />
            </RoundedBox>
            <Text position={[0, yOffset + h / 2, 0.45]} fontSize={0.09} color="#2D2D2D"
              anchorX="center" anchorY="middle">{`${item.service}\n$${item.estMonthly}`}</Text>
          </Float>
        );
      })}
      <Text position={[0, -0.3, 0]} fontSize={0.16} fontWeight={700} color={color}
        anchorX="center" anchorY="top">{label}</Text>
    </group>
  );
}

function PriorityTowersChart({ pipeline }: { pipeline: PipelineExpense[] }) {
  const groups = useMemo(() => {
    const high = pipeline.filter((e) => e.priority === "HIGH");
    const med = pipeline.filter((e) => e.priority === "MED");
    const low = pipeline.filter((e) => e.priority === "LOW");
    const maxVal = Math.max(...pipeline.map((e) => e.estMonthly), 1);
    return { high, med, low, maxVal };
  }, [pipeline]);

  if (!pipeline.length) return <EmptyChart text="No pipeline items." />;

  return (
    <ChartCard className="h-[400px] sm:h-[440px]">
      <Canvas camera={{ position: [0, 3, 7], fov: 40 }}>
        <StandardLights />
        <pointLight position={[0, 6, 0]} intensity={0.3} color="#f87171" />
        <GridFloor />
        <PriorityTower position={[-2.2, 0, 0]} items={groups.high}
          color={PRIORITY_COLORS.HIGH} label="HIGH" maxVal={groups.maxVal} />
        <PriorityTower position={[0, 0, 0]} items={groups.med}
          color={PRIORITY_COLORS.MED} label="MED" maxVal={groups.maxVal} />
        <PriorityTower position={[2.2, 0, 0]} items={groups.low}
          color={PRIORITY_COLORS.LOW} label="LOW" maxVal={groups.maxVal} />
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 8}
          maxPolarAngle={Math.PI / 2.5} autoRotate autoRotateSpeed={0.4} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 7 — 3D Ring Gauge (Budget Utilization)
───────────────────────────────────────────────────────────── */

function AnimatedRing({ progress, color, radius, tube }: {
  progress: number; color: string; radius: number; tube: number;
}) {
  const ref = useRef<THREE.Mesh>(null);
  const currentArc = useRef(0.01);

  useFrame(() => {
    if (!ref.current) return;
    currentArc.current += (progress - currentArc.current) * 0.03;
    const oldGeo = ref.current.geometry;
    ref.current.geometry = new THREE.TorusGeometry(radius, tube, 16, 64, Math.max(currentArc.current, 0.001) * Math.PI * 2);
    oldGeo.dispose();
  });

  return (
    <mesh ref={ref} rotation={[-Math.PI / 2, 0, -Math.PI / 2]}>
      <torusGeometry args={[radius, tube, 16, 64, Math.max(progress, 0.001) * Math.PI * 2]} />
      <meshStandardMaterial color={color} roughness={0.2} metalness={0.2}
        emissive={color} emissiveIntensity={0.15} />
    </mesh>
  );
}

function BudgetGaugeChart({ active, pipeline }: { active: ActiveExpense[]; pipeline: PipelineExpense[] }) {
  const totalActive = active.reduce((s, e) => s + e.monthly, 0);
  const totalPipeline = pipeline.reduce((s, e) => s + e.estMonthly, 0);
  const combined = totalActive + totalPipeline;
  const activeRatio = combined > 0 ? totalActive / combined : 0;
  const pipeRatio = combined > 0 ? totalPipeline / combined : 0;

  return (
    <ChartCard className="h-[340px] sm:h-[380px]">
      <Canvas camera={{ position: [0, 3, 4], fov: 40 }}>
        <StandardLights />
        {/* Background ring */}
        <Torus args={[1.3, 0.12, 16, 64]} rotation={[-Math.PI / 2, 0, 0]}>
          <meshStandardMaterial color="#e5e5e5" roughness={0.8} transparent opacity={0.3} />
        </Torus>
        {/* Active ring */}
        <AnimatedRing progress={activeRatio} color="#CFE1B9" radius={1.3} tube={0.12} />
        {/* Pipeline ring */}
        <Torus args={[1, 0.08, 16, 64]} rotation={[-Math.PI / 2, 0, 0]}>
          <meshStandardMaterial color="#e5e5e5" roughness={0.8} transparent opacity={0.2} />
        </Torus>
        <AnimatedRing progress={pipeRatio} color="#E8F5A8" radius={1} tube={0.08} />
        {/* Center text */}
        <Text position={[0, 0.15, 0]} fontSize={0.3} fontWeight={700} color="#2D2D2D"
          anchorX="center" anchorY="middle">${totalActive}</Text>
        <Text position={[0, -0.15, 0]} fontSize={0.12} color="#666"
          anchorX="center" anchorY="middle">active / mo</Text>
        {/* Legend */}
        <Text position={[-1.8, 0.5, 0]} fontSize={0.1} color="#CFE1B9" anchorX="left">Active ${totalActive}</Text>
        <Text position={[-1.8, 0.2, 0]} fontSize={0.1} color="#E8F5A8" anchorX="left">Pipeline ${totalPipeline}</Text>
        <Text position={[-1.8, -0.1, 0]} fontSize={0.1} color="#666" anchorX="left">Combined ${combined}</Text>
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 4}
          maxPolarAngle={Math.PI / 2.2} autoRotate autoRotateSpeed={0.3} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   CHART 8 — 3D Radar / Spider Chart (category distribution)
───────────────────────────────────────────────────────────── */

function RadarLine({ points, color, opacity = 0.6 }: {
  points: THREE.Vector3[]; color: string; opacity?: number;
}) {
  const lineObj = useMemo(() => {
    const geo = new THREE.BufferGeometry().setFromPoints([...points, points[0]]);
    const mat = new THREE.LineBasicMaterial({ color, transparent: true, opacity });
    return new THREE.Line(geo, mat);
  }, [points, color, opacity]);

  return <primitive object={lineObj} />;
}

function RadarAxisLine({ angle, radius, label }: { angle: number; radius: number; label: string }) {
  const lineObj = useMemo(() => {
    const pts = [new THREE.Vector3(0, 0.005, 0), new THREE.Vector3(Math.cos(angle) * radius, 0.005, Math.sin(angle) * radius)];
    const geo = new THREE.BufferGeometry().setFromPoints(pts);
    const mat = new THREE.LineBasicMaterial({ color: "#ddd", transparent: true, opacity: 0.3 });
    return new THREE.Line(geo, mat);
  }, [angle, radius]);

  return (
    <group>
      <primitive object={lineObj} />
      <Text position={[Math.cos(angle) * (radius + 0.25), 0.1, Math.sin(angle) * (radius + 0.25)]}
        fontSize={0.1} color="#666" anchorX="center" anchorY="middle">{label}</Text>
    </group>
  );
}

function RadarChart({ active, pipeline }: { active: ActiveExpense[]; pipeline: PipelineExpense[] }) {
  const { activePoints, pipePoints, labels, maxVal } = useMemo(() => {
    const cats = Array.from(new Set([...active.map((e) => e.category), ...pipeline.map((e) => e.category)]));
    if (!cats.length) return { activePoints: [], pipePoints: [], labels: [], maxVal: 1 };
    const aVals = cats.map((c) => active.filter((e) => e.category === c).reduce((s, e) => s + e.monthly, 0));
    const pVals = cats.map((c) => pipeline.filter((e) => e.category === c).reduce((s, e) => s + e.estMonthly, 0));
    const maxV = Math.max(...aVals, ...pVals, 1);
    const radius = 1.5;
    const toPoint = (vals: number[]) =>
      vals.map((v, i) => {
        const a = (i / cats.length) * Math.PI * 2 - Math.PI / 2;
        const r = (v / maxV) * radius;
        return new THREE.Vector3(Math.cos(a) * r, 0.01, Math.sin(a) * r);
      });
    return { activePoints: toPoint(aVals), pipePoints: toPoint(pVals), labels: cats, maxVal: maxV };
  }, [active, pipeline]);

  if (!labels.length) return <EmptyChart text="No data for radar." />;
  const radius = 1.5;

  return (
    <ChartCard className="h-[380px] sm:h-[420px]">
      <Canvas camera={{ position: [0, 3.5, 3.5], fov: 45 }}>
        <StandardLights />
        {/* Grid rings */}
        {[0.25, 0.5, 0.75, 1].map((r) => (
          <Torus key={r} args={[radius * r, 0.005, 8, 64]} rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]}>
            <meshBasicMaterial color="#ddd" transparent opacity={0.4} />
          </Torus>
        ))}
        {/* Axis lines */}
        {labels.map((_, i) => {
          const a = (i / labels.length) * Math.PI * 2 - Math.PI / 2;
          return <RadarAxisLine key={i} angle={a} radius={radius} label={labels[i]} />;
        })}
        {/* Data shapes */}
        {activePoints.length > 0 && <RadarLine points={activePoints} color="#CFE1B9" opacity={0.9} />}
        {pipePoints.length > 0 && <RadarLine points={pipePoints} color="#f87171" opacity={0.6} />}
        {/* Active dots */}
        {activePoints.map((p, i) => (
          <Sphere key={`a-${i}`} args={[0.04, 12, 12]} position={p}>
            <meshStandardMaterial color="#CFE1B9" emissive="#CFE1B9" emissiveIntensity={0.3} />
          </Sphere>
        ))}
        {pipePoints.map((p, i) => (
          <Sphere key={`p-${i}`} args={[0.03, 12, 12]} position={p}>
            <meshStandardMaterial color="#f87171" emissive="#f87171" emissiveIntensity={0.3} />
          </Sphere>
        ))}
        {/* Legend */}
        <Text position={[-2, 0.5, -2]} fontSize={0.1} color="#CFE1B9" anchorX="left">--- Active</Text>
        <Text position={[-2, 0.25, -2]} fontSize={0.1} color="#f87171" anchorX="left">--- Pipeline</Text>
        <OrbitControls enableZoom={false} enablePan={false} minPolarAngle={Math.PI / 6}
          maxPolarAngle={Math.PI / 2.2} autoRotate autoRotateSpeed={0.3} />
      </Canvas>
    </ChartCard>
  );
}

/* ─────────────────────────────────────────────────────────────
   2D Charts — Animated Horizontal Bars & Mini Pie
───────────────────────────────────────────────────────────── */

function HorizontalBarChart({ data, title }: {
  data: { label: string; value: number; color: string }[];
  title: string;
}) {
  const maxVal = Math.max(...data.map((d) => d.value), 1);

  return (
    <motion.div variants={scaleIn} initial="hidden" animate="show"
      className="rounded-xl border border-black/6 bg-white p-5 shadow-sm">
      <h3 className="mb-4 text-sm font-medium text-black/40">{title}</h3>
      <div className="space-y-3">
        {data.map((d, i) => (
          <div key={`${d.label}-${i}`}>
            <div className="mb-1 flex items-center justify-between text-xs">
              <span className="font-medium text-dark-charcoal">{d.label}</span>
              <span className="text-black/40">${d.value}/mo</span>
            </div>
            <div className="h-2.5 w-full overflow-hidden rounded-full bg-black/5">
              <motion.div
                className="h-full rounded-full"
                style={{ backgroundColor: d.color }}
                initial={{ width: 0 }}
                animate={{ width: `${(d.value / maxVal) * 100}%` }}
                transition={{ delay: i * 0.08, duration: 0.6, ease: "easeOut" }}
              />
            </div>
          </div>
        ))}
      </div>
    </motion.div>
  );
}

function MiniDonutCSS({ slices, label, total }: {
  slices: { pct: number; color: string; label: string }[];
  label: string; total: number;
}) {
  let accumulated = 0;
  const gradient = slices.map((s) => {
    const start = accumulated;
    accumulated += s.pct;
    return `${s.color} ${start}% ${accumulated}%`;
  }).join(", ");

  return (
    <motion.div variants={scaleIn} initial="hidden" animate="show"
      className="rounded-xl border border-black/6 bg-white p-5 shadow-sm">
      <h3 className="mb-4 text-sm font-medium text-black/40">{label}</h3>
      <div className="flex items-center gap-6">
        <div className="relative flex-shrink-0">
          <div className="h-28 w-28 rounded-full"
            style={{ background: `conic-gradient(${gradient})` }} />
          <div className="absolute inset-3 flex items-center justify-center rounded-full bg-white">
            <span className="text-lg font-bold text-dark-charcoal">${total}</span>
          </div>
        </div>
        <div className="space-y-1.5 text-xs">
          {slices.map((s) => (
            <div key={s.label} className="flex items-center gap-2">
              <div className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: s.color }} />
              <span className="text-black/50">{s.label}</span>
              <span className="ml-auto font-medium text-dark-charcoal">{s.pct.toFixed(0)}%</span>
            </div>
          ))}
        </div>
      </div>
    </motion.div>
  );
}

function ServiceCountCard({ paid, free }: { paid: number; free: number }) {
  const total = paid + free;
  const paidPct = total > 0 ? (paid / total) * 100 : 0;
  return (
    <motion.div variants={scaleIn} initial="hidden" animate="show"
      className="rounded-xl border border-black/6 bg-white p-5 shadow-sm">
      <h3 className="mb-3 text-sm font-medium text-black/40">Service Breakdown</h3>
      <div className="mb-3 flex items-end gap-2">
        <span className="text-3xl font-bold text-dark-charcoal">{total}</span>
        <span className="mb-1 text-xs text-black/30">total services</span>
      </div>
      <div className="mb-2 h-3 w-full overflow-hidden rounded-full bg-black/5">
        <motion.div className="h-full rounded-full bg-sage" initial={{ width: 0 }}
          animate={{ width: `${paidPct}%` }} transition={{ duration: 0.8, ease: "easeOut" }} />
      </div>
      <div className="flex justify-between text-xs text-black/40">
        <span>{paid} paid</span>
        <span>{free} free</span>
      </div>
    </motion.div>
  );
}

function MonthlyProjectionCard({ monthly }: { monthly: number }) {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return (
    <motion.div variants={scaleIn} initial="hidden" animate="show"
      className="rounded-xl border border-black/6 bg-white p-5 shadow-sm">
      <h3 className="mb-3 text-sm font-medium text-black/40">12-Month Projection</h3>
      <div className="flex items-end gap-1" style={{ height: 80 }}>
        {months.map((m, i) => {
          const variance = 1 + Math.sin(i * 0.8) * 0.15;
          const h = monthly > 0 ? ((monthly * variance) / (monthly * 1.2)) * 100 : 10;
          return (
            <div key={m} className="flex flex-1 flex-col items-center gap-1">
              <motion.div
                className="w-full rounded-t-sm bg-sage"
                initial={{ height: 0 }}
                animate={{ height: `${h}%` }}
                transition={{ delay: i * 0.05, duration: 0.5, ease: "easeOut" }}
                style={{ minHeight: 2 }}
              />
              <span className="text-[8px] text-black/30">{m}</span>
            </div>
          );
        })}
      </div>
      <div className="mt-2 text-right text-xs text-black/30">
        ~${(monthly * 12).toLocaleString()}/yr
      </div>
    </motion.div>
  );
}

function EmptyChart({ text }: { text: string }) {
  return (
    <div className="flex h-[300px] items-center justify-center rounded-xl border border-black/6 bg-white text-sm text-black/30">
      {text}
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Analytics Page — All Charts Combined
───────────────────────────────────────────────────────────── */

function AnalyticsTab({ active, pipeline }: { active: ActiveExpense[]; pipeline: PipelineExpense[] }) {
  const kpi = useMemo(() => computeKPIs(active, pipeline), [active, pipeline]);

  const topServices = useMemo(() =>
    active.filter((e) => e.monthly > 0)
      .sort((a, b) => b.monthly - a.monthly)
      .map((e) => ({ label: e.service, value: e.monthly, color: CHART_COLORS[e.category] || "#CFE1B9" })),
    [active],
  );

  const categorySlices = useMemo(() => {
    const total = active.reduce((s, e) => s + e.monthly, 0);
    if (!total) return [];
    const m = new Map<string, number>();
    active.forEach((e) => m.set(e.category, (m.get(e.category) || 0) + e.monthly));
    return Array.from(m.entries())
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1])
      .map(([l, v]) => ({ label: l, pct: (v / total) * 100, color: CHART_COLORS[l] || "#CFE1B9" }));
  }, [active]);

  const personSlices = useMemo(() => {
    const total = active.reduce((s, e) => s + e.monthly, 0);
    if (!total) return [];
    const m = new Map<string, number>();
    active.forEach((e) => { if (e.monthly > 0) m.set(e.assignedTo, (m.get(e.assignedTo) || 0) + e.monthly); });
    return Array.from(m.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([l, v]) => ({ label: l, pct: (v / total) * 100, color: PERSON_COLORS[l] || "#CFE1B9" }));
  }, [active]);

  const priorityBars = useMemo(() => {
    const groups = { HIGH: 0, MED: 0, LOW: 0 };
    pipeline.forEach((e) => { groups[e.priority] += e.estMonthly; });
    return Object.entries(groups)
      .filter(([, v]) => v > 0)
      .map(([k, v]) => ({ label: k, value: v, color: PRIORITY_COLORS[k as keyof typeof PRIORITY_COLORS] }));
  }, [pipeline]);

  return (
    <motion.div key="analytics" initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 20 }} transition={{ duration: 0.25 }} className="space-y-8">

      {/* Row 1: 2D summary cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <ServiceCountCard paid={kpi.paidServices} free={kpi.freeServices} />
        <MonthlyProjectionCard monthly={kpi.totalMonthly} />
        <MiniDonutCSS slices={categorySlices} label="Spend by Category" total={kpi.totalMonthly} />
        <MiniDonutCSS slices={personSlices} label="Spend by Person" total={kpi.totalMonthly} />
      </div>

      {/* Row 2: Horizontal bars */}
      <div className="grid gap-4 sm:grid-cols-2">
        <HorizontalBarChart data={topServices} title="Top Services by Cost" />
        <HorizontalBarChart data={priorityBars} title="Pipeline by Priority" />
      </div>

      {/* Row 3: 3D Category Bar + Person Donut */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">3D Spend by Category</h2>
        <CategoryBarChart expenses={active} />
      </div>

      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">3D Spend by Person</h2>
        <PersonDonutChart expenses={active} />
      </div>

      {/* Row 4: Bubble Cloud */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">Service Bubble Cloud</h2>
        <p className="mb-2 text-xs text-black/25">Sphere size = monthly cost. Drag to orbit.</p>
        <BubbleCloudChart expenses={active} />
      </div>

      {/* Row 5: Treemap */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">3D Cost Treemap</h2>
        <p className="mb-2 text-xs text-black/25">Block size and height proportional to spend.</p>
        <TreemapChart expenses={active} />
      </div>

      {/* Row 6: Stacked comparison */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">Active vs Pipeline (Stacked)</h2>
        <p className="mb-2 text-xs text-black/25">Solid = active spend. Translucent = pipeline.</p>
        <StackedComparisonChart active={active} pipeline={pipeline} />
      </div>

      {/* Row 7: Budget gauge */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">Budget Ring Gauge</h2>
        <p className="mb-2 text-xs text-black/25">Outer = active. Inner = pipeline proportion.</p>
        <BudgetGaugeChart active={active} pipeline={pipeline} />
      </div>

      {/* Row 8: Radar */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">Category Radar — Active vs Pipeline</h2>
        <p className="mb-2 text-xs text-black/25">Green = current spend. Red = future pipeline.</p>
        <RadarChart active={active} pipeline={pipeline} />
      </div>

      {/* Row 9: Priority towers */}
      <div>
        <h2 className="mb-3 text-sm font-medium text-black/40">Pipeline Priority Towers</h2>
        <p className="mb-2 text-xs text-black/25">Services stacked by priority group.</p>
        <PriorityTowersChart pipeline={pipeline} />
      </div>
    </motion.div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Priority badge
───────────────────────────────────────────────────────────── */

function PriorityBadge({ priority }: { priority: "HIGH" | "MED" | "LOW" }) {
  const styles = {
    HIGH: "bg-red-50 text-red-700 border-red-200",
    MED: "bg-amber-50 text-amber-700 border-amber-200",
    LOW: "bg-gray-50 text-gray-500 border-gray-200",
  };
  return (
    <span className={`inline-block rounded-full border px-2 py-0.5 text-xs font-medium ${styles[priority]}`}>
      {priority}
    </span>
  );
}

/* ─────────────────────────────────────────────────────────────
   Status badge with cycling action
───────────────────────────────────────────────────────────── */

const STATUS_CONFIG: Record<PipelineStatus, { label: string; bg: string; text: string; border: string }> = {
  plan: { label: "Plan", bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  "on-hold": { label: "On Hold", bg: "bg-amber-50", text: "text-amber-700", border: "border-amber-200" },
  active: { label: "Active", bg: "bg-emerald-50", text: "text-emerald-700", border: "border-emerald-200" },
};

function StatusBadge({ status, onCycle }: { status: PipelineStatus; onCycle?: () => void }) {
  const cfg = STATUS_CONFIG[status];
  return (
    <button
      onClick={onCycle}
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium transition-all hover:shadow-sm ${cfg.bg} ${cfg.text} ${cfg.border} ${onCycle ? "cursor-pointer hover:brightness-95" : "cursor-default"}`}
      title={onCycle ? "Click to change status" : undefined}
    >
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${
        status === "plan" ? "bg-blue-400" : status === "on-hold" ? "bg-amber-400" : "bg-emerald-400"
      }`} />
      {cfg.label}
    </button>
  );
}

/* ─────────────────────────────────────────────────────────────
   Password Gate
───────────────────────────────────────────────────────────── */

function PasswordGate({ onAuth }: { onAuth: () => void }) {
  const [value, setValue] = useState("");
  const [error, setError] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (value === PASSWORD) {
      sessionStorage.setItem(AUTH_KEY, "true");
      onAuth();
    } else { setError(true); setValue(""); }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-cream px-4">
      <motion.form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4"
        initial={{ opacity: 0, y: 30, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.5, ease: "easeOut" }}>
        <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }} className="text-center">
          <h1 className="text-2xl font-bold text-dark-charcoal">Admin Access</h1>
          <p className="mt-1 text-sm text-black/50">Enter the password to continue.</p>
        </motion.div>
        <motion.div initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.3 }}>
          <Input type="password" placeholder="Password" value={value}
            onChange={(e) => { setValue(e.target.value); setError(false); }} autoFocus />
        </motion.div>
        <AnimatePresence>
          {error && (
            <motion.p initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }} className="text-center text-sm text-red-500">
              Incorrect password.
            </motion.p>
          )}
        </AnimatePresence>
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }}>
          <Button type="submit" className="w-full">Unlock</Button>
        </motion.div>
      </motion.form>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Expense Modal — Add or Edit
───────────────────────────────────────────────────────────── */

interface ModalProps {
  type: "active" | "pipeline";
  onClose: () => void;
  onSubmit: (expense: ActiveExpense | PipelineExpense) => void;
  initial?: ActiveExpense | PipelineExpense | null;
}

function ExpenseModal({ type, onClose, onSubmit, initial }: ModalProps) {
  const isEdit = !!initial;
  const initActive = initial && "assignedTo" in initial ? initial : null;
  const initPipeline = initial && "estMonthly" in initial ? initial : null;

  const [service, setService] = useState(initial?.service ?? "");
  const [category, setCategory] = useState(initial?.category ?? CATEGORIES[0]);
  const [assignedTo, setAssignedTo] = useState(initActive?.assignedTo ?? "");
  const [monthly, setMonthly] = useState(
    initActive ? String(initActive.monthly) : initPipeline ? String(initPipeline.estMonthly) : "",
  );
  const [note, setNote] = useState(initActive?.note ?? "");
  const [priority, setPriority] = useState<"HIGH" | "MED" | "LOW">(initPipeline?.priority ?? "MED");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!service.trim()) return;
    if (type === "active") {
      onSubmit({ service: service.trim(), category, assignedTo: assignedTo.trim() || "ZuraLog",
        monthly: parseFloat(monthly) || 0, ...(note.trim() ? { note: note.trim() } : {}),
      } as ActiveExpense);
    } else {
      onSubmit({ service: service.trim(), category, estMonthly: parseFloat(monthly) || 0, priority, status: initPipeline?.status ?? "plan" } as PipelineExpense);
    }
    onClose();
  };

  return (
    <motion.div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4 backdrop-blur-sm"
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose}>
      <motion.div className="w-full max-w-md rounded-2xl border border-black/6 bg-white p-6 shadow-xl"
        initial={{ opacity: 0, y: 40, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 40, scale: 0.95 }} transition={{ type: "spring", damping: 25, stiffness: 300 }}
        onClick={(e) => e.stopPropagation()}>
        <h2 className="mb-4 text-lg font-bold text-dark-charcoal">
          {isEdit ? "Edit" : "Add"} {type === "active" ? "Active Expense" : "Pipeline Item"}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-black/40">Service Name</label>
            <Input value={service} onChange={(e) => setService(e.target.value)} placeholder="e.g. AWS Lambda" autoFocus />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-black/40">Category</label>
            <select value={category} onChange={(e) => setCategory(e.target.value)}
              className="flex w-full rounded-md border border-black/10 bg-white px-3 py-2 text-sm text-dark-charcoal focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-peach/40">
              {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
          {type === "active" && (
            <>
              <div>
                <label className="mb-1 block text-xs font-medium text-black/40">Assigned To</label>
                <Input value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)} placeholder="e.g. Fernando" />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-black/40">Note (optional)</label>
                <Input value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. free tier" />
              </div>
            </>
          )}
          <div>
            <label className="mb-1 block text-xs font-medium text-black/40">
              {type === "active" ? "Monthly ($)" : "Est. Monthly ($)"}
            </label>
            <Input type="number" min="0" step="0.01" value={monthly}
              onChange={(e) => setMonthly(e.target.value)} placeholder="0" />
          </div>
          {type === "pipeline" && (
            <div>
              <label className="mb-1 block text-xs font-medium text-black/40">Priority</label>
              <div className="flex gap-2">
                {(["HIGH", "MED", "LOW"] as const).map((p) => (
                  <button key={p} type="button" onClick={() => setPriority(p)}
                    className={`flex-1 rounded-md border px-3 py-2 text-xs font-medium transition-colors ${
                      priority === p
                        ? p === "HIGH" ? "border-red-300 bg-red-50 text-red-700"
                          : p === "MED" ? "border-amber-300 bg-amber-50 text-amber-700"
                          : "border-gray-300 bg-gray-50 text-gray-600"
                        : "border-black/10 bg-white text-black/40 hover:bg-black/5"
                    }`}>{p}</button>
                ))}
              </div>
            </div>
          )}
          <div className="flex gap-2 pt-2">
            <button type="button" onClick={onClose}
              className="flex-1 rounded-md border border-black/10 px-4 py-2 text-sm font-medium text-black/50 transition-colors hover:bg-black/5">
              Cancel
            </button>
            <Button type="submit" className="flex-1">{isEdit ? "Save" : "Add"}</Button>
          </div>
        </form>
      </motion.div>
    </motion.div>
  );
}

/* ─────────────────────────────────────────────────────────────
   KPI Card with animated counter
───────────────────────────────────────────────────────────── */

function KPICard({ label, value, sub, index }: { label: string; value: number; sub?: string; index: number }) {
  const animated = useAnimatedValue(value, 1000);
  return (
    <motion.div className="rounded-xl border border-black/6 bg-white p-4 shadow-sm"
      variants={fadeUp} initial="hidden" animate="show" custom={index}
      whileHover={{ y: -2, boxShadow: "0 4px 20px rgba(0,0,0,0.06)" }}
      transition={{ type: "spring", stiffness: 300 }}>
      <p className="text-xs font-medium text-black/40">{label}</p>
      <p className="mt-1 text-xl font-bold text-dark-charcoal">${animated.toLocaleString()}</p>
      {sub && <p className="mt-0.5 text-[11px] text-black/30">{sub}</p>}
    </motion.div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Tab button
───────────────────────────────────────────────────────────── */

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick}
      className={`relative flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
        active ? "text-dark-charcoal" : "text-black/40 hover:text-dark-charcoal"
      }`}>
      {active && (
        <motion.div layoutId="tab-bg" className="absolute inset-0 rounded-md bg-white shadow-sm"
          transition={{ type: "spring", stiffness: 400, damping: 30 }} />
      )}
      <span className="relative z-10">{children}</span>
    </button>
  );
}

/* ─────────────────────────────────────────────────────────────
   Tables
───────────────────────────────────────────────────────────── */

function ActiveTable({ expenses, onRemove, onEdit }: {
  expenses: ActiveExpense[]; onRemove: (i: number) => void; onEdit: (i: number) => void;
}) {
  return (
    <motion.div className="overflow-x-auto rounded-xl border border-black/6 bg-white shadow-sm"
      initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-black/6 text-xs font-medium text-black/40">
            <th className="px-4 py-3">Service</th><th className="px-4 py-3">Category</th>
            <th className="hidden px-4 py-3 sm:table-cell">Assigned To</th>
            <th className="px-4 py-3 text-right">Monthly</th><th className="w-20 px-2 py-3" />
          </tr>
        </thead>
        <motion.tbody variants={staggerContainer} initial="hidden" animate="show">
          {expenses.map((e, i) => (
            <motion.tr key={`${e.service}-${e.assignedTo}-${i}`} variants={tableRow}
              className="group border-b border-black/4 last:border-0">
              <td className="px-4 py-3 font-medium text-dark-charcoal">{e.service}</td>
              <td className="px-4 py-3 text-black/50">{e.category}</td>
              <td className="hidden px-4 py-3 text-black/50 sm:table-cell">{e.assignedTo}</td>
              <td className="px-4 py-3 text-right font-medium text-dark-charcoal">
                {e.monthly === 0 ? <span className="text-black/30">${e.monthly}{e.note ? ` (${e.note})` : ""}</span> : `$${e.monthly}`}
              </td>
              <td className="px-2 py-3">
                <span className="flex gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                  <button onClick={() => onEdit(i)} className="rounded px-1.5 py-0.5 text-xs text-black/30 transition-colors hover:bg-black/5 hover:text-dark-charcoal" title="Edit">Edit</button>
                  <button onClick={() => onRemove(i)} className="rounded px-1.5 py-0.5 text-xs text-black/30 transition-colors hover:bg-red-50 hover:text-red-600" title="Remove">&times;</button>
                </span>
              </td>
            </motion.tr>
          ))}
        </motion.tbody>
      </table>
    </motion.div>
  );
}

function PipelineTable({ expenses, onRemove, onEdit, onStatusChange, onActivate }: {
  expenses: PipelineExpense[];
  onRemove: (i: number) => void;
  onEdit: (i: number) => void;
  onStatusChange: (i: number) => void;
  onActivate: (i: number) => void;
}) {
  return (
    <motion.div className="overflow-x-auto rounded-xl border border-black/6 bg-white shadow-sm"
      initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-black/6 text-xs font-medium text-black/40">
            <th className="px-4 py-3">Service</th><th className="px-4 py-3">Category</th>
            <th className="px-4 py-3 text-right">Est. Monthly</th>
            <th className="px-4 py-3 text-center">Status</th>
            <th className="px-4 py-3 text-right">Priority</th><th className="w-28 px-2 py-3" />
          </tr>
        </thead>
        <motion.tbody variants={staggerContainer} initial="hidden" animate="show">
          {expenses.map((e, i) => (
            <motion.tr key={`${e.service}-${i}`} variants={tableRow}
              className="group border-b border-black/4 last:border-0">
              <td className="px-4 py-3 font-medium text-dark-charcoal">{e.service}</td>
              <td className="px-4 py-3 text-black/50">{e.category}</td>
              <td className="px-4 py-3 text-right font-medium text-dark-charcoal">${e.estMonthly}</td>
              <td className="px-4 py-3 text-center">
                <StatusBadge status={e.status} onCycle={() => onStatusChange(i)} />
              </td>
              <td className="px-4 py-3 text-right"><PriorityBadge priority={e.priority} /></td>
              <td className="px-2 py-3">
                <span className="flex gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                  <button onClick={() => onActivate(i)}
                    className="rounded px-1.5 py-0.5 text-xs font-medium text-emerald-600 transition-colors hover:bg-emerald-50"
                    title="Activate &amp; transfer to Active Expenses">Activate</button>
                  <button onClick={() => onEdit(i)} className="rounded px-1.5 py-0.5 text-xs text-black/30 transition-colors hover:bg-black/5 hover:text-dark-charcoal" title="Edit">Edit</button>
                  <button onClick={() => onRemove(i)} className="rounded px-1.5 py-0.5 text-xs text-black/30 transition-colors hover:bg-red-50 hover:text-red-600" title="Remove">&times;</button>
                </span>
              </td>
            </motion.tr>
          ))}
        </motion.tbody>
      </table>
    </motion.div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Dashboard
───────────────────────────────────────────────────────────── */

type Tab = "active" | "pipeline" | "analytics";

function Dashboard({ onLock }: { onLock: () => void }) {
  const [tab, setTab] = useState<Tab>("active");
  const [active, setActive] = useState<ActiveExpense[]>([]);
  const [pipeline, setPipeline] = useState<PipelineExpense[]>([]);
  const [modal, setModal] = useState<{ type: "active" | "pipeline"; editIndex?: number } | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => { setActive(loadActive()); setPipeline(loadPipeline()); setLoaded(true); }, []);

  const kpi = useMemo(() => computeKPIs(active, pipeline), [active, pipeline]);

  const handleModalSubmit = useCallback((expense: ActiveExpense | PipelineExpense) => {
    if (!modal) return;
    if (modal.type === "active") {
      setActive(prev => {
        const list = [...prev];
        if (modal.editIndex != null) list[modal.editIndex] = expense as ActiveExpense;
        else list.push(expense as ActiveExpense);
        saveActive(list);
        return list;
      });
    } else {
      setPipeline(prev => {
        const list = [...prev];
        if (modal.editIndex != null) list[modal.editIndex] = expense as PipelineExpense;
        else list.push(expense as PipelineExpense);
        savePipeline(list);
        return list;
      });
    }
  }, [modal]);

  const removeActive = useCallback((i: number) => {
    setActive(prev => {
      const next = prev.filter((_, idx) => idx !== i);
      saveActive(next);
      return next;
    });
  }, []);

  const removePipeline = useCallback((i: number) => {
    setPipeline(prev => {
      const next = prev.filter((_, idx) => idx !== i);
      savePipeline(next);
      return next;
    });
  }, []);

  const cyclePipelineStatus = useCallback((i: number) => {
    setPipeline(prev => {
      const order: PipelineStatus[] = ["plan", "on-hold"];
      const cur = prev[i].status;
      const nextStatus = order[(order.indexOf(cur) + 1) % order.length];
      const next = prev.map((e, idx) => idx === i ? { ...e, status: nextStatus } : e);
      savePipeline(next);
      return next;
    });
  }, []);

  const activatePipeline = useCallback((i: number) => {
    setPipeline(prev => {
      const item = prev[i];
      const newActive: ActiveExpense = {
        service: item.service,
        category: item.category,
        assignedTo: "ZuraLog",
        monthly: item.estMonthly,
      };
      setActive(prevActive => {
        const nextActive = [...prevActive, newActive];
        saveActive(nextActive);
        return nextActive;
      });
      const nextPipeline = prev.filter((_, idx) => idx !== i);
      savePipeline(nextPipeline);
      return nextPipeline;
    });
    setTab("active");
  }, []);

  if (!loaded) return <div className="min-h-screen bg-cream" />;

  return (
    <motion.div className="min-h-screen bg-cream" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.4 }}>
      <motion.header className="sticky top-0 z-20 border-b border-black/6 bg-cream/90 backdrop-blur-md"
        initial={{ y: -40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.4, ease: "easeOut" }}>
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 sm:px-6">
          <h1 className="text-lg font-bold text-dark-charcoal">Expense Dashboard</h1>
          <button onClick={onLock}
            className="rounded-md px-3 py-1.5 text-xs font-medium text-black/50 transition-colors hover:bg-black/5 hover:text-dark-charcoal">
            Lock
          </button>
        </div>
      </motion.header>

      <div className="mx-auto max-w-6xl space-y-6 px-4 py-8 sm:px-6">
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <KPICard label="Monthly Spend" value={kpi.totalMonthly} index={0} />
          <KPICard label="Annual Projection" value={kpi.totalAnnual} index={1} />
          <KPICard label="Fernando / mo" value={kpi.fernando} index={2} />
          <KPICard label="Hyowon / mo" value={kpi.hyowon} index={3} />
          <KPICard label="Pipeline Total" value={kpi.pipelineTotal} sub="if all activated" index={4} />
        </div>

        <div className="flex gap-1 rounded-lg bg-black/5 p-1">
          <TabButton active={tab === "active"} onClick={() => setTab("active")}>Active Expenses</TabButton>
          <TabButton active={tab === "pipeline"} onClick={() => setTab("pipeline")}>Future Pipeline</TabButton>
          <TabButton active={tab === "analytics"} onClick={() => setTab("analytics")}>Analytics</TabButton>
        </div>

        <AnimatePresence mode="wait">
          {tab === "active" && (
            <motion.div key="active" initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }} transition={{ duration: 0.25 }} className="space-y-3">
              <div className="flex justify-end">
                <Button onClick={() => setModal({ type: "active" })}>+ Add Expense</Button>
              </div>
              <ActiveTable expenses={active} onRemove={removeActive}
                onEdit={(i) => setModal({ type: "active", editIndex: i })} />
            </motion.div>
          )}
          {tab === "pipeline" && (
            <motion.div key="pipeline" initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }} transition={{ duration: 0.25 }} className="space-y-3">
              <div className="flex justify-end">
                <Button onClick={() => setModal({ type: "pipeline" })}>+ Add Pipeline</Button>
              </div>
              <PipelineTable expenses={pipeline} onRemove={removePipeline}
                onEdit={(i) => setModal({ type: "pipeline", editIndex: i })}
                onStatusChange={cyclePipelineStatus} onActivate={activatePipeline} />
            </motion.div>
          )}
          {tab === "analytics" && <AnalyticsTab active={active} pipeline={pipeline} />}
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {modal && (
          <ExpenseModal type={modal.type}
            initial={modal.editIndex != null
              ? modal.type === "active" ? active[modal.editIndex] : pipeline[modal.editIndex]
              : null}
            onClose={() => setModal(null)} onSubmit={handleModalSubmit} />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

/* ─────────────────────────────────────────────────────────────
   Page export
───────────────────────────────────────────────────────────── */

export default function ExpensePage() {
  const [authed, setAuthed] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => { setAuthed(sessionStorage.getItem(AUTH_KEY) === "true"); setMounted(true); }, []);

  const handleLock = useCallback(() => { sessionStorage.removeItem(AUTH_KEY); setAuthed(false); }, []);

  if (!mounted) return <div className="min-h-screen bg-cream" />;

  return (
    <AnimatePresence mode="wait">
      {authed ? (
        <motion.div key="dashboard" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
          <Dashboard onLock={handleLock} />
        </motion.div>
      ) : (
        <motion.div key="gate" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
          <PasswordGate onAuth={() => setAuthed(true)} />
        </motion.div>
      )}
    </AnimatePresence>
  );
}

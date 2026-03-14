"use client";

/**
 * LegalPageLayout — shared wrapper for legal / policy pages.
 *
 * Features:
 * - Reading progress bar (sage → lime gradient)
 * - Floating TOC sidebar (desktop) + collapsible dropdown TOC (mobile)
 * - Active section tracking + visited section checkmarks
 * - Scroll-triggered heading reveal animations (GSAP)
 * - Glassmorphic card with gradient section dividers (CSS-only)
 * - Animated page header with staggered entrance
 * - Breadcrumb navigation (Home > Legal > Page Title)
 * - "Updated X days ago" relative date + estimated read time
 * - Text size control (A-/A+) for accessibility
 * - Share button (Web Share API + copy fallback)
 * - Section anchor links on hover (click to copy URL)
 * - Hash-based deep link with section highlight on load
 * - Keyboard navigation (j/k to jump between sections)
 * - Search / filter in TOC sidebar
 * - Cross-page prev/next navigation footer
 * - "Was this helpful?" feedback widget
 * - Sticky mobile section indicator bar
 * - Reading position memory (sessionStorage)
 * - Print / PDF button
 * - Print-friendly styles (via CSS @media print)
 * - Back-to-top floating button
 *
 * No DOM mutation — React's tree stays intact.
 */

import { useEffect, useRef, useState, useCallback, useMemo } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// ── Legal page registry ──────────────────────────────────────────────────────

const LEGAL_PAGES = [
  { href: "/privacy-policy", title: "Privacy Policy" },
  { href: "/terms-of-service", title: "Terms of Service" },
  { href: "/cookie-policy", title: "Cookie Policy" },
  { href: "/community-guidelines", title: "Community Guidelines" },
];

const FONT_SIZES = [14, 15, 16, 17, 18] as const;
const DEFAULT_FONT_SIZE_IDX = 1; // 15px

// ── Types ────────────────────────────────────────────────────────────────────

interface LegalPageLayoutProps {
  title: string;
  lastUpdated: string;
  children: React.ReactNode;
}

interface TocItem {
  id: string;
  text: string;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function getRelativeDate(dateStr: string): string {
  const updated = new Date(`${dateStr}T12:00:00`);
  const now = new Date();
  const diffMs = now.getTime() - updated.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) return "Updated today";
  if (diffDays === 1) return "Updated yesterday";
  if (diffDays < 7) return `Updated ${diffDays} days ago`;
  if (diffDays < 30) {
    const weeks = Math.floor(diffDays / 7);
    return `Updated ${weeks} ${weeks === 1 ? "week" : "weeks"} ago`;
  }
  if (diffDays < 365) {
    const months = Math.floor(diffDays / 30);
    return `Updated ${months} ${months === 1 ? "month" : "months"} ago`;
  }
  const years = Math.floor(diffDays / 365);
  return `Updated ${years} ${years === 1 ? "year" : "years"} ago`;
}

function estimateReadTime(el: HTMLElement): number {
  const text = el.textContent || "";
  const words = text.trim().split(/\s+/).length;
  return Math.max(1, Math.ceil(words / 230));
}

// ── Component ────────────────────────────────────────────────────────────────

export function LegalPageLayout({
  title,
  lastUpdated,
  children,
}: LegalPageLayoutProps) {
  const pathname = usePathname();

  const dateObj = new Date(`${lastUpdated}T12:00:00`);
  const formatted = dateObj.toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const relative = getRelativeDate(lastUpdated);

  // Cross-page nav
  const currentPageIdx = LEGAL_PAGES.findIndex((p) => p.href === pathname);
  const prevPage = currentPageIdx > 0 ? LEGAL_PAGES[currentPageIdx - 1] : null;
  const nextPage =
    currentPageIdx < LEGAL_PAGES.length - 1
      ? LEGAL_PAGES[currentPageIdx + 1]
      : null;

  // Refs
  const proseRef = useRef<HTMLDivElement>(null);
  const headerRef = useRef<HTMLDivElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);
  const mainRef = useRef<HTMLElement>(null);
  const cleanupRef = useRef<(() => void) | null>(null);

  // State
  const [tocItems, setTocItems] = useState<TocItem[]>([]);
  const [activeId, setActiveId] = useState<string>("");
  const [visitedIds, setVisitedIds] = useState<Set<string>>(new Set());
  const [showBackToTop, setShowBackToTop] = useState(false);
  const [readTime, setReadTime] = useState(0);
  const [mobileTocOpen, setMobileTocOpen] = useState(false);
  const [tocSearch, setTocSearch] = useState("");
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<"up" | "down" | null>(null);
  const [fontSizeIdx, setFontSizeIdx] = useState(DEFAULT_FONT_SIZE_IDX);
  const [shareTooltip, setShareTooltip] = useState(false);
  const [showMobileStickyToc, setShowMobileStickyToc] = useState(false);

  // Mark sections as visited when they become active
  useEffect(() => {
    if (activeId) {
      setVisitedIds((prev) => {
        const next = new Set(prev);
        next.add(activeId);
        return next;
      });
    }
  }, [activeId]);

  // Filtered TOC
  const filteredTocItems = useMemo(() => {
    if (!tocSearch.trim()) return tocItems;
    const q = tocSearch.toLowerCase();
    return tocItems.filter((item) => item.text.toLowerCase().includes(q));
  }, [tocItems, tocSearch]);

  // Active section display text (for mobile sticky bar)
  const activeSectionText = useMemo(() => {
    const item = tocItems.find((t) => t.id === activeId);
    return item ? item.text.replace(/^\d+\.\s*/, "") : "";
  }, [tocItems, activeId]);

  // ── Build TOC + animations ─────────────────────────────────────────────
  useEffect(() => {
    const prose = proseRef.current;
    const header = headerRef.current;
    if (!prose || !header) return;

    // Reset
    setActiveId("");
    setVisitedIds(new Set());
    setTocItems([]);
    setTocSearch("");
    setMobileTocOpen(false);
    setFeedback(null);

    // Restore reading position from sessionStorage
    const storageKey = `legal-scroll-${pathname}`;
    const savedScroll = sessionStorage.getItem(storageKey);

    const rafId = requestAnimationFrame(() => {
      setReadTime(estimateReadTime(prose));

      const headings = Array.from(prose.querySelectorAll("h2"));
      const items: TocItem[] = headings
        .map((h2, i) => {
          const id = `section-${i}`;
          h2.id = id;
          const text = h2.textContent || "";
          return text ? { id, text } : null;
        })
        .filter(Boolean) as TocItem[];
      setTocItems(items);

      // Hash-based deep link
      const hash = window.location.hash.replace("#", "");
      if (hash) {
        const target = document.getElementById(hash);
        if (target) {
          setTimeout(() => {
            const y =
              target.getBoundingClientRect().top + window.scrollY - 100;
            window.scrollTo({ top: y, behavior: "smooth" });
            target.classList.add("legal-highlight");
            setTimeout(
              () => target.classList.remove("legal-highlight"),
              2000
            );
          }, 300);
        }
      } else if (savedScroll) {
        // Restore saved position (only if no hash)
        setTimeout(() => {
          window.scrollTo({ top: parseInt(savedScroll, 10) });
        }, 100);
      }

      // Header entrance animation
      const badge = header.querySelector(".legal-badge") as HTMLElement;
      const h1 = header.querySelector("h1") as HTMLElement;
      const breadcrumb = header.querySelector(
        ".legal-breadcrumb"
      ) as HTMLElement;
      const dateLine = header.querySelector(".legal-date") as HTMLElement;
      const meta = header.querySelector(".legal-meta") as HTMLElement;
      const toolbar = header.querySelector(".legal-toolbar") as HTMLElement;
      const divider = header.querySelector(".legal-divider") as HTMLElement;

      [badge, h1, breadcrumb, dateLine, meta, toolbar, divider].forEach(
        (el) => {
          if (el) gsap.set(el, { clearProps: "all" });
        }
      );

      const headerTl = gsap.timeline({ defaults: { ease: "power3.out" } });
      if (breadcrumb)
        headerTl.fromTo(
          breadcrumb,
          { opacity: 0, y: 8 },
          { opacity: 1, y: 0, duration: 0.4 }
        );
      if (badge)
        headerTl.fromTo(
          badge,
          { opacity: 0, y: 12 },
          { opacity: 1, y: 0, duration: 0.5 },
          "-=0.2"
        );
      if (h1)
        headerTl.fromTo(
          h1,
          { opacity: 0, y: 16 },
          { opacity: 1, y: 0, duration: 0.6 },
          "-=0.3"
        );
      if (dateLine)
        headerTl.fromTo(
          dateLine,
          { opacity: 0, y: 8 },
          { opacity: 1, y: 0, duration: 0.4 },
          "-=0.3"
        );
      if (meta)
        headerTl.fromTo(
          meta,
          { opacity: 0, y: 8 },
          { opacity: 1, y: 0, duration: 0.4 },
          "-=0.2"
        );
      if (toolbar)
        headerTl.fromTo(
          toolbar,
          { opacity: 0, y: 8 },
          { opacity: 1, y: 0, duration: 0.4 },
          "-=0.2"
        );
      if (divider)
        headerTl.fromTo(
          divider,
          { scaleX: 0 },
          { scaleX: 1, duration: 0.6, ease: "power2.inOut" },
          "-=0.2"
        );

      // Scroll-reveal for headings
      const triggers: ScrollTrigger[] = [];
      headings.forEach((h2) => {
        gsap.set(h2, { opacity: 0, x: -12 });
        const trigger = ScrollTrigger.create({
          trigger: h2,
          start: "top 90%",
          once: true,
          onEnter: () => {
            gsap.to(h2, {
              opacity: 1,
              x: 0,
              duration: 0.5,
              ease: "power2.out",
            });
          },
        });
        triggers.push(trigger);
      });

      // IntersectionObserver for active section
      const observer = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting) {
              setActiveId(entry.target.id);
            }
          }
        },
        { rootMargin: "-20% 0px -60% 0px" }
      );
      headings.forEach((h2) => observer.observe(h2));

      cleanupRef.current = () => {
        headerTl.kill();
        triggers.forEach((t) => t.kill());
        observer.disconnect();
        headings.forEach((h2) => gsap.set(h2, { clearProps: "all" }));
        [badge, h1, breadcrumb, dateLine, meta, toolbar, divider].forEach(
          (el) => {
            if (el) gsap.set(el, { clearProps: "all" });
          }
        );
      };
    });

    return () => {
      cancelAnimationFrame(rafId);
      cleanupRef.current?.();
      cleanupRef.current = null;
    };
  }, [title, pathname]);

  // ── Save scroll position periodically ──────────────────────────────────
  useEffect(() => {
    const storageKey = `legal-scroll-${pathname}`;
    let ticking = false;

    const saveScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(() => {
          sessionStorage.setItem(storageKey, String(window.scrollY));
          ticking = false;
        });
      }
    };

    window.addEventListener("scroll", saveScroll, { passive: true });
    return () => window.removeEventListener("scroll", saveScroll);
  }, [pathname]);

  // ── Progress bar + back-to-top + mobile sticky TOC ─────────────────────
  useEffect(() => {
    const mobileTocEl = document.querySelector(".legal-toc-mobile");

    const onScroll = () => {
      // Progress bar
      if (mainRef.current && progressRef.current) {
        const rect = mainRef.current.getBoundingClientRect();
        const total = mainRef.current.scrollHeight - window.innerHeight;
        const scrolled = -rect.top;
        const pct =
          total > 0
            ? Math.min(100, Math.max(0, (scrolled / total) * 100))
            : 0;
        progressRef.current.style.width = `${pct}%`;
      }

      // Back to top
      setShowBackToTop(window.scrollY > 600);

      // Mobile sticky TOC — show when mobile TOC scrolls out of view
      if (mobileTocEl) {
        const rect = mobileTocEl.getBoundingClientRect();
        setShowMobileStickyToc(rect.bottom < 0);
      }
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    onScroll();

    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, [tocItems]);

  // ── Keyboard navigation (j/k) ─────────────────────────────────────────
  useEffect(() => {
    if (tocItems.length === 0) return;

    const onKeyDown = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      if (e.key !== "j" && e.key !== "k") return;

      e.preventDefault();
      const currentIdx = tocItems.findIndex((item) => item.id === activeId);
      let nextIdx: number;

      if (e.key === "j") {
        nextIdx =
          currentIdx < tocItems.length - 1 ? currentIdx + 1 : currentIdx;
      } else {
        nextIdx = currentIdx > 0 ? currentIdx - 1 : 0;
      }

      scrollToSection(tocItems[nextIdx].id);
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [tocItems, activeId]);

  // ── Actions ────────────────────────────────────────────────────────────

  const scrollToTop = useCallback(() => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, []);

  const scrollToSection = useCallback((id: string) => {
    const el = document.getElementById(id);
    if (el) {
      const y = el.getBoundingClientRect().top + window.scrollY - 100;
      window.scrollTo({ top: y, behavior: "smooth" });
      el.classList.add("legal-highlight");
      setTimeout(() => el.classList.remove("legal-highlight"), 1500);
    }
    setMobileTocOpen(false);
  }, []);

  const copyAnchorLink = useCallback(
    (id: string) => {
      const url = `${window.location.origin}${pathname}#${id}`;
      navigator.clipboard.writeText(url).then(() => {
        setCopiedId(id);
        setTimeout(() => setCopiedId(null), 2000);
      });
    },
    [pathname]
  );

  const handleShare = useCallback(async () => {
    const url = `${window.location.origin}${pathname}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: `${title} | ZuraLog`, url });
      } catch {
        // User cancelled — no action needed
      }
    } else {
      await navigator.clipboard.writeText(url);
      setShareTooltip(true);
      setTimeout(() => setShareTooltip(false), 2000);
    }
  }, [pathname, title]);

  const decreaseFontSize = useCallback(() => {
    setFontSizeIdx((i) => Math.max(0, i - 1));
  }, []);

  const increaseFontSize = useCallback(() => {
    setFontSizeIdx((i) => Math.min(FONT_SIZES.length - 1, i + 1));
  }, []);

  // ── TOC list renderer ──────────────────────────────────────────────────
  const renderTocList = (items: TocItem[]) => (
    <ul className="space-y-0.5">
      {items.map((item) => {
        const isVisited =
          visitedIds.has(item.id) && item.id !== activeId;
        return (
          <li key={item.id} className="flex items-center gap-1 group/toc">
            {/* Visited checkmark / active dot */}
            <span className="w-3.5 shrink-0 flex items-center justify-center">
              {item.id === activeId ? (
                <span className="h-1.5 w-1.5 rounded-full bg-[#D4F291]" />
              ) : isVisited ? (
                <svg
                  viewBox="0 0 16 16"
                  fill="none"
                  stroke="#CFE1B9"
                  strokeWidth="2"
                  className="h-2.5 w-2.5"
                >
                  <path
                    d="M3 8.5l3 3 7-7"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              ) : (
                <span className="h-1 w-1 rounded-full bg-black/10" />
              )}
            </span>
            <button
              onClick={() => scrollToSection(item.id)}
              className={`
                flex-1 text-left text-[12px] leading-snug px-2 py-1.5 rounded-lg
                transition-all duration-200
                ${
                  activeId === item.id
                    ? "bg-[#E8F5A8]/30 text-[#1A1A1A] font-medium"
                    : isVisited
                      ? "text-black/30 hover:text-black/50 hover:bg-black/[0.02]"
                      : "text-black/40 hover:text-black/60 hover:bg-black/[0.02]"
                }
              `}
            >
              {item.text.replace(/^\d+\.\s*/, "")}
            </button>
            <button
              onClick={() => copyAnchorLink(item.id)}
              title="Copy link to section"
              className={`
                shrink-0 p-1 rounded transition-all duration-200
                ${
                  copiedId === item.id
                    ? "opacity-100 text-[#7ab33b]"
                    : "opacity-0 group-hover/toc:opacity-60 hover:!opacity-100 text-black/30"
                }
              `}
            >
              {copiedId === item.id ? (
                <svg
                  viewBox="0 0 16 16"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  className="h-3 w-3"
                >
                  <path
                    d="M3 8.5l3 3 7-7"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              ) : (
                <svg
                  viewBox="0 0 16 16"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  className="h-3 w-3"
                >
                  <path
                    d="M6.5 9.5l3-3M7 11l-1.15 1.15a2 2 0 01-2.83 0L2.85 12a2 2 0 010-2.83L4 8m5-1l1.15-1.15a2 2 0 012.83 0l.17.15a2 2 0 010 2.83L12 10"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              )}
            </button>
          </li>
        );
      })}
    </ul>
  );

  // ── Toolbar button component ───────────────────────────────────────────
  const ToolbarBtn = ({
    onClick,
    title: btnTitle,
    disabled,
    children: btnChildren,
  }: {
    onClick: () => void;
    title: string;
    disabled?: boolean;
    children: React.ReactNode;
  }) => (
    <button
      onClick={onClick}
      title={btnTitle}
      disabled={disabled}
      className="flex items-center justify-center h-8 w-8 rounded-lg border border-black/[0.06] bg-white/60 text-black/35 transition-all hover:bg-[#E8F5A8]/15 hover:text-black/55 hover:border-[#CFE1B9]/30 disabled:opacity-30 disabled:pointer-events-none"
    >
      {btnChildren}
    </button>
  );

  // ── Render ─────────────────────────────────────────────────────────────

  return (
    <>
      {/* Reading progress bar */}
      <div
        aria-hidden="true"
        className="legal-progress fixed inset-x-0 top-0 z-[9999] h-[3px] pointer-events-none"
        style={{ background: "rgba(207, 225, 185, 0.12)" }}
      >
        <div
          ref={progressRef}
          className="h-full w-0"
          style={{
            background:
              "linear-gradient(to right, #CFE1B9, #D4F291, #E8F5A8)",
            boxShadow:
              "0 0 10px 2px rgba(212, 242, 145, 0.6), 0 0 20px 4px rgba(207, 225, 185, 0.3)",
            transition: "width 80ms linear",
          }}
        />
      </div>

      {/* Background */}
      <div
        aria-hidden="true"
        className="legal-bg fixed inset-0 -z-10 pointer-events-none"
        style={{ backgroundColor: "#FAFAF5" }}
      />

      {/* ── Mobile sticky section indicator ─────────────────────── */}
      <div
        className={`
          legal-mobile-sticky xl:hidden fixed top-0 inset-x-0 z-[9998]
          border-b border-black/[0.04] bg-white/80 backdrop-blur-xl
          transition-all duration-300
          ${showMobileStickyToc && activeSectionText ? "translate-y-0 opacity-100" : "-translate-y-full opacity-0"}
        `}
      >
        <div className="mx-auto max-w-6xl px-6 py-2.5 flex items-center justify-between">
          <button
            onClick={() => {
              window.scrollTo({ top: 0, behavior: "smooth" });
            }}
            className="text-[11px] font-medium text-black/50 truncate max-w-[60%] text-left hover:text-black/70 transition-colors"
          >
            {activeSectionText}
          </button>
          <button
            onClick={() => {
              setMobileTocOpen(true);
              // Scroll to the mobile TOC
              const tocEl = document.querySelector(".legal-toc-mobile");
              if (tocEl) {
                const y =
                  tocEl.getBoundingClientRect().top + window.scrollY - 80;
                window.scrollTo({ top: y, behavior: "smooth" });
              }
            }}
            className="text-[10px] font-semibold uppercase tracking-widest text-black/30 hover:text-black/50 transition-colors"
          >
            All sections
          </button>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col">
        <Navbar />

        <main ref={mainRef} className="flex-1 pt-28 pb-24">
          <div className="mx-auto max-w-6xl px-6 lg:px-8">
            <div className="flex gap-12">
              {/* ── TOC Sidebar — desktop ──────────────────────── */}
              {tocItems.length > 0 && (
                <aside className="hidden xl:block w-56 shrink-0 legal-toc-sidebar">
                  <nav className="sticky top-28">
                    <div className="rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl p-5 shadow-sm">
                      <p className="text-[10px] font-semibold uppercase tracking-widest text-black/30 mb-3">
                        On this page
                      </p>

                      <div className="relative mb-3">
                        <svg
                          viewBox="0 0 16 16"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="1.5"
                          className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3 w-3 text-black/25 pointer-events-none"
                        >
                          <circle cx="7" cy="7" r="4.5" />
                          <path d="M10.5 10.5L14 14" strokeLinecap="round" />
                        </svg>
                        <input
                          type="text"
                          value={tocSearch}
                          onChange={(e) => setTocSearch(e.target.value)}
                          placeholder="Search sections..."
                          className="w-full rounded-lg border border-black/[0.04] bg-white/60 py-1.5 pl-8 pr-3 text-[11px] text-black/60 placeholder:text-black/25 outline-none transition-all focus:border-[#CFE1B9]/50 focus:ring-1 focus:ring-[#CFE1B9]/30"
                        />
                      </div>

                      <div className="max-h-[calc(100vh-16rem)] overflow-y-auto legal-toc-scroll">
                        {filteredTocItems.length > 0 ? (
                          renderTocList(filteredTocItems)
                        ) : (
                          <p className="text-[11px] text-black/25 px-3 py-2">
                            No matching sections
                          </p>
                        )}
                      </div>

                      {/* Progress + keyboard hint */}
                      <div className="mt-3 pt-3 border-t border-black/[0.04] flex items-center justify-between">
                        <span className="text-[10px] text-black/20">
                          {visitedIds.size}/{tocItems.length} read
                        </span>
                        <div className="flex items-center gap-1.5 text-[10px] text-black/20">
                          <kbd className="inline-flex items-center justify-center h-4 min-w-[16px] rounded border border-black/[0.08] bg-black/[0.02] px-1 font-mono text-[9px]">
                            j
                          </kbd>
                          <kbd className="inline-flex items-center justify-center h-4 min-w-[16px] rounded border border-black/[0.08] bg-black/[0.02] px-1 font-mono text-[9px]">
                            k
                          </kbd>
                        </div>
                      </div>
                    </div>
                  </nav>
                </aside>
              )}

              {/* ── Main content ───────────────────────────────── */}
              <div className="min-w-0 flex-1 max-w-[720px]">
                {/* Header */}
                <div ref={headerRef} className="mb-10 pb-8">
                  {/* Breadcrumb */}
                  <nav
                    aria-label="Breadcrumb"
                    className="legal-breadcrumb mb-5 opacity-0"
                  >
                    <ol className="flex items-center gap-1.5 text-xs text-black/35">
                      <li>
                        <Link
                          href="/"
                          className="transition-colors hover:text-[#2D2D2D]"
                        >
                          Home
                        </Link>
                      </li>
                      <li aria-hidden="true">
                        <svg
                          viewBox="0 0 16 16"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="1.5"
                          className="h-3 w-3"
                        >
                          <path
                            d="M6 4l4 4-4 4"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />
                        </svg>
                      </li>
                      <li>
                        <span className="text-black/25">Legal</span>
                      </li>
                      <li aria-hidden="true">
                        <svg
                          viewBox="0 0 16 16"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="1.5"
                          className="h-3 w-3"
                        >
                          <path
                            d="M6 4l4 4-4 4"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />
                        </svg>
                      </li>
                      <li aria-current="page">
                        <span className="font-medium text-black/50">
                          {title}
                        </span>
                      </li>
                    </ol>
                  </nav>

                  {/* Badge */}
                  <span className="legal-badge inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60 opacity-0">
                    <span className="h-1.5 w-1.5 rounded-full bg-[#CFE1B9] animate-pulse" />
                    Legal
                  </span>
                  <h1 className="mt-4 text-3xl font-bold tracking-tight text-[#1A1A1A] sm:text-4xl opacity-0">
                    {title}
                  </h1>
                  <p className="legal-date mt-3 text-sm text-black/40 opacity-0">
                    Last updated: {formatted}
                  </p>

                  {/* Relative date + read time */}
                  <div className="legal-meta mt-2 flex items-center gap-3 text-xs text-black/30 opacity-0">
                    <span className="inline-flex items-center gap-1.5">
                      <svg
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        className="h-3 w-3"
                      >
                        <circle cx="8" cy="8" r="6" />
                        <path
                          d="M8 5v3.5l2.5 1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                      {relative}
                    </span>
                    {readTime > 0 && (
                      <>
                        <span className="text-black/10">|</span>
                        <span className="inline-flex items-center gap-1.5">
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="h-3 w-3"
                          >
                            <path
                              d="M2 3h12M2 7h8M2 11h10M2 15h6"
                              strokeLinecap="round"
                            />
                          </svg>
                          ~{readTime} min read
                        </span>
                      </>
                    )}
                  </div>

                  {/* ── Toolbar: text size + share + print ─────── */}
                  <div className="legal-toolbar mt-4 flex items-center gap-2 opacity-0">
                    {/* Text size */}
                    <div className="flex items-center gap-1 rounded-lg border border-black/[0.04] bg-white/40 p-0.5">
                      <ToolbarBtn
                        onClick={decreaseFontSize}
                        title="Decrease text size"
                        disabled={fontSizeIdx === 0}
                      >
                        <span className="text-[10px] font-bold">A-</span>
                      </ToolbarBtn>
                      <span className="text-[10px] text-black/25 w-6 text-center font-mono">
                        {FONT_SIZES[fontSizeIdx]}
                      </span>
                      <ToolbarBtn
                        onClick={increaseFontSize}
                        title="Increase text size"
                        disabled={fontSizeIdx === FONT_SIZES.length - 1}
                      >
                        <span className="text-[12px] font-bold">A+</span>
                      </ToolbarBtn>
                    </div>

                    <div className="h-5 w-px bg-black/[0.06]" />

                    {/* Share */}
                    <div className="relative">
                      <ToolbarBtn onClick={handleShare} title="Share this page">
                        <svg
                          viewBox="0 0 16 16"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="1.5"
                          className="h-3.5 w-3.5"
                        >
                          <path
                            d="M4 8v5a1 1 0 001 1h6a1 1 0 001-1V8M11 4L8 1M8 1L5 4M8 1v9"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />
                        </svg>
                      </ToolbarBtn>
                      {shareTooltip && (
                        <span className="absolute -bottom-8 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-md bg-[#2D2D2D] px-2.5 py-1 text-[10px] text-white shadow-lg">
                          Link copied!
                        </span>
                      )}
                    </div>

                    {/* Print */}
                    <ToolbarBtn
                      onClick={() => window.print()}
                      title="Print / Save as PDF"
                    >
                      <svg
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        className="h-3.5 w-3.5"
                      >
                        <path
                          d="M4 11H2.5A1.5 1.5 0 011 9.5v-4A1.5 1.5 0 012.5 4H4M12 4h1.5A1.5 1.5 0 0115 5.5v4a1.5 1.5 0 01-1.5 1.5H12M4 4V1h8v3M4 9h8v6H4V9z"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                    </ToolbarBtn>
                  </div>

                  {/* Gradient divider */}
                  <div
                    className="legal-divider mt-6 h-px w-full origin-left"
                    style={{
                      background:
                        "linear-gradient(to right, transparent, #CFE1B9, #D4F291, #E8F5A8, transparent)",
                    }}
                  />
                </div>

                {/* ── Mobile TOC dropdown ──────────────────────── */}
                {tocItems.length > 0 && (
                  <div className="xl:hidden mb-6 legal-toc-mobile">
                    <button
                      onClick={() => setMobileTocOpen(!mobileTocOpen)}
                      className="w-full flex items-center justify-between rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl px-5 py-3.5 shadow-sm transition-colors hover:bg-white/70"
                    >
                      <span className="text-[12px] font-semibold uppercase tracking-widest text-black/30">
                        On this page ({visitedIds.size}/{tocItems.length})
                      </span>
                      <svg
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        className={`h-3.5 w-3.5 text-black/30 transition-transform duration-200 ${
                          mobileTocOpen ? "rotate-180" : ""
                        }`}
                      >
                        <path
                          d="M4 6l4 4 4-4"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                    </button>

                    {mobileTocOpen && (
                      <div className="mt-2 rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl p-4 shadow-sm">
                        <div className="relative mb-3">
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3 w-3 text-black/25 pointer-events-none"
                          >
                            <circle cx="7" cy="7" r="4.5" />
                            <path
                              d="M10.5 10.5L14 14"
                              strokeLinecap="round"
                            />
                          </svg>
                          <input
                            type="text"
                            value={tocSearch}
                            onChange={(e) => setTocSearch(e.target.value)}
                            placeholder="Search sections..."
                            className="w-full rounded-lg border border-black/[0.04] bg-white/60 py-1.5 pl-8 pr-3 text-[12px] text-black/60 placeholder:text-black/25 outline-none transition-all focus:border-[#CFE1B9]/50 focus:ring-1 focus:ring-[#CFE1B9]/30"
                          />
                        </div>
                        <div className="max-h-64 overflow-y-auto">
                          {filteredTocItems.length > 0 ? (
                            renderTocList(filteredTocItems)
                          ) : (
                            <p className="text-[11px] text-black/25 px-3 py-2">
                              No matching sections
                            </p>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* ── Prose container ──────────────────────────── */}
                <div className="legal-card rounded-3xl border border-black/[0.04] bg-white/50 backdrop-blur-xl p-8 sm:p-10 shadow-sm">
                  <div
                    ref={proseRef}
                    className="prose-legal"
                    style={{ fontSize: `${FONT_SIZES[fontSizeIdx]}px` }}
                  >
                    {children}
                  </div>
                </div>

                {/* ── Feedback ─────────────────────────────────── */}
                <div className="legal-feedback mt-6 flex items-center justify-center gap-4 rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl px-6 py-4 shadow-sm">
                  {feedback === null ? (
                    <>
                      <span className="text-[13px] text-black/40">
                        Was this page helpful?
                      </span>
                      <div className="flex gap-2">
                        <button
                          onClick={() => setFeedback("up")}
                          className="flex items-center gap-1.5 rounded-lg border border-black/[0.06] bg-white/60 px-3 py-1.5 text-[12px] text-black/40 transition-all hover:border-[#CFE1B9]/40 hover:bg-[#E8F5A8]/10 hover:text-black/60"
                        >
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="h-3.5 w-3.5"
                          >
                            <path
                              d="M5 9V14H3a1 1 0 01-1-1v-3a1 1 0 011-1h2zm0 0l2.5-5a1.5 1.5 0 011.5-1h.38a1 1 0 01.97 1.24L9.5 7H13a1 1 0 011 1.11l-.77 5A1 1 0 0112.23 14H5"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                          Yes
                        </button>
                        <button
                          onClick={() => setFeedback("down")}
                          className="flex items-center gap-1.5 rounded-lg border border-black/[0.06] bg-white/60 px-3 py-1.5 text-[12px] text-black/40 transition-all hover:border-black/[0.1] hover:bg-black/[0.02] hover:text-black/60"
                        >
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="h-3.5 w-3.5"
                          >
                            <path
                              d="M11 7V2h2a1 1 0 011 1v3a1 1 0 01-1 1h-2zm0 0L8.5 12a1.5 1.5 0 01-1.5 1h-.38a1 1 0 01-.97-1.24L6.5 9H3a1 1 0 01-1-1.11l.77-5A1 1 0 013.77 2H11"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                          No
                        </button>
                      </div>
                    </>
                  ) : (
                    <span className="text-[13px] text-black/40">
                      {feedback === "up"
                        ? "Thanks for your feedback!"
                        : "Thanks — we'll work on improving this page."}
                    </span>
                  )}
                </div>

                {/* ── Cross-page prev/next ─────────────────────── */}
                {(prevPage || nextPage) && (
                  <div className="legal-cross-nav mt-6 grid grid-cols-2 gap-4">
                    {prevPage ? (
                      <Link
                        href={prevPage.href}
                        className="group flex flex-col rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl px-5 py-4 shadow-sm transition-all hover:bg-white/70 hover:shadow-md"
                      >
                        <span className="text-[10px] font-semibold uppercase tracking-widest text-black/25 mb-1">
                          Previous
                        </span>
                        <span className="flex items-center gap-2 text-[13px] font-medium text-black/50 group-hover:text-[#1A1A1A] transition-colors">
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="h-3 w-3 shrink-0 transition-transform group-hover:-translate-x-0.5"
                          >
                            <path
                              d="M10 12L6 8l4-4"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                          {prevPage.title}
                        </span>
                      </Link>
                    ) : (
                      <div />
                    )}
                    {nextPage ? (
                      <Link
                        href={nextPage.href}
                        className="group flex flex-col items-end rounded-2xl border border-black/[0.04] bg-white/50 backdrop-blur-xl px-5 py-4 shadow-sm transition-all hover:bg-white/70 hover:shadow-md"
                      >
                        <span className="text-[10px] font-semibold uppercase tracking-widest text-black/25 mb-1">
                          Next
                        </span>
                        <span className="flex items-center gap-2 text-[13px] font-medium text-black/50 group-hover:text-[#1A1A1A] transition-colors">
                          {nextPage.title}
                          <svg
                            viewBox="0 0 16 16"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            className="h-3 w-3 shrink-0 transition-transform group-hover:translate-x-0.5"
                          >
                            <path
                              d="M6 4l4 4-4 4"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                        </span>
                      </Link>
                    ) : (
                      <div />
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        </main>

        <Footer />
      </div>

      {/* ── Back to top ──────────────────────────────────────── */}
      <button
        onClick={scrollToTop}
        aria-label="Back to top"
        className={`
          legal-back-to-top
          fixed bottom-8 right-8 z-50 flex h-10 w-10 items-center justify-center
          rounded-full border border-black/[0.06] bg-white/70 backdrop-blur-xl
          shadow-lg transition-all duration-300
          hover:bg-[#E8F5A8]/30 hover:shadow-xl hover:scale-110
          ${showBackToTop ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4 pointer-events-none"}
        `}
      >
        <svg
          viewBox="0 0 16 16"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          className="h-4 w-4 text-[#2D2D2D]"
        >
          <path
            d="M4 10l4-4 4 4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>
    </>
  );
}

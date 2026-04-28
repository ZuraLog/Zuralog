"use client";

import { type ReactNode } from "react";

interface PhoneFrameProps {
  children: ReactNode;
  className?: string;
  style?: React.CSSProperties;
}

export function PhoneFrame({ children, className = "", style }: PhoneFrameProps) {
  return (
    <div
      className={`relative flex-shrink-0 ${className}`}
      style={style}
    >
      {/* Outer bezel */}
      <div
        className="relative overflow-hidden rounded-[2.8rem]"
        style={{
          background: "#1a1a1a",
          border: "2.5px solid #2a2a2a",
          boxShadow:
            "0 0 0 1px rgba(255,255,255,0.05) inset, 0 20px 60px rgba(0,0,0,0.5)",
        }}
      >
        {/* Dynamic Island */}
        <div
          className="absolute left-1/2 top-3 z-20 -translate-x-1/2 rounded-full"
          style={{
            width: 72,
            height: 20,
            backgroundColor: "#000",
          }}
        />

        {/* Screen area */}
        <div className="relative m-[3px] overflow-hidden rounded-[2.6rem]" style={{ backgroundColor: "#161618" }}>
          {/* Status bar */}
          <div className="relative z-10 flex items-center justify-between px-7 pb-1 pt-4">
            <span className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>
              9:41
            </span>
            <div className="flex items-center gap-1">
              {/* Signal bars */}
              <svg width="14" height="10" viewBox="0 0 14 10" fill="#F0EEE9">
                <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
                <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
                <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
                <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
              </svg>
              {/* Battery */}
              <svg width="14" height="10" viewBox="0 0 24 12" fill="#F0EEE9">
                <rect x="0" y="1" width="20" height="10" rx="2" stroke="#F0EEE9" strokeWidth="1.5" fill="none" />
                <rect x="21" y="4" width="2" height="4" rx="1" />
                <rect x="2" y="3" width="14" height="6" rx="1" />
              </svg>
            </div>
          </div>

          {/* Content slot */}
          <div className="relative" style={{ minHeight: 420 }}>
            {children}
          </div>

          {/* Home indicator */}
          <div
            className="mx-auto mb-2 mt-1 rounded-full"
            style={{ width: 100, height: 4, backgroundColor: "rgba(240,238,233,0.2)" }}
          />
        </div>
      </div>
    </div>
  );
}

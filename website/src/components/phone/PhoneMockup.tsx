// website/src/components/phone/PhoneMockup.tsx
"use client";

import { forwardRef } from "react";
import { DeviceFrameset } from "react-device-frameset";

// iPhone X native CSS dimensions (content-box sizing):
// content area: 375 × 812 px
// padding: 26px all sides
// total outer frame: 427 × 864 px
const NATIVE_W = 427;
const NATIVE_H = 864;

export interface PhoneMockupProps {
  children?: React.ReactNode;
  // Desired rendered width of the full device frame (including bezel).
  // Height is derived from the 427/864 aspect ratio.
  // Defaults to NATIVE_W (427) — full size with no scaling.
  // Use CSS transform scale so notch/buttons stay proportional.
  frameWidth?: number;
}

export const PhoneMockup = forwardRef<HTMLDivElement, PhoneMockupProps>(
  function PhoneMockup({ children, frameWidth = NATIVE_W }, ref) {
    const scale = frameWidth / NATIVE_W;
    const frameHeight = Math.round(NATIVE_H * scale);

    return (
      // Outer div takes the correct layout space at the scaled size.
      <div
        ref={ref}
        style={{ width: frameWidth, height: frameHeight, overflow: "visible" }}
      >
        {/* Inner div renders at native size, then scaled — preserves all
            hardcoded px positions (notch, buttons, shadows). */}
        <div
          style={{
            width: NATIVE_W,
            height: NATIVE_H,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          <DeviceFrameset device="iPhone X" color="black">
            {children}
          </DeviceFrameset>
        </div>
      </div>
    );
  }
);

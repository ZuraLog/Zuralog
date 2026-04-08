// website/src/components/phone/PhoneMockup.tsx
"use client";

import { forwardRef } from "react";
import { IPhoneMockup } from "react-device-mockup";

export interface PhoneMockupProps {
  children?: React.ReactNode;
  /** Width of the phone screen area in px. Phone frame scales around this. Default: 290 */
  screenWidth?: number;
}

export const PhoneMockup = forwardRef<HTMLDivElement, PhoneMockupProps>(
  function PhoneMockup({ children, screenWidth = 290 }, ref) {
    return (
      <div ref={ref} className="inline-block">
        <IPhoneMockup screenWidth={screenWidth} screenType="island">
          {children}
        </IPhoneMockup>
      </div>
    );
  }
);

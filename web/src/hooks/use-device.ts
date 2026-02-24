/**
 * useDevice — detects device capabilities for adaptive rendering.
 *
 * Used to downgrade 3D complexity on mobile and low-power devices,
 * preventing performance issues on phones/tablets.
 */
'use client';

import { useEffect, useState } from 'react';

export interface DeviceInfo {
  /** True on screens ≤ 768px wide */
  isMobile: boolean;
  /** True on screens ≤ 1024px wide */
  isTablet: boolean;
  /** True when user has requested reduced motion */
  prefersReducedMotion: boolean;
  /** Estimated GPU performance tier: low | medium | high */
  gpuTier: 'low' | 'medium' | 'high';
  /** True when device pixel ratio ≥ 2 (retina) */
  isRetina: boolean;
}

/**
 * Returns static device information hydrated after first mount.
 * Returns conservative defaults (mobile=false, reduced motion=false) during SSR.
 */
export function useDevice(): DeviceInfo {
  const [info, setInfo] = useState<DeviceInfo>({
    isMobile: false,
    isTablet: false,
    prefersReducedMotion: false,
    gpuTier: 'high',
    isRetina: false,
  });

  useEffect(() => {
    const mq = (q: string) => window.matchMedia(q).matches;
    const isMobile = mq('(max-width: 768px)');
    const isTablet = mq('(max-width: 1024px)');
    const prefersReducedMotion = mq('(prefers-reduced-motion: reduce)');
    const isRetina = window.devicePixelRatio >= 2;

    // Heuristic GPU tier based on device class
    let gpuTier: DeviceInfo['gpuTier'] = 'high';
    if (isMobile) gpuTier = 'low';
    else if (isTablet) gpuTier = 'medium';

    setInfo({ isMobile, isTablet, prefersReducedMotion, gpuTier, isRetina });
  }, []);

  return info;
}

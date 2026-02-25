/**
 * FounderPhoto — client component that renders a founder's photo with an
 * initials fallback when the image file is not yet available.
 *
 * Marked 'use client' because it uses the onError event handler on <Image>.
 */
'use client';

import { useState } from 'react';
import Image from 'next/image';

interface FounderPhotoProps {
  /** Path to the photo in /public (e.g. "/founders/hyowon.jpg") */
  src: string;
  /** Full name for the alt attribute */
  name: string;
  /** Two-letter initials shown until the real photo loads */
  initials: string;
}

/**
 * Renders a founder's headshot inside a fixed-size container.
 * Falls back to a styled initials circle when the image cannot be loaded.
 *
 * @param src      - Public image path
 * @param name     - Full name for accessibility
 * @param initials - Two-letter fallback text
 */
export function FounderPhoto({ src, name, initials }: FounderPhotoProps) {
  const [hasError, setHasError] = useState(false);

  return (
    <div className="relative h-16 w-16 shrink-0 overflow-hidden rounded-2xl border border-black/[0.06] bg-[#E8F5A8]/30">
      {!hasError ? (
        <Image
          src={src}
          alt={`Photo of ${name}`}
          fill
          className="object-cover"
          onError={() => setHasError(true)}
        />
      ) : (
        <div className="flex h-full w-full items-center justify-center text-sm font-semibold text-[#2D2D2D]/50">
          {initials}
        </div>
      )}
    </div>
  );
}

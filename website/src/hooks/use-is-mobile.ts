/**
 * useIsMobile — convenience hook for the mobile breakpoint.
 *
 * Returns `true` when viewport width < 768px (below Tailwind `md:`).
 * Safe for SSR — returns `false` on the server.
 */

import { useMediaQuery } from './use-media-query';

export function useIsMobile(): boolean {
    return useMediaQuery('(max-width: 767px)');
}

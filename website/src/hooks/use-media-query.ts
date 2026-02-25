/**
 * useMediaQuery — reactive CSS media-query hook.
 *
 * Returns `true` when the given media query string matches.
 * Uses `window.matchMedia` with an event listener for live updates.
 * Returns `false` during SSR (no window).
 *
 * NOTE: On the initial client render, this always returns `false` (the SSR
 * default) and corrects itself after mount. Prefer this hook only for skipping
 * heavy renders (e.g. 3D models), not for toggling visible UI elements where
 * a one-frame flash would be noticeable.
 *
 * @param query - CSS media query string, e.g. "(max-width: 767px)"
 * @returns Whether the media query currently matches.
 */

import { useState, useEffect } from 'react';

function getSnapshot(query: string): boolean {
    if (typeof window === 'undefined') return false;
    return window.matchMedia(query).matches;
}

export function useMediaQuery(query: string): boolean {
    const [matches, setMatches] = useState(() => getSnapshot(query));

    useEffect(() => {
        const mql = window.matchMedia(query);
        const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
        mql.addEventListener('change', handler);
        return () => mql.removeEventListener('change', handler);
    }, [query]);

    return matches;
}

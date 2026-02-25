/**
 * useMediaQuery — reactive CSS media-query hook.
 *
 * Returns `true` when the given media query string matches.
 * Uses `window.matchMedia` with an event listener for live updates.
 * Returns `false` during SSR (no window).
 *
 * @param query - CSS media query string, e.g. "(max-width: 767px)"
 * @returns Whether the media query currently matches.
 */

import { useState, useEffect } from 'react';

export function useMediaQuery(query: string): boolean {
    const [matches, setMatches] = useState(false);

    useEffect(() => {
        const mql = window.matchMedia(query);
        setMatches(mql.matches);

        const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
        mql.addEventListener('change', handler);
        return () => mql.removeEventListener('change', handler);
    }, [query]);

    return matches;
}

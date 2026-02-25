/**
 * loading-bridge.ts
 *
 * Module-level singleton that bridges load progress from inside the R3F Canvas
 * (where useProgress works) to the LoadingScreen outside it.
 *
 * Usage:
 *   Inside Canvas: import { loadingBridge } from '@/lib/loading-bridge'
 *                  loadingBridge.setProgress(progress)
 *
 *   Outside Canvas: loadingBridge.subscribe((p) => setProgress(p))
 */

type Listener = (progress: number) => void;

class LoadingBridge {
    private listeners: Listener[] = [];
    private _progress = 0;

    get progress() { return this._progress; }

    setProgress(p: number) {
        this._progress = p;
        // Always defer notifications with setTimeout so they never fire during
        // React's render or R3F's render loop — prevents "update during render".
        const listeners = [...this.listeners];
        setTimeout(() => listeners.forEach(fn => fn(p)), 0);
    }

    subscribe(fn: Listener): () => void {
        this.listeners.push(fn);
        // Defer initial call too
        setTimeout(() => fn(this._progress), 0);
        return () => {
            this.listeners = this.listeners.filter(l => l !== fn);
        };
    }
}

export const loadingBridge = new LoadingBridge();

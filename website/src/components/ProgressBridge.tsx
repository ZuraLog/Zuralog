"use client";

/**
 * ProgressBridge.tsx
 *
 * Renders inside the R3F <Canvas>. Subscribes imperatively to Drei's
 * useProgress Zustand store (without triggering React re-renders) and pushes
 * values into the module-level loadingBridge singleton.
 *
 * Why imperative? Drei's useProgress store is updated synchronously by
 * Three.js's DefaultLoadingManager callbacks, which fire during R3F's render
 * loop. If we use useProgress() as a React hook, the Zustand store update
 * triggers a React re-render of this component while another component
 * (PhoneModel) is still rendering — causing "Cannot update a component while
 * rendering a different component". By subscribing imperatively in useEffect,
 * we decouple from React's render cycle entirely.
 */

import { useEffect } from "react";
import { useProgress } from "@react-three/drei";
import { loadingBridge } from "@/lib/loading-bridge";

export function ProgressBridge() {
    useEffect(() => {
        // Subscribe imperatively to the Zustand store — no React re-renders.
        // useProgress is a Zustand store created with `create()`, so it has
        // a `subscribe` method that takes a listener and returns an unsubscribe fn.
        const unsubscribe = useProgress.subscribe((state) => {
            loadingBridge.setProgress(state.progress);
        });

        // Push current state immediately in case assets already loaded
        loadingBridge.setProgress(useProgress.getState().progress);

        return unsubscribe;
    }, []);

    return null;
}

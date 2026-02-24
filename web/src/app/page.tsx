/**
 * Home page — placeholder while the full landing page is built in Phase 3.2.
 * Renders the Three.js test scene to verify the 3D pipeline.
 */
import { Button } from '@/components/ui/button';
import { HeroSceneLoader } from '@/components/3d/hero-scene-loader';

export default function Home() {
  return (
    <main className="relative min-h-screen">
      {/* 3D background scene — loaded client-side only */}
      <div className="absolute inset-0 -z-10">
        <HeroSceneLoader />
      </div>

      {/* Overlay content */}
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-24">
        <h1 className="font-display text-5xl font-bold tracking-tight">Zuralog</h1>
        <p className="text-muted-foreground">Coming soon — your AI fitness hub.</p>
        <Button className="rounded-full bg-primary px-8 text-primary-foreground">
          Join the Waitlist
        </Button>
      </div>
    </main>
  );
}

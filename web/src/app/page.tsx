/**
 * Home page — placeholder while the full landing page is built in Phase 3.2.
 */
import { Button } from '@/components/ui/button';

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-24">
      <h1 className="text-4xl font-bold">Zuralog</h1>
      <p className="text-muted-foreground">Coming soon — your AI fitness hub.</p>
      <Button>Join the Waitlist</Button>
    </main>
  );
}

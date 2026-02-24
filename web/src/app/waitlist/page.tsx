/**
 * /waitlist — redirect page.
 *
 * Visiting /waitlist redirects to the homepage with a scroll trigger
 * so the browser lands on the #waitlist section automatically.
 * Uses Next.js server-side redirect for instant, SEO-friendly handling.
 */
import { redirect } from 'next/navigation';

export default function WaitlistPage() {
  redirect('/?scroll=waitlist');
}

export const metadata = {
  title: 'Join the ZuraLog Waitlist',
  description: 'Join the ZuraLog waitlist and be first to access the AI fitness hub that connects all your apps.',
  robots: { index: false },
};

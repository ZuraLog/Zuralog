/**
 * Footer — minimal dark footer for the Zuralog landing page.
 *
 * Contains logo, tagline, social links, and legal copy.
 */
import { Separator } from '@/components/ui/separator';

const SOCIAL_LINKS = [
  { label: 'Twitter / X', href: 'https://x.com/zuralog' },
  { label: 'Instagram', href: 'https://instagram.com/zuralog' },
];

/**
 * Site footer with logo, social links, and copyright.
 */
export function Footer() {
  return (
    <footer className="border-t border-white/5 bg-black">
      <div className="mx-auto max-w-6xl px-6 py-16">
        <div className="flex flex-col gap-12 md:flex-row md:items-start md:justify-between">
          {/* Brand */}
          <div className="flex flex-col gap-3">
            <span className="font-display text-xl font-bold tracking-widest text-sage">
              ZURALOG
            </span>
            <p className="max-w-xs text-sm text-zinc-500">
              The AI fitness hub that connects all your apps into one action layer.
            </p>
          </div>

          {/* Links */}
          <div className="flex flex-col gap-3">
            <span className="text-xs font-semibold uppercase tracking-widest text-zinc-500">
              Community
            </span>
            <ul className="flex flex-col gap-2">
              {SOCIAL_LINKS.map(({ label, href }) => (
                <li key={label}>
                  <a
                    href={href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm text-zinc-400 transition-colors hover:text-white"
                  >
                    {label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div className="flex flex-col gap-3">
            <span className="text-xs font-semibold uppercase tracking-widest text-zinc-500">
              Legal
            </span>
            <ul className="flex flex-col gap-2">
              {[
                { label: 'Privacy Policy', href: '/privacy' },
                { label: 'Terms of Service', href: '/terms' },
              ].map(({ label, href }) => (
                <li key={label}>
                  <a
                    href={href}
                    className="text-sm text-zinc-400 transition-colors hover:text-white"
                  >
                    {label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <Separator className="my-10 bg-white/5" />

        <div className="flex flex-col items-center justify-between gap-4 text-center md:flex-row md:text-left">
          <p className="text-xs text-zinc-600">
            © {new Date().getFullYear()} Zuralog. All rights reserved.
          </p>
          <p className="text-xs text-zinc-700">
            Built with love for athletes who do too much.
          </p>
        </div>
      </div>
    </footer>
  );
}

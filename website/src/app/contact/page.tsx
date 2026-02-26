/**
 * Contact page — ZuraLog.
 *
 * Real contact form that submits to /api/contact, which forwards the
 * message to support@zuralog.com via Resend and sends a confirmation
 * email to the sender.
 *
 * Client component because it manages form state.
 */

'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Navbar } from '@/components/layout/Navbar';
import { Footer } from '@/components/layout/Footer';
import { PageBackground } from '@/components/PageBackground';
import { FaXTwitter, FaInstagram, FaLinkedinIn, FaTiktok } from 'react-icons/fa6';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

const CONTACT_REASONS = [
  'General inquiry',
  'Partnership or collaboration',
  'Press or media',
  'Bug report',
  'Feature request',
  'Other',
];

const SOCIAL_LINKS = [
  { label: 'X (Twitter)', href: 'https://twitter.com/zuralog', icon: FaXTwitter },
  { label: 'Instagram', href: 'https://instagram.com/zuralog', icon: FaInstagram },
  { label: 'LinkedIn', href: 'https://www.linkedin.com/company/112446156/', icon: FaLinkedinIn },
  { label: 'TikTok', href: 'https://www.tiktok.com/@zuralog', icon: FaTiktok },
];

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type FormStatus = 'idle' | 'loading' | 'success' | 'error';

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Contact form page. Submits to POST /api/contact.
 */
export default function ContactPage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [subject, setSubject] = useState(CONTACT_REASONS[0]);
  const [message, setMessage] = useState('');
  const [status, setStatus] = useState<FormStatus>('idle');
  const [errorMsg, setErrorMsg] = useState('');

  /**
   * Handles form submission. Sends data to /api/contact and updates UI state.
   *
   * @param e - Form submit event
   */
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus('loading');
    setErrorMsg('');

    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, subject, message }),
      });

      const data = await res.json() as { message?: string; error?: string };

      if (!res.ok) {
        setErrorMsg(data.error ?? 'Something went wrong. Please try again.');
        setStatus('error');
        return;
      }

      setStatus('success');
      setName('');
      setEmail('');
      setSubject(CONTACT_REASONS[0]);
      setMessage('');
    } catch {
      setErrorMsg('Network error. Please check your connection and try again.');
      setStatus('error');
    }
  }

  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col">
        <Navbar />

        <main className="mx-auto w-full max-w-[1280px] flex-1 px-6 pb-24 pt-32 lg:px-12">
          {/* Back link */}
          <Link
            href="/"
            className="mb-10 inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#2D2D2D]"
          >
            <svg
              aria-hidden="true"
              viewBox="0 0 16 16"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className="h-3.5 w-3.5"
            >
              <path d="M10 12L6 8l4-4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Back to home
          </Link>

          <div className="grid grid-cols-1 gap-16 lg:grid-cols-[1fr_400px]">

            {/* Left: form */}
            <div>
              {/* Header */}
              <span className="mb-4 inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60">
                Get in Touch
              </span>
              <h1 className="mt-3 text-3xl font-bold tracking-tight text-[#1A1A1A] sm:text-4xl">
                Say hello.
              </h1>
              <p className="mt-3 max-w-md text-sm leading-relaxed text-black/45">
                Whether it is a question, a partnership idea, or feedback — we read every
                message and aim to respond within 2 business days.
              </p>

              {/* Success state */}
              {status === 'success' ? (
                <div className="mt-10 rounded-3xl border border-[#CFE1B9]/40 bg-[#E8F5A8]/20 p-8">
                  <p className="text-sm font-semibold text-[#2D2D2D]">Message sent.</p>
                  <p className="mt-1 text-sm text-black/50">
                    Thanks for reaching out. We will be in touch soon. Check your inbox for
                    a confirmation email.
                  </p>
                  <button
                    type="button"
                    onClick={() => setStatus('idle')}
                    className="mt-5 text-xs font-medium text-black/40 underline underline-offset-2 transition-colors hover:text-[#2D2D2D]"
                  >
                    Send another message
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} noValidate className="mt-10 flex flex-col gap-5">

                  {/* Name + Email row */}
                  <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="name" className="text-xs font-medium text-black/50">
                        Name <span aria-hidden="true" className="text-black/30">*</span>
                      </label>
                      <input
                        id="name"
                        type="text"
                        required
                        autoComplete="name"
                        placeholder="Your name"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        className="rounded-2xl border border-black/[0.08] bg-white/60 px-4 py-3 text-sm text-[#1A1A1A] placeholder-black/25 outline-none transition-colors focus:border-[#CFE1B9] focus:ring-2 focus:ring-[#CFE1B9]/30"
                      />
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="email" className="text-xs font-medium text-black/50">
                        Email <span aria-hidden="true" className="text-black/30">*</span>
                      </label>
                      <input
                        id="email"
                        type="email"
                        required
                        autoComplete="email"
                        placeholder="you@example.com"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="rounded-2xl border border-black/[0.08] bg-white/60 px-4 py-3 text-sm text-[#1A1A1A] placeholder-black/25 outline-none transition-colors focus:border-[#CFE1B9] focus:ring-2 focus:ring-[#CFE1B9]/30"
                      />
                    </div>
                  </div>

                  {/* Subject */}
                  <div className="flex flex-col gap-1.5">
                    <label htmlFor="subject" className="text-xs font-medium text-black/50">
                      Subject <span aria-hidden="true" className="text-black/30">*</span>
                    </label>
                    <select
                      id="subject"
                      required
                      value={subject}
                      onChange={(e) => setSubject(e.target.value)}
                      className="rounded-2xl border border-black/[0.08] bg-white/60 px-4 py-3 text-sm text-[#1A1A1A] outline-none transition-colors focus:border-[#CFE1B9] focus:ring-2 focus:ring-[#CFE1B9]/30"
                    >
                      {CONTACT_REASONS.map((reason) => (
                        <option key={reason} value={reason}>{reason}</option>
                      ))}
                    </select>
                  </div>

                  {/* Message */}
                  <div className="flex flex-col gap-1.5">
                    <label htmlFor="message" className="text-xs font-medium text-black/50">
                      Message <span aria-hidden="true" className="text-black/30">*</span>
                    </label>
                    <textarea
                      id="message"
                      required
                      rows={6}
                      placeholder="What is on your mind?"
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      className="resize-none rounded-2xl border border-black/[0.08] bg-white/60 px-4 py-3 text-sm text-[#1A1A1A] placeholder-black/25 outline-none transition-colors focus:border-[#CFE1B9] focus:ring-2 focus:ring-[#CFE1B9]/30"
                    />
                  </div>

                  {/* Error message */}
                  {status === 'error' && (
                    <p className="text-xs font-medium text-red-500">{errorMsg}</p>
                  )}

                  {/* Submit */}
                  <div>
                    <button
                      type="submit"
                      disabled={status === 'loading'}
                      className="inline-flex items-center justify-center gap-2 rounded-full bg-[#E8F5A8] px-8 py-2.5 text-sm font-semibold text-[#2D2D2D] transition-opacity hover:opacity-80 disabled:opacity-50"
                    >
                      {status === 'loading' ? (
                        <>
                          <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-[#2D2D2D]/30 border-t-[#2D2D2D]" />
                          Sending...
                        </>
                      ) : (
                        'Send message'
                      )}
                    </button>
                  </div>

                </form>
              )}
            </div>

            {/* Right: contact info sidebar */}
            <div className="flex flex-col gap-8">

              {/* Email card */}
              <div className="rounded-3xl border border-black/[0.06] bg-white/60 p-8">
                <h2 className="text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
                  Email us directly
                </h2>
                <a
                  href="mailto:support@zuralog.com"
                  className="mt-3 inline-flex items-center gap-2 text-sm font-medium text-[#1A1A1A] transition-opacity hover:opacity-70"
                >
                  <svg
                    aria-hidden="true"
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    className="h-4 w-4 shrink-0 text-black/40"
                  >
                    <path d="M2 4l6 5 6-5M2 4h12v8H2V4z" strokeLinejoin="round" />
                  </svg>
                  support@zuralog.com
                </a>
                <p className="mt-2 text-xs leading-relaxed text-black/35">
                  We respond within 2 business days.
                </p>
              </div>

              {/* Social card */}
              <div className="rounded-3xl border border-black/[0.06] bg-white/60 p-8">
                <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
                  Follow us
                </h2>
                <div className="flex flex-col gap-3">
                  {SOCIAL_LINKS.map(({ label, href, icon: Icon }) => (
                    <a
                      key={label}
                      href={href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-3 text-sm font-medium text-black/50 transition-colors hover:text-[#2D2D2D]"
                    >
                      <span className="flex h-7 w-7 items-center justify-center rounded-full border border-black/[0.08] bg-white/60 text-black/40">
                        <Icon className="h-3 w-3" />
                      </span>
                      {label}
                    </a>
                  ))}
                </div>
              </div>

              {/* Response time note */}
              <p className="text-xs leading-relaxed text-black/30">
                ZuraLog is a remote-first team. We operate across time zones and will get
                back to you as quickly as we can.
              </p>

            </div>
          </div>
        </main>

        <Footer />
      </div>
    </>
  );
}

/**
 * POST /api/waitlist/join
 *
 * Adds a new user to the ZuraLog waitlist.
 * Set NEXT_PUBLIC_PREVIEW_MODE=true in .env.local to bypass Supabase in dev.
 */
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { joinWaitlistSchema } from '@/lib/validations';
import { rateLimiter } from '@/lib/rate-limit';
import { generateReferralCode } from '@/lib/referral';
import { getResendClient, FROM_EMAIL } from '@/lib/resend';

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

function getSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}

export async function POST(request: NextRequest) {
  if (IS_PREVIEW) {
    console.info('[waitlist/join] PREVIEW MODE — skipping DB + email');
    return NextResponse.json(
      {
        message: 'Successfully joined the waitlist! (preview mode)',
        position: Math.floor(Math.random() * 200) + 1,
        referralCode: 'PREVIEW123',
        tier: 'standard',
        preview: true,
      },
      { status: 201 },
    );
  }

  const ip = request.headers.get('x-forwarded-for') ?? 'unknown';
  const { success: allowed } = await rateLimiter.limit(ip);
  if (!allowed) {
    return NextResponse.json({ error: 'Too many requests. Please try again later.' }, { status: 429 });
  }

  let body: unknown;
  try { body = await request.json(); }
  catch { return NextResponse.json({ error: 'Invalid request body.' }, { status: 400 }); }

  const parsed = joinWaitlistSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Validation failed.' }, { status: 400 });
  }

  const { email, referralCode: referrerCode, quizAnswers } = parsed.data;
  const supabase = getSupabase();

  const { data: existing } = await supabase
    .from('waitlist_users')
    .select('id, referral_code, queue_position')
    .eq('email', email)
    .maybeSingle();

  if (existing) {
    return NextResponse.json({
      message: 'You are already on the waitlist!',
      position: existing.queue_position,
      referralCode: existing.referral_code,
      alreadyJoined: true,
    }, { status: 200 });
  }

  let referredByCode: string | null = null;
  let referrerId: string | null = null;
  if (referrerCode) {
    const { data: referrer } = await supabase
      .from('waitlist_users')
      .select('id, referral_code')
      .eq('referral_code', referrerCode.toUpperCase())
      .maybeSingle();
    if (referrer) { referredByCode = referrer.referral_code; referrerId = referrer.id; }
  }

  const newCode = generateReferralCode();
  const { data: inserted, error: insertError } = await supabase
    .from('waitlist_users')
    .insert({
      email,
      referral_code: newCode,
      referred_by: referredByCode,
      quiz_apps_used: quizAnswers?.apps ?? [],
      quiz_frustration: quizAnswers?.frustrations?.[0] ?? null,
      quiz_goal: quizAnswers?.goal ?? null,
    })
    .select('id, queue_position, tier')
    .single();

  if (insertError || !inserted) {
    console.error('[waitlist/join] insert error:', insertError);
    return NextResponse.json({ error: 'Failed to join waitlist. Please try again.' }, { status: 500 });
  }

  if (referrerId) {
    supabase.rpc('increment_referral_count', { user_id: referrerId }).then(
      () => {},
      (err: unknown) => console.error('[waitlist/join] referral increment:', err),
    );
  }

  const resend = getResendClient();
  if (resend) {
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://zuralog.com';
    resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: "You're on the ZuraLog waitlist!",
      html: `<p>Welcome! You're #${inserted.queue_position} on the list. Your referral code is <strong>${newCode}</strong>. Share ${siteUrl}?ref=${newCode} to move up.</p>`,
    }).catch((err: unknown) => console.error('[waitlist/join] email send:', err));
  }

  return NextResponse.json({
    message: 'Successfully joined the waitlist!',
    position: inserted.queue_position,
    referralCode: newCode,
    tier: inserted.tier,
  }, { status: 201 });
}

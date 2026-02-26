/**
 * POST /api/support/admin/contribute
 *
 * Manually add a non-BMC contribution to the support_contributions table.
 * Protected by ADMIN_API_SECRET bearer token in the Authorization header.
 *
 * Request body:
 * ```json
 * {
 *   "supporter_name": "John Doe",
 *   "amount": 50.00,
 *   "source": "paypal",
 *   "is_anonymous": false,
 *   "message": "Keep it up!",
 *   "currency": "USD"
 * }
 * ```
 *
 * @returns 201 with created contribution on success, 400/401/500 on error.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

/** Shape of the expected request body. */
interface ContributeBody {
  supporter_name: string;
  amount: number;
  source?: string;
  is_anonymous?: boolean;
  message?: string;
  currency?: string;
}

export async function POST(request: Request) {
  // ── Auth guard ─────────────────────────────────────────────────────────
  const authHeader = request.headers.get('Authorization');
  const expectedSecret = process.env.ADMIN_API_SECRET;

  if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // ── Parse body ─────────────────────────────────────────────────────────
  let body: ContributeBody;

  try {
    body = (await request.json()) as ContributeBody;
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  if (
    !body.supporter_name ||
    typeof body.amount !== 'number' ||
    body.amount <= 0
  ) {
    return NextResponse.json(
      { error: 'supporter_name (string) and amount (positive number) are required.' },
      { status: 400 },
    );
  }

  // ── Insert ─────────────────────────────────────────────────────────────
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { data, error } = await supabase
    .from('support_contributions')
    .insert({
      source: body.source ?? 'manual',
      supporter_name: body.supporter_name,
      is_anonymous: body.is_anonymous ?? false,
      amount: body.amount,
      currency: body.currency ?? 'USD',
      message: body.message ?? null,
    })
    .select()
    .single();

  if (error) {
    console.error('[support/admin/contribute] insert error:', error);
    return NextResponse.json(
      { error: 'Failed to insert contribution.' },
      { status: 500 },
    );
  }

  return NextResponse.json({ success: true, contribution: data }, { status: 201 });
}

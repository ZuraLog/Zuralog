/**
 * Buy Me a Coffee API client — server-side only.
 *
 * Fetches one-time supporters from the BMC API v1.
 * The API token is read from BMC_API_TOKEN env var.
 *
 * IMPORTANT: The BMC API does not support browser/client-side requests.
 * Only import this module from Next.js API routes or Server Components.
 *
 * @module
 */

const BMC_API_BASE = 'https://developers.buymeacoffee.com/api/v1';

/** Shape of a single one-time supporter returned by the BMC API. */
export interface BmcSupporter {
  support_id: number;
  support_note: string | null;
  support_coffees: number;
  /** Price per coffee as a string decimal, e.g. "5.00" */
  support_coffee_price: string;
  transaction_id: string;
  /** 1 = public, 0 = private/anonymous */
  support_visibility: number;
  /** ISO date string */
  support_created_on: string;
  support_updated_on: string;
  transfer_id: string | null;
  supporter_name: string | null;
  support_email: string | null;
  is_refunded: boolean | null;
  support_currency: string;
  refund_id: string | null;
  payer_email: string | null;
  payer_name: string | null;
}

/** Paginated response envelope from the BMC supporters endpoint. */
interface BmcSupportersResponse {
  current_page: number;
  data: BmcSupporter[];
  first_page_url: string;
  from: number | null;
  last_page: number;
  last_page_url: string;
  next_page_url: string | null;
  path: string;
  per_page: number;
  prev_page_url: string | null;
  to: number | null;
  total: number;
}

/**
 * Fetches ALL one-time supporters from the Buy Me a Coffee API,
 * paginating through all pages automatically.
 *
 * @returns Array of all supporters, or empty array on any error.
 */
export async function fetchAllBmcSupporters(): Promise<BmcSupporter[]> {
  const token = process.env.BMC_API_TOKEN;
  if (!token) {
    console.error('[bmc] BMC_API_TOKEN env var is not set');
    return [];
  }

  const allSupporters: BmcSupporter[] = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    try {
      const res = await fetch(`${BMC_API_BASE}/supporters?page=${page}`, {
        headers: { Authorization: `Bearer ${token}` },
        // Disable Next.js fetch cache — we manage caching at the route level
        next: { revalidate: 0 },
      });

      if (!res.ok) {
        console.error(`[bmc] API responded with ${res.status} ${res.statusText}`);
        break;
      }

      const json: BmcSupportersResponse = await res.json();
      allSupporters.push(...json.data);

      hasMore = json.next_page_url !== null;
      page++;
    } catch (err) {
      console.error('[bmc] Fetch error:', err);
      break;
    }
  }

  return allSupporters;
}

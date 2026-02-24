/**
 * integration-config.ts — dynamic registry of health/fitness app integrations.
 *
 * Adding a new integration:
 *   1. Add an entry to INTEGRATIONS array
 *   2. If react-simple-icons has the brand, use its Si* component
 *   3. Otherwise, set iconType: "letter" with a fallback letter
 *
 * Position angles are in degrees (0 = right, 90 = top, counter-clockwise).
 * They describe where the card floats around the phone in the hero scene.
 */

export interface IntegrationItem {
  /** Unique slug */
  id: string;
  /** Display name */
  label: string;
  /** Brand hex color */
  color: string;
  /** Icon source: "si" for react-simple-icons, "letter" for letter badge */
  iconType: "si" | "letter";
  /** For iconType "si": the simple-icons component name (e.g., "SiStrava"). For "letter": the letter(s). */
  iconKey: string;
  /** Polar angle in degrees for orbital placement (0=right, 90=top) */
  angle: number;
  /** Distance multiplier from center (1.0 = default radius) */
  distance: number;
  /** Relative scale of the card (1.0 = default) */
  scale: number;
  /** External URL for the integration's website */
  url: string;
}

/**
 * Initial minimal integration set.
 * Expand by adding entries — no other code changes needed.
 */
// All integrations placed in the top arc (10°–170°) so the bottom of the hero
// is clear for the text content and floating graphics below the phone.
export const INTEGRATIONS: IntegrationItem[] = [
  {
    id: "strava",
    label: "Strava",
    color: "#FC4C02",
    iconType: "si",
    iconKey: "SiStrava",
    angle: 22,       // top-right
    distance: 1.0,
    scale: 1.0,
    url: "https://www.strava.com",
  },
  {
    id: "apple_health",
    label: "Apple Health",
    color: "#FF3B30",
    iconType: "si",
    iconKey: "SiApple",
    angle: 66,       // upper-right
    distance: 1.1,
    scale: 0.9,
    url: "https://www.apple.com/health/",
  },
  {
    id: "oura",
    label: "Oura Ring",
    color: "#9B8EFF",
    iconType: "letter",
    iconKey: "O",
    angle: 90,       // straight up / center top
    distance: 1.3,
    scale: 0.8,
    url: "https://ouraring.com",
  },
  {
    id: "health_connect",
    label: "Health Connect",
    color: "#4285F4",
    iconType: "si",
    iconKey: "SiGoogle",
    angle: 114,      // upper-left
    distance: 1.1,
    scale: 0.9,
    url: "https://health.google/health-connect/",
  },
  {
    id: "garmin",
    label: "Garmin",
    color: "#007CC3",
    iconType: "si",
    iconKey: "SiGarmin",
    angle: 158,      // top-left
    distance: 1.0,
    scale: 0.85,
    url: "https://www.garmin.com",
  },
];

/** Radius base (% of viewport) for card placement */
export const ORBIT_RADIUS_VW = 36;

/** Brand color map for quick lookups */
export const BRAND_COLORS: Record<string, string> = Object.fromEntries(
  INTEGRATIONS.map((i) => [i.id, i.color])
);

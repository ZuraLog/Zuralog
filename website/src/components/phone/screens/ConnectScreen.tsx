// website/src/components/phone/screens/ConnectScreen.tsx
"use client";

/**
 * ConnectScreen — dark-themed "Connections" phone screen for the Connect section.
 *
 * Colors (all brand tokens):
 *   Canvas:  #161618 — brand dark canvas (app background)
 *   Surface: #1E1E20 — brand dark surface (cards)
 *   Text:    #F0EEE9 — warm white / cream (primary text on dark)
 *   Success: #34C759 — brand success green (Connected indicator)
 *   Sage:    #CFE1B9 — brand sage (More+ icon background)
 *   Strava:  #FC4C02 — Strava's real brand color
 */

function AppleHealthIcon() {
  return (
    <div className="w-9 h-9 rounded-xl bg-white flex items-center justify-center flex-shrink-0">
      <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path
          d="M10 17.5C10 17.5 3 13.5 3 8.5C3 6 5 4 7 4C8.5 4 9.5 5 10 5.5C10.5 5 11.5 4 13 4C15 4 17 6 17 8.5C17 13.5 10 17.5 10 17.5Z"
          fill="#FF375F"
        />
      </svg>
    </div>
  );
}

function HealthConnectIcon() {
  return (
    <div className="w-9 h-9 rounded-xl bg-white flex items-center justify-center flex-shrink-0">
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M9 3.6C10.8 3.6 12 4.3 12.7 5L14.8 3C13.3 1.6 11.4 0.7 9 0.7C5.5 0.7 2.5 3 1.3 6.2L3.7 8C4.4 5.5 6.5 3.6 9 3.6Z" fill="#EA4335" />
        <path d="M16.5 9.2C16.5 8.5 16.4 7.9 16.3 7.3H9V10.9H13.2C13 12 12.3 12.9 11.3 13.5L13.6 15.5C15.3 14 16.5 11.8 16.5 9.2Z" fill="#4285F4" />
        <path d="M3.7 10C3.5 9.4 3.4 8.7 3.4 8C3.4 7.3 3.5 6.6 3.7 6L1.3 4.2C0.5 5.8 0 7.6 0 9.5C0 11 0.3 12.4 1 13.7L3.7 10Z" fill="#FBBC05" />
        <path d="M9 17.3C11.4 17.3 13.4 16.5 14.8 15.1L12.5 13.1C11.7 13.6 10.6 13.9 9 13.9C6.5 13.9 4.4 12 3.7 9.6L1.3 11.8C2.7 15 5.7 17.3 9 17.3Z" fill="#34A853" />
      </svg>
    </div>
  );
}

function StravaIcon() {
  return (
    <div
      className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
      style={{ backgroundColor: "#FC4C02" }}
    >
      <svg width="16" height="18" viewBox="0 0 16 18" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M6.4 11.2L8 7.8L9.6 11.2H12.8L8 1L3.2 11.2H6.4Z" fill="white" fillOpacity="0.6" />
        <path d="M9.6 11.2L8 14.4L6.4 11.2H4L8 18L12 11.2H9.6Z" fill="white" />
      </svg>
    </div>
  );
}

function MoreIcon() {
  return (
    <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 bg-[#CFE1B9]">
      <span className="text-[#161618] text-lg font-bold leading-none">+</span>
    </div>
  );
}

function ConnectedBadge() {
  return (
    <div className="flex items-center gap-1.5 mt-0.5">
      <div className="w-2 h-2 rounded-full bg-[#34C759] flex-shrink-0" />
      <span className="text-[#34C759] text-[10px] font-medium">Connected</span>
    </div>
  );
}

export function ConnectScreen() {
  return (
    <div
      className="w-full h-full overflow-hidden flex flex-col"
      style={{ backgroundColor: "#161618", fontFamily: "var(--font-jakarta)" }}
    >
      {/* Status bar */}
      <div
        className="px-4 pt-2 pb-1 flex justify-between items-center text-[10px] flex-shrink-0"
        style={{ color: "rgba(240, 238, 233, 0.6)" }}
      >
        <span>9:41</span>
        <div className="flex items-center gap-1.5">
          {/* Signal bars */}
          <svg width="12" height="9" viewBox="0 0 12 9" fill="currentColor">
            <rect x="0" y="5" width="2" height="4" rx="0.5" />
            <rect x="3" y="3" width="2" height="6" rx="0.5" />
            <rect x="6" y="1" width="2" height="8" rx="0.5" />
            <rect x="9" y="0" width="2" height="9" rx="0.5" />
          </svg>
          {/* Battery */}
          <svg width="14" height="9" viewBox="0 0 14 9" fill="currentColor">
            <rect x="0.5" y="0.5" width="11" height="8" rx="1.5" stroke="currentColor" strokeWidth="1" fill="none" />
            <rect x="12" y="2.5" width="1.5" height="4" rx="0.5" />
            <rect x="2" y="2" width="7.5" height="5" rx="0.5" fillOpacity="0.8" />
          </svg>
        </div>
      </div>

      {/* Page heading */}
      <div className="px-4 pt-3 pb-3 flex-shrink-0">
        <h3 className="text-sm font-semibold" style={{ color: "#F0EEE9" }}>
          Connections
        </h3>
      </div>

      {/* Apple Health — large card */}
      <div
        className="mx-4 mb-2.5 rounded-2xl px-4 py-3 flex items-center gap-3 flex-shrink-0"
        style={{ backgroundColor: "#1E1E20" }}
      >
        <AppleHealthIcon />
        <div className="min-w-0">
          <p className="text-sm font-medium truncate" style={{ color: "#F0EEE9" }}>
            Apple Health
          </p>
          <ConnectedBadge />
        </div>
      </div>

      {/* Google Health Connect — large card */}
      <div
        className="mx-4 mb-3 rounded-2xl px-4 py-3 flex items-center gap-3 flex-shrink-0"
        style={{ backgroundColor: "#1E1E20" }}
      >
        <HealthConnectIcon />
        <div className="min-w-0">
          <p className="text-sm font-medium truncate" style={{ color: "#F0EEE9" }}>
            Health Connect
          </p>
          <ConnectedBadge />
        </div>
      </div>

      {/* Small cards row — Strava + More+ */}
      <div className="flex gap-2.5 mx-4 flex-shrink-0">
        {/* Strava */}
        <div
          className="flex-1 rounded-2xl px-3 py-3"
          style={{ backgroundColor: "#1E1E20" }}
        >
          <div className="flex items-center gap-2 mb-1.5">
            <StravaIcon />
            <p className="text-xs font-medium" style={{ color: "#F0EEE9" }}>
              Strava
            </p>
          </div>
          <ConnectedBadge />
        </div>
        {/* More+ */}
        <div
          className="flex-1 rounded-2xl px-3 py-3"
          style={{ backgroundColor: "#1E1E20" }}
        >
          <div className="flex items-center gap-2 mb-1.5">
            <MoreIcon />
            <p className="text-xs font-medium" style={{ color: "#F0EEE9" }}>
              More
            </p>
          </div>
          <p
            className="text-[10px]"
            style={{ color: "rgba(240, 238, 233, 0.5)" }}
          >
            Coming soon
          </p>
        </div>
      </div>
    </div>
  );
}

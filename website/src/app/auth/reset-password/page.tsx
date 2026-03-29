"use client";

import { useEffect, useState } from "react";

/**
 * Password Reset Redirect Page.
 *
 * Supabase sends users here after they click the reset link in their email.
 * The URL contains auth tokens in the hash fragment. This page extracts them
 * and redirects to the mobile app via the zuralog:// custom URL scheme.
 *
 * Flow: Email link → this page → zuralog://reset-password?access_token=...
 */
export default function ResetPasswordRedirect() {
  const [redirecting, setRedirecting] = useState(true);

  useEffect(() => {
    // Supabase puts tokens in the URL hash fragment (#access_token=...&...)
    const hash = window.location.hash.substring(1);
    const params = new URLSearchParams(hash);
    const accessToken = params.get("access_token");
    const type = params.get("type");

    if (accessToken && type === "recovery") {
      // Redirect to the mobile app with the recovery token
      const appUrl = `zuralog://reset-password?access_token=${encodeURIComponent(accessToken)}`;
      window.location.href = appUrl;

      // If the app doesn't open after 2 seconds, show a fallback message
      setTimeout(() => setRedirecting(false), 2000);
    } else {
      setRedirecting(false);
    }
  }, []);

  return (
    <div
      style={{
        backgroundColor: "#161618",
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontFamily:
          "'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
        padding: "20px",
      }}
    >
      <div
        style={{
          maxWidth: 400,
          textAlign: "center",
          backgroundColor: "#1E1E20",
          borderRadius: 20,
          padding: "40px 32px",
        }}
      >
        {/* Sage accent line */}
        <div
          style={{
            width: 40,
            height: 4,
            backgroundColor: "#CFE1B9",
            borderRadius: 2,
            margin: "0 auto 24px",
          }}
        />

        <h1
          style={{
            color: "#CFE1B9",
            fontSize: 24,
            fontWeight: 700,
            margin: "0 0 8px",
            letterSpacing: "-0.5px",
          }}
        >
          ZuraLog
        </h1>

        {redirecting ? (
          <>
            <p style={{ color: "#F0EEE9", fontSize: 16, margin: "24px 0 8px" }}>
              Opening the app...
            </p>
            <p style={{ color: "#9B9894", fontSize: 14, lineHeight: 1.6 }}>
              You should be redirected to ZuraLog momentarily.
            </p>
          </>
        ) : (
          <>
            <p style={{ color: "#F0EEE9", fontSize: 16, margin: "24px 0 8px" }}>
              Couldn&apos;t open the app
            </p>
            <p style={{ color: "#9B9894", fontSize: 14, lineHeight: 1.6 }}>
              Make sure ZuraLog is installed on your device, then tap the link in
              your email again.
            </p>
          </>
        )}
      </div>
    </div>
  );
}

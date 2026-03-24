/**
 * ManageCookiesButton — client component for the cookie consent trigger in the footer.
 *
 * Marked 'use client' because it uses an onClick handler.
 * When a cookie consent modal is implemented, wire it up here.
 */
'use client';

/**
 * Renders a "Manage Cookies" button that will eventually trigger a consent modal.
 * Currently a no-op placeholder — ready for future implementation.
 */
export function ManageCookiesButton() {
  return (
    <button
      type="button"
      className="text-xs font-medium transition-colors duration-300"
      style={{ color: "rgba(52, 78, 65, 0.30)" }}
      onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
      onMouseOut={(e) => { e.currentTarget.style.color = "rgba(52, 78, 65, 0.30)"; }}
      onClick={() => {
        // TODO: trigger cookie consent modal
      }}
    >
      Manage Cookies
    </button>
  );
}

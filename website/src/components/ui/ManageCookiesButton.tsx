"use client";

export function ManageCookiesButton() {
  return (
    <button
      type="button"
      className="text-xs font-medium transition-colors duration-300"
      style={{ color: "rgba(52, 78, 65, 0.30)" }}
      onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
      onMouseOut={(e) => { e.currentTarget.style.color = "rgba(52, 78, 65, 0.30)"; }}
      onClick={() => {
        localStorage.removeItem("zuralog-cookie-consent");
        window.location.reload();
      }}
    >
      Manage Cookies
    </button>
  );
}

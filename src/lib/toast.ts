/**
 * Non-blocking ephemeral toast. Injects a div into document.body with
 * role="status" + aria-live="polite". Auto-dismisses after 5 seconds.
 *
 * Used today only for the "Welcome back" upgrade-confirmation message.
 * If the surface area grows, replace with a proper toast system.
 */
export function showToast(message: string): void {
  if (typeof document === "undefined") return;
  const el = document.createElement("div");
  el.textContent = message;
  el.className =
    "fixed bottom-6 left-1/2 -translate-x-1/2 z-[60] rounded-md bg-emerald-600 px-4 py-2 text-sm text-white shadow-lg";
  el.setAttribute("role", "status");
  el.setAttribute("aria-live", "polite");
  // Single-call surface today (only the migrated boot path); stacking is
  // unhandled deliberately. If multiple callers are added later, replace
  // with a queue or a single-active-toast guard.
  document.body.appendChild(el);
  const dismiss = () => el.remove();
  el.addEventListener("click", dismiss);
  el.style.cursor = "pointer";
  setTimeout(dismiss, 5000);
}

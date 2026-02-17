/**
 * Birthday card auto-popup cutoff date.
 * The card auto-shows on app launch only until end of this date (local time).
 * After this date, the card is still accessible via the Mail button.
 */
const BIRTHDAY_CUTOFF = new Date(2026, 1, 19, 23, 59, 59, 999);

const SESSION_KEY = "birthdayCardShownThisSession";

/**
 * Returns true if the current date is on or before the birthday cutoff date.
 * Uses local time because birthdays are local-timezone events.
 */
export function isBirthdayPeriod(now: Date = new Date()): boolean {
  return now <= BIRTHDAY_CUTOFF;
}

/**
 * Returns true if the birthday card should auto-popup.
 * Conditions: within birthday period AND not already shown this session.
 */
export function shouldAutoShowBirthdayCard(now: Date = new Date()): boolean {
  if (!isBirthdayPeriod(now)) return false;
  return !sessionStorage.getItem(SESSION_KEY);
}

/**
 * Marks the birthday card as having been shown in this session.
 */
export function markBirthdayCardShown(): void {
  sessionStorage.setItem(SESSION_KEY, "true");
}

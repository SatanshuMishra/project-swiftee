import { describe, it, expect, beforeEach } from "vitest";
import {
  isBirthdayPeriod,
  shouldAutoShowBirthdayCard,
  markBirthdayCardShown,
} from "./birthday";

describe("isBirthdayPeriod", () => {
  it("returns true for dates before the cutoff", () => {
    expect(isBirthdayPeriod(new Date(2026, 1, 18))).toBe(true);
  });

  it("returns true for the cutoff date itself", () => {
    expect(isBirthdayPeriod(new Date(2026, 1, 19, 12, 0, 0))).toBe(true);
  });

  it("returns true at the very end of Feb 19", () => {
    expect(isBirthdayPeriod(new Date(2026, 1, 19, 23, 59, 59, 999))).toBe(
      true,
    );
  });

  it("returns false for Feb 20", () => {
    expect(isBirthdayPeriod(new Date(2026, 1, 20, 0, 0, 0))).toBe(false);
  });

  it("returns false for dates well after cutoff", () => {
    expect(isBirthdayPeriod(new Date(2027, 0, 1))).toBe(false);
  });
});

describe("shouldAutoShowBirthdayCard", () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it("returns true during birthday period when not yet shown", () => {
    expect(shouldAutoShowBirthdayCard(new Date(2026, 1, 15))).toBe(true);
  });

  it("returns false during birthday period after card was shown", () => {
    markBirthdayCardShown();
    expect(shouldAutoShowBirthdayCard(new Date(2026, 1, 15))).toBe(false);
  });

  it("returns false after birthday period even if not shown", () => {
    expect(shouldAutoShowBirthdayCard(new Date(2026, 5, 1))).toBe(false);
  });
});

describe("markBirthdayCardShown", () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it("sets sessionStorage key", () => {
    markBirthdayCardShown();
    expect(sessionStorage.getItem("birthdayCardShownThisSession")).toBe("true");
  });
});

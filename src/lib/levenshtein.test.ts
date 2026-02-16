import { describe, it, expect } from "vitest";
import { levenshteinDistance, isCloseMatch } from "./levenshtein";

describe("levenshteinDistance", () => {
  it("returns 0 for identical strings", () => {
    expect(levenshteinDistance("hello", "hello")).toBe(0);
  });

  it("returns string length for empty comparison", () => {
    expect(levenshteinDistance("hello", "")).toBe(5);
    expect(levenshteinDistance("", "hello")).toBe(5);
  });

  it("counts single substitution", () => {
    expect(levenshteinDistance("cat", "bat")).toBe(1);
  });

  it("counts insertion", () => {
    expect(levenshteinDistance("cat", "cats")).toBe(1);
  });

  it("counts deletion", () => {
    expect(levenshteinDistance("cats", "cat")).toBe(1);
  });

  it("handles transposition (2 operations)", () => {
    expect(levenshteinDistance("anit", "anti")).toBe(2);
  });
});

describe("isCloseMatch", () => {
  it("allows distance <= 2 for long strings", () => {
    expect(isCloseMatch("enchanted", "enchantd")).toBe(true); // dist 1
    expect(isCloseMatch("enchanted", "enchnted")).toBe(true); // dist 1
    expect(isCloseMatch("enchanted", "enchntd")).toBe(true); // dist 2, allowed
  });

  it("requires exact match for short strings (< 5 chars)", () => {
    expect(isCloseMatch("22", "22")).toBe(true);
    expect(isCloseMatch("22", "23")).toBe(false);
    expect(isCloseMatch("me", "me")).toBe(true);
    expect(isCloseMatch("me", "mee")).toBe(false);
  });

  it("accepts exact matches always", () => {
    expect(isCloseMatch("anti hero", "anti hero")).toBe(true);
    expect(isCloseMatch("22", "22")).toBe(true);
  });
});

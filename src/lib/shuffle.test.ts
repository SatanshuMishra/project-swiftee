import { describe, it, expect } from "vitest";
import { shuffle } from "./shuffle";

describe("shuffle", () => {
  it("returns a new array, does not mutate original", () => {
    const original = [1, 2, 3, 4, 5];
    const originalCopy = [...original];
    shuffle(original);
    expect(original).toEqual(originalCopy);
  });

  it("returns array of same length", () => {
    const arr = [1, 2, 3, 4, 5];
    expect(shuffle(arr).length).toBe(5);
  });

  it("contains all original elements", () => {
    const arr = [1, 2, 3, 4, 5];
    const result = shuffle(arr);
    expect(result.sort()).toEqual([1, 2, 3, 4, 5]);
  });

  it("handles empty array", () => {
    expect(shuffle([])).toEqual([]);
  });

  it("handles single element", () => {
    expect(shuffle([42])).toEqual([42]);
  });

  it("accepts readonly arrays", () => {
    const arr: readonly number[] = [1, 2, 3];
    const result = shuffle(arr);
    expect(result.sort()).toEqual([1, 2, 3]);
  });

  it("eventually produces different orderings", () => {
    const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const results = new Set<string>();
    for (let i = 0; i < 50; i++) {
      results.add(JSON.stringify(shuffle(arr)));
    }
    // With 10 elements and 50 attempts, we should get multiple orderings
    expect(results.size).toBeGreaterThan(1);
  });
});

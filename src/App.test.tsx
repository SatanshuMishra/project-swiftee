import { act, render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { App } from "./App";
import { useGameStore } from "./stores/gameStore";
import { DEFAULT_PROGRESS } from "./types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

vi.mock("@tauri-apps/plugin-updater", () => ({
  check: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import { check } from "@tauri-apps/plugin-updater";

const mockInvoke = vi.mocked(invoke);
const mockCheck = vi.mocked(check);

const SIX_HOURS_MS = 6 * 60 * 60 * 1000;

beforeEach(() => {
  vi.useFakeTimers();
  vi.resetAllMocks();
  mockInvoke.mockResolvedValue({ kind: "fresh" });
  mockCheck.mockResolvedValue(null);
  useGameStore.setState({
    progress: DEFAULT_PROGRESS,
    updaterState: { kind: "idle" },
  });
});

afterEach(() => {
  vi.useRealTimers();
});

describe("App update checks", () => {
  it("checks once at launch, then again only after six hours", async () => {
    render(<App />);

    await act(() => vi.advanceTimersByTimeAsync(60_000));
    expect(mockCheck).toHaveBeenCalledTimes(1);

    await act(() => vi.advanceTimersByTimeAsync(SIX_HOURS_MS));
    expect(mockCheck).toHaveBeenCalledTimes(2);
  });
});

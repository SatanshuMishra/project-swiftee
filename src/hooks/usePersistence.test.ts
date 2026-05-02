import { renderHook, waitFor } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";

import { usePersistence } from "./usePersistence";
import { useGameStore } from "../stores/gameStore";
import { DEFAULT_PROGRESS } from "../types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

vi.mock("../lib/toast", () => ({
  showToast: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import { showToast } from "../lib/toast";

const mockInvoke = vi.mocked(invoke);
const mockShowToast = vi.mocked(showToast);

beforeEach(() => {
  vi.resetAllMocks();
  useGameStore.setState({ progress: DEFAULT_PROGRESS });
});

describe("usePersistence", () => {
  it("does nothing on Fresh result (no toast, no setProgress)", async () => {
    mockInvoke.mockResolvedValueOnce({ kind: "fresh" });
    renderHook(() => usePersistence());
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("load_progress");
    });
    expect(mockShowToast).not.toHaveBeenCalled();
    // Store unchanged from DEFAULT_PROGRESS
    expect(useGameStore.getState().progress).toEqual(DEFAULT_PROGRESS);
  });

  it("setProgress (with merged settings) on Loaded result; no toast", async () => {
    const loadedProgress = {
      ...DEFAULT_PROGRESS,
      stats: { ...DEFAULT_PROGRESS.stats, totalCorrect: 42 },
    };
    mockInvoke.mockResolvedValueOnce({
      kind: "loaded",
      progress: loadedProgress,
    });
    renderHook(() => usePersistence());
    await waitFor(() => {
      expect(useGameStore.getState().progress.stats.totalCorrect).toBe(42);
    });
    expect(mockShowToast).not.toHaveBeenCalled();
  });

  it("setProgress + toast with version on Migrated result with known fromVersion", async () => {
    const migratedProgress = {
      ...DEFAULT_PROGRESS,
      stats: { ...DEFAULT_PROGRESS.stats, totalCorrect: 7 },
    };
    mockInvoke.mockResolvedValueOnce({
      kind: "migrated",
      progress: migratedProgress,
      fromVersion: 1,
    });
    renderHook(() => usePersistence());
    await waitFor(() => {
      expect(useGameStore.getState().progress.stats.totalCorrect).toBe(7);
    });
    expect(mockShowToast).toHaveBeenCalledOnce();
    const message = mockShowToast.mock.calls[0][0];
    expect(message).toMatch(/welcome back/i);
    expect(message).toMatch(/v1/i);
  });

  it("toast omits version when fromVersion is null", async () => {
    mockInvoke.mockResolvedValueOnce({
      kind: "migrated",
      progress: DEFAULT_PROGRESS,
      fromVersion: null,
    });
    renderHook(() => usePersistence());
    await waitFor(() => {
      expect(mockShowToast).toHaveBeenCalledOnce();
    });
    const message = mockShowToast.mock.calls[0][0];
    expect(message).toMatch(/welcome back/i);
    expect(message).not.toMatch(/v\d/);
  });

  it("does not overwrite store on invoke error (preserves seeded data for backup recovery)", async () => {
    mockInvoke.mockRejectedValueOnce(new Error("boom"));
    const seeded = {
      ...DEFAULT_PROGRESS,
      stats: { ...DEFAULT_PROGRESS.stats, totalCorrect: 99 },
    };
    useGameStore.setState({ progress: seeded });
    renderHook(() => usePersistence());
    // Wait a tick for the load promise to reject and the catch to run.
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("load_progress");
    });
    // The store should be UNCHANGED — no DEFAULT_PROGRESS reset.
    expect(useGameStore.getState().progress.stats.totalCorrect).toBe(99);
    // A toast should have been shown so the user knows.
    expect(mockShowToast).toHaveBeenCalledOnce();
    expect(mockShowToast.mock.calls[0][0]).toMatch(/couldn't load/i);
  });
});

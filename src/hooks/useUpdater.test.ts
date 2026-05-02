import { renderHook, act } from "@testing-library/react";
import { describe, it, expect, beforeEach, vi } from "vitest";

import { useUpdater, __resetUpdaterCtxForTests } from "./useUpdater";
import { useGameStore } from "../stores/gameStore";
import { DEFAULT_PROGRESS } from "../types";

vi.mock("@tauri-apps/plugin-updater", () => ({
  check: vi.fn(),
}));

import { check } from "@tauri-apps/plugin-updater";
const mockCheck = vi.mocked(check);

beforeEach(() => {
  vi.resetAllMocks();
  __resetUpdaterCtxForTests();
  useGameStore.setState({
    progress: DEFAULT_PROGRESS,
    updaterState: { kind: "idle" },
  });
});

describe("useUpdater", () => {
  it("starts in idle", () => {
    const { result } = renderHook(() => useUpdater());
    expect(result.current.state.kind).toBe("idle");
  });

  it("transitions idle → checking → up-to-date when no update", async () => {
    mockCheck.mockResolvedValueOnce(null);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("up-to-date");
  });

  it("transitions idle → checking → available when update exists", async () => {
    mockCheck.mockResolvedValueOnce({
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "## Changes\n- thing",
      date: "2026-05-01T00:00:00Z",
      download: vi.fn(),
      install: vi.fn(),
    } as any);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("available");
    if (result.current.state.kind === "available") {
      expect(result.current.state.manifest.version).toBe("0.3.0");
      expect(result.current.state.manifest.notes).toContain("Changes");
    }
  });

  it("transitions to error: check on check failure", async () => {
    mockCheck.mockRejectedValueOnce(new Error("network down"));
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("error");
    if (result.current.state.kind === "error") {
      expect(result.current.state.subtype).toBe("check");
      expect(result.current.state.message).toContain("network");
    }
  });

  it("download() transitions available → downloading → ready", async () => {
    const downloadFn = vi.fn().mockImplementation(async (onProgress: (e: any) => void) => {
      onProgress({ event: "Started", data: { contentLength: 1000 } });
      onProgress({ event: "Progress", data: { chunkLength: 500 } });
      onProgress({ event: "Progress", data: { chunkLength: 500 } });
      onProgress({ event: "Finished" });
    });
    const update = {
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "notes",
      date: "2026-05-01T00:00:00Z",
      download: downloadFn,
      install: vi.fn(),
    };
    mockCheck.mockResolvedValueOnce(update as any);

    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    await act(async () => {
      await result.current.download();
    });
    expect(result.current.state.kind).toBe("ready");
  });

  it("download() error mapped to error.subtype=signature when message hints verification failure", async () => {
    const downloadFn = vi.fn().mockRejectedValue(new Error("signature verification failed"));
    const update = {
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "notes",
      date: "2026-05-01T00:00:00Z",
      download: downloadFn,
      install: vi.fn(),
    };
    mockCheck.mockResolvedValueOnce(update as any);

    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    await act(async () => {
      await result.current.download();
    });
    expect(result.current.state.kind).toBe("error");
    if (result.current.state.kind === "error") {
      expect(result.current.state.subtype).toBe("signature");
    }
  });

  it("download() error mapped to error.subtype=download for generic failures", async () => {
    const downloadFn = vi.fn().mockRejectedValue(new Error("connection reset"));
    const update = {
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "notes",
      date: "2026-05-01T00:00:00Z",
      download: downloadFn,
      install: vi.fn(),
    };
    mockCheck.mockResolvedValueOnce(update as any);

    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    await act(async () => {
      await result.current.download();
    });
    expect(result.current.state.kind).toBe("error");
    if (result.current.state.kind === "error") {
      expect(result.current.state.subtype).toBe("download");
    }
  });

  it("dismiss clears error to idle", async () => {
    mockCheck.mockRejectedValueOnce(new Error("oops"));
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("error");
    act(() => {
      result.current.dismiss();
    });
    expect(result.current.state.kind).toBe("idle");
  });

  it("cancel clears pending update and returns to idle", async () => {
    mockCheck.mockResolvedValueOnce({
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "notes",
      date: "2026-05-01T00:00:00Z",
      download: vi.fn(),
      install: vi.fn(),
    } as any);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("available");
    act(() => {
      result.current.cancel();
    });
    expect(result.current.state.kind).toBe("idle");
  });

  it("skipVersion appends to gameStore.progress.updater.skippedVersions", () => {
    const { result } = renderHook(() => useUpdater());
    act(() => {
      result.current.skipVersion("0.3.0");
    });
    const progress = useGameStore.getState().progress;
    expect(progress.updater.skippedVersions).toContain("0.3.0");
  });

  it("skipVersion preserves prior skippedVersions (immutable append)", () => {
    // Seed the store with an existing skipped version
    const initial = useGameStore.getState().progress;
    useGameStore.getState().setProgress({
      ...initial,
      updater: {
        ...initial.updater,
        skippedVersions: ["0.2.5"],
      },
    });

    const { result } = renderHook(() => useUpdater());
    act(() => {
      result.current.skipVersion("0.3.0");
    });
    const progress = useGameStore.getState().progress;
    expect(progress.updater.skippedVersions).toEqual(["0.2.5", "0.3.0"]);
  });

  it("remindLater sets remindLaterUntil to ~24h in the future", () => {
    const before = Date.now();
    const { result } = renderHook(() => useUpdater());
    act(() => {
      result.current.remindLater();
    });
    const progress = useGameStore.getState().progress;
    expect(progress.updater.remindLaterUntil).not.toBeNull();
    const until = new Date(progress.updater.remindLaterUntil!).getTime();
    expect(until - before).toBeGreaterThan(23 * 3600 * 1000);
    expect(until - before).toBeLessThan(25 * 3600 * 1000);
  });

  it("auto-check is skipped when autoCheckEnabled is false", async () => {
    useGameStore.setState({
      progress: {
        ...DEFAULT_PROGRESS,
        updater: { ...DEFAULT_PROGRESS.updater, autoCheckEnabled: false },
      },
    });
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(mockCheck).not.toHaveBeenCalled();
    expect(result.current.state.kind).toBe("idle");
  });

  it("auto-check is skipped during remindLater cooldown", async () => {
    const future = new Date(Date.now() + 12 * 3600 * 1000).toISOString();
    useGameStore.setState({
      progress: {
        ...DEFAULT_PROGRESS,
        updater: { ...DEFAULT_PROGRESS.updater, remindLaterUntil: future },
      },
    });
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(mockCheck).not.toHaveBeenCalled();
  });

  it("manual check bypasses autoCheckEnabled=false", async () => {
    useGameStore.setState({
      progress: {
        ...DEFAULT_PROGRESS,
        updater: { ...DEFAULT_PROGRESS.updater, autoCheckEnabled: false },
      },
    });
    mockCheck.mockResolvedValueOnce(null);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check({ manual: true });
    });
    expect(mockCheck).toHaveBeenCalledOnce();
    expect(result.current.state.kind).toBe("up-to-date");
  });

  it("available update is demoted to up-to-date if version is in skippedVersions", async () => {
    useGameStore.setState({
      progress: {
        ...DEFAULT_PROGRESS,
        updater: { ...DEFAULT_PROGRESS.updater, skippedVersions: ["0.3.0"] },
      },
    });
    mockCheck.mockResolvedValueOnce({
      version: "0.3.0",
      currentVersion: "0.2.0",
      body: "",
      date: "",
      download: vi.fn(),
      install: vi.fn(),
    } as any);
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    expect(result.current.state.kind).toBe("up-to-date");
  });

  it("successful check writes lastCheckedAt to progress.updater", async () => {
    mockCheck.mockResolvedValueOnce(null);
    const before = Date.now();
    const { result } = renderHook(() => useUpdater());
    await act(async () => {
      await result.current.check();
    });
    const lastChecked = useGameStore.getState().progress.updater.lastCheckedAt;
    expect(lastChecked).not.toBeNull();
    const ts = Date.parse(lastChecked!);
    expect(ts).toBeGreaterThanOrEqual(before);
    expect(ts).toBeLessThanOrEqual(Date.now() + 1000);
  });
});

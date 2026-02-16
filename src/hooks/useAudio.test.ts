import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useAudio } from "./useAudio";
import type { TrackInfo } from "./useAudio";

// Mock gameStore
vi.mock("../stores/gameStore", () => ({
  useGameStore: (selector: (s: Record<string, unknown>) => unknown) =>
    selector({
      progress: { settings: { volume: 0.8 } },
      relistenCount: 0,
      incrementRelisten: vi.fn(),
    }),
}));

// Mock lrclib — returns empty danger zones by default
vi.mock("../lib/lrclib", () => ({
  fetchDangerZones: vi.fn().mockResolvedValue([]),
}));

// Mock clipSelector — returns 5 by default
vi.mock("../engine/clipSelector", () => ({
  selectClipStartWithFallback: vi.fn().mockReturnValue(5),
}));

// Mock AudioContext and related Web Audio API
const mockStop = vi.fn();
const mockStart = vi.fn();
const mockConnect = vi.fn();
const mockCreateBufferSource = vi.fn(() => ({
  buffer: null,
  connect: mockConnect,
  start: mockStart,
  stop: mockStop,
  onended: null as (() => void) | null,
}));
const mockCreateGain = vi.fn(() => ({
  gain: { value: 0 },
  connect: mockConnect,
}));
const mockDecodeAudioData = vi.fn();

vi.stubGlobal(
  "AudioContext",
  vi.fn(() => ({
    createBufferSource: mockCreateBufferSource,
    createGain: mockCreateGain,
    decodeAudioData: mockDecodeAudioData,
    destination: {},
    currentTime: 0,
  })),
);

const mockTrackInfo: TrackInfo = {
  title: "Enchanted (Taylor's Version)",
  titleShort: "Enchanted",
  artistName: "Taylor Swift",
  songDurationSeconds: 319,
};

describe("useAudio", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("starts in idle state", () => {
    const { result } = renderHook(() => useAudio());
    expect(result.current.playing).toBe(false);
    expect(result.current.loading).toBe(false);
    expect(result.current.progress).toBe(0);
    expect(result.current.relistenStage).toBe(0);
  });

  it("exports play, relisten, stop, and reset functions", () => {
    const { result } = renderHook(() => useAudio());
    expect(typeof result.current.play).toBe("function");
    expect(typeof result.current.relisten).toBe("function");
    expect(typeof result.current.stop).toBe("function");
    expect(typeof result.current.reset).toBe("function");
  });

  it("stop clears playing and progress state", () => {
    const { result } = renderHook(() => useAudio());
    act(() => {
      result.current.stop();
    });
    expect(result.current.playing).toBe(false);
    expect(result.current.progress).toBe(0);
  });

  it("reset clears all state and increments version", () => {
    const { result } = renderHook(() => useAudio());
    act(() => {
      result.current.reset();
    });
    expect(result.current.playing).toBe(false);
    expect(result.current.loading).toBe(false);
    expect(result.current.progress).toBe(0);
  });

  it("play sets loading to true then false (without trackInfo)", async () => {
    const mockBuffer = { duration: 30 } as AudioBuffer;
    mockDecodeAudioData.mockResolvedValueOnce(mockBuffer);
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce({
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(100)),
      }),
    );

    const { result } = renderHook(() => useAudio());

    await act(async () => {
      await result.current.play("https://example.com/preview.mp3");
    });

    expect(result.current.loading).toBe(false);
    expect(mockDecodeAudioData).toHaveBeenCalledTimes(1);
  });

  it("play stops previous playback before fetching", async () => {
    const mockBuffer = { duration: 30 } as AudioBuffer;
    mockDecodeAudioData.mockResolvedValue(mockBuffer);
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(100)),
      }),
    );

    const { result } = renderHook(() => useAudio());

    // Start first play
    await act(async () => {
      await result.current.play("https://example.com/a.mp3");
    });

    // Start second play — should stop the first one
    await act(async () => {
      await result.current.play("https://example.com/b.mp3");
    });

    // stop() should have been called on the source from the first play
    expect(mockStop).toHaveBeenCalled();
  });

  it("play with trackInfo uses smart clip selection", async () => {
    const { fetchDangerZones } = await import("../lib/lrclib");
    const { selectClipStartWithFallback } = await import(
      "../engine/clipSelector"
    );

    const mockBuffer = { duration: 30 } as AudioBuffer;
    mockDecodeAudioData.mockResolvedValueOnce(mockBuffer);
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce({
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(100)),
      }),
    );

    const { result } = renderHook(() => useAudio());

    await act(async () => {
      await result.current.play(
        "https://example.com/preview.mp3",
        mockTrackInfo,
      );
    });

    expect(fetchDangerZones).toHaveBeenCalledWith(
      mockTrackInfo.title,
      mockTrackInfo.artistName,
      mockTrackInfo.titleShort,
      mockTrackInfo.songDurationSeconds,
    );
    expect(selectClipStartWithFallback).toHaveBeenCalledWith(mockBuffer, []);
  });

  it("play without trackInfo does not call fetchDangerZones", async () => {
    const { fetchDangerZones } = await import("../lib/lrclib");
    const { selectClipStartWithFallback } = await import(
      "../engine/clipSelector"
    );

    const mockBuffer = { duration: 30 } as AudioBuffer;
    mockDecodeAudioData.mockResolvedValueOnce(mockBuffer);
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce({
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(100)),
      }),
    );

    const { result } = renderHook(() => useAudio());

    await act(async () => {
      await result.current.play("https://example.com/preview.mp3");
    });

    expect(fetchDangerZones).not.toHaveBeenCalled();
    expect(selectClipStartWithFallback).not.toHaveBeenCalled();
  });
});

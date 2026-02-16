import { useCallback, useRef, useState } from "react";
import { useGameStore } from "../stores/gameStore";

interface UseAudioResult {
  readonly playing: boolean;
  readonly loading: boolean;
  readonly progress: number;
  readonly relistenStage: number;
  readonly play: (previewUrl: string) => Promise<void>;
  readonly relisten: () => void;
  readonly stop: () => void;
  readonly reset: () => void;
}

export function useAudio(): UseAudioResult {
  const volume = useGameStore((s) => s.progress.settings.volume);
  const relistenCount = useGameStore((s) => s.relistenCount);
  const incrementRelisten = useGameStore((s) => s.incrementRelisten);

  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);

  const audioContextRef = useRef<AudioContext | null>(null);
  const bufferRef = useRef<AudioBuffer | null>(null);
  const sourceRef = useRef<AudioBufferSourceNode | null>(null);
  const gainRef = useRef<GainNode | null>(null);
  const randomStartRef = useRef(0);
  const progressTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const playVersionRef = useRef(0);

  const getContext = useCallback(() => {
    if (!audioContextRef.current) {
      audioContextRef.current = new AudioContext();
    }
    return audioContextRef.current;
  }, []);

  const stopPlayback = useCallback(() => {
    if (sourceRef.current) {
      try {
        sourceRef.current.stop();
      } catch {
        // Already stopped
      }
      sourceRef.current = null;
    }
    if (progressTimerRef.current) {
      clearInterval(progressTimerRef.current);
      progressTimerRef.current = null;
    }
    setPlaying(false);
    setProgress(0);
  }, []);

  const reset = useCallback(() => {
    stopPlayback();
    playVersionRef.current += 1;
    bufferRef.current = null;
    randomStartRef.current = 0;
    setLoading(false);
  }, [stopPlayback]);

  const playSlice = useCallback(
    (buffer: AudioBuffer, offset: number, duration: number) => {
      const version = playVersionRef.current;
      stopPlayback();

      const ctx = getContext();
      const source = ctx.createBufferSource();
      source.buffer = buffer;

      const gain = ctx.createGain();
      gain.gain.value = volume;
      gainRef.current = gain;

      source.connect(gain);
      gain.connect(ctx.destination);
      source.start(0, offset, duration);
      sourceRef.current = source;

      setPlaying(true);

      const startTime = ctx.currentTime;
      progressTimerRef.current = setInterval(() => {
        // Self-destruct if stale version
        if (playVersionRef.current !== version) {
          if (progressTimerRef.current) {
            clearInterval(progressTimerRef.current);
            progressTimerRef.current = null;
          }
          return;
        }
        const elapsed = ctx.currentTime - startTime;
        setProgress(Math.min(elapsed / duration, 1));
        if (elapsed >= duration) {
          setPlaying(false);
          if (progressTimerRef.current) {
            clearInterval(progressTimerRef.current);
          }
        }
      }, 50);

      source.onended = () => {
        // Only update state if this is still the current version
        if (playVersionRef.current !== version) return;
        setPlaying(false);
        if (progressTimerRef.current) {
          clearInterval(progressTimerRef.current);
        }
      };
    },
    [stopPlayback, getContext, volume],
  );

  const play = useCallback(
    async (previewUrl: string) => {
      // Stop any current playback before starting async work
      stopPlayback();
      playVersionRef.current += 1;
      const version = playVersionRef.current;

      setLoading(true);
      try {
        const ctx = getContext();
        const response = await fetch(previewUrl);

        // Stale guard after fetch
        if (playVersionRef.current !== version) return;

        const arrayBuffer = await response.arrayBuffer();

        // Stale guard after arrayBuffer
        if (playVersionRef.current !== version) return;

        const audioBuffer = await ctx.decodeAudioData(arrayBuffer);

        // Stale guard after decode
        if (playVersionRef.current !== version) return;

        bufferRef.current = audioBuffer;

        const sliceDuration = 10;
        const maxStart = Math.max(0, audioBuffer.duration - sliceDuration);
        randomStartRef.current = Math.random() * maxStart;

        playSlice(audioBuffer, randomStartRef.current, sliceDuration);
      } finally {
        // Only clear loading if still current version
        if (playVersionRef.current === version) {
          setLoading(false);
        }
      }
    },
    [getContext, playSlice, stopPlayback],
  );

  const relisten = useCallback(() => {
    const buffer = bufferRef.current;
    if (!buffer) return;

    incrementRelisten();
    const stage = relistenCount + 1;

    if (stage <= 1) {
      // Same 10s slice
      playSlice(buffer, randomStartRef.current, 10);
    } else if (stage === 2) {
      // 20s from same start
      const duration = Math.min(20, buffer.duration - randomStartRef.current);
      playSlice(buffer, randomStartRef.current, duration);
    } else {
      // Full 30s clip
      playSlice(buffer, 0, buffer.duration);
    }
  }, [relistenCount, incrementRelisten, playSlice]);

  return {
    playing,
    loading,
    progress,
    relistenStage: relistenCount,
    play,
    relisten,
    stop: stopPlayback,
    reset,
  };
}

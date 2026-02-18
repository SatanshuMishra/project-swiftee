import { useCallback, useEffect, useRef, useState } from "react";
import { useGameStore } from "../stores/gameStore";
import { fetchDangerZones } from "../lib/lrclib";
import { selectClipStartWithFallback } from "../engine/clipSelector";
import { getRelistenSlice } from "../engine/relistenSchedule";

export interface TrackInfo {
  readonly title: string;
  readonly titleShort: string;
  readonly artistName: string;
  readonly songDurationSeconds: number;
}

interface UseAudioResult {
  readonly playing: boolean;
  readonly paused: boolean;
  readonly loading: boolean;
  readonly progress: number;
  readonly clipDuration: number;
  readonly relistenStage: number;
  readonly play: (previewUrl: string, trackInfo?: TrackInfo) => Promise<void>;
  readonly relisten: () => void;
  readonly pause: () => void;
  readonly resume: () => void;
  readonly stop: () => void;
  readonly reset: () => void;
}

export function useAudio(): UseAudioResult {
  const volume = useGameStore((s) => s.progress.settings.volume);
  const relistenCount = useGameStore((s) => s.relistenCount);
  const incrementRelisten = useGameStore((s) => s.incrementRelisten);

  const [playing, setPlaying] = useState(false);
  const [paused, setPaused] = useState(false);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [clipDuration, setClipDuration] = useState(0);

  const audioContextRef = useRef<AudioContext | null>(null);
  const bufferRef = useRef<AudioBuffer | null>(null);
  const sourceRef = useRef<AudioBufferSourceNode | null>(null);
  const gainRef = useRef<GainNode | null>(null);
  const randomStartRef = useRef(0);
  const progressTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const playVersionRef = useRef(0);

  // Pause/resume tracking refs
  const sliceOffsetRef = useRef(0);
  const sliceDurationRef = useRef(0);
  const elapsedBeforePauseRef = useRef(0);
  const segmentStartTimeRef = useRef(0);

  const getContext = useCallback(() => {
    if (!audioContextRef.current) {
      audioContextRef.current = new AudioContext();
    }
    return audioContextRef.current;
  }, []);

  const haltSource = useCallback(() => {
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
  }, []);

  const stopPlayback = useCallback(() => {
    haltSource();
    setPlaying(false);
    setPaused(false);
    setProgress(0);
    setClipDuration(0);
    sliceOffsetRef.current = 0;
    sliceDurationRef.current = 0;
    elapsedBeforePauseRef.current = 0;
    segmentStartTimeRef.current = 0;
  }, [haltSource]);

  const reset = useCallback(() => {
    stopPlayback();
    playVersionRef.current += 1;
    bufferRef.current = null;
    randomStartRef.current = 0;
    setLoading(false);
  }, [stopPlayback]);

  const startPlaybackSegment = useCallback(
    (
      buffer: AudioBuffer,
      offset: number,
      duration: number,
      priorElapsed: number,
      totalSliceDuration: number,
    ) => {
      const version = playVersionRef.current;
      haltSource();

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

      segmentStartTimeRef.current = ctx.currentTime;
      setPlaying(true);
      setPaused(false);

      progressTimerRef.current = setInterval(() => {
        if (playVersionRef.current !== version) {
          if (progressTimerRef.current) {
            clearInterval(progressTimerRef.current);
            progressTimerRef.current = null;
          }
          return;
        }
        const segmentElapsed = ctx.currentTime - segmentStartTimeRef.current;
        const totalElapsed = priorElapsed + segmentElapsed;
        setProgress(Math.min(totalElapsed / totalSliceDuration, 1));
        if (segmentElapsed >= duration) {
          setPlaying(false);
          if (progressTimerRef.current) {
            clearInterval(progressTimerRef.current);
          }
        }
      }, 50);

      source.onended = () => {
        if (playVersionRef.current !== version) return;
        setPlaying(false);
        if (progressTimerRef.current) {
          clearInterval(progressTimerRef.current);
        }
      };
    },
    [haltSource, getContext, volume],
  );

  const playSlice = useCallback(
    (buffer: AudioBuffer, offset: number, duration: number) => {
      sliceOffsetRef.current = offset;
      sliceDurationRef.current = duration;
      elapsedBeforePauseRef.current = 0;
      setClipDuration(duration);
      startPlaybackSegment(buffer, offset, duration, 0, duration);
    },
    [startPlaybackSegment],
  );

  const play = useCallback(
    async (previewUrl: string, trackInfo?: TrackInfo) => {
      stopPlayback();
      playVersionRef.current += 1;
      const version = playVersionRef.current;

      const dangerZonesPromise = trackInfo
        ? fetchDangerZones(
            trackInfo.title,
            trackInfo.artistName,
            trackInfo.titleShort,
            trackInfo.songDurationSeconds,
          )
        : Promise.resolve([]);

      setLoading(true);
      try {
        const ctx = getContext();
        const response = await fetch(previewUrl);

        if (playVersionRef.current !== version) return;

        const arrayBuffer = await response.arrayBuffer();

        if (playVersionRef.current !== version) return;

        const audioBuffer = await ctx.decodeAudioData(arrayBuffer);

        if (playVersionRef.current !== version) return;

        bufferRef.current = audioBuffer;

        const dangerZones = await dangerZonesPromise;

        if (playVersionRef.current !== version) return;

        const sliceDuration = 10;
        randomStartRef.current = trackInfo
          ? selectClipStartWithFallback(audioBuffer, dangerZones)
          : Math.random() * Math.max(0, audioBuffer.duration - sliceDuration);

        playSlice(audioBuffer, randomStartRef.current, sliceDuration);
      } finally {
        if (playVersionRef.current === version) {
          setLoading(false);
        }
      }
    },
    [getContext, playSlice, stopPlayback],
  );

  const pause = useCallback(() => {
    if (!playing) return;

    const ctx = audioContextRef.current;
    if (ctx) {
      const segmentElapsed = ctx.currentTime - segmentStartTimeRef.current;
      elapsedBeforePauseRef.current += segmentElapsed;
    }

    haltSource();
    setPlaying(false);
    setPaused(true);
    // Progress stays frozen — do NOT reset
  }, [playing, haltSource]);

  const resume = useCallback(() => {
    const buffer = bufferRef.current;
    if (!paused || !buffer) return;

    const totalElapsed = elapsedBeforePauseRef.current;
    const totalDuration = sliceDurationRef.current;
    const remaining = totalDuration - totalElapsed;

    if (remaining <= 0) {
      setPaused(false);
      return;
    }

    const resumeOffset = sliceOffsetRef.current + totalElapsed;
    startPlaybackSegment(
      buffer,
      resumeOffset,
      remaining,
      totalElapsed,
      totalDuration,
    );
  }, [paused, startPlaybackSegment]);

  const relisten = useCallback(() => {
    const buffer = bufferRef.current;
    if (!buffer) return;

    incrementRelisten();
    const stage = relistenCount + 1;
    const { offset, duration } = getRelistenSlice(
      stage,
      randomStartRef.current,
      buffer.duration,
    );
    playSlice(buffer, offset, duration);
  }, [relistenCount, incrementRelisten, playSlice]);

  // Close AudioContext on unmount to prevent resource leaks
  useEffect(() => {
    return () => {
      audioContextRef.current?.close().catch(() => {});
      audioContextRef.current = null;
    };
  }, []);

  return {
    playing,
    paused,
    loading,
    progress,
    clipDuration,
    relistenStage: relistenCount,
    play,
    relisten,
    pause,
    resume,
    stop: stopPlayback,
    reset,
  };
}

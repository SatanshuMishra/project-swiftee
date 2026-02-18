/**
 * Plays a single quack sound on wrong answer.
 * Volume: 0.9 × user volume setting (0.72 gain at default 0.8 volume).
 */
export async function playQuacks(
  _count: number,
  audioContext: AudioContext,
  quackBuffer: AudioBuffer,
  volume: number,
): Promise<void> {
  const source = audioContext.createBufferSource();
  source.buffer = quackBuffer;

  const gain = audioContext.createGain();
  gain.gain.value = Math.min(volume * 0.9, 1.0);

  source.connect(gain);
  gain.connect(audioContext.destination);

  source.start(audioContext.currentTime);
}

import quackUrl from "../assets/sounds/quack.mp3";

let cachedQuackBuffer: AudioBuffer | null = null;

export async function loadQuackBuffer(
  audioContext: AudioContext,
): Promise<AudioBuffer> {
  if (cachedQuackBuffer) return cachedQuackBuffer;

  const response = await fetch(quackUrl);
  const arrayBuffer = await response.arrayBuffer();
  cachedQuackBuffer = await audioContext.decodeAudioData(arrayBuffer);
  return cachedQuackBuffer;
}

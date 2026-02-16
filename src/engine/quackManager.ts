/**
 * Plays escalating quack sounds based on consecutive wrong answer count.
 * count=1: single soft quack
 * count=2: two at 150ms offset
 * count=3: three louder
 * count=4: four rapid fire
 * count=5+: chaotic overlapping
 */
export async function playQuacks(
  count: number,
  audioContext: AudioContext,
  quackBuffer: AudioBuffer,
  volume: number,
): Promise<void> {
  const effectiveCount = Math.min(count, 8);

  for (let i = 0; i < effectiveCount; i++) {
    const source = audioContext.createBufferSource();
    source.buffer = quackBuffer;

    const gain = audioContext.createGain();
    const quackVolume = Math.min(volume * (0.5 + i * 0.1), 1.0);
    gain.gain.value = quackVolume;

    source.connect(gain);
    gain.connect(audioContext.destination);

    const delay = count >= 5 ? Math.random() * 0.3 : i * 0.15;
    source.start(audioContext.currentTime + delay);
  }
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

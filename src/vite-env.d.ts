/// <reference types="vite/client" />

declare module "*.mp3" {
  const src: string;
  export default src;
}

// Injected at build time by Vite (see `define` in vite.config.ts).
// Sourced from package.json#version.
declare const __APP_VERSION__: string;

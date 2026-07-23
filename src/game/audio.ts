// Audio manager for The U. Loads the pre-existing CC0 ogg files.
// Ambient loops, footstep random selection, UI one-shots.
const AUDIO_DIR = 'assets/audio';

let ambient: HTMLAudioElement | null = null;
let footsteps: HTMLAudioElement[] = [];
let uiOpen: HTMLAudioElement | null = null;
let uiConfirm: HTMLAudioElement | null = null;
let uiClose: HTMLAudioElement | null = null;
let stepIdx = 0;
let initialized = false;

export function initAudio() {
  if (initialized) return;
  initialized = true;

  // Ambient loop
  ambient = new Audio(`${AUDIO_DIR}/ambient_campus.ogg`);
  ambient.loop = true;
  ambient.volume = 0.25;

  // Footstep pool
  for (let i = 1; i <= 4; i++) {
    const af = new Audio(`${AUDIO_DIR}/footstep_${i}.ogg`);
    af.volume = 0.45;
    footsteps.push(af);
  }

  // UI one-shots
  uiOpen = new Audio(`${AUDIO_DIR}/ui_open.ogg`);
  uiOpen.volume = 0.35;
  uiConfirm = new Audio(`${AUDIO_DIR}/ui_confirm.ogg`);
  uiConfirm.volume = 0.35;
  uiClose = new Audio(`${AUDIO_DIR}/ui_close.ogg`);
  uiClose.volume = 0.35;
}

export function startAmbient() {
  ambient?.play().catch(() => {});
}

export function stopAmbient() {
  ambient?.pause();
}

export function playFootstep() {
  if (footsteps.length === 0) return;
  const a = footsteps[stepIdx % footsteps.length];
  stepIdx++;
  a.currentTime = 0;
  a.play().catch(() => {});
}

export function playUIOpen() {
  uiOpen?.play().catch(() => {});
}

export function playUIConfirm() {
  uiConfirm?.play().catch(() => {});
}

export function playUIClose() {
  uiClose?.play().catch(() => {});
}

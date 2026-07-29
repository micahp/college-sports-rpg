/**
 * systems/audioSystem.ts — lightweight WebAudio-based sound engine.
 * Generates procedural SFX (no asset files needed) and manages ambient loops.
 * All sounds are synthesized so there are zero licensing concerns.
 */
import React from 'react';
import { useGameStore } from '../store/gameStore';

let ctx: AudioContext | null = null;
let masterGain: GainNode | null = null;
let ambientNode: OscillatorNode | null = null;
let ambientGain: GainNode | null = null;
let started = false;

function getCtx() {
  if (!ctx) {
    ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    masterGain = ctx.createGain();
    masterGain.gain.value = 0.4;
    masterGain.connect(ctx.destination);
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

/** Play a short tone burst (UI click, swish, etc) */
export function playTone(freq: number, duration: number, type: OscillatorType = 'sine', volume = 0.3) {
  try {
    const c = getCtx();
    const osc = c.createOscillator();
    const gain = c.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.value = volume;
    gain.gain.exponentialRampToValueAtTime(0.001, c.currentTime + duration);
    osc.connect(gain);
    gain.connect(masterGain!);
    osc.start();
    osc.stop(c.currentTime + duration);
  } catch (e) { /* audio not available */ }
}

export function playSwish() {
  // noise burst + descending tone
  playTone(800, 0.15, 'sine', 0.2);
  setTimeout(() => playTone(400, 0.1, 'triangle', 0.15), 50);
}

export function playMiss() {
  playTone(150, 0.2, 'sawtooth', 0.15);
}

export function playClick() {
  playTone(600, 0.05, 'square', 0.1);
}

export function playScore() {
  playTone(523, 0.1, 'sine', 0.25);
  setTimeout(() => playTone(659, 0.1, 'sine', 0.25), 80);
  setTimeout(() => playTone(784, 0.15, 'sine', 0.3), 160);
}

/** Start a soft ambient drone for campus */
export function startAmbient() {
  if (started) return;
  started = true;
  try {
    const c = getCtx();
    ambientGain = c.createGain();
    ambientGain.gain.value = 0.04;
    ambientGain.connect(masterGain!);

    // Soft pad: two detuned oscillators
    const o1 = c.createOscillator();
    const o2 = c.createOscillator();
    o1.type = 'sine';
    o2.type = 'sine';
    o1.frequency.value = 110;
    o2.frequency.value = 110 * 1.01; // slight detune
    o1.connect(ambientGain);
    o2.connect(ambientGain);
    o1.start();
    o2.start();
    ambientNode = o1;
  } catch (e) {}
}

export function setAmbientIntensity(v: number) {
  if (ambientGain) ambientGain.gain.value = v * 0.05;
}

/** React hook: start ambient when entering play phase */
export function useAmbientAudio() {
  const phase = useGameStore((s) => s.phase);
  React.useEffect(() => {
    if (phase === 'playing') startAmbient();
  }, [phase]);
}

/**
 * animation.ts
 *
 * Shared animation math used across the character system: easing curves,
 * frame-rate independent damping, and a small keyframe channel sampler
 * (scalar / euler / quaternion). The animation controller builds its
 * procedural AnimationClips from these primitives so every channel can be
 * authored as a handful of keyframes instead of bakedata.
 */

export type EasingFn = (t: number) => number;

export const Easing = {
  linear: (t: number) => t,
  easeInOutCubic: (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  easeOutCubic: (t: number) => 1 - Math.pow(1 - t, 3),
  easeInCubic: (t: number) => t * t * t,
  easeInOutQuad: (t: number) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  easeOutQuad: (t: number) => 1 - (1 - t) * (1 - t),
  easeInQuad: (t: number) => t * t,
  /** Overshoot settle — good for celebratory poses snapping into place. */
  easeOutBack: (t: number, overshoot = 1.70158) => {
    const c1 = overshoot;
    const c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
  easeOutElastic: (t: number) => {
    if (t === 0 || t === 1) return t;
    const c4 = (2 * Math.PI) / 3;
    return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  },
  /** Smoothstep on [0,1] clamped. */
  smoothstep: (t: number) => {
    const x = Math.max(0, Math.min(1, t));
    return x * x * (3 - 2 * x);
  },
} as const;

export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;
export const invLerp = (a: number, b: number, v: number): number => (v - a) / (b - a);
export const clamp = (v: number, min: number, max: number): number =>
  Math.max(min, Math.min(max, v));
export const clamp01 = (v: number): number => Math.max(0, Math.min(1, v));

/** Wrap an angle (radians) into [-PI, PI]. */
export function normalizeAngle(a: number): number {
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}

/**
 * Frame-rate independent exponential approach toward target.
 * `lambda` is the decay rate (higher = snappier). Based on Ryan Hipple's
 * "damp" from GDC 2015. Returns the new value.
 */
export function damp(current: number, target: number, lambda: number, dt: number): number {
  return lerp(current, target, 1 - Math.exp(-lambda * dt));
}

/**
 * Vector3 damp (per component). Avoids per-component allocations by reusing out.
 */
export function dampVec3(
  current: [number, number, number],
  target: [number, number, number],
  lambda: number,
  dt: number,
  out: [number, number, number]
): void {
  const k = 1 - Math.exp(-lambda * dt);
  out[0] = lerp(current[0], target[0], k);
  out[1] = lerp(current[1], target[1], k);
  out[2] = lerp(current[2], target[2], k);
}

/**
 * critically-damped spring toward target — smooth, no overshoot.
 * Mutates `velocity` in place. Returns new value.
 */
export function smoothDamp(
  current: number,
  target: number,
  velocity: number,
  smoothTime: number,
  dt: number,
  maxSpeed = Infinity
): { value: number; velocity: number } {
  smoothTime = Math.max(0.0001, smoothTime);
  const omega = 2 / smoothTime;
  const x = omega * dt;
  const exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
  let change = current - target;
  const originalTo = target;
  const maxChange = maxSpeed * smoothTime;
  change = clamp(change, -maxChange, maxChange);
  const temp = (velocity + omega * change) * dt;
  let newVelocity = (velocity - omega * temp) * exp;
  let newValue = target + (change + temp) * exp;
  // prevent overshoot
  if (originalTo - current > 0 === newValue > originalTo) {
    newValue = originalTo;
    newVelocity = (newValue - originalTo) / dt;
  }
  return { value: newValue, velocity: newVelocity };
}

/**
 * Generic blend between two normalized animation layers.
 * `t` is the blend weight toward layer B. Uses the chosen easing for
 * non-linear crossfades (default easeInOutCubic).
 */
export function blendToward(
  a: number,
  b: number,
  t: number,
  easing: EasingFn = Easing.easeInOutCubic
): number {
  return lerp(a, b, easing(clamp01(t)));
}

/* ------------------------------------------------------------------ *
 * Keyframe channel sampler
 * ------------------------------------------------------------------ */

export interface ScalarKeyframe {
  time: number;
  value: number;
  easing?: EasingFn;
}

export interface Vec3Keyframe {
  time: number;
  value: [number, number, number];
  easing?: EasingFn;
}

/** Sample a scalar keyframe track at time `t`. Returns the interpolated value. */
export function sampleScalarChannel(frames: ScalarKeyframe[], t: number): number {
  if (frames.length === 0) return 0;
  if (frames.length === 1 || t <= frames[0].time) return frames[0].value;
  if (t >= frames[frames.length - 1].time) return frames[frames.length - 1].value;

  // find segment
  let i = 0;
  while (i < frames.length - 1 && t >= frames[i + 1].time) i++;
  const a = frames[i];
  const b = frames[i + 1];
  const span = b.time - a.time;
  const localT = span > 0 ? (t - a.time) / span : 0;
  const e = b.easing ?? Easing.linear;
  return lerp(a.value, b.value, e(localT));
}

/** Sample a vec3 keyframe track at time `t`. */
export function sampleVec3Channel(frames: Vec3Keyframe[], t: number): [number, number, number] {
  if (frames.length === 0) return [0, 0, 0];
  if (frames.length === 1 || t <= frames[0].time) return [...frames[0].value];
  if (t >= frames[frames.length - 1].time) return [...frames[frames.length - 1].value];

  let i = 0;
  while (i < frames.length - 1 && t >= frames[i + 1].time) i++;
  const a = frames[i];
  const b = frames[i + 1];
  const span = b.time - a.time;
  const localT = span > 0 ? (t - a.time) / span : 0;
  const e = b.easing ?? Easing.linear;
  const k = e(localT);
  return [lerp(a.value[0], b.value[0], k), lerp(a.value[1], b.value[1], k), lerp(a.value[2], b.value[2], k)];
}

/** euler angles (degrees) → radians helper for authoring convenience. */
export const deg = (d: number): number => (d * Math.PI) / 180;

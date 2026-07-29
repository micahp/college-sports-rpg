/**
 * Sky.tsx — dynamic time-of-day sky dome + fog interpolation.
 * Reads gameStore hour, interpolates sky colors across dawn/day/dusk/night.
 */
import React, { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../../store/gameStore';

const PHASES = [
  // night deep
  { hour: 0, top: '#050810', bottom: '#0a0e12' },
  { hour: 5, top: '#0a0e12', bottom: '#0f1020' },
  { hour: 6, top: '#1a2040', bottom: '#3a2848' }, // dawn
  { hour: 7, top: '#2c3e6e', bottom: '#c97048' },
  { hour: 8, top: '#3d6fb0', bottom: '#e8b060' },
  { hour: 12, top: '#4a80c0', bottom: '#c8d8e8' }, // midday
  { hour: 17, top: '#3d6fb0', bottom: '#e8b060' },
  { hour: 18, top: '#2c3e6e', bottom: '#d07038' }, // dusk
  { hour: 19, top: '#1a2040', bottom: '#704038' },
  { hour: 21, top: '#0a0e1a', bottom: '#0f1020' },
  { hour: 24, top: '#050810', bottom: '#0a0e12' },
];

function lerpColor(a: string, b: string, t: number): THREE.Color {
  const ca = new THREE.Color(a);
  const cb = new THREE.Color(b);
  return ca.lerp(cb, t);
}

export const Sky = () => {
  const meshRef = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.ShaderMaterial>(null);

  // Big inverted sphere with a vertical gradient shader
  const geometry = useMemo(() => new THREE.SphereGeometry(300, 32, 16), []);

  const uniforms = useMemo(
    () => ({
      topColor: { value: new THREE.Color('#4a80c0') },
      bottomColor: { value: new THREE.Color('#c8d8e8') },
      horizonColor: { value: new THREE.Color('#e8b060') },
      offset: { value: 20 },
      exponent: { value: 0.7 },
    }),
    []
  );

  useFrame(() => {
    const hour = useGameStore.getState().hour;
    const minute = useGameStore.getState().minute;
    const t = hour + minute / 60;

    // Find surrounding phases
    let lo = PHASES[0];
    let hi = PHASES[PHASES.length - 1];
    for (let i = 0; i < PHASES.length - 1; i++) {
      if (t >= PHASES[i].hour && t <= PHASES[i + 1].hour) {
        lo = PHASES[i];
        hi = PHASES[i + 1];
        break;
      }
    }
    const span = hi.hour - lo.hour;
    const f = span > 0 ? (t - lo.hour) / span : 0;

    uniforms.topColor.value.copy(lerpColor(lo.top, hi.top, f));
    uniforms.bottomColor.value.copy(lerpColor(lo.bottom, hi.bottom, f));
    // Horizon gets warm near dawn/dusk
    const isTwilight = (t >= 5.5 && t <= 8) || (t >= 17 && t <= 20);
    uniforms.horizonColor.value.copy(
      isTwilight
        ? lerpColor('#d07038', '#c8d8e8', 0.3)
        : new THREE.Color('#c8d8e8')
    );
  });

  return (
    <mesh ref={meshRef} geometry={geometry} renderOrder={-1} scale={[-1, 1, 1]}>
      <shaderMaterial
        ref={matRef}
        depthWrite={false}
        side={THREE.BackSide}
        uniforms={uniforms}
        vertexShader={`
          varying vec3 vWorldPosition;
          void main() {
            vec4 worldPos = modelMatrix * vec4(position, 1.0);
            vWorldPosition = worldPos.xyz;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          }
        `}
        fragmentShader={`
          uniform vec3 topColor;
          uniform vec3 bottomColor;
          uniform vec3 horizonColor;
          uniform float offset;
          uniform float exponent;
          varying vec3 vWorldPosition;
          void main() {
            float h = normalize(vWorldPosition + vec3(0.0, offset, 0.0)).y;
            float t = max(pow(max(h, 0.0), exponent), 0.0);
            vec3 col = mix(bottomColor, topColor, t);
            // warm horizon band
            float horizonMix = exp(-abs(h) * 8.0);
            col = mix(col, horizonColor, horizonMix * 0.4);
            gl_FragColor = vec4(col, 1.0);
          }
        `}
      />
    </mesh>
  );
};

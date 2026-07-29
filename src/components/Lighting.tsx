/**
 * Lighting.tsx — sun direction + ambient/hemisphere tuned by time of day.
 * Shadow-casting directional sun moves across the sky dome as hours pass.
 */
import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

export const Lighting = () => {
  const sunRef = useRef<THREE.DirectionalLight>(null);
  const hemiRef = useRef<THREE.HemisphereLight>(null);
  const ambientRef = useRef<THREE.AmbientLight>(null);

  useFrame(() => {
    const hour = useGameStore.getState().hour + useGameStore.getState().minute / 60;
    // Sun angle: 6am east horizon, 12pm overhead, 6pm west horizon
    const sunAngle = ((hour - 6) / 12) * Math.PI; // 0 at 6am, pi at 6pm
    const sunHeight = Math.sin(sunAngle);
    const sunX = Math.cos(sunAngle);

    if (sunRef.current) {
      sunRef.current.position.set(sunX * 60, Math.max(sunHeight, 0.05) * 50, -20);
      // Daylight intensity follows sun height
      const dayFactor = Math.max(0, Math.min(1, sunHeight));
      sunRef.current.intensity = 0.3 + dayFactor * 2.2;
      // Warm at low angles, white at noon
      const warm = 1 - dayFactor;
      sunRef.current.color.setRGB(1, 1 - warm * 0.2, 1 - warm * 0.5);
      sunRef.current.visible = sunHeight > -0.1;
    }

    if (hemiRef.current) {
      const intensity = 0.15 + Math.max(0, sunHeight) * 0.55;
      hemiRef.current.intensity = intensity;
      // Sky blue to ground brown
      hemiRef.current.color.setHSL(0.6, 0.3, 0.5 + sunHeight * 0.2);
      hemiRef.current.groundColor.setHSL(0.08, 0.2, 0.15);
    }

    if (ambientRef.current) {
      // Night ambient higher so scene is not pure black
      const nightBoost = sunHeight < 0 ? 0.2 : 0;
      ambientRef.current.intensity = 0.08 + Math.max(0, sunHeight) * 0.25 + nightBoost;
    }
  });

  return (
    <>
      <ambientLight ref={ambientRef} intensity={0.15} />
      <hemisphereLight ref={hemiRef} intensity={0.4} color="#88aaff" groundColor="#2a1a0a" />
      <directionalLight
        ref={sunRef}
        castShadow
        position={[40, 50, -20]}
        intensity={2.5}
        shadow-mapSize={[2048, 2048]}
        shadow-camera-left={-80}
        shadow-camera-right={80}
        shadow-camera-top={80}
        shadow-camera-bottom={-80}
        shadow-camera-near={0.5}
        shadow-camera-far={200}
        shadow-bias={-0.0004}
        shadow-normalBias={0.02}
      />
    </>
  );
};

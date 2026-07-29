/**
 * basketball/Hoop.tsx — the rim + backboard + pole.
 * The hoop is a torus at regulation height (3.05m). A sensor cylinder underneath
 * detects a scored shot (handled in BasketballBall via position check, but we
 * also place a visible net).
 */
import React, { useMemo } from 'react';
import * as THREE from 'three';

const RIM_RADIUS = 0.225; // half of 45cm diameter
const RIM_HEIGHT = 3.05;

export const Hoop = ({ position }: { position: [number, number, number] }) => {
  const rimGeo = useMemo(() => new THREE.TorusGeometry(RIM_RADIUS, 0.02, 12, 24), []);
  const rimMat = useMemo(() => new THREE.MeshStandardMaterial({
    color: '#d4762a',
    roughness: 0.4,
    metalness: 0.6,
  }), []);

  // Net: a cylinder of lines going downward
  const netGeo = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const vertices: number[] = [];
    const segments = 12;
    const netDepth = 0.4;
    const netBottomRadius = 0.16;
    // Top ring
    for (let i = 0; i < segments; i++) {
      const a1 = (i / segments) * Math.PI * 2;
      const a2 = ((i + 1) / segments) * Math.PI * 2;
      // vertical cords from top to bottom center
      const x1t = Math.cos(a1) * RIM_RADIUS;
      const z1t = Math.sin(a1) * RIM_RADIUS;
      const x1b = Math.cos(a1) * netBottomRadius;
      const z1b = Math.sin(a1) * netBottomRadius;
      vertices.push(x1t, 0, z1t, x1b, -netDepth, z1b);
      // top ring link
      const x2t = Math.cos(a2) * RIM_RADIUS;
      const z2t = Math.sin(a2) * RIM_RADIUS;
      vertices.push(x1t, 0, z1t, x2t, 0, z2t);
    }
    g.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    return g;
  }, []);
  const netMat = useMemo(() => new THREE.LineBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.6 }), []);

  return (
    <group position={position}>
      {/* Rim */}
      <mesh geometry={rimGeo} material={rimMat} rotation={[Math.PI / 2, 0, 0]} position={[0, RIM_HEIGHT, 0]} />

      {/* Net */}
      <lineSegments geometry={netGeo} material={netMat} position={[0, RIM_HEIGHT, 0]} />

      {/* Backboard */}
      <mesh position={[0, RIM_HEIGHT + 0.35, -0.1]} castShadow receiveShadow>
        <boxGeometry args={[1.8, 1.05, 0.05]} />
        <meshStandardMaterial color="#f0ece0" roughness={0.5} metalness={0.1} />
      </mesh>
      {/* Backboard frame */}
      <mesh position={[0, RIM_HEIGHT + 0.35, -0.07]}>
        <boxGeometry args={[1.85, 1.1, 0.02]} />
        <meshStandardMaterial color="#0a1628" roughness={0.3} metalness={0.4} />
      </mesh>
      {/* Inner square target */}
      <mesh position={[0, RIM_HEIGHT + 0.25, -0.04]}>
        <boxGeometry args={[0.59, 0.45, 0.01]} />
        <meshStandardMaterial color="#d4762a" roughness={0.3} metalness={0.3} transparent opacity={0.6} />
      </mesh>

      {/* Support pole */}
      <mesh position={[0, RIM_HEIGHT / 2, -0.9]}>
        <cylinderGeometry args={[0.06, 0.08, RIM_HEIGHT, 12]} />
        <meshStandardMaterial color="#222" roughness={0.5} metalness={0.4} />
      </mesh>
      {/* Base */}
      <mesh position={[0, 0.1, -0.9]}>
        <boxGeometry args={[1.5, 0.2, 1]} />
        <meshStandardMaterial color="#222" roughness={0.6} metalness={0.3} />
      </mesh>
    </group>
  );
};

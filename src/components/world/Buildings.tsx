/**
 * Buildings.tsx — modular building kit.
 * Each building gets a styled box with windows, door, roof, and a floating name label.
 * Windows glow warm at night via emissive material.
 */
import React, { useMemo } from 'react';
import { Text } from '@react-three/drei';
import { LOCATIONS } from '../../data/content';

const NAVY = '#0a1628';
const NAVY_LIGHT = '#142240';
const GOLD = '#d4a843';
const TRIM = '#2a3a5a';

interface BuildingProps {
  id: string;
  name: string;
  position: [number, number, number];
  size: [number, number, number];
  accent?: string;
}

const Building: React.FC<BuildingProps> = ({ name, position, size, accent = NAVY }) => {
  const [w, h, d] = size;

  const windows = useMemo(() => {
    const pts = [];
    const colsFront = Math.max(2, Math.floor(w / 2.5));
    const rows = Math.max(1, Math.floor(h / 2.5));
    const spacingX = w / (colsFront + 1);
    const spacingY = h / (rows + 1);

    for (let r = 1; r <= rows; r++) {
      for (let c = 1; c <= colsFront; c++) {
        const x = -w / 2 + spacingX * c;
        const y = spacingY * r;
        pts.push({ x, y, z: d / 2 + 0.02, face: 'front' });
        pts.push({ x, y, z: -d / 2 - 0.02, face: 'back' });
      }
    }
    const colsSide = Math.max(2, Math.floor(d / 3));
    const spacingZ = d / (colsSide + 1);
    for (let r = 1; r <= rows; r++) {
      for (let c = 1; c <= colsSide; c++) {
        const z = -d / 2 + spacingZ * c;
        const y = spacingY * r;
        pts.push({ x: w / 2 + 0.02, y, z, face: 'left' });
        pts.push({ x: -w / 2 - 0.02, y, z, face: 'right' });
      }
    }
    return pts;
  }, [w, h, d]);

  return (
    <group position={position}>
      <mesh castShadow receiveShadow position={[0, h / 2, 0]}>
        <boxGeometry args={[w, h, d]} />
        <meshStandardMaterial color="#c8b89a" roughness={0.85} />
      </mesh>
      <mesh castShadow position={[0, h * 0.78, 0]}>
        <boxGeometry args={[w + 0.1, 0.25, d + 0.1]} />
        <meshStandardMaterial color={accent} roughness={0.6} metalness={0.1} />
      </mesh>
      <mesh receiveShadow position={[0, 0.15, 0]}>
        <boxGeometry args={[w + 0.4, 0.3, d + 0.4]} />
        <meshStandardMaterial color="#666" roughness={0.7} />
      </mesh>
      <mesh castShadow position={[0, h + 0.2, 0]}>
        <boxGeometry args={[w + 0.3, 0.4, d + 0.3]} />
        <meshStandardMaterial color="#8a7460" roughness={0.7} />
      </mesh>
      <mesh castShadow position={[0, h + 0.6, 0]}>
        <coneGeometry args={[w * 0.55, 0.8, 4]} />
        <meshStandardMaterial color="#8a7460" roughness={0.7} />
      </mesh>
      {windows.map((win, i) => {
        const glow = i % 3 === 0;
        return (
          <mesh
            key={i}
            position={[win.x, win.y, win.z]}
            rotation={[
              0,
              win.face === 'front' ? 0 : win.face === 'back' ? Math.PI : win.face === 'left' ? Math.PI / 2 : -Math.PI / 2,
              0,
            ]}
          >
            <planeGeometry args={[0.9, 1.1]} />
            <meshStandardMaterial
              color={glow ? '#ffeecc' : '#3a4a6a'}
              emissive={glow ? '#ffcc66' : '#000000'}
              emissiveIntensity={glow ? 0.4 : 0}
              roughness={glow ? 0.4 : 0.2}
              metalness={glow ? 0 : 0.5}
              transparent={glow}
              opacity={glow ? 0.95 : 1}
            />
          </mesh>
        );
      })}
      <mesh position={[0, 0.9, d / 2 + 0.05]}>
        <planeGeometry args={[1.6, 1.8]} />
        <meshStandardMaterial color={GOLD} roughness={0.3} metalness={0.5} />
      </mesh>
      <mesh position={[0, 0.9, d / 2 + 0.03]}>
        <boxGeometry args={[1.8, 2.0, 0.05]} />
        <meshStandardMaterial color={accent} roughness={0.6} metalness={0.1} />
      </mesh>
      <Text
        position={[0, h + 1.4, 0]}
        fontSize={1.2}
        color={NAVY}
        anchorX="center"
        anchorY="middle"
        outlineWidth={0.04}
        outlineColor={GOLD}
      >
        {name}
      </Text>
    </group>
  );
};

export const Buildings = () => {
  const buildingData = [
    { id: 'dorm-a', name: 'Ridgeview Hall', position: LOCATIONS['dorm-exterior'].position, size: [16, 9, 14], accent: NAVY },
    { id: 'rec', name: 'Rec Center', position: LOCATIONS['rec-center'].position, size: [26, 10, 18], accent: GOLD },
    { id: 'athletic-center', name: 'Athletics', position: [LOCATIONS['basketball-gym'].position[0], 0, LOCATIONS['basketball-gym'].position[2] + 6], size: [18, 12, 24], accent: NAVY },
    { id: 'stem', name: 'STEM Building', position: LOCATIONS['science-hall'].position, size: [16, 11, 14], accent: TRIM },
    { id: 'arts-sciences', name: 'Arts and Sciences', position: LOCATIONS['main-classroom'].position, size: [14, 9, 16], accent: NAVY_LIGHT },
    { id: 'library', name: 'Carter Library', position: LOCATIONS['library'].position, size: [18, 10, 16], accent: NAVY },
    { id: 'dining', name: 'The Commons', position: LOCATIONS['dining-hall'].position, size: [18, 7, 16], accent: GOLD },
    { id: 'union', name: 'Student Union', position: LOCATIONS['student-union'].position, size: [22, 7, 16], accent: NAVY_LIGHT },
  ];

  return (
    <group>
      {buildingData.map((b) => (
        <Building key={b.id} {...(b as BuildingProps)} />
      ))}
    </group>
  );
};

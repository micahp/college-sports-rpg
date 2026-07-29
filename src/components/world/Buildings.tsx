/**
 * Buildings.tsx — modular building kit with improved visuals.
 * Each building gets varied rooflines, entrance recesses, signage, and distinct color palettes.
 */
import React, { useMemo } from 'react';
import { Text } from '@react-three/drei';
import { RigidBody, CuboidCollider } from '@react-three/rapier';
import { LOCATIONS } from '../../data/content';

const NAVY = '#0a1628';
const NAVY_LIGHT = '#142240';
const GOLD = '#d4a843';
const TRIM = '#2a3a5a';
const CREAM = '#e8dcc0';
const RED_BRICK = '#8a4a3a';
const STONE = '#9a9488';
const DARK_STONE = '#6a6458';

interface BuildingProps {
  id: string;
  name: string;
  position: [number, number, number];
  size: [number, number, number];
  accent?: string;
  variant?: 'dorm' | 'athletic' | 'academic' | 'social' | 'library';
}

const Building: React.FC<BuildingProps> = ({ name, position, size, accent = NAVY, variant = 'academic' }) => {
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
        pts.push({ x, y, z: d / 2 + 0.05, face: 'front' });
        pts.push({ x, y, z: -d / 2 - 0.05, face: 'back' });
      }
    }
    const colsSide = Math.max(2, Math.floor(d / 3));
    const spacingZ = d / (colsSide + 1);
    for (let r = 1; r <= rows; r++) {
      for (let c = 1; c < colsSide; c++) {
        const z = -d / 2 + spacingZ * c;
        const y = spacingY * r;
        pts.push({ x: w / 2 + 0.05, y, z, face: 'left' });
        pts.push({ x: -w / 2 - 0.05, y, z, face: 'right' });
      }
    }
    return pts;
  }, [w, h, d]);

  // Color palette per variant
  const wallColor = variant === 'athletic' ? CREAM : variant === 'dorm' ? RED_BRICK : variant === 'library' ? STONE : variant === 'social' ? '#b8a88a' : '#c8b89a';
  const roofColor = variant === 'athletic' ? NAVY : variant === 'dorm' ? '#5a3a2a' : variant === 'library' ? DARK_STONE : '#4a3a2a';
  const trimColor = variant === 'athletic' ? GOLD : variant === 'social' ? GOLD : TRIM;

  return (
    <RigidBody type="fixed" colliders={false} position={position}>
      <CuboidCollider args={[w / 2, h / 2, d / 2]} position={[0, h / 2, 0]} />
      <group>
        {/* Main body */}
        <mesh castShadow receiveShadow position={[0, h / 2, 0]}>
          <boxGeometry args={[w, h, d]} />
          <meshStandardMaterial color={wallColor} roughness={0.85} />
        </mesh>

        {/* Upper trim band */}
        <mesh castShadow position={[0, h * 0.78, 0]}>
          <boxGeometry args={[w + 0.15, 0.3, d + 0.15]} />
          <meshStandardMaterial color={trimColor} roughness={0.5} metalness={0.15} />
        </mesh>

        {/* Foundation / base */}
        <mesh receiveShadow position={[0, 0.15, 0]}>
          <boxGeometry args={[w + 0.5, 0.3, d + 0.5]} />
          <meshStandardMaterial color={DARK_STONE} roughness={0.8} />
        </mesh>

        {/* Roof — varied style */}
        {variant === 'dorm' ? (
          // Pitched roof (dormitory)
          <mesh castShadow position={[0, h + 0.5, 0]} rotation={[0, Math.PI / 4, 0]}>
            <coneGeometry args={[w * 0.75, 1.2, 4]} />
            <meshStandardMaterial color={roofColor} roughness={0.7} />
          </mesh>
        ) : variant === 'library' ? (
          // Flat roof with parapet
          <>
            <mesh castShadow position={[0, h + 0.15, 0]}>
              <boxGeometry args={[w + 0.2, 0.3, d + 0.2]} />
              <meshStandardMaterial color={roofColor} roughness={0.6} />
            </mesh>
            <mesh castShadow position={[0, h + 0.5, 0]}>
              <boxGeometry args={[w + 0.4, 0.4, d + 0.4]} />
              <meshStandardMaterial color={trimColor} roughness={0.5} metalness={0.2} />
            </mesh>
          </>
        ) : variant === 'athletic' ? (
          // Barrel-vault suggestion (athletic)
          <mesh castShadow position={[0, h + 0.4, 0]}>
            <boxGeometry args={[w + 0.3, 0.8, d + 0.3]} />
            <meshStandardMaterial color={roofColor} roughness={0.5} metalness={0.2} />
          </mesh>
        ) : (
          // Standard cornice roof
          <>
            <mesh castShadow position={[0, h + 0.2, 0]}>
              <boxGeometry args={[w + 0.3, 0.4, d + 0.3]} />
              <meshStandardMaterial color={roofColor} roughness={0.7} />
            </mesh>
            <mesh castShadow position={[0, h + 0.5, 0]}>
              <boxGeometry args={[w + 0.15, 0.15, d + 0.15]} />
              <meshStandardMaterial color={trimColor} roughness={0.4} metalness={0.3} />
            </mesh>
          </>
        )}

        {/* Entrance recess */}
        <mesh position={[0, 1.0, d / 2 + 0.08]}>
          <boxGeometry args={[2.0, 2.0, 0.15]} />
          <meshStandardMaterial color={NAVY} roughness={0.4} metalness={0.2} />
        </mesh>
        {/* Door */}
        <mesh position={[0, 0.9, d / 2 + 0.12]}>
          <planeGeometry args={[1.4, 1.8]} />
          <meshStandardMaterial color={GOLD} roughness={0.3} metalness={0.4} />
        </mesh>
        {/* Door frame */}
        <mesh position={[0, 0.9, d / 2 + 0.1]}>
          <boxGeometry args={[1.6, 2.0, 0.05]} />
          <meshStandardMaterial color={accent} roughness={0.6} metalness={0.1} />
        </mesh>

        {/* Windows with glow variation */}
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
              <planeGeometry args={[0.8, 1.0]} />
              <meshStandardMaterial
                color={glow ? '#ffeecc' : '#3a4a6a'}
                emissive={glow ? '#ffcc66' : '#000000'}
                emissiveIntensity={glow ? 0.5 : 0}
                roughness={glow ? 0.3 : 0.2}
                metalness={glow ? 0 : 0.4}
                transparent={glow}
                opacity={glow ? 0.9 : 1}
              />
            </mesh>
          );
        })}

        {/* Signage plate on building */}
        <mesh position={[0, h * 0.55, d / 2 + 0.06]}>
          <boxGeometry args={[Math.min(w * 0.6, 6), 0.6, 0.04]} />
          <meshStandardMaterial color={NAVY} roughness={0.4} metalness={0.3} />
        </mesh>

        {/* Building name label */}
        <Text
          position={[0, h + (variant === 'dorm' ? 1.4 : 0.9), 0]}
          fontSize={Math.min(1.0, w * 0.08)}
          color={GOLD}
          anchorX="center"
          anchorY="middle"
          outlineWidth={0.03}
          outlineColor="#000"
        >
          {name}
        </Text>
      </group>
    </RigidBody>
  );
};

export const Buildings = () => {
  const buildingData: BuildingProps[] = [
    { id: 'dorm-a', name: 'Ridgeview Hall', position: LOCATIONS['dorm-exterior'].position, size: [16, 9, 14], accent: NAVY, variant: 'dorm' },
    { id: 'rec', name: 'Rec Center', position: LOCATIONS['rec-center'].position, size: [26, 10, 18], accent: GOLD, variant: 'athletic' },
    { id: 'athletic-center', name: 'Athletics', position: [LOCATIONS['basketball-gym'].position[0], 0, LOCATIONS['basketball-gym'].position[2] + 6], size: [18, 12, 24], accent: NAVY, variant: 'athletic' },
    { id: 'stem', name: 'STEM Building', position: LOCATIONS['science-hall'].position, size: [16, 11, 14], accent: TRIM, variant: 'academic' },
    { id: 'arts-sciences', name: 'Arts and Sciences', position: LOCATIONS['main-classroom'].position, size: [14, 9, 16], accent: NAVY_LIGHT, variant: 'academic' },
    { id: 'library', name: 'Carter Library', position: LOCATIONS['library'].position, size: [18, 10, 16], accent: NAVY, variant: 'library' },
    { id: 'dining', name: 'The Commons', position: LOCATIONS['dining-hall'].position, size: [18, 7, 16], accent: GOLD, variant: 'social' },
    { id: 'union', name: 'Student Union', position: LOCATIONS['student-union'].position, size: [22, 7, 16], accent: NAVY_LIGHT, variant: 'social' },
  ];

  return (
    <group>
      {buildingData.map((b) => (
        <Building key={b.id} {...b} />
      ))}
    </group>
  );
};

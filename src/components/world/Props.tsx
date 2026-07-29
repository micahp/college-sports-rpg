/**
 * Props.tsx — campus dressing: banner poles w/ Ridgehawks flags, bulletin board,
 * club table, plaza emblem, food truck.
 */
import React, { useMemo, useRef } from 'react';
import * as THREE from 'three';
import { useFrame } from '@react-three/fiber';
import { Text } from '@react-three/drei';
import { LOCATIONS } from '../../data/content';

const NAVY = '#0a1628';
const GOLD = '#d4a843';

// Simple cloth-like flag with twoanimated wave
function FlagPole({ position }: { position: [number, number, number] }) {
  const flagRef = useRef<THREE.Mesh>(null);
  const geo = useMemo(() => {
    const g = new THREE.PlaneGeometry(1.6, 1, 12, 8);
    return g;
  }, []);

  useFrame((state) => {
    if (!flagRef.current) return;
    const pos = geo.attributes.position;
    const t = state.clock.elapsedTime;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const y = pos.getY(i);
      // Wave amplitude grows toward the free edge (x > 0)
      const wave = Math.sin(t * 3 + x * 2 + y) * 0.12 * (x + 1);
      pos.setZ(i, wave);
    }
    pos.needsUpdate = true;
  });

  return (
    <group position={position}>
      {/* pole */}
      <mesh castShadow position={[0, 2.5, 0]}>
        <cylinderGeometry args={[0.06, 0.06, 5, 8]} />
        <meshStandardMaterial color="#ddd" metalness={0.6} roughness={0.4} />
      </mesh>
      {/* gold ball top */}
      <mesh position={[0, 5.1, 0]}>
        <sphereGeometry args={[0.15, 12, 12]} />
        <meshStandardMaterial color={GOLD} metalness={0.7} roughness={0.3} />
      </mesh>
      {/* flag */}
      <mesh ref={flagRef} geometry={geo} position={[-0.7, 4.4, 0]}>
        <meshStandardMaterial
          color={NAVY}
          side={THREE.DoubleSide}
          roughness={0.8}
          emissive={GOLD}
          emissiveIntensity={0.05}
        />
      </mesh>
      {/* gold stripe on flag */}
      <mesh position={[-0.7, 4.32, 0.01]}>
        <planeGeometry args={[0.6, 0.3]} />
        <meshStandardMaterial color={GOLD} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
}

// Banner strung between two poles on a wall or freestanding
function BannerLine({
  from,
  to,
}: {
  from: [number, number, number];
  to: [number, number, number];
}) {
  const len = Math.hypot(to[0] - from[0], to[2] - from[2]);
  const mid: [number, number, number] = [
    (from[0] + to[0]) / 2,
    (from[1] + to[1]) / 2 - 0.1,
    (from[2] + to[2]) / 2,
  ];
  const angle = Math.atan2(to[2] - from[2], to[0] - from[0]);

  return (
    <group position={mid} rotation={[0, -angle, 0]}>
      {/* string */}
      <mesh position={[0, 0, 0]}>
        <boxGeometry args={[len, 0.02, 0.02]} />
        <meshStandardMaterial color="#ddd" />
      </mesh>
      {/* banner cloth */}
      <mesh position={[0, -0.35, 0]}>
        <planeGeometry args={[len * 0.85, 0.6]} />
        <meshStandardMaterial color={GOLD} side={THREE.DoubleSide} roughness={0.7} />
      </mesh>
      <mesh position={[0, -0.35, 0.01]}>
        <planeGeometry args={[len * 0.6, 0.4]} />
        <meshStandardMaterial color={NAVY} side={THREE.DoubleSide} roughness={0.7} />
      </mesh>
    </group>
  );
}

// Bulletin board
function BulletinBoard({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      {/* frame */}
      <mesh castShadow position={[0, 1.2, 0]}>
        <boxGeometry args={[2.4, 1.6, 0.1]} />
        <meshStandardMaterial color="#5a4028" roughness={0.8} />
      </mesh>
      {/* cork surface */}
      <mesh position={[0, 1.2, 0.06]}>
        <boxGeometry args={[2.2, 1.4, 0.02]} />
        <meshStandardMaterial color="#c8a060" roughness={0.9} />
      </mesh>
      {/* flyers */}
      {[[-0.6, 1.5], [0.2, 1.2], [0.7, 1.6], [-0.3, 0.9]].map(([x, y], i) => (
        <mesh key={i} position={[x, y, 0.09]} rotation={[0, 0, (i - 1.5) * 0.1]}>
          <boxGeometry args={[0.4, 0.5, 0.005]} />
          <meshStandardMaterial
            color={['#d0d0d0', '#e8d8b8', '#b8c8d8', '#d8c0a0'][i]}
            roughness={0.9}
          />
        </mesh>
      ))}
    </group>
  );
}

// Club/promo table
function ClubTable({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      {/* table top */}
      <mesh castShadow position={[0, 0.75, 0]}>
        <cylinderGeometry args={[0.8, 0.7, 0.05, 12]} />
        <meshStandardMaterial color="#ddd" roughness={0.5} metalness={0.1} />
      </mesh>
      {/* leg */}
      <mesh position={[0, 0.37, 0]}>
        <cylinderGeometry args={[0.06, 0.06, 0.74, 8]} />
        <meshStandardMaterial color="#888" roughness={0.5} metalness={0.4} />
      </mesh>
      {/* skirt banner */}
      <mesh position={[0, 0.55, 0]}>
        <cylinderGeometry args={[0.82, 0.72, 0.4, 12, 1, true]} />
        <meshStandardMaterial color={NAVY} side={THREE.DoubleSide} roughness={0.7} />
      </mesh>
      {/* pamphlets */}
      <mesh position={[0, 0.8, 0]}>
        <boxGeometry args={[0.6, 0.04, 0.4]} />
        <meshStandardMaterial color="#f0ece0" roughness={0.9} />
      </mesh>
    </group>
  );
}

// Plaza emblem ( Ridgehawks emblem on the ground )
function PlazaEmblem({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
        <circleGeometry args={[2, 32]} />
        <meshStandardMaterial color={NAVY} roughness={0.6} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 0]}>
        <ringGeometry args={[1.4, 1.6, 32]} />
        <meshStandardMaterial color={GOLD} roughness={0.4} metalness={0.3} />
      </mesh>
      {/* Hawk silhouette (simple diamond-ish shape approximation with a stretched octahedron) */}
      <mesh position={[0, 0.6, 0]} rotation={[0, 0, 0]}>
        <octahedronGeometry args={[1, 0]} />
        <meshStandardMaterial color={GOLD} roughness={0.5} metalness={0.3} />
      </mesh>
    </group>
  );
}

// Food truck near dining hall
function FoodTruck({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      {/* body */}
      <mesh castShadow position={[0, 1, 0]}>
        <boxGeometry args={[4, 2.2, 2.2]} />
        <meshStandardMaterial color="#f0ece0" roughness={0.7} />
      </mesh>
      {/* serving window */}
      <mesh position={[0, 1.2, -1.12]}>
        <boxGeometry args={[2.6, 1.2, 0.05]} />
        <meshStandardMaterial color={NAVY} roughness={0.3} metalness={0.2} />
      </mesh>
      {/* roof */}
      <mesh castShadow position={[0, 2.2, 0]}>
        <boxGeometry args={[4.3, 0.15, 2.5]} />
        <meshStandardMaterial color="#ccc" roughness={0.5} metalness={0.3} />
      </mesh>
      {/* wheels */}
      {[[-1.4, 0.3, 0.9], [1.4, 0.3, 0.9], [-1.4, 0.3, -0.9], [1.4, 0.3, -0.9]].map(
        (p, i) => (
          <mesh key={i} position={p as [number, number, number]} rotation={[Math.PI / 2, 0, 0]}>
            <cylinderGeometry args={[0.3, 0.3, 0.2, 12]} />
            <meshStandardMaterial color="#222" roughness={0.7} />
          </mesh>
        )
      )}
      {/* Text */}
      {/* small text on side omitted for performance */}
    </group>
  );
}

// Outdoor basketball court — visible on campus, triggers minigame
function OutdoorCourt({ position }: { position: [number, number, number] }) {
  const hoopX = 0;
  const hoopZ = -4;
  const rimY = 3.05;

  return (
    <group position={position}>
      {/* Court floor */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, 0]} receiveShadow>
        <planeGeometry args={[15, 14]} />
        <meshStandardMaterial color="#c8a060" roughness={0.7} />
      </mesh>
      {/* Court lines */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.04, 0]}>
        <ringGeometry args={[1.8, 1.85, 32]} />
        <meshStandardMaterial color="#a07838" />
      </mesh>
      {/* Three-point arc */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.04, hoopZ + 2]}>
        <ringGeometry args={[4.5, 4.55, 48, 1, 0, Math.PI]} />
        <meshStandardMaterial color="#ffffff" transparent opacity={0.5} />
      </mesh>
      {/* Pole */}
      <mesh castShadow position={[hoopX, rimY * 0.5, hoopZ - 0.3]}>
        <cylinderGeometry args={[0.08, 0.08, rimY, 8]} />
        <meshStandardMaterial color="#444" metalness={0.6} roughness={0.4} />
      </mesh>
      {/* Backboard */}
      <mesh castShadow position={[hoopX, rimY + 0.3, hoopZ - 0.35]}>
        <boxGeometry args={[1.8, 1.05, 0.06]} />
        <meshStandardMaterial color="#f0ece0" roughness={0.3} metalness={0.1} />
      </mesh>
      {/* Backboard frame */}
      <mesh position={[hoopX, rimY + 0.15, hoopZ - 0.32]}>
        <boxGeometry args={[0.6, 0.04, 0.02]} />
        <meshStandardMaterial color="#d43020" />
      </mesh>
      {/* Rim */}
      <mesh position={[hoopX, rimY, hoopZ]} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.225, 0.015, 8, 24]} />
        <meshStandardMaterial color="#ff6a00" metalness={0.7} roughness={0.3} />
      </mesh>
      {/* Net (simple cone of lines) */}
      <mesh position={[hoopX, rimY - 0.2, hoopZ]}>
        <cylinderGeometry args={[0.18, 0.22, 0.4, 8, 1, true]} />
        <meshStandardMaterial color="#ffffff" transparent opacity={0.4} side={THREE.DoubleSide} />
      </mesh>
      {/* "PLAY" text */}
      <Text
        position={[0, 0.05, hoopZ + 5]}
        fontSize={0.8}
        color="#0a1628"
        anchorX="center"
        rotation={[-Math.PI / 2, 0, 0]}
        outlineWidth={0.02}
        outlineColor="#d4a843"
      >
        {'OUTDOOR COURT'}
      </Text>
    </group>
  );
}

export const Props = () => {
  const recCenter = LOCATIONS['rec-center'].position;
  const quadCenter: [number, number, number] = [0, 0, 10];

  return (
    <group>
      {/* Banner poles framing the rec center entrance */}
      <FlagPole position={[recCenter[0] - 10, 0, recCenter[2] + 8]} />
      <FlagPole position={[recCenter[0] + 10, 0, recCenter[2] + 8]} />
      <BannerLine
        from={[recCenter[0] - 10, 3.5, recCenter[2] + 8]}
        to={[recCenter[0] + 10, 3.5, recCenter[2] + 8]}
      />

      {/* Plaza emblem on quad */}
      <PlazaEmblem position={quadCenter} />

      {/* Bulletin board near quad */}
      <BulletinBoard position={[15, 0, 8]} />
      <BulletinBoard position={[-18, 0, 5]} />

      {/* Club tables on quad */}
      <ClubTable position={[8, 0, 14]} />
      <ClubTable position={[-10, 0, 12]} />

      {/* Food truck near dining */}
      <FoodTruck position={[34, 0, 20]} />

      {/* Outdoor basketball court — close to spawn, visible */}
      <OutdoorCourt position={[0, 0, 22]} />

      {/* Lamp posts along paths are in Campus.Details already */}
    </group>
  );
};

/**
 * NpcManager.tsx — campus NPCs with visible character models.
 * Each NPC has a body, head, hair, and clothing. They walk between scheduled locations.
 */
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { NPCS, getNPCSchedule, getLocation } from '../data/content';
import { Text } from '@react-three/drei';

const PRINCIPALS = Object.keys(NPCS);
const BG_COUNT = 16;

// Clothing colors per NPC role
const SHIRT_COLORS: Record<string, string> = {
  jordan: '#8a2a2a',
  marcus: '#2a5a3a',
  coachriley: '#0a1628',
  tyrell: '#d4a843',
  elena: '#4a2a5a',
};

const SKIN_TONES = ['#e0b080', '#c09060', '#a07040', '#805830', '#603e20'];

export const NpcManager = () => {
  const tmpObj = useMemo(() => new THREE.Object3D(), []);

  // Principal NPCs with schedule targets
  const principals = useMemo(() => {
    return PRINCIPALS.map((id, i) => {
      const def = NPCS[id];
      const startLoc = def?.schedule?.[0]?.location ?? 'quad';
      const loc = getLocation(startLoc);
      const pos = loc ? new THREE.Vector3(...loc.position) : new THREE.Vector3(0, 0, 10);
      return {
        id,
        name: def?.name ?? id,
        skinColor: SKIN_TONES[i % SKIN_TONES.length],
        shirtColor: SHIRT_COLORS[id] ?? '#3a3a5a',
        pantsColor: '#2a2a3a',
        height: 1.72 + (i % 3) * 0.04,
        targetPos: pos.clone().add(new THREE.Vector3((i - 2) * 1.2, 0, (i % 2) * 1.5)),
        currentPos: pos.clone(),
        rotation: i,
      };
    });
  }, []);

  // Background students
  const bgState = useRef(
    Array.from({ length: BG_COUNT }, (_, i) => ({
      pos: new THREE.Vector3((Math.random() - 0.5) * 50, 0, 5 + Math.random() * 30),
      target: new THREE.Vector3((Math.random() - 0.5) * 50, 0, 5 + Math.random() * 30),
      speed: 0.8 + Math.random() * 1.2,
      skinColor: SKIN_TONES[i % SKIN_TONES.length],
      shirtColor: ['#1a4a8a', '#8a2a2a', '#2a5a3a', '#5a2a5a', '#d4a843'][i % 5],
      retargetIn: Math.random() * 5,
    }))
  );

  useFrame((_state, delta) => {
    const hour = useGameStore.getState().hour;

    // Update principals: schedule target
    for (const npc of principals) {
      const entry = getNPCSchedule(npc.id, hour);
      if (entry) {
        const loc = getLocation(entry.location);
        if (loc) {
          npc.targetPos.set(
            loc.position[0] + Math.sin(npc.id.length + hour) * 2.0,
            0,
            loc.position[2] + Math.cos(npc.id.length + hour) * 2.0
          );
        }
      }
      const diff = npc.targetPos.clone().sub(npc.currentPos);
      const dist = diff.length();
      if (dist > 0.1) {
        diff.normalize();
        npc.currentPos.add(diff.multiplyScalar(Math.min(dist, 1.8 * delta)));
        npc.rotation = Math.atan2(diff.x, diff.z);
      }
    }

    // Update background students
    const arr = bgState.current;
    for (let i = 0; i < arr.length; i++) {
      const s = arr[i];
      s.retargetIn -= delta;
      if (s.retargetIn <= 0) {
        s.target.set((Math.random() - 0.5) * 50, 0, 5 + Math.random() * 30);
        s.retargetIn = 4 + Math.random() * 8;
      }
      const d = s.target.clone().sub(s.pos);
      const dist = d.length();
      if (dist > 0.1) {
        d.normalize();
        s.pos.add(d.multiplyScalar(Math.min(dist, s.speed * delta)));
      }
    }
  });

  return (
    <group>
      {/* Principal NPCs — full character models */}
      {principals.map((npc) => (
        <group key={npc.id} position={[npc.currentPos.x, 0, npc.currentPos.z]} rotation={[0, npc.rotation, 0]}>
          {/* Legs */}
          <mesh position={[-0.12, 0.25, 0]} castShadow>
            <capsuleGeometry args={[0.1, 0.4, 4, 6]} />
            <meshStandardMaterial color={npc.pantsColor} roughness={0.7} />
          </mesh>
          <mesh position={[0.12, 0.25, 0]} castShadow>
            <capsuleGeometry args={[0.1, 0.4, 4, 6]} />
            <meshStandardMaterial color={npc.pantsColor} roughness={0.7} />
          </mesh>
          {/* Torso */}
          <mesh position={[0, 0.7, 0]} castShadow>
            <capsuleGeometry args={[0.22, 0.45, 4, 8]} />
            <meshStandardMaterial color={npc.shirtColor} roughness={0.6} />
          </mesh>
          {/* Arms */}
          <mesh position={[-0.32, 0.75, 0]} rotation={[0, 0, 0.15]} castShadow>
            <capsuleGeometry args={[0.07, 0.4, 4, 6]} />
            <meshStandardMaterial color={npc.shirtColor} roughness={0.6} />
          </mesh>
          <mesh position={[0.32, 0.75, 0]} rotation={[0, 0, -0.15]} castShadow>
            <capsuleGeometry args={[0.07, 0.4, 4, 6]} />
            <meshStandardMaterial color={npc.shirtColor} roughness={0.6} />
          </mesh>
          {/* Head */}
          <mesh position={[0, 1.15, 0]} castShadow>
            <sphereGeometry args={[0.2, 10, 10]} />
            <meshStandardMaterial color={npc.skinColor} roughness={0.6} />
          </mesh>
          {/* Hair */}
          <mesh position={[0, 1.28, -0.02]} castShadow>
            <sphereGeometry args={[0.17, 8, 8, 0, Math.PI * 2, 0, Math.PI * 0.55]} />
            <meshStandardMaterial color="#2a1a0a" roughness={0.8} />
          </mesh>
          {/* Name label */}
          <Text position={[0, 1.65, 0]} fontSize={0.28} color="#f0d070" anchorX="center" outlineWidth={0.015} outlineColor="#000">
            {npc.name}
          </Text>
        </group>
      ))}

      {/* Background students — simpler but visible */}
      {bgState.current.map((s, i) => (
        <group key={`bg-${i}`} position={[s.pos.x, 0, s.pos.z]}>
          <mesh position={[0, 0.25, 0]} castShadow>
            <capsuleGeometry args={[0.09, 0.35, 3, 6]} />
            <meshStandardMaterial color="#2a2a3a" roughness={0.7} />
          </mesh>
          <mesh position={[0, 0.65, 0]} castShadow>
            <capsuleGeometry args={[0.18, 0.35, 3, 6]} />
            <meshStandardMaterial color={s.shirtColor} roughness={0.6} />
          </mesh>
          <mesh position={[0, 1.0, 0]} castShadow>
            <sphereGeometry args={[0.17, 8, 8]} />
            <meshStandardMaterial color={s.skinColor} roughness={0.6} />
          </mesh>
        </group>
      ))}
    </group>
  );
};

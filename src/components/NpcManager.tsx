/**
 * NpcManager.tsx — lightweight campus NPCs for QA.
 * Simple capsule meshes (cheap) with name labels. Skinned humanoids restored in perf phase.
 */
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { NPCS, getNPCSchedule, getLocation } from '../data/content';
import { Text } from '@react-three/drei';

const PRINCIPALS = Object.keys(NPCS);
const BG_COUNT = 10;
const SKIN_TONES = ['#e0b080', '#c09060', '#a07040', '#805830', '#603e20'];

export const NpcManager = () => {
  const tmpObj = useMemo(() => new THREE.Object3D(), []);

  // Principal NPCs with their own color + schedule target
  const principals = useMemo(() => {
    return PRINCIPALS.map((id, i) => {
      const def = NPCS[id];
      const startLoc = def?.schedule?.[0]?.location ?? 'quad';
      const loc = getLocation(startLoc);
      const pos = loc ? new THREE.Vector3(...loc.position) : new THREE.Vector3(0, 0, 10);
      return {
        id,
        name: def?.name ?? id,
        color: new THREE.Color(SKIN_TONES[i % SKIN_TONES.length]),
        height: 1.72 + (i % 3) * 0.04,
        targetPos: pos.clone().add(new THREE.Vector3(i * 1.5, 0, i * 0.8)),
        currentPos: pos.clone(),
        rotation: i,
      };
    });
  }, []);

  // Background students
  const bgState = useRef(
    Array.from({ length: BG_COUNT }, (_, i) => ({
      pos: new THREE.Vector3((Math.random() - 0.5) * 60, 0.9, 8 + Math.random() * 30),
      target: new THREE.Vector3((Math.random() - 0.5) * 60, 0.9, 8 + Math.random() * 30),
      speed: 0.8 + Math.random() * 0.8,
      skinColor: new THREE.Color(SKIN_TONES[i % SKIN_TONES.length]),
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
          npc.targetPos.set(loc.position[0] + Math.sin(npc.id.length) * 1.5, 0, loc.position[2] + Math.cos(npc.id.length) * 1.5);
        }
      }
      const diff = npc.targetPos.clone().sub(npc.currentPos);
      const dist = diff.length();
      if (dist > 0.1) {
        diff.normalize();
        npc.currentPos.add(diff.multiplyScalar(Math.min(dist, 2.0 * delta)));
        npc.rotation = Math.atan2(diff.x, diff.z);
      }
    }

    // Update background students
    const arr = bgState.current;
    for (let i = 0; i < arr.length; i++) {
      const s = arr[i];
      s.retargetIn -= delta;
      if (s.retargetIn <= 0) {
        s.target.set((Math.random() - 0.5) * 60, 0.9, 8 + Math.random() * 30);
        s.retargetIn = 5 + Math.random() * 8;
      }
      const d = s.target.clone().sub(s.pos);
      const dist = d.length();
      if (dist > 0.1) {
        d.normalize();
        s.pos.add(d.multiplyScalar(Math.min(dist, s.speed * delta)));
      }
    }
  });

  const bodyGeo = useMemo(() => new THREE.CapsuleGeometry(0.28, 1.1, 4, 8), []);
  const headGeo = useMemo(() => new THREE.SphereGeometry(0.22, 8, 8), []);

  return (
    <group>
      {/* Principal NPCs */}
      {principals.map((npc) => (
        <group key={npc.id} position={[npc.currentPos.x, 0, npc.currentPos.z]}>
          {/* Body */}
          <mesh position={[0, npc.height * 0.5, 0]} rotation={[0, npc.rotation, 0]} castShadow>
            <primitive object={bodyGeo} attach="geometry" />
            <meshStandardMaterial color={npc.color} roughness={0.7} />
          </mesh>
          {/* Head */}
          <mesh position={[0, npc.height * 0.95, 0]} castShadow>
            <primitive object={headGeo} attach="geometry" />
            <meshStandardMaterial color={npc.color} roughness={0.7} />
          </mesh>
          {/* Name label */}
          <Text position={[0, npc.height + 0.4, 0]} fontSize={0.3} color="#f0d070" anchorX="center" outlineWidth={0.02} outlineColor="#000">
            {npc.name}
          </Text>
        </group>
      ))}

      {/* Background students - simple single mesh */}
      {bgState.current.map((s, i) => (
        <mesh key={`bg-${i}`} position={[s.pos.x, 0.9, s.pos.z]}>
          <capsuleGeometry args={[0.25, 1.0, 4, 8]} />
          <meshStandardMaterial color={s.skinColor} roughness={0.8} />
        </mesh>
      ))}
    </group>
  );
};

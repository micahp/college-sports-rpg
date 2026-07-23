import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { buildCharacter, type CharacterSpec } from './characters';

// Background students with their own little lives: walking loops, sitting on
// benches, standing in pairs. Varied looks derived from the same builder.

const STUDENT_SPECS: CharacterSpec[] = [
  { skin: '#e8b48a', hairColor: '#6b4a2f', hairStyle: 'waves', top: '#7a9cc6', topStyle: 'hoodie', bottoms: '#2e3440', bottomsStyle: 'jeans', shoes: '#d9d4c7', accent: '#e8e2d4', accessory: 'backpack', build: 'slim' },
  { skin: '#8a5a3b', hairColor: '#141210', hairStyle: 'locs', top: '#c94f6d', topStyle: 'tee', bottoms: '#3d4451', bottomsStyle: 'joggers', shoes: '#e8e6e1', accent: '#f5d76e', accessory: 'none', build: 'athletic' },
  { skin: '#f0c8a0', hairColor: '#a86b32', hairStyle: 'ponytail', top: '#e8e2d4', topStyle: 'tank', bottoms: '#1F335C', bottomsStyle: 'leggings', shoes: '#c9c4b7', accent: '#c94f6d', accessory: 'none', build: 'slim' },
  { skin: '#a5715a', hairColor: '#241d16', hairStyle: 'short', top: '#4a7a5c', topStyle: 'tee', bottoms: '#232a36', bottomsStyle: 'shorts', shoes: '#d9d4c7', accent: '#e8e2d4', accessory: 'cap', build: 'stocky' },
  { skin: '#c68863', hairColor: '#0f0c09', hairStyle: 'bun', top: '#EBB84D', topStyle: 'hoodie', bottoms: '#2e3440', bottomsStyle: 'jeans', shoes: '#e8e6e1', accent: '#1F335C', accessory: 'backpack', build: 'slim' },
  { skin: '#d9a078', hairColor: '#3a2a1a', hairStyle: 'braids', top: '#5a6a80', topStyle: 'jacket', bottoms: '#3d4451', bottomsStyle: 'joggers', shoes: '#f0ede6', accent: '#EBB84D', accessory: 'none', build: 'athletic' },
];

type Routine =
  | { kind: 'walk'; from: [number, number]; to: [number, number]; speed: number }
  | { kind: 'sit'; at: [number, number]; facing: number }
  | { kind: 'stand'; at: [number, number]; facing: number }
  | { kind: 'pair'; at: [number, number]; facing: number };

const ROUTINES: Routine[] = [
  { kind: 'walk', from: [-20, 16], to: [18, -14], speed: 1.4 },
  { kind: 'walk', from: [20, 14], to: [-16, -16], speed: 1.1 },
  { kind: 'walk', from: [-4, 20], to: [2, -20], speed: 1.6 },
  { kind: 'sit', at: [9.6, 12.6], facing: -2.4 },
  { kind: 'pair', at: [-9, 2], facing: 1.2 },
  { kind: 'pair', at: [-9.9, 2.6], facing: -1.8 },
];

export function Students() {
  const students = useMemo(
    () =>
      ROUTINES.map((routine, i) => ({
        spec: STUDENT_SPECS[i % STUDENT_SPECS.length],
        routine,
        model: buildCharacter(STUDENT_SPECS[i % STUDENT_SPECS.length]),
        phase: Math.random() * 10,
      })),
    [],
  );
  return (
    <group>
      {students.map((s, i) => (
        <Student key={i} {...s} />
      ))}
    </group>
  );
}

function Student({
  model,
  routine,
  phase,
}: {
  spec: CharacterSpec;
  model: THREE.Group;
  routine: Routine;
  phase: number;
}) {
  const g = useRef<THREE.Group>(null);
  const t = useRef(phase);

  useFrame((_, dt) => {
    t.current += dt;
    const grp = g.current;
    if (!grp) return;

    if (routine.kind === 'walk') {
      const { from, to, speed } = routine;
      const dx = to[0] - from[0];
      const dz = to[1] - from[1];
      const len = Math.hypot(dx, dz);
      const cycle = (len * 2) / speed; // there and back
      const tt = (t.current % cycle) / cycle;
      const k = tt < 0.5 ? tt * 2 : (1 - tt) * 2; // ping-pong
      const x = from[0] + dx * k;
      const z = from[1] + dz * k;
      grp.position.set(x, 0, z);
      const dir = tt < 0.5 ? 1 : -1;
      grp.rotation.y = Math.atan2(dx * dir, dz * dir);
      model.position.y = Math.abs(Math.sin(t.current * 7)) * 0.04;
    } else {
      const at = routine.at;
      grp.position.set(at[0], routine.kind === 'sit' ? -0.35 : 0, at[1]);
      grp.rotation.y = routine.facing;
      model.position.y = Math.sin(t.current * 1.5) * 0.008;
      if (routine.kind === 'pair') {
        // chatting: gentle gesture sway
        model.rotation.z = Math.sin(t.current * 1.1) * 0.02;
      }
    }
  });

  return (
    <group ref={g}>
      <primitive object={model} />
    </group>
  );
}

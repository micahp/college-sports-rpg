import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { buildCharacter, CAST } from './characters';
import { useGame } from './store';
import { useProx } from './prox';
import { npcs } from './content';

export interface NpcPlacement {
  id: string;
  castKey: keyof typeof CAST;
  position: [number, number, number];
  facing: number;
}

export const NPC_PLACEMENTS: NpcPlacement[] = [
  { id: 'jordan', castKey: 'jordan', position: [-7, 0, 8], facing: 0.8 },
  { id: 'leader', castKey: 'dee', position: [4, 0, -6], facing: 2.6 },
  { id: 'coach', castKey: 'coach', position: [2.5, 0, -18], facing: 3.1 },
];

export function Npcs() {
  const setNearNpc = useProx((s) => s.setNearNpc);
  return (
    <group>
      {NPC_PLACEMENTS.map((p) => (
        <Npc key={p.id} placement={p} onApproach={setNearNpc} />
      ))}
    </group>
  );
}

function Npc({ placement, onApproach }: { placement: NpcPlacement; onApproach: (id: string | null) => void }) {
  const model = useMemo(() => buildCharacter(CAST[placement.castKey]), [placement.castKey]);
  const group = useRef<THREE.Group>(null);
  const idle = useRef(Math.random() * 10);
  const near = useRef(false);
  const talkedTo = useGame((s) => s.talkedTo.includes(placement.id));

  useFrame((state, dt) => {
    idle.current += dt;
    // subtle breathing/sway so nobody looks frozen
    model.position.y = Math.sin(idle.current * 1.6) * 0.008;
    model.rotation.y = Math.sin(idle.current * 0.4) * 0.05;

    // proximity check against camera-followed player position stored on window (set by Player frame)
    const g = group.current;
    if (g) {
      const pp = (window as any).__playerPos as THREE.Vector3 | undefined;
      if (pp) {
        const d = g.position.distanceTo(pp);
        const isNear = d < 2.6;
        if (isNear !== near.current) {
          near.current = isNear;
          onApproach(isNear ? placement.id : null);
        }
      }
    }
  });

  return (
    <group ref={group} position={placement.position} rotation={[0, placement.facing, 0]}>
      <primitive object={model} />
      {/* interaction ring */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, 0]}>
        <ringGeometry args={[0.7, 0.85, 32]} />
        <meshBasicMaterial color={talkedTo ? '#5a6a80' : '#EBB84D'} transparent opacity={0.7} />
      </mesh>
    </group>
  );
}

export function npcDef(id: string) {
  return npcs[id];
}

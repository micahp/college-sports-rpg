import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useKeyboardControls } from '@react-three/drei';
import { buildCharacter, CAST } from './characters';
import { playFootstep } from './audio';

// Player controller: WASD/arrows + touch joystick vector (from input store below).
// Character-focused camera: close third-person follow with slight look-ahead.

export const inputVector = { x: 0, z: 0 }; // written by joystick overlay + keys

export function Player({ position = [0, 0, 6] as [number, number, number] }) {
  const group = useRef<THREE.Group>(null);
  const model = useMemo(() => buildCharacter(CAST.player), []);
  const vel = useRef(new THREE.Vector3());
  const heading = useRef(Math.PI);
  const bobPhase = useRef(0);
  const stepTimer = useRef(0);

  useFrame((state, dt) => {
    const g = group.current;
    if (!g) return;

    const speed = 3.2;
    const ix = inputVector.x;
    const iz = inputVector.z;
    const moving = Math.abs(ix) > 0.01 || Math.abs(iz) > 0.01;

    vel.current.set(ix * speed, 0, iz * speed);
    g.position.addScaledVector(vel.current, dt);

    // clamp to quad bounds
    g.position.x = THREE.MathUtils.clamp(g.position.x, -26, 26);
    g.position.z = THREE.MathUtils.clamp(g.position.z, -20, 22);

    if (moving) {
      const target = Math.atan2(ix, iz);
      heading.current = dampAngle(heading.current, target, 12, dt);
      bobPhase.current += dt * 9;
      // footstep timing
      stepTimer.current -= dt;
      if (stepTimer.current <= 0) {
        playFootstep();
        stepTimer.current = 0.48; // ~2 steps/sec at walk speed
      }
    } else {
      bobPhase.current += dt * 2;
    }
    g.rotation.y = heading.current;

    // publish position for NPC proximity checks
    (window as any).__playerPos = g.position;

    // walk bob + subtle lean
    const bob = moving ? Math.abs(Math.sin(bobPhase.current)) * 0.05 : Math.sin(bobPhase.current) * 0.008;
    model.position.y = bob;
    model.rotation.x = moving ? 0.06 : 0;

    // camera: character-focused, close over-shoulder framing
    const cam = state.camera;
    const behind = new THREE.Vector3(Math.sin(heading.current), 0, Math.cos(heading.current)).multiplyScalar(-3.1);
    const camTarget = g.position.clone().add(behind).add(new THREE.Vector3(0, 1.9, 0));
    cam.position.lerp(camTarget, 1 - Math.exp(-4 * dt));
    const lookAt = g.position.clone().add(new THREE.Vector3(0, 1.15, 0)).addScaledVector(vel.current, 0.3);
    cam.lookAt(lookAt);
  });

  return (
    <group ref={group} position={position}>
      <primitive object={model} />
    </group>
  );
}

function dampAngle(current: number, target: number, lambda: number, dt: number) {
  let delta = target - current;
  while (delta > Math.PI) delta -= Math.PI * 2;
  while (delta < -Math.PI) delta += Math.PI * 2;
  return current + delta * (1 - Math.exp(-lambda * dt));
}

// Keyboard hookup — call once at scene level.
export function useKeyboardMovement() {
  const [, getKeys] = useKeyboardControls();
  useFrame(() => {
    const k = getKeys() as Record<string, boolean>;
    let x = 0;
    let z = 0;
    if (k.forward) z -= 1;
    if (k.back) z += 1;
    if (k.left) x -= 1;
    if (k.right) x += 1;
    // touch joystick wins when active
    if (Math.abs(inputVector.x) > 0.01 || Math.abs(inputVector.z) > 0.01) return;
    const len = Math.hypot(x, z) || 1;
    inputVector.x = x / len;
    inputVector.z = z / len;
  });
}

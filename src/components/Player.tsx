/**
 * Player.tsx — physics character controller + visible character with face and college clothing.
 */
import React, { useRef } from 'react';
import { RigidBody, CapsuleCollider } from '@react-three/rapier';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { useInputStore } from '../store/inputStore';
import { setPlayerWorldPosition } from './CameraRig';
import { playFootstep } from '../systems/audioSystem';

const WALK_SPEED = 4.5;
const RUN_SPEED = 8.5;
const ACCELERATION = 3.5;
const DAMPING = 8.0;

export const Player = () => {
  const bodyRef = useRef(null);
  const meshGroupRef = useRef<THREE.Group>(null);
  const velocity = useRef(new THREE.Vector3());
  const stepTimer = useRef(0);
  const facingRef = useRef(0);

  useFrame((_state, delta) => {
    const input = useInputStore.getState();
    const gs = useGameStore.getState();
    const dt = Math.min(delta, 0.05);

    if (!bodyRef.current) return;
    const rb = bodyRef.current as any;

    const paused = gs.ui.paused || gs.ui.dialogueActive || gs.ui.basketballMode;

    if (paused) {
      rb.setLinvel({ x: 0, y: rb.linvel().y, z: 0 }, true);
      return;
    }

    const dir = new THREE.Vector3(input.moveX, 0, input.moveY);
    const moving = dir.length() > 0.1;

    if (moving) {
      dir.normalize();
      const speed = input.sprint ? RUN_SPEED : WALK_SPEED;
      velocity.current.x = THREE.MathUtils.damp(velocity.current.x, dir.x * speed, ACCELERATION, dt);
      velocity.current.z = THREE.MathUtils.damp(velocity.current.z, dir.z * speed, ACCELERATION, dt);
      const targetAngle = Math.atan2(velocity.current.x, velocity.current.z);
      facingRef.current = THREE.MathUtils.lerp(facingRef.current, targetAngle, 1 - Math.exp(-12 * dt));
    } else {
      velocity.current.x = THREE.MathUtils.damp(velocity.current.x, 0, DAMPING, dt);
      velocity.current.z = THREE.MathUtils.damp(velocity.current.z, 0, DAMPING, dt);
    }

    rb.setLinvel({ x: velocity.current.x, y: rb.linvel().y, z: velocity.current.z }, true);

    // Footstep sounds
    const spd = Math.hypot(velocity.current.x, velocity.current.z);
    if (spd > 0.5) {
      stepTimer.current -= dt;
      if (stepTimer.current <= 0) {
        playFootstep();
        stepTimer.current = spd > 6 ? 0.28 : 0.4;
      }
    } else {
      stepTimer.current = 0;
    }

    // Position mesh group at rigidbody
    const pos = rb.translation();
    if (meshGroupRef.current) {
      meshGroupRef.current.position.set(pos.x, pos.y, pos.z);
      meshGroupRef.current.rotation.y = facingRef.current;
    }

    // Push to camera
    setPlayerWorldPosition(new THREE.Vector3(pos.x, pos.y + 1.5, pos.z));

    // Interaction: basketball (only on E press, not auto)
    if (input.interact && !gs.ui.basketballMode) {
      const cdx = pos.x - 0;
      const cdz = pos.z - 22;
      if (Math.hypot(cdx, cdz) < 6) {
        useGameStore.getState().enterBasketballMode('free');
      }
    }
  });

  // Player colors from profile
  const gs = useGameStore.getState();
  const skinTone = gs.player?.skinTone ?? 3;
  const skinColor = new THREE.Color().setHSL(0.07, 0.45 + skinTone * 0.04, 0.38 + skinTone * 0.05);
  const hairColor = new THREE.Color().setHSL(0.05, 0.3 + (gs.player?.hairColor ?? 0) * 0.05, 0.15 + (gs.player?.hairColor ?? 0) * 0.03);
  const hoodieColor = new THREE.Color('#1a4a8a'); // Ridgehawks navy
  const shortsColor = new THREE.Color('#2a2a3a');
  const shoeColor = new THREE.Color('#f0ece0');

  return (
    <group>
      <RigidBody
        ref={bodyRef}
        enabledRotations={[false, false, false]}
        position={[0, 1.0, 32]}
        mass={1}
        friction={0.5}
        restitution={0}
        linearDamping={0.05}
        angularDamping={1}
        gravityScale={1.0}
        type="dynamic"
        colliders={false}
        userData={{ tag: 'player' }}
      >
        <CapsuleCollider args={[0.5, 0.35]} position={[0, 0.5, 0]} />
      </RigidBody>
      <group ref={meshGroupRef}>
        {/* Basketball shorts */}
        <mesh position={[-0.1, 0.22, 0]} castShadow>
          <capsuleGeometry args={[0.12, 0.35, 4, 8]} />
          <meshStandardMaterial color={shortsColor} roughness={0.7} />
        </mesh>
        <mesh position={[0.1, 0.22, 0]} castShadow>
          <capsuleGeometry args={[0.12, 0.35, 4, 8]} />
          <meshStandardMaterial color={shortsColor} roughness={0.7} />
        </mesh>
        {/* Shoes */}
        <mesh position={[-0.1, 0.04, 0.04]} castShadow>
          <boxGeometry args={[0.14, 0.08, 0.22]} />
          <meshStandardMaterial color={shoeColor} roughness={0.5} />
        </mesh>
        <mesh position={[0.1, 0.04, 0.04]} castShadow>
          <boxGeometry args={[0.14, 0.08, 0.22]} />
          <meshStandardMaterial color={shoeColor} roughness={0.5} />
        </mesh>
        {/* Hoodie torso */}
        <mesh position={[0, 0.65, 0]} castShadow>
          <capsuleGeometry args={[0.25, 0.4, 4, 10]} />
          <meshStandardMaterial color={hoodieColor} roughness={0.7} />
        </mesh>
        {/* Hoodie pocket/kangaroo pouch */}
        <mesh position={[0, 0.5, 0.18]}>
          <boxGeometry args={[0.28, 0.15, 0.04]} />
          <meshStandardMaterial color={hoodieColor} roughness={0.8} />
        </mesh>
        {/* Hood (behind head) */}
        <mesh position={[0, 1.05, -0.08]} castShadow>
          <sphereGeometry args={[0.18, 10, 10, 0, Math.PI * 2, 0, Math.PI * 0.5]} />
          <meshStandardMaterial color={hoodieColor} roughness={0.7} />
        </mesh>
        {/* Arms with sleeves */}
        <mesh position={[-0.34, 0.68, 0]} rotation={[0, 0, 0.2]} castShadow>
          <capsuleGeometry args={[0.08, 0.38, 4, 6]} />
          <meshStandardMaterial color={hoodieColor} roughness={0.7} />
        </mesh>
        <mesh position={[0.34, 0.68, 0]} rotation={[0, 0, -0.2]} castShadow>
          <capsuleGeometry args={[0.08, 0.38, 4, 6]} />
          <meshStandardMaterial color={hoodieColor} roughness={0.7} />
        </mesh>
        {/* Hands */}
        <mesh position={[-0.4, 0.42, 0]} castShadow>
          <sphereGeometry args={[0.06, 8, 8]} />
          <meshStandardMaterial color={skinColor} roughness={0.6} />
        </mesh>
        <mesh position={[0.4, 0.42, 0]} castShadow>
          <sphereGeometry args={[0.06, 8, 8]} />
          <meshStandardMaterial color={skinColor} roughness={0.6} />
        </mesh>
        {/* Head */}
        <mesh position={[0, 1.15, 0]} castShadow>
          <sphereGeometry args={[0.19, 16, 16]} />
          <meshStandardMaterial color={skinColor} roughness={0.5} />
        </mesh>
        {/* Eyes */}
        <mesh position={[-0.07, 1.18, 0.16]}>
          <sphereGeometry args={[0.035, 8, 8]} />
          <meshStandardMaterial color="#ffffff" roughness={0.3} />
        </mesh>
        <mesh position={[0.07, 1.18, 0.16]}>
          <sphereGeometry args={[0.035, 8, 8]} />
          <meshStandardMaterial color="#ffffff" roughness={0.3} />
        </mesh>
        {/* Pupils */}
        <mesh position={[-0.07, 1.18, 0.19]}>
          <sphereGeometry args={[0.018, 6, 6]} />
          <meshStandardMaterial color="#1a1a2a" roughness={0.2} />
        </mesh>
        <mesh position={[0.07, 1.18, 0.19]}>
          <sphereGeometry args={[0.018, 6, 6]} />
          <meshStandardMaterial color="#1a1a2a" roughness={0.2} />
        </mesh>
        {/* Eyebrows */}
        <mesh position={[-0.07, 1.23, 0.16]} rotation={[0, 0, 0.1]}>
          <boxGeometry args={[0.06, 0.015, 0.02]} />
          <meshStandardMaterial color={hairColor} roughness={0.8} />
        </mesh>
        <mesh position={[0.07, 1.23, 0.16]} rotation={[0, 0, -0.1]}>
          <boxGeometry args={[0.06, 0.015, 0.02]} />
          <meshStandardMaterial color={hairColor} roughness={0.8} />
        </mesh>
        {/* Nose */}
        <mesh position={[0, 1.13, 0.18]}>
          <sphereGeometry args={[0.025, 6, 6]} />
          <meshStandardMaterial color={skinColor} roughness={0.5} />
        </mesh>
        {/* Mouth */}
        <mesh position={[0, 1.06, 0.17]} rotation={[0.1, 0, 0]}>
          <boxGeometry args={[0.08, 0.015, 0.01]} />
          <meshStandardMaterial color="#8a3a3a" roughness={0.6} />
        </mesh>
        {/* Hair */}
        <mesh position={[0, 1.27, -0.03]} castShadow>
          <sphereGeometry args={[0.17, 12, 12, 0, Math.PI * 2, 0, Math.PI * 0.55]} />
          <meshStandardMaterial color={hairColor} roughness={0.8} />
        </mesh>
        {/* Side hair */}
        <mesh position={[-0.14, 1.2, -0.02]} castShadow>
          <sphereGeometry args={[0.08, 8, 8]} />
          <meshStandardMaterial color={hairColor} roughness={0.8} />
        </mesh>
        <mesh position={[0.14, 1.2, -0.02]} castShadow>
          <sphereGeometry args={[0.08, 8, 8]} />
          <meshStandardMaterial color={hairColor} roughness={0.8} />
        </mesh>
      </group>
    </group>
  );
};

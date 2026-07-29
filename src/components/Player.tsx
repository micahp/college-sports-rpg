/**
 * Player.tsx — physics character controller + visible capsule character.
 * Reads inputStore, drives a Rapier RigidBody, syncs mesh.
 */
import React, { useRef } from 'react';
import { RigidBody, CapsuleCollider } from '@react-three/rapier';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { useInputStore } from '../store/inputStore';
import { setPlayerWorldPosition } from './CameraRig';
import { LOCATIONS } from '../data/content';
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

    const paused = gs.ui.paused || gs.ui.dialogueActive;

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

    // Interaction: basketball
    if (input.interact && !gs.ui.basketballMode) {
      // Outdoor court at [0, 0, 22] (close to spawn)
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
  const shirtColor = new THREE.Color('#1a4a8a');
  const pantsColor = new THREE.Color('#2a2a3a');

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
        {/* Legs */}
        <mesh position={[-0.12, 0.25, 0]} castShadow>
          <capsuleGeometry args={[0.1, 0.4, 4, 8]} />
          <meshStandardMaterial color={pantsColor} roughness={0.7} />
        </mesh>
        <mesh position={[0.12, 0.25, 0]} castShadow>
          <capsuleGeometry args={[0.1, 0.4, 4, 8]} />
          <meshStandardMaterial color={pantsColor} roughness={0.7} />
        </mesh>
        {/* Torso */}
        <mesh position={[0, 0.7, 0]} castShadow>
          <capsuleGeometry args={[0.22, 0.45, 4, 10]} />
          <meshStandardMaterial color={shirtColor} roughness={0.6} />
        </mesh>
        {/* Arms */}
        <mesh position={[-0.32, 0.75, 0]} rotation={[0, 0, 0.2]} castShadow>
          <capsuleGeometry args={[0.07, 0.4, 4, 6]} />
          <meshStandardMaterial color={shirtColor} roughness={0.6} />
        </mesh>
        <mesh position={[0.32, 0.75, 0]} rotation={[0, 0, -0.2]} castShadow>
          <capsuleGeometry args={[0.07, 0.4, 4, 6]} />
          <meshStandardMaterial color={shirtColor} roughness={0.6} />
        </mesh>
        {/* Head */}
        <mesh position={[0, 1.15, 0]} castShadow>
          <sphereGeometry args={[0.2, 12, 12]} />
          <meshStandardMaterial color={skinColor} roughness={0.6} />
        </mesh>
        {/* Hair */}
        <mesh position={[0, 1.28, -0.02]} castShadow>
          <sphereGeometry args={[0.18, 10, 10, 0, Math.PI * 2, 0, Math.PI * 0.6]} />
          <meshStandardMaterial color="#2a1a0a" roughness={0.8} />
        </mesh>
      </group>
    </group>
  );
};

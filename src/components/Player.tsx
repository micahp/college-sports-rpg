/**
 * Player.tsx — physics character controller + skinned character visual.
 * Reads inputStore, drives a Rapier RigidBody, syncs mesh, drives animation.
 */
import React, { useRef, useMemo } from 'react';
import { RigidBody, CapsuleCollider } from '@react-three/rapier';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { useInputStore } from '../store/inputStore';
import { buildSkeleton, buildSkinnedHumanoid } from './characters/characterModel';
import { AnimationController } from '../systems/animationController';
import { setPlayerWorldPosition } from './CameraRig';
import { LOCATIONS } from '../data/content';

// Tuning
const WALK_SPEED = 4.0;
const RUN_SPEED = 8.0;
const ACCELERATION = 3.0;
const DAMPING = 8.0;
const GRAVITY_SCALE = 1.0;

export const Player = () => {
  const bodyRef = useRef(null);
  const meshGroupRef = useRef<THREE.Group>(null);
  const controller = useRef<AnimationController | null>(null);
  const velocity = useRef(new THREE.Vector3());
  const facing = useRef(0);

  // Build character skeleton + skinned mesh once
  const { skeleton, mesh } = useMemo(() => {
    const s = buildSkeleton(1.78);
    // Skin tone from player profile
    const gs = useGameStore.getState();
    const skinTone = gs.player?.skinTone ?? 3;
    const build = gs.player?.bodyType ?? 'athletic';
    const skinColor = new THREE.Color().setHSL(0.07, 0.4 + skinTone * 0.05, 0.35 + skinTone * 0.06);
    const m = buildSkinnedHumanoid(s, { height: 1.78, build: build === 'slim' ? 'slim' : build === 'muscular' ? 'muscular' : 'athletic' });
    (m.material as THREE.MeshStandardMaterial).color.copy(skinColor);
    return { skeleton: s, mesh: m };
  }, []);

  const facingRef = useRef(0);

  useFrame((_state, delta) => {
    const input = useInputStore.getState();
    const gs = useGameStore.getState();
    const dt = Math.min(delta, 0.05);

    if (!bodyRef.current) return;
    const rb = bodyRef.current as any;

    const paused = gs.ui.paused || gs.ui.dialogueActive;

    // Paused freezes movement but still updates animation with idle
    if (paused) {
      controller.current?.play('idle', 0.2);
      controller.current?.update(dt);
      rb.setLinvel({ x: 0, y: rb.linvel().y, z: 0 }, true);
      return;
    }

    // Move direction
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

    // Position mesh group at rigidbody position
    const pos = rb.translation();
    if (meshGroupRef.current) {
      meshGroupRef.current.position.set(pos.x, pos.y - 1.78, pos.z);
      // When moving, face direction
      if (moving) {
        meshGroupRef.current.rotation.y = facingRef.current;
      }
    }

    // Push player position to camera system
    setPlayerWorldPosition(new THREE.Vector3(pos.x, pos.y + 1.5, pos.z));

    // --- Interaction: press E near gym/practice gym to play basketball ---
    const gyms = ['basketball-gym', 'rec-gym'];
    for (const gid of gyms) {
      const loc = LOCATIONS[gid];
      if (!loc) continue;
      const dx = pos.x - loc.position[0];
      const dz = pos.z - loc.position[2];
      if (Math.hypot(dx, dz) < 3.5) {
        if (input.interact && !gs.ui.basketballMode) {
          useGameStore.getState().enterBasketballMode('free');
        }
        break;
      }
    }

    // Animation
    if (controller.current) {
      const movingFast = Math.hypot(velocity.current.x, velocity.current.z) > 0.4;
      if (movingFast) {
        controller.current.play(input.sprint ? 'run' : 'walk', 0.12);
      } else {
        controller.current.play('idle', 0.2);
      }
      controller.current.update(dt);
    }
  });

  return (
    <group>
      <RigidBody
        ref={bodyRef}
        enabledRotations={[false, false, false]}
        position={[0, 1.78, 32]}
        mass={1}
        friction={0.5}
        restitution={0}
        linearDamping={0.05}
        angularDamping={1}
        gravityScale={GRAVITY_SCALE}
        type="dynamic"
        colliders={false}
        userData={{ tag: 'player' }}
      >
        <CapsuleCollider args={[0.8, 0.35]} position={[0, 0.8, 0]} />
      </RigidBody>
      <group ref={meshGroupRef}>
        <primitive object={mesh} ref={(m: THREE.Mesh) => {
          if (m && !controller.current) {
            controller.current = new AnimationController(m);
            controller.current.play('idle', 0.3);
          }
        }} />
      </group>
    </group>
  );
};

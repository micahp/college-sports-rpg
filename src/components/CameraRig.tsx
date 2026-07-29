/**
 * CameraRig.tsx — cinematic third-person camera with look-ahead, damping,
 * dialogue framing, and collision push.
 */
import React, { useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { useInputStore } from '../store/inputStore';

const DEFAULT_DISTANCE = 5.5;
const DEFAULT_HEIGHT = 2.4;
const DIALOGUE_DISTANCE = 3.2;
const DIALOGUE_HEIGHT = 1.7;
const LOOK_LERP = 3.0;
const POS_LERP = 4.0;

export const CameraRig = () => {
  const { camera, scene } = useThree();
  const playerPos = useRef(new THREE.Vector3(0, 1.8, 40));
  const smoothPos = useRef(new THREE.Vector3(0, 4, 46));
  const smoothLook = useRef(new THREE.Vector3(0, 1.5, 35));
  const lookYaw = useRef(0);
  const lookPitch = useRef(0.1);

  useFrame((_state, delta) => {
    const gs = useGameStore.getState();
    const input = useInputStore.getState();

    // Get player position from a global we set — read via store or DOM
    // For now we track the player through a shared ref updated by Player.
    // We read from the physics body position by reading a module-level variable.
    const pp = getPlayerWorldPosition() ?? playerPos.current;

    playerPos.current.copy(pp);

    // Look input adjusts yaw/pitch when not in dialogue
    if (!gs.ui.dialogueActive) {
      lookYaw.current -= input.lookX * 0.003;
      lookPitch.current = THREE.MathUtils.clamp(
        lookPitch.current + input.lookY * 0.002,
        -0.2,
        0.6
      );
    }

    const isDialogue = gs.ui.dialogueActive;
    const dist = isDialogue ? DIALOGUE_DISTANCE : 5.5;
    const height = isDialogue ? DIALOGUE_HEIGHT : 2.8;

    // Determine camera offset
    const offset = new THREE.Vector3(
      Math.sin(lookYaw.current) * dist,
      height - lookPitch.current * dist * 0.5,
      Math.cos(lookYaw.current) * dist
    );
    const desiredPos = playerPos.current.clone().add(offset);

    // Collision: push camera in if it passes through walls
    const push = checkCameraCollision(playerPos.current, desiredPos, scene);
    if (push) desiredPos.copy(push);

    // Smooth
    const dt = Math.min(delta, 0.05);
    smoothPos.current.lerp(desiredPos, 1 - Math.exp(-POS_LERP * dt));

    // Look target: slightly above player
    const lookTarget = playerPos.current.clone();
    lookTarget.y += 1.5;
    smoothLook.current.lerp(lookTarget, 1 - Math.exp(-LOOK_LERP * dt));

    camera.position.copy(smoothPos.current);
    camera.lookAt(smoothLook.current);
  });

  return null;
};

// ---------------------------------------------------------------------------
// Shared inter-module communication (player position)
// ---------------------------------------------------------------------------
let _playerWorldPos: THREE.Vector3 | null = null;
export function setPlayerWorldPosition(p: THREE.Vector3) {
  _playerWorldPos = p;
}
export function getPlayerWorldPosition(): THREE.Vector3 | null {
  return _playerWorldPos;
}

// ---------------------------------------------------------------------------
// Camera collision — simple sphere-vs-mesh raycast
// ---------------------------------------------------------------------------
function checkCameraCollision(
  from: THREE.Vector3,
  to: THREE.Vector3,
  scene: THREE.Scene
): THREE.Vector3 | null {
  const dir = to.clone().sub(from);
  const dist = dir.length();
  if (dist < 0.001) return null;
  dir.normalize();

  const ray = new THREE.Raycaster(from.clone(), dir, 0, dist + 0.3);
  ray.camera = null as any;

  // Intersect visible meshes (excluding helpers)
  const hits = ray.intersectObjects(scene.children, true);
  for (const hit of hits) {
    // Skip the player itself and very small details
    if (hit.distance < 0.6 && hit.object.userData?.cameraPassable) continue;
    if (hit.distance < 0.3) {
      // Too close — push to slightly outside the hit
      const pushed = from.clone().add(dir.multiplyScalar(Math.max(hit.distance - 0.25, 0.3)));
      pushed.y = to.y;
      return pushed;
    }
  }
  return null;
}

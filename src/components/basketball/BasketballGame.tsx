/**
 * basketball/BasketballGame.tsx — spatial practice-shooting scene.
 * Player moves on the court with WASD, aims toward the hoop, charges and releases.
 * Ball physics with trajectory based on player position. Tracks makes/misses.
 */
import React, { useRef, useState, useMemo, useEffect } from 'react';
import { RigidBody, BallCollider, CuboidCollider, CapsuleCollider } from '@react-three/rapier';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../../store/gameStore';
import { useInputStore } from '../../store/inputStore';
import { Hoop } from './Hoop';
import { BasketballHUD } from './BasketballHUD';
import { playScore, playMiss, playBounce } from '../../systems/audioSystem';

const HOOP_POS: [number, number, number] = [0, 0, -6.7];
const RIM_Y = 3.05;
const RIM_RADIUS = 0.225;
const COURT_HALF_W = 7.5;
const COURT_HALF_D = 7;

export const BasketballGame = () => {
  return (
    <group>
      <ambientLight intensity={0.4} />
      <directionalLight position={[5, 10, 5]} intensity={1.3} castShadow shadow-mapSize={[1024, 1024]} />
      <pointLight position={[0, 6, -3]} intensity={0.7} color="#ffe0a0" />

      <Floor />
      <Walls />
      <Hoop position={HOOP_POS} />

      {/* Backboard collider */}
      <RigidBody type="fixed" position={[0, RIM_Y + 0.35, HOOP_POS[2] - 0.1]}>
        <CuboidCollider args={[0.9, 0.525, 0.025]} />
      </RigidBody>
      {/* Rim colliders */}
      <RigidBody type="fixed" position={[RIM_RADIUS, RIM_Y, HOOP_POS[2]]}>
        <BallCollider args={[0.04]} restitution={0.4} />
      </RigidBody>
      <RigidBody type="fixed" position={[-RIM_RADIUS, RIM_Y, HOOP_POS[2]]}>
        <BallCollider args={[0.04]} restitution={0.4} />
      </RigidBody>

      <PlayerOnCourt />
      <BasketballHUD />
    </group>
  );
};

// ---------------------------------------------------------------------------
// Floor
// ---------------------------------------------------------------------------
function Floor() {
  return (
    <RigidBody type="fixed" position={[0, -0.05, -2]}>
      <CuboidCollider args={[12, 0.05, 12]} />
      <mesh receiveShadow position={[0, 0, -2]}>
        <boxGeometry args={[24, 0.1, 24]} />
        <meshStandardMaterial color="#c8a060" roughness={0.6} metalness={0.1} />
      </mesh>
      <mesh position={[0, 0.06, -2]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[1.8, 1.85, 32]} />
        <meshStandardMaterial color="#a07838" />
      </mesh>
      <mesh position={[0, 0.06, 0.91]} rotation={[-Math.PI / 2, 0, 0]}>
        <planeGeometry args={[0.05, 1]} />
        <meshStandardMaterial color="#0a1628" />
      </mesh>
    </RigidBody>
  );
}

// ---------------------------------------------------------------------------
// Walls
// ---------------------------------------------------------------------------
function Walls() {
  return (
    <>
      <RigidBody type="fixed" position={[0, 2, -10]} userData={{ cameraPassable: true }}>
        <CuboidCollider args={[12, 3, 0.2]} />
        <mesh position={[0, 0, 0]}><boxGeometry args={[24, 6, 0.2]} /><meshStandardMaterial color="#1a2030" transparent opacity={0.6} /></mesh>
      </RigidBody>
      <RigidBody type="fixed" position={[-8, 2, -2]} userData={{ cameraPassable: true }}>
        <CuboidCollider args={[0.2, 3, 12]} />
      </RigidBody>
      <RigidBody type="fixed" position={[8, 2, -2]} userData={{ cameraPassable: true }}>
        <CuboidCollider args={[0.2, 3, 12]} />
      </RigidBody>
    </>
  );
}

// ---------------------------------------------------------------------------
// Player on court — moves with WASD, shoots toward hoop
// ---------------------------------------------------------------------------
function PlayerOnCourt() {
  const bodyRef = useRef<any>(null);
  const ballRef = useRef<any>(null);
  const [power, setPower] = useState(0);
  const [charging, setCharging] = useState(false);
  const [message, setMessage] = useState('');
  const chargeStart = useRef(0);
  const inFlight = useRef(false);
  const shotHandled = useRef(false);
  const scoreNotified = useRef(false);
  const playerFacing = useRef(0);

  const ballGeo = useMemo(() => new THREE.SphereGeometry(0.12, 16, 16), []);
  const ballMat = useMemo(() => new THREE.MeshStandardMaterial({ color: '#d4762a', roughness: 0.65 }), []);

  const release = () => {
    setCharging(false);
    const gs = useGameStore.getState();
    const elapsed = Math.min(1.6, (performance.now() - chargeStart.current) / 1000);
    const pct = 35 + Math.min(100, (elapsed / 1.6) * 100) * 0.65;
    const athleticBonus = (gs.stats.athletic ?? 50) / 100;
    const confidenceBonus = (gs.stats.confidence ?? 50) / 200;
    const accuracy = 0.65 + athleticBonus * 0.25 + confidenceBonus;

    if (!ballRef.current || !bodyRef.current) return;

    const playerPos = bodyRef.current.translation();
    // Direction from ball to hoop
    const toHoop = new THREE.Vector3(
      HOOP_POS[0] - playerPos.x,
      RIM_Y + 0.5 - 1.2,
      HOOP_POS[2] - playerPos.z
    );
    const dist = toHoop.length();
    toHoop.normalize();

    // Power scale based on charge and distance
    const powerScale = pct / 60;
    const noise = (1 - accuracy) * 0.3;

    const shootDir = toHoop.clone();
    shootDir.x += (Math.random() - 0.5) * noise;
    shootDir.z += (Math.random() - 0.5) * noise;
    shootDir.multiplyScalar(powerScale * (4 + dist * 0.35));
    shootDir.y = 3.5 + dist * 0.25 + (Math.random() - 0.5) * (1 - accuracy);

    ballRef.current.setLinvel({ x: shootDir.x, y: shootDir.y, z: shootDir.z }, true);
    ballRef.current.setAngvel({ x: 0, y: 0, z: -8 }, true);
    inFlight.current = true;
    shotHandled.current = false;
    scoreNotified.current = false;
    gs.resetBasketball();
  };

  // Charge + release input
  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if ((e.target as HTMLElement)?.closest('[data-ui]')) return;
      if (e.button !== 0) return;
      if (inFlight.current) return;
      setCharging(true);
      chargeStart.current = performance.now();
    };
    const onUp = (e: MouseEvent) => {
      if (e.button === 0 && charging && !inFlight.current) release();
    };
    const onTouchStart = (e: TouchEvent) => {
      if (inFlight.current) return;
      setCharging(true);
      chargeStart.current = performance.now();
    };
    const onTouchEnd = () => {
      if (charging && !inFlight.current) release();
    };
    window.addEventListener('mousedown', onDown);
    window.addEventListener('mouseup', onUp);
    window.addEventListener('touchstart', onTouchStart);
    window.addEventListener('touchend', onTouchEnd);
    return () => {
      window.removeEventListener('mousedown', onDown);
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('touchstart', onTouchStart);
      window.removeEventListener('touchend', onTouchEnd);
    };
  }, [charging]);

  useFrame((_state, delta) => {
    const input = useInputStore.getState();
    const dt = Math.min(delta, 0.05);
    const rb = bodyRef.current;

    if (rb) {
      // Player movement on court
      const speed = 5.0;
      const moveX = input.moveX;
      const moveZ = input.moveY;
      const moving = Math.hypot(moveX, moveZ) > 0.1;

      if (moving && !inFlight.current) {
        const len = Math.hypot(moveX, moveZ);
        const nx = moveX / len;
        const nz = moveZ / len;
        rb.setLinvel({ x: nx * speed, y: rb.linvel().y, z: nz * speed }, true);
        playerFacing.current = Math.atan2(nx, nz);
      } else if (!inFlight.current) {
        rb.setLinvel({ x: 0, y: rb.linvel().y, z: 0 }, true);
      }

      // Clamp to court bounds
      const p = rb.translation();
      const cx = THREE.MathUtils.clamp(p.x, -COURT_HALF_W, COURT_HALF_W);
      const cz = THREE.MathUtils.clamp(p.z, -COURT_HALF_D, COURT_HALF_D);
      if (cx !== p.x || cz !== p.z) {
        rb.setTranslation({ x: cx, y: p.y, z: cz }, true);
      }

      // Ball follows player when not in flight
      if (!inFlight.current && ballRef.current) {
        const bx = p.x + Math.sin(playerFacing.current) * 0.6;
        const bz = p.z + Math.cos(playerFacing.current) * 0.6;
        ballRef.current.setTranslation({ x: bx, y: 1.2, z: bz }, true);
        ballRef.current.setLinvel({ x: 0, y: 0, z: 0 }, true);
      }
    }

    // Power meter while charging
    if (charging && !inFlight.current) {
      const elapsed = Math.min(1.6, (performance.now() - chargeStart.current) / 1000);
      setPower((elapsed / 1.6) * 100);
    } else if (!charging && power !== 0) {
      setPower(0);
    }

    // Detect score: ball drops through rim zone with downward velocity
    if (inFlight.current && ballRef.current) {
      const ballRb = ballRef.current;
      const pos = ballRb.translation();
      const vel = ballRb.linvel();

      // Bounce sound
      if (Math.abs(pos.y - 0.2) < 0.15 && vel.y < -1 && !shotHandled.current) {
        playBounce();
      }

      const inRimZone =
        pos.y < RIM_Y + 0.15 &&
        pos.y > RIM_Y - 0.2 &&
        Math.abs(pos.x) < RIM_RADIUS + 0.05 &&
        pos.z < HOOP_POS[2] + 0.1 &&
        pos.z > HOOP_POS[2] - 0.15;

      if (!scoreNotified.current && inRimZone && vel.y < -0.3) {
        scoreNotified.current = true;
        useGameStore.getState().onScore();
        playScore();
        setMessage('SWISH!');
        setTimeout(() => setMessage(''), 1000);
      }

      const speed = Math.hypot(vel.x, vel.y, vel.z);
      if (!shotHandled.current && (pos.y < 0.15 || speed < 0.08)) {
        shotHandled.current = true;
        if (!scoreNotified.current) {
          playMiss();
          setMessage('MISS');
          setTimeout(() => setMessage(''), 800);
        }
        setTimeout(() => {
          inFlight.current = false;
        }, 600);
      }
    }
  });

  return (
    <group>
      {/* Player body (capsule) */}
      <RigidBody
        ref={bodyRef}
        position={[0, 0.9, 4]}
        enabledRotations={[false, false, false]}
        mass={1}
        friction={0.3}
        linearDamping={4}
        type="dynamic"
        colliders={false}
      >
        <CapsuleCollider args={[0.5, 0.3]} position={[0, 0.5, 0]} />
        {/* Visual capsule */}
        <mesh position={[0, 0.8, 0]} castShadow>
          <capsuleGeometry args={[0.3, 0.9, 4, 12]} />
          <meshStandardMaterial color="#1a4a8a" roughness={0.6} />
        </mesh>
        {/* Head */}
        <mesh position={[0, 1.55, 0]} castShadow>
          <sphereGeometry args={[0.22, 12, 12]} />
          <meshStandardMaterial color="#c8a070" roughness={0.7} />
        </mesh>
      </RigidBody>

      {/* Ball */}
      <RigidBody
        ref={ballRef}
        position={[0, 1.2, 4.6]}
        restitution={0.6}
        friction={0.45}
        density={0.5}
        linearDamping={0.15}
        angularDamping={0.3}
        colliders={false}
        type="dynamic"
      >
        <BallCollider args={[0.12]} />
        <mesh geometry={ballGeo} material={ballMat} castShadow>
          <mesh geometry={ballGeo} scale={[1.02, 1.02, 0.3]} material={new THREE.MeshStandardMaterial({ color: '#3a1e0a', roughness: 0.8 })} />
        </mesh>
      </RigidBody>

      <BallStateBridge power={power} message={message} />
    </group>
  );
}

// Bridge power + message into a ref the HUD can read
let _ballState = { power: 0, message: '' };
function BallStateBridge({ power, message }: { power: number; message: string }) {
  React.useEffect(() => { _ballState = { power, message }; }, [power, message]);
  return null;
}
export function getBallState() { return _ballState; }

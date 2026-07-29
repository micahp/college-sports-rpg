/**
 * basketball/BasketballGame.tsx — complete practice-shooting scene.
 * A self-contained mini-game: a court, a hoop at -Z, and a charge-and-release
 * shooting mechanic. Hold mouse/touch to charge, release to fire. Physics-based
 * ball flight with accuracy derived from player stats. Tracks makes/misses.
 */
import React, { useRef, useState, useMemo } from 'react';
import { RigidBody, BallCollider, CuboidCollider } from '@react-three/rapier';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { useGameStore } from '../../store/gameStore';
import { Hoop } from './Hoop';
import { BasketballHUD } from './BasketballHUD';
import { playScore, playMiss } from '../../systems/audioSystem';

const HOOP_POS: [number, number, number] = [0, 0, -6.7];
const BALL_START: [number, number, number] = [0, 1.2, 3];
const RIM_Y = 3.05;
const RIM_RADIUS = 0.225;

export const BasketballGame = () => {
  return (
    <group>
      {/* Low ambient + warm gym lights */}
      <ambientLight intensity={0.35} />
      <directionalLight position={[5, 8, 5]} intensity={1.2} castShadow shadow-mapSize={[1024, 1024]} />
      <pointLight position={[0, 6, -3]} intensity={0.6} color="#ffe0a0" />

      {/* Floor */}
      <Floor />
      {/* Walls (keep ball in play) */}
      <Walls />
      {/* Hoop */}
      <Hoop position={HOOP_POS} />

      {/* Ball + shooting logic */}
      <ShootingRig />

      {/* Backboard collider */}
      <RigidBody type="fixed" position={[0, RIM_Y + 0.35, HOOP_POS[2] - 0.1]}>
        <CuboidCollider args={[0.9, 0.525, 0.025]} />
      </RigidBody>
      {/* Rim colliders (two small spheres at rim edges to deflect ball) */}
      <RigidBody type="fixed" position={[RIM_RADIUS, RIM_Y, HOOP_POS[2]]}>
        <BallCollider args={[0.04]} restitution={0.4} />
      </RigidBody>
      <RigidBody type="fixed" position={[-RIM_RADIUS, RIM_Y, HOOP_POS[2]]}>
        <BallCollider args={[0.04]} restitution={0.4} />
      </RigidBody>

      {/* Camera rig + HUD */}
      <CameraRig />
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
      {/* Court lines */}
      <mesh position={[0, 0.06, -2]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[1.8, 1.85, 32]} />
        <meshStandardMaterial color="#a07838" />
      </mesh>
      {/* Free throw line */}
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
// Ball + Shooting
// ---------------------------------------------------------------------------
function ShootingRig() {
  const ballRef = useRef<any>(null);
  const [power, setPower] = useState(0);
  const [charging, setCharging] = useState(false);
  const [message, setMessage] = useState('');
  const chargeStart = useRef(0);
  const inFlight = useRef(false);
  const shotHandled = useRef(false);
  const scoreNotified = useRef(false);

  const ballGeo = useMemo(() => new THREE.SphereGeometry(0.12, 16, 16), []);
  const ballMat = useMemo(() => new THREE.MeshStandardMaterial({ color: '#d4762a', roughness: 0.65 }), []);

  // Charge + release
  React.useEffect(() => {
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

  const release = () => {
    setCharging(false);
    const gs = useGameStore.getState();
    const elapsed = Math.min(1.6, (performance.now() - chargeStart.current) / 1000);
    const pct = 35 + Math.min(100, (elapsed / 1.6) * 100) * 0.65;
    const athleticBonus = (gs.stats.athletic ?? 50) / 100;
    const confidenceBonus = (gs.stats.confidence ?? 50) / 200;
    const accuracy = 0.65 + athleticBonus * 0.25 + confidenceBonus;

    // Velocity toward hoop at z = -6.7 from z = 3
    const shootDir = new THREE.Vector3(0, 0, -1);
    const noise = (1 - accuracy) * 0.4;
    shootDir.x += (Math.random() - 0.5) * noise;
    const powerScale = pct / 60;
    shootDir.multiplyScalar(powerScale * 6);
    shootDir.y = 4.2 + (Math.random() - 0.5) * (1 - accuracy);

    if (ballRef.current) {
      ballRef.current.setLinvel({ x: shootDir.x, y: shootDir.y, z: shootDir.z }, true);
      ballRef.current.setAngvel({ x: 0, y: 0, z: 0 }, true);
    }
    inFlight.current = true;
    shotHandled.current = false;
    scoreNotified.current = false;
    gs.resetBasketball();
  };

  useFrame(() => {
    // Power meter while charging
    if (charging && !inFlight.current) {
      const elapsed = Math.min(1.6, (performance.now() - chargeStart.current) / 1000);
      setPower((elapsed / 1.6) * 100);
    } else if (!charging && power !== 0) {
      setPower(0);
    }

    // Detect score: ball drops through rim zone with downward velocity
    if (inFlight.current && ballRef.current) {
      const rb = ballRef.current;
      const pos = rb.translation();
      const vel = rb.linvel();

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

      // When ball stops or hits floor, end the shot
      const speed = Math.hypot(vel.x, vel.y, vel.z);
      if (!shotHandled.current && (pos.y < 0.2 || speed < 0.08)) {
        shotHandled.current = true;
        if (!scoreNotified.current) {
          playMiss();
          setMessage('MISS');
          setTimeout(() => setMessage(''), 800);
        }
        // After a beat, reset ball to shooting spot
        setTimeout(() => {
          if (ballRef.current) {
            ballRef.current.setTranslation({ x: BALL_START[0], y: BALL_START[1], z: BALL_START[2] }, true);
            ballRef.current.setLinvel({ x: 0, y: 0, z: 0 }, true);
            ballRef.current.setAngvel({ x: 0, y: 0, z: 0 }, true);
          }
          inFlight.current = false;
        }, 700);
      }
    }
  });

  return (
    <group>
      <RigidBody
        ref={ballRef}
        position={BALL_START}
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
          {/* seam */}
          <mesh geometry={ballGeo} scale={[1.02, 1.02, 0.3]} material={new THREE.MeshStandardMaterial({ color: '#3a1e0a', roughness: 0.8 })} />
        </mesh>
      </RigidBody>
      {/* Render power meter via event bus not used; HUD reads store */}
      <BallStateBridge power={power} message={message} />
    </group>
  );
}

// Bridge power + message into a zustand-ish ref the HUD can read
let _ballState = { power: 0, message: '' };
function BallStateBridge({ power, message }: { power: number; message: string }) {
  React.useEffect(() => { _ballState = { power, message }; }, [power, message]);
  return null;
}
export function getBallState() { return _ballState; }

// ---------------------------------------------------------------------------
// During-play camera
// ---------------------------------------------------------------------------
function CameraRig() {
  const { camera } = useThree();
  useFrame(() => {
    const target = new THREE.Vector3(4, 3.2, 5);
    camera.position.lerp(target, 0.08);
    camera.lookAt(new THREE.Vector3(0, 2.2, -3));
  });
  return null;
}

/**
 * Game.tsx — top-level phase router + Canvas.
 * Handles lifecycle: input manager attach, narrative tick, UI overlay per phase.
 */
import React, { useEffect, Suspense, lazy } from 'react';
import { Canvas } from '@react-three/fiber';
import { Physics, RigidBody, CuboidCollider } from '@react-three/rapier';
import { AdaptiveDpr, AdaptiveEvents, Preload } from '@react-three/drei';
import { World } from './components/World';
import { Player } from './components/Player';
import { CameraRig } from './components/CameraRig';
import { Lighting } from './components/Lighting';
import { PostFX } from './components/PostFX';
import { HUD } from './ui/HUD';
import { DialogueOverlay } from './ui/DialogueOverlay';
import { MainMenu } from './ui/MainMenu';
import { LoadingScreen } from './ui/LoadingScreen';
import { MobileControls } from './ui/MobileControls';
import { useGameStore } from './store/gameStore';
import { attachInputManager } from './systems/inputManager';
import { useNarrativeTick } from './systems/narrativeTick';
import { useAmbientAudio } from './systems/audioSystem';

const BasketballGame = lazy(() => import('./components/basketball/BasketballGame').then(m => ({ default: m.BasketballGame })));
const CharacterCreator = lazy(() => import('./ui/CharacterCreator').then(m => ({ default: m.CharacterCreator })));
const Phone = lazy(() => import('./ui/Phone').then(m => ({ default: m.Phone })));

export function Game() {
  const phase = useGameStore((s) => s.phase);

  useEffect(() => {
    const cleanup = attachInputManager();
    return cleanup;
  }, []);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      {phase === 'menu' && <MainMenu />}
      {phase === 'creator' && <Suspense fallback={<LoadingScreen />}><CharacterCreator /></Suspense>}
      {phase === 'loading' && <LoadingScreen />}
      {phase === 'playing' && <GameCanvas />}
    </div>
  );
}

function GameCanvas() {
  const basketballMode = useGameStore((s) => s.ui.basketballMode);
  useAmbientAudio();

  return (
    <>
      <Canvas
        shadows
        dpr={[1, 1.75]}
        gl={{
          antialias: true,
          alpha: false,
          powerPreference: 'high-performance',
          stencil: false,
        }}
        camera={{ fov: 50, near: 0.1, far: 500, position: [0, 5, 10] }}
      >
        <color attach="background" args={['#0a0e1a']} />
        <fog attach="fog" args={['#0a0e1a', 80, 300]} />
        {basketballMode ? (
          <Suspense fallback={null}><BasketballGame /></Suspense>
        ) : (
          <>
            <Lighting />
            <Physics gravity={[0, -9.81, 0]} timeStep="vary">
              {/* Ground plane collider so the player doesn't fall through the world */}
              <RigidBody type="fixed" colliders={false}>
                <CuboidCollider args={[100, 0.1, 100]} position={[0, -0.1, 10]} />
              </RigidBody>
              <World />
              <Player />
            </Physics>
            <CameraRig />
            <PostFX />
          </>
        )}
        <AdaptiveDpr pixelated />
        <AdaptiveEvents />
        <Preload all />
      </Canvas>
      <HUD />
      <Suspense fallback={null}><Phone /></Suspense>
      <DialogueOverlay />
      <MobileControls />
    </>
  );
}

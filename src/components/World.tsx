/**
 * World.tsx — root scene composition.
 * Instantiates the campus, lighting, sky, and NPC manager.
 * Player is mounted separately in Game.tsx (needs physics + input).
 */
import React, { Suspense } from 'react';
import { Campus } from './world/Campus';
import { Buildings } from './world/Buildings';
import { Props } from './world/Props';
import { Sky } from './world/Sky';
import { Lighting } from './Lighting';
import { NpcManager } from './NpcManager';
import { useTimeSystem } from '../systems/timeSystem';

export const World = () => {
  useTimeSystem(1.5);
  return (
    <group>
      <Suspense fallback={null}>
        <Sky />
        <Lighting />
        <Campus />
        <Buildings />
        <Props />
        <NpcManager />
      </Suspense>
    </group>
  );
};

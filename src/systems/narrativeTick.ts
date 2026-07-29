/**
 * systems/narrativeTick.ts — React hook that drives the narrative engine inside Canvas.
 * Each frame, calls tickNarrative() which evaluates unmet story beats and fires them.
 */
import { useFrame } from '@react-three/fiber';
import { tickNarrative } from './narrativeEngine';

export function useNarrativeTick() {
  useFrame(() => {
    tickNarrative();
  });
}

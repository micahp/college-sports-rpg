/**
 * PostFX.tsx — postprocessing stack: subtle bloom, vignette, SMAA.
 */
import React from 'react';
import { EffectComposer, Bloom, Vignette, SMAA } from '@react-three/postprocessing';

export const PostFX = () => {
  return (
    <EffectComposer>
      <Bloom
        intensity={0.35}
        luminanceThreshold={0.7}
        luminanceSmoothing={0.2}
        mipmapBlur={true}
      />
      <Vignette eskil={false} offset={0.2} darkness={0.7} />
      <SMAA />
    </EffectComposer>
  );
};

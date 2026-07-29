/**
 * animationController.ts — procedural animation for the humanoid skeleton.
 *
 * Builds THREE.AnimationClip objects from hand-authored keyframed bone rotations
 * (no external files). Each AnimationClip targets bone names with VectorKeyframeTrack
 * (position) and QuaternionKeyframeTrack (rotation). The controller owns an
 * AnimationMixer and blends between clips with crossfade.
 */
import * as THREE from 'three';

export type AnimName =
  | 'idle'
  | 'walk'
  | 'run'
  | 'talk'
  | 'sit'
  | 'celebrate'
  | 'disappointed'
  | 'wave'
  | 'cheer'
  | 'point';

interface ClipSpec {
  name: AnimName;
  duration: number;
  loop: number;
  tracks: Array<{
    bone: string;
    type: 'pos' | 'rot';
    times: number[];
    values: number[]; // vec3 (x,y,z) or quat (x,y,z,w)
  }>;
}

// ---------------------------------------------------------------------------
// Keyframe clip generator
// ---------------------------------------------------------------------------

function buildClips(): ClipSpec[] {
  const T = Math.PI;

  return [
    // ----- idle: subtle weight shift + breathing -----
    {
      name: 'idle',
      duration: 4,
      loop: THREE.LoopRepeat,
      tracks: [
        // chest breathing
        {
          bone: 'chest',
          type: 'pos',
          times: [0, 2, 4],
          values: [0, 0.18, 0, 0, 0.19, 0, 0, 0.18, 0],
        },
        // arms slight sway
        {
 bone: 'upperArm.L', type: 'rot', times: [0, 2, 4],
          values: [0,0,0,1, 0.05,0,0,0.998, 0,0,0,1],
        },
        {
          bone: 'upperArm.R', type: 'rot', times: [0, 2, 4],
          values: [0,0,0,1, -0.05,0,0,0.998, 0,0,0,1],
        },
        // head subtle look
        { bone: 'head', type: 'rot', times: [0, 2, 4], values: [0,0,0,1, 0.08,0,0,0.996, 0,0,0,1] },
      ],
    },

    // ----- walk -----
    {
      name: 'walk',
      duration: 1.0,
      loop: THREE.LoopRepeat,
      tracks: [
        // hips bob
        {
          bone: 'hips', type: 'pos',
          times: [0, 0.25, 0.5, 0.75, 1],
          values: [0,0.95,0, 0,0.97,0, 0,0.93,0, 0,0.97,0, 0,0.95,0],
        },
        // left leg forward/back
        {
          bone: 'upLeg.L', type: 'rot',
          times: [0, 0.25, 0.5, 0.75, 1],
          values: eulerToQuat(0.6, 0, 0).concat(eulerToQuat(-0.5, 0, 0)).concat(eulerToQuat(0.6, 0, 0)),
        },
        // right leg opposite
        {
          bone: 'upLeg.R', type: 'rot',
          times: [0, 0.25, 0.5, 0.75, 1],
          values: eulerToQuat(-0.5, 0, 0).concat(eulerToQuat(0.6, 0, 0)).concat(eulerToQuat(-0.5, 0, 0)),
        },
        // arms opposite swing
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 0.5, 1],
          values: eulerToQuat(-0.4, 0, 0).concat(eulerToQuat(0.4, 0, 0)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 0.5, 1],
          values: eulerToQuat(0.4, 0, 0).concat(eulerToQuat(-0.4, 0, 0)),
        },
        // counter-rotation lower arms
        {
          bone: 'lowerArm.L', type: 'rot',
          times: [0, 0.5, 1],
          values: eulerToQuat(-0.3, 0, 0).concat(eulerToQuat(-0.4, 0, 0)),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 0.5, 1],
          values: eulerToQuat(-0.4, 0, 0).concat(eulerToQuat(-0.3, 0, 0)),
        },
      ],
    },

    // ----- run -----
    {
      name: 'run',
      duration: 0.6,
      loop: THREE.LoopRepeat,
      tracks: [
        // hips bigger bob + forward lean via spine
        {
          bone: 'hips', type: 'pos',
          times: [0, 0.15, 0.3, 0.45, 0.6],
          values: [0,0.95,0, 0,1.0,0, 0,0.9,0, 0,1.0,0, 0,0.95,0],
        },
        { bone: 'spine', type: 'rot', times: [0, 0.6], values: eulerToQuat(0.25, 0, 0) },
        {
          bone: 'upLeg.L', type: 'rot',
          times: [0, 0.15, 0.3, 0.45, 0.6],
          values: eulerToQuat(0.9, 0, 0)
            .concat(eulerToQuat(-0.7, 0, 0))
            .concat(eulerToQuat(0.9, 0, 0)),
        },
        {
          bone: 'upLeg.R', type: 'rot',
          times: [0, 0.15, 0.3, 0.45, 0.6],
          values: eulerToQuat(-0.7, 0, 0)
            .concat(eulerToQuat(0.9, 0, 0))
            .concat(eulerToQuat(-0.7, 0, 0)),
        },
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 0.3, 0.6],
          values: eulerToQuat(-0.8, 0, 0).concat(eulerToQuat(0.8, 0, 0)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 0.3, 0.6],
          values: eulerToQuat(0.8, 0, 0).concat(eulerToQuat(-0.8, 0, 0)),
        },
        {
          bone: 'lowerArm.L', type: 'rot',
          times: [0, 0.6],
          values: eulerToQuat(-0.6, 0, 0),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 0.6],
          values: eulerToQuat(-0.6, 0, 0),
        },
      ],
    },

    // ----- talk: head nods + one hand gesture -----
    {
      name: 'talk',
      duration: 2.5,
      loop: THREE.LoopRepeat,
      tracks: [
        {
          bone: 'head', type: 'rot',
          times: [0, 0.6, 1.2, 1.8, 2.5],
          values: eulerToQuat(0, 0, 0)
            .concat(eulerToQuat(0.05, 0.1, 0))
            .concat(eulerToQuat(0, -0.05, 0))
            .concat(eulerToQuat(-0.03, 0.05, 0))
            .concat(eulerToQuat(0, 0, 0)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 1.0, 2.0, 2.5],
          values: eulerToQuat(-0.2, 0, 0.3)
            .concat(eulerToQuat(-0.6, 0, 0.6))
            .concat(eulerToQuat(-0.2, 0, 0.3))
            .concat(eulerToQuat(-0.2, 0, 0.3)),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 1.0, 2.0, 2.5],
          values: eulerToQuat(-0.3, 0, 0)
            .concat(eulerToQuat(-0.7, 0, 0))
            .concat(eulerToQuat(-0.3, 0, 0))
            .concat(eulerToQuat(-0.3, 0, 0)),
        },
      ],
    },

    // ----- sit: legs bent back, arms on lap -----
    {
      name: 'sit',
      duration: 1,
      loop: THREE.LoopOnce,
      tracks: [
        {
          bone: 'hips', type: 'pos',
          times: [0, 1],
          values: [0, 0.95, 0, 0, 0.5, 0],
        },
        {
          bone: 'upLeg.L', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(-1.5, 0, 0)),
        },
        {
          bone: 'upLeg.R', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(-1.5, 0, 0)),
        },
        {
          bone: 'lowerLeg.L', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(1.8, 0, 0)),
        },
        {
          bone: 'lowerLeg.R', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(1.8, 0, 0)),
        },
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(-0.4, 0, 0.4)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0, 0, 0).concat(eulerToQuat(-0.4, 0, -0.4)),
        },
      ],
    },

    // ----- celebrate: arms up, slight hop -----
    {
      name: 'celebrate',
      duration: 0.8,
      loop: THREE.LoopRepeat,
      tracks: [
        {
          bone: 'hips', type: 'pos',
          times: [0, 0.2, 0.4, 0.6, 0.8],
          values: [0,0.95,0, 0,1.05,0, 0,0.95,0, 0,1.02,0, 0,0.95,0],
        },
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 0.4, 0.8],
          values: eulerToQuat(0,0,2.5).concat(eulerToQuat(0,0,2.7)).concat(eulerToQuat(0,0,2.5)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 0.4, 0.8],
          values: eulerToQuat(0,0,-2.5).concat(eulerToQuat(0,0,-2.7)).concat(eulerToQuat(0,0,-2.5)),
        },
        {
          bone: 'lowerArm.L', type: 'rot',
          times: [0, 0.8],
          values: eulerToQuat(0,0,-0.5),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 0.8],
          values: eulerToQuat(0,0,0.5),
        },
      ],
    },

    // ----- disappointed: shoulders drop, head down -----
    {
      name: 'disappointed',
      duration: 1.5,
      loop: THREE.LoopOnce,
      tracks: [
        {
          bone: 'spine', type: 'rot',
          times: [0, 1.5],
          values: eulerToQuat(0,0,0).concat(eulerToQuat(0.2,0,0)),
        },
        {
          bone: 'head', type: 'rot',
          times: [0, 1.5],
          values: eulerToQuat(0,0,0).concat(eulerToQuat(0.3,0,0)),
        },
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 1.5],
          values: eulerToQuat(0,0,0).concat(eulerToQuat(0.1,0,0.3)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 1.5],
          values: eulerToQuat(0,0,0).concat(eulerToQuat(0.1,0,-0.3)),
        },
      ],
    },

    // ----- wave -----
    {
      name: 'wave',
      duration: 1.2,
      loop: THREE.LoopRepeat,
      tracks: [
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 1.2],
          values: eulerToQuat(0,0,-2.2),
        },
        {
          bone: 'hand.R', type: 'rot',
          times: [0, 0.3, 0.6, 0.9, 1.2],
          values: eulerToQuat(0,0,0)
            .concat(eulerToQuat(0.5,0,0))
            .concat(eulerToQuat(-0.5,0,0))
            .concat(eulerToQuat(0.5,0,0))
            .concat(eulerToQuat(0,0,0)),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 1.2],
          values: eulerToQuat(0,0,0.4),
        },
      ],
    },

    // ----- cheer: both arms up quick -----
    {
      name: 'cheer',
      duration: 0.6,
      loop: THREE.LoopRepeat,
      tracks: [
        {
          bone: 'upperArm.L', type: 'rot',
          times: [0, 0.3, 0.6],
          values: eulerToQuat(0,0,2.3).concat(eulerToQuat(0,0,2.5)).concat(eulerToQuat(0,0,2.3)),
        },
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 0.3, 0.6],
          values: eulerToQuat(0,0,-2.3).concat(eulerToQuat(0,0,-2.5)).concat(eulerToQuat(0,0,-2.3)),
        },
        {
          bone: 'hips', type: 'pos',
          times: [0, 0.3, 0.6],
          values: [0,0.95,0, 0,1.02,0, 0,0.95,0],
        },
      ],
    },

    // ----- point: right arm extend -----
    {
      name: 'point',
      duration: 1,
      loop: THREE.LoopOnce,
      tracks: [
        {
          bone: 'upperArm.R', type: 'rot',
          times: [0, 0.5, 1],
          values: eulerToQuat(0,0,-0.3).concat(eulerToQuat(-1.3,0,-0.2)).concat(eulerToQuat(-1.3,0,-0.2)),
        },
        {
          bone: 'lowerArm.R', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0,0,0),
        },
        {
          bone: 'hand.R', type: 'rot',
          times: [0, 1],
          values: eulerToQuat(0,0,0),
        },
      ],
    },
  ];
}

// helper: euler XYZ (radians) → quaternion (x,y,z,w)
function eulerToQuat(x: number, y: number, z: number): number[] {
  const q = new THREE.Quaternion();
  q.setFromEuler(new THREE.Euler(x, y, z, 'XYZ'));
  return [q.x, q.y, q.z, q.w];
}

// ---------------------------------------------------------------------------
// Controller class
// ---------------------------------------------------------------------------

export class AnimationController {
  readonly mixer: THREE.AnimationMixer;
  private clips: Record<string, THREE.AnimationClip> = {};
  private clipLoops: Record<string, number> = {};
  private currentAction: THREE.AnimationAction | null = null;
  private currentName: string = '';

  constructor(root: THREE.Object3D) {
    this.mixer = new THREE.AnimationMixer(root);
    for (const spec of buildClips()) {
      const tracks: THREE.KeyframeTrack[] = [];
      for (const trk of spec.tracks) {
        const name = `${trk.bone}.${trk.type === 'pos' ? 'position' : 'quaternion'}`;
        if (trk.type === 'pos') {
          tracks.push(
            new THREE.VectorKeyframeTrack(name, trk.times, trk.values)
          );
        } else {
          tracks.push(
            new THREE.QuaternionKeyframeTrack(name, trk.times, trk.values)
          );
        }
      }
      const clip = new THREE.AnimationClip(spec.name, spec.duration, tracks);
      this.clips[spec.name] = clip;
      this.clipLoops[spec.name] = spec.loop;
    }
  }

  play(name: AnimName, fade: number = 0.25): THREE.AnimationAction {
    const clip = this.clips[name];
    if (!clip) {
      console.warn(`Animation ${name} not found`);
      return this.currentAction!;
    }
    if (this.currentName === name && this.currentAction?.isRunning()) {
      return this.currentAction;
    }
    const action = this.mixer.clipAction(clip);
    action.reset();
    action.setLoop((this.clipLoops[name] ?? THREE.LoopRepeat) as THREE.LoopModes, Infinity);
    action.setEffectiveTimeScale(1);
    action.setEffectiveWeight(1);
    if (this.currentAction && fade > 0) {
      this.currentAction.crossFadeTo(action, fade, false);
    } else {
      this.currentAction?.stop();
    }
    action.play();
    this.currentAction = action;
    this.currentName = name;
    return action;
  }

  setTimeScale(s: number) {
    if (this.currentAction) this.currentAction.setEffectiveTimeScale(s);
  }

  update(delta: number) {
    this.mixer.update(delta);
  }

  get current() {
    return this.currentName;
  }
}

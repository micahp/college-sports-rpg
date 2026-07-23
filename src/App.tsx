import { useEffect } from 'react';
import { Canvas } from '@react-three/fiber';
import { KeyboardControls } from '@react-three/drei';
import { Campus } from './game/Campus';
import { Player, useKeyboardMovement } from './game/Player';
import { Npcs } from './game/Npcs';
import { Students } from './game/Students';
import { useGame, PERIODS } from './game/store';
import { useProx } from './game/prox';
import { day1 } from './game/content';
import { initAudio, startAmbient, stopAmbient } from './game/audio';
import { styles } from './ui/styles';
import {
  Hud,
  InteractionPrompt,
  DialoguePanel,
  BeatCard,
  ReactionCard,
  TitleScreen,
  CreateScreen,
  RecapScreen,
  Joystick,
} from './ui/Ui';
import { TryoutScreen } from './ui/Tryout';

const KEY_MAP = [
  { name: 'forward', keys: ['KeyW', 'ArrowUp'] },
  { name: 'back', keys: ['KeyS', 'ArrowDown'] },
  { name: 'left', keys: ['KeyA', 'ArrowLeft'] },
  { name: 'right', keys: ['KeyD', 'ArrowRight'] },
];

export function App() {
  const phase = useGame((s) => s.phase);
  // Init audio on first user interaction
  useEffect(() => {
    const h = () => { initAudio(); document.removeEventListener('click', h); document.removeEventListener('touchstart', h); };
    document.addEventListener('click', h);
    document.addEventListener('touchstart', h);
    return () => { document.removeEventListener('click', h); document.removeEventListener('touchstart', h); };
  }, []);
  // Start/stop ambient based on phase
  useEffect(() => {
    if (phase === 'play') startAmbient();
    else stopAmbient();
  }, [phase]);
  return (
    <div className="u-root">
      <style>{styles}</style>
      {phase === 'title' && <TitleScreen />}
      {phase === 'create' && <CreateScreen />}
      {(phase === 'play' || phase === 'beat' || phase === 'reaction' || phase === 'tryout' || phase === 'recap') && <GameScreen />}
    </div>
  );
}

function GameScreen() {
  const phase = useGame((s) => s.phase);
  const nearNpc = useProx((s) => s.nearNpc);
  const talkingTo = useProx((s) => s.talkingTo);
  const setTalkingTo = useProx((s) => s.setTalkingTo);
  const setTryoutResult = useGame((s) => s.setTryoutResult);

  return (
    <>
      <div className="u-canvas-layer">
        <KeyboardControls map={KEY_MAP}>
          <Canvas
            shadows
            camera={{ position: [0, 2.6, 11], fov: 55, near: 0.1, far: 200 }}
            dpr={[1, 2]}
            gl={{ antialias: true }}
          >
            <Scene />
          </Canvas>
        </KeyboardControls>
      </div>
      <div className="u-ui-layer">
        <Hud />
        {phase === 'play' && !talkingTo && <ObjectiveToast />}
        {phase === 'play' && nearNpc && !talkingTo && (
          <InteractionPrompt npcId={nearNpc} onTalk={() => setTalkingTo(nearNpc)} />
        )}
        {talkingTo && phase === 'play' && <DialoguePanel npcId={talkingTo} onClose={() => setTalkingTo(null)} />}
        {phase === 'beat' && <BeatCard />}
        {phase === 'reaction' && <ReactionCard />}
        {phase === 'tryout' && (
          <TryoutScreen onComplete={(r) => setTryoutResult(r.made, r.attempted, r.grade)} />
        )}
        {phase === 'recap' && <RecapScreen />}
      </div>
      <Joystick />
    </>
  );
}

function Scene() {
  useKeyboardMovement();
  return (
    <>
      <Campus />
      <Player />
      <Npcs />
      <Students />
    </>
  );
}

// Watches the clock and presents the narrative beat for the current period.
function ObjectiveToast() {
  const completedBeats = useGame((s) => s.completedBeats);
  const periodIndex = useGame((s) => s.periodIndex);
  const showBeat = useGame((s) => s.showBeat);
  const talkingTo = useProx((s) => s.talkingTo);

  const beat = day1.beats.find((b) => !completedBeats.includes(b.id) && b.period === PERIODS[periodIndex]);

  useEffect(() => {
    if (!beat || talkingTo) return;
    // Auto-present the beat after a short window of free-roam
    const t = setTimeout(() => showBeat(beat), completedBeats.length === 0 ? 900 : 6000);
    return () => clearTimeout(t);
  }, [beat, completedBeats.length, showBeat, talkingTo]);

  if (!beat) return null;
  return (
    <div className="u-objective">
      <b>{beat.title}</b> — {beatHint(beat.id)}
    </div>
  );
}

function beatHint(id: string) {
  switch (id) {
    case 'morning_arrival':
      return 'find Jordan near the plaza';
    case 'afternoon_path':
      return 'class, gym, or the quad — pick one';
    case 'evening_coach':
      return 'the Rec Center office is open';
    case 'night_choice':
      return 'back at Hargrove for the night';
    default:
      return '';
  }
}

import { useEffect, useState } from 'react';
import { useGame, PERIODS, STAT_KEYS, type StatKey, hasSave, restoreGame } from '../game/store';
import { day1, identities } from '../game/content';
import { npcDef } from '../game/Npcs';
import { playUIConfirm } from '../game/audio';

const STAT_LABELS: Record<StatKey, string> = {
  energy: 'Energy',
  academics: 'Academics',
  athleticism: 'Athleticism',
  basketball_skill: 'Basketball',
  roommate_relationship: 'Jordan',
  coach_interest: 'Coach Interest',
};

export function Hud() {
  const day = useGame((s) => s.day);
  const periodIndex = useGame((s) => s.periodIndex);
  const energy = useGame((s) => s.stats.energy);
  return (
    <div className="u-hud">
      <div className="u-clock">
        <div className="u-clock-day">Day {day} — Move-In</div>
        <div className="u-clock-period">{cap(PERIODS[periodIndex])}</div>
      </div>
      <div className="u-energy">
        <span className="u-energy-icon">⚡</span>
        <div className="u-energy-bar">
          <div className="u-energy-fill" style={{ width: `${energy}%` }} />
        </div>
      </div>
    </div>
  );
}

export function Objective() {
  return null; // superseded by ObjectiveToast in App
}

export function InteractionPrompt({ npcId, onTalk }: { npcId: string; onTalk: () => void }) {
  const npc = npcDef(npcId);
  if (!npc) return null;
  return (
    <button className="u-prompt" onClick={onTalk}>
      Talk to {npc.name.split('—')[0].trim()}
    </button>
  );
}

export function DialoguePanel({ npcId, onClose }: { npcId: string; onClose: () => void }) {
  const npc = npcDef(npcId)!;
  const talkedTo = useGame((s) => s.talkedTo.includes(npcId));
  const applyNpcChoice = useGame((s) => s.applyNpcChoice);
  const [lineIdx] = useState(0);

  if (talkedTo) {
    return (
      <div className="u-dialogue">
        <div className="u-dialogue-name">{npc.name}</div>
        <div className="u-dialogue-text">{npc.repeat_line}</div>
        <button className="u-continue" onClick={onClose}>Close</button>
      </div>
    );
  }

  return (
    <div className="u-dialogue">
      <div className="u-dialogue-name">{npc.name}</div>
      <div className="u-dialogue-text">{npc.lines[lineIdx]}{npc.lines.length > 1 ? `\n\n${npc.lines[1]}` : ''}</div>
      <div className="u-choices">
        {npc.choices.map((c) => (
          <button key={c.id} className="u-choice" onClick={() => { playUIConfirm(); applyNpcChoice(npcId, c); }}>
            {c.label}
          </button>
        ))}
      </div>
    </div>
  );
}

export function BeatCard() {
  const currentBeat = useGame((s) => s.currentBeat);
  const chooseBeatOption = useGame((s) => s.chooseBeatOption);
  const energy = useGame((s) => s.stats.energy);
  if (!currentBeat) return null;

  return (
    <div className="u-beat-wrap">
      <div className="u-beat">
        <div className="u-beat-period">{cap(currentBeat.period)}</div>
        <div className="u-beat-title">{currentBeat.title}</div>
        <div className="u-beat-text">{currentBeat.text}</div>
        <div className="u-choices">
          {currentBeat.choices.map((c) => {
            const need = c.requirements?.energy_min;
            const locked = typeof need === 'number' && energy < need;
            return (
              <button
                key={c.id}
                className="u-choice"
                disabled={locked}
                onClick={() => { playUIConfirm(); chooseBeatOption(currentBeat, c); }}
              >
                {c.label}
                {locked && <span className="u-choice-reason">Needs {need} energy — you're running on fumes</span>}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

export function ReactionCard() {
  const pending = useGame((s) => s.pendingReaction);
  const dismiss = useGame((s) => s.dismissReaction);
  if (!pending) return null;
  const fx = Object.entries(pending.effects).filter(([, v]) => typeof v === 'number' && v !== 0);
  return (
    <div className="u-beat-wrap">
      <div className="u-beat">
        {fx.length > 0 && (
          <div className="u-effects">
            {fx.map(([k, v]) => (
              <span key={k} className={`u-effect ${(v as number) > 0 ? 'up' : 'down'}`}>
                {STAT_LABELS[k as StatKey] ?? k} {(v as number) > 0 ? `+${v}` : v}
              </span>
            ))}
          </div>
        )}
        <div className="u-beat-text">{pending.text}</div>
        <button className="u-continue" onClick={dismiss}>Continue</button>
      </div>
    </div>
  );
}

export function TitleScreen() {
  const newGame = useGame((s) => s.newGame);
  const [hasSaveState, setHasSaveState] = useState(false);
  useEffect(() => {
    setHasSaveState(hasSave());
  }, []);
  const onContinue = () => {
    if (restoreGame()) return;
  };
  return (
    <div className="u-title">
      <img className="u-title-emblem" src="assets/branding/emblem.png" alt="North Valley State emblem" />
      <div className="u-title-word">THE U</div>
      <div className="u-title-sub">North Valley State</div>
      <div className="u-menu">
        <button className="u-menu-btn primary" onClick={newGame}>New Game</button>
        <button className="u-menu-btn" onClick={onContinue} disabled={!hasSaveState}>
          {hasSaveState ? 'Continue' : 'No saved game'}
        </button>
      </div>
    </div>
  );
}

export function CreateScreen() {
  const setIdentity = useGame((s) => s.setIdentity);
  const setPlayerName = useGame((s) => s.setPlayerName);
  const startPlay = useGame((s) => s.startPlay);
  const showBeat = useGame((s) => s.showBeat);
  const identityId = useGame((s) => s.identityId);
  const [name, setName] = useState('');
  const [picked, setPicked] = useState<string | null>(null);

  const canStart = name.trim().length >= 2 && picked !== null;

  const begin = () => {
    if (!canStart) return;
    setPlayerName(name.trim());
    startPlay();
    showBeat(day1.beats[0]);
  };

  return (
    <div className="u-create">
      <h1>Who are you?</h1>
      <div className="sub">Your story at North Valley State starts here.</div>

      <div className="u-field">
        <label>Your name</label>
        <input
          className="u-name-input"
          placeholder="e.g. Alex Carter"
          value={name}
          maxLength={24}
          onChange={(e) => setName(e.target.value)}
        />
      </div>

      <div className="u-field">
        <label>Your reputation back home</label>
        <div className="u-id-cards">
          {identities.map((idn) => (
            <button
              key={idn.id}
              className={`u-id-card ${picked === idn.id ? 'selected' : ''}`}
              onClick={() => {
                setPicked(idn.id);
                setIdentity(idn.id, idn.effects);
              }}
            >
              <div className="name">{idn.name}</div>
              <div className="blurb">{idn.blurb}</div>
              <div className="fx">{formatEffects(idn.effects)}</div>
            </button>
          ))}
        </div>
      </div>

      <button className="u-menu-btn primary" style={{ width: 'min(460px, 92vw)' }} disabled={!canStart} onClick={begin}>
        Arrive on campus
      </button>
    </div>
  );
}

export function RecapScreen() {
  const stats = useGame((s) => s.stats);
  const traits = useGame((s) => s.traits);
  const reset = useGame((s) => s.reset);
  const signedUp = useGame((s) => s.signedUp);
  const tryoutMade = useGame((s) => s.tryoutMade);
  const tryoutAttempted = useGame((s) => s.tryoutAttempted);
  const tryoutGrade = useGame((s) => s.tryoutGrade);

  const counts: Record<string, number> = {};
  traits.forEach((t) => (counts[t] = (counts[t] ?? 0) + 1));
  const trait = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'social';
  const traitLine: Record<string, string> = {
    grind: 'You spent Day 1 chasing the work. The Rec Center already knows your face.',
    social: 'You spent Day 1 building your people. Half the quad knows your name.',
    scholar: 'You spent Day 1 getting ahead of the books. Professor Okafor approves. Probably.',
    rest: 'You spent Day 1 protecting your energy. Saturday you’ll be fresh — if you make it there.',
  };

  return (
    <div className="u-recap">
      <div className="u-recap-card">
        <h2>Day 1 — In the books</h2>
        <div className="u-recap-trait">{traitLine[trait]}</div>
        <div className="u-stat-rows">
          {STAT_KEYS.map((k) => (
            <div key={k} className="u-stat-row">
              <span className="lbl">{STAT_LABELS[k]}</span>
              <div className="bar"><div className="fill" style={{ width: `${stats[k]}%` }} /></div>
              <span className="val">{stats[k]}</span>
            </div>
          ))}
        </div>
        <div className="u-beat-text" style={{ fontSize: 14 }}>
          {signedUp
            ? `Tryout: ${tryoutMade}/${tryoutAttempted} free throws — ${tryoutGrade.toUpperCase()}. `
            : 'You never signed the walk-on sheet. Some doors close quietly.'}
          {tryoutGrade === 'perfect' && "Coach Delgado nodded. Once. That's the closest thing to a contract he gives."}
          {tryoutGrade === 'good' && "Delgado made a note. Good enough to watch. Not good enough to commit."}
          {tryoutGrade === 'okay' && "You didn't embarrass yourself. The coach says 'keep working.' You know what that means."}
          {tryoutGrade === 'poor' && "Delgado didn't say anything. He didn't have to."}
        </div>
        <button className="u-menu-btn primary" style={{ width: '100%' }} onClick={reset}>
          Play Day 1 again
        </button>
      </div>
    </div>
  );
}

const cap = (s: string) => s[0].toUpperCase() + s.slice(1);

function formatEffects(fx: Partial<Record<StatKey, number>>) {
  return Object.entries(fx)
    .map(([k, v]) => `${(v as number) > 0 ? '+' : ''}${v} ${STAT_LABELS[k as StatKey] ?? k}`)
    .join('  ·  ');
}

// ---------- Touch joystick ----------
export function Joystick() {
  useEffect(() => {
    let active = false;
    let originX = 0;
    let originY = 0;
    let joyEl: HTMLDivElement | null = null;
    let knobEl: HTMLDivElement | null = null;

    const onDown = (e: TouchEvent) => {
      const t = e.touches[0];
      // ignore touches on UI (buttons/panels)
      if ((e.target as HTMLElement).closest('button, .u-dialogue, .u-beat, .u-hud, .u-create, .u-menu')) return;
      active = true;
      originX = t.clientX;
      originY = t.clientY;
      joyEl = document.createElement('div');
      joyEl.className = 'u-joystick active';
      joyEl.style.left = `${originX - 56}px`;
      joyEl.style.top = `${originY - 56}px`;
      knobEl = document.createElement('div');
      knobEl.className = 'u-joystick-knob';
      joyEl.appendChild(knobEl);
      document.body.appendChild(joyEl);
    };
    const onMove = (e: TouchEvent) => {
      if (!active) return;
      const t = e.touches[0];
      let dx = t.clientX - originX;
      let dy = t.clientY - originY;
      const len = Math.hypot(dx, dy);
      const max = 44;
      if (len > max) {
        dx = (dx / len) * max;
        dy = (dy / len) * max;
      }
      if (knobEl) {
        knobEl.style.left = `${32 + dx}px`;
        knobEl.style.top = `${32 + dy}px`;
      }
      const { inputVector } = joystickRef;
      inputVector.x = dx / max;
      inputVector.z = dy / max;
    };
    const onUp = () => {
      active = false;
      joystickRef.inputVector.x = 0;
      joystickRef.inputVector.z = 0;
      joyEl?.remove();
      joyEl = null;
      knobEl = null;
    };

    window.addEventListener('touchstart', onDown, { passive: true });
    window.addEventListener('touchmove', onMove, { passive: true });
    window.addEventListener('touchend', onUp);
    window.addEventListener('touchcancel', onUp);
    return () => {
      window.removeEventListener('touchstart', onDown);
      window.removeEventListener('touchmove', onMove);
      window.removeEventListener('touchend', onUp);
      window.removeEventListener('touchcancel', onUp);
      onUp();
    };
  }, []);
  return null;
}

// mutable ref the Player reads
import { inputVector as sharedInput } from '../game/Player';
const joystickRef = { inputVector: sharedInput };

/**
 * DialogueOverlay.tsx — cinematic dialogue with name, text, character reactions,
 * and branching choices. Controlled by gameStore dialogueActive + dialogueTarget.
 */
import React, { useState, useEffect } from 'react';
import { useGameStore } from '../store/gameStore';

// Dialogue tree — simple per-character per-beat branching
const DIALOGUES: Record<string, { speaker: string; emotion: string; text: string; choices?: { label: string; nextId: string }[]; nextId?: string }[]> = {
  'jordan-intro': [
    {
      speaker: 'Jordan Hayes',
      emotion: 'curious',
      text: "You're new. I can tell — you've got that look. Like you're already trying to decide if this place is going to be something.",
      choices: [
        { label: "It already feels like something.", nextId: 'jordan-a' },
        { label: "Still figuring that out.", nextId: 'jordan-b' },
      ],
    },
    {
      speaker: 'Jordan Hayes',
      emotion: 'warm',
      text: "You smile easy. I like that. Most people here front for three weeks before they relax.",
      nextId: 'end',
    },
    {
      speaker: 'Jordan Hayes',
      emotion: 'empathetic',
      text: "That's fair. This campus has a way of pushing back until you figure out what you actually want.",
      nextId: 'end',
    },
  ],
  'marcus-intro': [
    {
      speaker: 'Marcus Chen',
      emotion: 'friendly',
      text: "Hey — I'm Marcus. I took the left side, hope that's cool. Parents are gone now, so... just us.",
      choices: [
        { label: "Perfect. Let's make this work.", nextId: 'marcus-a' },
        { label: "What're you studying?", nextId: 'marcus-b' },
      ],
    },
    {
      speaker: 'Marcus Chen',
      emotion: 'relieved',
      text: "Good. My last roommate transferred week three. Not nerves, just... yeah.",
      nextId: 'end',
    },
    {
      speaker: 'Marcus Chen',
      emotion: 'bright',
      text: "Pre-med. Bio. It's a lot. But you play anything in high school? You've got the build for something.",
      nextId: 'end',
    },
  ],
  'coach-intro': [
    {
      speaker: 'Coach Riley',
      emotion: 'measured',
      text: "You don't wander into my hall by accident. What do you want, freshman?",
      choices: [
        { label: "To walk on. Show me what you need.", nextId: 'coach-a' },
        { label: "I'm just trying to earn my spot.", nextId: 'coach-b' },
      ],
    },
    {
      speaker: 'Coach Riley',
      emotion: 'respectful',
      text: "Alright. Earn it, then. I've got eyes on everything.",
      nextId: 'end',
    },
    {
      speaker: 'Coach Riley',
      emotion: 'neutral',
      text: "Everyone's 'just trying.' Show me instead of telling me.",
      nextId: 'end',
    },
  ],
  'first-arrival': [
    { speaker: '', emotion: 'reflective', text: "The car pulls away. You're standing in front of Ridgeview Hall alone. Suitcase. Dorm key. One chance.", nextId: 'end' },
  ],
};

function getDialogue(id: string) {
  const tree = DIALOGUES[id];
  if (!tree) return null;
  return tree;
}

export const DialogueOverlay = () => {
  const active = useGameStore((s) => s.ui.dialogueActive);
  const target = useGameStore((s) => s.ui.dialogueTarget);
  const endDialogue = useGameStore((s) => s.endDialogue);
  const [nodeId, setNodeId] = useState<string>('start');

  // Reset node when dialogue becomes active / target changes
  useEffect(() => {
    if (active) setNodeId('start');
  }, [active, target]);

  if (!active || !target) return null;

  const tree = getDialogue(target);
  if (!tree) {
    // No dialogue data — render fallback and allow exit
    return (
      <div style={d.root}>
        <div style={d.panel}>
          <div style={d.speaker}>{target}</div>
          <p style={d.text}>...</p>
          <button style={d.choiceBtn} onClick={() => endDialogue()}>Continue</button>
        </div>
      </div>
    );
  }

  // find current node in tree by id
  // id maps directly to index when numeric; named entries map via their key
  let node = tree[0];
  if (nodeId !== 'start') {
    const idx = tree.findIndex((n, i) => {
      return (
        `${i}` === nodeId ||
        (n as any).id === nodeId ||
        false
      );
    });
    if (idx >= 0) node = tree[idx];
  }

  if (!node) node = tree[0];

  const handleChoice = (nextId: string | undefined) => {
    if (!nextId || nextId === 'end') {
      endDialogue();
    } else {
      setNodeId(nextId);
    }
  };

  return (
    <div style={d.root}>
      {/* Speaker name plate */}
      {node.speaker && (
        <div style={d.speakerPlate}>
          <span style={d.speakerName}>{node.speaker}</span>
        </div>
      )}

      {/* Dialogue panel */}
      <div style={d.panel}>
        <p style={d.text}>{node.text}</p>

        {/* Choices */}
        {node.choices && node.choices.length > 0 && (
          <div style={d.choices}>
            {node.choices.map((c, i) => (
              <button
                key={i}
                style={d.choiceBtn}
                onClick={() => handleChoice(c.nextId)}
              >
                {c.label}
              </button>
            ))}
          </div>
        )}

        {/* Continue (no choices) */}
        {(!node.choices || node.choices.length === 0) && (
          <button style={{ ...d.choiceBtn, alignSelf: 'flex-end' }} onClick={() => handleChoice(node.nextId)}>
            Continue
          </button>
        )}
      </div>
    </div>
  );
};

const d: Record<string, React.CSSProperties> = {
  root: { position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', padding: '8vh 8vw', pointerEvents: 'auto', gap: 16},
  speakerPlate: { alignSelf: 'flex-start', background: 'rgba(10, 22, 40, 0.9)', padding: '6px 16px', borderRadius: 20, border: '1px solid rgba(212,168,67,0.4)', marginLeft: 40 },
  speakerName: { color: '#f0d070', fontSize: 14, fontWeight: 600, letterSpacing: '0.08em' },
  panel: { background: 'rgba(10, 14, 26, 0.92)', borderRadius: 14, padding: '20px 26px', border: '1px solid rgba(255,255,255,0.1)', backdropFilter: 'blur(8px)', maxWidth: 700, display: 'flex', flexDirection: 'column', gap: 14 },
  text: { color: '#f0ece0', fontSize: 17, lineHeight: 1.5, margin: 0 },
  choices: { display: 'flex', flexDirection: 'column', gap: 8 },
  choiceBtn: { padding: '12px 16px', background: 'rgba(212, 168, 67, 0.12)', border: '1px solid rgba(212,168,67,0.4)', borderRadius: 8, color: '#f0ece0', fontSize: 15, textAlign: 'left', cursor: 'pointer', fontFamily: 'inherit', transition: 'background 0.15s' },
};

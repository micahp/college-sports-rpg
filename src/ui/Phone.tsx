/**
 * Phone.tsx — smartphone overlay. Central hub for campus life.
 * Slides up from bottom; contains tabs: Schedule, Map, Messages, Team, Me.
 */
import React, { useState } from 'react';
import { useGameStore } from '../store/gameStore';

type Tab = 'schedule' | 'map' | 'messages' | 'team' | 'me';

function ScheduleTab() {
  const day = useGameStore((s) => s.day);
  const relationships = useGameStore((s) => s.relationships);
  return (
    <div style={{ padding: 16 }}>
      <h3 style={{ color: '#f0d070', fontSize: 18, margin: '0 0 12px', fontFamily: 'Georgia, serif' }}>Today</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <ScheduleItem time="9:00" text="Breakfast — The Commons" />
        <ScheduleItem time="12:00" text="Class — Lecture Hall A (Elena Reyes)" />
        <ScheduleItem time="16:00" text="Gym — Rec Center" />
        <ScheduleItem time="19:00" text="Evening — Student Union" />
      </div>
      {Object.keys(relationships).length > 0 && (
        <>
          <h4 style={{ color: '#a09880', fontSize: 12, margin: '16px 0 8px', letterSpacing: '0.15em' }}>KEY PEOPLE</h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {Object.entries(relationships).map(([id, rel]) => (
              <div key={id} style={{ color: '#f0ece0', fontSize: 13 }}>
                {rel.name ?? id} — {rel.relation >= 15 ? 'friendly' : rel.relation >= 5 ? 'warming' : 'neutral'}
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

const ScheduleItem: React.FC<{ time: string; text: string }> = ({ time, text }) => (
  <div style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '10px 12px', background: 'rgba(255,255,255,0.04)', borderRadius: 8 }}>
    <span style={{ color: '#d4a843', fontSize: 12, fontVariantNumeric: 'tabular-nums', minWidth: 44 }}>{time}</span>
    <span style={{ color: '#f0ece0', fontSize: 13 }}>{text}</span>
  </div>
);

function MapTab() {
  // Simple stylized campus map with dots + teleport
  const locations = useGameStore.getState();
  const teleport = (x: number, z: number) => {
    // Teleport player to location
    useGameStore.getState().travelTo('quad');
    // Set player position via the physics body
    const { useInputStore } = require('../store/inputStore');
    // Direct position set through game store action
    useGameStore.getState().setPaused(false);
    // Move player by setting the rigidbody position (we'll use a global event)
    window.dispatchEvent(new CustomEvent('teleportPlayer', { detail: { x, z } }));
  };
  return (
    <div style={{ padding: 16 }}>
      <h3 style={{ color: '#f0d070', fontSize: 18, margin: '0 0 12px', fontFamily: 'Georgia, serif' }}>Campus Map</h3>
      <div style={{ position: 'relative', width: '100%', height: 280, background: 'rgba(30, 40, 60, 0.5)', borderRadius: 10, overflow: 'hidden' }}>
        {/* campus blocks */}
        {[
          [-20, 30, 'Dorm'],
          [10, -10, 'Rec'],
          [32, -20, 'Gym'],
          [-10, -15, 'STEM'],
          [20, 15, 'Dining'],
          [5, 20, 'Union'],
          [-30, 10, 'Lib'],
          [0, 22, 'Court'],
        ].map(([x, z, label], i) => (
          <div key={i} style={{ position: 'absolute', left: `${50 + (x as number) * 1.0}%`, top: `${50 - (z as number) * 1.0}%`, transform: 'translate(-50%,-50%)' }}>
            <button
              onClick={() => teleport(x as number, z as number)}
              style={{ width: 18, height: 18, borderRadius: 9, background: label === 'Court' ? '#d4762a' : '#d4a843', border: 'none', cursor: 'pointer', padding: 0 }}
              title={`Teleport to ${label}`}
            />
            <div style={{ color: '#a09880', fontSize: 8, marginTop: 2, textAlign: 'center' }}>{label as string}</div>
          </div>
        ))}
      </div>
      <p style={{ color: '#a09880', fontSize: 11, marginTop: 8 }}>Tap a location to teleport there.</p>
    </div>
  );
}

function MessagesTab() {
  return (
    <div style={{ padding: 16 }}>
      <h3 style={{ color: '#f0d070', fontSize: 18, margin: '0 0 12px', fontFamily: 'Georgia, serif' }}>Messages</h3>
      <MsgItem from="Jordan" text="Find the rec yet?" unread />
      <MsgItem from="Marcus" text="you got the left side remember" />
      <MsgItem from="Campus" text="Welcome to North Valley State — orientation tonight." />
    </div>
  );
}

const MsgItem: React.FC<{ from: string; text: string; unread?: boolean }> = ({ from, text, unread }) => (
  <div style={{ display: 'flex', gap: 10, padding: '12px 12px', background: unread ? 'rgba(212, 168, 67, 0.08)' : 'rgba(255,255,255,0.03)', borderRadius: 8, marginBottom: 6 }}>
    <div style={{ width: 36, height: 36, borderRadius: 18, background: 'linear-gradient(135deg, #0a1628, #142240)', border: '1px solid #d4a843', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#d4a843', fontWeight: 600, fontSize: 14 }}>{from[0]}</div>
    <div>
      <div style={{ color: '#f0d070', fontSize: 13, fontWeight: 600 }}>{from}</div>
      <div style={{ color: unread ? '#f0ece0' : '#a09880', fontSize: 13 }}>{text}</div>
    </div>
  </div>
);

function TeamTab() {
  const stats = useGameStore((s) => s.stats);
  return (
    <div style={{ padding: 16 }}>
      <h3 style={{ color: '#f0d070', fontSize: 18, margin: '0 0 12px', fontFamily: 'Georgia, serif' }}>Ridgehawks — Walk-on</h3>
      <Stat label="Athletic" value={stats.athletic} color="#27ae60" />
      <Stat label="Confidence" value={stats.confidence} color="#d4a843" />
      <Stat label="Academic" value={stats.academic} color="#2980b9" />
      <Stat label="Reputation" value={stats.reputation} color="#e67e22" />
    </div>
  );
}

const Stat: React.FC<{ label: string; value: number; color: string }> = ({ label, value, color }) => (
  <div style={{ marginBottom: 10 }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#a09880', marginBottom: 3 }}>
      <span>{label}</span><span>{Math.round(value)}</span>
    </div>
    <div style={{ height: 5, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
      <div style={{ width: `${Math.min(100, value)}%`, height: '100%', background: color, borderRadius: 3 }} />
    </div>
  </div>
);

function MeTab() {
  const player = useGameStore((s) => s.player);
  return (
    <div style={{ padding: 16 }}>
      <h3 style={{ color: '#f0d070', fontSize: 18, margin: '0 0 12px', fontFamily: 'Georgia, serif' }}>Me</h3>
      {player && (
        <>
          <div style={{ color: '#f0ece0', fontSize: 20, fontWeight: 600 }}>{player.name}</div>
          <div style={{ color: '#a09880', fontSize: 13, marginBottom: 8 }}>{player.pronouns} · {player.bodyType} · {player.personality}</div>
          <div style={{ color: '#a09880', fontSize: 13, fontStyle: 'italic' }}>"{player.motivation}"</div>
        </>
      )}
    </div>
  );
}

export const Phone = () => {
  const open = useGameStore((s) => s.ui.phoneOpen);
  const closePhone = useGameStore((s) => s.closePhone);
  const [tab, setTab] = useState<Tab>('schedule');

  if (!open) return null;

  const tabs: { id: Tab; icon: string }[] = [
    { id: 'schedule', icon: '◷' },
    { id: 'map', icon: '✦' },
    { id: 'messages', icon: '✉' },
    { id: 'team', icon: '◆' },
    { id: 'me', icon: '☺' },
  ];

  return (
    <div style={p.overlay} onClick={closePhone}>
      <div style={p.phone} onClick={(e) => e.stopPropagation()}>
        {/* Status bar */}
        <div style={p.statusBar}>
          <span style={{ color: '#f0ece0', fontSize: 11, letterSpacing: '0.1em' }}>North Valley State</span>
          <span style={{ color: '#f0ece0', fontSize: 11 }}>
            {useGameStore.getState().hour.toString().padStart(2, '0')}:
            {useGameStore.getState().minute.toString().padStart(2, '0')}
          </span>
        </div>

        {/* Screen content */}
        <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch' }}>
          {tab === 'schedule' && <ScheduleTab />}
          {tab === 'map' && <MapTab />}
          {tab === 'messages' && <MessagesTab />}
          {tab === 'team' && <TeamTab />}
          {tab === 'me' && <MeTab />}
        </div>

        {/* Tab bar */}
        <div style={p.tabBar}>
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              style={{
                ...p.tabBtn,
                color: tab === t.id ? '#f0d070' : '#a09880',
                background: tab === t.id ? 'rgba(212, 168, 67, 0.1)' : 'transparent',
              }}
            >
              <span style={{ fontSize: 18, display: 'block' }}>{t.icon}</span>
              <span style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.1em' }}>{t.id}</span>
            </button>
          ))}
        </div>

        {/* Close hint */}
        <button style={p.closeBtn} onClick={closePhone}>
          <svg viewBox="0 0 24 24" width={18} height={18} fill="none" stroke="#a09880" strokeWidth={2}>
            <circle cx="12" cy="12" r="10" />
            <line x1="8" y1="8" x2="16" y2="16" />
            <line x1="16" y1="8" x2="8" y2="16" />
          </svg>
        </button>
      </div>
    </div>
  );
};

const p: Record<string, React.CSSProperties> = {
  overlay: { position: 'absolute', inset: 0, background: 'rgba(5, 8, 16, 0.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'flex-end', justifyContent: 'flex-end', zIndex: 50 },
  phone: { width: 'min(400px, 90vw)', height: 'min(600px, 78vh)', background: 'linear-gradient(160deg, #0a1628, #142240)', border: '1px solid rgba(212, 168, 67, 0.3)', borderRadius: 20, margin: '4vh 4vw', display: 'flex', flexDirection: 'column', position: 'relative', boxShadow: '0 20px 60px rgba(0,0,0,0.5)', overflow: 'hidden' },
  statusBar: { display: 'flex', justifyContent: 'space-between', padding: '8px 16px', borderBottom: '1px solid rgba(255,255,255,0.08)' },
  tabBar: { display: 'flex', justifyContent: 'space-around', padding: '4px 0', borderTop: '1px solid rgba(255,255,255,0.08)' },
  tabBtn: { flex: 1, padding: '4px 0', border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, fontFamily: 'inherit' },
  closeBtn: { position: 'absolute', top: 8, right: 8, width: 28, height: 28, borderRadius: 14, background: 'rgba(255,255,255,0.08)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center' },
};

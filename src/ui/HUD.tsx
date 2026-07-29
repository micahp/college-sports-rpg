/**
 * HUD.tsx — heads-up display: clock, energy, money, quest + phone toggle.
 */
import React from 'react';
import { useGameStore } from '../store/gameStore';

function clamp(n: number, min: number, max: number) { return Math.max(min, Math.min(max, n)); }

function Clock({ hour, minute, day }: { hour: number; minute: number; day: number }) {
  const hh = Math.floor(hour).toString().padStart(2, '0');
  const mm = Math.floor(minute).toString().padStart(2, '0');
  return (
    <div style={h.clockBox}>
      <div style={h.clockTime}>{hh}:{mm}</div>
      <div style={h.clockDay}>Day {day}</div>
    </div>
  );
}

function StatBar({ value, max, color, icon }: { value: number; max: number; color: string; icon: string }) {
  const pct = clamp((value / max) * 100, 0, 100);
  return (
    <div style={h.statRow}>
      <span style={h.statIcon}>{icon}</span>
      <div style={h.statTrack}>
        <div style={{ ...h.statFill, width: `${pct}%`, background: color }} />
      </div>
      <span style={h.statVal}>{Math.round(value)}</span>
    </div>
  );
}

function QuestBanner() {
  const quest = useGameStore((s) => s.activeQuest);
  const notify = useGameStore((s) => s.ui.notification);
  const text = notify ?? quest ?? "Arrive on campus. Find Ridgeview Hall.";
  if (!text) return null;
  return (
    <div style={h.questBanner}>
      <span role="img" aria-label="quote" style={{ color: '#d4a843' }}>◆</span>
      <span style={{ marginLeft: 8 }}>{text}</span>
    </div>
  );
}

function FPSCounter() {
  const [fps, setFps] = React.useState(60);
  React.useEffect(() => {
    let frames = 0;
    let lastTime = performance.now();
    let rafId: number;
    const tick = (now: number) => {
      frames++;
      const delta = now - lastTime;
      if (delta >= 500) {
        setFps(Math.round((frames * 1000) / delta));
        frames = 0;
        lastTime = now;
      }
      rafId = requestAnimationFrame(tick);
    };
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, []);
  const color = fps >= 55 ? '#27ae60' : fps >= 30 ? '#d4a843' : '#c0392b';
  return (
    <div style={{ background: 'rgba(10, 14, 26, 0.85)', borderRadius: 8, padding: '4px 10px', border: '1px solid rgba(255,255,255,0.1)', fontSize: 12, fontVariantNumeric: 'tabular-nums', color }}>
      {fps} FPS
    </div>
  );
}

function InteractionPrompt() {
  const [show, setShow] = React.useState(false);
  const [message, setMessage] = React.useState('');
  const gs = useGameStore.getState();
  
  React.useEffect(() => {
    const checkProximity = () => {
      // Check if near basketball court at [0, 0, 22]
      const body = (window as any).__playerBody;
      if (body) {
        const pos = body.translation();
        const dist = Math.hypot(pos.x - 0, pos.z - 22);
        if (dist < 6 && !gs.ui.basketballMode) {
          setShow(true);
          setMessage('Press E to Play Basketball');
        } else {
          setShow(false);
        }
      }
    };
    const interval = setInterval(checkProximity, 200);
    return () => clearInterval(interval);
  }, []);
  
  if (!show) return null;
  return (
    <div style={{ position: 'absolute', bottom: 120, left: '50%', transform: 'translateX(-50%)', background: 'rgba(10, 22, 40, 0.9)', borderRadius: 12, padding: '12px 24px', border: '2px solid #d4a843', color: '#f0d070', fontSize: 16, fontWeight: 600, pointerEvents: 'none', animation: 'pulse 2s infinite' }}>
      {message}
    </div>
  );
}

export const HUD = () => {
  const hour = useGameStore((s) => s.hour);
  const minute = useGameStore((s) => s.minute);
  const day = useGameStore((s) => s.day);
  const stats = useGameStore((s) => s.stats);
  const openPhone = useGameStore((s) => s.openPhone);
  const dialogueActive = useGameStore((s) => s.ui.dialogueActive);

  if (dialogueActive) {
    // Minimal clock during dialogue so it doesnt block the cinematic framing
    return (
      <div style={h.dialogueCorner}>
        <Clock hour={hour} minute={minute} day={day} />
      </div>
    );
  }

  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      {/* Top-left: clock + stats */}
      <div style={h.topLeft}>
        <Clock hour={hour} minute={minute} day={day} />
        <StatBar value={stats.energy} max={100} color="#27ae60" icon="⚡" />
        <StatBar value={stats.confidence} max={100} color="#d4a843" icon="✦" />
        <div style={h.moneyTag}>${stats.money}</div>
      </div>

      {/* Bottom-center: quest banner */}
      <div style={h.questWrap}>
        <QuestBanner />
      </div>

      {/* Bottom-right: phone button (always visible in play) */}
      <button style={h.phoneBtn} onClick={() => openPhone()} title="Open Phone">
        <svg viewBox="0 0 24 24" width={28} height={28} fill="none" stroke="#f0ece0" strokeWidth={1.8}>
          <rect x="5" y="2" width="14" height="20" rx="2" />
          <line x1="10" y1="18" x2="14" y2="18" />
        </svg>
      </button>

      {/* Top-right: map / menu quick access + FPS */}
      <div style={h.topRight}>
        <FPSCounter />
        <button style={h.iconBtn} title="Map" onClick={() => {}}>
          <svg viewBox="0 0 24 24" width={22} height={22} fill="none" stroke="#a09880" strokeWidth={1.8}>
            <path d="M9 4 L3 6 V20 L9 18 L15 20 L21 18 V4 L15 6 Z" />
            <line x1="9" y1="4" x2="9" y2="18" />
            <line x1="15" y1="6" x2="15" y2="20" />
          </svg>
        </button>
        <button style={h.iconBtn} title="Menu" onClick={() => {}}>
          <svg viewBox="0 0 24 24" width={22} height={22} fill="none" stroke="#a09880" strokeWidth={2}>
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
      </div>

      {/* Interaction prompt (context-sensitive) */}
      <InteractionPrompt />
    </div>
  );
};

const h: Record<string, React.CSSProperties> = {
  topLeft: { position: 'absolute', top: 16, left: 16, display: 'flex', flexDirection: 'column', gap: 8 },
  clockBox: { background: 'rgba(10, 14, 26, 0.85)', borderRadius: 10, padding: '10px 14px', border: '1px solid rgba(212, 168, 67, 0.3)', backdropFilter: 'blur(6px)' },
  clockTime: { color: '#f0ece0', fontSize: 22, fontWeight: 600, fontVariantNumeric: 'tabular-nums' },
  clockDay: { color: '#a09880', fontSize: 11, letterSpacing: '0.15em', marginTop: 2 },
  moneyTag: { color: '#27ae60', fontSize: 14, fontWeight: 600, background: 'rgba(10, 14, 26, 0.85)', borderRadius: 20, padding: '4px 12px', border: '1px solid rgba(39, 174, 96, 0.3)', width: 'fit-content' },
  statRow: { display: 'flex', alignItems: 'center', gap: 6 },
  statIcon: { fontSize: 14, width: 16, textAlign: 'center' },
  statTrack: { width: 120, height: 6, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' },
  statFill: { height: '100%', borderRadius: 3, transition: 'width 0.3s' },
  statVal: { color: '#a09880', fontSize: 12, width: 28, textAlign: 'right' },
  questWrap: { position: 'absolute', bottom: 24, left: '50%', transform: 'translateX(-50%)', width: 'min(600px, 80vw)' },
  questBanner: { background: 'rgba(10, 14, 26, 0.9)', color: '#f0ece0', borderRadius: 10, padding: '12px 18px', fontSize: 14, border: '1px solid rgba(212, 168, 67, 0.25)', textAlign: 'center' },
  phoneBtn: { position: 'absolute', bottom: 24, right: 24, width: 60, height: 60, borderRadius: 30, background: 'linear-gradient(135deg, #d4a843, #a07820)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 6px 24px rgba(212, 168, 67, 0.4)', pointerEvents: 'auto' },
  topRight: { position: 'absolute', top: 16, right: 16, display: 'flex', gap: 8 },
  iconBtn: { width: 44, height: 44, borderRadius: 12, background: 'rgba(10, 14, 26, 0.85)', border: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'auto' },
  dialogueCorner: { position: 'absolute', top: 16, right: 16 },
};

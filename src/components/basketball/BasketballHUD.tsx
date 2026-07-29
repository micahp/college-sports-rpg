/**
 * basketball/BasketballHUD.tsx — score, makes, streak, power meter, exit button.
 */
import React from 'react';
import { useGameStore } from '../../store/gameStore';
import { getBallState } from './BasketballGame';

export const BasketballHUD = () => {
  const shotsTaken = useGameStore((s) => s.basketball.shotsTaken);
  const shotsMade = useGameStore((s) => s.basketball.shotsMade);
  const score = useGameStore((s) => s.basketball.score);
  const streak = useGameStore((s) => s.basketball.streak);
  const exit = useGameStore((s) => s.exitBasketballMode);
  const pct = shotsTaken > 0 ? Math.round((shotsMade / shotsTaken) * 100) : 0;
  const power = getBallState().power;
  const message = getBallState().message;

  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', fontFamily: 'Georgia, serif' }}>
      {/* Top bar */}
      <div style={{ position: 'absolute', top: 16, left: 16, display: 'flex', gap: 12, alignItems: 'center' }}>
        <div style={{ background: 'rgba(10,14,26,0.85)', borderRadius: 10, padding: '8px 16px', border: '1px solid rgba(212,168,67,0.4)' }}>
          <span style={{ color: '#a09880', fontSize: 11, marginRight: 8 }}>SCORE</span>
          <span style={{ color: '#f0ece0', fontSize: 22, fontWeight: 700 }}>{score}</span>
        </div>
        <div style={{ background: 'rgba(10,14,26,0.85)', borderRadius: 10, padding: '8px 14px', border: '1px solid rgba(255,255,255,0.1)' }}>
          <span style={{ color: '#27ae60', fontSize: 13, fontWeight: 600 }}>{shotsMade}</span>
          <span style={{ color: '#a09880', fontSize: 13 }}> / {shotsTaken}</span>
        </div>
        <div style={{ background: 'rgba(10,14,26,0.85)', borderRadius: 10, padding: '8px 14px', border: '1px solid rgba(255,255,255,0.1)' }}>
          <span style={{ color: '#a09880', fontSize: 12 }}>FG% </span>
          <span style={{ color: '#f0ece0', fontSize: 14, fontWeight: 600 }}>{pct}</span>
        </div>
        {streak > 1 && (
          <div style={{ background: 'rgba(212, 100, 50, 0.3)', borderRadius: 10, padding: '6px 12px', border: '1px solid #d4762a' }}>
            <span style={{ color: '#f0d070', fontSize: 14, fontWeight: 700 }}>🔥 {streak}</span>
          </div>
        )}
      </div>

      {/* Message */}
      {message && (
        <div style={{ position: 'absolute', top: '40%', left: '50%', transform: 'translate(-50%,-50%)', color: message === 'SWISH!' ? '#27ae60' : '#c0392b', fontSize: 64, fontWeight: 700, letterSpacing: '0.1em', textShadow: '0 4px 20px rgba(0,0,0,0.6)' }}>
          {message}
        </div>
      )}

      {/* Power meter bottom-center */}
      <div style={{ position: 'absolute', bottom: 30, left: '50%', transform: 'translateX(-50%)', width: 260 }}>
        <div style={{ height: 8, background: 'rgba(10,14,26,0.85)', borderRadius: 4, border: '1px solid rgba(255,255,255,0.1)', overflow: 'hidden' }}>
          <div style={{ width: `${power}%`, height: '100%', background: 'linear-gradient(90deg, #27ae60, #f0d070, #d4762a)', transition: 'width 0.05s', borderRadius: 4 }} />
        </div>
        <div style={{ color: '#a09880', fontSize: 11, textAlign: 'center', marginTop: 4, letterSpacing: '0.1em' }}>HOLD TO CHARGE · RELEASE TO SHOOT</div>
      </div>

      {/* Exit button */}
      <button
        data-ui="true"
        onClick={() => exit()}
        style={{ position: 'absolute', top: 16, right: 16, pointerEvents: 'auto', background: 'rgba(10,14,26,0.9)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: 10, color: '#a09880', padding: '10px 16px', fontSize: 13, display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}
      >
        ✕ Exit Gym
      </button>
    </div>
  );
};

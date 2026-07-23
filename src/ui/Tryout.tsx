// Timing-based basketball free throw minigame.
// Power bar sweeps up and down; player taps to release.
// Accuracy determines shot quality (perfect / good / okay / miss).
// Score feeds into the final recap alongside week choices.

import { useState, useEffect, useRef } from 'react';
import { useGame } from '../game/store';

interface TryoutResult {
  made: number;
  attempted: number;
  grade: 'perfect' | 'good' | 'okay' | 'poor';
}

export function TryoutScreen({ onComplete }: { onComplete: (r: TryoutResult) => void }) {
  const [phase, setPhase] = useState<'intro' | 'shooting' | 'done'>('intro');
  const [power, setPower] = useState(0);
  const [dir, setDir] = useState(1);
  const [shots, setShots] = useState<('made' | 'miss')[]>([]);
  const frameRef = useRef(0);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const totalShots = 5;

  // Animate power bar
  useEffect(() => {
    if (phase !== 'shooting') return;
    let running = true;
    const loop = () => {
      if (!running) return;
      setPower((p) => {
        let next = p + dir * 0.025;
        if (next >= 1) { setDir(-1); next = 1; }
        if (next <= 0) { setDir(1); next = 0; }
        return next;
      });
      frameRef.current = requestAnimationFrame(loop);
    };
    frameRef.current = requestAnimationFrame(loop);
    return () => { running = false; cancelAnimationFrame(frameRef.current); };
  }, [phase, dir]);

  // Draw mini hoop scene on the canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = 400 * dpr;
    canvas.height = 200 * dpr;
    ctx.scale(dpr, dpr);

    // backdrop
    ctx.fillStyle = '#1a1530';
    ctx.fillRect(0, 0, 400, 200);

    // court floor
    ctx.fillStyle = '#7a5030';
    ctx.fillRect(0, 150, 400, 50);

    // backboard
    ctx.fillStyle = '#d94a3a';
    ctx.fillRect(263, 35, 120, 65);
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 2;
    ctx.strokeRect(263, 35, 120, 65);
    ctx.strokeRect(323, 35, 0, 65);

    // rim
    ctx.strokeStyle = '#e65030';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.ellipse(323, 100, 22, 8, 0, 0, Math.PI * 2);
    ctx.stroke();

    // net
    ctx.strokeStyle = '#ddd';
    ctx.lineWidth = 1;
    for (let i = -18; i <= 18; i += 6) {
      ctx.beginPath();
      ctx.moveTo(323 + i * 0.9, 100);
      ctx.lineTo(323 + i * 0.7, 118);
      ctx.stroke();
    }

    // ball (animated position based on power for preview)
    const by = phase === 'shooting' ? 140 - power * 140 : 140;
    const bx = 323 - (1 - power) * 8 + Math.sin(power * 3) * 7;

    ctx.fillStyle = '#e8983e';
    ctx.beginPath();
    ctx.arc(bx, by, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#1a1a1a';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(bx, by, 7, 0, Math.PI * 2);
    ctx.stroke();
    // lines on ball
    ctx.beginPath();
    ctx.moveTo(bx - 5, by);
    ctx.lineTo(bx + 5, by);
    ctx.moveTo(bx, by - 5);
    ctx.lineTo(bx, by + 5);
    ctx.stroke();
  }, [power, phase]);

  const takeShot = () => {
    const accuracy = 1 - Math.abs(power - 0.48); // sweet spot at 48%
    const made = accuracy > 0.35 || (accuracy > 0.18 && Math.random() < accuracy * 1.5);
    const next = [...shots, made ? 'made' as const : 'miss' as const];
    setShots(next);
    setPower(0);
    setDir(1);
    if (next.length >= totalShots) {
      cancelAnimationFrame(frameRef.current);
      setPhase('done');
    }
  };

  // Calculate grade
  const made = shots.filter((s) => s === 'made').length;
  let grade: TryoutResult['grade'];
  if (made >= 5) grade = 'perfect';
  else if (made >= 3) grade = 'good';
  else if (made >= 1) grade = 'okay';
  else grade = 'poor';

  useEffect(() => {
    if (phase === 'done') {
      onComplete({ made, attempted: totalShots, grade });
    }
  }, [phase, made, grade, onComplete]);

  if (phase === 'intro') {
    return (
      <div style={overlay}>
        <div style={card}>
          <h2 style={{ margin: '0 0 12px', fontFamily: 'Archivo', fontSize: 26, fontWeight: 900 }}>Walk-On Tryout</h2>
          <p style={{ margin: '0 0 18px', color: '#b8bfce', fontSize: 15, lineHeight: 1.55 }}>
            Coach Delgado is watching from the sideline. Five free throws. Make them count.
          </p>
          <button style={btn} onClick={() => { setPhase('shooting'); }}>Step to the line</button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ ...overlay, background: 'rgba(10, 14, 22, 0.85)' }}>
      <div style={card}>
        {/* Score tracker */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 16, justifyContent: 'center' }}>
          {Array.from({ length: totalShots }, (_, i) => (
            <div key={i} style={{
              width: 28, height: 28, borderRadius: '50%',
              background: shots[i] === 'made' ? '#7dd69a' : shots[i] === 'miss' ? '#e08080' : 'rgba(255,255,255,0.15)',
              border: '2px solid rgba(255,255,255,0.3)',
            }} />
          ))}
        </div>

        {/* Mini hoop visualization */}
        <canvas ref={canvasRef} style={{ width: 320, height: 160, margin: '0 auto 14px', display: 'block', borderRadius: 12 }} />

        {/* Power bar */}
        <div style={{
          width: '100%', height: 12, borderRadius: 99, background: 'rgba(255,255,255,0.12)',
          overflow: 'hidden', marginBottom: 14,
        }}>
          <div style={{
            width: `${power * 100}%`, height: '100%', borderRadius: 99,
            background: power > 0.55 ? '#e08080' : power < 0.35 ? '#e08080' : 'linear-gradient(90deg, #7dd69a, var(--gold))',
            transition: 'width 30ms linear',
          }} />
        </div>

        <button
          style={{ ...btn, opacity: phase === 'shooting' ? 1 : 0.6 }}
          onClick={phase === 'shooting' ? takeShot : undefined}
        >
          {phase === 'shooting' ? 'SHOOT' : `${made}/${totalShots} — ${grade.toUpperCase()}`}
        </button>
        <p style={{ margin: '8px 0 0', fontSize: 12, color: '#6a7488' }}>
          Tap when the bar is in the gold zone
        </p>
      </div>
    </div>
  );
}

const overlay: React.CSSProperties = {
  position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
  background: 'radial-gradient(ellipse at center, rgba(10,14,24,0.7), rgba(10,14,24,0.95))',
  zIndex: 100,
};
const card: React.CSSProperties = {
  width: 'min(420px, calc(100% - 32px))',
  background: 'linear-gradient(165deg, #1a2440, #101623)',
  border: '1px solid rgba(235,184,77,0.45)',
  borderRadius: 24, padding: 28,
  boxShadow: '0 32px 80px rgba(0,0,0,0.6)',
  textAlign: 'center',
};
const btn: React.CSSProperties = {
  display: 'inline-block',
  fontFamily: '"Archivo", system-ui, sans-serif', fontWeight: 800, fontSize: 17,
  letterSpacing: '0.06em',
  padding: '14px 34px', borderRadius: 14,
  border: '1px solid rgba(235,184,77,0.5)',
  background: 'var(--gold, #EBB84D)', color: '#101623',
  cursor: 'pointer',
  textTransform: 'uppercase',
};

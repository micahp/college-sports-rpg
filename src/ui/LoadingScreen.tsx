/**
 * LoadingScreen.tsx — branded loading sequence.
 * Simulates loading, then transitions into the game.
 */
import React, { useEffect, useState } from 'react';
import { useGameStore } from '../store/gameStore';

const TIPS = [
  "Your choices echo past the first week.",
  "Jordan notices who shows up early.",
  "Coach Riley watches everything.",
  "Tyrell's respect has to be earned.",
  "Grades keep you eligible.",
];

export const LoadingScreen = () => {
  const setPhase = useGameStore((s) => s.setPhase);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    const tick = () => {
      const elapsed = (performance.now() - start) / 1000;
      const p = Math.min(100, elapsed * 30);
      setProgress(p);
      if (p < 100) {
        raf = requestAnimationFrame(tick);
      } else {
        setTimeout(() => setPhase('playing'), 400);
      }
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [setPhase]);

  return (
    <div style={st.root}>
      <div style={{ ...st.bar, width: `${progress}%` }} />
      <div style={st.center}>
        <h2 style={st.title}>The U</h2>
        <p style={st.tip}>{TIPS[Math.floor(progress / 25) % TIPS.length]}</p>
      </div>
      <p style={st.pct}>{Math.round(progress)}%</p>
    </div>
  );
};

const st: Record<string, React.CSSProperties> = {
  root: { position: 'absolute', inset: 0, background: '#050810', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  bar: { position: 'absolute', top: 0, left: 0, height: 3, background: 'linear-gradient(90deg, #d4a843, #f0d070)', transition: 'width 0.1s' },
  center: { textAlign: 'center' },
  title: { color: '#f0ece0', fontSize: 48, letterSpacing: '0.3em', margin: '0 0 24px', fontFamily: 'Georgia, serif' },
  tip: { color: '#a09880', fontSize: 14, fontStyle: 'italic', maxWidth: 400 },
  pct: { position: 'absolute', bottom: 40, color: '#4a4840', fontSize: 12, letterSpacing: '0.2em' },
};

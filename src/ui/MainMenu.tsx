/**
 * ui/MainMenu.tsx — branded title screen with new game / continue / settings.
 * Dark, atmospheric, Ridgehawks gold accents, stylized campus silhouette behind.
 */
import React, { useState } from 'react';
import { useGameStore } from '../store/gameStore';

export const MainMenu = () => {
  const setPhase = useGameStore((s) => s.setPhase);
  const createPlayer = useGameStore((s) => s.createPlayer);
  const params = new URLSearchParams(window.location.search);
  const quickPlay = params.has('quick');
  const startHour = parseFloat(params.get('t') || '7.5');

  if (quickPlay) {
    setTimeout(() => {
      useGameStore.getState().setTime(Math.floor(startHour), Math.round((startHour % 1) * 60));
    }, 100);
    createPlayer({
      name: 'Jordan',
      pronouns: 'he',
      skinTone: 4,
      face: 0,
      hairStyle: 1,
      hairColor: 1,
      bodyType: 'athletic',
      clothing: { top: 0, bottom: 0, shoes: 0, accessory: 0 },
      athleticBackground: 'basketball',
      academicStrength: 'math',
      personality: 'driven',
      motivation: 'Make the team and prove I belong here.',
    });
    setPhase('loading');
    return null;
  }

  return (
    <div style={styles.root}>
      <div style={styles.bg} />
      {/* Ridgehawks emblem placeholder */}
      <div style={styles.logoMark}>
        <svg viewBox="0 0 100 100" style={{ width: 90, height: 90 }}>
          <circle cx="50" cy="50" r="46" fill="none" stroke="#d4a843" strokeWidth="2" />
          {/* simplified hawk silhouette */}
          <path d="M50 18 L60 40 L80 38 L65 50 L72 72 L50 58 L28 72 L35 50 L20 38 L40 40 Z" fill="#0a1628" stroke="#d4a843" strokeWidth="1.5" />
          <text x="50" y="90" textAnchor="middle" fill="#d4a843" fontSize="8" fontFamily="Georgia, serif" fontWeight="bold">RIDGEHAWKS</text>
        </svg>
      </div>

      <h1 style={styles.title}>THE U</h1>
      <p style={styles.subtitle}>Arrive at North Valley State. Decide who you're going to become.</p>

      <div style={styles.menu}>
        <button style={styles.primaryBtn} onClick={() => setPhase('creator')}>
          New Game
        </button>
        <button style={styles.secondaryBtn} onClick={() => {}}>
          Settings
        </button>
      </div>

      <p style={styles.footer}>v0.1.0 — Milestone: Week 1</p>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  root: {
    position: 'absolute',
    inset: 0,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#f0ece0',
    overflow: 'hidden',
    fontFamily: "'Georgia', 'Times New Roman', serif",
  },
  bg: {
    position: 'absolute',
    inset: 0,
    background:
      'radial-gradient(ellipse at center, #142240 0%, #0a0e1a 60%, #050810 100%)',
    zIndex: -1,
  },
  logoMark: {
    marginBottom: 12,
    opacity: 0.9,
    filter: 'drop-shadow(0 0 20px rgba(212, 168, 67, 0.3))',
  },
  title: {
    fontSize: 'clamp(48px, 12vw, 110px)',
    fontWeight: 700,
    letterSpacing: '0.15em',
    color: '#f0ece0',
    margin: 0,
    textShadow: '0 2px 40px rgba(0,0,0,0.6)',
  },
  subtitle: {
    fontSize: 'clamp(14px, 2vw, 18px)',
    color: '#a09880',
    marginTop: 8,
    marginBottom: 48,
    fontStyle: 'italic',
    letterSpacing: '0.05em',
  },
  menu: {
    display: 'flex',
    flexDirection: 'column',
    gap: 14,
    width: 240,
  },
  primaryBtn: {
    padding: '14px 0',
    fontSize: 18,
    fontWeight: 600,
    fontFamily: 'inherit',
    color: '#0a0e1a',
    background: 'linear-gradient(135deg, #f0d070, #d4a843)',
    borderRadius: 6,
    border: 'none',
    letterSpacing: '0.1em',
    boxShadow: '0 4px 20px rgba(212, 168, 67, 0.3)',
    transition: 'transform 0.15s',
  },
  secondaryBtn: {
    padding: '12px 0',
    fontSize: 15,
    fontFamily: 'inherit',
    color: '#a09880',
    background: 'rgba(255,255,255,0.05)',
    borderRadius: 6,
    border: '1px solid rgba(255,255,255,0.1)',
    letterSpacing: '0.08em',
    transition: 'all 0.15s',
  },
  footer: {
    position: 'absolute',
    bottom: 20,
    color: '#4a4840',
    fontSize: 12,
    letterSpacing: '0.1em',
  },
};

/**
 * ui/CharacterCreator.tsx — character identity + appearance creation.
 * Multi-step flow: name/pronouns -> appearance -> identity -> motivation.
 */
import React, { useState, useMemo } from 'react';
import { useGameStore, PlayerProfile } from '../store/gameStore';

const SKIN_TONES = ['#f5d0a0', '#e0b080', '#c09060', '#a07040', '#805830', '#603e20'];
const HAIR_COLORS = ['#1a1008', '#3a2818', '#6b3a18', '#a05a20', '#c8a040', '#808080', '#c84040'];
const HAIR_STYLES = ['Buzz', 'Short', 'Medium', 'Long', 'Tied', 'Curly', 'Fade'];
const BODY_TYPES = ['slim', 'athletic', 'muscular'] as const;
const ATHLETIC_BGS = [
  { id: 'basketball', label: 'Basketball' },
  { id: 'track', label: 'Track' },
  { id: 'swimming', label: 'Swimming' },
  { id: 'none', label: 'No sport' },
] as const;
const ACAD = [
  { id: 'math', label: 'Math' },
  { id: 'writing', label: 'Writing' },
  { id: 'science', label: 'Science' },
  { id: 'arts', label: 'Arts' },
] as const;
const PERSONALITIES = [
  { id: 'confident', label: 'Confident', desc: 'You walk into a room and people notice.' },
  { id: 'quiet', label: 'Quiet', desc: 'You watch first. Speak second.' },
  { id: 'charming', label: 'Charming', desc: 'People like you before you earn it.' },
  { id: 'driven', label: 'Driven', desc: 'You came here with a plan.' },
] as const;

export const CharacterCreator = () => {
  const createPlayer = useGameStore((s) => s.createPlayer);
  const setPhase = useGameStore((s) => s.setPhase);
  const [step, setStep] = useState(0);
  const [profile, setProfile] = useState<Partial<PlayerProfile>>({
    name: '',
    pronouns: 'he',
    skinTone: 3,
    face: 0,
    hairStyle: 1,
    hairColor: 1,
    bodyType: 'athletic',
    clothing: { top: 0, bottom: 0, shoes: 0, accessory: 0 },
    athleticBackground: 'basketball',
    academicStrength: 'math',
    personality: 'confident',
    motivation: '',
  });

  const canAdvance = useMemo(() => {
    if (step === 0) return (profile.name?.trim().length ?? 0) >= 2;
    if (step === 4) return (profile.motivation?.trim().length ?? 0) >= 5;
    return true;
  }, [step, profile]);

  const handleFinalize = () => {
    const p = profile as PlayerProfile;
    createPlayer(p);
    setPhase('loading');
  };

  return (
    <div style={s.root}>
      <div style={s.card}>
        <div style={s.header}>
          <h2 style={s.stepTitle}>{['Your Name', 'Your Appearance', 'Your Identity', 'Your Personality', 'Why Are You Here?'][step]}</h2>
          <div style={s.dots}>
            {[0,1,2,3,4].map((d) => (
              <div key={d} style={{ ...s.dot, opacity: d === step ? 1 : 0.3, background: d === step ? '#d4a843' : '#a09880' }} />
            ))}
          </div>
        </div>

        <div style={s.body}>
          {step === 0 && (
            <div>
              <label style={s.label}>First Name</label>
              <input
                style={s.input}
                value={profile.name}
                onChange={(e) => setProfile({ ...profile, name: e.target.value })}
                placeholder="Alex"
                maxLength={16}
                autoFocus
              />
              <label style={s.label}>Pronouns</label>
              <div style={s.row}>
                {(['he', 'she', 'they'] as const).map((p) => (
                  <button
                    key={p}
                    style={{ ...s.chip, ...(profile.pronouns === p ? s.chipActive : {}) }}
                    onClick={() => setProfile({ ...profile, pronouns: p })}
                  >
                    {p}
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 1 && (
            <div>
              <label style={s.label}>Skin Tone</label>
              <div style={s.row}>
                {SKIN_TONES.map((c, i) => (
                  <button
                    key={i}
                    style={{
                      ...s.swatch,
                      background: c,
                      outline: profile.skinTone === i ? '3px solid #d4a843' : '1px solid rgba(255,255,255,0.15)',
                    }}
                    onClick={() => setProfile({ ...profile, skinTone: i })}
                  />
                ))}
              </div>
              <label style={s.label}>Hair Color</label>
              <div style={s.row}>
                {HAIR_COLORS.map((c, i) => (
                  <button
                    key={i}
                    style={{
                      ...s.swatch,
                      background: c,
                      outline: profile.hairColor === i ? '3px solid #d4a843' : '1px solid rgba(255,255,255,0.15)',
                    }}
                    onClick={() => setProfile({ ...profile, hairColor: i })}
                  />
                ))}
              </div>
              <label style={s.label}>Hair Style</label>
              <div style={s.rowWrap}>
                {HAIR_STYLES.map((h, i) => (
                  <button
                    key={i}
                    style={{ ...s.chipSmall, ...(profile.hairStyle === i ? s.chipActive : {}) }}
                    onClick={() => setProfile({ ...profile, hairStyle: i })}
                  >
                    {h}
                  </button>
                ))}
              </div>
              <label style={s.label}>Build</label>
              <div style={s.row}>
                {BODY_TYPES.map((b) => (
                  <button
                    key={b}
                    style={{ ...s.chip, ...(profile.bodyType === b ? s.chipActive : {}) }}
                    onClick={() => setProfile({ ...profile, bodyType: b })}
                  >
                    {b}
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <label style={s.label}>Athletic Background</label>
              <div style={s.grid2}>
                {ATHLETIC_BGS.map((a) => (
                  <button
                    key={a.id}
                    style={{ ...s.cardOption, ...(profile.athleticBackground === a.id ? s.cardOptionActive : {}) }}
                    onClick={() => setProfile({ ...profile, athleticBackground: a.id })}
                  >
                    {a.label}
                  </button>
                ))}
              </div>
              <label style={s.label}>Academic Strength</label>
              <div style={s.grid2}>
                {ACAD.map((a) => (
                  <button
                    key={a.id}
                    style={{ ...s.cardOption, ...(profile.academicStrength === a.id ? s.cardOptionActive : {}) }}
                    onClick={() => setProfile({ ...profile, academicStrength: a.id })}
                  >
                    {a.label}
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <label style={s.label}>Personality</label>
              <div style={s.col}>
                {PERSONALITIES.map((p) => (
                  <button
                    key={p.id}
                    style={{ ...s.radioCard, ...(profile.personality === p.id ? s.radioCardActive : {}) }}
                    onClick={() => setProfile({ ...profile, personality: p.id })}
                  >
                    <div style={s.radioLabel}>{p.label}</div>
                    <div style={s.radioDesc}>{p.desc}</div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 4 && (
            <div>
              <label style={s.label}>What brought you to North Valley State?</label>
              <textarea
                style={s.textarea}
                value={profile.motivation}
                onChange={(e) => setProfile({ ...profile, motivation: e.target.value })}
                maxLength={160}
                placeholder="I want to make the team. I want to prove I belong here."
                rows={4}
              />
              <div style={s.counter}>{(profile.motivation ?? '').length}/160</div>
            </div>
          )}
        </div>

        <div style={s.footer}>
          <button
            style={{ ...s.btnSecondary, visibility: step === 0 ? 'hidden' : 'visible' }}
            onClick={() => setStep((v) => Math.max(0, v - 1))}
          >
            Back
          </button>
          {step < 4 ? (
            <button
              style={{ ...s.btnPrimary, opacity: canAdvance ? 1 : 0.5 }}
              disabled={!canAdvance}
              onClick={() => setStep((v) => v + 1)}
            >
              Next
            </button>
          ) : (
            <button
              style={{ ...s.btnPrimary, opacity: canAdvance ? 1 : 0.5, letterSpacing: '0.15em' }}
              disabled={!canAdvance}
              onClick={handleFinalize}
            >
              Arrive on Campus
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

const s: Record<string, React.CSSProperties> = {
  root: { position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'linear-gradient(180deg, #0a1628 0%, #0a0e1a 100%)' },
  card: { width: 'min(520px, 92vw)', background: 'rgba(10, 14, 26, 0.9)', border: '1px solid rgba(212, 168, 67, 0.3)', borderRadius: 16, padding: '32px 36px', boxShadow: '0 20px 60px rgba(0,0,0,0.5)', backdropFilter: 'blur(20px)' },
  header: { marginBottom: 24 },
  stepTitle: { color: '#f0ece0', fontSize: 24, margin: '0 0 16px', fontFamily: 'Georgia, serif' },
  dots: { display: 'flex', gap: 8 },
  dot: { width: 24, height: 4, borderRadius: 2, transition: 'all 0.3s' },
  body: { minHeight: 280 },
  label: { color: '#a09880', fontSize: 12, letterSpacing: '0.15em', textTransform: 'uppercase', display: 'block', marginBottom: 8, marginTop: 16 },
  input: { width: '100%', padding: '12px 14px', fontSize: 18, background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: 8, color: '#f0ece0', fontFamily: 'inherit', outline: 'none' },
  row: { display: 'flex', gap: 8, flexWrap: 'wrap' },
  rowWrap: { display: 'flex', flexWrap: 'wrap', gap: 8 },
  chip: { padding: '8px 16px', borderRadius: 20, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.15)', color: '#a09880', fontSize: 14, cursor: 'pointer', fontFamily: 'inherit' },
  chipActive: { background: 'rgba(212, 168, 67, 0.2)', borderColor: '#d4a843', color: '#f0d070' },
  chipSmall: { padding: '6px 12px', borderRadius: 16, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.15)', color: '#a09880', fontSize: 13 },
  swatch: { width: 36, height: 36, borderRadius: 18, cursor: 'pointer', padding: 0 },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 },
  cardOption: { padding: '14px 12px', borderRadius: 10, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.12)', color: '#a09880', fontSize: 14 },
  cardOptionActive: { background: 'rgba(212, 168, 67, 0.18)', borderColor: '#d4a843', color: '#f0d070' },
  col: { display: 'flex', flexDirection: 'column', gap: 10 },
  radioCard: { padding: '12px 16px', borderRadius: 10, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.12)', color: '#a09880', textAlign: 'left' },
  radioCardActive: { background: 'rgba(212, 168, 67, 0.15)', borderColor: '#d4a843' },
  radioLabel: { color: '#f0ece0', fontSize: 15, fontWeight: 600, marginBottom: 4 },
  radioDesc: { fontSize: 12, lineHeight: 1.4 },
  textarea: { width: '100%', padding: '12px 14px', fontSize: 15, background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: 8, color: '#f0ece0', fontFamily: 'inherit', outline: 'none', resize: 'vertical', minHeight: 100 },
  counter: { color: '#6a6660', fontSize: 12, textAlign: 'right', marginTop: 4 },
  footer: { display: 'flex', justifyContent: 'space-between', marginTop: 28 },
  btnPrimary: { padding: '12px 22px', fontSize: 15, fontWeight: 600, fontFamily: 'inherit', background: 'linear-gradient(135deg, #f0d070, #d4a843)', color: '#0a0e1a', borderRadius: 6, border: 'none', cursor: 'pointer', letterSpacing: '0.05em' },
  btnSecondary: { padding: '12px 22px', fontSize: 15, fontFamily: 'inherit', background: 'transparent', color: '#a09880', borderRadius: 6, border: '1px solid rgba(255,255,255,0.15)', cursor: 'pointer' },
};

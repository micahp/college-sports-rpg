// Global styles for The U — premium, branded, mobile-first.

export const styles = `
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Archivo:wght@700;800;900&display=swap');

  :root {
    --navy: #1F335C;
    --navy-deep: #14213d;
    --gold: #EBB84D;
    --gold-soft: #f5d78a;
    --ink: #101623;
    --paper: #f4f1ea;
    --muted: #8a94a8;
  }

  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }

  .u-root {
    position: fixed; inset: 0;
    font-family: 'Inter', system-ui, sans-serif;
    color: var(--paper);
    pointer-events: none;
  }
  .u-root > * { pointer-events: auto; }
  .u-canvas-layer { position: absolute; inset: 0; pointer-events: auto; }
  .u-ui-layer { position: absolute; inset: 0; pointer-events: none; display: flex; flex-direction: column; }
  .u-ui-layer > * { pointer-events: auto; }

  /* ---------- HUD ---------- */
  .u-hud {
    position: absolute; top: 0; left: 0; right: 0;
    display: flex; justify-content: space-between; align-items: flex-start;
    padding: max(12px, env(safe-area-inset-top)) max(16px, env(safe-area-inset-right)) 12px max(16px, env(safe-area-inset-left));
    pointer-events: none !important;
  }
  .u-hud > * { pointer-events: auto; }
  .u-clock {
    background: rgba(16, 22, 35, 0.72); backdrop-filter: blur(8px);
    border: 1px solid rgba(235, 184, 77, 0.35);
    border-radius: 12px; padding: 8px 14px;
  }
  .u-clock-day { font-family: 'Archivo'; font-weight: 800; font-size: 13px; letter-spacing: 0.08em; color: var(--gold); text-transform: uppercase; }
  .u-clock-period { font-size: 15px; font-weight: 600; }
  .u-energy {
    display: flex; align-items: center; gap: 8px;
    background: rgba(16, 22, 35, 0.72); backdrop-filter: blur(8px);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 999px; padding: 7px 14px 7px 10px;
  }
  .u-energy-bar { width: 90px; height: 8px; border-radius: 99px; background: rgba(255,255,255,0.14); overflow: hidden; }
  .u-energy-fill { height: 100%; border-radius: 99px; background: linear-gradient(90deg, #e0704f, var(--gold)); transition: width 0.4s ease; }
  .u-energy-icon { font-size: 13px; }

  /* ---------- Interaction prompt ---------- */
  .u-prompt {
    position: absolute; bottom: 132px; left: 50%; transform: translateX(-50%);
    background: rgba(16, 22, 35, 0.85); backdrop-filter: blur(10px);
    border: 1px solid var(--gold);
    border-radius: 999px; padding: 10px 22px;
    font-weight: 600; font-size: 15px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.45);
    animation: u-pulse 1.6s ease-in-out infinite;
    white-space: nowrap;
  }
  @keyframes u-pulse { 0%,100% { box-shadow: 0 8px 32px rgba(0,0,0,0.45), 0 0 0 0 rgba(235,184,77,0.4);} 50% { box-shadow: 0 8px 32px rgba(0,0,0,0.45), 0 0 0 10px rgba(235,184,77,0);} }

  /* ---------- Dialogue ---------- */
  .u-dialogue {
    position: absolute; left: 50%; transform: translateX(-50%);
    bottom: max(20px, env(safe-area-inset-bottom));
    width: min(680px, calc(100% - 32px));
    background: linear-gradient(160deg, rgba(20, 28, 46, 0.94), rgba(16, 22, 35, 0.96));
    backdrop-filter: blur(14px);
    border: 1px solid rgba(235, 184, 77, 0.4);
    border-radius: 20px;
    padding: 20px 22px;
    box-shadow: 0 24px 64px rgba(0,0,0,0.55);
    animation: u-rise 0.28s cubic-bezier(0.2, 0.9, 0.25, 1.2);
  }
  @keyframes u-rise { from { opacity: 0; transform: translateX(-50%) translateY(18px);} to { opacity: 1; transform: translateX(-50%) translateY(0);} }
  .u-dialogue-name {
    font-family: 'Archivo'; font-weight: 800; font-size: 13px;
    letter-spacing: 0.1em; text-transform: uppercase; color: var(--gold);
    margin-bottom: 8px;
  }
  .u-dialogue-text { font-size: 16.5px; line-height: 1.55; color: var(--paper); margin-bottom: 14px; white-space: pre-wrap; }
  .u-choices { display: flex; flex-direction: column; gap: 8px; }
  .u-choice {
    text-align: left; font-family: inherit;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 12px; padding: 12px 16px;
    color: var(--paper); font-size: 15px; font-weight: 600;
    cursor: pointer; transition: all 0.15s ease;
  }
  .u-choice:hover, .u-choice:focus-visible {
    background: rgba(235, 184, 77, 0.16);
    border-color: var(--gold);
    transform: translateX(4px);
    outline: none;
  }
  .u-choice:disabled { opacity: 0.45; cursor: not-allowed; transform: none; }
  .u-choice-reason { display: block; font-size: 12px; color: var(--muted); font-weight: 400; margin-top: 3px; }
  .u-continue {
    align-self: flex-end;
    background: var(--gold); color: var(--ink);
    border: none; border-radius: 999px;
    font-family: 'Archivo'; font-weight: 800; font-size: 14px;
    letter-spacing: 0.05em; padding: 10px 26px; cursor: pointer;
    transition: transform 0.15s ease, box-shadow 0.15s ease;
  }
  .u-continue:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(235,184,77,0.35); }

  /* ---------- Reaction effects ---------- */
  .u-effects { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 14px; }
  .u-effect {
    font-size: 12.5px; font-weight: 700;
    border-radius: 999px; padding: 4px 12px;
    background: rgba(255,255,255,0.08);
  }
  .u-effect.up { color: #7dd69a; }
  .u-effect.down { color: #e08080; }

  /* ---------- Beat card ---------- */
  .u-beat-wrap {
    position: absolute; inset: 0; display: flex;
    align-items: center; justify-content: center;
    background: radial-gradient(ellipse at center, rgba(10,14,24,0.55), rgba(10,14,24,0.88));
    backdrop-filter: blur(4px);
    animation: u-fade 0.3s ease;
  }
  @keyframes u-fade { from { opacity: 0; } to { opacity: 1; } }
  .u-beat {
    width: min(620px, calc(100% - 32px));
    background: linear-gradient(165deg, #1a2440, var(--ink));
    border: 1px solid rgba(235,184,77,0.45);
    border-radius: 24px; padding: 28px;
    box-shadow: 0 32px 80px rgba(0,0,0,0.6);
    animation: u-rise2 0.35s cubic-bezier(0.2, 0.9, 0.25, 1.15);
  }
  @keyframes u-rise2 { from { opacity: 0; transform: translateY(24px) scale(0.97);} to { opacity: 1; transform: none;} }
  .u-beat-period { font-family: 'Archivo'; font-weight: 800; font-size: 12px; letter-spacing: 0.14em; text-transform: uppercase; color: var(--gold); }
  .u-beat-title { font-family: 'Archivo'; font-weight: 900; font-size: 30px; margin: 6px 0 14px; }
  .u-beat-text { font-size: 15.5px; line-height: 1.65; color: #d8dce6; margin-bottom: 20px; white-space: pre-wrap; }

  /* ---------- Title screen ---------- */
  .u-title {
    position: absolute; inset: 0;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    background:
      radial-gradient(ellipse 80% 60% at 50% 110%, rgba(235,184,77,0.14), transparent),
      radial-gradient(ellipse 90% 70% at 50% -20%, rgba(31,51,92,0.9), transparent),
      linear-gradient(170deg, #0d1322, #101623 55%, #0a0e18);
  }
  .u-title-emblem { width: 130px; height: 130px; margin-bottom: 6px; filter: drop-shadow(0 12px 32px rgba(235,184,77,0.25)); }
  .u-title-word { font-family: 'Archivo'; font-weight: 900; font-size: clamp(56px, 11vw, 96px); letter-spacing: -0.02em; line-height: 1;
    background: linear-gradient(180deg, #fff 30%, var(--gold)); -webkit-background-clip: text; background-clip: text; color: transparent; }
  .u-title-sub { font-size: 15px; letter-spacing: 0.32em; text-transform: uppercase; color: var(--muted); margin: 10px 0 40px; font-weight: 600; }
  .u-menu { display: flex; flex-direction: column; gap: 12px; width: min(300px, 80vw); }
  .u-menu-btn {
    font-family: 'Archivo'; font-weight: 800; font-size: 17px; letter-spacing: 0.06em;
    padding: 15px; border-radius: 14px; cursor: pointer;
    border: 1px solid rgba(235,184,77,0.5); background: rgba(235,184,77,0.08); color: var(--paper);
    transition: all 0.16s ease; text-transform: uppercase;
  }
  .u-menu-btn:hover { background: var(--gold); color: var(--ink); transform: translateY(-2px); box-shadow: 0 10px 28px rgba(235,184,77,0.3); }
  .u-menu-btn.primary { background: var(--gold); color: var(--ink); }
  .u-menu-btn.primary:hover { box-shadow: 0 14px 36px rgba(235,184,77,0.45); }
  .u-menu-btn:disabled { opacity: 0.35; cursor: not-allowed; transform: none; }

  /* ---------- Character creation ---------- */
  .u-create {
    position: absolute; inset: 0; overflow-y: auto;
    display: flex; flex-direction: column; align-items: center;
    background: linear-gradient(170deg, #0d1322, #101623);
    padding: 40px 20px 60px; pointer-events: auto !important;
  }
  .u-create h1 { font-family: 'Archivo'; font-weight: 900; font-size: 32px; margin: 0 0 4px; }
  .u-create .sub { color: var(--muted); margin-bottom: 26px; font-size: 14px; }
  .u-field { width: min(460px, 92vw); margin-bottom: 22px; }
  .u-field label { display: block; font-family: 'Archivo'; font-weight: 800; font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--gold); margin-bottom: 10px; }
  .u-name-input {
    width: 100%; font-family: inherit; font-size: 17px; font-weight: 600;
    background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.18);
    border-radius: 12px; padding: 13px 16px; color: var(--paper); outline: none;
  }
  .u-name-input:focus { border-color: var(--gold); }
  .u-id-cards { display: flex; flex-direction: column; gap: 10px; }
  .u-id-card {
    text-align: left; font-family: inherit; cursor: pointer;
    background: rgba(255,255,255,0.05); border: 1.5px solid rgba(255,255,255,0.12);
    border-radius: 14px; padding: 15px 18px; color: var(--paper);
    transition: all 0.15s ease;
  }
  .u-id-card:hover { border-color: rgba(235,184,77,0.6); }
  .u-id-card.selected { border-color: var(--gold); background: rgba(235,184,77,0.1); box-shadow: 0 0 0 3px rgba(235,184,77,0.15); }
  .u-id-card .name { font-family: 'Archivo'; font-weight: 800; font-size: 16px; }
  .u-id-card .blurb { font-size: 13.5px; color: #b8bfce; margin-top: 4px; line-height: 1.45; }
  .u-id-card .fx { font-size: 12px; color: var(--gold-soft); margin-top: 6px; font-weight: 600; }

  /* ---------- Recap ---------- */
  .u-recap {
    position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    background: radial-gradient(ellipse at center, rgba(10,14,24,0.7), rgba(10,14,24,0.95));
  }
  .u-recap-card {
    width: min(560px, calc(100% - 32px));
    background: linear-gradient(165deg, #1a2440, var(--ink));
    border: 1px solid rgba(235,184,77,0.5); border-radius: 24px;
    padding: 30px; box-shadow: 0 32px 80px rgba(0,0,0,0.65);
  }
  .u-recap-card h2 { font-family: 'Archivo'; font-weight: 900; font-size: 26px; margin: 0 0 4px; }
  .u-recap-trait { color: var(--gold); font-weight: 700; font-size: 14px; margin-bottom: 18px; }
  .u-stat-rows { display: flex; flex-direction: column; gap: 10px; margin-bottom: 22px; }
  .u-stat-row { display: flex; align-items: center; gap: 12px; font-size: 14px; }
  .u-stat-row .lbl { width: 150px; color: #b8bfce; font-weight: 600; }
  .u-stat-row .bar { flex: 1; height: 8px; border-radius: 99px; background: rgba(255,255,255,0.1); overflow: hidden; }
  .u-stat-row .fill { height: 100%; border-radius: 99px; background: linear-gradient(90deg, var(--navy), var(--gold)); transition: width 0.6s ease; }
  .u-stat-row .val { width: 34px; text-align: right; font-weight: 700; }

  /* ---------- Joystick ---------- */
  .u-joystick {
    position: absolute; border-radius: 50%;
    width: 112px; height: 112px;
    background: rgba(255,255,255,0.07);
    border: 1.5px solid rgba(255,255,255,0.25);
    backdrop-filter: blur(4px);
    display: none;
  }
  .u-joystick-knob {
    position: absolute; width: 48px; height: 48px; border-radius: 50%;
    background: rgba(235,184,77,0.85);
    left: 32px; top: 32px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.4);
  }
  .u-joystick.active { display: block; }

  /* ---------- Objective toast ---------- */
  .u-objective {
    position: absolute; top: max(76px, calc(env(safe-area-inset-top) + 64px)); left: 50%; transform: translateX(-50%);
    background: rgba(16,22,35,0.8); backdrop-filter: blur(8px);
    border-left: 3px solid var(--gold);
    border-radius: 8px; padding: 10px 18px;
    font-size: 13.5px; font-weight: 600; color: #d8dce6;
    max-width: min(440px, 86vw); text-align: center;
    animation: u-fade 0.4s ease;
    pointer-events: none !important;
  }
  .u-objective b { color: var(--gold); }

  @media (max-width: 720px) and (orientation: landscape) {
    .u-dialogue { width: min(560px, calc(100% - 24px)); padding: 14px 18px; bottom: 10px; }
    .u-dialogue-text { font-size: 14.5px; margin-bottom: 10px; }
    .u-beat { padding: 20px; }
    .u-beat-title { font-size: 24px; }
    .u-beat-text { font-size: 14px; }
  }
`;

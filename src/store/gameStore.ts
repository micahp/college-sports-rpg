import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type GamePhase = 'menu' | 'creator' | 'loading' | 'playing';

export interface PlayerProfile {
  name: string;
  pronouns: 'he' | 'she' | 'they';
  skinTone: number;
  face: number;
  hairStyle: number;
  hairColor: number;
  bodyType: 'slim' | 'athletic' | 'muscular';
  clothing: {
    top: number;
    bottom: number;
    shoes: number;
    accessory: number;
  };
  athleticBackground: 'basketball' | 'track' | 'swimming' | 'none';
  academicStrength: 'math' | 'writing' | 'science' | 'arts';
  personality: 'confident' | 'quiet' | 'charming' | 'driven';
  motivation: string;
}

export interface PlayerStats {
  athletic: number;
  academic: number;
  social: number;
  confidence: number;
  energy: number;
  money: number;
  reputation: number;
}

export interface CharacterArc {
  id: string;
  name: string;
  relation: number; // -100 to 100
  trust: number;
  romance: number;
  history: string[];
  flags: Record<string, boolean>;
}

export interface GameState {
  phase: GamePhase;
  day: number; // 1-28 (4 weeks)
  hour: number; // 0-23
  minute: number;
  weather: 'clear' | 'cloudy' | 'rain' | 'snow';
  player: PlayerProfile | null;
  stats: PlayerStats;
  relationships: Record<string, CharacterArc>;
  location: string;
  activeQuest: string | null;
  flags: Record<string, boolean>;
  decisions: Array<{ day: number; hour: number; choice: string; outcome: string }>;
  ui: {
    phoneOpen: boolean;
    mapOpen: boolean;
    inventoryOpen: boolean;
    dialogueActive: boolean;
    dialogueTarget: string | null;
    notification: string | null;
    paused: boolean;
    basketballMode: boolean;
    basketballDrill: 'free' | 'spot' | 'freeThrow' | 'tryout' | null;
  };
  basketball: {
    shotsTaken: number;
    shotsMade: number;
    score: number;
    streak: number;
  };

  // actions
  setPhase: (p: GamePhase) => void;
  createPlayer: (profile: PlayerProfile) => void;
  advanceTime: (minutes: number) => void;
  setTime: (hour: number, minute: number) => void;
  setDay: (day: number) => void;
  travelTo: (location: string) => void;
  modifyStat: (stat: keyof PlayerStats, delta: number) => void;
  setStat: (stat: keyof PlayerStats, value: number) => void;
  updateRelationship: (id: string, changes: Partial<CharacterArc>) => void;
  setFlag: (key: string, value: boolean) => void;
  recordDecision: (choice: string, outcome: string) => void;
  openPhone: () => void;
  closePhone: () => void;
  openMap: () => void;
  closeMap: () => void;
  openInventory: () => void;
  closeInventory: () => void;
  startDialogue: (target: string) => void;
  endDialogue: () => void;
  notify: (msg: string | null) => void;
  setPaused: (p: boolean) => void;

  // Basketball
  enterBasketballMode: (drill: 'free' | 'spot' | 'freeThrow' | 'tryout' | null) => void;
  exitBasketballMode: () => void;
  onScore: () => void;
  onShotEnd: () => void;
  resetBasketball: () => void;
  saveGame: () => void;
  loadGame: () => boolean;
  reset: () => void;
}

const initialStats: PlayerStats = {
  athletic: 45,
  academic: 50,
  social: 40,
  confidence: 50,
  energy: 80,
  money: 200,
  reputation: 30,
};

const initialState = {
  phase: 'menu' as GamePhase,
  day: 1,
  hour: 7,
  minute: 30,
  weather: 'clear' as const,
  player: null,
  stats: initialStats,
  relationships: {},
  location: 'dorm-exterior',
  activeQuest: null,
  flags: {},
  decisions: [],
  ui: {
    phoneOpen: false,
    mapOpen: false,
    inventoryOpen: false,
    dialogueActive: false,
    dialogueTarget: null,
    notification: null,
    paused: false,
    basketballMode: false,
    basketballDrill: null,
  },
  basketball: {
    shotsTaken: 0,
    shotsMade: 0,
    score: 0,
    streak: 0,
  },
};

export const useGameStore = create<GameState>()(
  persist(
    (set) => ({
      ...initialState,

      setPhase: (p) => set({ phase: p }),

      createPlayer: (profile) =>
        set((state) => ({
          player: profile,
          stats: {
            ...initialStats,
            athletic:
              profile.athleticBackground === 'basketball'
                ? 60
                : profile.athleticBackground === 'none'
                ? 35
                : 50,
            academic:
              profile.academicStrength === 'math'
                ? 60
                : profile.academicStrength === 'writing'
                ? 55
                : profile.academicStrength === 'science'
                ? 58
                : 52,
            confidence: profile.personality === 'confident' ? 65 : profile.personality === 'quiet' ? 35 : 50,
          },
          flags: { ...state.flags, createdPlayer: true },
        })),

      advanceTime: (minutes) =>
        set((state) => {
          let hour = state.hour;
          let minute = state.minute + minutes;
          let day = state.day;
          while (minute >= 60) {
            minute -= 60;
            hour++;
          }
          while (hour >= 24) {
            hour -= 24;
            day++;
          }
          return { hour, minute, day };
        }),

      setTime: (hour, minute) => set({ hour, minute }),
      setDay: (day) => set({ day }),

      travelTo: (location) =>
        set((state) => ({
          location,
          decisions: [
            ...state.decisions,
            { day: state.day, hour: state.hour, choice: `traveled to ${location}`, outcome: '' },
          ],
        })),

      modifyStat: (stat, delta) =>
        set((state) => ({
          stats: { ...state.stats, [stat]: clamp(state.stats[stat] + delta, 0, 100) },
        })),

      setStat: (stat, value) =>
        set((state) => ({
          stats: { ...state.stats, [stat]: clamp(value, 0, 100) },
        })),

      updateRelationship: (id, changes) =>
        set((state) => {
          const existing = state.relationships[id] || {
            id,
            name: id,
            relation: 0,
            trust: 0,
            romance: 0,
            history: [],
            flags: {},
          };
          return {
            relationships: {
              ...state.relationships,
              [id]: { ...existing, ...changes },
            },
          };
        }),

      setFlag: (key, value) =>
        set((state) => ({ flags: { ...state.flags, [key]: value } })),

      recordDecision: (choice, outcome) =>
        set((state) => ({
          decisions: [
            ...state.decisions,
            { day: state.day, hour: state.hour, choice, outcome },
          ],
        })),

      openPhone: () => set((s) => ({ ui: { ...s.ui, phoneOpen: true } })),
      closePhone: () => set((s) => ({ ui: { ...s.ui, phoneOpen: false } })),
      openMap: () => set((s) => ({ ui: { ...s.ui, mapOpen: true } })),
      closeMap: () => set((s) => ({ ui: { ...s.ui, mapOpen: false } })),
      openInventory: () => set((s) => ({ ui: { ...s.ui, inventoryOpen: true } })),
      closeInventory: () => set((s) => ({ ui: { ...s.ui, inventoryOpen: false } })),
      startDialogue: (target) =>
        set((s) => ({
          ui: { ...s.ui, dialogueActive: true, dialogueTarget: target, paused: true },
        })),
      endDialogue: () =>
        set((s) => ({
          ui: { ...s.ui, dialogueActive: false, dialogueTarget: null, paused: false },
        })),
      notify: (msg) => set((s) => ({ ui: { ...s.ui, notification: msg } })),
      setPaused: (p) => set((s) => ({ ui: { ...s.ui, paused: p } })),

      // Basketball
      enterBasketballMode: (drill) =>
        set((s) => ({
          ui: { ...s.ui, basketballMode: true, basketballDrill: drill, paused: false },
        })),
      exitBasketballMode: () =>
        set((s) => ({
          ui: { ...s.ui, basketballMode: false, basketballDrill: null },
        })),
      onScore: () =>
        set((s) => ({
          basketball: {
            ...s.basketball,
            shotsMade: s.basketball.shotsMade + 1,
            score: s.basketball.score + 2 + s.basketball.streak,
            streak: s.basketball.streak + 1,
          },
        })),
      onShotEnd: () =>
        set((s) => ({
          basketball: {
            ...s.basketball,
            shotsTaken: s.basketball.shotsTaken + 1,
            streak: 0,
          },
        })),
      resetBasketball: () =>
        set({
          basketball: { shotsTaken: 0, shotsMade: 0, score: 0, streak: 0 },
        }),

      saveGame: () => {
        // persisted automatically
      },
      loadGame: () => {
        return true;
      },
      reset: () => set({ ...initialState }),
    }),
    {
      name: 'the-u-save',
      partialize: (state) => ({
        day: state.day,
        hour: state.hour,
        minute: state.minute,
        weather: state.weather,
        player: state.player,
        stats: state.stats,
        relationships: state.relationships,
        flags: state.flags,
        decisions: state.decisions,
        activeQuest: state.activeQuest,
      }),
    }
  )
);

function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v));
}

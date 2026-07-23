import { describe, it, expect, beforeEach } from 'vitest';
import { useGame, applyEffects, saveGame, hasSave, loadGame, restoreGame } from '../src/game/store';

// Reset store between tests
beforeEach(() => {
  useGame.getState().reset();
});

describe('applyEffects', () => {
  it('clamps stats to 0-100', () => {
    const r = applyEffects(
      { energy: 5, academics: 50, athleticism: 50, basketball_skill: 50, roommate_relationship: 50, coach_interest: 50 },
      { energy: -20, basketball_skill: 60 },
    );
    expect(r.energy).toBe(0);
    expect(r.basketball_skill).toBe(100);
  });

  it('rounds stat values to integers', () => {
    const r = applyEffects(
      { energy: 50, academics: 50, athleticism: 50, basketball_skill: 50, roommate_relationship: 50, coach_interest: 50 },
      { energy: 3.7 },
    );
    expect(r.energy).toBe(54);
  });
});

describe('game flow', () => {
  it('starts on title screen', () => {
    expect(useGame.getState().phase).toBe('title');
  });

  it('newGame transitions to create', () => {
    useGame.getState().newGame();
    expect(useGame.getState().phase).toBe('create');
  });

  it('character creation sets identity and stats', () => {
    const { newGame, setIdentity, setPlayerName, startPlay } = useGame.getState();
    newGame();
    setIdentity('workhorse', { basketball_skill: 6, athleticism: 4, energy: -5 });
    setPlayerName('Alex');
    expect(useGame.getState().stats.basketball_skill).toBe(56);
    expect(useGame.getState().stats.energy).toBe(65);
    startPlay();
    expect(useGame.getState().phase).toBe('play');
  });

  it('completing a beat advances state correctly', () => {
    const { newGame, setIdentity, setPlayerName, startPlay, showBeat, chooseBeatOption, dismissReaction } = useGame.getState();
    newGame();
    setIdentity('workhorse', {});
    setPlayerName('Alex');
    startPlay();

    // Simulate first beat
    const beat = {
      id: 'morning_arrival',
      period: 'morning' as const,
      title: 'Move-In Day',
      text: 'Test',
      choices: [{
        id: 'c1', label: 'Test', tags: ['social'],
        effects: { roommate_relationship: 10, energy: -5 },
        reaction: 'Nice one.',
      }],
    };
    showBeat(beat);
    chooseBeatOption(beat, beat.choices[0]);
    expect(useGame.getState().phase).toBe('reaction');
    expect(useGame.getState().stats.roommate_relationship).toBe(60);
    expect(useGame.getState().completedBeats).toContain('morning_arrival');

    dismissReaction();
    expect(useGame.getState().phase).toBe('play');
  });

  it('all 4 beats lead to tryout phase', () => {
    const state = useGame.getState();
    state.newGame();
    state.setIdentity('workhorse', {});
    state.setPlayerName('Alex');
    state.startPlay();

    // Complete 4 beats
    for (const id of ['morning_arrival', 'afternoon_path', 'evening_coach', 'night_choice']) {
      const beat = {
        id, period: 'morning' as const, title: 'T', text: 'T',
        choices: [{ id: 'c', label: 'X', tags: [], effects: {}, reaction: '.' }],
      };
      state.showBeat(beat);
      state.chooseBeatOption(beat, beat.choices[0]);
      state.dismissReaction();
    }
    expect(useGame.getState().phase).toBe('tryout');
  });

  it('tryout result transitions to recap', () => {
    useGame.getState().setTryoutResult(4, 5, 'good');
    const s = useGame.getState();
    expect(s.phase).toBe('recap');
    expect(s.tryoutMade).toBe(4);
    expect(s.tryoutGrade).toBe('good');
  });

  it('reset clears everything and deletes save', () => {
    const state = useGame.getState();
    state.newGame();
    state.reset();
    expect(useGame.getState().phase).toBe('title');
    expect(useGame.getState().completedBeats).toHaveLength(0);
  });
});

describe('save/load', () => {
  it('saveGame and hasSave work', () => {
    useGame.getState().setPlayerName('Test Player');
    useGame.getState().signedUp = true;
    saveGame();
    expect(hasSave()).toBe(true);

    const data = loadGame();
    expect(data?.playerName).toBe('Test Player');
    expect(data?.signedUp).toBe(true);
  });

  it('restoreGame restores play state', () => {
    useGame.getState().setPlayerName('Saved');
    useGame.getState().signedUp = true;
    saveGame();

    useGame.getState().reset();
    // reset clears localStorage, so re-save after reset
    useGame.getState().setPlayerName('Saved');
    useGame.getState().signedUp = true;
    saveGame();
    restoreGame();
    expect(useGame.getState().phase).toBe('play');
    expect(useGame.getState().playerName).toBe('Saved');
    expect(useGame.getState().signedUp).toBe(true);
  });
});

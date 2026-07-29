/**
 * narrative.ts — Week 1 story beats for The U.
 *
 * All 1 scripted moments from arrival through the tryout outcome. Beats are data-driven:
 * the narrative engine reads the current day/hour/position, fires the beat when its trigger
 * condition is met, plays its dialogue, and applies consequences (stat changes, flags,
 * relationship adjustments). Outcome branches on accumulated stats + decisions + relationships.
 *
 * Beats MUST be ordered chronologically (the engine iterates them in array order and
 * expects day N beats before day N+1 beats).
 */

// ---------------------------------------------------------------------------
// Beat / consequence types
// ---------------------------------------------------------------------------

export type StatKey = 'athletic' | 'academic' | 'social' | 'confidence' | 'energy' | 'money' | 'reputation';

export type RelationshipKey = 'jordan' | 'marcus' | 'coachriley' | 'tyrell' | 'elena';

export interface Consequence {
  statChanges?: Partial<Record<StatKey, number>>;
  flags?: Record<string, boolean>;
  relationshipChanges?: Partial<Record<RelationshipKey, { relation?: number; trust?: number; romance?: number }>>;
  decision?: { id: string; prompt: string; options: { label: string; consequence: Consequence }[] };
  travelTo?: string;
  notify?: string;
}

export interface StoryBeat {
  id: string;
  /** Day + hour window when this beat can fire. */
  day: number;
  hour: number;
  /** Latest hour the beat can fire (inclusive). Leave = hour for an exact moment. */
  hourEnd?: number;
  /** Location id the player must be at, or 'any' if location-independent. */
  location: string;
  /** Additional condition that must be true for the beat to fire. */
  trigger?: { flag?: string; statGte?: Partial<Record<StatKey, number>>; relationshipGte?: Partial<Record<RelationshipKey, number>> };
  /** Dialogue file id to play when this beat fires. */
  dialogueId: string;
  /** Consequences applied after the dialogue completes. */
  consequence: Consequence;
  /** If true, the beat fires only once across the whole game run. */
  once?: boolean;
  /** Description — purely documentary; not read by the engine. */
  description: string;
}

// ---------------------------------------------------------------------------
// The 19 beats — in chronological order
// ---------------------------------------------------------------------------

export const WEEK1_BEATS: StoryBeat[] = [
  // --- Day 1: Arrival ---
  {
    id: 'beat-arrival',
    day: 1,
    hour: 8,
    location: 'dorm-exterior',
    dialogueId: 'arrival-01',
    consequence: { flags: { arrived: true }, notify: 'Welcome to North Valley State.' },
    once: true,
    description: 'Player steps out of the car, sees the dorm for the first time.',
  },
  {
    id: 'beat-dorm-dropoff',
    day: 1,
    hour: 9,
    location: 'dorm-room',
    dialogueId: 'arrival-02',
    consequence: {
      statChanges: { confidence: 2 },
      flags: { unpacked: false },
      notify: 'Find your room — Ridgeview Hall.',
    },
    once: true,
    description: 'Player enters the dorm room, drops bags, the room feels small.',
  },
  {
    id: 'beat-meet-marcus',
    day: 1,
    hour: 10,
    location: 'dorm-room',
    trigger: { flag: 'arrived' },
    dialogueId: 'marcus-intro',
    consequence: {
      statChanges: { social: 5 },
      relationshipChanges: { marcus: { relation: 15, trust: 10 } },
      flags: { metMarcus: true },
      decision: {
        id: 'marcus-choice',
        prompt: 'Marcus asks what youre hoping to get out of freshman year.',
        options: [
          { label: 'Make the team. Consequences matter.', consequence: { statChanges: { confidence: 3 }, relationshipChanges: { marcus: { trust: 5 } }, flags: { wantsBall: true } } },
          { label: 'Honestly? Figure myself out.', consequence: { statChanges: { confidence: 1 }, relationshipChanges: { marcus: { relation: 5 } }, flags: { introspective: true } } },
        ],
      },
    },
    once: true,
    description: 'Marcus Chen claims the left side and becomes the first familiar face.',
  },
  {
    id: 'beat-explore-quad',
    day: 1,
    hour: 12,
    location: 'quad',
    trigger: { flag: 'metMarcus' },
    dialogueId: 'explore-quad',
    consequence: {
      statChanges: { social: 3 },
      flags: { exploredQuad: true },
      notify: 'The quad is buzzing. Get your bearings.',
    },
    once: true,
    description: 'Player walks the Founders Quad, absorbs campus life.',
  },
  {
    id: 'beat-meet-jordan',
    day: 1,
    hour: 15,
    location: 'quad',
    trigger: { flag: 'exploredQuad' },
    dialogueId: 'jordan-intro',
    consequence: {
      statChanges: { social: 5, confidence: 2 },
      relationshipChanges: { jordan: { relation: 18, trust: 8 } },
      flags: { metJordan: true },
      decision: {
        id: 'jordan-meet',
        prompt: 'Jordan asks if youve found the rec center yet.',
        options: [
          { label: 'Yeah — checking it out later.', consequence: { relationshipChanges: { jordan: { relation: 5 } }, flags: { JordanKnowsRec: true } } },
          { label: 'Not yet. Want to show me?', consequence: { relationshipChanges: { jordan: { relation: 10, romance: 5 } }, flags: { jordanShowedRec: true } } },
        ],
      },
    },
    once: true,
    description: 'Jordan Hayes notices the new face and strikes up a conversation.',
  },
  {
    id: 'beat-orientation',
    day: 1,
    hour: 17,
    location: 'student-union',
    trigger: { flag: 'metJordan' },
    dialogueId: 'orientation-evening',
    consequence: {
      statChanges: { academic: 2, social: 2 },
      flags: { didOrientation: true },
      notify: 'Orientation tonight. Student Union at 5pm.',
    },
    once: true,
    description: 'Evening orientation — campus resources, academic expectations, a first intro to basketball.',
  },

  // --- Day 2: Discovery ---
  {
    id: 'beat-discover-basketball',
    day: 2,
    hour: 10,
    location: 'rec-gym',
    trigger: { flag: 'didOrientation' },
    dialogueId: 'discover-hoop',
    consequence: {
      statChanges: { athletic: 6, confidence: 4 },
      flags: { foundBasketball: true },
      notify: 'The gym feels like home. The ball is lighter here.',
    },
    once: true,
    description: 'Player wanders into the rec gym — the bounce of a ball, the sound of the net.',
  },
  {
    id: 'beat-solo-shooting',
    day: 2,
    hour: 12,
    location: 'basketball-gym',
    trigger: { flag: 'foundBasketball' },
    dialogueId: 'solo-shooting',
    consequence: {
      statChanges: { athletic: 4, confidence: 2, energy: -5 },
      flags: { didSoloShooting: true },
      notify: 'The gym is empty. Just you and the net.',
    },
    once: true,
    description: 'Player returns to the practice gym alone for a self-guided shooting session — the first real sign of hunger.',
  },
  {
    id: 'beat-meet-coach',
    day: 2,
    hour: 14,
    location: 'athletic-offices',
    trigger: { flag: 'foundBasketball', statGte: { athletic: 45 } },
    dialogueId: 'coach-riley-intro',
    consequence: {
      statChanges: { confidence: 2 },
      relationshipChanges: { coachriley: { relation: 10, trust: 5 } },
      flags: { metCoach: true },
      decision: {
        id: 'coach-impress',
        prompt: 'Coach Riley asks why a freshman is hanging around the offices.',
        options: [
          { label: 'I want to walk on. What do I need to show you?', consequence: { relationshipChanges: { coachriley: { relation: 10, trust: 5 } }, statChanges: { confidence: 3 }, flags: { askedToWalkOn: true } } },
          { label: 'Just getting familiar with the program.', consequence: { relationshipChanges: { coachriley: { relation: 3 } }, flags: { cautiousWithCoach: true } } },
        ],
      },
    },
    once: true,
    description: 'Coach Riley looks up from film and decides whether the kid is worth a conversation.',
  },
  {
    id: 'beat-first-class',
    day: 3,
    hour: 9,
    location: 'main-classroom',
    trigger: { flag: 'metCoach' },
    dialogueId: 'first-class',
    consequence: {
      statChanges: { academic: 5 },
      relationshipChanges: { elena: { relation: 8, trust: 5 } },
      flags: { attendedFirstClass: true, metElena: true },
      notify: 'Professor Reyes does not waste time. First essay assigned.',
    },
    once: true,
    description: 'First lecture with Elena Reyes. The bar is set on day one.',
  },

  // --- Days 3-4: Study / Train fork ---
  {
    id: 'beat-study-neglect-decision',
    day: 3,
    hour: 18,
    location: 'any',
    trigger: { flag: 'attendedFirstClass' },
    dialogueId: 'study-or-train',
    consequence: {
      decision: {
        id: 'train-vs-study',
        prompt: 'Its Sunday night. Essay due tomorrow. The gym is open until 10.',
        options: [
          { label: 'Lock in. Paper comes first.', consequence: { statChanges: { academic: 8, energy: -5 }, flags: { prioritizedStudy: true }, relationshipChanges: { elena: { trust: 5 } } } },
          { label: 'Gym hits hard. Paper after.', consequence: { statChanges: { athletic: 8, academic: -3, energy: -10 }, flags: { prioritizedTrain: true }, relationshipChanges: { coachriley: { relation: 5 } } } },
        ],
      },
    },
    once: true,
    description: 'The first real fork — academic discipline or athletic hunger.',
  },
  {
    id: 'beat-meet-tyrell',
    day: 4,
    hour: 15,
    location: 'basketball-gym',
    trigger: { flag: 'foundBasketball' },
    dialogueId: 'tyrell-intro',
    consequence: {
      statChanges: { confidence: -2 },
      relationshipChanges: { tyrell: { relation: 8, trust: 2 } },
      flags: { metTyrell: true },
      notify: 'Tyrell Banks is exactly as advertised.',
    },
    once: true,
    description: 'On the practice court, Tyrell Banks shows what top-of-the-conference looks like.',
  },

  // --- Days 4-6: Social events ---
  {
    id: 'beat-social-event',
    day: 4,
    hour: 21,
    location: 'student-union',
    trigger: { flag: 'metTyrell' },
    dialogueId: 'social-night',
    consequence: {
      statChanges: { social: 6, confidence: 3 },
      relationshipChanges: { jordan: { relation: 8 }, marcus: { trust: 5 } },
      flags: { didSocial: true },
      notify: 'You make real connections tonight. The campus feels a little smaller.',
    },
    once: true,
    description: 'A late-night student union run-in with Jordan and Marcus. Walls come down.',
  },
  {
    id: 'beat-big-decision',
    day: 5,
    hour: 12,
    location: 'any',
    trigger: { flag: 'metCoach' },
    dialogueId: 'walk-on-decision',
    consequence: {
      decision: {
        id: 'walk-on-commit',
        prompt: 'Coach Riley says theres one walk-on spot open. Your call by Friday.',
        options: [
          { label: 'Im in. Whatever it takes.', consequence: { statChanges: { athletic: 5, confidence: 5 }, flags: { committedWalkOn: true }, relationshipChanges: { coachriley: { trust: 10 } } } },
          { label: 'I need to think about my grades.', consequence: { statChanges: { academic: 3 }, flags: { deferredWalkOn: true }, relationshipChanges: { coachriley: { relation: -5 } } } },
        ],
      },
    },
    once: true,
    description: 'The moment of commitment — or the moment of hesitation.',
  },

  // --- Days 5-6: Practice grind ---
  {
    id: 'beat-first-practice',
    day: 5,
    hour: 17,
    location: 'basketball-gym',
    trigger: { flag: 'committedWalkOn' },
    dialogueId: 'first-practice',
    consequence: {
      statChanges: { athletic: 10, confidence: 3, energy: -15 },
      relationshipChanges: { coachriley: { relation: 5 }, tyrell: { trust: 5 } },
      flags: { didFirstPractice: true },
      notify: 'Day one of tryouts conditioning. Youre not alone in this gym.',
    },
    once: true,
    description: 'First real walk-on conditioning session under Coach Riley.',
  },
  {
    id: 'beat-extra-work',
    day: 6,
    hour: 10,
    location: 'rec-gym',
    trigger: { flag: 'didFirstPractice' },
    dialogueId: 'extra-work',
    consequence: {
      statChanges: { athletic: 6, energy: -8 },
      relationshipChanges: { coachriley: { trust: 5 }, jordan: { relation: 5 } },
      flags: { putInExtraWork: true },
      notify: 'Nobody asked you to be here at 10am on a Saturday. Coach noticed.',
    },
    once: true,
    description: 'Optional early grind — the player puts in extra reps while others sleep.',
  },
  {
    id: 'beat-tyrell-showdown',
    day: 6,
    hour: 18,
    location: 'basketball-gym',
    trigger: { flag: 'metTyrell' },
    dialogueId: 'tyrell-scrimmage',
    consequence: {
      statChanges: { athletic: 4, confidence: 2 },
      relationshipChanges: { tyrell: { relation: 5, trust: 8 } },
      flags: { playedTyrell: true },
      notify: 'Tyrell respects the effort. Thats not nothing.',
    },
    once: true,
    description: 'An impromptu one-on-one with Tyrell reveals how far there is to go.',
  },

  // --- Day 7: Tryout + outcome ---
  {
    id: 'beat-tryout',
    day: 7,
    hour: 15,
    location: 'basketball-gym',
    trigger: { flag: 'committedWalkOn' },
    dialogueId: 'tryout',
    consequence: {
      statChanges: { energy: -20, confidence: 5 },
      flags: { didTryout: true },
      notify: 'Tryout day. Leave everything on the court.',
    },
    once: true,
    description: 'The walk-on tryout — everything built so far comes to bear.',
  },
  {
    id: 'beat-outcome',
    day: 7,
    hour: 20,
    location: 'any',
    trigger: { flag: 'didTryout' },
    dialogueId: 'tryout-result',
    consequence: {
      // Outcome is computed dynamically by the narrative engine at resolve-time;
      // statChanges are stamped in by evaluateOutcome() based on accumulated state.
      flags: { week1Complete: true },
    },
    once: true,
    description: 'Coach Riley delivers the verdict.',
  },
];

// ---------------------------------------------------------------------------
// Outcome evaluation
// ---------------------------------------------------------------------------

export interface OutcomeResult {
  id: string;
  title: string;
  description: string;
  statChanges: Partial<Record<string, number>>;
  flags: Record<string, boolean>;
  notify: string;
}

/**
 * Evaluate the tryout outcome based on accumulated stats, decisions, and relationships.
 * Called by the narrative engine when beat-outcome fires.
 *
 * Three tiers:
 *  - 'Made the team': high athletic + consistent training + coach trust + extra work
 *  - 'Waitlist': decent showing but a gap somewhere — academic risk or coach distrust
 *  - 'Cut': not enough signal that this player belongs
 */
export function evaluateOutcome(stats: Record<string, number>, flags: Record<string, boolean>, relationships: Record<string, { trust?: number; relation?: number }>): OutcomeResult {
  const athletic = stats.athletic ?? 0;
  const academic = stats.academic ?? 0;
  const confidence = stats.confidence ?? 0;
  const coachTrust = relationships.coachriley?.trust ?? 0;
  const coachRel = relationships.coachriley?.relation ?? 0;
  const extraWork = flags.putInExtraWork ? 10 : 0;
  const didSocial = flags.didSocial ? 5 : 0;
  const prioritizedTrain = flags.prioritizedTrain ? 8 : 0;
  const prioritizedStudy = flags.prioritizedStudy ? 5 : 0;

  const score = athletic * 0.4 + confidence * 0.2 + coachTrust * 0.25 + coachRel * 0.15 + extraWork + didSocial + prioritizedTrain;

  if (score >= 85) {
    return {
      id: 'outcome-made-team',
      title: 'You made it.',
      description: 'Coach Riley nods once. Thats his standing ovation. The roster spot is yours — and the real work starts now.',
      statChanges: { athletic: 5, confidence: 10, reputation: 15 },
      flags: { madeTeam: true },
      notify: 'Walk-on spot secured. Welcome to the Ridgehawks.',
    };
  }
  if (score >= 60) {
    return {
      id: 'outcome-waitlist',
      title: 'Not a no.',
      description: 'You showed enough. Coach says hell keep you on the practice roster — train with the team, prove it for real next week.',
      statChanges: { athletic: 3, reputation: 5 },
      flags: { waitlisted: true },
      notify: 'Practice roster. Show Coach Riley it was the right call.',
    };
  }
  return {
    id: 'outcome-cut',
    title: 'This time, no.',
    description: 'Its not the end of the road — but it is the end of this road. Coach Riley says youre not where you need to be. Yet.',
    statChanges: { confidence: -5, reputation: -5 },
    flags: { cutFromTeam: true },
    notify: 'Cut from tryouts. The season is long — this isnt over.',
  };
}

/** Convenience: find a beat by id. */
export function getBeatById(id: string): StoryBeat | undefined {
  return WEEK1_BEATS.find((b) => b.id === id);
}

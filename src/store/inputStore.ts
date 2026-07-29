import { create } from 'zustand';

export interface InputState {
  // movement axes (-1 to 1)
  moveX: number;
  moveY: number;
  // look axes
  lookX: number;
  lookY: number;
  // buttons
  sprint: boolean;
  interact: boolean;
  // touch state
  joystick: { x: number; y: number; active: boolean };
  lookTouch: { deltaX: number; deltaY: number; active: boolean };
  // keyboard state map (codes)
  keys: Record<string, boolean>;

  setMove: (x: number, y: number) => void;
  setLook: (x: number, y: number) => void;
  setSprint: (v: boolean) => void;
  setInteract: (v: boolean) => void;
  setJoystick: (x: number, y: number, active: boolean) => void;
  setLookTouch: (dx: number, dy: number, active: boolean) => void;
  setKey: (code: string, pressed: boolean) => void;
}

export const useInputStore = create<InputState>((set) => ({
  moveX: 0,
  moveY: 0,
  lookX: 0,
  lookY: 0,
  sprint: false,
  interact: false,
  joystick: { x: 0, y: 0, active: false },
  lookTouch: { deltaX: 0, deltaY: 0, active: false },
  keys: {},

  setMove: (x, y) => set({ moveX: x, moveY: y }),
  setLook: (x, y) => set({ lookX: x, lookY: y }),
  setSprint: (v) => set({ sprint: v }),
  setInteract: (v) => set({ interact: v }),
  setJoystick: (x, y, active) => set({ joystick: { x, y, active } }),
  setLookTouch: (deltaX, deltaY, active) => set({ lookTouch: { deltaX, deltaY, active } }),
  setKey: (code, pressed) =>
    set((s) => ({ keys: { ...s.keys, [code]: pressed } })),
}));

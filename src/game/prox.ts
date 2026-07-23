import { create } from 'zustand';

// Proximity + conversation state shared between the 3D scene and the HTML UI.
interface ProxState {
  nearNpc: string | null;
  talkingTo: string | null;
  setNearNpc: (id: string | null) => void;
  setTalkingTo: (id: string | null) => void;
}

export const useProx = create<ProxState>((set) => ({
  nearNpc: null,
  talkingTo: null,
  setNearNpc: (id) => set({ nearNpc: id }),
  setTalkingTo: (id) => set({ talkingTo: id }),
}));

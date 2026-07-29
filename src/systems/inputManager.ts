/**
 * systems/inputManager.ts — wires keyboard, mouse, touch to inputStore.
 * Import once in Game.tsx (or App root) to activate.
 * Exposes an attach function that registers window listeners.
 */
import { useInputStore } from '../store/inputStore';

let attached = false;

export function attachInputManager() {
  if (attached) return;
  attached = true;

  const store = useInputStore;

  // Keyboard
  const onKeyDown = (e: KeyboardEvent) => {
    if (e.repeat) return;
    const s = store.getState();
    s.setKey(e.code, true);

    switch (e.code) {
      case 'KeyW':
      case 'ArrowUp':
        s.setMove(s.moveX, -1);
        break;
      case 'KeyS':
      case 'ArrowDown':
        s.setMove(s.moveX, 1);
        break;
      case 'KeyA':
      case 'ArrowLeft':
        s.setMove(-1, s.moveY);
        break;
      case 'KeyD':
      case 'ArrowRight':
        s.setMove(1, s.moveY);
        break;
      case 'ShiftLeft':
      case 'ShiftRight':
        s.setSprint(true);
        break;
      case 'KeyE':
      case 'Space':
        s.setInteract(true);
        break;
      case 'Tab':
        e.preventDefault();
        break;
    }
  };

  const onKeyUp = (e: KeyboardEvent) => {
    const s = store.getState();
    s.setKey(e.code, false);

    // Recompute axes from currently-held keys (robust to ordering)
    const keys = s.keys;
    let x = 0;
    let y = 0;
    if (keys['KeyW'] || keys['ArrowUp']) y -= 1;
    if (keys['KeyS'] || keys['ArrowDown']) y += 1;
    if (keys['KeyA'] || keys['ArrowLeft']) x -= 1;
    if (keys['KeyD'] || keys['ArrowRight']) x += 1;
    s.setMove(x, y);

    if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') s.setSprint(false);
    if (e.code === 'KeyE' || e.code === 'Space') s.setInteract(false);
  };

  // Attach to both window AND document for maximum compatibility
  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', onKeyUp);
  document.addEventListener('keydown', onKeyDown);
  document.addEventListener('keyup', onKeyUp);

  // Mouse look
  let mouseDown = false;
  const onMouseDown = (e: MouseEvent) => {
    if ((e.target as HTMLElement)?.closest('button')) return;
    mouseDown = true;
  };
  const onMouseUp = () => { mouseDown = false; };
  const onMouseMove = (e: MouseEvent) => {
    if (!mouseDown) return;
    store.getState().setLook(e.movementX, e.movementY);
  };
  window.addEventListener('mousedown', onMouseDown);
  window.addEventListener('mouseup', onMouseUp);
  window.addEventListener('mousemove', onMouseMove);

  // Cleanup on reload (not really needed for SPA but nice)
  return () => {
    window.removeEventListener('keydown', onKeyDown);
    window.removeEventListener('keyup', onKeyUp);
    document.removeEventListener('keydown', onKeyDown);
    document.removeEventListener('keyup', onKeyUp);
    window.removeEventListener('mousedown', onMouseDown);
    window.removeEventListener('mouseup', onMouseUp);
    window.removeEventListener('mousemove', onMouseMove);
    attached = false;
  };
}

// ---------------------------------------------------------------------------
// Touch helpers used by Joystick component and look-drag layer
// ---------------------------------------------------------------------------
export function isTouchDevice() {
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
}

/**
 * ui/MobileControls.tsx — virtual joystick + look-drag for touch devices.
 * Renders only on touch devices. Writes to inputStore.
 */
import React, { useRef, useState } from 'react';
import { useInputStore } from '../store/inputStore';
import { isTouchDevice } from '../systems/inputManager';

export const MobileControls = () => {
  const [joystickActive, setJoystickActive] = useState(false);
  const [stick, setStick] = useState({ x: 28, y: 28 }); // position within base (0..56)
  const baseRef = useRef<HTMLDivElement>(null);

  if (!isTouchDevice()) return null;

  const handleJoystickStart = (e: React.TouchEvent) => {
    e.stopPropagation();
    setJoystickActive(true);
    handleJoystickMove(e);
  };

  const handleJoystickMove = (e: React.TouchEvent) => {
    if (!baseRef.current) return;
    const rect = baseRef.current.getBoundingClientRect();
    const touch = e.touches[0];
    const x = Math.max(0, Math.min(56, touch.clientX - rect.left - 28));
    const y = Math.max(0, Math.min(56, touch.clientY - rect.top - 28));
    setStick({ x, y });
    const nx = x / 28 - 1; // -1..1
    const ny = y / 28 - 1;
    useInputStore.getState().setMove(-nx, ny);
  };

  const handleJoystickEnd = () => {
    setJoystickActive(false);
    setStick({ x: 28, y: 28 });
    useInputStore.getState().setMove(0, 0);
  };

  // Look area on the right side of screen
  const lookStart = (e: React.TouchEvent) => {
    const t = e.touches[0];
    lookState.current.startX = t.clientX;
    lookState.current.startY = t.clientY;
    lookState.current.active = true;
  };
  const lookState = useRef({ startX: 0, startY: 0, active: false });
  const lookMove = (e: React.TouchEvent) => {
    if (!lookState.current.active) return;
    const t = e.touches[0];
    const dx = t.clientX - lookState.current.startX;
    const dy = t.clientY - lookState.current.startY;
    lookState.current.startX = t.clientX;
    lookState.current.startY = t.clientY;
    useInputStore.getState().setLook(dx, dy);
  };
  const lookEnd = () => {
    lookState.current.active = false;
  };

  return (
    <>
      {/* Joystick base (bottom-left) */}
      <div
        ref={baseRef}
        onTouchStart={handleJoystickStart}
        onTouchMove={handleJoystickMove}
        onTouchEnd={handleJoystickEnd}
        style={{
          position: 'absolute',
          bottom: 90,
          left: 30,
          width: 110,
          height: 110,
          borderRadius: 55,
          background: 'rgba(10, 22, 40, 0.6)',
          border: '2px solid rgba(212, 168, 67, 0.5)',
          touchAction: 'none',
          pointerEvents: 'auto',
        }}
      >
        {/* Stick */}
        <div
          style={{
            position: 'absolute',
            left: stick.x,
            top: stick.y,
            width: 56,
            height: 56,
            borderRadius: 28,
            background: joystickActive
              ? 'radial-gradient(circle, #f0d070, #d4a843)'
              : 'radial-gradient(circle, #d4a843, #a07820)',
            boxShadow: '0 4px 12px rgba(0,0,0,0.4)',
            transition: joystickActive ? 'none' : 'all 0.15s',
          }}
        />
      </div>

      {/* Look area (right half of screen) */}
      <div
        onTouchStart={lookStart}
        onTouchMove={lookMove}
        onTouchEnd={lookEnd}
        style={{
          position: 'absolute',
          top: 0,
          right: 0,
          width: '50%',
          height: '100%',
          touchAction: 'none',
          pointerEvents: 'auto',
        }}
      />

      {/* Action buttons (bottom-right, above phone) */}
      <div style={{ position: 'absolute', bottom: 90, right: 100, display: 'flex', gap: 10 }}>
        <button
          onTouchStart={() => useInputStore.getState().setInteract(true)}
          onTouchEnd={() => useInputStore.getState().setInteract(false)}
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            background: 'rgba(39, 174, 96, 0.7)',
            border: '2px solid rgba(39, 174, 96, 0.9)',
            color: '#fff',
            fontSize: 22,
            fontWeight: 700,
            pointerEvents: 'auto',
          }}
        >
          E
        </button>
        <button
          onTouchStart={() => useInputStore.getState().setSprint(true)}
          onTouchEnd={() => useInputStore.getState().setSprint(false)}
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            background: 'rgba(212, 168, 67, 0.7)',
            border: '2px solid rgba(212, 168, 67, 0.9)',
            color: '#0a0e1a',
            fontSize: 14,
            fontWeight: 700,
            pointerEvents: 'auto',
          }}
        >
          RUN
        </button>
      </div>
    </>
  );
};

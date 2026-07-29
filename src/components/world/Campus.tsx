/**
 * Campus.tsx — ground plane, walking paths, quad lawn, trees, benches, monument, boundaries.
 * Uses InstancedMesh for trees and benches (hundreds of instances, one draw call).
 */
import React, { useMemo, useRef } from 'react';
import * as THREE from 'three';
import { useFrame } from '@react-three/fiber';
import { Instances, Instance } from '@react-three/drei';

// ---------------------------------------------------------------------------
// Ground + Paths (single large mesh with vertex-colored zones)
// ---------------------------------------------------------------------------

function Ground() {
  const mesh = useMemo(() => {
    const geo = new THREE.PlaneGeometry(160, 120, 80, 60);
    geo.rotateX(-Math.PI / 2);

    // Zone coloring based on world position
    const pos = geo.attributes.position;
    const colors = new Float32Array(pos.count * 3);
    const grass = new THREE.Color('#3a6b28');
    const darkGrass = new THREE.Color('#2d5520');
    const concrete = new THREE.Color('#8a8478');
    const pathColor = new THREE.Color('#9a9078');
    const dirt = new THREE.Color('#6b5438');

    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);

      // Normalize into campus bounds [-80,80] x [-60,60]
      let c = grass.clone();

      // Mix two grass colors with noise for variation
      const n = Math.sin(x * 0.3) * Math.cos(z * 0.25) * 0.5 + 0.5;
      c.lerp(darkGrass, n * 0.4);

      // Quad lawn zone (center, x -30..30, z -10..30)
      const inQuad = Math.abs(x) < 30 && z > -10 && z < 30;
      if (inQuad) {
        const distToCenter = Math.sqrt(x * x + (z - 10) * (z - 10));
        c.lerp(new THREE.Color('#4a8030'), THREE.MathUtils.smoothstep(distToCenter, 40, 0));
      }

      // Concrete pad under buildings and plazas
      const buildingPads =
        (Math.abs(x + 20) < 12 && Math.abs(z - 30) < 10) || // dorm
        (Math.abs(x - 10) < 18 && Math.abs(z + 10) < 14) || // rec
        (Math.abs(x - 32) < 14 && Math.abs(z + 20) < 22) || // athletic
        (Math.abs(x + 10) < 12 && Math.abs(z + 15) < 10) || // stem
        (Math.abs(x + 25) < 8 && Math.abs(z + 20) < 12) || // arts
        (Math.abs(x - 22) < 14 && Math.abs(z - 15) < 12) || // dining
        (Math.abs(x - 5) < 16 && Math.abs(z - 20) < 12); // union

      if (buildingPads) {
        c.copy(concrete);
      }

      // Main diagonal path
      const onPath = Math.abs(x * 0.6 + z * 0.8) < 3 && z > -5 && z < 40;
      if (onPath) c.copy(pathColor);

      // Paths connecting to rec center
      const onRecPath =
        Math.abs(z + 10 - (x - 10) * 0.0) < 2.5 && x > -20 && x < 30 && z < 0;
      if (onRecPath) c.copy(pathColor);

      // Dirt/gravel around off-campus
      if (x < -35 && z > 25) c.copy(dirt);

      colors[i * 3] = c.r;
      colors[i * 3 + 1] = c.g;
      colors[i * 3 + 2] = c.b;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geo.computeVertexNormals();

    return geo;
  }, []);

  return (
    <mesh geometry={mesh} receiveShadow position={[0, 0.02, 10]}>
      <meshStandardMaterial vertexColors roughness={0.95} metalness={0} />
    </mesh>
  );
}

// ---------------------------------------------------------------------------
// Trees — InstancedMesh with slight per-instance scale + color variation
// ---------------------------------------------------------------------------
function Trees() {
  const trunk = useMemo(() => {
    const g = new THREE.CylinderGeometry(0.18, 0.28, 2.4, 6);
    g.translate(0, 1.2, 0);
    return g;
  }, []);

  const canopy = useMemo(() => {
    const g = new THREE.IcosahedronGeometry(1.6, 1);
    g.translate(0, 3.4, 0);
    return g;
  }, []);

  const trunkMat = useMemo(
    () => new THREE.MeshStandardMaterial({ color: '#5a3a22', roughness: 0.9 }),
    []
  );
  const canopyMat = useMemo(
    () => new THREE.MeshStandardMaterial({ color: '#2d5a1e', roughness: 0.85, flatShading: true }),
    []
  );

  // Scatter trees avoiding building footprints
  const positions = useMemo(() => {
    const list: { p: [number, number, number]; s: number }[] = [];
    const rng = mulberry32(42);
    let attempts = 0;
    while (list.length < 80 && attempts < 600) {
      attempts++;
      const x = (rng() - 0.5) * 130;
      const z = 5 + rng() * 40;
      // Avoid building footprints
      if (Math.abs(x + 20) < 16 && Math.abs(z - 30) < 14) continue;
      if (Math.abs(x - 10) < 20 && Math.abs(z + 10) < 16) continue;
      if (Math.abs(x - 32) < 16 && Math.abs(z + 20) < 24) continue;
      if (Math.abs(x + 10) < 14 && Math.abs(z + 15) < 12) continue;
      if (Math.abs(x + 25) < 10 && Math.abs(z + 20) < 14) continue;
      if (Math.abs(x - 22) < 16 && Math.abs(z - 15) < 14) continue;
      if (Math.abs(x - 5) < 18 && Math.abs(z - 20) < 14) continue;
      // Avoid quad center
      if (Math.abs(x) < 28 && z > -8 && z < 28) continue;
      list.push({ p: [x, 0, z], s: 0.8 + rng() * 0.6 });
    }
    return list;
  }, []);

  const trunkRef = useRef<THREE.InstancedMesh>(null);
  const canopyRef = useRef<THREE.InstancedMesh>(null);

  React.useEffect(() => {
    const dummy = new THREE.Object3D();
    positions.forEach((t, i) => {
      dummy.position.set(...t.p);
      dummy.scale.setScalar(t.s);
      dummy.rotation.y = i * 0.7;
      dummy.updateMatrix();
      trunkRef.current?.setMatrixAt(i, dummy.matrix);
      canopyRef.current?.setMatrixAt(i, dummy.matrix);
      // canopy color variation
      const colorVar = 0.85 + (i % 5) * 0.04;
      const col = new THREE.Color();
      col.setHSL(0.28 + (i % 3) * 0.02, 0.5 * colorVar, 0.22 * colorVar);
      canopyRef.current?.setColorAt(i, col);
    });
    if (trunkRef.current) trunkRef.current.instanceMatrix.needsUpdate = true;
    if (canopyRef.current) {
      canopyRef.current.instanceMatrix.needsUpdate = true;
      if (canopyRef.current.instanceColor) canopyRef.current.instanceColor.needsUpdate = true;
    }
  }, [positions]);

  return (
    <>
      <instancedMesh ref={trunkRef} args={[trunk, trunkMat, 80]} castShadow receiveShadow />
      <instancedMesh ref={canopyRef} args={[canopy, canopyMat, 80]} castShadow />
    </>
  );
}

// ---------------------------------------------------------------------------
// Benches
// ---------------------------------------------------------------------------
function Benches() {
  const frame = useMemo(() => new THREE.BoxGeometry(2, 0.06, 0.5), []);
  const legGeo = useMemo(() => new THREE.BoxGeometry(0.08, 0.4, 0.4), []);
  const seatMat = useMemo(() => new THREE.MeshStandardMaterial({ color: '#6b4226', roughness: 0.8 }), []);
  const legMat = useMemo(() => new THREE.MeshStandardMaterial({ color: '#222', roughness: 0.6, metalness: 0.4 }), []);

  const spots: [number, number, number, number][] = [
    [-5, 0, 18, 0],
    [8, 0, 22, Math.PI],
    [-15, 0, 5, Math.PI * 0.5],
    [15, 0, 8, Math.PI * 1.5],
    [25, 0, 2, 0],
    [-20, 0, 12, Math.PI * 0.25],
  ];

  return (
    <group>
      {spots.map((s, i) => (
        <group key={i} position={[s[0], s[1], s[2]]} rotation={[0, s[3], 0]}>
          <mesh geometry={frame} material={seatMat} position={[0, 0.5, 0]} castShadow />
          <mesh geometry={frame} material={seatMat} position={[0, 0.7, 0]} castShadow />
          <mesh geometry={legGeo} material={legMat} position={[-0.8, 0.25, 0]} />
          <mesh geometry={legGeo} material={legMat} position={[0.8, 0.25, 0]} />
        </group>
      ))}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Monument Sign (North Valley State)
// ---------------------------------------------------------------------------
function Monument() {
  return (
    <group position={[0, 0, 6]}>
      {/* base */}
      <mesh castShadow receiveShadow position={[0, 0.3, 0]}>
        <boxGeometry args={[4, 0.6, 1.2]} />
        <meshStandardMaterial color="#555" roughness={0.5} />
      </mesh>
      {/* pillars */}
      {[-1.2, 1.2].map((x) => (
        <mesh key={x} castShadow position={[x, 1.6, 0]}>
          <boxGeometry args={[0.25, 2, 0.25]} />
          <meshStandardMaterial color="#666" roughness={0.4} metalness={0.3} />
        </mesh>
      ))}
      {/* arch */}
      <mesh castShadow position={[0, 2.7, 0]}>
        <boxGeometry args={[3.2, 0.35, 0.3]} />
        <meshStandardMaterial color="#0a1628" roughness={0.3} metalness={0.5} />
      </mesh>
      {/* nvs letters (simple boxes) */}
      {[-0.9, 0, 0.9].map((x, i) => (
        <mesh key={i} position={[x, 2.7, 0.18]}>
          <boxGeometry args={[0.5, 0.45, 0.08]} />
          <meshStandardMaterial color="#d4a843" roughness={0.3} metalness={0.6} emissive="#d4a843" emissiveIntensity={0.15} />
        </mesh>
      ))}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Campus Storefront: Dining Hall Awning + Planters (simple but readable)
// ---------------------------------------------------------------------------
function Details() {
  return (
    <group>
      {/* Trash cans on quad */}
      {[[-10, 15], [12, 18], [-22, 8]].map(([x, z], i) => (
        <group key={`tc-${i}`} position={[x, 0, z]}>
          <mesh castShadow position={[0, 0.45, 0]}>
            <cylinderGeometry args={[0.3, 0.3, 0.9, 12]} />
            <meshStandardMaterial color="#3a7d3a" roughness={0.7} />
          </mesh>
          <mesh position={[0, 0.95, 0]}>
            <cylinderGeometry args={[0.32, 0.32, 0.08, 12]} />
            <meshStandardMaterial color="#2d5a2d" roughness={0.6} />
          </mesh>
        </group>
      ))}
      {/* Lamp posts on main path */}
      {[-20, -10, 0, 10, 20].map((x, i) => (
        <group key={`lp-${i}`} position={[x, 0, 2 - Math.abs(x) * 0.05]}>
          <mesh castShadow position={[0, 2, 0]}>
            <cylinderGeometry args={[0.06, 0.08, 4, 8]} />
            <meshStandardMaterial color="#222" metalness={0.5} roughness={0.5} />
          </mesh>
          <mesh position={[0, 4.1, 0]}>
            <sphereGeometry args={[0.25, 12, 12]} />
            <meshStandardMaterial
              color="#ffeebb"
              emissive="#ffcc44"
              emissiveIntensity={0}
              roughness={0.3}
            />
          </mesh>
        </group>
      ))}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Boundaries — low walls / hedges at the edge of playable space
// ---------------------------------------------------------------------------
function Boundaries() {
  return (
    <group>
      {/* front wall (south) */}
      <mesh position={[0, 0.5, 48]} receiveShadow>
        <boxGeometry args={[120, 1, 0.5]} />
        <meshStandardMaterial color="#6b5438" roughness={0.9} />
      </mesh>
      {/* left */}
      <mesh position={[-55, 0.5, 15]} receiveShadow>
        <boxGeometry args={[0.5, 1, 80]} />
        <meshStandardMaterial color="#6b5438" roughness={0.9} />
      </mesh>
      {/* right */}
      <mesh position={[55, 0.5, 15]} receiveShadow>
        <boxGeometry args={[0.5, 1, 80]} />
        <meshStandardMaterial color="#6b5438" roughness={0.9} />
      </mesh>
      {/* back */}
      <mesh position={[0, 0.5, -28]} receiveShadow>
        <boxGeometry args={[120, 1, 0.5]} />
        <meshStandardMaterial color="#6b5438" roughness={0.9} />
      </mesh>
    </group>
  );
}

// Compose
export const Campus = () => {
  return (
    <group>
      <Ground />
      <Trees />
      <Benches />
      <Monument />
      <Details />
      <Boundaries />
    </group>
  );
};

// ---------------------------------------------------------------------------
// utils
// ---------------------------------------------------------------------------
function mulberry32(a: number) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Fix: float32 array initializer


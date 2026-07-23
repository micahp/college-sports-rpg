import { useMemo } from 'react';
import * as THREE from 'three';
import { useTexture } from '@react-three/drei';

// North Valley State quad — art-directed, late-afternoon, dense but composed.
// Navy #1F335C + gold #EBB84D branding. Every element earns its place.

const NAVY = '#1F335C';
const GOLD = '#EBB84D';

export function Campus() {
  return (
    <group>
      <Ground />
      <RecCenter />
      <DormHall />
      <AcademicHall />
      <Trees />
      <PlazaProps />
      <BannerPoles />
      <Sky />
    </group>
  );
}

function Sky() {
  return (
    <>
      {/* warm sunset gradient sky */}
      <mesh scale={[100, 60, 1]} position={[0, 16, -30]}>
        <planeGeometry args={[1, 1]} />
        <shaderMaterial
          transparent
          depthWrite={false}
          uniforms={{ uTime: { value: 0 } }}
          vertexShader={/* glsl */ `
            varying vec2 vUv;
            void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
          `}
          fragmentShader={/* glsl */ `
            varying vec2 vUv;
            void main() {
              vec3 skyTop = vec3(0.31, 0.40, 0.62);
              vec3 skyMid = vec3(0.62, 0.42, 0.57);
              vec3 skyBot = vec3(0.96, 0.65, 0.38);
              float t = smoothstep(-0.05, 1.05, vUv.y);
              vec3 col = mix(skyBot, skyMid, smoothstep(0.0, 0.45, t));
              col = mix(col, skyTop, smoothstep(0.45, 1.0, t));
              gl_FragColor = vec4(col, 1.0);
            }
          `}
        />
      </mesh>
      {/* distant hill silhouette — closes the horizon */}
      <mesh position={[0, 0.2, -38]} scale={[70, 10, 1]}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial color="#7d8f6a" transparent opacity={0.55} depthWrite={false} />
      </mesh>
      {/* distant campus buildings — dark silhouette */}
      {[[-14, -37, 18, 6], [8, -36, 10, 5], [-5, -39, 14, 4]].map(([x, z, w, h], i) => (
        <mesh key={`dist-${i}`} position={[x, h / 2, z]} castShadow={false}>
          <boxGeometry args={[w, h, 2]} />
          <meshBasicMaterial color="#5a4a3a" transparent opacity={0.5} />
        </mesh>
      ))}
      <fog attach="fog" args={['#e0a860', 24, 90]} />
      <directionalLight
        position={[24, 12, 14]}
        intensity={2.6}
        color="#ffb855"
        castShadow
        shadow-mapSize={[2048, 2048]}
        shadow-camera-left={-40}
        shadow-camera-right={40}
        shadow-camera-top={40}
        shadow-camera-bottom={-40}
        shadow-radius={2}
      />
      <hemisphereLight args={['#f2c080', '#6b5340', 0.8]} />
      <ambientLight intensity={0.32} color="#ffd9b0" />
    </>
  );
}

function Ground() {
  return (
    <group>
      {/* warm campus lawn */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[120, 120]} />
        <meshStandardMaterial color="#7d8f6a" roughness={1} />
      </mesh>
      {/* main quad plaza — warm flagstone */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 0]} receiveShadow>
        <circleGeometry args={[15, 48]} />
        <meshStandardMaterial color="#c4b5a3" roughness={0.92} />
      </mesh>
      {/* inner ring accent */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, 0]} receiveShadow>
        <ringGeometry args={[13.2, 15, 48]} />
        <meshStandardMaterial color="#baaa8f" roughness={0.94} />
      </mesh>
      {/* crosswalks */}
      {[0, Math.PI / 2, Math.PI, -Math.PI / 2].map((r, i) => (
        <mesh key={`cw-${i}`} rotation={[-Math.PI / 2, 0, r]} position={[Math.sin(r) * 18, 0.04, Math.cos(r) * 18]} receiveShadow>
          <planeGeometry args={[3.5, 12]} />
          <meshStandardMaterial color="#8a7760" roughness={0.96} />
        </mesh>
      ))}
      {/* secondary paths */}
      {[-1.2, 1.2, 1.9, 4.3, -(1.2), -(4.3)].map((r, i) => (
        <mesh key={`sc-${i}`} rotation={[-Math.PI / 2, 0, r]} position={[Math.sin(r) * 22, 0.04, Math.cos(r) * 22]} receiveShadow>
          <planeGeometry args={[2.4, 10]} />
          <meshStandardMaterial color="#9c8b78" roughness={0.96} />
        </mesh>
      ))}
      {/* plaza brick sections */}
      {[[-5, 5], [5, -5], [-3, -8], [8, 3]].map(([x, z], i) => (
        <mesh key={`pl-${i}`} rotation={[-Math.PI / 2, 0, (i * 37) % 2 === 0 ? 0.3 : -0.3]} position={[x, 0.05, z]} receiveShadow>
          <planeGeometry args={[4.5, 3.5]} />
          <meshStandardMaterial color="#7d694f" roughness={0.97} />
        </mesh>
      ))}
      {/* grass edge tufts — soften the grass/plaza transition */}
      {Array.from({ length: 60 }, (_, i) => {
        const a = (i / 60) * Math.PI * 2 + 0.12;
        const r = 15.3 + (i % 3) * 0.5;
        return (
          <mesh key={`tuft-${i}`} position={[Math.cos(a) * r, 0.07, Math.sin(a) * r]} rotation={[-0.3, i * 0.4, 0.2]}>
            <planeGeometry args={[0.3 + (i % 4) * 0.15, 0.25]} />
            <meshStandardMaterial color="#8fa070" roughness={1} side={THREE.DoubleSide} transparent opacity={0.7} />
          </mesh>
        );
      })}
      {/* center emblem */}
      <EmblemDecal />
    </group>
  );
}

function EmblemDecal() {
  const tex = useTexture('assets/branding/decal_emblem.png');
  tex.colorSpace = THREE.SRGBColorSpace;
  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 0]}>
      <circleGeometry args={[4.5, 40]} />
      <meshStandardMaterial map={tex} transparent opacity={0.9} roughness={0.9} />
    </mesh>
  );
}

// Hero building: Recreation Center — where tryouts live.
function RecCenter() {
  return (
    <group position={[0, 0, -26]}>
      {/* main mass with concrete base */}
      <mesh position={[0, 5.3, 0]} castShadow receiveShadow>
        <boxGeometry args={[26, 9.4, 12]} />
        <meshStandardMaterial color="#8a7a68" roughness={0.9} />
      </mesh>
      {/* concrete foundation — grounds the building */}
      <mesh position={[0, 0.6, 0]} castShadow receiveShadow>
        <boxGeometry args={[27, 1.2, 13]} />
        <meshStandardMaterial color="#9c8f7d" roughness={0.95} />
      </mesh>
      {/* exterior wall seams — subtle vertical breaks */}
      {[-10, -5, 0, 5, 10].map((x) => (
        <mesh key={`seam-${x}`} position={[x, 5, 6.01]}>
          <boxGeometry args={[0.04, 7, 0.08]} />
          <meshStandardMaterial color="#7a6d5e" roughness={0.8} />
        </mesh>
      ))}
      {/* glass band */}
      <mesh position={[0, 3.2, 6.02]}>
        <boxGeometry args={[22, 3.4, 0.1]} />
        <meshStandardMaterial color="#2c3e50" roughness={0.15} metalness={0.6} />
      </mesh>
      {/* navy fascia + gold trim */}
      <mesh position={[0, 10.6, 0]} castShadow>
        <boxGeometry args={[27, 1.2, 13]} />
        <meshStandardMaterial color={NAVY} roughness={0.7} />
      </mesh>
      <mesh position={[0, 9.9, 6.1]}>
        <boxGeometry args={[26.2, 0.25, 0.2]} />
        <meshStandardMaterial color={GOLD} roughness={0.4} metalness={0.3} />
      </mesh>
      {/* recessed entrance alcove */}
      <group position={[0, 1.3, 6.05]}>
        {/* alcove cutout */}
        <mesh position={[0, 1.6, -0.6]}>
          <boxGeometry args={[5.6, 4.4, 1.2]} />
          <meshStandardMaterial color="#6a5a4e" roughness={0.92} />
        </mesh>
        {/* back wall of alcove */}
        <mesh position={[0, 1.7, -1.1]}>
          <boxGeometry args={[5.4, 4.2, 0.1]} />
          <meshStandardMaterial color="#544438" roughness={0.9} />
        </mesh>
        {/* warm interior glow at back of alcove */}
        <mesh position={[0, 1.7, -1.05]}>
          <boxGeometry args={[5.2, 3.8, 0.2]} />
          <meshStandardMaterial color="#ffe0a0" emissive="#ffc880" emissiveIntensity={0.5} roughness={0.5} />
        </mesh>
        {/* glass panels — pushed back in the recess */}
        {[-1.2, 0, 1.2].map((x) => (
          <mesh key={x} position={[x, 1.65, -0.55]}>
            <boxGeometry args={[1.15, 3.4, 0.04]} />
            <meshStandardMaterial color="#f4d098" roughness={0.1} metalness={0.3} emissive="#f4d098" emissiveIntensity={0.25} />
          </mesh>
        ))}
        {/* gold door trim */}
        <mesh position={[0, -0.25, -0.52]}>
          <boxGeometry args={[5.6, 0.18, 0.25]} />
          <meshStandardMaterial color={GOLD} roughness={0.4} metalness={0.3} />
        </mesh>
        {/* alcove ceiling — cast shadow from it */}
        <mesh position={[0, 3.9, -0.6]} castShadow>
          <boxGeometry args={[5.6, 0.2, 1.2]} />
          <meshStandardMaterial color="#6a5a4e" roughness={0.92} />
        </mesh>
      </group>
      <Banner text="REC CENTER" position={[0, 7.2, 6.15]} width={10} />
      {/* side banners */}
      <BannerTexture img="assets/branding/banner_rec.png" position={[-9, 6, 6.1]} />
      <BannerTexture img="assets/branding/banner_hawks.png" position={[9, 6, 6.1]} />
    </group>
  );
}

function DormHall() {
  return (
    <group position={[-28, 0, -4]} rotation={[0, Math.PI / 2.6, 0]}>
      <mesh position={[0, 6, 0]} castShadow receiveShadow>
        <boxGeometry args={[18, 12, 10]} />
        <meshStandardMaterial color="#96684f" roughness={0.95} />
      </mesh>
      {/* window grid */}
      {[-6, -2, 2, 6].map((x) =>
        [3, 6.5, 10].map((y) => (
          <mesh key={`${x}${y}`} position={[x, y, 5.05]}>
            <boxGeometry args={[1.8, 1.6, 0.1]} />
            <meshStandardMaterial color="#3a4a5e" roughness={0.2} metalness={0.5} emissive="#ffd9a0" emissiveIntensity={y === 6.5 ? 0.25 : 0.05} />
          </mesh>
        )),
      )}
      <Banner text="HARGROVE HALL" position={[0, 12.8, 5.2]} width={9} />
    </group>
  );
}

function AcademicHall() {
  return (
    <group position={[27, 0, -6]} rotation={[0, -Math.PI / 2.8, 0]}>
      <mesh position={[0, 5.5, 0]} castShadow receiveShadow>
        <boxGeometry args={[16, 11, 10]} />
        <meshStandardMaterial color="#7d6e5c" roughness={0.95} />
      </mesh>
      {/* colonnade */}
      {[-5.5, -1.8, 1.8, 5.5].map((x) => (
        <mesh key={x} position={[x, 2.6, 5.4]} castShadow>
          <cylinderGeometry args={[0.35, 0.4, 5.2, 10]} />
          <meshStandardMaterial color="#b0a48e" roughness={0.9} />
        </mesh>
      ))}
      <mesh position={[0, 5.6, 5.4]} castShadow>
        <boxGeometry args={[15, 1, 1.4]} />
        <meshStandardMaterial color="#b0a48e" roughness={0.9} />
      </mesh>
      <Banner text="MORENO HALL" position={[0, 6.4, 6.15]} width={8} />
    </group>
  );
}

function Trees() {
  const positions: [number, number][] = [
    [-14, -12], [14, -13], [-18, 6], [18, 7], [-10, 14], [11, 15], [-22, -14], [22, -15],
  ];
  return (
    <group>
      {positions.map(([x, z], i) => (
        <Tree key={i} x={x} z={z} s={0.9 + ((i * 37) % 10) / 25} />
      ))}
    </group>
  );
}

function Tree({ x, z, s }: { x: number; z: number; s: number }) {
  return (
    <group position={[x, 0, z]} scale={[s, s, s]}>
      <mesh position={[0, 1.4, 0]} castShadow>
        <cylinderGeometry args={[0.22, 0.34, 2.8, 8]} />
        <meshStandardMaterial color="#5d4a38" roughness={1} />
      </mesh>
      {[[0, 3.6, 0, 1.9], [0.9, 2.9, 0.4, 1.3], [-0.9, 3.1, -0.3, 1.25]].map(([cx, cy, cz, r], i) => (
        <mesh key={i} position={[cx, cy, cz]} castShadow>
          <sphereGeometry args={[r, 12, 10]} />
          <meshStandardMaterial color={i === 0 ? '#5f7a4a' : '#6c8754'} roughness={1} />
        </mesh>
      ))}
    </group>
  );
}

function PlazaProps() {
  return (
    <group>
      {/* benches ringing the plaza */}
      {[0.6, 1.5, 2.6, 3.7, 4.8, 5.7].map((a, i) => (
        <Bench key={i} angle={a} />
      ))}
      {/* club table with gold banner — move-in day energy */}
      <group position={[7, 0, 4]} rotation={[0, -0.7, 0]}>
        <mesh position={[0, 0.5, 0]} castShadow>
          <boxGeometry args={[2.4, 0.08, 1]} />
          <meshStandardMaterial color="#e8e2d4" roughness={0.8} />
        </mesh>
        {[[-1.05, -0.4], [1.05, -0.4], [-1.05, 0.4], [1.05, 0.4]].map(([x, z], i) => (
          <mesh key={i} position={[x, 0.23, z]}>
            <cylinderGeometry args={[0.03, 0.03, 0.46, 6]} />
            <meshStandardMaterial color="#8a8378" />
          </mesh>
        ))}
        <mesh position={[0, 0.52, 0.51]}>
          <boxGeometry args={[2.4, 0.5, 0.02]} />
          <meshStandardMaterial color={NAVY} roughness={0.8} />
        </mesh>
      </group>
      {/* bulletin board near Rec Center */}
      <group position={[3.5, 0, -11]} rotation={[0, -0.3, 0]}>
        <mesh position={[0, 2.3, 0]} castShadow>
          <boxGeometry args={[1.8, 2.8, 0.1]} />
          <meshStandardMaterial color="#5a4030" roughness={0.92} />
        </mesh>
        {[[-0.5, 3.0], [0.5, 2.5], [-0.3, 2.0], [0.4, 1.6]].map(([x, y], i) => (
          <mesh key={i} position={[x, y, 0.06]} rotation={[0, 0, (i - 1) * 0.15]}>
            <planeGeometry args={[0.65, 0.45]} />
            <meshStandardMaterial color={`hsl(${36 + i * 14}, 60%, ${82 + i * 4}%)`} side={THREE.DoubleSide} roughness={0.85} />
          </mesh>
        ))}
      </group>
      {/* trash cans */}
      {[[5, 1], [-6, -2], [12, -19]].map(([x, z], i) => (
        <mesh key={`trash-${i}`} position={[x, 0, z]} castShadow>
          <cylinderGeometry args={[0.18, 0.22, 0.8, 8]} />
          <meshStandardMaterial color="#5a554a" metalness={0.3} roughness={0.6} />
        </mesh>
      ))}
      {/* bikes parked near Hargrove */}
      <group position={[-22, 0, 2]} rotation={[0, 0.5, 0]}>
        {[[0, 0], [0.8, 0.15], [-0.7, 0.1]].map(([bx, bz], i) => (
          <group key={i} position={[bx, 0, bz]}>
            <mesh position={[0, 0.5, 0]} castShadow>
              <torusGeometry args={[0.55, 0.025, 6, 16]} />
              <meshStandardMaterial color="#3a3a3a" metalness={0.6} roughness={0.4} />
            </mesh>
            <mesh position={[0, 0.5, 0]}>
              <torusGeometry args={[0.55, 0.025, 6, 16]} />
              <meshStandardMaterial color="#3a3a3a" metalness={0.6} roughness={0.4} />
            </mesh>
            <mesh position={[0, 0.9, 0]}>
              <boxGeometry args={[0.6, 0.5, 0.03]} />
              <meshStandardMaterial color="#e8e2d4" roughness={0.6} />
            </mesh>
          </group>
        ))}
      </group>
    </group>
  );
}

function Bench({ angle }: { angle: number }) {
  const r = 13;
  const x = Math.sin(angle) * r;
  const z = Math.cos(angle) * r;
  return (
    <group position={[x, 0, z]} rotation={[0, angle + Math.PI / 2, 0]}>
      <mesh position={[0, 0.45, 0]} castShadow>
        <boxGeometry args={[2, 0.07, 0.55]} />
        <meshStandardMaterial color="#6e5744" roughness={0.9} />
      </mesh>
      <mesh position={[0, 0.72, -0.24]} castShadow>
        <boxGeometry args={[2, 0.5, 0.06]} />
        <meshStandardMaterial color="#6e5744" roughness={0.9} />
      </mesh>
      {[-0.8, 0.8].map((x) => (
        <mesh key={x} position={[x, 0.22, 0]}>
          <boxGeometry args={[0.08, 0.44, 0.5]} />
          <meshStandardMaterial color="#3d3a36" />
        </mesh>
      ))}
    </group>
  );
}

function BannerPoles() {
  return (
    <group>
      {[[-6, 10, 'theu'], [6, 10, 'hawks'], [-6, -8, 'club'], [6, -8, 'rec']].map(([x, z, b], i) => (
        <group key={i} position={[x as number, 0, z as number]}>
          <mesh position={[0, 2.6, 0]} castShadow>
            <cylinderGeometry args={[0.06, 0.08, 5.2, 8]} />
            <meshStandardMaterial color="#4a4a4a" metalness={0.5} roughness={0.5} />
          </mesh>
          <BannerTexture img={`assets/branding/banner_${b}.png`} position={[0, 4, 0]} />
        </group>
      ))}
    </group>
  );
}

function BannerTexture({ img, position }: { img: string; position: [number, number, number] }) {
  const tex = useTexture(img);
  tex.colorSpace = THREE.SRGBColorSpace;
  return (
    <mesh position={position} castShadow>
      <planeGeometry args={[1.6, 2.4]} />
      <meshStandardMaterial map={tex} side={THREE.DoubleSide} roughness={0.85} />
    </mesh>
  );
}

// Text banner using a generated canvas texture — crisp, branded, no font assets needed.
function Banner({ text, position, width }: { text: string; position: [number, number, number]; width: number }) {
  const texture = useMemo(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 1024;
    canvas.height = 160;
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = NAVY;
    ctx.fillRect(0, 0, 1024, 160);
    ctx.strokeStyle = GOLD;
    ctx.lineWidth = 6;
    ctx.strokeRect(10, 10, 1004, 140);
    ctx.fillStyle = GOLD;
    ctx.font = '700 72px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 512, 84);
    const t = new THREE.CanvasTexture(canvas);
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 4;
    return t;
  }, [text]);
  return (
    <mesh position={position}>
      <planeGeometry args={[width, width * 0.156]} />
      <meshStandardMaterial map={texture} roughness={0.8} />
    </mesh>
  );
}

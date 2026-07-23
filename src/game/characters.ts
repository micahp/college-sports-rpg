// Character design system for The U.
// Custom-built stylized characters — NOT asset-pack defaults.
// Each named character has a signature look: silhouette, palette, hair, accessories.
// Proportions: ~7 heads tall, slightly stylized. Fashionable, youthful, readable.

import * as THREE from 'three';

export interface CharacterSpec {
  skin: string;
  hairColor: string;
  hairStyle: 'fade' | 'curls' | 'ponytail' | 'bun' | 'braids' | 'waves' | 'short' | 'locs';
  top: string;          // shirt/jersey color
  topStyle: 'tee' | 'hoodie' | 'jersey' | 'tank' | 'jacket';
  bottoms: string;
  bottomsStyle: 'shorts' | 'joggers' | 'jeans' | 'leggings';
  shoes: string;
  accent: string;       // trim / accessory color
  accessory?: 'cap' | 'headband' | 'chain' | 'backpack' | 'none';
  build: 'athletic' | 'slim' | 'stocky';
}

// The cast — each visually distinctive at a glance.
export const CAST: Record<string, CharacterSpec> = {
  player: {
    skin: '#c68863',
    hairColor: '#1c1712',
    hairStyle: 'fade',
    top: '#1F335C', topStyle: 'tee',
    bottoms: '#3d4451', bottomsStyle: 'joggers',
    shoes: '#e8e6e1',
    accent: '#EBB84D',
    accessory: 'backpack',
    build: 'athletic',
  },
  jordan: {
    skin: '#8a5a3b',
    hairColor: '#0f0c09',
    hairStyle: 'curls',
    top: '#EBB84D', topStyle: 'jersey',       // gold Ridgehawks jersey — instantly readable
    bottoms: '#1F335C', bottomsStyle: 'shorts',
    shoes: '#d9d4c7',
    accent: '#1F335C',
    accessory: 'headband',
    build: 'athletic',
  },
  dee: {
    skin: '#b87a56',
    hairColor: '#2a1a12',
    hairStyle: 'ponytail',
    top: '#c94f6d', topStyle: 'tank',         // coral orientation-tee energy
    bottoms: '#2e3440', bottomsStyle: 'jeans',
    shoes: '#f0ede6',
    accent: '#f5d76e',
    accessory: 'none',
    build: 'slim',
  },
  coach: {
    skin: '#a5715a',
    hairColor: '#4a4a4a',
    hairStyle: 'short',
    top: '#232a36', topStyle: 'jacket',       // navy-black team-issued jacket
    bottoms: '#232a36', bottomsStyle: 'joggers',
    shoes: '#3a3a3a',
    accent: '#EBB84D',
    accessory: 'none',
    build: 'stocky',
  },
};

const M = (color: string, rough = 0.85, metal = 0) =>
  new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal });

// Build a stylized character mesh group from a spec.
// Returns a group ~1.75 units tall, origin at feet, facing +Z.
export function buildCharacter(spec: CharacterSpec): THREE.Group {
  const g = new THREE.Group();
  const build = spec.build;
  const shoulderW = build === 'stocky' ? 0.46 : build === 'athletic' ? 0.42 : 0.36;
  const hipW = build === 'stocky' ? 0.4 : 0.34;
  const bulk = build === 'stocky' ? 1.15 : build === 'athletic' ? 1.05 : 0.95;

  const skin = M(spec.skin);
  const hair = M(spec.hairColor, 0.6);
  const top = M(spec.top);
  const bottoms = M(spec.bottoms);
  const shoes = M(spec.shoes, 0.5);
  const accent = M(spec.accent, 0.6);

  const cast = (m: THREE.Mesh) => {
    m.castShadow = true;
    return m;
  };

  // ---- legs ----
  const legGeo = new THREE.CapsuleGeometry(0.075 * bulk, 0.62, 4, 10);
  for (const side of [-1, 1]) {
    const leg = cast(new THREE.Mesh(legGeo, bottoms));
    leg.position.set(side * hipW * 0.32, 0.44, 0);
    g.add(leg);

    const shoe = cast(new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.09, 0.24), shoes));
    shoe.position.set(side * hipW * 0.32, 0.045, 0.04);
    g.add(shoe);
  }

  // ---- shorts layer (over upper legs) ----
  if (spec.bottomsStyle === 'shorts') {
    const shorts = cast(new THREE.Mesh(new THREE.CylinderGeometry(hipW * 0.62, hipW * 0.68, 0.22, 12), bottoms));
    shorts.position.y = 0.72;
    g.add(shorts);
  }

  // ---- torso ----
  const torsoH = spec.topStyle === 'hoodie' || spec.topStyle === 'jacket' ? 0.52 : 0.48;
  const torsoGeo = new THREE.CapsuleGeometry(shoulderW * 0.5, torsoH - shoulderW * 0.5, 4, 12);
  const torso = cast(new THREE.Mesh(torsoGeo, top));
  torso.scale.set(1, 1, 0.72);
  torso.position.y = 0.78 + torsoH / 2;
  g.add(torso);

  // jersey number / accent stripe
  if (spec.topStyle === 'jersey') {
    const stripe = cast(new THREE.Mesh(new THREE.TorusGeometry(shoulderW * 0.42, 0.02, 6, 20), accent));
    stripe.rotation.x = Math.PI / 2;
    stripe.scale.set(1, 0.72, 1);
    stripe.position.y = 0.84;
    g.add(stripe);
  }
  if (spec.topStyle === 'hoodie' || spec.topStyle === 'jacket') {
    // hood / collar bulk
    const collar = cast(new THREE.Mesh(new THREE.TorusGeometry(0.11, 0.045, 8, 16), top));
    collar.rotation.x = Math.PI / 2;
    collar.position.y = 0.78 + torsoH + 0.02;
    g.add(collar);
  }

  // ---- arms ----
  const armGeo = new THREE.CapsuleGeometry(0.055 * bulk, 0.5, 4, 10);
  const sleeveGeo = new THREE.CapsuleGeometry(0.062 * bulk, spec.topStyle === 'tank' ? 0.05 : 0.2, 4, 10);
  for (const side of [-1, 1]) {
    const shoulder = new THREE.Group();
    shoulder.position.set(side * (shoulderW * 0.5 + 0.05), 0.78 + torsoH - 0.06, 0);

    const arm = cast(new THREE.Mesh(armGeo, skin));
    arm.position.y = -0.31;
    shoulder.add(arm);

    if (spec.topStyle !== 'tank') {
      const sleeve = cast(new THREE.Mesh(sleeveGeo, top));
      sleeve.position.y = -0.13;
      shoulder.add(sleeve);
    }

    shoulder.rotation.z = side * 0.12; // natural A-pose-ish hang
    g.add(shoulder);
  }

  // ---- head ----
  const headG = new THREE.Group();
  headG.position.y = 0.78 + torsoH + 0.16;

  const head = cast(new THREE.Mesh(new THREE.SphereGeometry(0.125, 20, 16), skin));
  head.scale.set(0.92, 1.05, 0.98);
  headG.add(head);

  // simple readable face: brow + eyes via small dark spheres
  const eyeMat = M('#1a1410', 0.4);
  for (const side of [-1, 1]) {
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.014, 8, 8), eyeMat);
    eye.position.set(side * 0.045, 0.01, 0.108);
    headG.add(eye);
  }

  // ---- hair (signature silhouettes) ----
  addHair(headG, spec.hairStyle, hair, accent, spec.accessory === 'headband');

  // ---- accessories ----
  if (spec.accessory === 'cap') {
    const cap = cast(new THREE.Mesh(new THREE.SphereGeometry(0.13, 16, 10, 0, Math.PI * 2, 0, Math.PI / 2), accent));
    cap.position.y = 0.045;
    headG.add(cap);
    const brim = cast(new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.14, 0.015, 12, 1, false, 0, Math.PI), accent));
    brim.position.set(0, 0.045, 0.12);
    headG.add(brim);
  }

  g.add(headG);

  if (spec.accessory === 'backpack') {
    const pack = cast(new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.34, 0.12), accent));
    pack.position.set(0, 0.78 + torsoH * 0.55, -0.19);
    g.add(pack);
    for (const side of [-1, 1]) {
      const strap = cast(new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.3, 0.02), accent));
      strap.position.set(side * 0.1, 0.78 + torsoH * 0.6, -0.1);
      g.add(strap);
    }
  }

  return g;
}

function addHair(
  headG: THREE.Group,
  style: CharacterSpec['hairStyle'],
  hair: THREE.Material,
  accent: THREE.Material,
  headband: boolean,
) {
  const cast = (m: THREE.Mesh) => {
    m.castShadow = true;
    return m;
  };
  switch (style) {
    case 'fade': {
      const top = cast(new THREE.Mesh(new THREE.SphereGeometry(0.128, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.45), hair));
      top.position.y = 0.018;
      top.scale.set(0.95, 0.8, 1);
      headG.add(top);
      break;
    }
    case 'curls': {
      // cluster of small spheres — distinctive Jordan silhouette
      const rng = mulberry(7);
      for (let i = 0; i < 14; i++) {
        const a = rng() * Math.PI * 2;
        const r = 0.05 + rng() * 0.075;
        const y = 0.05 + rng() * 0.09;
        const c = cast(new THREE.Mesh(new THREE.SphereGeometry(0.035 + rng() * 0.02, 8, 8), hair));
        c.position.set(Math.cos(a) * r, y, Math.sin(a) * r * 0.9 - 0.01);
        headG.add(c);
      }
      break;
    }
    case 'ponytail': {
      const capMesh = cast(new THREE.Mesh(new THREE.SphereGeometry(0.13, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.55), hair));
      capMesh.position.y = 0.01;
      headG.add(capMesh);
      const tail = cast(new THREE.Mesh(new THREE.CapsuleGeometry(0.045, 0.22, 4, 8), hair));
      tail.position.set(0, -0.02, -0.16);
      tail.rotation.x = 0.5;
      headG.add(tail);
      break;
    }
    case 'bun': {
      const capMesh = cast(new THREE.Mesh(new THREE.SphereGeometry(0.13, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.5), hair));
      capMesh.position.y = 0.012;
      headG.add(capMesh);
      const bun = cast(new THREE.Mesh(new THREE.SphereGeometry(0.06, 10, 10), hair));
      bun.position.set(0, 0.11, -0.06);
      headG.add(bun);
      break;
    }
    case 'braids':
    case 'locs': {
      const capMesh = cast(new THREE.Mesh(new THREE.SphereGeometry(0.13, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.5), hair));
      capMesh.position.y = 0.01;
      headG.add(capMesh);
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        const loc = cast(new THREE.Mesh(new THREE.CapsuleGeometry(0.016, 0.14, 3, 6), hair));
        loc.position.set(Math.cos(a) * 0.1, -0.03, Math.sin(a) * 0.1);
        headG.add(loc);
      }
      break;
    }
    case 'waves':
    case 'short':
    default: {
      const capMesh = cast(new THREE.Mesh(new THREE.SphereGeometry(0.128, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.52), hair));
      capMesh.position.y = 0.014;
      capMesh.scale.set(0.97, 0.9, 1);
      headG.add(capMesh);
      break;
    }
  }
  if (headband) {
    const band = cast(new THREE.Mesh(new THREE.TorusGeometry(0.122, 0.018, 6, 20), accent));
    band.rotation.x = Math.PI / 2;
    band.position.y = 0.045;
    headG.add(band);
  }
}

function mulberry(seed: number) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

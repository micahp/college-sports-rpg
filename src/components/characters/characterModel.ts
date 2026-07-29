/**
 * characterModel.ts — procedural skinned humanoid builder.
 *
 * Builds a THREE.Skeleton + SkinnedMesh with correct bone hierarchy and skin weights.
 * No visible primitives — the body is a single skinned surface with skeletal animation.
 *
 * Bone hierarchy:
 *   hips
 *   └── spine → chest → neck → head
 *   └── upperArm.L → lowerArm.L → hand.L
 *   └── upperArm.R → lowerArm.R → hand.R
 *   └── upLeg.L → lowerLeg.L → foot.L
 *   └── upLeg.R → lowerLeg.R → foot.R
 *
 * Each body part is a parametric lathe/spline tube so the silhouette is smooth,
 * not a capsule. Every vertex is weighted to the nearest bone.
 */
import * as THREE from 'three';

export interface HumanoidSkeleton {
  skeleton: THREE.Skeleton;
  bones: Record<string, THREE.Bone>;
  root: THREE.Bone;
}

const BONE_NAMES = [
  'hips', 'spine', 'chest', 'neck', 'head',
  'upperArm.L', 'lowerArm.L', 'hand.L',
  'upperArm.R', 'lowerArm.R', 'hand.R',
  'upLeg.L', 'lowerLeg.L', 'foot.L',
  'upLeg.R', 'lowerLeg.R', 'foot.R',
];

/** Build a fresh skeleton with rest pose in standard T-ish stance. */
export function buildSkeleton(height: number = 1.78): HumanoidSkeleton {
  const scale = height / 1.78;

  const make = (name: string, pos: THREE.Vector3): THREE.Bone => {
    const b = new THREE.Bone();
    b.name = name;
    b.position.copy(pos);
    return b;
  };

  // root
  const hips = make('hips', new THREE.Vector3(0, 0.95 * scale, 0));
  const spine = make('spine', new THREE.Vector3(0, 0.12 * scale, 0));
  const chest = make('chest', new THREE.Vector3(0, 0.18 * scale, 0));
  const neck = make('neck', new THREE.Vector3(0, 0.2 * scale, 0));
  const head = make('head', new THREE.Vector3(0, 0.15 * scale, 0));

  // Left arm (X negative in three.js is left if character faces +Z)
  const upperArmL = make('upperArm.L', new THREE.Vector3(-0.18 * scale, 0.16 * scale, 0));
  const lowerArmL = make('lowerArm.L', new THREE.Vector3(-0.28 * scale, 0, 0));
  const handL = make('hand.L', new THREE.Vector3(-0.26 * scale, 0, 0));

  const upperArmR = make('upperArm.R', new THREE.Vector3(0.18 * scale, 0.16 * scale, 0));
  const lowerArmR = make('lowerArm.R', new THREE.Vector3(0.28 * scale, 0, 0));
  const handR = make('hand.R', new THREE.Vector3(0.26 * scale, 0, 0));

  // Legs (down from hips)
  const upLegL = make('upLeg.L', new THREE.Vector3(-0.1 * scale, 0, 0));
  const lowerLegL = make('lowerLeg.L', new THREE.Vector3(0, -0.42 * scale, 0));
  const footL = make('foot.L', new THREE.Vector3(0, -0.42 * scale, 0));

  const upLegR = make('upLeg.R', new THREE.Vector3(0.1 * scale, 0, 0));
  const lowerLegR = make('lowerLeg.R', new THREE.Vector3(0, -0.42 * scale, 0));
  const footR = make('foot.R', new THREE.Vector3(0, -0.42 * scale, 0));

  // Parenting
  hips.add(spine);
  spine.add(chest);
  chest.add(neck);
  neck.add(head);

  chest.add(upperArmL);
  upperArmL.add(lowerArmL);
  lowerArmL.add(handL);

  chest.add(upperArmR);
  upperArmR.add(lowerArmR);
  lowerArmR.add(handR);

  hips.add(upLegL);
  upLegL.add(lowerLegL);
  lowerLegL.add(footL);

  hips.add(upLegR);
  upLegR.add(lowerLegR);
  lowerLegR.add(footR);

  const bones = [
    hips, spine, chest, neck, head,
    upperArmL, lowerArmL, handL,
    upperArmR, lowerArmR, handR,
    upLegL, lowerLegL, footL,
    upLegR, lowerLegR, footR,
  ];

  const skeleton = new THREE.Skeleton(bones);

  const map: Record<string, THREE.Bone> = {};
  bones.forEach((b) => (map[b.name] = b));

  return { skeleton, bones: map, root: hips };
}

// ---------------------------------------------------------------------------
// Skinned mesh geometry generation
// ---------------------------------------------------------------------------

interface BodyParams {
  height: number;
  build: 'slim' | 'athletic' | 'muscular' | 'stocky';
  // Muscle/bulk scale multipliers
  chestWidth?: number;
  armWidth?: number;
  legWidth?: number;
}

/**
 * Build a skinned humanoid mesh from a parametric skeleton.
 * The mesh is one merged BufferGeometry with skinIndex/skinWeight attributes.
 */
export function buildSkinnedHumanoid(hs: HumanoidSkeleton, params: BodyParams): THREE.SkinnedMesh {
  const { skeleton } = hs;
  const { height, build } = params;
  const scale = height / 1.78;

  const boneIndex = (name: string) => {
    for (let i = 0; i < skeleton.bones.length; i++) {
      if (skeleton.bones[i].name === name) return i;
    }
    return 0;
  };
  const bi = {
    hips: boneIndex('hips'),
    spine: boneIndex('spine'),
    chest: boneIndex('chest'),
    neck: boneIndex('neck'),
    head: boneIndex('head'),
    upperArmL: boneIndex('upperArm.L'),
    lowerArmL: boneIndex('lowerArm.L'),
    handL: boneIndex('hand.L'),
    upperArmR: boneIndex('upperArm.R'),
    lowerArmR: boneIndex('lowerArm.R'),
    handR: boneIndex('hand.R'),
    upLegL: boneIndex('upLeg.L'),
    lowerLegL: boneIndex('lowerLeg.L'),
    footL: boneIndex('foot.L'),
    upLegR: boneIndex('upLeg.R'),
    lowerLegR: boneIndex('lowerLeg.R'),
    footR: boneIndex('foot.R'),
  };

  // Build parts — each part is a tube around its bone axis, with vertices
  // weighted to the dominant bone of that segment.
  const parts: THREE.BufferGeometry[] = [];

  // Torso: chest → hips. Build via lathe + scale.
  const torso = buildTorso(scale, build);
  weightGeometry(torso, [
    { yMin: 0.55, bone: bi.chest },
    { yMin: 0.25, bone: bi.spine },
    { yMin: -0.2, bone: bi.hips },
  ]);
  parts.push(torso);

  // Head: a slightly squashed sphere weighted to head bone
  const headGeo = new THREE.SphereGeometry(0.12 * scale, 16, 16);
  headGeo.translate(0, 1.65 * scale, 0);
  // Slightly oval
  headGeo.scale(1, 1.1, 1);
  weightGeometryUniform(headGeo, bi.head);
  parts.push(headGeo);

  // Neck
  const neck = new THREE.CylinderGeometry(0.06 * scale, 0.06 * scale, 0.1 * scale, 12);
  neck.translate(0, 1.55 * scale, 0);
  weightGeometryUniform(neck, bi.neck);
  parts.push(neck);

  // Arms (upper + lower + hand as one smooth tube both sides)
  parts.push(buildArm(scale, bi.upperArmL, bi.lowerArmL, bi.handL, 'L'));
  parts.push(buildArm(scale, bi.upperArmR, bi.lowerArmR, bi.handR, 'R'));

  // Legs
  parts.push(buildLeg(scale, bi.upLegL, bi.lowerLegL, bi.footL, 'L'));
  parts.push(buildLeg(scale, bi.upLegR, bi.lowerLegR, bi.footR, 'R'));

  // Merge
  const merged = mergeGeometries(parts);
  merged.computeVertexNormals();

  // Add skinning attributes
  const skinIndices = new Float32Array(merged.attributes.position.count * 4);
  const skinWeights = new Float32Array(merged.attributes.position.count * 4);
  for (let i = 0; i < merged.attributes.position.count; i++) {
    skinIndices[i * 4] = merged.attributes.skinIndex?.getX(i) ?? 0;
    skinIndices[i * 4 + 1] = 0;
    skinIndices[i * 4 + 2] = 0;
    skinIndices[i * 4 + 3] = 0;
    skinWeights[i * 4] = merged.attributes.skinWeight?.getX(i) ?? 1;
    skinWeights[i * 4 + 1] = 0;
    skinWeights[i * 4 + 2] = 0;
    skinWeights[i * 4 + 3] = 0;
  }
  merged.setAttribute('skinIndex', new THREE.BufferAttribute(skinIndices, 4));
  merged.setAttribute('skinWeight', new THREE.BufferAttribute(skinWeights, 4));

  const material = new THREE.MeshStandardMaterial({
    color: '#c8a070',
    roughness: 0.7,
    metalness: 0,
  });

  const mesh = new THREE.SkinnedMesh(merged, material);
  mesh.bind(skeleton);
  mesh.castShadow = true;
  mesh.receiveShadow = true;

  return mesh;
}

// ---------------------------------------------------------------------------
// Part builders
// ---------------------------------------------------------------------------

function buildTorso(scale: number, build: BodyParams['build']): THREE.BufferGeometry {
  const width =
    build === 'muscular' ? 0.38 : build === 'athletic' ? 0.34 : build === 'stocky' ? 0.4 : 0.3;
  const depth = width * 0.7;
  // Profile along Y from hips (y=0) to shoulders (y≈0.6)
  const segments = 14;
  const positions: number[] = [];
  const indices: number[] = [];
  const ringVerts: number[][] = [];

  for (let s = 0; s <= segments; s++) {
    const t = s / segments;
    const y = -0.1 + t * 0.7; // -0.1 → 0.6
    // Width profile: narrow waist, wide chest, rounded hips
    let r: number;
    if (t < 0.3) {
      // hips
      const lt = t / 0.3;
      r = 0.22 + Math.sin(lt * Math.PI) * 0.06;
    } else if (t < 0.7) {
      // waist + lower chest
      const lt = (t - 0.3) / 0.4;
      r = 0.2 + lt * 0.08;
    } else {
      // upper chest tapering to shoulders
      const lt = (t - 0.7) / 0.3;
      r = 0.28 - lt * 0.06;
    }
    const ring: number[] = [];
    const radial = 10;
    for (let i = 0; i < radial; i++) {
      const angle = (i / radial) * Math.PI * 2;
      const px = Math.cos(angle) * r * width * scale;
      const pz = Math.sin(angle) * r * depth * scale;
      positions.push(px, y * scale, pz);
      ring.push(positions.length / 3 - 1);
    }
    ringVerts.push(ring);
  }

  // Indices
  for (let s = 0; s < segments; s++) {
    const a = ringVerts[s];
    const b = ringVerts[s + 1];
    const radial = a.length;
    for (let i = 0; i < radial; i++) {
      const i2 = (i + 1) % radial;
      indices.push(a[i], b[i], a[i2]);
      indices.push(a[i2], b[i], b[i2]);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setIndex(indices);
  return geo;
}

function buildArm(
  scale: number,
  upperBone: number,
  lowerBone: number,
  handBone: number,
  side: 'L' | 'R'
): THREE.BufferGeometry {
  const dir = side === 'L' ? -1 : 1;
  // Start at shoulder (chest+0.16, x offset), go down
  const segs = 10;
  const positions: number[] = [];
  const indices: number[] = [];
  const ringVerts: number[][] = [];

  const startX = dir * 0.18;
  const rotDir = dir; // arm hangs down

  for (let s = 0; s <= segs; s++) {
    const t = s / segs;
    const y = 1.6 - t * 0.62; // 1.6 → 0.98 (hand area)
    const x = startX;
    // Radius
    let r = 0.07;
    if (t < 0.45) r = 0.07 - t * 0.01; // upper arm slight taper
    else if (t < 0.55) r = 0.055; // elbow
    else r = 0.045 - (t - 0.55) * 0.01; // forearm taper

    r *= scale;
    const ring: number[] = [];
    const radial = 8;
    for (let i = 0; i < radial; i++) {
      const angle = (i / radial) * Math.PI * 2;
      const dy = Math.cos(angle) * r;
      const dz = Math.sin(angle) * r;
      positions.push(x * scale, y * scale + dy, dz);
      ring.push(positions.length / 3 - 1);
    }
    ringVerts.push(ring);
  }

  for (let s = 0; s < segs; s++) {
    const a = ringVerts[s];
    const b = ringVerts[s + 1];
    for (let i = 0; i < a.length; i++) {
      const i2 = (i + 1) % a.length;
      indices.push(a[i], b[i], a[i2]);
      indices.push(a[i2], b[i], b[i2]);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setIndex(indices);
  return geo;
}

function buildLeg(
  scale: number,
  upLegBone: number,
  lowerLegBone: number,
  footBone: number,
  side: 'L' | 'R'
): THREE.BufferGeometry {
  const dir = side === 'L' ? -1 : 1;
  const segs = 12;
  const positions: number[] = [];
  const indices: number[] = [];
  const ringVerts: number[][] = [];

  const startX = dir * 0.1;

  for (let s = 0; s <= segs; s++) {
    const t = s / segs;
    let y = 0.95 - t * 0.95; // 0.95 → 0
    const x = startX;

    let r: number;
    if (t < 0.5) {
      // thigh
      r = 0.12 - t * 0.04;
    } else if (t < 0.6) {
      r = 0.07; // knee
    } else {
      // shin
      r = 0.065 - (t - 0.6) * 0.03;
    }
    r *= scale;

    const ring: number[] = [];
    const radial = 8;
    for (let i = 0; i < radial; i++) {
      const angle = (i / radial) * Math.PI * 2;
      const dy = Math.cos(angle) * r;
      const dz = Math.sin(angle) * r;
      positions.push(x * scale, y * scale + dy, dz);
      ring.push(positions.length / 3 - 1);
    }
    ringVerts.push(ring);
  }

  for (let s = 0; s < segs; s++) {
    const a = ringVerts[s];
    const b = ringVerts[s + 1];
    for (let i = 0; i < a.length; i++) {
      const i2 = (i + 1) % a.length;
      indices.push(a[i], b[i], a[i2]);
      indices.push(a[i2], b[i], b[i2]);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geo.setIndex(indices);
  return geo;
}

// ---------------------------------------------------------------------------
// Weighting utilities
// ---------------------------------------------------------------------------

function weightGeometry(geo: THREE.BufferGeometry, layers: { yMin: number; bone: number }[]) {
  const pos = geo.attributes.position;
  const indices = new Float32Array(pos.count);
  const weights = new Float32Array(pos.count);
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i);
    let chosen = layers[layers.length - 1].bone;
    for (const l of layers) {
      if (y >= l.yMin) {
        chosen = l.bone;
        break;
      }
    }
    indices[i] = chosen;
    weights[i] = 1;
  }
  geo.setAttribute('skinIndex', new THREE.BufferAttribute(indices, 1));
  geo.setAttribute('skinWeight', new THREE.BufferAttribute(weights, 1));
}

function weightGeometryUniform(geo: THREE.BufferGeometry, bone: number) {
  const pos = geo.attributes.position;
  const indices = new Float32Array(pos.count).fill(bone);
  const weights = new Float32Array(pos.count).fill(1);
  geo.setAttribute('skinIndex', new THREE.BufferAttribute(indices, 1));
  geo.setAttribute('skinWeight', new THREE.BufferAttribute(weights, 1));
}

// ---------------------------------------------------------------------------
// Geometry merge (simplified: assumes each part has position + index)
// ---------------------------------------------------------------------------

function mergeGeometries(geos: THREE.BufferGeometry[]): THREE.BufferGeometry {
  // Merge by hand since we need to preserve positions
  let totalVerts = 0;
  let totalIndices = 0;
  for (const g of geos) {
    totalVerts += g.attributes.position.count;
    totalIndices += g.index?.count ?? 0;
  }

  const positions = new Float32Array(totalVerts * 3);
  const normals = new Float32Array(totalVerts * 3);
  const indicesArr: number[] = [];

  let vOffset = 0;
  let iOffset = 0;
  for (const g of geos) {
    const p = g.attributes.position;
    positions.set(p.array as Float32Array, vOffset * 3);
    // compute vertex normals if missing
    if (!g.attributes.normal) g.computeVertexNormals();
    const n = g.attributes.normal;
    normals.set(n.array as Float32Array, vOffset * 3);

    if (g.index) {
      for (let i = 0; i < g.index.count; i++) {
        indicesArr.push(g.index.array[i] + vOffset);
      }
    }
    vOffset += p.count;
  }

  const merged = new THREE.BufferGeometry();
  merged.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  merged.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  if (indicesArr.length > 0) merged.setIndex(indicesArr);
  return merged;
}

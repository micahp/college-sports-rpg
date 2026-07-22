#!/usr/bin/env python3
"""Synthesize the campus presentation audio (CC0-safe, fully procedural).

Outputs OGG files to assets/audio/: an ambient loop, four footsteps,
and three UI sounds. Requires ffmpeg for WAV->OGG. Deterministic.
"""
import math
import os
import random
import struct
import subprocess
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(42)


def write_wav(name, samples, stereo=False):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        clipped = [max(-1.0, min(1.0, s)) for s in samples]
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in clipped))
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-q:a", "3", ogg], check=True)
    os.remove(path)
    print(name + ".ogg", os.path.getsize(ogg), "bytes")


def lowpass(samples, alpha):
    out, prev = [], 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def env_ad(n, attack, decay):
    """Attack-decay envelope over n samples."""
    out = []
    a = int(n * attack)
    for i in range(n):
        if i < a:
            out.append(i / max(1, a))
        else:
            out.append(math.exp(-4.0 * (i - a) / max(1, n - a)))
    return out


# --- Ambient campus loop: breeze + birds + distant activity ---------------------

DUR = 24.0
N = int(SR * DUR)
breeze = lowpass([rnd.uniform(-1, 1) for _ in range(N)], 0.02)
# Slow amplitude swell so the wind breathes
amb = []
for i, s in enumerate(breeze):
    t = i / SR
    swell = 0.6 + 0.4 * math.sin(2 * math.pi * t / DUR * 2 + 1.3) * math.sin(2 * math.pi * t / DUR * 3)
    amb.append(s * 0.55 * swell)

# Bird chirps: short frequency-swept sine bursts, sparse and varied
def chirp(start_t, base_f, sweeps):
    t0 = int(start_t * SR)
    for k, (df, dur) in enumerate(sweeps):
        n = int(dur * SR)
        gap = int(0.03 * SR)
        off = t0 + sum(int(d * SR) + gap for _, d in sweeps[:k])
        for i in range(n):
            if off + i >= N:
                return
            ph = 2 * math.pi * (base_f * i / SR + df * (i / SR) ** 2 / (2 * dur))
            amb[off + i] += math.sin(ph) * 0.055 * math.sin(math.pi * i / n)

for t in [1.2, 3.1, 6.4, 9.8, 12.5, 15.0, 18.3, 21.1]:
    base = rnd.uniform(2200, 3400)
    chirp(t + rnd.uniform(-0.4, 0.4), base,
          [(rnd.uniform(400, 1200), rnd.uniform(0.05, 0.12)) for _ in range(rnd.randint(2, 4))])

# Distant low walla: filtered noise band, very quiet
walla = lowpass([rnd.uniform(-1, 1) for _ in range(N)], 0.005)
amb = [a + w * 0.35 for a, w in zip(amb, walla)]

# Crossfade the loop seam
FADE = int(0.8 * SR)
for i in range(FADE):
    f = i / FADE
    amb[i] = amb[i] * f + amb[N - FADE + i] * (1 - f)
write_wav("ambient_campus", amb[: N - FADE])


# --- Footsteps: short filtered noise thuds with pitch variation -----------------

for step in range(1, 5):
    n = int(0.11 * SR)
    noise = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 0.12 + step * 0.02)
    env = env_ad(n, 0.04, 0.5)
    thump_f = 95 + step * 7
    samples = [
        (noise[i] * 0.6 + math.sin(2 * math.pi * thump_f * i / SR) * 0.5)
        * env[i] * 0.5
        for i in range(n)
    ]
    write_wav("footstep_%d" % step, samples)


# --- UI sounds ------------------------------------------------------------------

def tone_seq(name, notes, vol=0.3, dur=0.09):
    samples = []
    for f in notes:
        n = int(dur * SR)
        env = env_ad(n, 0.15, 0.6)
        samples += [
            (math.sin(2 * math.pi * f * i / SR) + 0.35 * math.sin(2 * math.pi * f * 2 * i / SR))
            * env[i] * vol
            for i in range(n)
        ]
    write_wav(name, samples)


tone_seq("ui_open", [523.25, 659.25])           # C5 -> E5
tone_seq("ui_close", [659.25, 523.25])          # E5 -> C5
tone_seq("ui_confirm", [523.25, 783.99], vol=0.26)  # C5 -> G5

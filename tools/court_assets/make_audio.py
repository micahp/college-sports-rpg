"""Generates the court sound effects (plain Python, no dependencies).

  python make_audio.py <out_dir>      # writes .wav; convert to .ogg with ffmpeg

Everything is synthesized, so there is nothing to license. Sounds: ball
bounce, net swish, rim clank, sneaker squeaks, catch slap, whistle, buzzer,
a loopable crowd bed and a crowd cheer.
"""
import math, random, struct, sys, wave, os

RATE = 44100
random.seed(11)


def write(path, samples, peak=0.9):
    top = max(1e-9, max(abs(s) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / top * peak)) * 32767)) for s in samples))
    print("wrote", os.path.basename(path), "%.2fs" % (len(samples) / RATE))


def noise(n):
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, hz):
    a = 1.0 - math.exp(-2.0 * math.pi * hz / RATE)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, hz):
    lp = lowpass(x, hz)
    return [s - l for s, l in zip(x, lp)]


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def env(n, attack, decay):
    """Fast linear attack, exponential decay (both in seconds)."""
    out = []
    for i in range(n):
        t = i / RATE
        out.append(min(1.0, t / attack) * math.exp(-max(0.0, t - attack) / decay))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def bounce(pitch=1.0):
    """Leather on hardwood: a low thump that drops in pitch, plus a slap."""
    n = int(0.22 * RATE)
    e = env(n, 0.002, 0.045)
    phase, body = 0.0, []
    for i in range(n):
        f = (70.0 + 150.0 * math.exp(-i / RATE / 0.018)) * pitch
        phase += 2.0 * math.pi * f / RATE
        body.append(math.sin(phase) * e[i])
    slap = bandpass(noise(n), 500, 2600)
    se = env(n, 0.001, 0.012)
    return mix(body, [s * v * 0.55 for s, v in zip(slap, se)])


def swish():
    """Ball through the net: a soft rush of air that darkens as it passes."""
    n = int(0.42 * RATE)
    x = noise(n)
    out, y, lp = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        cut = 5200.0 - 3400.0 * t
        a = 1.0 - math.exp(-2.0 * math.pi * cut / RATE)
        y += a * (x[i] - y)
        lp += 0.02 * (y - lp)
        e = min(1.0, t / 0.06) * math.exp(-max(0.0, t - 0.1) / 0.28)
        out.append((y - lp) * e)
    return out


def rim():
    """Ball off the iron: a dull metallic clank with a short ring."""
    n = int(0.6 * RATE)
    out = [0.0] * n
    for f, amp, dec in [(410, 1.0, 0.07), (655, 0.7, 0.11), (1240, 0.5, 0.16), (1910, 0.35, 0.2), (2760, 0.2, 0.12)]:
        for i in range(n):
            t = i / RATE
            out[i] += amp * math.sin(2.0 * math.pi * f * t + f) * math.exp(-t / dec)
    thud = bounce(0.8)
    return mix(out, [s * 0.8 for s in thud])


def squeak(base, length):
    """Sneaker on hardwood: a short rising chirp with a rough edge."""
    n = int(length * RATE)
    phase, out = 0.0, []
    for i in range(n):
        t = i / n
        f = base * (1.0 + 0.35 * t) * (1.0 + 0.02 * math.sin(2.0 * math.pi * 90.0 * i / RATE))
        phase += 2.0 * math.pi * f / RATE
        e = math.sin(math.pi * t) ** 0.6
        out.append((math.sin(phase) + 0.35 * math.sin(2.0 * phase) + 0.15 * math.sin(3.0 * phase)) * e)
    return out


def slap():
    """Ball into hands on a catch."""
    n = int(0.09 * RATE)
    x = bandpass(noise(n), 700, 3500)
    e = env(n, 0.001, 0.014)
    return [s * v for s, v in zip(x, e)]


def whistle():
    """Referee's pea whistle: two close tones with a fast flutter."""
    n = int(0.55 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        flutter = 0.6 + 0.4 * math.sin(2.0 * math.pi * 38.0 * t)
        e = min(1.0, t / 0.015) * min(1.0, (n / RATE - t) / 0.05)
        out.append((math.sin(2.0 * math.pi * 2850.0 * t) + 0.7 * math.sin(2.0 * math.pi * 3060.0 * t)) * flutter * e)
    air = highpass(noise(n), 3000)
    return mix(out, [s * 0.12 for s in air])


def buzzer():
    """Arena horn: a harsh low tone."""
    n = int(1.0 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(math.sin(2.0 * math.pi * 118.0 * k * t) / k for k in (1, 2, 3, 4, 5, 7, 9))
        e = min(1.0, t / 0.01) * min(1.0, (n / RATE - t) / 0.06)
        out.append(math.tanh(s * 1.6) * e)
    return lowpass(out, 3200)


def crowd(seconds, loop):
    """Arena murmur: many band-limited voices swelling at their own pace."""
    n = int(seconds * RATE)
    out = [0.0] * n
    for _ in range(14):
        lo = random.uniform(180, 700)
        voice = bandpass(noise(n), lo, lo * random.uniform(2.5, 4.5))
        rate = random.uniform(0.15, 0.6)
        ph = random.uniform(0, 6.28)
        # Whole cycles over the loop so the bed repeats without a seam.
        cycles = max(1, round(rate * seconds))
        for i in range(n):
            swell = 0.55 + 0.45 * math.sin(2.0 * math.pi * cycles * i / n + ph)
            out[i] += voice[i] * swell
    if loop:
        fade = int(0.4 * RATE)  # crossfade the tail into the head
        for i in range(fade):
            k = i / fade
            out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
        out = out[:n - fade]
    return out


def cheer():
    """Crowd reacting to a bucket: the murmur jumps up and brightens."""
    n = int(2.2 * RATE)
    base = crowd(2.2, False)
    bright = bandpass(noise(n), 900, 4200)
    out = []
    for i in range(n):
        t = i / RATE
        e = min(1.0, t / 0.18) * math.exp(-max(0.0, t - 0.5) / 0.75)
        out.append((base[i] * 0.5 + bright[i] * 1.6) * e)
    return out


if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for name, data, peak in [
        ("court_bounce_1", bounce(1.0), 0.9), ("court_bounce_2", bounce(0.93), 0.9), ("court_bounce_3", bounce(1.08), 0.9),
        ("court_swish", swish(), 0.8), ("court_rim", rim(), 0.85),
        ("court_squeak_1", squeak(2300, 0.09), 0.5), ("court_squeak_2", squeak(2750, 0.12), 0.5),
        ("court_squeak_3", squeak(1950, 0.07), 0.5),
        ("court_catch", slap(), 0.7), ("court_whistle", whistle(), 0.6), ("court_buzzer", buzzer(), 0.7),
        ("court_crowd_loop", crowd(8.0, True), 0.6), ("court_cheer", cheer(), 0.85),
    ]:
        write(os.path.join(out_dir, name + ".wav"), data, peak)

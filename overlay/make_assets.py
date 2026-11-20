#!/usr/bin/env python3
"""Synthesises Gus's toots as WAV files. Standard library only.

A real fart is a flap of skin vibrating as air is pushed past it: a train of
pressure pulses whose rate (the pitch, 40–300 Hz) wobbles and stumbles, shaped
by the resonance of the body around it, with wet crackles mixed in and a
sputtering tail as the pressure runs out. That is what this models, rather
than a buzzing oscillator, which sounds like a kazoo.
"""
import math, os, random, struct, sys, wave

# Writes into the folder given as the first argument (the build directory), or next to this script.
HERE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
SR = 44100


class Biquad:
    """RBJ cookbook filter, one sample at a time."""

    def __init__(self, kind, freq, q):
        w = 2 * math.pi * freq / SR
        alpha = math.sin(w) / (2 * q)
        cos = math.cos(w)
        if kind == "band":
            b0, b1, b2 = alpha, 0.0, -alpha
        elif kind == "low":
            b0 = b2 = (1 - cos) / 2
            b1 = 1 - cos
        else:  # high
            b0 = b2 = (1 + cos) / 2
            b1 = -(1 + cos)
        a0 = 1 + alpha
        self.b = (b0 / a0, b1 / a0, b2 / a0)
        self.a = (-2 * cos / a0, (1 - alpha) / a0)
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x):
        b0, b1, b2 = self.b
        a1, a2 = self.a
        y = b0 * x + b1 * self.x1 + b2 * self.x2 - a1 * self.y1 - a2 * self.y2
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def smooth_noise(n, rate, rng):
    """A slowly wandering value around 0, for pitch and loudness drift."""
    out, v, target = [], 0.0, 0.0
    k = 1 - math.exp(-2 * math.pi * rate / SR)
    for i in range(n):
        if i % max(1, int(SR / (rate * 4))) == 0:
            target = rng.uniform(-1, 1)
        v += k * (target - v)
        out.append(v)
    return out


def fart(dur, f0, f1, *, rng, wet=0.2, rasp=0.3, body=320, body2=900, sputter=0.25,
         drift=0.07, flutter=0.0, attack=0.02):
    """One continuous toot from pitch f0 to f1 over dur seconds."""
    n = int(dur * SR)
    out = [0.0] * n
    wander = smooth_noise(n, 6, rng)
    swell = smooth_noise(n, 3, rng)
    res1, res2 = Biquad("band", body, 2.5), Biquad("band", body2, 4)
    air = Biquad("band", 2200, 0.8)
    low = Biquad("low", 2800, 0.7)

    phase, period_amp, period_width = 1.0, 1.0, 0.35
    tail_start = 1 - sputter
    for i in range(n):
        k = i / n
        # Pitch glides from f0 to f1 and wanders; the tail gets shakier.
        shaky = 1 + (max(0, k - tail_start) / max(1e-6, sputter)) * 2.5
        f = f0 * (f1 / f0) ** k * (1 + drift * wander[i] * shaky)
        if flutter:
            f *= 1 + 0.12 * math.sin(2 * math.pi * flutter * i / SR)
        phase += f / SR
        if phase >= 1:
            phase -= 1
            # Each flap is a little different, and in the tail some don't happen at all.
            jitter = 0.08 * shaky
            phase += rng.uniform(-jitter, jitter) * 0.5
            period_width = rng.uniform(0.25, 0.45)
            drop = k > tail_start and rng.random() < 0.35 * (k - tail_start) / sputter
            period_amp = 0.0 if drop else rng.uniform(0.75, 1.15)
        # Asymmetric pressure pulse: a quick open, a slower close.
        p = phase / period_width if phase < period_width else -1
        pulse = (math.sin(math.pi * p) ** 1.5 if p >= 0 else 0.0) * period_amp

        noise = rng.uniform(-1, 1)
        aspiration = air(noise) * (0.3 + pulse) * rasp
        x = pulse - 0.35  # remove most of the DC so the body filters ring
        y = 0.55 * res1(x) + 0.25 * res2(x) + 0.22 * x + aspiration

        # Loudness: quick attack, a wandering middle, a fade as pressure runs out.
        t = i / SR
        env = min(1.0, t / attack) * (1 + 0.25 * swell[i])
        if k > 0.7:
            env *= math.exp(-3.5 * (k - 0.7) / 0.3)
        out[i] = low(y) * env

    # Wet bubbles: short resonant pops scattered through it.
    if wet > 0:
        count = int(wet * 40 * dur)
        for _ in range(count):
            start = int(rng.uniform(0, 0.9) * n)
            fr = rng.uniform(250, 900)
            length = int(rng.uniform(0.008, 0.025) * SR)
            amp = rng.uniform(0.2, 0.6) * wet
            for j in range(length):
                if start + j >= n:
                    break
                out[start + j] += amp * math.sin(2 * math.pi * fr * j / SR) * math.exp(-j / (length / 4))
    return out


def hiss(dur, rng):
    """Silent but deadly: a long, quiet, breathy leak with a faint squeak."""
    n = int(dur * SR)
    hp, bp = Biquad("high", 1800, 0.7), Biquad("band", 3500, 1.2)
    squeak = Biquad("band", 1400, 12)
    swell = smooth_noise(n, 2, rng)
    out = []
    for i in range(n):
        k = i / n
        env = math.sin(math.pi * min(1, k * 1.2)) ** 0.8 * (1 + 0.3 * swell[i])
        x = rng.uniform(-1, 1)
        y = bp(hp(x)) * 0.8 + squeak(x) * 0.15
        out.append(y * env)
    return out


def room(buf):
    """A small room: a few early reflections, so it doesn't sound like a test tone."""
    out = buf + [0.0] * int(0.12 * SR)
    for delay, gain in ((0.011, 0.22), (0.023, 0.16), (0.037, 0.11), (0.053, 0.07), (0.079, 0.04)):
        d = int(delay * SR)
        for i, v in enumerate(buf):
            out[i + d] += v * gain
    return out


def mix(pieces):
    total = max(int(off * SR) + len(p) for off, p in pieces)
    buf = [0.0] * total
    for off, p in pieces:
        s = int(off * SR)
        for i, v in enumerate(p):
            buf[s + i] += v
    return buf


def write(name, buf, peak=0.9):
    buf = room(buf)
    m = max(1e-9, max(abs(v) for v in buf))
    g = peak / m
    fade = int(0.01 * SR)
    with wave.open(os.path.join(HERE, "sounds", name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        frames = bytearray()
        for i, v in enumerate(buf):
            if i > len(buf) - fade:
                v *= (len(buf) - i) / fade
            frames += struct.pack("<h", int(max(-1, min(1, v * g)) * 32767))
        w.writeframes(bytes(frames))


def main():
    rng = random.Random(11)
    os.makedirs(os.path.join(HERE, "sounds"), exist_ok=True)
    # Deep, long and proud.
    write("tuba.wav", fart(1.5, 58, 46, rng=rng, wet=0.1, rasp=0.25, body=220, body2=640, sputter=0.3))
    # Tight and high.
    write("squeaker.wav", fart(0.75, 260, 360, rng=rng, wet=0.0, rasp=0.5, body=900, body2=2200, sputter=0.2, drift=0.04), 0.7)
    # A string of short bursts.
    write("machinegun.wav", mix([(i * 0.14 + rng.uniform(-0.01, 0.01),
                                  fart(rng.uniform(0.07, 0.1), rng.uniform(90, 130), 85, rng=rng, wet=0.2,
                                       rasp=0.35, body=360, sputter=0.1, attack=0.005))
                                 for i in range(7)]))
    # Splattery.
    write("wetflap.wav", fart(0.7, 95, 60, rng=rng, wet=1.0, rasp=0.6, body=420, body2=1200, sputter=0.45, drift=0.12))
    # Rises at the end, like a question.
    write("question.wav", fart(1.0, 70, 190, rng=rng, wet=0.15, rasp=0.3, body=380, sputter=0.15))
    # Three notes.
    write("opera.wav", mix([(0.0, fart(0.5, 130, 125, rng=rng, wet=0.05, rasp=0.25, body=420, sputter=0.05, flutter=6)),
                            (0.52, fart(0.5, 165, 160, rng=rng, wet=0.05, rasp=0.25, body=480, sputter=0.05, flutter=6)),
                            (1.04, fart(0.95, 105, 62, rng=rng, wet=0.15, rasp=0.3, body=320, sputter=0.4, flutter=5))]))
    write("sbd.wav", hiss(1.8, rng), 0.25)
    print("sounds written")


if __name__ == "__main__":
    main()

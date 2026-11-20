#!/usr/bin/env python3
"""Builds Gus's face variants (SVG) and his toot sounds (WAV). Standard library only."""
import math, os, random, struct, sys, wave

# Writes into the folder given as the first argument (the build directory), or next to this script.
HERE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
INK = "#2b1838"

BODY = f'''
<path d="M22 280 C22 200 50 168 100 168 C150 168 178 200 178 280 Z" fill="#ff6f91" stroke="{INK}" stroke-width="5"/>
<circle cx="52" cy="220" r="9" fill="#ffe066"/><circle cx="150" cy="212" r="8" fill="#ffe066"/>
<circle cx="120" cy="252" r="9" fill="#ffe066"/><circle cx="70" cy="262" r="7" fill="#ffe066"/>
<circle cx="60" cy="214" r="4" fill="#4fc3b0"/><circle cx="142" cy="220" r="4" fill="#4fc3b0"/>
<circle cx="128" cy="246" r="4" fill="#4fc3b0"/><circle cx="160" cy="250" r="6" fill="#4fc3b0"/><circle cx="40" cy="250" r="5" fill="#4fc3b0"/>
<path d="M78 172 L100 206 L122 172" fill="#fffaf0" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
<rect x="84" y="148" width="32" height="26" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<circle cx="40" cy="98" r="15" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<circle cx="160" cy="98" r="15" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<ellipse cx="100" cy="94" rx="60" ry="64" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<ellipse cx="80" cy="50" rx="18" ry="9" fill="#ffffff" fill-opacity=".55" transform="rotate(-20 80 50)"/>
<path d="M92 31 C86 14 96 8 100 2 M102 30 C104 14 116 12 114 0 M110 32 C118 20 130 22 130 10" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
'''
CHEEKS = '<circle cx="62" cy="116" r="11" fill="#ff8e9e" fill-opacity=".55"/><circle cx="138" cy="116" r="11" fill="#ff8e9e" fill-opacity=".55"/>'
BLUSH = '<circle cx="62" cy="116" r="14" fill="#ff4f6d" fill-opacity=".75"/><circle cx="138" cy="116" r="14" fill="#ff4f6d" fill-opacity=".75"/>'

def eyes(px=2, py=2):
    return f'''
<path d="M60 66 Q76 56 92 66" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
<path d="M108 66 Q124 56 140 66" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
<circle cx="77" cy="86" r="14" fill="#ffffff" stroke="{INK}" stroke-width="4"/>
<circle cx="123" cy="86" r="14" fill="#ffffff" stroke="{INK}" stroke-width="4"/>
<circle cx="{77+px}" cy="{86+py}" r="6" fill="{INK}"/><circle cx="{123+px}" cy="{86+py}" r="6" fill="{INK}"/>'''

SQUINT = f'''
<path d="M58 60 L92 70" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
<path d="M142 60 L108 70" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
<path d="M64 80 L86 88 L64 96" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M136 80 L114 88 L136 96" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'''

NOSE_STACHE = f'''
<ellipse cx="100" cy="108" rx="17" ry="14" fill="#ff9c78" stroke="{INK}" stroke-width="4"/>
<path d="M100 122 C88 116 70 116 58 128 C66 140 84 140 100 130 C116 140 134 140 142 128 C130 116 112 116 100 122 Z" fill="#6b3b1f" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'''

SMIRK = f'<path d="M86 144 Q102 152 116 142" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
OH = f'<ellipse cx="100" cy="146" rx="9" ry="8" fill="#7a2335" stroke="{INK}" stroke-width="4"/>'
WHISTLE = f'''<circle cx="108" cy="145" r="5" fill="#7a2335" stroke="{INK}" stroke-width="3"/>
<ellipse cx="172" cy="128" rx="8" ry="6" fill="{INK}"/><rect x="177" y="96" width="4" height="32" fill="{INK}"/>
<path d="M181 96 Q196 102 190 114 Q190 104 181 104 Z" fill="{INK}"/>'''

HANDS = f'''
<ellipse cx="44" cy="222" rx="20" ry="14" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<ellipse cx="156" cy="222" rx="20" ry="14" fill="#ffc797" stroke="{INK}" stroke-width="5"/>
<path d="M34 214 L34 226 M44 212 L44 226 M54 214 L54 226 M146 214 L146 226 M156 212 L156 226 M166 214 L166 226" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'''

def svg(*parts):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-10 -10 220 300" width="220" height="300">'
            + "".join(parts) + "</svg>\n")

VARIANTS = {
    "gus.svg": svg(BODY, CHEEKS, eyes(), NOSE_STACHE, SMIRK, HANDS),
    "gus-toot.svg": svg(BODY, BLUSH, SQUINT, NOSE_STACHE, OH, HANDS),
    "gus-sbd.svg": svg(BODY, CHEEKS, eyes(4, -5), NOSE_STACHE, WHISTLE, HANDS),
}

# ---------- sound ----------
SR = 44100

def burst(dur, f0, f1, flutter, cut, vol, noise):
    n = int(dur * SR)
    out = [0.0] * n
    a = 1 - math.exp(-2 * math.pi * cut / SR)
    lp1 = lp2 = 0.0
    ph = fph = 0.0
    wob = random.uniform(5, 11)
    fl_end = flutter * random.uniform(0.7, 1.3)
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * (f1 / f0) ** k + f0 * 0.12 * math.sin(2 * math.pi * wob * t)
        ph = (ph + f / SR) % 1.0
        fph = (fph + (flutter + (fl_end - flutter) * k) / SR) % 1.0
        chop = 1.0 if fph < 0.55 else 0.15
        s = ((2 * ph - 1) + noise * random.uniform(-1, 1)) * chop
        lp1 += a * (s - lp1)
        lp2 += a * (lp1 - lp2)
        if t < 0.025:
            env = t / 0.025
        elif k < 0.65:
            env = 1.0
        else:
            env = math.exp(-6 * (k - 0.65) / 0.35)
        out[i] = lp2 * vol * env
    return out

def hiss(dur, vol):
    n = int(dur * SR)
    prev = 0.0
    out = []
    for i in range(n):
        t = i / SR
        x = random.uniform(-1, 1)
        hp = x - prev
        prev = x
        env = min(1.0, t / 0.3) * math.exp(-3 * max(0.0, t - 0.3) / dur)
        out.append(hp * vol * env)
    return out

def mix(pieces):
    total = max(int(off * SR) + len(p) for off, p in pieces) + int(0.05 * SR)
    buf = [0.0] * total
    for off, p in pieces:
        s = int(off * SR)
        for i, v in enumerate(p):
            buf[s + i] += v
    return buf

def write(name, buf, peak=0.9):
    m = max(1e-9, max(abs(v) for v in buf))
    g = peak / m
    with wave.open(os.path.join(HERE, "sounds", name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in buf))

def main():
    random.seed(7)
    os.makedirs(HERE, exist_ok=True)
    for name, body in VARIANTS.items():
        with open(os.path.join(HERE, name), "w") as f:
            f.write(body)
    os.makedirs(os.path.join(HERE, "sounds"), exist_ok=True)
    write("tuba.wav", burst(1.3, 72, 48, 17, 700, .8, .3))
    write("squeaker.wav", burst(.7, 240, 420, 42, 2600, .35, .2), .6)
    write("machinegun.wav", mix([(i * .13, burst(.09, random.uniform(85, 120), 80, 30, 1100, .7, .5)) for i in range(7)]))
    write("wetflap.wav", burst(.55, 110, 60, 28, 1400, .7, 1.3))
    write("question.wav", burst(.95, 80, 230, 24, 1500, .6, .3))
    write("opera.wav", mix([(0, burst(.5, 140, 120, 22, 1300, .55, .3)),
                            (.5, burst(.5, 180, 160, 22, 1500, .55, .3)),
                            (1.0, burst(.9, 100, 55, 20, 900, .75, .3))]))
    write("sbd.wav", hiss(1.6, .06), .12)
    print("assets written")

if __name__ == "__main__":
    main()

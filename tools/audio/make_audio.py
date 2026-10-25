"""Synthesizes every sound effect and both music loops for R.I.L.E.Y. (all original, license-free).

python make_audio.py <out_dir>
Writes 22.05 kHz mono WAV effects and 32 kHz OGG music loops.
"""
import sys, os, math
import numpy as np
import soundfile as sf
from scipy import signal

OUT = sys.argv[1] if len(sys.argv) > 1 else 'audio'
os.makedirs(OUT, exist_ok=True)
SR = 22050
rng = np.random.default_rng(42)


def t_(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sr=SR, hold=0.0):
    a_n, d_n, h_n, r_n = int(a * sr), int(d * sr), int(hold * sr), int(r * sr)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1)), np.ones(h_n), np.linspace(1, s, max(d_n, 1)),
                        np.full(max(n - a_n - h_n - d_n - r_n, 0), s), np.linspace(s, 0, max(r_n, 1))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def osc(freq, dur, kind='sine', sr=SR):
    """freq: scalar or array (per-sample)."""
    n = int(dur * sr)
    f = np.full(n, freq) if np.isscalar(freq) else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(freq)), freq)
    ph = 2 * np.pi * np.cumsum(f) / sr
    if kind == 'sine':
        return np.sin(ph)
    if kind == 'square':
        return np.sign(np.sin(ph)) * 0.7
    if kind == 'saw':
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == 'tri':
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(kind)


def noise(dur, sr=SR):
    return rng.uniform(-1, 1, int(dur * sr))


def bp(x, lo, hi, sr=SR, order=2):
    b, a = signal.butter(order, [lo / (sr / 2), min(hi / (sr / 2), 0.99)], 'band')
    return signal.lfilter(b, a, x)


def lp(x, f, sr=SR, order=2):
    b, a = signal.butter(order, min(f / (sr / 2), 0.99), 'low')
    return signal.lfilter(b, a, x)


def hp(x, f, sr=SR, order=2):
    b, a = signal.butter(order, f / (sr / 2), 'high')
    return signal.lfilter(b, a, x)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, sr=SR):
    return np.concatenate([np.zeros(int(offset * sr)), x])


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / m * 1.2) / np.tanh(1.2) * peak
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    sf.write(os.path.join(OUT, name + '.wav'), x.astype(np.float32), SR, subtype='PCM_16')


# ------------------------------------------------------------------ effects
def launch_boom():
    d = 1.2
    body = osc(np.geomspace(140, 38, 50), d) * env(int(d * SR), 0.002, 0.9, 0, 0.2)
    crack = bp(noise(d), 200, 4000) * env(int(d * SR), 0.001, 0.25, 0, 0.05)
    rumble = lp(noise(d), 180) * env(int(d * SR), 0.01, 1.0, 0, 0.1) * 2.5
    pop = osc(np.geomspace(900, 120, 10), 0.08) * env(int(0.08 * SR), 0.001, 0.07, 0, 0.005)
    save('launch_boom', mix(body * 1.2, crack * 0.8, rumble, pop * 0.6))


def crank():
    out = np.zeros(int(0.6 * SR))
    for k in range(8):
        c = bp(noise(0.03), 1500, 6000) * env(int(0.03 * SR), 0.001, 0.025)
        c += osc(2400 + 80 * k, 0.03) * env(int(0.03 * SR), 0.001, 0.02) * 0.4
        out = mix(out, at(c, k * 0.07))
    save('crank', out, 0.6)


def tick():
    save('tick', osc(1800, 0.04, 'square') * env(int(0.04 * SR), 0.001, 0.035), 0.4)


def lock():
    save('lock', mix(osc(880, 0.12, 'square') * env(int(0.12 * SR), 0.002, 0.1) * 0.6,
                     at(osc(1320, 0.12, 'square') * env(int(0.12 * SR), 0.002, 0.1) * 0.6, 0.05)), 0.5)


def whoosh(name='whoosh', d=0.6, lo=300, hi=3000):
    n = noise(d)
    e = np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2
    sweep = np.concatenate([bp(n[i:i + 512], lo + (hi - lo) * i / len(n), lo + (hi - lo) * i / len(n) + 800) for i in range(0, len(n), 512)])
    save(name, sweep[:len(e)] * e, 0.6)


def wind_loop():
    d = 3.0
    n = noise(d + 0.5)
    w = lp(bp(n, 150, 1400), 900)
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(len(w)) / SR / 1.5)
    w = w * lfo
    k = int(0.5 * SR)
    loop = w[k:k + int(d * SR)].copy()
    loop[:k] = loop[:k] * np.linspace(0, 1, k) + w[k + int(d * SR):k + int(d * SR) + k][:k] * np.linspace(1, 0, k) if len(w) >= 2 * k + int(d * SR) else loop[:k]
    save('wind_loop', loop, 0.5)


def boing():
    d = 0.7
    tt = t_(d)
    f = 160 + 260 * np.exp(-tt * 5) * (1 + 0.25 * np.sin(2 * np.pi * 18 * tt)) + 120 * (1 - np.exp(-tt * 12))
    x = osc(f, d) + 0.35 * osc(f * 2.01, d)
    save('boing', x * env(int(d * SR), 0.003, 0.65, 0, 0.05))


def sproing():
    d = 0.8
    tt = t_(d)
    f = 250 + 900 * (1 - np.exp(-tt * 9)) + 60 * np.sin(2 * np.pi * 26 * tt) * np.exp(-tt * 2)
    x = osc(f, d, 'tri') + 0.3 * osc(f * 3.03, d)
    save('sproing', x * env(int(d * SR), 0.002, 0.75, 0, 0.05))


def splash():
    d = 1.1
    body = bp(noise(d), 300, 6000) * env(int(d * SR), 0.003, 0.9, 0, 0.1)
    low = lp(noise(d), 300) * env(int(d * SR), 0.002, 0.3) * 2
    bub = np.zeros(int(d * SR))
    for k in range(14):
        f0 = rng.uniform(500, 1400)
        b = osc(np.linspace(f0, f0 * 1.8, 20), 0.05) * env(int(0.05 * SR), 0.002, 0.045)
        bub = mix(bub, at(b, rng.uniform(0.1, 0.9)))[:len(bub)]
    save('splash', mix(body, low, bub * 0.35))


def thud(name='thud', f0=110, d=0.35, bright=0.4):
    x = osc(np.geomspace(f0 * 1.8, f0 * 0.6, 20), d) * env(int(d * SR), 0.001, d * 0.9)
    c = lp(noise(0.05), 2500) * env(int(0.05 * SR), 0.001, 0.04) * bright
    save(name, mix(x, c))


def bumper():
    d = 0.5
    x = mix(osc(1046, d) * env(int(d * SR), 0.001, 0.45), osc(1568, d) * env(int(d * SR), 0.001, 0.3) * 0.6,
            at(osc(2093, 0.3) * env(int(0.3 * SR), 0.001, 0.25) * 0.5, 0.06))
    save('bumper', mix(x, bp(noise(0.03), 2000, 8000) * 0.4))


def bonk():
    d = 0.6
    x = osc(np.geomspace(700, 180, 30), 0.25) * env(int(0.25 * SR), 0.001, 0.24)
    wh = osc(np.linspace(1400, 300, 40), 0.55, 'sine') * env(int(0.55 * SR), 0.02, 0.5) * 0.5
    save('crash_bonk', mix(x, at(wh, 0.08), lp(noise(0.06), 3000) * 0.5))


def coin():
    a = osc(1976, 0.08, 'square') * env(int(0.08 * SR), 0.001, 0.07) * 0.6
    b = osc(2637, 0.3, 'square') * env(int(0.3 * SR), 0.001, 0.28) * 0.6
    save('coin', mix(a, at(b, 0.07)), 0.45)


def combo():
    out = np.zeros(1)
    for k, f in enumerate((523, 659, 784, 1046)):
        n = osc(f, 0.18, 'square') * env(int(0.18 * SR), 0.002, 0.16) * 0.5 + osc(f * 2, 0.18) * env(int(0.18 * SR), 0.002, 0.1) * 0.3
        out = mix(out, at(n, k * 0.055))
    save('combo', out, 0.55)


def perfect():
    out = np.zeros(1)
    for k, (f, d) in enumerate(((784, 0.12), (988, 0.12), (1175, 0.12), (1568, 0.45))):
        n = (osc(f, d, 'square') * 0.5 + osc(f * 1.005, d, 'saw') * 0.25) * env(int(d * SR), 0.003, d * 0.9)
        out = mix(out, at(n, k * 0.1))
    save('perfect', out, 0.6)


def rocket():
    d = 1.0
    roar = lp(noise(d), 1200) * env(int(d * SR), 0.03, 0.8, 0.0, 0.1) * 2
    hiss = hp(noise(d), 3000) * env(int(d * SR), 0.01, 0.6) * 0.5
    ign = osc(np.geomspace(300, 80, 20), 0.3) * env(int(0.3 * SR), 0.002, 0.28)
    cr = np.zeros(int(d * SR))
    for k in range(40):
        p = int(rng.uniform(0, d * 0.8) * SR)
        cr[p:p + 30] += rng.uniform(-1, 1, 30)[:len(cr[p:p + 30])]
    save('rocket', mix(roar, hiss, ign, cr * 0.4))


def balloon():
    d = 0.9
    tt = t_(d)
    f = 300 + 500 * tt / d + 40 * np.sin(2 * np.pi * 30 * tt)
    x = osc(f, d, 'saw')
    x = bp(x, 400, 2500) * env(int(d * SR), 0.05, 0.8, 0, 0.05)
    save('balloon', x, 0.5)


def umbrella():
    d = 0.4
    x = lp(noise(d), 900) * env(int(d * SR), 0.004, 0.3) * 2 + osc(np.geomspace(260, 120, 10), d) * env(int(d * SR), 0.002, 0.3)
    save('umbrella', x)


def plunger():
    thwip = osc(np.geomspace(2500, 400, 20), 0.15) * env(int(0.15 * SR), 0.001, 0.14)
    suck = osc(np.linspace(180, 90, 10), 0.18, 'square') * env(int(0.18 * SR), 0.005, 0.16) * 0.5
    save('plunger', mix(thwip, at(lp(suck, 900), 0.18)), 0.6)


def inflate():
    d = 0.8
    hiss = bp(noise(d), 2000, 7000) * np.linspace(0.2, 1, int(d * SR)) * env(int(d * SR), 0.01, 0.75)
    pop = at(osc(np.geomspace(500, 150, 10), 0.1) * env(int(0.1 * SR), 0.001, 0.09), 0.6)
    save('inflate', mix(hiss * 0.6, pop))


def fan_loop():
    d = 2.0
    tt = t_(d)
    x = osc(90, d, 'saw') * 0.3 + osc(180, d) * 0.4 + lp(noise(d), 400) * 0.8
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 15 * tt)
    save('fan_loop', lp(x, 1200), 0.4)


def horn():
    d = 0.6
    x = (osc(392, d, 'saw') + osc(494, d, 'saw')) * env(int(d * SR), 0.02, 0.1, 0.8, 0.1, hold=0.3)
    save('horn', lp(x, 2200), 0.6)


def squeak():
    d = 0.35
    tt = t_(d)
    f = 900 + 600 * np.sin(np.pi * tt / d)
    save('squeak', bp(osc(f, d, 'saw'), 600, 3500) * env(int(d * SR), 0.01, 0.3), 0.5)


def wood_break():
    out = np.zeros(int(0.8 * SR))
    for k in range(6):
        c = bp(noise(0.08), 400, 5000) * env(int(0.08 * SR), 0.001, 0.07)
        c += osc(rng.uniform(150, 300), 0.08) * env(int(0.08 * SR), 0.001, 0.06)
        out = mix(out, at(c, k * 0.06 + rng.uniform(0, 0.03)))
    save('wood_break', out)


def ui_click():
    save('ui_click', osc(np.geomspace(1200, 700, 5), 0.06) * env(int(0.06 * SR), 0.001, 0.055), 0.5)
    save('ui_back', osc(np.geomspace(700, 400, 5), 0.07) * env(int(0.07 * SR), 0.001, 0.065), 0.5)


def purchase():
    out = mix(bp(noise(0.12), 3000, 9000) * env(int(0.12 * SR), 0.001, 0.1) * 0.5,
              at(osc(1568, 0.25, 'square') * env(int(0.25 * SR), 0.002, 0.23) * 0.5, 0.05),
              at(osc(2093, 0.35, 'square') * env(int(0.35 * SR), 0.002, 0.33) * 0.5, 0.13))
    save('purchase', out, 0.55)


def new_record():
    notes = [(523, 0.1), (659, 0.1), (784, 0.1), (1046, 0.2), (784, 0.1), (1046, 0.5)]
    out, tpos = np.zeros(1), 0
    for f, d in notes:
        n = (osc(f, d + 0.05, 'square') * 0.5 + osc(f / 2, d + 0.05, 'tri') * 0.4) * env(int((d + 0.05) * SR), 0.003, d)
        out = mix(out, at(n, tpos))
        tpos += d
    save('new_record', out, 0.6)


# ------------------------------------------------------------------ cartoon voice (formant synthesis)
VOW = {'a': (1000, 1450, 3300), 'o': (680, 1000, 2900), 'u': (380, 1000, 2700), 'e': (640, 2200, 3000),
       'i': (330, 2700, 3500), 'h': (0, 0, 0)}


def voice(name, segs, breath=0.0):
    """segs: list of (vowel, dur, f0_start, f0_end)."""
    out = []
    zi = [None, None, None]
    prev = None
    for v, d, f0a, f0b in segs:
        n = int(d * SR)
        f0 = np.linspace(f0a, f0b, n) * (1 + 0.02 * np.sin(2 * np.pi * 6 * np.arange(n) / SR))
        src = osc(f0, d, 'saw') * 0.6 + noise(d) * (0.08 + breath)
        if v == 'h':
            out.append(bp(noise(d), 600, 4000) * 0.25 * env(n, 0.01, d * 0.8))
            continue
        target = np.array(VOW[v], dtype=float)
        start = np.array(VOW[prev] if prev and prev != 'h' else VOW[v], dtype=float)
        chunk = 256
        y = np.zeros(n)
        for i in range(0, n, chunk):
            k = min(1.0, i / max(1, n * 0.35))
            F = start + (target - start) * k
            seg_out = np.zeros(min(chunk, n - i))
            for j, (fc, bw, g) in enumerate(zip(F, (90, 120, 200), (1.0, 0.6, 0.3))):
                b, a = signal.iirpeak(fc / (SR / 2), fc / bw)
                if zi[j] is None or len(zi[j]) != max(len(a), len(b)) - 1:
                    zi[j] = signal.lfilter_zi(b, a) * 0
                r, zi[j] = signal.lfilter(b, a, src[i:i + chunk], zi=zi[j])
                seg_out += r * g
            y[i:i + chunk] = seg_out
        out.append(y * env(n, 0.02, d * 0.85, 0.0, 0.03, hold=d * 0.1))
        prev = v
    save('voice_' + name, np.concatenate(out), 0.75)


def voices():
    voice('woohoo', [('u', 0.18, 380, 470), ('h', 0.05, 0, 0), ('u', 0.32, 470, 640)])
    voice('whoa', [('u', 0.08, 420, 450), ('o', 0.18, 450, 520), ('a', 0.3, 520, 380)])
    voice('yay', [('i', 0.06, 480, 520), ('e', 0.18, 520, 600), ('i', 0.2, 600, 560)])
    voice('oof', [('u', 0.16, 300, 220)])
    voice('aah', [('a', 0.7, 560, 600)], breath=0.05)
    voice('yeah', [('i', 0.06, 420, 440), ('e', 0.14, 440, 520), ('a', 0.22, 520, 430)])
    voice('ouch', [('a', 0.12, 470, 520), ('u', 0.16, 520, 380), ('h', 0.06, 0, 0)])


# ------------------------------------------------------------------ music
MSR = 32000
NOTE = {n: i for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}


def midi(name):
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def mosc(f, d, kind):
    return osc(f, d, kind, MSR)


def menv(n, a, d, s, r):
    return env(n, a, d, s, r, MSR)


def song(name, bpm, prog, melody_seed, bars=16, swing=0.0, lead='square'):
    beat = 60 / bpm
    total = bars * 4 * beat
    N = int(total * MSR)
    out = np.zeros(N + MSR)
    r = np.random.default_rng(melody_seed)

    def put(x, tpos):
        i = int(tpos * MSR)
        out[i:i + len(x)] += x[:len(out) - i]

    scale = [0, 2, 4, 5, 7, 9, 11]
    phrase = None
    for bar in range(bars):
        root, quality = prog[bar % len(prog)]
        rm = midi(root + '2')
        third = 3 if quality == 'm' else 4
        chord = [rm + 12, rm + 12 + third, rm + 19]
        # bass: root-fifth bounce
        for k, off in enumerate((0, 7, 12, 7)):
            d = beat * 0.9
            x = mosc(hz(rm + off), d, 'tri') * menv(int(d * MSR), 0.005, d * 0.8, 0.2, 0.03) * 0.55
            put(x, (bar * 4 + k) * beat)
        # chord stabs on off-beats
        for k in range(4):
            d = beat * 0.35
            x = sum(mosc(hz(m + 12), d, 'square') for m in chord) / 3 * menv(int(d * MSR), 0.003, d * 0.9, 0, 0.02) * 0.16
            put(lp(x, 3500, MSR), (bar * 4 + k + 0.5) * beat)
        # drums
        for k in range(4):
            kick = mosc(np.geomspace(150, 45, 10), 0.18, 'sine') * menv(int(0.18 * MSR), 0.001, 0.17, 0, 0.01) * 0.9
            if k in (0, 2):
                put(kick, (bar * 4 + k) * beat)
            if k in (1, 3):
                sn = bp(rng.uniform(-1, 1, int(0.15 * MSR)), 900, 7000, MSR) * menv(int(0.15 * MSR), 0.001, 0.14, 0, 0.005) * 0.5
                put(sn, (bar * 4 + k) * beat)
            for h in (0, 0.5):
                hh = hp(rng.uniform(-1, 1, int(0.04 * MSR)), 7000, MSR) * menv(int(0.04 * MSR), 0.001, 0.035, 0, 0.003) * 0.18
                put(hh, (bar * 4 + k + h + (swing if h else 0)) * beat)
        # melody: 2-bar phrases, repeated with variation
        if bar % 4 == 0 or phrase is None:
            phrase = []
            pos = 0.0
            while pos < 8:
                d = r.choice([0.5, 0.5, 1.0, 0.25, 0.75, 1.5]) if pos % 1 == 0 else 0.5
                d = min(d, 8 - pos)
                deg = int(r.integers(0, 7))
                phrase.append((pos, d, deg, r.random() < 0.15))
                pos += d
        start = bar % 2 * 4
        for pos, d, deg, rest in phrase:
            if not (start <= pos < start + 4) or rest:
                continue
            m = midi(root + '4') + scale[deg] - (scale[deg] > 7) * 12
            # pull toward chord tones on strong beats
            if pos % 1 == 0:
                m = min(chord, key=lambda c: abs((c + 24) - m)) + 24
            dur = d * beat * 0.92
            n = int(dur * MSR)
            vib = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * np.arange(n) / MSR) * np.linspace(0, 1, n))
            x = (mosc(vib, dur, lead) * 0.6 + mosc(vib * 2, dur, 'sine') * 0.15) * menv(n, 0.005, dur * 0.6, 0.6, 0.03) * 0.33
            put(lp(x, 5000, MSR), (bar * 4 + pos - start) * beat)
    loop = out[:N]
    tail = out[N:N + int(0.2 * MSR)]
    loop[:len(tail)] += tail * np.linspace(1, 0, len(tail))
    loop = np.tanh(loop * 1.1) * 0.8
    sf.write(os.path.join(OUT, name + '.ogg'), loop.astype(np.float32), MSR, format='OGG', subtype='VORBIS')


for fn in (launch_boom, crank, tick, lock, whoosh, wind_loop, boing, sproing, splash, bumper, bonk, coin, combo, perfect,
           rocket, balloon, umbrella, plunger, inflate, fan_loop, horn, squeak, wood_break, ui_click, purchase, new_record, voices):
    fn()
thud('thud', 110, 0.35, 0.4)
thud('soft_land', 80, 0.4, 0.1)
thud('roof_land', 160, 0.25, 0.8)
whoosh('gadget_whoosh', 0.4, 600, 4000)
song('music_menu', 104, [('C', ''), ('A', 'm'), ('F', ''), ('G', '')], 5, bars=16, swing=0.08)
song('music_game', 138, [('C', ''), ('G', ''), ('A', 'm'), ('F', ''), ('D', 'm'), ('G', ''), ('C', ''), ('G', '')], 21, bars=16)
song('music_space', 120, [('A', 'm'), ('F', ''), ('C', ''), ('G', '')], 33, bars=16, lead='tri')
print('AUDIO DONE', len(os.listdir(OUT)))

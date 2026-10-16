"""배경음악 합성 (외부 라이브러리 없이): 차분한 일렉트로닉 루프 → assets/music/bgm.wav
112 BPM, A 단조, 16마디 (Am - F - C - G 를 두 마디씩, 두 바퀴). 끝과 처음이 이어지게 꼬리를 앞에 겹친다.
층: 패드(부드러운 화음) · 베이스(8분음, 박마다 사이드체인 펌핑) · 아르페지오(16분, 5마디부터) · 킥 · 오프비트 하이햇 · 2·4박 클랩(9마디부터).
실행: python tools/make_bgm.py
"""
import math
import random
import struct
import os

RATE = 32000
BPM = 112.0
BEAT = 60.0 / BPM
BARS = 16
TOTAL = BARS * 4 * BEAT
N = int(TOTAL * RATE)
TAIL = int(2.0 * RATE)                     # 끝에서 넘치는 잔향 → 앞에 겹쳐 이음매를 없앤다
random.seed(7)

CHORDS = [  # (근음 MIDI, 화음 MIDI 목록) 두 마디씩
    (45, [57, 60, 64]),   # Am
    (41, [53, 57, 60]),   # F
    (48, [55, 60, 64]),   # C
    (43, [55, 59, 62]),   # G
]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


buf = [0.0] * (N + TAIL)


def add(start, samples, gain):
    i0 = int(start * RATE)
    for k, v in enumerate(samples):
        j = i0 + k
        if j < len(buf):
            buf[j] += v * gain


def chord_at(bar):
    return CHORDS[(bar // 2) % 4]


def saw(ph):
    return 2.0 * (ph - math.floor(ph + 0.5))


def pad(freqs, dur):
    n = int(dur * RATE)
    out = []
    lp = 0.0
    phases = [random.random() for _ in freqs for _ in range(2)]
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.6) * min(1.0, (dur - t) / 0.8 + 0.0) if t < dur else 0.0
        env = max(env, 0.0)
        s = 0.0
        k = 0
        for f in freqs:
            for det in (0.997, 1.003):
                s += saw(phases[k] + f * det * t)
                k += 1
        s /= (len(freqs) * 2)
        a = 1.0 - math.exp(-2.0 * math.pi * 900.0 / RATE)       # 부드럽게 (저역 통과)
        lp += (s - lp) * a
        out.append(lp * env)
    return out


def bass(f, dur):
    n = int(dur * RATE)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / RATE
        s = saw(f * t) * 0.6 + math.sin(2 * math.pi * f * 0.5 * t) * 0.6
        cut = 300.0 + 1400.0 * math.exp(-t * 18.0)
        a = 1.0 - math.exp(-2.0 * math.pi * cut / RATE)
        lp += (s - lp) * a
        out.append(lp * math.exp(-t * 5.0) * min(1.0, t * 400.0))
    return out


def pluck(f, dur):
    n = int(dur * RATE)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / RATE
        s = saw(f * t) * 0.5 + math.sin(2 * math.pi * f * 2.0 * t) * 0.2
        cut = 1200.0 + 3500.0 * math.exp(-t * 25.0)
        a = 1.0 - math.exp(-2.0 * math.pi * cut / RATE)
        lp += (s - lp) * a
        out.append(lp * math.exp(-t * 9.0) * min(1.0, t * 600.0))
    return out


def kick():
    n = int(0.35 * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 45.0 + 85.0 * math.exp(-t * 30.0)
        ph += f / RATE
        out.append(math.sin(2 * math.pi * ph) * math.exp(-t * 9.0))
    return out


def hat():
    n = int(0.06 * RATE)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        w = random.uniform(-1, 1)
        hp = w - prev                                  # 고역만 (차분)
        prev = w
        out.append(hp * math.exp(-t * 70.0) * 0.5)
    return out


def clap():
    n = int(0.18 * RATE)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / RATE
        w = random.uniform(-1, 1)
        a = 1.0 - math.exp(-2.0 * math.pi * 2500.0 / RATE)
        lp += (w - lp) * a
        burst = sum(math.exp(-max(0.0, t - d) * 60.0) for d in (0.0, 0.012, 0.024) if t >= d)
        out.append((w - lp) * burst * 0.35 * math.exp(-t * 14.0))
    return out


K = kick()
H = hat()
C = clap()
for bar in range(BARS):
    root, tones = chord_at(bar)
    bar_t = bar * 4 * BEAT
    if bar % 2 == 0:
        add(bar_t, pad([hz(m) for m in tones], 2 * 4 * BEAT + 0.3), 0.22)
    for e in range(8):                                  # 베이스 8분음
        t0 = bar_t + e * BEAT / 2
        add(t0, bass(hz(root - 12 + (12 if e % 4 == 3 else 0)), BEAT / 2 + 0.05), 0.32)
    for b in range(4):                                  # 킥 · 하이햇
        add(bar_t + b * BEAT, K, 0.45)
        add(bar_t + b * BEAT + BEAT / 2, H, 0.22)
        if bar >= 8 and b in (1, 3):
            add(bar_t + b * BEAT, C, 0.5)
    if bar >= 4:                                        # 아르페지오 16분 (위로 오르내림)
        seq = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[1] + 24, tones[2] + 12, tones[1] + 12]
        for s16 in range(16):
            m = seq[s16 % len(seq)]
            vel = 0.13 if s16 % 4 == 0 else 0.08
            add(bar_t + s16 * BEAT / 4, pluck(hz(m), BEAT / 4 + 0.15), vel)

# 사이드체인: 박마다 패드·베이스가 살짝 눌렸다 올라온다 (일렉트로닉 펌핑). 킥 자체도 눌리지만 짧아서 괜찮다
for i in range(N + TAIL):
    t = (i / RATE) % BEAT
    buf[i] *= 0.6 + 0.4 * min(1.0, t / (BEAT * 0.45))

# 이음매: 넘친 꼬리를 앞에 겹친다
out = buf[:N]
for i in range(TAIL):
    out[i] += buf[N + i]

peak = max(abs(v) for v in out) or 1.0
scale = 0.7 / peak
os.makedirs(os.path.join(os.path.dirname(__file__), "..", "assets", "music"), exist_ok=True)
path = os.path.join(os.path.dirname(__file__), "..", "assets", "music", "bgm.wav")
with open(path, "wb") as f:
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32000)) for v in out)
    f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE")
    f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
    f.write(b"data" + struct.pack("<I", len(data)) + data)
print("wrote", path, "%.1fs" % TOTAL, len(data) // 1024, "KB")

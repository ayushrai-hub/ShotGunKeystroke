#!/usr/bin/env python3
"""Synthesize the shotgun blast (Resources/shotgun.wav) from scratch.

Pure stdlib — no numpy needed. The sound is three layers:
  1. a sharp white-noise crack (the muzzle report),
  2. a low-passed noise boom (the body of the blast),
  3. a pitch-dropping sub-bass thump (the punch you feel).

Deterministic (seeded RNG) so the committed wav is reproducible.
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
DURATION = 0.7
N = int(SAMPLE_RATE * DURATION)

random.seed(1337)

samples = [0.0] * N

# Layer 1: crack — white noise with a very fast decay.
for i in range(N):
    t = i / SAMPLE_RATE
    env = math.exp(-t / 0.012)
    samples[i] += random.uniform(-1.0, 1.0) * env * 0.9

# Layer 2: boom — one-pole low-passed noise, slower decay.
random.seed(7331)
lp = 0.0
ALPHA = 0.08
for i in range(N):
    t = i / SAMPLE_RATE
    lp += ALPHA * (random.uniform(-1.0, 1.0) - lp)
    env = math.exp(-t / 0.15)
    samples[i] += lp * env * 2.4

# Layer 3: thump — sine sweep dropping from ~95 Hz to ~55 Hz.
phase = 0.0
for i in range(N):
    t = i / SAMPLE_RATE
    freq = 55.0 + 40.0 * math.exp(-t / 0.05)
    phase += 2.0 * math.pi * freq / SAMPLE_RATE
    env = math.exp(-t / 0.09)
    samples[i] += math.sin(phase) * env * 0.8

# Soft-clip, normalize, and fade out the tail.
samples = [math.tanh(s * 1.4) for s in samples]
peak = max(abs(s) for s in samples)
samples = [s / peak * 0.92 for s in samples]
fade = int(SAMPLE_RATE * 0.05)
for i in range(fade):
    samples[N - fade + i] *= 1.0 - i / fade

out = Path(__file__).resolve().parent.parent / "Resources" / "shotgun.wav"
out.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(out), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(SAMPLE_RATE)
    frames = b"".join(
        struct.pack("<h", int(s * 32767)) for s in samples
    )
    wav.writeframes(frames)

print(f"wrote {out} ({N} samples, {DURATION}s)")

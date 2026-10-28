#!/usr/bin/env python3
"""Original, deterministic PCM sound kit; no recordings or third-party samples.

Run only when intentionally replacing these authored assets. 22.05 kHz / 16 bit;
mono physical actions, stereo environmental beds. Runtime owns the quiet mix.
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[2] / "assets/audio/settlement"
RATE = 22050
TAU = math.tau


def save(name, channels, peak=0.72, loop=False):
    if loop:
        overlap = int(RATE * 0.3)
        for samples in channels:
            tail = samples[-overlap:]
            for i in range(overlap):
                t = i / overlap
                samples[i] = tail[i] * (1 - t) + samples[i] * t
            del samples[-overlap:]
    else:
        for samples in channels:
            fade = min(int(RATE * 0.012), len(samples) // 10)
            for i in range(fade):
                samples[i] *= i / fade
                samples[-i - 1] *= i / fade
    # Remove DC before normalizing, leaving ample headroom for polyphony.
    for samples in channels:
        mean = sum(samples) / len(samples)
        for i in range(len(samples)):
            samples[i] -= mean
    scale = peak / max(max(abs(v) for v in c) for c in channels)
    pcm = array('h', (round(v * scale * 32767) for frame in zip(*channels) for v in frame))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def impact(index, chop=False):
    rng = random.Random(481 + index + 500 * chop)
    length = (0.45 if chop else 0.24) + rng.uniform(-0.025, 0.025)
    samples = array('f')
    low = 0.0
    body = rng.uniform(155, 195) if chop else rng.uniform(82, 115)
    for i in range(int(RATE * length)):
        t = i / RATE
        low += 0.23 * (rng.uniform(-1, 1) - low)
        if chop:
            # Dull wood impact, brief grain fracture, then short hollow resonance.
            grain = low * (math.exp(-t * 65) + 0.24 * math.exp(-((t - 0.035) / 0.018) ** 2))
            value = 0.8 * grain + sum(
                amp * math.sin(TAU * body * ratio * t) * math.exp(-t * decay)
                for ratio, amp, decay in [(1, .28, 24), (2.34, .13, 35), (3.8, .07, 48)]
            )
        else:
            # Soft barefoot contact on sandy earth: low thud plus a short scuff.
            value = 0.45 * math.sin(TAU * body * t) * math.exp(-t * 60)
            value += low * (0.65 * math.exp(-t * 38) + 0.16 * math.exp(-((t - .065) / .027) ** 2))
        samples.append(value)
    save(('chop' if chop else 'step') + f'_{index + 1:02}', [samples])


def bell(index):
    rng = random.Random(972 + index)
    base = 440 * rng.uniform(.99, 1.01)
    modes = [(1, 1, 1.5), (2.01, .42, 1.1), (2.74, .15, .8), (4.07, .10, .55), (5.43, .035, .35)]
    samples = array('f')
    for i in range(int(RATE * 5.5)):
        t = i / RATE
        attack = 1 - math.exp(-t * 160)
        value = sum(amp * math.sin(TAU * base * ratio * t) * math.exp(-t / decay)
                    for ratio, amp, decay in modes)
        value += .13 * math.sin(TAU * (base + 2.1) * t) * math.exp(-t / 1.4)
        samples.append(value * attack)
    save(f'bell_{index + 1:02}', [samples])


def ambience(index, kind):
    duration = {'wind': 12.0, 'rain': 9.0, 'drops': 5.7}[kind] + index * .37
    channels = []
    for channel in range(2):
        rng = random.Random(4130 + index * 13 + channel + {'wind': 0, 'rain': 100, 'drops': 200}[kind])
        samples = array('f')
        low = slow = 0.0
        for i in range(int(RATE * duration)):
            t = i / RATE
            noise = rng.uniform(-1, 1)
            low += (0.035 if kind == 'wind' else 0.38) * (noise - low)
            slow += .005 * (noise - slow)
            if kind == 'wind':
                envelope = .55 + .22 * math.sin(TAU * t / 7.3 + index) + .15 * math.sin(TAU * t / 3.7 + channel)
                value = (low - slow * .6) * envelope
            elif kind == 'rain':
                # Broad, softened white noise, with slow density fluctuations.
                value = (.78 * low + .08 * noise) * (.9 + .1 * math.sin(TAU * t / 6.1 + index))
            else:
                value = 0.0
            samples.append(value)
        if kind == 'drops':
            time = .08
            while time < duration - .12:
                start = int(time * RATE)
                frequency = rng.uniform(600, 1900)
                strength = rng.uniform(.2, .8)
                for j in range(int(.085 * RATE)):
                    t = j / RATE
                    env = (1 - math.exp(-t * 1500)) * math.exp(-t * 90)
                    samples[start + j] += strength * env * (.45 * rng.uniform(-1, 1) + .25 * math.sin(TAU * frequency * t))
                time += rng.uniform(.075, .38)
        channels.append(samples)
    save(f'{kind}_{index + 1:02}', channels, peak=.55 if kind != 'drops' else .65, loop=True)


if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    for index in range(6):
        impact(index)
    for index in range(5):
        impact(index, chop=True)
    for index in range(3):
        bell(index)
        for kind in ('wind', 'rain', 'drops'):
            ambience(index, kind)
    print(f'Generated 23 original variations in {ROOT}')

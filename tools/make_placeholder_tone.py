"""Writes the development placeholder tone: 20 s of a quiet 220 Hz sine,
mono, 8 kHz, 8-bit. It is not a chant and exists only to try the audio
controls. The output is the same bytes on every run.

Usage: python -I -X utf8 tools/make_placeholder_tone.py <out.wav>
"""

import math
import sys
import wave

RATE = 8000
SECONDS = 20
FREQUENCY = 220
AMPLITUDE = 20  # out of 127: quiet


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("Usage: make_placeholder_tone.py <out.wav>")
    samples = bytes(
        128 + round(AMPLITUDE * math.sin(2 * math.pi * FREQUENCY * n / RATE))
        for n in range(RATE * SECONDS)
    )
    with wave.open(sys.argv[1], "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(1)
        out.setframerate(RATE)
        out.writeframes(samples)


if __name__ == "__main__":
    main()

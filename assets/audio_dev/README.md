# Development audio

`placeholder_tone_not_a_chant.wav` is 20 seconds of a quiet 220 Hz tone. It is
**not a chant** and not a recording of anything. It exists only so the audio
controls can be tried before a real recording exists.

- It is made by `tools/make_placeholder_tone.py` and can be regenerated with
  `python -I -X utf8 tools/make_placeholder_tone.py assets/audio_dev/placeholder_tone_not_a_chant.wav`.
- The app offers it only in a debug build started with
  `--dart-define=NAMO_DEV_AUDIO=true`, and always labels it
  "Development placeholder tone (not a chant)".
- It is never offered in a release build.

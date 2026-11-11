# Branding

- `namo_icon_square.png` is the owner-supplied icon (`design/branding/namo_icon_owner_supplied.png`) laid over a square of its corner colour, 1254 x 1254, no alpha channel.
- Corner colour: `#2B3837`. The web background and theme colour, and the start-up screen, are `#151714`.
- Made by `tools/make_icon_square.py`; the owner's file is not altered.
- The start-up (splash) screen does not use `namo_icon_square.png`: it uses the owner-supplied icon itself, whose corners are see-through, so no square shows on the dark `#151714` start-up background (`flutter_native_splash.image` in `pubspec.yaml`). After re-running `dart run flutter_native_splash:create`, remove the zoom-blocking viewport tag it adds to `web/index.html`.

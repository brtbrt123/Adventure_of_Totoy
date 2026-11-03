# Fonts

**Pixelify Sans** (`PixelifySans.ttf`, a variable font with a weight axis 400-700).
- Source: https://github.com/google/fonts/tree/main/ofl/pixelifysans (`PixelifySans[wght].ttf`), downloaded 2026-10-19 with the human's approval.
- Copyright 2021 The Pixelify Sans Project Authors (https://github.com/eifetx/Pixelify-Sans).
- License: SIL Open Font License 1.1, no Reserved Font Name. The full text is `OFL-PixelifySans.txt` and must ship with the game. The font is used unmodified.
- SHA-256 of the downloaded file: `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5` (79,160 bytes). OFL.txt: `b66ba46f511a851ab09998b5a5a9fdbb102545a3864cb993095e1745996873a7`.

`presentation/arena/hud.gd` (`ui_font()`) loads it for all HUD, title, controls and credits text and falls back to Godot's built-in font if the file is missing.

**Cinzel** (`Cinzel.ttf`, a variable font with a weight axis 400-900).
- Source: https://github.com/google/fonts/tree/main/ofl/cinzel (`Cinzel[wght].ttf`), downloaded 2026-10-19 with the human's approval; the closest free match to the carved capitals of the title logo the human supplied.
- Copyright 2020 The Cinzel Project Authors (https://github.com/NDISCOVER/Cinzel).
- License: SIL Open Font License 1.1, no Reserved Font Name; full text in `OFL-Cinzel.txt`, which must ship with the game. Used unmodified.
- SHA-256 of the downloaded file: `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34` (125,468 bytes). OFL.txt: `f2b3029aba64c378bf0963b62945eee15e564fe4330b934c8f2eb058282b5e83`.
- Used for the menu text (and by `tools/art/make_title_logo.py` for the title logo lettering).

## SpriteCook UI integration (2026-10-29)

Cinzel now supplies both body (`ui_font`, weight 400) and heading (`menu_font`, weight 900) text. Numerals and input labels use the original bitmap font in `art/ui_kit/pixel_keys.fnt`, reproduced by `make_pixel_font.py` beside it. Pixelify Sans remains available for older art/tools. See decision 0005.

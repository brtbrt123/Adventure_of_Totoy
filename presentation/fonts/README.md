# Fonts

**Pixelify Sans** (`PixelifySans.ttf`, a variable font with a weight axis 400-700).
- Source: https://github.com/google/fonts/tree/main/ofl/pixelifysans (`PixelifySans[wght].ttf`), downloaded 2026-10-19 with the human's approval.
- Copyright 2021 The Pixelify Sans Project Authors (https://github.com/eifetx/Pixelify-Sans).
- License: SIL Open Font License 1.1, no Reserved Font Name. The full text is `OFL-PixelifySans.txt` and must ship with the game. The font is used unmodified.
- SHA-256 of the downloaded file: `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5` (79,160 bytes). OFL.txt: `b66ba46f511a851ab09998b5a5a9fdbb102545a3864cb993095e1745996873a7`.

`presentation/arena/hud.gd` (`ui_font()`) loads it for all HUD, title, controls and credits text and falls back to Godot's built-in font if the file is missing.

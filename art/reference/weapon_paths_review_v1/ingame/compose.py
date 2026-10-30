"""Compose the --motion runtime captures, preserving the exact 3x game-pixel grid.

python art/reference/weapon_paths_review_v1/ingame/compose.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
RAW = ROOT / "art/build/arena_weapon_paths_motion"
WEAPONS = [("black_katana", "Katana"), ("dual_dagger", "Dual Daggers"), ("chain_scythe", "Chain Scythe")]


def main() -> None:
    font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 18)
    frames = []
    for tick in range(90):
        canvas = Image.new("RGB", (1152, 544), (28, 24, 36))
        draw = ImageDraw.Draw(canvas)
        for row, scene in enumerate(("arena", "road")):
            for col, (weapon, title) in enumerate(WEAPONS):
                im = Image.open(RAW / f"arena_{scene}_{weapon}_right_{tick:03}.png").convert("RGB")
                canvas.paste(im, (col * 384, row * 272 + 32))
                draw.text((col * 384 + 12, row * 272 + 4), f"{title} / {'Arena' if row == 0 else 'Woodland'}", font=font, fill=(244, 236, 214))
        frames.append(canvas)
    # One GIF palette keeps stationary terrain stable between frames and avoids palette flicker around halos.
    samples = Image.new("RGB", (1152, 544 * 4))
    for row, index in enumerate((0, 8, 16, 24)):
        samples.paste(frames[index], (0, row * 544))
    palette = samples.quantize(colors=256)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(OUT / "glow_particles_live.gif", save_all=True, append_images=indexed[1:], duration=40, loop=0, disposal=2, optimize=True)
    frames[8].save(OUT / "glow_particles_contact.png")
    katana = []
    large_font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 22)
    for tick in range(90):
        close = Image.new("RGB", (1056, 424), (28, 24, 36))
        d = ImageDraw.Draw(close)
        for col, scene in enumerate(("arena", "road")):
            image = Image.open(RAW / f"arena_{scene}_black_katana_right_{tick:03}.png").convert("RGB")
            zoom = image.crop((48, 48, 312, 240)).resize((528, 384), Image.Resampling.NEAREST)
            close.paste(zoom, (col * 528, 40))
            d.text((col * 528 + 16, 6), "Katana - " + ("arena" if scene == "arena" else "woodland"), font=large_font, fill=(244, 236, 214))
        katana.append(close)
    swatches = Image.new("RGB", (1056, 424 * 4))
    for row, index in enumerate((0, 8, 48, 50)):
        swatches.paste(katana[index], (0, row * 424))
    kp = swatches.quantize(colors=256)
    close_indexed = [frame.quantize(palette=kp, dither=Image.Dither.NONE) for frame in katana]
    close_indexed[0].save(OUT / "katana_alignment_v2.gif", save_all=True, append_images=close_indexed[1:], duration=40, loop=0, disposal=2, optimize=True)
    katana = []
    large_font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 22)
    for tick in range(90):
        close = Image.new("RGB", (1056, 424), (28, 24, 36))
        d = ImageDraw.Draw(close)
        for col, scene in enumerate(("arena", "road")):
            image = Image.open(RAW / f"arena_{scene}_dual_dagger_right_{tick:03}.png").convert("RGB")
            zoom = image.crop((48, 48, 312, 240)).resize((528, 384), Image.Resampling.NEAREST)
            close.paste(zoom, (col * 528, 40))
            d.text((col * 528 + 16, 6), "Dual Daggers - " + ("arena" if scene == "arena" else "woodland"), font=large_font, fill=(244, 236, 214))
        katana.append(close)
    swatches = Image.new("RGB", (1056, 424 * 4))
    for row, index in enumerate((0, 8, 48, 50)):
        swatches.paste(katana[index], (0, row * 424))
    kp = swatches.quantize(colors=256)
    close_indexed = [frame.quantize(palette=kp, dither=Image.Dither.NONE) for frame in katana]
    close_indexed[0].save(OUT / "daggers_alignment.gif", save_all=True, append_images=close_indexed[1:], duration=40, loop=0, disposal=2, optimize=True)
    katana = []
    large_font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 22)
    for tick in range(90):
        close = Image.new("RGB", (1056, 424), (28, 24, 36))
        d = ImageDraw.Draw(close)
        for col, scene in enumerate(("arena", "road")):
            image = Image.open(RAW / f"arena_{scene}_chain_scythe_right_{tick:03}.png").convert("RGB")
            zoom = image.crop((48, 48, 312, 240)).resize((528, 384), Image.Resampling.NEAREST)
            close.paste(zoom, (col * 528, 40))
            d.text((col * 528 + 16, 6), "Chain Scythe - " + ("arena" if scene == "arena" else "woodland"), font=large_font, fill=(244, 236, 214))
        katana.append(close)
    swatches = Image.new("RGB", (1056, 424 * 4))
    for row, index in enumerate((0, 8, 48, 50)):
        swatches.paste(katana[index], (0, row * 424))
    kp = swatches.quantize(colors=256)
    close_indexed = [frame.quantize(palette=kp, dither=Image.Dither.NONE) for frame in katana]
    close_indexed[0].save(OUT / "scythe_alignment.gif", save_all=True, append_images=close_indexed[1:], duration=40, loop=0, disposal=2, optimize=True)
    print("Saved live 6-panel glow/particle GIF (slowed 2.4x for review), no runtime pixels resized")


if __name__ == "__main__":
    main()

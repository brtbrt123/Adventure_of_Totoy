"""Stitch a new layered-scene floor out of the existing forest floors' own pixels (texture by numbers).

The owner rejected the first Rootcrown floor because it did not match the other scenes. This tool makes a floor that
matches by construction: every output pixel is copied from an approved forest floor (Root Hollow, Woodland Approach,
Hollow Trial), so the grass, the dirt, the fringe where they meet, the texture density and the palette are theirs.

How: the target is a label map (True = dirt, False = grass). The output is filled with overlapping square patches in
scan order (image quilting, Efros and Freeman 2001). Each patch is chosen from every source position by two costs: how
well its dirt/grass labels match the target's labels there, and how well it continues the pixels already placed in the
overlap. A minimum-error cut through the overlap hides the seam. Patches used recently cost more, so no corner repeats.

The source labels come from the colours (dirt is brown: red above green), smoothed so tufts and grit do not count.

Depth (optional `shade`): a target brightness per pixel, 0 = the darkest grass of the sources, 1 = the lightest (their grass runs
from deep shade under the trees to sunlit tufts; their dirt is nearly flat). Patches are then also chosen by how close their mean
brightness is to the target, so shade falls where the map wants it, still made only of the sources' own pixels. NaN = no wish.

Library use (see tools/art/make_rootcrown_v2_preview.py):
    from quilt_ground import load_sources, quilt
    rgb = quilt(target_label_bool_array, load_sources(), seed=7)
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FLOORS = [
    ROOT / "presentation" / "forest" / "root_hollow_layered_ground.png",
    ROOT / "presentation" / "forest" / "woodland_approach_ground.png",
    ROOT / "presentation" / "forest" / "hollow_trial_layered_ground.png",
]


LUM_DARK, LUM_LIGHT = 62.0, 100.0  # mean patch brightness of the sources' darkest and lightest grass (5th/95th percentile)


def box_mean(a: np.ndarray, r: int) -> np.ndarray:
    """Mean of a 2D array over a (2r+1) square window, edges clamped."""
    p = np.pad(a.astype(np.float64), r, mode="edge")
    c = p.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    h, w = a.shape
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return s / (k * k)


def dirt_label(rgb: np.ndarray, alpha: np.ndarray | None = None) -> np.ndarray:
    """True where the floor is dirt (brown: red channel above green), smoothed over a 9x9 window."""
    r = rgb[..., 0].astype(np.int32)
    g = rgb[..., 1].astype(np.int32)
    raw = (r > g).astype(np.float64)
    lab = box_mean(raw, 4) > 0.5
    if alpha is not None:
        lab &= alpha > 0
    return lab


def load_sources(paths: list[Path] | None = None) -> list[tuple[np.ndarray, np.ndarray, np.ndarray]]:
    """(rgb uint8 HxWx3, dirt label bool HxW, usable bool HxW) for each floor."""
    out = []
    for p in paths or FLOORS:
        im = Image.open(p).convert("RGBA")
        a = np.asarray(im)
        rgb = a[..., :3].copy()
        usable = a[..., 3] == 255
        out.append((rgb, dirt_label(rgb), usable))
    return out


def _candidates(sources, P: int, O: int, stride: int):
    """Every usable P x P source window: its pixels, labels and the left/top overlap strips as flat float rows."""
    pix, lab, where = [], [], []
    for si, (rgb, lb, ok) in enumerate(sources):
        h, w = lb.shape
        for y in range(0, h - P + 1, stride):
            for x in range(0, w - P + 1, stride):
                if not ok[y:y + P, x:x + P].all():
                    continue
                pix.append(rgb[y:y + P, x:x + P])
                lab.append(lb[y:y + P, x:x + P])
                where.append((si, x, y))
    pix = np.stack(pix)                                                    # N,P,P,3 uint8
    n = len(pix)
    lab = np.stack(lab).astype(np.float32).reshape(n, P // 4, 4, P // 4, 4).mean((2, 4))  # N,P/4,P/4 dirt share
    left = pix[:, :, :O, :].reshape(n, -1).astype(np.float32)             # N, P*O*3
    top = pix[:, :O, :, :].reshape(n, -1).astype(np.float32)              # N, O*P*3
    lum = (pix.astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32)).mean((1, 2))
    lum = np.clip((lum - LUM_DARK) / (LUM_LIGHT - LUM_DARK), 0.0, 1.0)     # 0 darkest grass .. 1 lightest
    return pix, lab, left, top, where, lum


def _min_cut_vertical(err: np.ndarray) -> np.ndarray:
    """err: P x O. Returns a P x O bool mask, True where the NEW patch wins (right of the cheapest top-to-bottom path)."""
    h, w = err.shape
    cost = err.copy()
    back = np.zeros((h, w), dtype=np.int64)
    for y in range(1, h):
        for x in range(w):
            lo, hi = max(0, x - 1), min(w, x + 2)
            k = lo + int(np.argmin(cost[y - 1, lo:hi]))
            back[y, x] = k
            cost[y, x] += cost[y - 1, k]
    mask = np.zeros((h, w), dtype=bool)
    x = int(np.argmin(cost[-1]))
    for y in range(h - 1, -1, -1):
        mask[y, x:] = True
        x = back[y, x]
    return mask


def quilt(target: np.ndarray, sources, seed: int = 1, P: int = 32, O: int = 10, stride: int = 4,
          label_weight: float = 6.0, reuse_penalty: float = 0.6, choose_from: int = 6,
          shade: np.ndarray | None = None, shade_weight: float = 3.0) -> np.ndarray:
    """Fill an image the size of `target` (bool, True = dirt) with patches of the sources. Returns uint8 HxWx3."""
    rng = np.random.default_rng(seed)
    H, W = target.shape
    pix, lab, left, top, where, lum = _candidates(sources, P, O, stride)
    n = len(pix)
    lab_flat = lab.reshape(n, -1)
    lab_sq = (lab_flat ** 2).sum(1)
    left_sq = (left ** 2).sum(1)
    top_sq = (top ** 2).sum(1)
    step = P - O
    nx = int(np.ceil((W - P) / step)) + 1
    ny = int(np.ceil((H - P) / step)) + 1
    Wp, Hp = (nx - 1) * step + P, (ny - 1) * step + P
    tgt = np.zeros((Hp, Wp), dtype=np.float32)
    tgt[:H, :W] = target
    tgt[H:, :] = tgt[H - 1:H, :] if H < Hp else 0
    tgt[:, W:] = tgt[:, W - 1:W]
    out = np.zeros((Hp, Wp, 3), dtype=np.float32)
    used = np.zeros(n, dtype=np.float32)
    for j in range(ny):
        for i in range(nx):
            x, y = i * step, j * step
            t = tgt[y:y + P, x:x + P].reshape(P // 4, 4, P // 4, 4).mean((1, 3)).reshape(-1)
            mism = (lab_sq + (t ** 2).sum() - 2.0 * (lab_flat @ t)) / t.size    # mean squared label difference
            cost = label_weight * mism
            if shade is not None:
                want = shade[y:min(H, y + P), x:min(W, x + P)]
                if want.size and not np.isnan(want).all():
                    cost = cost + shade_weight * (lum - float(np.nanmean(want))) ** 2
            ov = 0.0
            if i > 0:
                s = out[y:y + P, x:x + O, :].reshape(-1)
                cost = cost + (left_sq - 2.0 * (left @ s) + (s ** 2).sum()) / (s.size * 255.0 ** 2) * 40.0
                ov += 1
            if j > 0:
                s = out[y:y + O, x:x + P, :].reshape(-1)
                cost = cost + (top_sq - 2.0 * (top @ s) + (s ** 2).sum()) / (s.size * 255.0 ** 2) * 40.0
                ov += 1
            cost = cost + reuse_penalty * used
            best = np.argpartition(cost, choose_from)[:choose_from]
            k = int(rng.choice(best))
            used *= 0.995
            used[k] += 1.0
            patch = pix[k].astype(np.float32)
            mask = np.ones((P, P), dtype=bool)
            if i > 0:
                e = ((out[y:y + P, x:x + O, :] - patch[:, :O, :]) ** 2).sum(2)
                mask[:, :O] &= _min_cut_vertical(e)
            if j > 0:
                e = ((out[y:y + O, x:x + P, :] - patch[:O, :, :]) ** 2).sum(2)
                mask[:O, :] &= _min_cut_vertical(e.T).T
            region = out[y:y + P, x:x + P, :]
            region[mask] = patch[mask]
    return out[:H, :W, :].round().astype(np.uint8)

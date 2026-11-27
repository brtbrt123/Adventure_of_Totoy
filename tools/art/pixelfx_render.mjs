// Renders one PixelFX effect with a margin round its canvas (PixelFX's own tools/render.mjs has none, so a turned effect is cut off
// at its canvas edge) and writes its sprite sheet and JSON, the pivot moved by the margin. Used by tools/art/import_pixelfx.py.
//   node tools/art/pixelfx_render.mjs <pixelfx checkout> <effect id> <out dir> <margin px> <options JSON>
// It only calls the checkout's own tools/lib/fxlib.mjs (loadEffect, renderFrames, spriteSheet, save); nothing else.

import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [dir, id, out, margin, opts] = process.argv.slice(2);
const lib = await import(pathToFileURL(join(dir, "tools", "lib", "fxlib.mjs")).href);
const fx = await lib.loadEffect(id);
const m = Number(margin);
const r = lib.renderFrames(fx, { bg: "none", margin: m, options: JSON.parse(opts) });
const name = id.split("/")[1];
const sheet = lib.spriteSheet(fx, r, name);
sheet.json.meta.pixelfx.pivot = [fx.meta.origin[0] + m, fx.meta.origin[1] + m];
lib.save(join(out, `${name}.png`), sheet.png);
lib.save(join(out, `${name}.json`), JSON.stringify(sheet.json));
console.log(`${id}: ${r.n} frames ${r.w}x${r.h}, pivot ${sheet.json.meta.pixelfx.pivot}`);

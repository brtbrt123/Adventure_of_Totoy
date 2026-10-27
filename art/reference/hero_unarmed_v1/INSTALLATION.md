# Approved unarmed hero installation — 2026-10-27

Owner approved the existing sheet. All18 normalized review frames were copied into art/src without changing pixel grids:6idle,6walk,6dash;40x40canvas,feet anchor20,35. Source header now records approved provenance. Existing hero2/dagger/lightning/scythe sources were preserved.

Exploration chooses the new set solely from snapshot.armed=false. Tovan's actual first-sword grant switches to existing armed poses immediately; save/legacy-armed behavior stays core-owned. Parry-success pose override is armed-only. The arena animation tables remain unchanged.

Art validate -> build -> preview passed. Godot editor import and expanded first-sword receipt smoke passed (all18frames, real unarmed walk/dash, immediate handover switch and armed reload). Full harness regression passed: Python suites, Godot import, all core tests and every presentation smoke suite. Log: art/build/arena_unarmed_full_regression.log (ignored). Expanded first-sword receipt and exploration smoke tests also passed independently. Runtime captures passed in both villages. Runtime captures in runtime/ use actual core events and no persistent player save. Human has approved sheet appearance; in-game motion/feel remains for playtest. Concurrent architecture edit and chapter plan left untouched. No core/tools/data changes.

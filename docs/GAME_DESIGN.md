# Adventure of Totoy

Game design draft · 15 October 2026 · private portfolio project

## The promise

A top-down, story-driven action fantasy game set in a lively pixel-art valley. The player travels between a safe village and dangerous regions, learns the tells of powerful enemies, and turns abilities taken from monsters into a personal fighting style. Six main-story bosses guard the path to the valley's heart. Side quests lead to mini-bosses, new Aspects, artifacts, and stories about the people who live there.

The intended deliverable is a **private Windows desktop application** and portfolio case study. There is no public release or store launch planned. The six-boss story is the full design vision; the first portfolio milestone is a polished, complete-feeling vertical slice.

The game should feel inviting to explore and demanding to master. Its combat identity is simple to read: **gold heavy attacks can be parried; red attacks must be dodged.** A good parry sparks, breaks posture, and opens a short counter window. Dash is available with every weapon.

This is a 2D, top-down game built on a **16×16 tile grid**. Ordinary characters may use 16×24 or 32×32 sprites, and bosses may span many tiles. The grid sets the visual rhythm; it does not force every creature into 16 pixels.

## Story: the valley that forgot its seasons

The village of **Lanternfen** sits beside the Heartloom, an ancient living mechanism that carries warmth, rain, growth, and memory through the valley. Every year the villagers hold the Night of Returning Lights, when six beacons answer one another across the land. This year only one answers. Strange weather spreads, animals become Aspect creatures, and familiar paths lead somewhere else.

**Totoy** is a young Waykeeper returning to Lanternfen with a broken beacon key and no memory of the night the Heartloom failed. The village's mapmaker, **Mira**, helps trace the six missing beacon songs. **Tovan**, the smith, studies weapons and artifacts found along the route. **Edda**, an Aspect keeper, teaches Totoy to bind a fragment of a monster's power without destroying what remains of it. These three give Totoy reasons to return home between expeditions.

The six guardians were once protectors of the Heartloom. Each has been twisted by a different failure in the valley. Defeating one restores its beacon and changes the world: a crossing opens, weather clears, an NPC returns, or a new area becomes safe enough to explore. After the fifth beacon, the player learns that the **Starless Regent** stopped the Heartloom deliberately. The old system demanded a guardian's life to keep the valley whole. The Regent chose to break it rather than sacrifice another person. That choice saved one life and endangered everyone else.

In the finale, the player gathers the six songs and builds a new Heartloom that shares its burden among the valley's people and Aspect creatures. The ending should pay off quests and relationships, while the main story remains understandable without completing every side quest.

### Main-story chapters

| Chapter | Region and story beat | Main boss | Fight lesson | World change |
| --- | --- | --- | --- | --- |
| 1. Roots | Lanternfen outskirts; discover the broken key | **Mossbound Colossus** | Gold slam parry, red sweep and shard dodge | Restore the forest beacon; paths through the briars open |
| 2. Tides | Flooded orchard; find the first missing Waykeeper record | **Glass-Tide Serpent** | Curving projectiles and shifting safe ground | Water recedes; old village route returns |
| 3. Ash | Ember quarry; learn the beacons were built by people | **Cinder Matriarch** | Heat zones, delayed explosions, close-range counters | Forge relights; artifact crafting unlocks |
| 4. Storm | Bellspire heights; follow Mira's map into lost ruins | **Storm Bell Knight** | Rhythm changes, lightning lanes, dash timing | Mountain lift and distant signals return |
| 5. Memory | Pale-root sanctuary; recover the truth of the player's past | **Pale Root Monarch** | Illusions with readable real attack cues | Fifth song reveals the Heartloom's cost |
| 6. Choice | Heartloom chamber; confront the Regent and repair the system | **Starless Regent** | Combines learned attack language, then changes tempo | Valley reaches a new balance; epilogue reflects side quests |

Each boss needs a clear entrance, three to five attacks at first, a short phase shift, a posture break, and a narrative aftermath. The sixth boss may have more attacks because it is the final exam. Boss difficulty should come from recognizable patterns and meaningful decisions, rather than surprise hits.

## Combat rules

- **Gold diamond:** a committed heavy attack. Its final windup slows briefly. A timed parry creates a spark and immediately breaks posture; an early deflection grants partial posture pressure. The player can still dash away.
- **Red warning:** basic strikes, beams, lasers, and projectiles. Parry does not cancel them. The player moves out of the indicated area or dashes through the danger window. Long beams remain harmful for their entire visible duration.
- **Posture break:** the boss exposes a weak point for a short, visible window. A counter deals much more damage than ordinary attacks. The opening must be long enough to reach the boss without requiring perfect positioning.
- **Dash:** quick directional movement with brief invulnerability, a distinct trail, and a readable cooldown. Every weapon has it.
- **Normal hits:** useful for pressure and finishing weakened enemies, but inefficient against armored bosses until posture breaks. Regular mobs can take normal damage so travel fights stay brisk.
- **Fair tells:** color is paired with shape, text/icon, and sound. The warning area must match the real hit area. An enemy cannot change its aim after the attack is committed.

## The first three weapons

All three use the same movement, dash, gold parry, and red dodge language. Their unique mechanic changes what the player does *between* defensive moments.

| Weapon | Unique mechanic | Parry reward | Strength and cost |
| --- | --- | --- | --- |
| **Sword** | **Edge:** close attacks build Edge; a counter spends it on a longer riposte that cuts through armor. | Gains Edge and closes distance with a short riposte step. | Direct posture-focused duels; must stay near danger. |
| **Bow** | **Tension:** hold to draw, release in a narrow timing band for a piercing shot. A dashed shot marks a target so the next arrow curves slightly toward it. | Instantly readies one full-draw arrow during the opening. | Precise ranged control; weak damage from rushed shots. |
| **Staff** | **Sigils:** alternate quick casts and placed sigils. Casting through a sigil changes the spell: wider burst, chained hit, or protective pulse depending on the equipped Aspect. | Charges the next sigil without its usual cast time. | Space control and Aspect combinations; setup takes time. |

The starting choice is a preference, not a permanent class. The player can switch weapons at Lanternfen checkpoints and eventually carry two in the field. Each gets a small upgrade tree focused on its mechanic. Avoid giving the sword a better bow or the staff a universal answer to every attack.

## Aspects: monster powers for skill slots

An **Aspect** is a learnable ability associated with a monster family. Defeating an Aspect creature can drop its fragment. The first fragment of a family guarantees the base skill; later fragments improve it or craft a variant. This avoids a rare drop blocking a build or quest.

The player equips **two active Aspect skills and one passive** at a checkpoint. Skills use a shared focus meter earned through combat, with modest gains from well-timed defensive actions. An Aspect must work with all three weapons, though a weapon can express it differently through Edge, Tension, or Sigils.

| Aspect creature | Base skill | Combat purpose |
| --- | --- | --- |
| Ember Moth | **Cinder Step:** dash leaves a short-lived burning trail | Area denial and dash offense |
| Mire Toad | **Bog Anchor:** place a slowing patch | Hold a lane or protect a cast |
| Glass Heron | **Mirror Pin:** mark one enemy; the next hit repeats for reduced damage | Reward precision |
| Thunder Ram | **Storm Pulse:** release a small radial stun on non-boss foes | Create breathing room |
| Pale Fox | **Veil Double:** leave an illusion after dashing | Reposition against groups |
| Root Stag | **Bramble Guard:** gain a small shield after a successful parry | Defensive build choice |

Bosses may grant a special Aspect upgrade, but the ordinary monster family provides the base skill. The player should understand what dropped, what it does, and where to equip it within a few seconds.

## Artifacts and progression

Artifacts are equippable drops that modify stats or one clear rule. Start with **two artifact slots** and expand to three through the story. Examples: a charm that adds a small health buffer, a ring that shortens dash cooldown, and a bell that extends the posture opening. Stat boosts should be modest; most power should come from learning attacks and combining weapon and Aspect mechanics.

Every named mini-boss guarantees a distinct first-clear artifact. Repeat kills can grant crafting material. Main bosses unlock story progress and a related upgrade. Ordinary monsters provide Aspect fragments and materials. This keeps rewards predictable enough for a story game and still gives players reasons to explore.

Four first side-quest mini-bosses:

| Quest | Mini-boss | Reward | Story purpose |
| --- | --- | --- | --- |
| The Missing Lanterns | **Briar Warden** | Lantern Charm: wider parry spark visibility | Introduces how the forest changed |
| The Ferry That Won't Return | **Drowned Bellkeeper** | River Stone: small dash cooldown reduction | Reopens an optional crossing |
| Coals for Tovan | **Ashback Boar** | Smith's Coal: small normal-hit boost | Gives the smith a personal quest |
| The Last Map | **Echo Cartographer** | Compass Thread: longer posture opening | Explains the false paths near Bellspire |

## World, quests, and presentation

Lanternfen is a compact, friendly hub with a few recurring residents, changing dialogue, and visible improvements after each beacon. Regions branch from it through shortcuts. Each region needs one main route, a couple of secrets, a checkpoint, one small puzzle, and a story boss. Side quests should reveal a character or place and end with a concrete world change or reward. A quest log tracks location and next step without turning exploration into a line of markers.

The visual target is the cozy clarity of a farming-era pixel game: warm village interiors, readable paths, lively crops and water, and seasonal color changes. Combat areas use stronger silhouettes and restrained effects so attack cues remain obvious. Make original characters, environments, icons, and palettes; use **Stardew Valley as a feeling and readability reference**, not a source to copy. Start with 16×16 ground and wall tiles. Use larger sprite canvases for the player, weapons, and bosses. Nearest-neighbor integer scaling keeps pixels crisp.

Sound should carry gameplay information. Gold heavy attacks have a low, gathering cue; red attacks use a distinct warning; a successful parry has a sharp metal impact and ringing tail; posture breaks add a deeper crack; dash has a fast airy sweep. Music can soften in the village and rise in bosses without covering these signals.

## Build order and scope gates

1. **Combat vertical slice:** one room, Mossbound Colossus, sword, dash, parry, break, counter, and clear victory/defeat. Tune this through playtesting. The current browser prototype is a starting reference, not the final engine project.
2. **Godot foundation:** Godot 4 with typed GDScript, shared `AGENTS.md` and `CLAUDE.md`, `docs/` vault, 16×16 palette and tile rules, and a small validator. Decide the exact gameplay-to-presentation interface from the vertical slice.
3. **First explorable chapter:** Lanternfen, a short forest route, one Aspect creature, one mini-boss quest, and the Colossus. Add save/load and a minimal quest log here.
4. **Weapon comparison:** add bow and staff against the same forest encounters. Keep them only when their mechanics feel different and fair. Add switching and the first two Aspect slots.
5. **Chapter production:** build chapters 2–5 one at a time, including art, sound, side content, accessibility, and playtesting. Reuse combat systems and change encounter rules intentionally.
6. **Finale and polish:** chapter 6, story consequences, ending, balance, controller support, performance, and private playtest builds.

For each step, play the build before expanding scope. A useful first milestone is a **ten-minute forest chapter** that begins in Lanternfen, teaches dash and parry, awards one Aspect, and ends with the Colossus. The full game is a longer-term plan; estimate schedule only after this slice is fun and measurable.

### Portfolio deliverable

Package the vertical slice as a Windows executable with a simple title screen, save or restart flow, controls page, clear ending, and credits. Keep its source in a readable project repository. Prepare a short case study with screenshots or a brief gameplay video showing the three weapon mechanics, an Aspect skill, the dash/parry language, the boss encounter, and what was learned through playtesting. Share the build directly with reviewers when desired; a store page is unnecessary.

The portfolio version should be judged by **feel, clarity, completion, and presentation**, rather than by how many planned chapters are implemented. The full six-boss plan remains a roadmap after the slice proves itself.

## Decisions to test early

- How generous should the gold parry window feel on keyboard and controller?
- Can bow and staff parry feel as natural as sword parry while keeping distinct rewards?
- How many ordinary enemies can be on screen before red warnings overlap?
- Should the player switch two weapons during combat or only at checkpoints in the first release?
- Does a two-second counter opening give all three weapons enough time to respond?

These are playtest questions, not prerequisites for starting the vertical slice.

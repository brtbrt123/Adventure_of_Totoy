# Chapter 1 road story: Lanternfen to the Stag Glade (PROPOSAL)

Status: **draft for the owner** (2026-11-03, Claude). The owner asked: "why the story is only to the village then on other
scene its all fighting" and "write a proposal upto stag glade". Nothing here is in the game. Everything follows
`docs/GAME_DESIGN.md` and `docs/CHAPTER1_PLAN.md` and invents only the small things marked **(new)**; the owner rewrites freely.
Lines stay under 110 characters, like `data/dialogue/chapter1.json`.

## The thread: follow the blue light

The village gives three hooks that the road never picks up: the child saw **a blue light in the forest, "not a lantern"**,
Mira says the cracked key is **"still humming"**, and Totoy **remembers nothing** of the night the Heartloom failed.
The road story pays them off one scene at a time:

1. **Woodland Approach:** Totoy finds **his own camp** from that night, with a note in his own hand he does not remember writing.
2. **Forest Route:** lighting the two lanterns warms the key and brings back **one memory** (two pictures, no answers).
3. **Root Hollow:** an old **Waykeeper shrine** reads the key: five beacon marks dark, the forest's faintly blue, pulsing toward the glade.
4. **Hollow Trial** (optional): the place old Waykeepers proved themselves.
5. **Stag Glade:** the blue light is the **forest beacon's song**, which fled into the Thornback Stag when the beacon went dark.
   Edda binds it gently; the song runs along the crack in the key and the crack holds. The rest of the song is caught in the
   roots of the ruins, where the **Mossbound Colossus** sleeps.

Totoy stays silent, as in the village; the road speaks through **narration** (no speaker, like the intro cutscene),
**things he reads or looks at** ([E] READ / [E] LOOK), the key, and Edda at the end.

## Scene by scene

### 1. Woodland Approach (leaving home; the camp)

| When | What happens | Lines (draft) |
|---|---|---|
| Entering, first time | narration | The east road. The trees stand closer than you remember. / The key hums, and pulls east. |
| The sign (prop exists) | [E] READ | LANTERNFEN, WEST. THE OLD FOREST, EAST. / Under it, Mira's chalk: a lantern in a circle. A Waykeeper road. |
| Mossling Clearing cleared | narration | The Mosslings crumble to moss. Something faint and blue drifts out of them, and fades. |
| Abandoned Camp cleared, the bedroll | [E] LOOK | A cold fire ring. A bedroll. A pack with your name stitched inside. / This is your camp. |
| Same, the supplies | [E] LOOK | A note, in your own hand: "If I forget, follow the blue light. Do not let it go dark." |
| Boar Clearing | fight only | |

Objective after the note: **Follow the blue light into the forest.**

### 2. Forest Route (the lanterns; the first memory)

| When | What happens | Lines (draft) |
|---|---|---|
| The signpost (object exists, its text does not) | [E] READ | THE GLADE: PAST THE ROOT GATE. / Newer chalk under it: two lanterns, then the roots let go. M. |
| Mossling Trail, Boar Bend | fights | |
| First pedestal lit | narration | The lantern catches. The key grows warm in your hand. |
| Second pedestal lit | **memory flash** (cutscene, 2 pictures) | 1: Rain on the beacon hill. Six lights going out, one after another. |
| | | 2: A hand closes yours around the key. "Go, Waykeeper. Remember the way back." Then dark. |
| After the flash | the root gate opens (exists) | |
| The dead-end chest | herb (exists) | |

Objective: **Go through the root gate.** The hand's owner stays unknown (a seed for later chapters; see the questions).

### 3. Root Hollow (the old road; what the key is)

| When | What happens | Lines (draft) |
|---|---|---|
| Entering | narration | Roots have swallowed an old road. Its lanterns are older than Lanternfen. |
| Root Hollow, Overgrown Shrine | fights | |
| The shrine, after its fight | [E] LOOK | A Waykeeper shrine. In the stone, a slot the shape of your key. |
| | | You set the key in it. Six marks wake on the stone: five dark, one a faint, beating blue. |
| | | The blue pulses toward the south-east. Toward the glade. |
| The shed antlers (prop exists) | [E] LOOK | Shed antlers, scorched blue at the tips. |
| The barrier to the trial | [E] READ | Carved over the arch: WAYKEEPERS PROVE THEIR STEP HERE. |

Objective after the shrine: **Find the Thornback Stag.** The trial stays a side path (no objective).

### 4. The Hollow Trial (optional)

| When | What happens | Lines (draft) |
|---|---|---|
| The altar, before the trial | [E] READ | Three tides of the forest. Stand, and the Hollow answers. |
| Trial won | narration | The Warden kneels. Its stone eyes dim to the shrine's blue. The old Waykeepers set it here to test their own. |
| The chest | reward (exists; the owner picks the Aspect) | |

### 5. Stag Glade (the blue light; the first binding; the way on)

| When | What happens | Lines (draft) |
|---|---|---|
| Entering | narration | The blue light. It is here: in the standing stones, and in the antlers of the stag between them. |
| | | The key hums so loudly your hand shakes. |
| The fight | exists (gold slam, red charge, roots, the moth chant) | |
| After the fight | the Stag kneels **(new pose)**; **Edda** steps out from the root arch | |
| Edda | | Gently now. You did not kill it. Good. |
| | | Hold out the key. The blue in its antlers is not its own. It is the forest beacon's song. |
| | | When the beacon died, its song fled into the nearest heart that would hold it. This one. |
| Binding | narration + key glow **(new effect)** | The song leaves the antlers and runs along the crack in your key. The crack glows, and holds. |
| Edda | an Aspect is given (the owner picks) | And a fragment for you, freely given. Treat it as a loan. |
| | | The rest of the song is caught in the roots of the ruins past the arch. Something huge sleeps there. |
| | | The Mossbound Colossus. Go carefully, Waykeeper. I will tell Mira you are close. |
| The Stag | stands and walks into the root arch **(new)**, showing the way | |

Objective: **Enter the ruins past the arch.** (Then the Colossus, as planned.)

## The objective line after the village (the quest book's second half)

1. Take the east road. 2. Follow the blue light into the forest (after the camp note). 3. Light the two lanterns.
4. Go through the root gate. 5. Find the Waykeeper shrine. 6. Find the Thornback Stag. 7. Enter the ruins past the arch.

## What it needs (build list, after the owner's yes)

| Piece | Exists? | Work |
|---|---|---|
| Fights, lantern puzzle, root gate, chests, Hollow Trial, Stag | yes | none |
| Dialogue box, portraits, objective line and marker, scene banners | yes | none |
| [E] READ / [E] LOOK objects with text (sign, camp, shrine, antlers, arch, altar) | hint only | a "text" object kind that shows lines in the dialogue box (core data + presentation) |
| Narration on entering a scene or clearing an encounter, once | no | per-scene story triggers in the scene data |
| Quest book past the village | no | the 7 objectives above, with flags |
| Memory flash | the intro cutscene player exists | 2 new pictures (owner's art) |
| Stag aftermath | no | kneel and walk-away poses (art), Edda placed in the glade after the fight, key glow, Aspect grant (exists) |
| Line budget | 57 of 60 | this adds about 40 lines: raise the budget to about 100 |

## Questions for the owner

1. **Totoy silent** (narration, as proposed) or does he speak short lines?
2. **Which Aspect the Stag gives**: Edda already gives Sprint in the village. Echo Step, Stone Ward, or a new Stag Aspect?
3. **Edda in the glade**, or the binding without her (the key alone)?
4. **The memory flash**: how much to show. The hand on the key is a seed; whose hand it is stays secret for now.
5. **The camp note's words**, and the Hollow Trial chest's Aspect.
6. **The rune gate**: the intro, Mira's objective and the road's blocked message still name it, but the village gate was removed today.

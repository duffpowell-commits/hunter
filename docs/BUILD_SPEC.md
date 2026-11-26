# Hunter: build spec (for any coding AI starting cold)

Read this, then docs/DESIGN.md (story and content), then docs/style-guide.md (art). If DESIGN.md and this file disagree on story, DESIGN.md wins. If they disagree on how to build, this file wins. Anything marked TBD is still open. Use the placeholder shown and don't invent a final answer.

## Hard rules
- Godot 4.7.x only, 4.7.2-stable today (moved from 4.6.3 on Nov 24; Duff Nov 25: "Lets only build on 4.7", never downgrade), GDScript only, Compatibility renderer. Portrait 720x1280 base, `canvas_items` stretch, `expand` aspect. (Why 4.6.3: Duff asked which version fits his goals, Grok recommended 4.6.3 to match godot-game-starter, its CI and the latest Godot Android editor, and Duff confirmed "Yes, lock in 4.6.3" on Nov 21. This line said 4.5-stable before. docs/DECISIONS.md.)
  - Not a hard rule, Grok's choice pending Duff's review (Nov 21): `stretch/scale` 1.3333 in project.godot. The UI lays out on about 540x960 logical units, so the starter's buttons and text keep their size and touch targets stay at least 48 dp. Drop it if Duff wants a denser UI, and re-check `test_touch_targets`.
- Android APK first. Duff tests on his phone and edits in the Godot Android editor, so nothing may depend on desktop tools or C#/GDExtension.
- Milestone 0 is NOT written from scratch. Copy the whole of `duffpowell-commits/godot-game-starter` into this repo (everything except `.git`). Keep docs/ in this repo where names collide: this repo's AGENTS.md, CLAUDE.md, QUEUE.md, docs/DECISIONS.md, docs/PITCH.md and docs/style-guide.md win. Merge the starter's AGENTS.md commands and standing rules into this repo's AGENTS.md (CLAUDE.md imports it with `@AGENTS.md`). Take `.claude/hooks/guard.cfg` from the starter on purpose: it turns on the test gate. (Why, Nov 21: Hunter's rules now live in AGENTS.md, so copying the starter's over it would lose them.) Then set `config/name="Hunter"` in project.godot. The starter already provides CI + signed APK, in-app updater, version on title, REPORT A BUG, boot/intro/title/pause/game over flow, autosave/resume, settings, subtitles, colorblind keys, dev menu, autoplay bot. Do not rebuild any of it.
- Signing: the repo needs the `KEYSTONE_PASS` Actions secret (Duff adds it on github.com from his phone; docs/SIGNING.md in the starter). Without it CI signs with a throwaway key and APKs can't update in place.
- `scripts/game.gd` in the starter is a placeholder ("Orb Catch"). Replace its PLAY section with Hunter. Keep its pause, focus-out save, back-button and `debug_skip_level()` handling.
- Every screen uses `ui.gd` helpers. Every gameplay colour goes through `UI.key()` plus a shape cue. Every sound a player must notice also goes through `Subs.cue()`. Buttons are at least 72 base units, 18 apart.
- Save at every checkpoint with `Save.write(state())`. Bump `Save.VERSION` and migrate when the format changes.
- Extend `scripts/autoplay.gd` with one PASS line per feature below. CI must stay green: parse check, `tests/run_tests.gd`, autoplay.
- Content is data, not code: enemies, bosses, specials, loot, realms and trophies live in `data/*.json` (or `.tres` Resources). Adding a boss should mean adding data plus art, with no new engine code.
- Placeholder: CC0 low-poly models with the toon shader until the real models land in `assets/models/`. Never block gameplay work on art.
- Push after every chunk. Merge to main at the end of every milestone. Green PRs merge themselves.

## Camera, view and animation (Duff, Nov 20: "full range of movement")
- **Characters are real-time 3D, not 2D sprites.** Duff rejected stills that bob and tilt. Every character needs real limb animation: walk and run in any direction (360°, not 4 or 8 facings), plus attacks, specials, dodge, hit, knockdown and death.
- Look (LOCKED by Duff, Nov 20): the "ink and blood" style on 3D models. Details: docs/style-guide.md. Use a toon shader (2 or 3 hard light bands, no gradients) plus a thick black outline (inverted hull or a screen-space outline that keeps the same width on screen), flat colours, and an orange demon rim light on the hero. Reference clip: docs/art/ink-3d/full_movement_3d_ink_test.mp4 (Duff: "Excellent"). It's a stand-in robot model; the technique is what counts.
- Engine: Godot 4.7.2 Compatibility renderer (4.7.x only; see Hard rules): `CharacterBody3D` + `AnimationTree` (blend space for idle/walk/run by speed, one-shots for attacks), low-poly skinned meshes (under ~5k tris each), one directional light + ambient. The world is 3D too (simple floor and props) so the camera angle stays consistent.
- Animations: start from a CC0 humanoid animation library (for example Quaternius "Universal Animation Library", CC0, glTF) retargeted in Godot to every humanoid, so walk/run/punch/kick/dodge/hit/death come free. Boss specials get extra clips on the same skeleton. No paid assets without Duff's OK.
- Models: start with CC0 low-poly humanoids recoloured per character (hoodie hero, robed zealots, suited Gus). Later, swap in models made from the Foxboard concept art (image-to-3D pipeline in the Chaos/DuffQuest repos) on the same skeleton. Never block gameplay on final models.
- Camera: a fixed high three-quarter angle (about 50° down), following the player with slight look-ahead. Same angle in and out of combat. No player camera rotation.
- Hit feel: 60 ms hit-stop, a white flash on the victim, small camera shake, spark particles.

## Controls (portrait, one thumb each side)
- Left half of the screen: floating virtual stick for moving. Left-handed setting mirrors the halves.
- Right half: the action pad.
  - Tap = light attack. Three taps in rhythm = light string (L, L, L). The third hit knocks back.
  - Press and hold 0.3 s, then release = heavy attack (guard break).
  - Swipe = special. Four directions: up, down, toward the target, away from it. Each equipped voice owns one or two swipe slots (see Voices).
  - Double-tap = dodge roll with i-frames (0.25 s, 0.6 s cooldown).
  - INTERACT / SCAVENGE / FINISH appear as a context button above the pad when relevant.
- Combos: a special swiped within 0.35 s of a landed light or heavy hit "cancels" into it and gets +25% damage. Show the combo count on screen (it does not feed corruption: that was cut).
- No quarter-circle motions, no buttons smaller than `UI.MIN_TOUCH`.

## Pipeline rules (lessons from another AI-built 3D jam game, Nov 20)
- **Motion comes from the animation library, never hand-written.** Don't animate limbs in code (tweens, sine bobs): Duff rejected that look, and so did the other team. Give each character personality by tuning the shared clips (playback speed, stride, a 5-10% scale on specific bones, extra idle fidgets), not by keying new ones.
- **Every imported model is normalised on import.** 1 unit = 1 m. Transforms applied. Root/armature scale 1 (watch for 100x cm-scale roots: the CC0 test robot came in about 149 units tall). Feet at y=0, facing +Z (glTF standard, matches the template mannequin and Character3D; see GROK_STANDARDS.md). Rest pose checked. A test in `tests/run_tests.gd` loads every `assets/models/*.glb`, plays idle, run and an attack, and asserts the height is within 10% of the target and the feet stay within 5 cm of the floor through each clip. CI fails otherwise.
- **Texture import settings are explicit.** Colour maps are sRGB, never flagged as normal maps; mobile-friendly compression (ETC2/ASTC via the Compatibility renderer defaults). A test checks every albedo's `.import` file.
- **Never ask a generator for a "seamless tile".** Generate one large surface and make the seams in code (offset and blend), or use flat ink colours with drawn crack decals, which suits the style better anyway.
- **Controls legend: follow GROK_STANDARDS.md** (it shows once a key or pad is used; no text walls). The swipe pad is gesture-only, so touch players also get short one-time contextual hints the first time each gesture matters ("Swipe toward him: special", "Double-tap: dodge"), routed through `Subs`, and a gesture card in the pause menu.
- **Directing, not grinding.** One milestone at a time, merged with a green CI and an autoplay PASS before the next starts. No parallel coding sessions on the same files.

## Core loop
Lair (hub) -> map room: pick a realm and a target -> realm: explore, scavenge, stalk -> fight the target -> finisher choice -> scavenge the scene -> portal home -> lair: craft, place trophy, talk to voices and Furfur -> next target.

## Systems (with starting numbers; tune later)

### Player
- HP 100. Stamina is not used. Dodge has a cooldown instead.
- Light 8 dmg, heavy 20 dmg. Specials 15-35 dmg (per data).
- Heat 0-100 (see Heat). Corruption 0-100 (see Corruption).

### Stalking (out of combat)
- Each target has a "studied" meter 0-100. It fills while the target is on screen and within 6 tiles, and you're not in its view cone (60°, 5 tiles). It fills faster while crouched (hold the stick lightly = sneak walk, half speed).
- Being seen resets the meter and starts the fight normally.
- At 100: the context button shows AMBUSH. The fight starts with the target staggered and your first special free (no cooldown).

### Bosses
- Each boss has 2 phases (3 for Price), a moveset of 3 specials (DESIGN.md), and telegraphs of 0.5 s or more with a red `UI.key("bad")` flash plus a shape cue.
- At 0 HP the boss kneels and the FINISH button shows two choices:
  - CLEAN: an intact trophy + crafting parts. Corruption +5.
  - BRUTAL: +1 extra special slot level for that voice. Corruption +15. Fewer parts.
- After the finisher: EAT (always). The boss becomes a voice.

### Voices (eaten bosses)
- Equip up to 2 voices (4 swipe slots total). Swap them in the lair, not in the field.
- Each voice line shows in a dialogue box at the top of the screen (portrait plus name plus text, 3 s or tap to dismiss), routed through `Subs`. Trigger voice lines on fight start, low HP, a big combo, a boss kill and lair visits. Keep the lines in `data/voices/<id>.json`.
- Grudge: a voice whose grudge is active has its specials locked (greyed with a padlock shape). Doing its revenge quest unlocks them for good.

### Improvised weapons
- Weapons are picked up in the realm (pipe, chair, chain, etc.). Each has 3-5 durability, and each hit costs 1.
- When durability hits 0, the next hit breaks it as a combo ender: x2.5 damage and a big knockback. Then you're unarmed until you scavenge another.
- Unarmed is always available. Weapons come from loot tables per realm.

### Scavenging and crafting (kept simple, no combos)
- Searchable objects in realms (glowing outline + magnifier shape). Tap SCAVENGE: a 1 s hold-to-search ring, then loot drops into inventory.
- Inventory: a grid of 24 slots, with stacks.
- Crafting in the lair workshop: recipe list, tap to craft if you have the parts. Recipes are data. Starting set: weapon upgrades (+durability), traps for lair defence, healing items.

### Heat
- Rises when you take collection plates, search noisily or leave bodies. Falls by 10 per night in the lair.
- At 70+, the next return home triggers a LAIR RAID: a wave fight in the lair where your placed traps fire. Lose and you lose some stored parts, not the save.

### Corruption
- 0-100. Rises with brutal finishers, eating bosses (+10 each) and venting on Furfur. Falls only through story choices (TBD with endings).
- It visibly changes the lair (3 looks: 0-33, 34-66, 67-100) and the player model's tint and horns.
- It decides the ending band (see Endings, TBD).

### Lair (hub)
- One screen, scrolling vertically. Rooms unlock over the game: Trophy wall (start), Furfur's cage (after his intro), Workshop, Cold room (stored parts), Map room (realm portals).
- Trophy wall: a grid of slots (start with 6). Each trophy gives a perk depending on the slot row (row 1 = offence, row 2 = defence, row 3 = utility). Moving a trophy is free in the lair.
- Furfur: a talk menu (lore, contract clauses for small mercies). VENT is available only after a real failed hunt, and unlocks one combo string per real failure (track a `failures_unvented` counter, so it can't be farmed).

### Price's contract
- An inventory item. Opening it shows clauses. Hidden clauses are revealed by story flags (Furfur leaks, Price fight loopholes). Store it as data plus save flags.

## Milestones (one at a time, each ends merged to main with a working APK)
- **M0 Foundation**: copy the starter as above, rename, CI green, the APK installs, the autoplay passes. Title shows "HUNTER" (working title).
- **M1 Movement and combat feel**: one 3D test arena with the toon/outline shader. Player model with full 360° walk/run blend and real attack animations, virtual stick, the light/heavy/dodge/special swipe pad, 1 dummy enemy type, 1 improvised weapon with breaking, combo counter, hit-stop (60 ms) and screen shake. Autoplay: move, light string, special, weapon break.
- **M2 The Pews and Vesper (vertical slice)**: the Pews realm (one map), zealots plus a choir buff enemy, collection-plate hazard, scavenging, Vesper boss (2 phases, Sermon/Flock/Laying of Hands), stalking/ambush, CLEAN vs BRUTAL finisher, EAT, Vesper as the first voice with dialogue boxes. Portal home.
- **M3 The lair**: hub with the trophy wall, workshop crafting, map room, voice equip, Heat, a lair raid, Corruption tint. Save and resume all of it.
- **M4 Furfur** (built Nov 26): the lost-hunt intro, the home-invasion fight, the cage, the talk menu, VENT gated on real failures.
- **M5+**: one realm and boss per milestone in the order Casino (Gus) -> Quarry (Rook) / Ballroom (Ines) -> Nursery (Hollis) -> Price & Partners (Price, specials-void "objection" zones, loophole counters). Then endings.

## File layout to aim for
- `scenes/` boot, intro, title, game (starter) + `lair.tscn`, `realm.tscn` (one scene, loads realm data), `combat/`.
- `scripts/` starter autoloads + `player.gd`, `enemy.gd`, `boss.gd`, `voice.gd`, `inventory.gd`, `crafting.gd`, `lair.gd`, `realm.gd`, `heat.gd`, `corruption.gd`, `swipe_pad.gd`, `virtual_stick.gd`.
- `data/` `realms.json`, `enemies.json`, `bosses.json`, `specials.json`, `loot.json`, `recipes.json`, `trophies.json`, `voices/*.json`.
- `assets/models/<id>.glb` (skinned, shared humanoid skeleton), `assets/anims/` (the shared animation library), `shaders/toon.gdshader`, `shaders/outline.gdshader`. 2D art (`assets/art/`) only for UI, portraits in the voice dialogue boxes, and the trophy wall.

## Still open (Duff decides; use the placeholder until then)
- Protagonist name: **Cain Vantre** (Duff, Nov 26, 2026; "Cain Mercer" was dropped because it echoes Alex Mercer of Prototype, whose powers also come from eating enemies). Use it in text; the title is "The Devil You Owe".
- Mom's name and past: TBD. Placeholder `MOM`.
- The rival hunter/detective: TBD (not before M5).
- Endings: TBD (not before M5).
- Game title: **The Devil You Owe**.

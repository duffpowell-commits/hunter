# Hunter: build spec (for any coding AI starting cold)

Read this, then docs/DESIGN.md (story and content), then docs/style-guide.md (art). If DESIGN.md and this file disagree on story, DESIGN.md wins. If they disagree on how to build, this file wins. Anything marked TBD is still open. Use the placeholder shown and don't invent a final answer.

## Hard rules
- Godot 4.5-stable, GDScript only, Compatibility renderer. Portrait 720x1280 base, `canvas_items` stretch, `expand` aspect.
- Android APK first. Duff tests on his phone and edits in the Godot Android editor, so nothing may depend on desktop tools or C#/GDExtension.
- Milestone 0 is NOT written from scratch. Copy the whole of `duffpowell-commits/godot-game-starter` into this repo (everything except `.git`). Keep docs/ in this repo where names collide: this repo's CLAUDE.md, QUEUE.md, docs/PITCH.md and docs/style-guide.md win. Merge the starter's CLAUDE.md "Commands" and "Rules for building on this" sections into this repo's CLAUDE.md. Then set `config/name="Hunter"` in project.godot. The starter already provides CI + signed APK, in-app updater, version on title, REPORT A BUG, boot/intro/title/pause/game over flow, autosave/resume, settings, subtitles, colorblind keys, dev menu, autoplay bot. Do not rebuild any of it.
- Signing: the repo needs the `KEYSTONE_PASS` Actions secret (Duff adds it on github.com from his phone; docs/SIGNING.md in the starter). Without it CI signs with a throwaway key and APKs can't update in place.
- `scripts/game.gd` in the starter is a placeholder ("Orb Catch"). Replace its PLAY section with Hunter. Keep its pause, focus-out save, back-button and `debug_skip_level()` handling.
- Every screen uses `ui.gd` helpers. Every gameplay colour goes through `UI.key()` plus a shape cue. Every sound a player must notice also goes through `Subs.cue()`. Buttons are at least 72 base units, 18 apart.
- Save at every checkpoint with `Save.write(state())`. Bump `Save.VERSION` and migrate when the format changes.
- Extend `scripts/autoplay.gd` with one PASS line per feature below. CI must stay green: parse check, `tests/run_tests.gd`, autoplay.
- Content is data, not code: enemies, bosses, specials, loot, realms and trophies live in `data/*.json` (or `.tres` Resources). Adding a boss should mean adding data plus art, with no new engine code.
- Placeholder art drawn in code until real sprites land in `assets/art/`. Never block gameplay work on art.
- Push after every chunk. Merge to main at the end of every milestone. Green PRs merge themselves.

## Camera and view
- Top-down, high three-quarter angle, same in and out of combat. Camera follows the player with slight look-ahead in the move direction.
- Characters are 2D sprites about 96-128 px tall on screen at base resolution. Y-sort everything.

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
- It visibly changes the lair (3 looks: 0-33, 34-66, 67-100) and the player's sprite tint/horns.
- It decides the ending band (see Endings, TBD).

### Lair (hub)
- One screen, scrolling vertically. Rooms unlock over the game: Trophy wall (start), Furfur's cage (after his intro), Workshop, Cold room (stored parts), Map room (realm portals).
- Trophy wall: a grid of slots (start with 6). Each trophy gives a perk depending on the slot row (row 1 = offence, row 2 = defence, row 3 = utility). Moving a trophy is free in the lair.
- Furfur: a talk menu (lore, contract clauses for small mercies). VENT is available only after a real failed hunt, and unlocks one combo string per real failure (track a `failures_unvented` counter, so it can't be farmed).

### Price's contract
- An inventory item. Opening it shows clauses. Hidden clauses are revealed by story flags (Furfur leaks, Price fight loopholes). Store it as data plus save flags.

## Milestones (one at a time, each ends merged to main with a working APK)
- **M0 Foundation**: copy the starter as above, rename, CI green, the APK installs, the autoplay passes. Title shows "HUNTER" (working title).
- **M1 Movement and combat feel**: one test arena. Player, virtual stick, the light/heavy/dodge/special swipe pad, 1 dummy enemy type, 1 improvised weapon with breaking, combo counter, hit-stop (60 ms) and screen shake. Autoplay: move, light string, special, weapon break.
- **M2 The Pews and Vesper (vertical slice)**: the Pews realm (one map), zealots plus a choir buff enemy, collection-plate hazard, scavenging, Vesper boss (2 phases, Sermon/Flock/Laying of Hands), stalking/ambush, CLEAN vs BRUTAL finisher, EAT, Vesper as the first voice with dialogue boxes. Portal home.
- **M3 The lair**: hub with the trophy wall, workshop crafting, map room, voice equip, Heat, a lair raid, Corruption tint. Save and resume all of it.
- **M4 Furfur**: the lost-hunt intro, the home-invasion fight, the cage, the talk menu, VENT gated on real failures.
- **M5+**: one realm and boss per milestone in the order Casino (Gus) -> Quarry (Rook) / Ballroom (Ines) -> Nursery (Hollis) -> Price & Partners (Price, specials-void "objection" zones, loophole counters). Then endings.

## File layout to aim for
- `scenes/` boot, intro, title, game (starter) + `lair.tscn`, `realm.tscn` (one scene, loads realm data), `combat/`.
- `scripts/` starter autoloads + `player.gd`, `enemy.gd`, `boss.gd`, `voice.gd`, `inventory.gd`, `crafting.gd`, `lair.gd`, `realm.gd`, `heat.gd`, `corruption.gd`, `swipe_pad.gd`, `virtual_stick.gd`.
- `data/` `realms.json`, `enemies.json`, `bosses.json`, `specials.json`, `loot.json`, `recipes.json`, `trophies.json`, `voices/*.json`.
- `assets/art/` sprites per character: `<id>/idle.png`, `walk.png`, `attack.png`, … on a transparent background (keyed from #00FF00).

## Still open (Duff decides; use the placeholder until then)
- Art style: TBD. Placeholder: shapes drawn in code.
- Protagonist name: TBD. Placeholder `HUNTER`.
- Mom's name and past: TBD. Placeholder `MOM`.
- The rival hunter/detective: TBD (not before M5).
- Endings: TBD (not before M5).
- Game title: TBD. Placeholder `HUNTER`.

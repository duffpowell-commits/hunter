# The studio mascot in every game (Duff's rule, Nov 26, 2026)

For any coding AI (Claude, Grok, Codex, ChatGPT...) or person working on a 3 Eyed Fox Studios game.

## The rule
- The studio mascot, the **three-eyed fox**, appears in **every** game.
- It is a **cameo, not a pal**: no companion, no sidekick, no follower, no helper the player keeps.
- It shows up as a **small event that matters but never ruins a run**: it costs or nudges something
  the player notices (a turn, a moment, a bit of noise, a dropped item), never a death, a lost save,
  a failed level or anything the player can't recover from.
- Rare: at most once a run or once a night/level, so it stays a surprise.
- **Duff approves the fox art on a tappable card before anything is built.** Use the studio look
  (distressed gold, tattoo-inspired, three eyes, the ear jewelry; godot-game-starter docs/MARKETING.md "Brand"), make
  it in Foxboard Forge first, then show him. No fox art ships without his yes.
- The example Duff gave (Rush): on a quiet service a fox gets loose in the kitchen and costs a turn.

## Exceptions (Duff's calls)
- **Hunter:** the fox is the **main character's pet**, not a cameo (Duff, Nov 26).
- **DuffQuest:** besides its cameo, the fox also joins the overworld animals, with the raccoons.

## How to build one
1. Write the game's cameo idea (one line) in this file's "This game" section and the handoff log.
2. Get the fox art approved by Duff on a card (see above).
3. Build it with a TUNE slider for its odds/cost and an autoplay PASS line, like any feature.
4. Log it in the handoff (CLAUDE.md "Where things stand" + the handoff log).

## This game: The Devil You Owe (Hunter)
- **Exception: the fox is Cain's pet, not a cameo (the cameo lines above don't apply here)** (Duff, Nov 26: "For the WO, we'll make the mascot the main character's pet"). It lives in the lair.
- **Art approved (Duff tapped "B: upright third eye", Nov 26):** soot black with bone white chest,
  tail tip and inner ears, an upright ember third eye. Concept: `docs/art/fox-pet/fox_pet_B_approved.png`
  (Forge job dh-fox-pet-20261126, seed 194755873). Duff picked this over the studio's gold look, for
  this game only.
- **Built (Nov 26, `scripts/fox_pet.gd`, numbers `data/fox.json`, sliders in TUNE as `fox_*`):**
  - Follows Cain in the Pews and the lair: walks, runs to catch up, idles beside him.
  - Can't be hurt, never fights, never a target; hangs back (`fight_distance`) while a fight is on.
  - SNEAK: it creeps and keeps low with Cain.
  - **Demon Sight is its third eye**: SIGHT opens and flares the eye.
  - Once a hunt it yips at an unaware enemy nearby (caption "[the fox yips: something close]").
  - Lair: waits at the door and runs to greet Cain; keeps a warier distance at higher corruption
    looks (`wary_follow`).
- Model: free CC0 fox (Khronos glTF sample, credits in `assets/pets/SOURCES.md`), recoloured by
  `tools/recolor_fox.py`; real clips only (Survey, Walk, Run). No sit or sleep clip yet. Renders:
  `docs/renders/fox_pet_sight_*.png`, `flow_lair_fox_greet.png`.
- Still Duff's call: **the fox's name** (placeholder FOX in `data/fox.json`).

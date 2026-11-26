# HANDOFF: where the build stops and how to pick it up

Any AI (Claude, Grok, Codex, ChatGPT...) can take over from this file. Read it, then AGENTS.md
(rules + commands), then docs/DECISIONS.md (why things are the way they are). Duff asked for this
on Nov 26, 2026: "Continue but keep logs for another ai to build where you stop." **Update this file
in every PR**, not only at the end: the log at the bottom is the running record.

## Studio mascot (Duff, Nov 26)
- **Here the three-eyed fox is Cain's pet**, not the usual cameo (every
  other game gets a rare cameo). Duff OKs the fox art on a card before it's built. Details: `docs/MASCOT.md`.

## Current state (updated 2026-11-26, 17:30 UTC)
- Game: **The Devil You Owe**, hero **Cain Vantre**. Godot 4.7.2, GDScript, Compatibility renderer,
  portrait 720x1280. Repo duffpowell-commits/hunter.
- On main: Milestones 0-4 (training arena, The Pews + Brother Vesper, the lair, Furfur Kemp), the
  8.5 pass (PR #30) and its polish (PR #31), both merged Nov 26.
- Building: **free-flow combat + predator stealth** (branch `claude/hunter-freeflow`, one PR). Duff
  asked for fluid fighting like a named free-flow brawler, stealth and brawl both, and tapped
  "Buttons + swipe specials". What it does: docs/DECISIONS.md 2026-11-26 "free-flow". Code:
  `arena.gd` (lunge, COUNTER, dodge_toward, TAKEDOWN/FINISHER, Demon Sight, SNEAK flag),
  `hunt_arena.gd` (minion hooks, SILENT KILL, sneak aggro), `pews_arena.gd` (Vesper hooks, SNEAK
  replaces the tilt), `game.gd` (COUNTER/DODGE/SNEAK/SIGHT buttons), `character3d.gd` (dash).
- Live builds (from main, by CI):
  - APK: Releases -> `dev` -> `hunter.apk`.
  - Browser (iPhone Safari): https://duffpowell-commits.github.io/hunter/ . **404 until Duff turns
    on Pages** (Settings -> Pages -> branch `gh-pages`, folder `/root`). An agent can't do it: the
    Pages API is blocked from cloud sessions.
- Open PR: the free-flow PR (above). Merge when green + fresh-eyes.
- Other open PRs, not part of this work: #21, #22, #12 (see CLAUDE.md).

## The 8.5 rule (Duff, Nov 26)
Before building another round on a game: get a **blind first-time-player review** (a fresh AI that
plays with no code/docs), write an "8.5 plan" (what it takes to score 8.5/10), get Duff's OK on one
tappable card, build it all in **one pass** (one PR), then re-run the blind review and report the
score against 8.5. No one-fix-per-PR loops.

### Review scores
| Date | Build | Score | Notes |
|---|---|---|---|
| Nov 26 | M4 (main, 2e96a5d) | 4.5/10 | No controls, no goal, camera inside the hero, ambush at spawn, unreadable heal, template intro, dark lair |
| - | PR #30 merged | not run | Duff, Nov 26 7:12 AM CT: "We'll build all of the fixes, cancel the reviews". The second blind review is cancelled; only run one if Duff asks again |

### The 8 items (all built in PR #30)
1. Guided first hunt: `scripts/first_hunt.gd`, pad/stick hints, minions wait (`pews.json minions.aggro_radius`).
2. Camera: `scripts/camera_rig.gd` tilts up over walls, min distance, never yaws.
3. Fair first boss: HP bars (`hunt_arena.gd hp_bar`), "+ HEALING" tell, one hit breaks the heal, soft aim.
4. Cold open: `scripts/intro.gd` four story cards; HUD "GOAL: HUNT VESPER".
5. Readable lair: brighter, station rings, NEXT HUNT marker, context button off the attack pad.
6. Explainers: `scripts/explainer.gd`, once ever per number.
7. Title: Vesper key art `assets/art/title_vesper.png`.
8. Captions: `scripts/subs.gd` newest wins; dialogue never cut by a cue.

## Next steps, in order
1. Merge the free-flow PR (green CI + fresh-eyes PASS, docs/FRESH_EYES.md).
2. Duff plays it on his phone (APK from the `dev` release; browser once Pages is on) and tunes the
   feel in DEV MENU -> TUNE (lunge_range, lunge_speed, counter_*, takedown_at, finisher_at...).
   Left over: a vault-over dodge clip; maybe a cooldown after a successful COUNTER on Vesper.
3. Milestone 5 (Cellar Casino, Gus; docs/BUILD_SPEC.md) when Duff says go. Under the 8.5 rule, a new
   round of fixes starts with a plan on one card for Duff; blind reviews only when he asks.

## Build and test (cloud sandbox)
- Godot: 4.7.2-stable Linux zip from GitHub releases -> `/usr/local/bin/godot`; fresh clone:
  `godot --headless --path . --import`. Run `git config core.hooksPath .githooks` once.
- Before every push: `tools/test.sh` -> `TESTS PASS` (82 tests), then `tools/autoplay.sh` ->
  `AUTOPLAY PASS` (~8 min; renders land in docs/renders/, commit them).
- Local web build: export templates for 4.7.2 web into `~/.local/share/godot/export_templates/4.7.2.stable`,
  then `godot --headless --path . --export-release "Web" build/web/index.html`; serve with
  `python3 -m http.server`. Headless Chromium needs `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`.
- CI: `gh api repos/duffpowell-commits/hunter/actions/runs?per_page=3` (GraphQL is blocked).

## Gotchas (learned the hard way)
- Autoplay taps are real taps: a button sitting over the attack pad eats them (that's how the
  context-button problem was found). Keep `game.gd CONTEXT_TOP` clear of the pad ring.
- `game.gd _build()` frees every HUD child not in group "keep" or "sheet" whenever text size,
  contrast or left-handed changes. Anything you add to the HUD must survive that.
- Texture imports must set `compress/normal_map` explicitly (2 = off) or `test_texture_imports_explicit` fails.
- Coach prompts are 4 words max (asserted). Coach/explainer state lives in user://coach.cfg and
  user://explain.cfg, not the save, so no `Save.VERSION` bump.
- Never: force push, push to main, `--no-verify`, add the `duff-ok` label, make a signing key,
  put secrets anywhere. Rule-locked files need Duff's tap (AGENTS.md "Rule lock").
- `bool(x)` on a null Variant is a runtime error in Godot 4.7; compare `== true` instead.
- Free-flow: a strike at someone past reach doesn't swing at once: `_move` stays empty while
  `_lunge` runs, and `_free()` is false. Tests that fire several moves in a row must call
  `_end_lunge()` between them, and checks must read `_lunge.move` as well as `_move`.
- The finisher's hits go through `_apply_damage(target, r)`; the Pews' boss sync lives in its
  `_damage_dummy` override. New damage paths should use those, not subtract HP by hand.

## Log (newest first; one line per chunk of work)
- 2026-11-26 17:30 Claude: free-flow combat + predator stealth built on `claude/hunter-freeflow`; tests 82 pass (8 new), autoplay checks for lunge, counter, takedown, DODGE button, SNEAK button, Demon Sight, SILENT KILL.
- 2026-11-26 16:00 Claude: Duff asked for free-flow fighting + stealth; tapped "Buttons + swipe specials".
- 2026-11-26 13:25 Claude: PR #30 merged (CI green, fresh-eyes PASS c6463b1). Duff cancelled the second blind review. Polish PR for the review notes.
- 2026-11-26 13:12 Claude: Duff paused all games, then resumed Hunter a minute later ("build all of the fixes, cancel the reviews").
- 2026-11-26 13:10 Claude: fixed fresh-eyes note (prompts hid behind pause/GAME OVER sheets); wrote this file.
- 2026-11-26 12:55 Claude: fresh-eyes round 2 on 341e1df: no blockers.
- 2026-11-26 12:50 Claude: fresh-eyes round 1 blocker fixed (prompts freed on HUD rebuild); dialogue captions protected; camera pitch cap; tests 73.
- 2026-11-26 12:43 Claude: PR #30 opened with all 8 items; tests 71, autoplay pass; first CI green.
- 2026-11-26 12:22 Claude: Duff tapped "Build all 8" on the 8.5 plan.
- 2026-11-26 06:21 Claude: M4 (Furfur) merged as PR #29; web build job added.

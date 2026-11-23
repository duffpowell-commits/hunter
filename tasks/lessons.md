# Lessons

- Nov 20: the GitHub connector got 403 writing to Foxboard; queuing Forge jobs worked by cloning the repo in the session and pushing with git.
- Nov 20: Canva went into cooldown after one image. Run exploration on Forge; keep Canva for edits and private art.
- Nov 20: FLUX schnell adds details nobody asked for (horns on Vesper) and drops face coverings (Rook's mask). Fix with a same-seed reroll that names the one failed detail.

## From godot-game-starter (copied at Milestone 0, Nov 21; why: Hunter now runs the starter's code, so its lessons apply)
- `godot --check-only --script` doesn't load autoloads, so any script using `Settings.` etc. fails
  it. Use `tools/check_scripts.gd` (loads every script inside a running tree) instead.
- Adding UI from `_notification` (focus out, back button) fails with "parent busy": call it deferred.
- An imported .wav's loop is set in its .import (`edit/loop_mode=2`), not at runtime (it's compressed).
- Rebuilding a screen's UI after a settings change: move open sheets back on top (`move_child(sheet, -1)`).
- DuffQuest went weeks without a GAME OVER because end screens weren't day-one plumbing. They are now.

## Hunter code
- Nov 21: on a slow sandbox (8 cores, software GL) autoplay's `CAMERA SMOOTH` failed once out of
  three runs (15.1 m/s vs a 12 m/s limit) and passed the other two (9.4, 9.6). It measures per
  frame, so a hitch shows up as speed. Rerun before chasing it; fix the check if it repeats in CI.
  Fixed in M1 (Nov 21): it now measures over >= 0.1 s of real time (a real cut still fails it).
- Nov 21 (M1): a Character3D one-shot isn't "acting" until the next physics step, so code that
  checks `is_acting()` right after `act()` must allow a short grace period (arena.gd `_move_age`).
- Nov 21 (M1 CI): don't sample a 60 ms effect from the bot; a slow CI frame is longer than that.
  Count it instead (Character3D `stops` / `last_stop`, used by HITSTOP PASS).
- Nov 21 (M1 review): a save point must check that the player is alive. Dying, then PAUSE, then
  QUIT, then CONTINUE brought a dead run back. Guard `checkpoint()`, clear the save on death, and treat a
  0 HP save as a new run.
- Nov 21 (M1 review): a TUNE slider that's copied once in `_build`/`_ready` isn't live. Push every
  slider each frame (arena `push_tune()`, the pad in game.gd `_process`).
- Nov 21 (M1 review): once contact waits for `hit_at`, a target still sliding from the last knockback
  walks out of reach. Autoplay must let the knockback finish before it sets up the next hit.
- Nov 23 (M2 review): a boss fight that autoplay wins in God mode with the boss's cooldown parked
  proves the hero's attacks, not the boss's. Give every enemy power its own PASS line with God mode
  off, and stage by placing actors and zeroing cooldowns, never by calling the damage code.
- Nov 23 (M2 review): `Character3D.tint` is read once during setup. Set it before `add_child`, or
  re-run `apply_toon` after changing it.
- Nov 23 (M2 review): after a hit the hero is still sliding. An autoplay check that needs the hero
  in range must wait out the knockback, then place them (same lesson as M1's dummy knockback).
- Nov 23 (M2): four AIs built M2 on four branches. One integration PR merges; the rest get closed
  with a pointer to it, or the next session can't tell which branch is the game.

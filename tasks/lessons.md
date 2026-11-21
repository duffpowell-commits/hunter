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

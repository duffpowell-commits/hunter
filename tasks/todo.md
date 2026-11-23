# Todo

- [x] Duff picks art style: ink and blood on 3D (Nov 20).
- [ ] Rerender hero + 5 bosses in the picked style; Rook needs the iron mask, Vesper shouldn't have horns.
- [ ] Protagonist, Mom's name, the rival hunter, endings, title (see QUEUE.md NEXT).

## Code (why this section, Nov 21: Duff greenlit Hunter and code started)
- [x] Milestone 0: copy godot-game-starter, rename Hunter, 720x1280, Godot 4.6.3 (Nov 21).
- [x] Duff: add the `KEYSTONE_PASS` Actions secret so APKs update in place (done Nov 21).
- [ ] Duff: confirm or drop the UI `stretch/scale` 1.3333 (docs/BUILD_SPEC.md).
- [x] Milestone 1: 3D test arena slice (Nov 21).
- [x] M1 review fixes (fresh-eyes CHANGES REQUESTED on 95847e0), pushed to PR #14 (Nov 21). Waiting
  on the next fresh-eyes review, then Duff merges. See docs/DECISIONS.md "Milestone 1 review fixes".
- [ ] Duff: swipe up/down when the dummy is straight up or down the screen. Right now toward/away
  wins within 45 degrees, so "up" means toward there (DECISIONS M1 judgment call 4). The reviewer left
  it to you.
- [ ] Duff: double-tap = dodge, unless the tap before was a light that connected (then it's a light).
  Keep it, or pick another rule (DECISIONS, M1 review fixes).
- [ ] Duff: review M1's judgment calls (docs/DECISIONS.md, 2026-11-21 M1 entry).
- [ ] Copy `Character3D.extra_actions` back to godot-game-starter.
- [ ] Gesture hints + pause-menu gesture card (BUILD_SPEC pipeline rules), before or with M2.
- [x] Milestone 2: The Pews and Vesper (Nov 23, PR #20).

## From the M2 review (Nov 23 fresh-eyes on PR #20; do these at the start of M3)
- [ ] Profile-level save: cash, heat, parts, corruption, trophies and voices live only in the run
  save's "pews" blob and NEW GAME wipes them. The lair needs them to persist. Show them on the HUD too.
- [ ] Training-arena leftovers in the Pews: HUD says "ROUND n", killing Vesper plays the round chime,
  GAME OVER says "Round 1, 0 knockouts", `debug_skip_level` only bumps the round, and four inherited
  TUNE sliders (enemy_attack_every, enemy_telegraph, enemy_damage, dummy_max_hp) do nothing there.
- [ ] Flock is nearly harmless: the first tick knocks the hero out of its radius, and the shadows stay
  where they were cast while damage follows Vesper. Duff: tune it (flock sliders) or redesign it.
- [ ] AMBUSH has no distance check: at 100% study it can be pressed from anywhere in the church.
- [ ] Vesper never moves or turns; phase 2 differs only in HP. No checkpoint at the phase break.
- [ ] Minions walk straight at the hero with no pathing and can snag on pews.
- [ ] BRUTAL is covered by rule tests only: add an autoplay PASS line.
- [ ] Autoplay shortcuts to tighten: the stalk check presets study to 99%; the M1 dodge check sets
  `_last_light_landed` directly and counts i-frames as "rolling".
- [ ] "COLLECT PLATE" and "RETURN HOME" are wider than the 200 px context button.
- [ ] Mid-fight CONTINUE puts the hero back at the door (boss HP, phase and dead minions are kept).

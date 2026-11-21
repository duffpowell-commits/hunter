# Queue

## NOW
- Code: Milestone 1 (docs/BUILD_SPEC.md): 3D test arena, ink look, 360 movement, stick + swipe
  combat, dummy, breakable weapon, combos, hit-stop, shake, one autoplay PASS line per feature.
  Milestone 0 (copy of godot-game-starter, Godot 4.6.3, 720x1280) was built Nov 21.
- Design, in parallel: hero name (asked Nov 20), then the rest of NEXT. Art is locked: ink on 3D (docs/style-guide.md).

## NEXT (design, no code)
- Protagonist: name, look, day life.
- Mom: name, hunter past.
- The hunter/detective on your tail.
- Endings.
- Title.

## LATER
- Code: Milestones 2-5+ per docs/BUILD_SPEC.md.

## OPEN QUESTIONS (Duff decides; don't change these until he does)
Why: when the docs disagree and Duff hasn't picked, no session guesses (docs/DECISIONS.md, Nov 21).
- None open. Settled Nov 21 by Duff: Godot 4.6.3, not 4.5-stable (he asked which fits his goals, Grok
  recommended 4.6.3, and he confirmed "Yes, lock in 4.6.3"), and Hunter is greenlit for building
  (docs/DECISIONS.md, 2026-11-21 Milestone 0 entry).
- Waiting on Duff's review (Grok's default until then): `stretch/scale` 1.3333, which keeps the UI on
  about 540x960 logical units so touch targets stay at least 48 dp (docs/BUILD_SPEC.md hard rules).

## IDEAS
- (Nov 20) Lair raids, trophy-wall skill tree, MO-as-build, case board rival. See docs/DESIGN.md.

## CUT
- Combo meter feeding corruption (Duff, Nov 20).

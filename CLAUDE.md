@AGENTS.md

# The Devil You Owe

Top-down action RPG: you're a half-demon serial killer of demons. Stalk, kill, scavenge, build your lair, eat the bosses and wear their movesets. Street Fighter-style combos in combat, Westland Survival-style scavenging outside it. Owner: Duff. Read this first; it is the handoff between sessions. Commands, standing rules, guards and layout: AGENTS.md (imported above), shared by every coding AI.
Why the import (Nov 21): Claude Code skips AGENTS.md when CLAUDE.md exists unless it's imported. Catch-up log: docs/DECISIONS.md.

## Gothic Ink Realism environment pass (Nov 22, 2026)

- The Pews has cracked blue-gray flagstones, outlined worn-wood seats, a dressed altar, broken stained glass, and gold candle clusters. The art uses the existing collision layout and top-down camera. High graphics uses two shadow splits focused on the aisle, and autoplay checks the Pews draw-call and triangle budget during the sermon. Character designs are still pending Duff's approval.
- Vesper's existing halo uses one instanced mesh and is visible during his ability telegraphs. The autoplay renders in `docs/renders/` show the aisle, combat, the sermon windup, and the scene after it clears.
- Actions run 45083524356 landed three jabs because slow render frames let the light-string timer expire between autoplay taps. Autoplay now taps as soon as each swing recovers, verifies jab, cross, and hook in order, and still checks the hook's physical knockback.

## Milestone 2 integration

- The integration branch combines the branded startup from main with The Pews and Vesper from PR #17, including the Gothic Ink environment work in PR #18.
- NEW GAME opens The Pews in normal play. Autoplay also loads the training arena to retain the Milestone 1 combat checks. The dodge check sends real taps through the swipe pad.
- In The Pews, a light stick tilt crouch-walks before Vesper engages. The shared TUNE panel exposes stalking, Vesper phase health and spell timing, and minion balance. Tuning edits affect the active encounter configuration.
- Autoplay uses real attack-pad holds to clear Vesper’s two phases, with fixed positioning and God mode after the sermon check.
- The return-home portal leads to the lair (M3, Nov 24).
- Nov 23 fresh-eyes fixes (docs/DECISIONS.md): every Pews range and timing is in `data/pews.json` with a
  TUNE slider; autoplay now takes real damage with God mode off (spotted, Sermon, Flock, Hands, Choir
  buff, GAME OVER in the church); dead minions stay dead on CONTINUE; Vesper wears his own colour.

## Where things stand (Nov 26, 2026)
- **Any AI picking this up: start at docs/HANDOFF.md** (current state, next steps, gotchas, running
  log). Duff, Nov 26: "keep logs for another ai to build where you stop". Update it in every PR.
- **Nov 26: free-flow combat + predator stealth** (Claude, one PR; Duff tapped "Buttons + swipe
  specials"). Strikes lunge to targets, COUNTER and DODGE buttons, the combo holds across enemies,
  TAKEDOWN at 5 / FINISHER at 8, SNEAK button (no more tilt), SILENT KILL, Demon Sight. Details:
  docs/DECISIONS.md.
- **Nov 26: the 8.5 pass** (Claude, one PR; Duff's new bar: plan to an 8.5 blind first-timer review,
  OK once, build in one pass). First-timer scored M4 4.5/10. Built all 8: guided first hunt, camera
  rises over walls, HP bars + breakable heal tell + soft aim, real cold open + goal, readable lair,
  one-line explainers, title key art, newest-only captions. Details: docs/DECISIONS.md.
- **Nov 26: hero name LOCKED: Cain Vantre** (Duff tapped it; Cain Mercer dropped, it echoes
  Prototype's Alex Mercer).
- **Nov 26: Milestone 4 built** (Claude, one PR): Furfur Kemp. GAME OVER in a hunt offers LIMP HOME;
  he follows you into the lair (a fight you can't lose, only win ugly); CHAIN HIM puts him in the cage
  by the door. The cage station: TALK (one lore leak a night), a cash mercy for a hidden contract
  clause, READ YOUR CONTRACT (also in the cold room), VENT after a real loss (one extra light-string
  hit per loss, max 3, +5 corruption). Rules `furfur_rules.gd`, data `furfur.json` +
  `voices/furfur.json` (writing is placeholder). Judgment calls: docs/DECISIONS.md 2026-11-26.
  **Next: Milestone 5** (Cellar Casino, Gus), after Duff plays M3 + M4.
- **Nov 26: browser build** (Duff wanted the same as Lethemoor/Rush): https://duffpowell-commits.github.io/hunter/
  plays in iPhone Safari, upright or sideways (sideways = smaller text), **once Duff turns on Pages**
  (Settings -> Pages -> branch gh-pages, /root); until then the link is a 404. CI job `web` exports it on
  every run and force-pushes it to `gh-pages` on main. Web preset: threads off, no COOP/COEP needed.
- **Nov 25: Godot 4.7.x only** (Duff). CI fails if the engine or `config/features` drifts off 4.7.
- **Nov 24: Milestone 3 built** (Claude, one PR): profile save (Save v4 + `Profile` autoload), every
  M2-review carry-over, and the lair (trophy wall, workshop, cold room, voice shrine, map room, heat,
  LAIR RAID, three corruption looks). RETURN HOME now opens the lair. Details + judgment calls:
  docs/DECISIONS.md. PR #21 failed fresh-eyes (update sheet can open
  mid-fight); #22 and #12 wait on Duff.
- **Nov 23: Milestone 2 built** (Grok, ChatGPT and Codex built it across PRs #15-#18; PR #20 is the one
  that merges; Claude did the fresh-eyes fixes). NEW GAME opens The Pews: stalk Vesper, ambush or get
  spotted, two boss phases (Sermon, Flock, Laying of Hands), Zealot + Choir, plate and loot, CLEAN/BRUTAL,
  EAT, return home. PRs #15, #16 and #17 are superseded by #20: close them, don't merge them.
  **Next: Milestone 3** (the lair, docs/BUILD_SPEC.md). Before M3 content, do the carry-overs in
  tasks/todo.md "From the M2 review": a profile-level save comes first, because cash, parts, trophies
  and voices live only in the run save and NEW GAME wipes them.
- Still open PRs that are NOT part of M2: #21 (Android update recheck), #22 (working title "The Devil
  You Owe", waits on Duff's naming call), #12 (art generation guide). Each needs its own fresh-eyes pass.
- **Nov 21: Milestone 1 built** (Grok, PR "Milestone 1", on top of the M0 PR): NEW GAME opens the 3D test
  arena with the stick and swipe pad, a dummy that fights back, a pipe that breaks, combos, hit-stop
  and shake. Grok's judgment calls for Duff are listed in docs/DECISIONS.md. **Next: Milestone 2**
  (The Pews and Vesper).
- **Nov 21: Milestone 0 built** (Grok, PR "Milestone 0"): godot-game-starter copied in, renamed
  Hunter, base canvas 720x1280, Godot 4.6.3 (moved to 4.7.2 on Nov 24). Tests, autoplay and the APK export pass. Duff greenlit
  Hunter on Nov 21, asked which version fits his goals, Grok recommended 4.6.3, and he confirmed
  "lock in 4.6.3" the same day (docs/DECISIONS.md). KEYSTONE_PASS is set, so CI APKs update in place. **Next: Milestone 1** (docs/BUILD_SPEC.md):
  the 3D test arena slice. `scripts/game.gd` is still the starter's "Orb Catch" placeholder.
- Phase: design done enough to build. Duff greenlit coding on Nov 20 (another coding AI starts Nov 21). **Coding starts at docs/BUILD_SPEC.md**: hard rules, controls, systems with numbers, milestones M0-M5+.
- Build spec: docs/BUILD_SPEC.md. Full design: docs/DESIGN.md. Pitch: docs/PITCH.md. Queue: QUEUE.md. Art: docs/style-guide.md + docs/ART_LOG.md.
- Done: core concept, combat rules, story spine (Mom, Samael Price, Furfur Kemp), 5 bosses/voices, 6 realms. First sprite exploration rendered (docs/art/explore-20261120/).
- Art LOCKED Nov 20: ink and blood on real-time 3D, full range of movement (docs/style-guide.md, docs/art/ink-3d/).
- Nov 21 (Grok): Git pre-push hook for every agent (`.githooks/pre-push`); rules moved into AGENTS.md. Both open questions (Godot version, active game) were settled by Duff on Nov 21.
- Design still open (doesn't block code; use the BUILD_SPEC placeholders): the protagonist (name, look, day life), Mom's name and hunter past, the hunter/detective on your tail, and endings.

## Claude-only notes
- `.claude/settings.json` runs `.claude/hooks/guard.py` before every Bash/Write/Edit call. A blocked
  call comes back with the reason; fix the cause, don't work around it.
- In that hook `--force-with-lease` is allowed; the Git pre-push hook still blocks any push that
  rewrites the remote branch, so plan on merging, not rewriting.

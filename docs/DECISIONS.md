# Decisions log (catch-up file for Claude, Grok and any agent)

## 2026-11-24: Milestone 3, the lair; profile save; M2 review carry-overs (Claude)

What, in the order Duff asked for:
1. **Profile save** (`scripts/profile.gd`, autoload `Profile`, `user://profile.json`): cash, heat, parts,
   corruption, inventory, trophies + wall slots, voices + equipped + BRUTAL levels, upgrades, traps,
   nights/raids, `failures_unvented` (for M4's VENT). NEW GAME and GAME OVER clear only the run save.
   **Save.VERSION 4**: the run save gains `where` ("pews"/"lair"); a v3 run's rewards are lifted out of
   its "pews" blob and handed to the profile once (Save.read rewrites the run without them). The HUD
   shows `$ HEAT PARTS CORR` plus the status line on a full-width row.
2. **M2 review carry-overs, all done**: ROUND/chime/"Round 1, 0 knockouts" gone outside training;
   SKIP LEVEL downs Vesper; the four dummy sliders hidden in the Pews (`tune_spec()`); Flock damage
   sits on the shadows and its knockback is a slider (default 0); AMBUSH needs `ambush_range` (3 m);
   Vesper turns, walks in between powers, phase 2 powers 25% faster, checkpoint at the phase break;
   minions (and Vesper) steer round props; BRUTAL has an autoplay PASS; the stalk check now fills study
   by real sneaking; the M1 dodge check no longer sets `_last_light_landed` or counts i-frames as a
   roll; context button 260 wide; mid-hunt CONTINUE keeps the hero's (and Vesper's) spot.
   Eating a boss now adds +10 corruption (BUILD_SPEC; it was missing). Bodies (+3) and searching (+2)
   add heat.
3. **The lair** (`lair_arena.gd`, `lair_rules.gd`, `lair_sheets.gd`, data `lair/recipes/trophies/realms.json`,
   `voices/vesper.json`): one room scrolling vertically. RETURN HOME lands at the portal; a night passes
   (heat -10). Trophy wall (3 rows x 2: offence +15% special damage, defence +15 HP, utility heat -5/night
   for Vesper's collar), workshop (grip upgrade, glass trap, wax poultice; HEAL button in fights), cold room
   (stores, 24-slot bag), voice shrine (slot 1 = UP swipe, slot 2 = DOWN; Vesper's SERMON, +6 per BRUTAL
   level), map room (The Pews open, the rest locked). Heat 70+ on return = LAIR RAID: 2 waves of 2
   raiders, set traps fire on their own, losing costs 30% of parts and never the save. Corruption picks
   HOME / STAINED / HELLMOUTH looks and tints the hero, with horns. Voice lines (fight, low HP, 5-hit combo,
   kill, lair visit) show in a dialogue box at the top (3 s or tap). `hunt_arena.gd` is the shared base
   (foes, steering, perks, voices). Every number has a slider (`lair_tuning.gd`, `pews_tuning.gd`).

Tests: 61 (10 new), each seen failing by stashing or mutating the code. Autoplay: 120 PASS lines, new
ones with God mode off (raid, BRUTAL, profile, corruption). Autoplay timeout 300 -> 480 s (it runs ~4 min).

Judgment calls for Duff:
- The lair is a 3D room you walk through (stations along the aisle), not a 2D menu.
- All lair rooms are open from the start except Furfur's cage (M4). Re-hunting Vesper is allowed after
  he's eaten: cash and parts farm, trophies and voices don't duplicate, every run's plate adds heat.
- A night passes only on RETURN HOME (no bed to farm heat away). Winning a raid drops heat 25.
- Voice lines and Vesper's portrait (a mauve disc with an initial) are placeholders.
- Fresh-eyes on PR #21: CHANGES REQUESTED (the update sheet can now pop mid-fight). Not merged.

## 2026-11-23: Milestone 2 merged through PR #20; fresh-eyes fixes (Claude)

What: The Pews and Vesper (Grok PR #15, ChatGPT PRs #16-#18, Codex integration PR #20) went through a
fresh-context review on f37c8c4. Verdict: CHANGES REQUESTED, three house-rule blockers, no crash or
save-loss bug. Fixed in one push:
- Numbers out of `pews_arena.gd`: sermon radius; flock radius, duration and tick times; minion chase
  band, speed, attack and hit ranges, first attack delay; interact radius; pre-fight target range;
  Vesper's first cooldown and telegraph floor now live in `data/pews.json` with TUNE sliders
  (`pews_tuning.gd`). Spawn points, loot points and the boss move order are data too (no sliders:
  they are layout, not feel). Why: "every gameplay number gets a TUNE slider"; Duff tunes on his phone.
- Autoplay: six new PASS lines with God mode off (SPOTTED, SERMON, FLOCK, HANDS, CHOIR BUFF, GAMEOVER).
  Why: the boss fight ran in God mode with Vesper's cooldown parked, so his powers were never run.
- Renders refreshed from the real NEW GAME flow; the unused `scenes/pews_arena.tscn` deleted.
- Also fixed (cheap, from the notes): Vesper's tint never applied; dead minions came back on CONTINUE
  (`dead_foes` in the pews save, optional key, `Save.VERSION` stays 3); Zealot spawned inside a pew.
- Two new rule tests (51 total), both seen failing against the old files.

Judgment calls for Duff:
- PRs #15, #16 and #17 are superseded by #20 and should be closed, not merged.
- PR #22 (working title "The Devil You Owe") was left out of M2: it is his naming call.
- Vesper is now mauve (8b718f, the colour already in the code) instead of the dummy's orange. Still a
  placeholder mannequin until the character designs are approved.
- The rest of the review's notes are in tasks/todo.md "From the M2 review". The big one: rewards only
  live in the run save, so M3 has to start with a profile-level save.

## 2026-11-23 — Studio publisher

Startup shows the approved weathered 3 Eyed Fox Studios logo from the studio Drive folder
during the existing boot. The player can skip the card with the button, Enter, Escape, or
Android Back. Settings → Credits names the publisher.

Newest first. Dates are America/Chicago. Each entry: what changed, why, where the idea came from,
what review found, and what is still open. Add an entry whenever a session changes how agents
work here or settles a design question. AGENTS.md lists this file in its reading order.
Game-design decisions themselves live in docs/DESIGN.md; this file is the "why" and the history.

## 2026-11-21: Milestone 1 review fixes (fresh-eyes CHANGES REQUESTED on 95847e0)
Grok, same branch, no force-push. Every item below has a rule test that I saw fail by breaking the
code on purpose before it passed.

**Blockers**
1. Pad sliders: `game.gd` copies hold_time, swipe_min and double_tap into the pad every frame.
   Before, it copied them once at build time, so dragging the slider did nothing
   (`test_keyboard_reaches_every_special`, "pad sliders act live").
2. Missing TUNE sliders: arena.TUNE now also has dodge_iframes, dodge_cooldown, double_tap,
   string_gap, cancel_bonus, damage_scale (x every move's damage), dummy_max_hp, pipe_durability
   and break_mult. `arena.push_tune()` pushes them into combat every frame (`test_arena_tune_live`).
3. Death escaped through the save. `_on_hero_died` now sets `dying` and clears the save at once.
   `checkpoint()` never writes while the hero is dying, dead, at 0 HP or over. A loaded save with
   hp <= 0 starts a new run. Test: `test_death_cannot_escape_through_save` dies, then runs PAUSE, then QUIT
   (`save_for_quit`), and no save survives. It then plants a 0 HP save and gets a fresh run.
4. Keyboard and pad reach every special: there are new Controls actions HEAVY (I / RB) and SPECIAL (O / RT).
   SPECIAL uses the stick direction through the same `Combat.swipe_dir` as a swipe, so SPIN (away) and
   SWEEP (down) work too. The legend lists HEAVY and SPECIAL (`test_keyboard_reaches_every_special`).

**Non-blocking, also fixed**
- Hit timing: every move has `hit_at` and `recover` in data/moves.json, in seconds of hero time
  (hit-stop pauses them). Contact lands at hit_at, not on the first frame. A new input waits until
  the swing has recovered. One input is buffered, newest wins, if pressed within `arena.input_buffer`
  (0.3 s) of recovery. Earlier presses are dropped, so mashing can't restart swings. A special may still
  cancel a swing that has landed (`test_hit_timing_and_buffer`).
- A special out of a roll gives up the roll's i-frames. A special during a stagger (knockback,
  hit_chest, hit_head) is queued until the stagger ends instead of aborting it (`test_special_rules_in_arena`).
- combat.gd: `special()` only looks. `commit()` spends the cooldown when the move really starts, so a
  refused move costs nothing. The +25 % goes to the first special after each landed light/heavy only
  (`test_special_cancel`).
- Double-tap (judgment call, for Duff): a double-tap is a dodge, unless the tap before it was a light
  that connected. Then it's another light. Why: mashing light in a fight used to alternate light, dodge,
  light, dodge, which threw the hero out of range. A double-tap on empty air (or after a whiff) is still the
  dodge the spec asks for. The window is 0.2 s and is a TUNE slider (`test_double_tap_resolves`).
- Numbers moved to data: pickup radius, auto-face distance, KO knockback, input buffer
  (moves.json `arena`), and the dummy's approach margin and hit power on the hero (enemies.json).
- Autoplay: SPECIAL PASS now requires the cancel and exactly +25 % damage. DODGE PASS uses the dummy's own
  telegraphed swing (hero 1.62 m away: out of jab reach, inside the dummy's) instead of calling `_swing()`.

**Left alone on purpose**
- Judgment call 4 (up/down when the dummy is straight up the screen) stays as it is. The reviewer
  flagged it as Duff's call, and it's in tasks/todo.md.

## 2026-11-21: Milestone 1 built: the 3D test arena (movement and combat feel)
Built by Grok on branch `grok/milestone-1-arena`, on top of PR #13 (M0). docs/BUILD_SPEC.md M1.

**What changed**
- NEW GAME now opens the arena. `scripts/game.gd`'s PLAY section is Hunter: `scripts/arena.gd`
  (the 3D arena) plus `virtual_stick.gd` (left thumb) and `swipe_pad.gd` (right thumb). Pause,
  focus-out save, back button, game over and left-handed mirroring are the starter's.
- Rules live in `scripts/combat.gd` (no nodes, so tests call it directly). Numbers live in
  `data/moves.json`, `data/enemies.json` and `data/weapons.json`, loaded by `scripts/game_data.gd`.
  `export_presets.cfg` now ships `data/*.json` (`test_data_files_ship`).
- `Character3D` got `extra_actions` so a game can add one-shot clips (heavy, specials, pipe swings)
  from the CC0 UAL library without editing ACTIONS. Every clip comes from the library; there's
  no hand-made motion.
- `Save.VERSION` 2: {level = round, score = knockouts, hp}. v1 saves migrate (lives dropped,
  HP full). See `test_save_migrates_v1`.
- 10 new rule tests and 13 new autoplay PASS lines (ARENA CAMERA, STICK, LIGHT STRING, COMBO,
  HITSTOP, SHAKE, HEAVY, SPECIAL, DODGE, PICKUP, WEAPON BREAK, KO, ENEMY). I saw every new test
  fail on purpose before it passed. The arena screenshots are in `docs/renders/flow_arena*.png`.
- Autoplay `CAMERA SMOOTH` now measures over at least 0.1 s of real time instead of per frame. Why: it
  flaked once in three runs on a slow box (one hitch frame read as 15 m/s). A real camera cut still
  fails it: I faked a 4 m cut and it read 34 m/s, FAIL.

**Grok's judgment calls, for Duff to review** (the spec didn't say; each is easy to change)
1. The training dummy fights back. It telegraphs for 0.6 s (red "!" plus a caption), then swings for
   10 damage within 1.7 m, every 2.5 s. Why: dodge i-frames and GAME OVER need something to dodge
   and something that can kill you. Its numbers are in data/enemies.json and TUNE.
2. A round is one knockout. Each KO is a checkpoint (autosave), and HP carries over. Why: the
   starter's checkpoint/CONTINUE flow needs a "level"; M1 has no realms yet.
3. Placeholder specials for the four swipes, until voices own the slots (M2):
   - toward = LUNGE 20
   - away = SPIN 15, hits all round
   - up = LAUNCHER 25
   - down = SWEEP 18 (a slide)
   - cooldowns of 1.2 to 1.5 s
   They're in data/moves.json.
4. Swipe directions: toward/away win when the swipe is within 45 degrees of the dummy's direction
   on screen. Otherwise it's up or down. When the dummy is straight up the screen, "up" means toward.
5. The combo counter shows at 2+ hits. It resets after 1.2 s without a hit, or when you get hit.
   The spec gives no gap.
6. Weapon durability is spent by every hit, specials included. After the pipe breaks, a new one
   appears at its spawn so the test arena can be replayed.
7. Attacks snap the hero to face the dummy when it's within 3 m (touch players can't aim a swing).
8. Keyboard/gamepad: ATTACK = light, HEAVY (I / RB) = heavy, SPECIAL (O / RT) + stick direction =
   the special, read like a swipe (no direction = toward), DODGE = dodge. Changed in the review fixes
   below. The first version reached only LUNGE and LAUNCHER.
9. Look: dark charcoal floor with ink crack lines and dried-blood splats (#6E1212, darker than
   the palette's #B01818 so characters read first). The hero is still the yellow UAL mannequin with
   the orange rim. A black-hoodie model is later work (BUILD_SPEC: never block on models).

**Not in M1 (later milestones or follow-ups)**
- One-time gesture hints ("Swipe toward him: special") and the pause-menu gesture card (BUILD_SPEC
  pipeline rules).
- Voices, stalking, scavenging and realms (M2+).
- The starter's 3D CHARACTER TEST stays in the dev menu, with all its checks.
- Multi-touch: the stick and pad each follow their own finger. That logic is written but has not
  been tried on a phone yet.
- `Character3D.extra_actions` should be copied back to godot-game-starter (it's the master).

## 2026-11-21: Hunter greenlit; Godot 4.6.3; Milestone 0 built (copy of godot-game-starter)
**Decisions (Duff, Nov 21)**
- Hunter is greenlit for building. Duff: "lets move forward to building a small sample of hunter".
  docs/PITCH.md now says so. This settles the open question about PITCH.md vs QUEUE.md and CLAUDE.md.
- Engine: Godot 4.6.3-stable, not 4.5-stable. How it was chosen: Duff asked which version better
  fits what he wants ("Which will provide the capabilities i want better"). Grok recommended 4.6.3:
  it's newer, it matches godot-game-starter and its CI (`GODOT_VERSION`), and it matches the latest
  Godot Android editor he edits on. Duff then confirmed it outright on 2026-11-21: "Yes, lock in
  4.6.3". docs/BUILD_SPEC.md and QUEUE.md are updated.
  Why this wording (fresh-eyes note on 34850aa): the first version of this entry blurred "Duff
  asked" and "Duff picked". QUEUE.md's rule is that only Duff settles open questions, so the
  record shows he confirmed it.

**What changed (Milestone 0)**
- Copied all of godot-game-starter except `.git`, from the head of starter PR #11 (4da9d15), so the
  copy has the same pre-push hook and AGENTS.md layout as this repo's PR #11. This branch starts
  from hunter PR #11's head (8d59ffa) because neither #11 had merged yet.
- Hunter's own files won where names clashed: AGENTS.md, CLAUDE.md, QUEUE.md, docs/DECISIONS.md,
  docs/PITCH.md, docs/style-guide.md. Also kept: tasks/lessons.md and tasks/todo.md, with the
  starter's lessons appended. Why: those hold Hunter's history (Forge and art lessons), and
  overwriting them would have lost it.
- Taken from the starter on purpose: `.claude/hooks/guard.cfg` (turns on the test gate);
  `standards/03` and `standards/12` (the starter is the master, and Hunter's copies were behind:
  TUNE sliders, hooks and fresh-eyes text); docs/FRESH_EYES.md (its house-rule list is about code);
  `.gitignore` (Godot build files).
- AGENTS.md: merged the starter's Commands, standing rules and code layout. CLAUDE.md, QUEUE.md,
  README.md and tasks/todo.md now say M0 is done and M1 is next.
- project.godot: `config/name="Hunter"`, base canvas 720x1280 (it was 540x960), with `canvas_items`
  stretch, `expand` aspect, the Compatibility renderer and `config/features` 4.6.
  - `stretch/scale` 1.3333 was added. **This is Grok's choice, waiting on Duff's review, not a hard
    rule he set.** It means the UI still lays out on about 540x960 logical units: the 720x1280
    base gives the UI no extra density, only 3D benefits. Why: the starter's UI and its touch rule (72 units >= 48 dp) were
    tuned for a 540-wide canvas. Without the scale every screen and button would shrink to 75% on
    the phone and drop under 48 dp.
  - 3D still renders at full window resolution. To make the UI denser later, lower the scale and
    re-check `test_touch_targets`.
- The title shows "HUNTER" (`title.gd` uppercases `config/name`). `config.gd` FALLBACK_REPO is
  duffpowell-commits/hunter. `export_presets.cfg` package is com.duffpowell.hunter (CI stamps it
  from the repo name anyway). `tools/autoplay.sh` records at 720x1280.
- New checks: rule test `test_hunter_project_settings` (watched it fail with the starter's
  settings, then pass), and the autoplay line `HUNTER PASS` (the title shows HUNTER on a
  720x1280 canvas).

- docs/renders/ is committed: the 720x1280 autoplay screenshots (`flow_*.png`), the same way the
  starter commits its own. Why (fresh-eyes note on 34850aa): standards/00-core.md says visual work
  needs screenshots in `docs/renders/` ("Show, don't describe", "Done means"). The first push had
  dropped the starter's 540x960 shots and called renders "not committed" in AGENTS.md, which
  contradicted that standard. The clip `gameplay.mp4` stays ignored (CI posts it to the dev release).
- Signing: Duff added the `KEYSTONE_PASS` Actions secret to this repo on 2026-11-21, so CI APKs are
  signed with the shared keystone (docs/SIGNING.md) and update in place.

**Verified locally (Godot 4.6.3 headless):** SCRIPTS OK, ALL PASS (22), TESTS PASS, AUTOPLAY PASS
with every starter line plus HUNTER PASS, PUSH GUARD PASS, and an Android debug APK export (see
the PR for details). One flaky `CAMERA SMOOTH` failure on a slow sandbox (tasks/lessons.md).

**Still open**
- Duff: confirm or drop `stretch/scale` 1.3333 (above). Until he does it's a Grok default.
- Merge hunter #11 (and starter #11) before this PR. This PR is built on #11.

## 2026-11-21: Pre-push hook for every agent; AGENTS.md is the one rulebook; art-lock docs fixed (PR #11)
Approved by Duff on Nov 21 ("Build the pre-push hook", "Build the shared rulebook and fix the docs").
Same hook and rulebook change as godot-game-starter PR #11 (that repo's docs/DECISIONS.md has the same entry).

**What changed**
- `.githooks/pre-push` runs `.claude/hooks/guard.py --pre-push` (guard.py is the same file as the
  starter's). It blocks force pushes (any push that rewrites a remote branch), pushes to or deleting
  main/master, and secret or plain key files in the pushed commits. The test gate stays off while
  `guard.cfg` `test_cmd` is empty (no code yet). Setup per clone: `git config core.hooksPath .githooks`.
  `tools/test_push_guard.sh` tests it against a local bare remote (14 checks, `PUSH GUARD PASS`).
- AGENTS.md now holds the commands, reading order, Milestone 0 note, house rules, guards and layout.
  CLAUDE.md starts with `@AGENTS.md` and keeps only where things stand plus Claude-only notes.
- docs/DESIGN.md and docs/ART_LOG.md now show the art style as locked: ink and blood on real-time 3D.
- docs/BUILD_SPEC.md Milestone 0: AGENTS.md and docs/DECISIONS.md are on the list of files this repo
  keeps when copying the starter. Take the starter's guard.cfg on purpose to turn on the test gate.
- QUEUE.md: OPEN QUESTIONS section for the two things Duff hasn't decided (below).
- Short "Why" notes were added in every changed file (Duff: "write why in all files for better memory").

**Why**
- Claude Code hooks only fire inside Claude Code. Grok and other agents could push to main or
  force-push without anything stopping them. A Git hook binds every agent. `--no-verify` still
  skips it, so CI and the fresh-eyes gate stay the backstop.
- Claude Code skips AGENTS.md when a CLAUDE.md exists unless CLAUDE.md imports it with `@AGENTS.md`.
  Rules were split between files only some agents read. Now there's one source.
- Art: Duff locked ink and blood on 3D on Nov 20 (docs/style-guide.md; he called the 3D ink test
  "Excellent"). style-guide.md, QUEUE.md, CLAUDE.md and BUILD_SPEC.md already said so, but DESIGN.md
  still listed "Art style lock" as open and ART_LOG.md said no style was picked. Only the stale notes changed.

**Research behind it** (Grok, Nov 21: X, Reddit, dev blogs on AI coding setups)
- Rules that keep getting broken become hooks, not prose (r/ClaudeCode, "corrected twice = a hook").
- AGENTS.md as the shared file, CLAUDE.md importing it:
  https://codexguild.com/blog/claude-md-agents-md-best-practices and Claude Code memory docs
  https://code.claude.com/docs/en/memory (the `@path` import syntax).
- Keep always-loaded files short (under about 200 lines) and point to topic files instead of copying them.
- Skipped: live Godot-editor connectors for AIs. They need a desktop editor, and Duff is phone-only.
- Later, once Hunter has code: a parse check after every script edit, and screenshot comparison in CI.

**Review findings** (fresh-eyes on 49e239a: changes requested)
- Blocking, fixed: BUILD_SPEC's Milestone 0 step kept only CLAUDE.md, QUEUE.md, PITCH.md and
  style-guide.md when copying the starter. Hunter's rules now live in AGENTS.md, so copying the
  starter over it would have lost them. AGENTS.md is now on the keep list (plus DECISIONS.md).
- Non-blocking: merge godot-game-starter #11 first, because BUILD_SPEC now points to the starter's
  AGENTS.md sections. In Claude Code's mode `--force-with-lease` still gets through. AGENTS.md now
  says so, and the Git hook blocks it. Delete-only code pushes skip the test gate (moot while
  `test_cmd` is empty), and the hook lets pushes through if guard.py is missing (on purpose).

**Still open (Duff decides; also in QUEUE.md; don't change until he says)**
- Godot version: docs/BUILD_SPEC.md says 4.5-stable, while standards/00-core.md and the starter use 4.6.3.
- Is Hunter greenlit and the active game? docs/PITCH.md says "Not greenlit for building; Lethemoor
  is the active game", but QUEUE.md and CLAUDE.md say Duff greenlit coding on Nov 20 for Nov 21.

# Decisions log (catch-up file for Claude, Grok and any agent)

Newest first. Dates are America/Chicago. Each entry: what changed, why, where the idea came from,
what review found, and what is still open. Add an entry whenever a session changes how agents
work here or settles a design question. AGENTS.md lists this file in its reading order.
Game-design decisions themselves live in docs/DESIGN.md; this file is the "why" and the history.

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
8. Keyboard/gamepad: ATTACK = light, CROUCH = heavy, AIM = special toward, JUMP = special up, DODGE =
   dodge. No new actions were added to Controls.
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

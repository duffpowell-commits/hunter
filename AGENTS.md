# AGENTS.md: the rulebook for any coding AI in Hunter (Grok, Claude, Codex, Copilot...)

This file is the source of truth for commands and standing rules in this repo. Claude Code loads it
through the `@AGENTS.md` line at the top of CLAUDE.md. CLAUDE.md keeps only the handoff (where
things stand) and Claude-only notes. Topic rules live in `standards/` (index: GROK_STANDARDS.md);
this file points to them rather than copying them. Repo-specific rules here win where they are more
specific than `standards/`.
Why (Nov 21, 2026): Claude Code skips AGENTS.md when a CLAUDE.md exists unless CLAUDE.md imports it,
so rules kept only here were invisible to Claude, and rules kept only in CLAUDE.md to everyone else.

## First step of every session (required, once per clone)
```sh
git config core.hooksPath .githooks
```
This turns on `.githooks/pre-push` for every agent, not just Claude Code (details under Guards).
Why: Claude Code hooks only fire inside Claude Code, so Grok and other agents could skip them.

## Commands
Merged from godot-game-starter's AGENTS.md at Milestone 0 (Nov 21, 2026). Why: Hunter is now a copy
of the starter, so its commands apply here; this file stays the one rulebook (docs/DECISIONS.md).
- Engine: Godot 4.7.2-stable (Grok recommended it to match the starter, its CI and the latest
  Android editor, and Duff confirmed "lock in 4.6.3" on Nov 21). Version lives in `GODOT_VERSION` (`.github/workflows/build.yml`) + `config/features`.
- Godot in a cloud sandbox: 4.7.2-stable Linux zip from GitHub releases -> `/usr/local/bin/godot`.
  Fresh clone: `godot --headless --path . --import`.
- Tests: `tools/test.sh` -> `TESTS PASS` (runs `test_cmd` from `.claude/hooks/guard.cfg`: parse
  check `tools/check_scripts.gd` + rule tests `tests/run_tests.gd` -> `ALL PASS`; records the
  passing tree for the push guard).
- Flow + screenshots: `tools/autoplay.sh` -> last line `AUTOPLAY PASS` (also writes `docs/renders/gameplay.mp4`).
- Push guard self-test: `tools/test_push_guard.sh` -> `PUSH GUARD PASS` (local bare remote, never GitHub).
- CI: `gh api repos/duffpowell-commits/hunter/actions/runs?per_page=3` (gh GraphQL is blocked in sessions).

Before every push: `tools/test.sh` prints `TESTS PASS`, then `tools/autoplay.sh` prints `AUTOPLAY PASS`.
Before any merge: a fresh-eyes review (docs/FRESH_EYES.md); CI keeps the PR pending until then.

## Read first, in order
1. **GROK_STANDARDS.md**: the index of the rulebook for Duff's games. Always read
   `standards/00-core.md`, then only the `standards/*.md` files your task needs. Both are copied
   unchanged from `duffpowell-commits/godot-game-starter`; that copy is the master.
2. **CLAUDE.md**: this repo's handoff (what's decided, what's next).
3. **docs/DECISIONS.md**: dated log of what changed and why, plus open questions. Read it to catch up.
4. **docs/BUILD_SPEC.md**: what to build for Hunter. QUEUE.md: what to work on now.

## Starting the code
Milestone 0 is done (Nov 21): the godot-game-starter template was copied in (scenes, scripts,
autoloads, CI, signing, tests, autoplay bot) and renamed Hunter, base canvas 720x1280. Next is
Hunter's Milestone 1 on top (docs/BUILD_SPEC.md). Hunter is a 3D game: use the template's
`Character3D` and keep every movement and standards PASS line green (`standards/02-movement.md`,
`standards/12-testing.md`). Since M1 (Nov 21) `scripts/game.gd`'s PLAY section is Hunter's
arena (`arena.gd` + `combat.gd`, numbers in `data/*.json`).

## Standing rules
- Duff works phone-only (Android, Godot Android editor). No desktop-only tools. GDScript only.
- UI through `ui.gd` helpers. Sounds a player must notice: `Subs.cue`. Gameplay colours: `UI.key()` + a shape cue.
- Gameplay scenes handle focus-out (pause + save) and the back button, deferred, like `game.gd`.
  Save at checkpoints; bump `Save.VERSION` + migrate when the format changes.
- 3D characters: `Character3D` on the shared skeleton, real clips only (docs/MOVEMENT_3D.md).
- Every gameplay number gets a TUNE slider (`standards/03`). Every new feature gets an autoplay PASS line.
- Renderer is Compatibility everywhere. Visual decisions need real engine renders, saved to files.
- Base canvas 720x1280 with `stretch/scale` 1.3333, so UI code still lays out on a 540-wide canvas
  and the touch rule in `ui.gd` holds. The scale is Grok's choice waiting on Duff's review, not his
  rule. Why (Nov 21): BUILD_SPEC asks for 720x1280; the starter's UI was tuned for 540 wide (docs/DECISIONS.md).
- Push after every chunk of work; merge to main at the end of every milestone.
- Up to three milestones per session, merged and handed off after each. Save renders to files, not chat.
- After an engine upgrade delete `.godot/imported/` (stale cache = T-pose).
- Prompts in Forge are public: never put private info in them. Duff's likeness is OK (his call, Nov 24, 2026);
  copy his real tattoos, never invent them.
- Never put secrets in the repo, commits, logs or chat. Duff adds secrets himself.
- Signing: one keystone for every game except Lethemoor (docs/SIGNING.md). Never make another key.

## Guards (enforced, Nov 21)
- One rule script, two triggers: `.claude/hooks/guard.py`. Settings: `.claude/hooks/guard.cfg`.
  - Claude Code runs it before every tool call (`.claude/settings.json`).
  - Every agent runs it on `git push` through `.githooks/pre-push`, once `core.hooksPath` is set (above).
- It blocks force push (caveat: in Claude Code's mode `--force-with-lease` still gets through; the
  Git hook blocks it), direct push to main, writing/generating signing keys and committing secret
  files (.env, keystores, secrets.*; names only), and pushing code the tests didn't pass on
  (`test_cmd` is set since Milestone 0, Nov 21: the starter's guard.cfg, taken on purpose).
- The Git hook sees what a push does, not its flags: any push that rewrites the remote branch counts
  as a force push (so `--force-with-lease` is blocked there too), and deleting main is blocked.
- `git push --no-verify` skips the Git hook. Don't use it; CI and the fresh-eyes gate stay the backstop.
- PRs: the `fresh-eyes` status stays pending until a fresh-context review posts `FRESH-EYES REVIEW: PASS` on the head
  commit (`docs/FRESH_EYES.md`). Pending is not green: sessions check the combined status and don't merge
  (GitHub itself doesn't block it).

## Layout
- docs/BUILD_SPEC.md: how to build it, milestone by milestone. Start here for code.
- docs/DESIGN.md: every locked decision.
- docs/PITCH.md: one-page pitch + pillars + not-in-this-game.
- docs/style-guide.md: the locked art style (ink on 3D).
- docs/ART_LOG.md: every render with prompt, seed, verdict.
- docs/DECISIONS.md: dated catch-up log (what changed, why, open questions).
- docs/art/: renders. Art is made in Foxboard Forge (repo duffpowell-commits/Foxboard, forge/jobs, job ids `dh-*`), Canva as fallback (art-director skill).
- tasks/todo.md, tasks/lessons.md.
- Code (from the starter, Nov 21): `scenes/` boot, intro, title, game, character_test (Control +
  script; UI built in code). `scripts/` autoloads: Controls, Settings, Save, Audio, Subs, Feel,
  Telemetry, Loader, Battery, Updater, DebugMenu, Autoplay. Helpers: `ui.gd`, `config.gd`,
  `bug_report.gd`, `settings_sheet.gd`, `tune_panel.gd`, `camera_rig.gd`, `coach.gd`,
  `character3d.gd` (+ foot_ik, aim_twist, ragdoll). `shaders/` toon + outline (the ink look).
- Hunter code (M1, Nov 21): `arena.gd` (3D arena, hero, dummy, pipe), `combat.gd` (rules, no
  nodes), `swipe_pad.gd`, `virtual_stick.gd`, `game_data.gd` (reads `data/*.json`: moves,
  enemies, weapons). Content is data: a new enemy or weapon is a JSON edit.
- Hunter code (M2, Nov 23): `pews_arena.gd` (The Pews, extends `arena.gd`: Vesper, minions, plate,
  loot, finishers), `pews_rules.gd` (rules, no nodes), `pews_tuning.gd` (TUNE sliders onto
  `data/pews.json`). `game.gd` loads the Pews on NEW GAME; autoplay still visits the training arena.
- Hunter code (M3, Nov 24): `profile.gd` (autoload Profile: what survives runs), `lair_rules.gd`
  (rules, no nodes), `hunt_arena.gd` (base of the Pews and the lair: foes, steering, perks, voices),
  `lair_arena.gd`, `lair_sheets.gd` (station sheets), `lair_tuning.gd`, `voice_box.gd`. Data:
  `lair.json`, `recipes.json`, `trophies.json`, `realms.json`, `voices/<id>.json`.
- `tests/run_tests.gd` rule tests. `tools/` check_scripts.gd, test.sh, autoplay.sh, gen_audio.py.
- `assets/audio/` (list every clip in SOURCES.md), `assets/art/`, `assets/models/`. `grok_art/` never ships.
- `signing/` keystone (encrypted) + `unlock.sh`. `docs/renders/` autoplay screenshots, committed at
  720x1280 (standards/00-core.md "Show, don't describe"; refresh them with `tools/autoplay.sh` after
  visual changes). Only `gameplay.mp4` is ignored. Why (Nov 21 review): this line used to say they
  weren't committed, which contradicted that standard.
- Starter docs that came along: docs/MILESTONE0.md (what the foundation does), docs/MOVEMENT_3D.md,
  docs/SIGNING.md and the rest of docs/ not listed above.
- `.claude/` Claude Code hooks + guard rules; `.githooks/` the Git pre-push hook for every agent; `tools/` test.sh, test_push_guard.sh.

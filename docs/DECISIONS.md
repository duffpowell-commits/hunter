# Decisions log (catch-up file for Claude, Grok and any agent)

Newest first. Dates are America/Chicago. Each entry: what changed, why, where the idea came from,
what review found, and what is still open. Add an entry whenever a session changes how agents
work here or settles a design question. AGENTS.md lists this file in its reading order.
Game-design decisions themselves live in docs/DESIGN.md; this file is the "why" and the history.

## 2026-11-21: Hunter greenlit; Godot 4.6.3; Milestone 0 built (copy of godot-game-starter)
**Decisions (Duff, Nov 21)**
- Hunter is greenlit for building. Duff: "lets move forward to building a small sample of hunter".
  docs/PITCH.md now says so. This settles the open question about PITCH.md vs QUEUE.md and CLAUDE.md.
- Engine: Godot 4.6.3-stable, not 4.5-stable. Duff asked which version gives him the capabilities
  he wants. 4.6.3 is newer, it matches godot-game-starter and its CI (`GODOT_VERSION`), and it
  matches the latest Godot Android editor he edits on. docs/BUILD_SPEC.md and QUEUE.md are updated.

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
  - `stretch/scale` 1.3333 was added. Why: the starter's UI and its touch rule (72 units >= 48 dp) were
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

**Verified locally (Godot 4.6.3 headless):** SCRIPTS OK, ALL PASS (22), TESTS PASS, AUTOPLAY PASS
with every starter line plus HUNTER PASS, PUSH GUARD PASS, and an Android debug APK export (see
the PR for details). One flaky `CAMERA SMOOTH` failure on a slow sandbox (tasks/lessons.md).

**Still open**
- Duff: add the `KEYSTONE_PASS` Actions secret if it isn't there yet. Without it CI signs with a
  throwaway key and APKs can't update in place (docs/SIGNING.md).
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

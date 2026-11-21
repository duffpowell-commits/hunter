# AGENTS.md: the rulebook for any coding AI in Hunter (Grok, Claude, Codex, Copilot...)

This file is the source of truth for commands and standing rules in this repo. Claude Code loads it
through the `@AGENTS.md` line at the top of CLAUDE.md. CLAUDE.md keeps only the handoff (where
things stand) and Claude-only notes. Topic rules live in `standards/` (index: GROK_STANDARDS.md);
this file points to them rather than copying them. Repo-specific rules here win where they are more
specific than `standards/`.

## First step of every session (required, once per clone)
```sh
git config core.hooksPath .githooks
```
This turns on `.githooks/pre-push` for every agent, not just Claude Code (details under Guards).

## Commands
- No game code yet (design repo), so there is no test gate: `test_cmd` in `.claude/hooks/guard.cfg`
  is empty and `tools/test.sh` just prints `no test_cmd`.
- Push guard self-test: `tools/test_push_guard.sh` -> `PUSH GUARD PASS` (local bare remote, never GitHub).
- When code starts (Milestone 0): copy `.claude/hooks/guard.cfg` + `tools/test.sh` from godot-game-starter
  for the test gate, and merge the starter's AGENTS.md Commands section into this one. Then before
  every push: `tools/test.sh` -> `TESTS PASS`, `tools/autoplay.sh` -> `AUTOPLAY PASS`
  (`standards/12-testing.md`).
- Before any merge: a fresh-eyes review (docs/FRESH_EYES.md); CI keeps the PR pending until then.

## Read first, in order
1. **GROK_STANDARDS.md**: the index of the rulebook for Duff's games. Always read
   `standards/00-core.md`, then only the `standards/*.md` files your task needs. Both are copied
   unchanged from `duffpowell-commits/godot-game-starter`; that copy is the master.
2. **CLAUDE.md**: this repo's handoff (what's decided, what's next).
3. **docs/BUILD_SPEC.md**: what to build for Hunter. QUEUE.md: what to work on now.

## Starting the code
Milestone 0 means **copying the godot-game-starter template** into this repo (scenes, scripts,
autoloads, CI, signing, tests, autoplay bot), not rebuilding it. Then build Hunter's Milestone 1 on
top. Hunter is a 3D game: use the template's `Character3D` and keep every movement and standards
PASS line green (`standards/02-movement.md`, `standards/12-testing.md`).

## Standing rules
- Duff works phone-only (Android, Godot Android editor). No desktop-only tools. GDScript only once code starts.
- Push after every chunk of work; merge to main at the end of every milestone.
- Up to three milestones per session, merged and handed off after each. Save renders to files, not chat.
- Visual decisions need real engine renders once there is an engine build.
- When code starts, Milestone 0 is the game-repo-rules Foundation checklist.
- Prompts in Forge are public: never put Duff's likeness or private info in them.
- Never put secrets in the repo, commits, logs or chat. Duff adds secrets himself.

## Guards (enforced, Nov 21)
- One rule script, two triggers: `.claude/hooks/guard.py`. Settings: `.claude/hooks/guard.cfg`.
  - Claude Code runs it before every tool call (`.claude/settings.json`).
  - Every agent runs it on `git push` through `.githooks/pre-push`, once `core.hooksPath` is set (above).
- It blocks force push, direct push to main, writing/generating signing keys and committing secret
  files (.env, keystores, secrets.*; names only), and (once `test_cmd` is set) pushing code the tests
  didn't pass on.
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
- docs/art/: renders. Art is made in Foxboard Forge (repo duffpowell-commits/Foxboard, forge/jobs, job ids `dh-*`), Canva as fallback (art-director skill).
- tasks/todo.md, tasks/lessons.md.
- `.claude/` Claude Code hooks + guard rules; `.githooks/` the Git pre-push hook for every agent; `tools/` test.sh, test_push_guard.sh.

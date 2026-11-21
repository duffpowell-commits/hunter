# AGENTS.md

Any coding AI working in this repo (Grok, Claude, Copilot, Codex...): read **GROK_STANDARDS.md**
first: it is the index of the rulebook for Duff's games. Always read `standards/00-core.md`, then
only the `standards/*.md` files your task needs. Both are copied unchanged from
`duffpowell-commits/godot-game-starter`; that copy is the master.

Then read, in order:
1. **CLAUDE.md**: this repo's handoff (what's decided, what's next).
2. **docs/BUILD_SPEC.md**: what to build for Hunter.

Starting the code: Milestone 0 means **copying the godot-game-starter template** into this repo
(scenes, scripts, autoloads, CI, signing, tests, autoplay bot), not rebuilding it. Then build
Hunter's Milestone 1 on top. Hunter is a 3D game: use the template's `Character3D` and keep every
movement and standards PASS line green (`standards/02-movement.md`, `standards/12-testing.md`).

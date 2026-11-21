@AGENTS.md

# Hunter (working title)

Top-down action RPG: you're a half-demon serial killer of demons. Stalk, kill, scavenge, build your lair, eat the bosses and wear their movesets. Street Fighter-style combos in combat, Westland Survival-style scavenging outside it. Owner: Duff. Read this first; it is the handoff between sessions. Commands, standing rules, guards and layout: AGENTS.md (imported above), shared by every coding AI.
Why the import (Nov 21): Claude Code skips AGENTS.md when CLAUDE.md exists unless it's imported. Catch-up log: docs/DECISIONS.md.

## Where things stand (Nov 21, 2026)
- **Nov 21: Milestone 0 built** (Grok, PR "Milestone 0"): godot-game-starter copied in, renamed
  Hunter, base canvas 720x1280, Godot 4.6.3. Tests, autoplay and the APK export pass. Duff greenlit
  Hunter and picked 4.6.3 on Nov 21 (docs/DECISIONS.md). **Next: Milestone 1** (docs/BUILD_SPEC.md):
  the 3D test arena slice. `scripts/game.gd` is still the starter's "Orb Catch" placeholder.
- Phase: design done enough to build. Duff greenlit coding on Nov 20 (another coding AI starts Nov 21). **Coding starts at docs/BUILD_SPEC.md**: hard rules, controls, systems with numbers, milestones M0-M5+.
- Build spec: docs/BUILD_SPEC.md. Full design: docs/DESIGN.md. Pitch: docs/PITCH.md. Queue: QUEUE.md. Art: docs/style-guide.md + docs/ART_LOG.md.
- Done: core concept, combat rules, story spine (Mom, Samael Price, Furfur Kemp), 5 bosses/voices, 6 realms. First sprite exploration rendered (docs/art/explore-20261120/).
- Art LOCKED Nov 20: ink and blood on real-time 3D, full range of movement (docs/style-guide.md, docs/art/ink-3d/).
- Nov 21 (Grok): Git pre-push hook for every agent (`.githooks/pre-push`); rules moved into AGENTS.md. Both open questions (Godot version, active game) were settled by Duff on Nov 21.
- Design still open (doesn't block code; use the BUILD_SPEC placeholders): the protagonist (name, look, day life), Mom's name and hunter past, the hunter/detective on your tail, endings, title.

## Claude-only notes
- `.claude/settings.json` runs `.claude/hooks/guard.py` before every Bash/Write/Edit call. A blocked
  call comes back with the reason; fix the cause, don't work around it.
- In that hook `--force-with-lease` is allowed; the Git pre-push hook still blocks any push that
  rewrites the remote branch, so plan on merging, not rewriting.

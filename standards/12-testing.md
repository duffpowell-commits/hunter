# Testing: the bot and the rule tests

- **Autoplay bot** plays the whole game with real taps, saves screenshots to `docs/renders/`, prints
  one `PASS` line per check, and records the 15 s vertical gameplay clip. CI fails on any `FAIL`.
  **Every new feature adds a PASS line.**
- **Rule tests** (`tests/run_tests.gd`): one `test_*` function per rule.
- **A new test only counts once you've seen it fail** (break the code, watch it go red, restore).
- Bot checks use real time, not frame counts: CI machines are slow.
- Before every push:
  - `godot --headless --path . --script tools/check_scripts.gd` -> `SCRIPTS OK`
  - `XDG_DATA_HOME=$(mktemp -d) godot --headless --path . --script tests/run_tests.gd` -> `ALL PASS`
  - `tools/autoplay.sh` -> `AUTOPLAY PASS` (also writes `docs/renders/gameplay.mp4`)

# M5 local verification — Godot 4.7.2 (Nov 27, 2026)

The approved seven-item implementation was checked on the same final source tree before pushing.

- `tools/test.sh`: `ALL PASS (91)` and `TESTS PASS`. The first five new test functions were mutation-tested in isolated temporary copies: broken unlock, boss double strike, locked voice, stale profile priority and coin multiplier all went red. A sixth test reproduced the exact-head review finding (minion-only Loaded Dice interrupted Vesper’s prayer), then passed after the fix.
- `tools/autoplay.sh`: `AUTOPLAY PASS`, with real engine Compatibility renders and a gameplay clip. The cloud lacks xvfb-run; an Xorg dummy wrapper supplied its display without changing the repository tool. Baseline Godot shutdown warnings (ObjectDB/resource cleanup) remain, with no script errors or failed checks.
- `godot --headless --export-release Web`: exit 0, generated HTML, WASM and PCK.
- `godot --headless --export-debug Android`: exit 0 with an unsigned preset in a temporary copy. AAPT confirms package `com.duffpowell.hunter`, and archive integrity passed. Production preset and encrypted keystone remain untouched. The CI-signed APK is required for installation/update.
- Actual renders, 720×1280: `docs/renders/flow_casino_*.png`, `flow_gus_voice_edge.png`, and updated map sheet. Existing approved source art and pet model unchanged.
- No device FPS/touch verification in the cloud. The generic shared rigs are placeholders, as permitted by BUILD_SPEC; no assets purchased or generated. No blind-player review initiated.

## New autoplay checks

```text
CASINO ENTRY PASS (Gus and Vig)
CASINO SLOT PASS
CASINO DUSTER PASS
CASINO FOES PASS (real pad taps)
GUS TELEGRAPH PASS
GUS ALL IN PASS (phase one defeated with pad holds)
GUS DICE TELL PASS (phase two warns of slot activation)
GUS DICE PASS (projectiles and slot effect)
GUS HOUSE EDGE TELL PASS
GUS HOUSE EDGE PASS (strike countered)
GUS PHASE PASS
GUS REWARDS PASS
CASINO SAVE TITLE PASS
CASINO RESUME PASS
CASINO RETURN PASS
GUS GRUDGE PASS
GUS VAULT DEFENDERS PASS
GUS VAULT PASS
GUS VOICE MOVES PASS (all three available after debt)
GUS VOICE COIN PASS (real DOWN swipe)
GUS VOICE DICE PASS (real toward swipe, hit landed)
GUS VOICE EDGE PASS (real away swipe counters incoming damage)
AUTOPLAY PASS
```

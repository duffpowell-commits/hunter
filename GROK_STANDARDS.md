# Game Standards (for any coding AI: Grok, Claude, Copilot, anyone)

Owner: Duff. These rules apply to every Duff game repo. Read this whole file before writing code.
If a repo's own README/CLAUDE.md/AGENTS.md says something more specific, that wins for that repo.
Copy this file unchanged into any game repo. The master copy lives at
`duffpowell-commits/godot-game-starter/GROK_STANDARDS.md`.

Rules are written engine-agnostic: they stay true if a game moves from Godot to Unity or Unreal.
Under each rule, "Godot today" says how the template already does it.

---

## 0. How Duff works (read first)

- **Duff is phone-only.** He uses a phone browser, GitHub on the phone and the Godot Android
  editor. Never give him desktop steps. If something can't be done from a phone, say so up front.
- **Do the work, then tell him.** Ask first only if it costs money, can't be undone, or a wrong
  guess is expensive. Ask once, with tappable choices.
- **Green merges itself.** In game repos a pull request with all checks passing gets merged without
  asking Duff. Red CI never merges. Never skip, disable or delete a test to get green.
- **Nothing is "done" until it's checked**: merged to main, CI green, the build installed or live.
- **Show, don't describe.** Visual changes need real engine screenshots saved in `docs/renders/`.
- **Never put secrets in the repo, commits, logs or chat.** Duff adds secrets himself in GitHub
  settings.
- One AI session per repo at a time. `git fetch` before starting and before pushing. Push after
  every chunk of work. Merge to `main` at the end of every milestone.
- Plain words for Duff: short sentences, no jargon, lead with the result.

## 1. Milestone 0 = copy the template, don't rebuild it

Every new game starts from `duffpowell-commits/godot-game-starter`, which already has Milestone 0
built and tested. **Do not rebuild any of this. Copy the template and start at Milestone 1.**

To start a game (all from the phone): github.com -> godot-game-starter -> **Use this template** ->
new repo named after the game -> add the `KEYSTONE_PASS` secret -> first push to `main` builds
the APK. Then rename the game in `project.godot` (`config/name`), fill `docs/PITCH.md`, write the
repo's handoff file, and build the core loop (Milestone 1). Replace the placeholder game in
`scripts/game.gd` (its PLAY section); keep everything else.

Milestone 0, already in the template (every game must keep all of it working):
1. Handoff files: README/CLAUDE.md/AGENTS.md, QUEUE.md, docs/PITCH.md, docs/style-guide.md.
2. CI on every push: parse every script, rule tests, autoplay bot, signed APK. On `main` it uploads
   `<repo>.apk` and `version.json` to the repo's `dev` release.
3. One signing key for every game (section 4).
4. **In-app updater**: on launch and when the app returns to the front, it reads `version.json` from
   the `dev` release; if newer, it offers UPDATE NOW and installs the new APK. Version shown on the
   title (`v0.1.<build>`).
5. **REPORT A BUG** button on the title and pause screens: opens a prefilled GitHub issue (or copies
   the text), adding build, device, scene, game state, fps and "crashed last run".
6. Full scene flow: boot -> intro (once, skippable) -> title -> game -> pause -> game over -> title.
   Pause and save when the app loses focus (phone call, home button). Android back pauses, never quits.
7. Autosave + CONTINUE: save at checkpoints and on pause; game over clears the save.
8. Settings: music, SFX, brightness, vibration, text size, subtitles, high contrast, colorblind
   colours, left-handed, invert look, sensitivity, low graphics, share anonymous stats, CONTROLS.
9. Touch: buttons at least 72 base units tall (~56 dp), 18 apart; left-handed mirrors the controls.
10. Audio buses Music + SFX that exist at boot.
11. Subtitles + sound captions, high-contrast theme, colourblind-safe colours plus shape cues.
12. Dev menu in debug builds (5 taps on the version, 3-finger tap, F1): FPS, god mode, skip level,
    3D character test, phone speed test, clear save.
13. Autoplay bot: plays the whole game with real taps, saves screenshots, prints one `PASS` line per
    check. CI fails on any `FAIL`. **Every new feature adds a PASS line.**
14. Placeholder art drawn in code; real art comes from Foxboard (section 3.8).

## 2. Movement: the full range the engine supports

**Rule:** characters use the full range of movement the current engine supports: real skeletons,
real animation clips, real physics. **Never fake movement** by bobbing, tilting, squashing or
sliding a still image. A move with no animation clip doesn't exist yet; placeholder = the stand-in
mannequin doing the real clip.

Keep it portable so it survives an engine change:
- One **standard humanoid skeleton** for every character: UE5 mannequin bone names (`pelvis`,
  `spine_01..03`, `neck_01`, `Head`, `thigh_l`, `calf_l`, `foot_l`, `upperarm_r`, `hand_r`...).
- Models and clips in **glTF 2.0 (`.glb`)**, FBX only as a fallback. List every model/clip pack and
  its licence in `assets/models/SOURCES.md`.
- Movement numbers (speeds, jump height, timings) live as plain constants at the top of the
  character script.
- Characters under ~5k triangles each so several fit on a phone.

What "full range" means today (all must work for any game that has 3D characters):
- Locomotion: idle, walk, jog, sprint in any direction; stick length = speed.
- 8-way / strafe: chest faces the target while legs walk any direction; backpedal.
- Turn in place with real steps. Jump with take-off, fall and land. Crouch (won't stand under a roof).
- Foot IK: feet planted on slopes, stairs and kerbs; hips drop to reach.
- Look-at: head turns to the target.
- Hit reactions: flinch, and knockback driven by the clip's root motion.
- Physics ragdoll on death (an animated death on low graphics).
- Climb ledges (also out of water), vault low walls, swim. Each switchable per game.

Godot today: `scripts/character3d.gd` (`Character3D`) plus `foot_ik.gd`, `aim_twist.gd`,
`ragdoll.gd`, `LookAtModifier3D`; clips from Quaternius Universal Animation Library 1 + 2 (CC0, one
skeleton). Playground: `scenes/character_test.tscn`. Details: `docs/MOVEMENT_3D.md`.

## 3. The twelve game standards

Each is engine-agnostic. Each has a bot check in the template; keep it passing.

1. **Game feel.** Every hit gets all five: hit-stop (~60 ms freeze on both fighters), screen shake,
   a sound, a particle burst, and a phone buzz. Bigger hits = more of each.
   Godot today: `Feel.impact(pos, power, parent)` + `Character3D.hit()`. Check: `FEEL PASS`.
2. **Camera.** Smooth follow with look-ahead; never passes through walls (cuts in front of them);
   frames the current target (pulls back to keep both on screen); shakes on impact.
   Godot today: `scripts/camera_rig.gd`. Checks: `CAMERA SMOOTH/WALL/FRAME PASS`.
3. **Frame budget.** 60 fps on Duff's phone. CI fails a build that breaks the scene budget
   (draw calls <= 250, triangles <= 300k, game code + physics <= 8 ms per frame, with a typical fight
   on screen). The dev menu's PHONE SPEED TEST runs that fight on the phone and shows PASS
   (>= 58 fps average, >= 45 fps worst 1%). Godot today: `perf_test()` in the playground. Check: `PERF PASS`.
4. **Responsive controls.** Input buffering (a press up to 0.15 s early still counts), coyote time
   (jump up to 0.12 s after leaving an edge), every action cancels into a dodge, presses during a
   stagger are queued. Checks: `BUFFER`, `COYOTE`, `CANCEL PASS`.
5. **Lighting / readability.** The hero always reads against the floor: hero rim light, a key light
   that only lights characters, no black-on-black. Contrast hero vs floor >= 2:1 in normal light and
   in the dark. Check: `READ PASS`.
6. **Audio.** Footsteps from the animation, sound picked by surface (stone, wood, grass, water...);
   music with an explore layer and a combat layer that crossfade in sync; music ducks under
   important sounds. Godot today: `Audio.step()`, `Audio.music_layers()`, `Audio.set_intensity()`,
   `Audio.duck()`; floors carry a `surface` tag. Checks: `STEPS`, `MUSIC`, `DUCK PASS`.
7. **First 60 seconds.** Playable within 10 s of launch (intro skippable, plays once). Controls are
   taught by doing: one hint of 4 words or fewer, shown until the player does it, then gone for
   good. No text walls, no tutorial screens. Godot today: `Coach.teach()`. Checks: `BOOT`, `COACH PASS`.
8. **Portable assets.** Standard humanoid skeleton, glTF, sources listed with licences. Source art
   lives in Foxboard (Duff's art app; finished art arrives in `grok_art/<date>-foxboard/` via its
   Send to game button). Check: `test_models_portable`.
9. **Analytics and crash hooks.** Log key events locally; detect a run that didn't close cleanly and
   report it next launch (offer REPORT A BUG). Data leaves the phone only if the player turned on
   "share anonymous stats" AND the game has an endpoint set. Random install id only, nothing
   personal. Godot today: `Telemetry.event()`. Checks: `TELEMETRY PASS`, `test_telemetry_*`.
10. **Haptics.** A buzz on every hit, scaled by power; respects the Vibration setting.
11. **Controller support + remapping.** Every action works on touch, keyboard and gamepad. Games read
    named actions (`move_left`, `jump`, `attack`, `dodge`, `crouch`, `aim`, `pause`), never raw keys.
    Players remap keys and pad buttons in Settings -> CONTROLS; saved; reset to defaults.
    Godot today: `Controls` autoload. Checks: `PAD`, `REMAP PASS`, `test_controls_*`.
12. **Offline-first, no forced login.** The whole game plays with no network and no account. Network
    features (updater, stats) fail silently and never block play.

## 4. Signing: one key for every game

- Android only installs an update over an app signed with the same key. Every Duff game is signed
  with ONE key, the **keystone**: `signing/keystone.keystore.enc` (encrypted) +
  `signing/keystone.sha256` (fingerprint), unlocked in CI by the repo secret **`KEYSTONE_PASS`**
  via `signing/unlock.sh`. Games made from the template already carry it.
- Each game repo needs the `KEYSTONE_PASS` secret (Duff adds it: Settings -> Secrets and variables
  -> Actions). Without it CI signs with a throwaway key and warns; that APK can't update an
  installed copy.
- Package name `com.duffpowell.<repo>`, APK `<repo>.apk`, version code = CI run number. All derived
  from the repo name; no edits needed.
- **Lethemoor is the exception**: it keeps its own key. Never sign another game with it.
- Never make a new key, never commit an unlocked keystore or the passphrase, never print it.

## 5. Tech rules

- Godot 4.5, GDScript only (no C#, no native plugins), Compatibility renderer everywhere (runs on
  phones and iPhone Safari). Portrait 540x960 base unless the game says otherwise.
- Build all UI with the template's `ui.gd` helpers (text size, contrast and touch size come free).
- Every sound a player must notice gets a caption (`Subs.cue`). Every gameplay colour comes from
  `UI.key()` plus a shape cue.
- Every gameplay scene pauses + saves on focus loss and handles the back button (close sheet / pause).
- Save at every checkpoint; bump the save version and migrate when the format changes.
- Before every push: parse check (`tools/check_scripts.gd` -> `SCRIPTS OK`), rule tests
  (`tests/run_tests.gd` -> `ALL PASS`), autoplay (`tools/autoplay.sh` -> `AUTOPLAY PASS`).
- A new test only counts once you've seen it fail.
- Every feature serves the game's pitch, or it gets cut.

## 6. Done means

A change is done when: it's on `main`, CI is green, the bot has a PASS line for it, screenshots are
in `docs/renders/` if it's visual, the handoff file says what changed, and the build is in the
`dev` release for Duff to install.

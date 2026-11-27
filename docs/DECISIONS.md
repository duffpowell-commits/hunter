# Decisions log (catch-up file for Claude, Grok and any agent)

## 2026-11-27: Debt Ledger and presentation (Codex)
- The ledger is a read-only Pause sheet, paginated and scrollable for the 720×1280 portrait canvas. It uses the existing Profile trophies, hunt count, Furfur state, contract and revealed lore rather than introducing a debt balance or quest system. No save migration is needed.
- Intro copy names Cain, the existing bargain and Price's stated promise, without exposing Furfur's hidden clauses. The journal's first page puts the current account first. The camera is slightly wider (48° FOV, previously 45°), retains the existing fixed pitch, and captions no longer cover the idle touch labels. Existing left-handed mirroring is unchanged.
- Vig's sanctuary uses a collision-free rug, cushion and bowl near the existing lair portal. The approved model is unchanged. Its real Survey, Walk and Run clips are the only available compatible clips; sit/sleep and an additional dedicated greeting clip remain open. No paid assets, new locations or Cellar Casino work.
- Duff requested one PR, no merge/public release and no new blind review. Physical phone checks remain pending.

## 2026-11-26: Cain's pet fox (Claude)
- Duff (via the project chat): "we'll make the mascot the main character's pet". He tapped
  "B: upright third eye" on the art card (`docs/art/fox-pet/fox_pet_B_approved.png`).
- Built: `scripts/fox_pet.gd` in the Pews and the lair (added by `hunt_arena.gd`), numbers in
  `data/fox.json`, 20 TUNE sliders (`fox_*` in `lair_tuning.gd`).
- Judgment calls (Duff can change any):
  - Demon Sight = the fox's third eye: the eye flares while SIGHT is on. Story glue, no new button.
  - It never fights and can't be hurt (not a target); it hangs back 4.5 m in a fight so it never
    blocks a swing or the camera.
  - One yip a hunt at an unaware enemy nearby: a small help, not a radar.
  - Lair greet at the door, and the MASCOT.md idea of corruption: at looks 1/2/3 it follows at
    1.2/1.8/2.8 m (warier as Cain turns).
  - Model: free CC0 Khronos fox, recoloured (no Meshy credits spent). It has no sit/sleep clips, so
    it idles with its look-around clip; a custom model is a later Meshy card if Duff wants one.
  - B's two blood-red eyes aren't on the model yet (the texture's eyes are dark); the third eye is.
  - Name: **Vig** (Duff tapped it, Nov 26: the interest on a debt; it ties into the Casino).

## 2026-11-26: free-flow combat + predator stealth (Claude)
Duff, Nov 26 10:00 AM CT: "The fighting isn't very fluid, and most breaks as you go, its too hard to
just tilt the controller, lets get the fight style decided, combat should feel like [a named free-flow brawler] for both stealth options and brawler". Claude wrote an original spec (no names copied) and
Duff tapped **"Buttons + swipe specials"**. Built in one PR; numbers in `data/moves.json` "freeflow".
- **Lunge** (`arena._start`, `Character3D.dash_*`): a strike picks the enemy the stick points at
  (within 70°), else the nearest, up to 6 m; out of reach the hero dashes at 14 m/s and swings on
  arrival. Combo gap 1.2 -> 2.0 s, string gap 0.8 -> 1.2 s, input buffer 0.3 -> 0.45 s.
- **COUNTER** button: any enemy showing its warning (dummy "!", minion wind-up, Vesper's powers)
  within 4.5 m. Cancels the attack, lunges, hits for 14, 0.45 s i-frames. Countering Vesper's prayer
  counts as breaking the heal. A press with nothing to counter locks the button 0.6 s (no mashing).
  The button turns orange and reads "> COUNTER <" when it would work (colour + shape).
- **DODGE** button: roll along the stick, or away from the attacker with no stick. Judgment call: a
  roll, not a vault over the enemy (no vault clip on the shared skeleton yet).
- **Double-tap** on the pad is now a second strike, not a roll.
- **TAKEDOWN / FINISHER** on the context button at 5 / 8 hits; both spend the combo. A takedown drops
  a minion outright; Vesper and Furfur take 40 instead (a takedown can't skip a boss).
- **Pipe** durability 4 -> 8 (BUILD_SPEC said 3-5; raised so a weapon lasts most of a fight). The
  autoplay weapon check sets the TUNE slider to 4 so it still breaks inside one dummy's HP.
- **Stealth**: SNEAK toggle button (the tilt is gone; `sneak_stick_max` slider swapped for
  `minion_sneak_aggro_scale`); the fight starting stands you up. Sneaking, a minion notices you at
  3.2 x 0.35 m; SILENT KILL drops an unaware one within 1.8 m, nobody else turns. Judgment call: from
  any side, not only behind, because idle minions don't patrol or turn yet.
- **Demon Sight** toggle: markers drawn over walls (? unaware info-blue, ! hunting orange, !! red),
  a ring at the feet, a light red screen tint. Free, any time.
- **First hunt** prompts: TAP SNEAK TO CROUCH, TAP COUNTER ON ! (waits for the first warning), TAP
  DODGE TO EVADE replace the tilt and double-tap ones (new ids, so returning players see them).
- Keys/pad (fresh-eyes): COUNTER = U / LB, SNEAK = the CROUCH action (C / Y), DEMON SIGHT = V /
  left-stick click; DODGE = K / B now rolls like the button. An unbreakable prayer
  (`hands_interrupt` 0) can't be countered either.
- For Duff to judge in play: COUNTER cancels every Vesper power within 4.5 m with no cooldown after
  a success; if it makes him too easy, raise `counter_whiff_lock` or shrink `counter_range`.

## 2026-11-26: the 8.5 pass, first-timer fixes before M5 (Claude)
Duff set a new bar (Nov 26): before building more, plan what it takes for a blind first-time player
to score the game 8.5, OK it once, build it in one pass. A blind first-timer played the browser
build for ~30 min and scored it **4.5/10** (no controls, no goal, a camera that dove into the hero,
an ambush at spawn, an unreadable heal, template intro cards, a dark lair). Duff tapped "Build all 8".
1. **Guided first hunt** (`first_hunt.gd`): Coach prompts one at a time, gone once done: DRAG TO
   MOVE, TILT LIGHTLY TO SNEAK, then (once someone's in reach) TAP TO ATTACK, HOLD FOR HEAVY,
   DOUBLE-TAP TO DODGE, SWIPE FOR SPECIAL. Saved in coach.cfg, so a second hunt shows none. The pad
   shows a fist, ATTACK and "TAP · HOLD · 2× TAP · SWIPE"; the stick side shows MOVE.
   Minions stand still until you come within `minions.aggro_radius` (3.2 m), hit them, or Vesper's
   fight starts (base foe AI; the lair raid and Furfur have no aggro_radius, so they're unchanged).
2. **Camera** (`camera_rig.gd`): a wall now tilts the camera up (to `max_pitch` 82) instead of
   pulling it in front of the wall; last resort still never comes within `min_distance` (4 m). It
   looks at the smoothed point it follows, so it never turns.
3. **Fair first boss**: billboard HP bars over minions and Vesper; Laying of Hands shows a green
   "+ HEALING" for 1.4 s (was 0.6 s and a red "!"), a "+18" pops when it lands, and **one hit breaks
   it** (`laying_of_hands.interrupt`, slider). Soft aim: in the fight a swing turns to the nearest
   enemy (Vesper or a minion); `arena.auto_face` 3.0 -> 3.6.
4. **Cold open** (`intro.gd`): four cards (born dying / Mom's deal with Samael Price / you collect
   for him / first name: BROTHER VESPER). The HUD in the Pews reads "GOAL: HUNT VESPER  STUDY n%".
   Writing is placeholder until Duff signs it off.
5. **Lair**: brighter ambient and sun, a lit ring at every station, bigger labels, a bobbing NEXT
   HUNT over the map room when nothing's pending, a one-time MAP ROOM: NEXT HUNT prompt. The context
   button moved from over the middle of the pad to the top of the pad half (it ate attack taps).
6. **Explainers** (`explainer.gd`): the first time $, HEAT, PARTS, CORR, STUDY or weapon wear
   changes, one line explains it, once ever (explain.cfg).
7. **Title**: Brother Vesper key art (docs/art/explore-20261120/vesper-ink-0.png, green keyed out,
   `assets/art/title_vesper.png`), a tagline, the menu anchored to the bottom; local builds say
   "v0.1", not "dev".
8. **Captions**: newest wins; a waiting line cuts in after 0.45 s; cleared on death and GAME OVER.
Also: the fresh-eyes nits from M4 (pipefail on the web export, token via env).
Tests 71/71 (6 new), autoplay adds SAFE START, GUIDED HUNT, HP BAR, PAD CLEAR, HEAL TELL, COLD OPEN,
TITLE ART, EXPLAINER and LAIR READ. Next: a second blind first-timer review, scored against 8.5.

## 2026-11-26: Milestone 4, Furfur Kemp (Claude); hero name Cain Vantre
Duff tapped **Cain Vantre** for the hero (Nov 26). "Cain Mercer" was dropped because it echoes Alex
Mercer of Prototype, a hero whose powers also come from eating enemies. It is in BUILD_SPEC, DESIGN,
QUEUE and the contract sheet ("Bearer: Cain Vantre"). Then Duff said "Go" on M4.

What M4 does (`furfur_rules.gd`, data `furfur.json` + `voices/furfur.json`, sliders in `lair_tuning.gd`):
1. **Lost hunt**: GAME OVER in the Pews now offers **LIMP HOME** (first button). It writes a lair
   arrival at half HP (`limp_hp_fraction`); a night passes like any arrival.
2. **Home invasion**: on that arrival Furfur follows you in (profile `furfur` = "invading"). An intro
   sheet, FIGHT (Back also means FIGHT, like the raid). He's one foe on the shared foe AI: 140 HP,
   12 damage. **You can't lose**: drop and you're back up at 60% HP while he heals 15% ("win ugly").
   Beat him, CHAIN HIM (Back also chains): +5 corruption, he's in the cage by the door for good.
   Quitting mid-fight restarts the fight on CONTINUE.
3. **Cage + talk menu** (station "FURFUR'S CAGE", only once he's caged): TALK = one lore leak a night
   (6, in order: Price & Partners, the buyout, whose debt your kills pay, Mom walked in, the
   unkillable hint). GIVE A MERCY ($10 each: a blanket, water, loosen the chain, a candle) = he reads
   the next hidden clause of Price's contract. READ YOUR CONTRACT shows open clauses plus the ones
   he's read (also from the cold room). He mocks you whenever you come home (worse after a loss).
4. **VENT**: only with a real loss unvented (`failures_unvented`, +1 per death in a hunt). Each VENT
   spends one loss, adds +5 corruption, and adds the next hit to the end of the light string:
   L, L, L, ELBOW, HEADBUTT, HAMMER FIST (3 max, reusing the hook/heavy/launcher clips). Cain
   actually hits him in the cage when you vent.

Judgment calls for Duff (say the word and any of these change):
- **When he comes**: after the first lost hunt, or on the 3rd arrival home if you never lose
  (`after_hunts`), so nobody misses him. The spec only names the lost-hunt path.
- **Raid vs Furfur**: if heat also calls a raid that night, Furfur comes first and the raid follows
  once he's chained.
- **Can't-lose fight**: dropping is never GAME OVER in his fight (DESIGN "you win ugly").
- **VENT costs corruption** (+5), per BUILD_SPEC Corruption ("rises with venting on Furfur").
- **All writing is placeholder**: his lines, the 6 lore leaks and the 4 hidden clauses. Placeholders
  hint at locked story (Price's betrayal, Mom); rewrite freely.
- Furfur's model is the shared skeleton with his own colour, like the raiders; real art waits on
  his character design.

**Browser build (same PR)**: Duff asked for the iPhone link the other games have. New "Web" export
preset (threads off, so GitHub Pages needs no special headers) and a CI `web` job; on main it
publishes https://duffpowell-commits.github.io/hunter/. Checked in Chromium at iPhone 13 size,
upright and sideways (WebGL 2, Compatibility renderer, no errors): sideways plays with a wide view
and smaller text. Autoplay timeout 480 -> 600 s for the Furfur checks.

Tests: 65 (3 new, each seen failing by mutating the code). Autoplay: new FURFUR PASS lines with
God mode off (lost hunt, limp home, invasion, win ugly, beaten, chain, talk, mercy, contract, vent,
the longer string from real pad taps, cage on CONTINUE).

## 2026-11-25: Godot 4.7.x only, enforced in CI
Duff, Nov 25: "Lets only build on 4.7." Hunter was already on 4.7.2. `build.yml` now fails if
`godot --version` isn't 4.7.x or `config/features` isn't "4.7", and downloads retry
(`curl -fsSL --retry 5`). Stale 4.6.3 lines in AGENTS.md, QUEUE.md and BUILD_SPEC.md now say 4.7.x
only. Same change as godot-game-starter's.

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
- BRUTAL on a re-hunt adds another voice level each time, uncapped. Cap it or keep it? (fresh-eyes note)
- Fresh-eyes on PR #23 (CHANGES REQUESTED, fixed in the second commit): Back on the raid warning now
  starts the raid and the map room is shut while one is pending; HEAL, losing a raid and Back-on-raid
  got autoplay PASS lines; HEAL moved to the bottom corner (the voice box ate its tap); a v3 save's
  looted props stay looted.
- Quitting (or a killed app) mid-raid restarts the raid from wave 1 on CONTINUE; spent traps stay spent.
  Should a reload count as a lost raid instead? (second fresh-eyes note) **Settled Nov 24 (Duff: "port
  the wave fix"):** CONTINUE now resumes the raid at the wave you left (that wave comes in fresh; beaten
  waves stay beaten, spent traps stay spent), with no warning sheet. `lair_arena.gd` save_state/
  restore_state + `start_raid(from_wave)`; test `test_raid_resumes_at_its_wave` (seen failing on main),
  autoplay `RAID RESUME PASS`.
- Fresh-eyes on PR #21: CHANGES REQUESTED (the update sheet can now pop mid-fight). Not merged.

## 2026-11-23: In-app updates recheck while the game stays open (PR #21, Claude fresh-eyes fixes)

What: the updater polls version.json every 30 s (gate: 120 s since the last check) while the app is open.
The offer never opens in the Game scene (pause screen included: back there resumes play under it),
and a reply that lands there is dropped. LATER or back holds that build until the app restarts.
Why: fresh-eyes review found the first version could cover a Vesper fight with an input-blocking sheet
and re-offered the same build every 2-4 minutes after LATER.
Nov 24: a reply landing while NEW GAME loads the Pews also counts as play, and a sheet already up
when the Game scene enters is withdrawn (not counted as LATER).

## 2026-11-23 — Game title

Duff chose **The Devil You Owe**. The title refers to the soul contract behind the hunts.
Duff confirmed it in the project chat on Nov 23 ("hunter is The Devil You Owe"); merged via PR #22.
The hero still has no name.

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
- PR #22 (working title "The Devil You Owe") was left out of M2: it is his naming call. Duff confirmed it later the same day (entry above).
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

## 2026-11-24: Godot 4.7.2 for every game

- Duff: "Lets go 4.7 for all of our games." 4.7.2 is the latest stable; 4.7 adds a stable Godot Android Build Environment (GABE) for exporting from the phone, HDR output and AreaLight3D. CI `GODOT_VERSION`, `config/features` and the engine lines in AGENTS.md / standards moved from 4.6.3 to 4.7.2. Older entries below keep their original version numbers as history.

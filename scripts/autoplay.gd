extends Node
## Autoload "Autoplay": a bot that plays the whole flow with real taps and saves screenshots.
## Off unless the game is started with `-- --autoplay`. Run it (needs a screen, so xvfb):
##   tools/autoplay.sh            -> docs/renders/flow_*.png, prints one PASS line per check
## It ends with "AUTOPLAY PASS" or "AUTOPLAY FAIL <step>"; CI fails without the PASS or on any FAIL line.
## Uses its own settings/save folder (XDG_DATA_HOME in the script), never the player's.
##
## When the game grows, extend `_run()`: drive the real game the way a player would, and add a
## PASS line for each thing that must keep working.

var shots := ""
var clip := ""                          # --clip=DIR: save a gameplay clip's frames there
const GameData = preload("res://scripts/game_data.gd")
const CLIP_SECS := 15.0                 # vertical 9:16 (the game is portrait), sized for Shorts/Reels/TikTok
var failed := false
var training_arena := false
var _start_ms := 0                      # when game code first runs (engine/driver start-up excluded)


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	if not "--autoplay" in OS.get_cmdline_user_args():
		queue_free()
		return
	training_arena = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
		if a.begins_with("--clip="):
			clip = a.trim_prefix("--clip=")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	get_tree().create_timer(420.0).timeout.connect(func(): _fail("timeout"))
	_run.call_deferred()


# ---------------------------------------------------------------- the run

func _run() -> void:
	await _wait_scene("Boot")
	# Disable the timer in this run so only the tap can dismiss the card.
	get_tree().current_scene.get_node("StudioSplash/DisplayTimer").stop()
	await _shot("studio_splash")
	await _click("Skip splash")
	_check(_find("Skip splash") == null, "STUDIO SPLASH PASS (Skip splash dismisses the publisher card)")
	await _wait_scene("Intro")
	var intro_ms := Time.get_ticks_msec()
	await _frames(10)
	_shot("intro")
	var skip_ms := Time.get_ticks_msec()
	await _click("SKIP")
	await _wait_scene("Title")
	# Game start -> intro on screen, plus SKIP -> title. Driver start-up (10 s of ALSA/llvmpipe on a CI
	# box, not a phone) and the bot's own frames and screenshot don't count.
	var boot_ms := (intro_ms - _start_ms) + (Time.get_ticks_msec() - skip_ms)
	_check(boot_ms < 10000, "BOOT PASS (title ready %.1f s after game start)" % (boot_ms / 1000.0))
	# Quality tier: picked on first launch and saved; LOW really lowers; then HIGH for the checks below.
	var Q = preload("res://scripts/quality.gd")
	var st: Node = get_node("/root/Settings")
	var picked: int = st.get_value("tier")
	Q.apply(get_tree(), 0)
	var low_ok: bool = st.get_value("low_graphics") and is_equal_approx(get_tree().root.scaling_3d_scale, 0.7)
	Q.apply(get_tree(), 2)
	var high_ok: bool = not st.get_value("low_graphics") and is_equal_approx(get_tree().root.scaling_3d_scale, 1.0)
	_check(picked >= 0 and Q.last_ms > 0.0 and low_ok and high_ok,
		"TIER PASS (first launch picked %s, test frame %.1f ms; LOW and HIGH apply)" % [Q.NAMES[maxi(picked, 0)], Q.last_ms])
	await _frames(10)
	_shot("title")
	_check(_find("CONTINUE") == null, "TITLE PASS (no save yet)")
	await _click("SETTINGS")
	await _click("CREDITS")
	_check(_has_label("Published by 3 Eyed Fox Studios"), "PUBLISHER CREDITS PASS")
	await _click("DONE")
	await _click("DONE")
	# Why (Hunter M0, Nov 21): BUILD_SPEC says the title shows "HUNTER" and the canvas is 720x1280.
	var vp_w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vp_h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	_check(_has_label("HUNTER") and vp_w == 720 and vp_h == 1280,
		"HUNTER PASS (title shows HUNTER, base canvas %dx%d)" % [vp_w, vp_h])
	await _click("NEW GAME")
	await _wait_scene("Game")
	var game := get_tree().current_scene
	var ld: Node = get_node("/root/Loader")
	_check(ld.loads >= 2 and not ld.busy(), "LOAD PASS (%d scenes loaded in the background, %d frames drawn meanwhile)" % [ld.loads, ld.frames_while_loading])

	# Play (Hunter M1): fight the dummy in the arena with real stick drags and pad gestures.
	var start_score: int = game.score
	var bat: Node = get_node("/root/Battery")
	var playing_full: bool = bat.state == "play" and Engine.max_fps == 60
	await _arena_checks(game)
	_check(game.score > start_score, "PLAY PASS (%d knockout, now round %d)" % [game.score, game.level])

	# Checkpoint: every knockout autosaves the round.
	var saved: Dictionary = get_node("/root/Save").read()
	var saved_level: int = int(saved.get("level", 0))
	_check(saved_level == game.level and saved_level >= 2, "AUTOSAVE PASS (round %d saved)" % saved_level)

	# Phone interruption: the app loses focus -> pause + save.
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	_check(game.paused and _find("RESUME") != null, "INTERRUPT PASS (paused on focus loss)")
	var bg_low: bool = bat.state == "background" and Engine.max_fps == 5
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(3)
	_check(playing_full and bg_low and bat.state == "saver" and Engine.max_fps == 30,
		"BATTERY PASS (play 60 fps, background 5 fps, paused 30 fps)")
	bat.idle_secs = INF                         # the bot plays without input events: don't treat it as idle
	_shot("pause")

	# Settings from the pause menu: bigger text, colorblind, left-handed.
	await _click("SETTINGS")
	await _frames(10)
	_shot("settings")
	await _click("TEXT SIZE")
	await _frames(5)
	await _click("COLORBLIND")
	await _click("LEFT-HANDED")
	await _frames(10)
	_shot("settings_changed")
	var s: Node = get_node("/root/Settings")
	_check(s.get_value("colorblind") and s.get_value("left_handed") and int(s.get_value("text_size")) == 2,
		"SETTINGS PASS (saved)")
	await _click("DONE")
	await _frames(5)

	# Quit to title, CONTINUE, back where we were.
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	await _frames(10)
	_shot("title_continue")
	await _click("CONTINUE")
	await _wait_scene("Game")
	game = get_tree().current_scene
	_check(game.level == saved_level, "RESUME PASS (continued at round %d)" % game.level)
	await _frames(10)
	_shot("game_lefthanded")

	# Android back = pause, back again = resume.
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(game.paused, "BACK PASS (back button pauses)")
	await _click("RESUME")
	await _frames(5)

	# Stand next to a fast, hard-hitting dummy (TUNE values) until the hero drops: GAME OVER.
	var ar: Node = game.arena
	ar.reset_dummy()
	ar.enemy_attack_every = 0.3
	ar.enemy_telegraph = 0.5
	ar.enemy_damage = 40.0
	_place(ar.hero, ar.dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	Engine.time_scale = 4.0
	var go_until := Time.get_ticks_msec() + 30000
	while not game.over and Time.get_ticks_msec() < go_until:
		if not ar.hero.dead:
			_place(ar.hero, ar.dummy.global_position + Vector3(0, 0.05, 1.0), PI)
		await _frames(5)
	Engine.time_scale = 1.0
	await _frames(10)
	_shot("gameover")
	_check(game.over and _find("TRY AGAIN") != null and not get_node("/root/Save").exists(),
		"GAMEOVER PASS (game over screen, save cleared)")
	await _click("TITLE")
	await _wait_scene("Title")
	await _frames(5)
	_check(_find("CONTINUE") == null, "FLOW PASS (back at title, no stale CONTINUE)")

	# Bug report sheet carries the build line.
	await _click("REPORT A BUG")
	await _frames(10)
	_shot("bug_report")
	var txt: String = preload("res://scripts/bug_report.gd").report_text("test", get_tree())
	_check("build:" in txt and "device:" in txt, "BUGREPORT PASS")
	await _click("CLOSE")

	# Debug menu (dev builds): 5 taps on the version number.
	for i in 5:
		await _click_node(get_tree().current_scene.find_child("Version", true, false))
	await _frames(10)
	_check(_find("GOD MODE") != null, "DEBUG PASS (dev menu opens)")
	_shot("debug_menu")

	# 3D character standard (docs/MOVEMENT_3D.md): full range of movement, every system proven.
	await _click("3D CHARACTER TEST")
	await _wait_scene("CharacterTest")
	await _frames(20)
	var coach_was: bool = get_tree().current_scene.has_node("UI/Root/Coach_move")
	await _movement_checks(get_tree().current_scene)
	await _standards_checks(get_tree().current_scene, coach_was)
	await _tune_checks(get_tree().current_scene)
	if clip != "":
		await _record_clip(get_tree().current_scene)
	await _pews_checks()

	if not failed:
		print("AUTOPLAY PASS")
	get_tree().quit(1 if failed else 0)


# ---------------------------------------------------------------- Hunter M2: The Pews vertical slice

func _pews_checks() -> void:
	training_arena = false
	await _click("BACK")
	await _wait_scene("Title")
	await _click("NEW GAME")
	await _wait_scene("Game")
	var game := get_tree().current_scene
	var arena = game.arena
	var in_pews: bool = arena.has_method("restore_state")
	_check(in_pews, "PEWS SCENE PASS (NEW GAME opens The Pews)")
	if not in_pews:
		return
	await _frames(25)
	arena.rig.cam.make_current()
	_check(arena.dummy.name == "Vesper" and arena.get_node_or_null("Pews/Altar") != null
		and arena._foes.size() == 2, "PEWS MAP PASS (church altar, Vesper, Zealot and Choir)")
	_place(arena.hero, Vector3(0, 0.05, -2.3), PI)
	arena.rig.snap()
	await _physics(3)
	_check(not arena._occult_halo.is_visible_in_tree(),
		"PEWS EXPLORATION ART PASS (Vesper's occult halo is off during exploration)")
	await _shot("pews_map")

	var stick_point: Vector2 = game.stick.get_global_rect().get_center()
	_mouse(stick_point, true)
	_mouse(stick_point + Vector2(24, 0), null)
	await _frames(3)
	_check(arena.hero.crouching, "PEWS SNEAK PASS (light stick input crouch-walks)")
	_mouse(stick_point + Vector2(24, 0), false)
	await _frames(3)
	_check(not arena.hero.crouching, "PEWS WALK PASS (releasing the stick stands up)")
	var tuning: Node = get_tree().get_first_node_in_group("tunable")
	for candidate in get_tree().get_nodes_in_group("tunable"):
		if candidate.get_parent() == arena and candidate.get("sermon_damage") != null:
			tuning = candidate
			break
	var sermon_damage: float = float(arena.rules.config.boss.moves.sermon.damage)
	tuning.set("sermon_damage", sermon_damage + 1.0)
	_check(arena.rules.config.boss.moves.sermon.damage == sermon_damage + 1.0,
		"PEWS TUNE PASS (changes to the sermon slider reach the active rules)")
	tuning.set("sermon_damage", sermon_damage)

	_place(arena.hero, arena.dummy.global_position + Vector3(0, 0.05, 3.7), PI)
	await _physics(3)
	# Real stalking (M2 review: this used to preset study to 99%). Sneak behind Vesper by wiggling a
	# light stick, first from 3.7 m (full study, too far to AMBUSH), then step in to 2.6 m.
	# Staging: the hero is put back on the 3.7 m spot between wiggles; the crouch and the study
	# come from the real stick input.
	var hide_at: Vector3 = arena.hero.position
	var stalk_by := Time.get_ticks_msec() + 12000
	var wiggle := 1.0
	_mouse(stick_point, true)
	while arena.rules.studied < 100.0 and Time.get_ticks_msec() < stalk_by:
		wiggle = -wiggle
		_mouse(stick_point + Vector2(22.0 * wiggle, 0), null)
		await _secs(0.22)
		_place(arena.hero, hide_at, PI)
	_mouse(stick_point, false)
	await _frames(3)
	var far: float = arena.rules.distance
	_check(arena.rules.studied == 100.0 and far > float(arena.rules.config.stalking.ambush_range) and _find("AMBUSH") == null,
		"PEWS AMBUSH RANGE PASS (study filled by sneaking; at %.1f m AMBUSH stays hidden)" % far)
	_place(arena.hero, arena.dummy.global_position + Vector3(0, 0.05, 2.6), PI)
	var near_by := Time.get_ticks_msec() + 2500
	while _find("AMBUSH") == null and Time.get_ticks_msec() < near_by:
		await get_tree().process_frame
	_check(arena.rules.studied == 100.0 and _find("AMBUSH") != null,
		"PEWS STALK PASS (study %.1f%% from real sneaking, context %s at %.1f m)" % [arena.rules.studied, arena.context_label(), arena.rules.distance])
	await _click("AMBUSH")
	_check(arena.encounter_started and arena._ambush_free_special,
		"PEWS AMBUSH PASS (Vesper staggered, first special free)")

	# Stage the normal camera close enough to read the altar and the encounter together.
	_place(arena.hero, Vector3(0, 0.05, -4.65), PI)
	arena.rig.snap()
	await _physics(3)
	await _shot("pews_combat")
	arena._boss_cd = 0.0
	await _frames(2)
	_check(arena._boss_move == "sermon" and arena._warn.visible and arena._occult_halo.is_visible_in_tree(),
		"PEWS OCCULT PASS (the sermon telegraph shows Vesper's halo and warning symbol)")
	await _shot("pews_occult")
	var budget: Dictionary = preload("res://scripts/character_test.gd").BUDGET
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var triangles := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_check(draws > 0 and draws <= budget.draw_calls and triangles > 0 and triangles <= budget.primitives,
		"PEWS RENDER BUDGET PASS (%d draw calls, %d triangles during the sermon)" % [draws, triangles])
	var sermon_by := Time.get_ticks_msec() + 4000
	while arena._boss_telegraph > 0.0 and Time.get_ticks_msec() < sermon_by:
		await get_tree().process_frame
	_check(arena._boss_telegraph <= 0.0 and not arena._occult_halo.is_visible_in_tree(),
		"PEWS OCCULT CLEAR PASS (Vesper's halo goes dark after the sermon)")
	await _shot("pews_after_sermon")

	# Keep the encounter deterministic while using stock damage and the real attack pad.
	var debug := get_node("/root/DebugMenu")
	debug.god_mode = true
	arena._boss_cd = 999.0
	await _fight_vesper_phase(game, 1)
	_check(arena.rules.boss_phase == 2 and not arena.boss_defeated,
		"PEWS PHASE PASS (pad attacks break phase one)")
	await _shot("pews_boss")
	await _fight_vesper_phase(game, 2)
	debug.god_mode = false
	_check(arena.boss_defeated and arena.rules.boss_defeated,
		"PEWS BOSS PASS (pad attacks defeat phase two)")
	_place(arena.hero, arena.get_node("CollectionPlate").position + Vector3.UP * 0.05, PI)
	arena.rig.snap()
	await _frames(3)
	await _click("COLLECT PLATE")
	_place(arena.hero, arena.get_node("stained_glass").position + Vector3.UP * 0.05, PI)
	arena.rig.snap()
	await _frames(3)
	await _click("SCAVENGE")
	_check(arena.rules.cash > 0 and arena.rules.heat > 0 and arena.rules.inventory.has("stained_glass"),
		"PEWS SCAVENGE PASS (field buttons collect the plate and realm loot)")
	await _frames(2)
	await _click("FINISH")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(_find("CLEAN") == null and not game.paused, "PEWS BACK PASS (Back dismisses the finisher sheet)")
	await _click("FINISH")
	await _click("CLEAN")
	_check(arena.rules.trophies.has("vesper") and arena.rules.corruption == 5,
		"PEWS FINISH PASS (CLEAN choice awards intact trophy and +5 corruption)")
	await _frames(2)
	await _click("EAT")
	_check(arena.rules.eaten and arena.portal_ready and _has_label("BROTHER VESPER LYLE"),
		"PEWS EAT PASS (EAT opens the voice sheet)")
	await _click("CLOSE")
	# CONTINUE mid-hunt keeps the boss, the loot and where the hero stood (M2 review: the door).
	var stood: Vector3 = arena.hero.position
	await _click("PAUSE")
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	await _click("CONTINUE")
	await _wait_scene("Game")
	game = get_tree().current_scene
	arena = game.arena
	_check(arena.rules.boss_phase == 2 and arena.rules.boss_defeated
		and arena.rules.eaten and arena.rules.inventory.has("stained_glass")
		and arena.hero.position.distance_to(stood) < 0.5,
		"PEWS CONTINUE PASS (boss, voice, loot and the hero's spot survive the checkpoint)")
	await _click("RETURN HOME")
	await _wait_scene("Game")
	await _lair_checks()
	await _pews_danger_checks()
	await _brutal_and_raid_checks()


## The parts of The Pews that hurt, with God mode OFF and Vesper's own timers doing the work.
## Why (Nov 23 fresh-eyes review of PR #20): the fight above runs in God mode with Vesper's
## cooldown parked, so a script error in Flock, Laying of Hands, the Choir buff, the "spotted" path
## or GAME OVER inside the church would still have printed AUTOPLAY PASS. Staging here only places
## actors and zeroes cooldowns; every hit goes through the real telegraph, range and damage code.
func _pews_danger_checks() -> void:
	await _click("PAUSE")
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	await _click("NEW GAME")
	await _wait_scene("Game")
	var game := get_tree().current_scene
	var arena = game.arena
	await _frames(25)
	arena.rig.cam.make_current()
	get_node("/root/DebugMenu").god_mode = false
	# M3: NEW GAME is a new hunt, not a new hunter. The profile and the HUD line come along.
	var prof: Dictionary = get_node("/root/Profile").data
	_check(not arena.rules.boss_defeated and int(prof.cash) >= 10 and prof.trophies.has("vesper")
		and prof.voices.has("vesper") and game.profile_label.text.begins_with("$%d" % int(prof.cash))
		and arena.max_hp == 100 + int(GameData.load_json("trophies").trophies.vesper.defence.max_hp),
		"PROFILE PASS (NEW GAME keeps $%d, the trophy, the voice and the perk; HUD: %s)" % [int(prof.cash), game.profile_label.text])
	var cfg: Dictionary = arena.rules.config
	var zealot: Dictionary
	var choir: Dictionary
	for foe in arena._foes:
		if foe.kind == "Zealot":
			zealot = foe
		else:
			choir = foe
	# Park the minions out of chase range so each boss power is measured alone.
	_place(zealot.actor, Vector3(-2.0, 0.05, 40.0), 0.0)
	_place(choir.actor, Vector3(2.0, 0.05, 40.0), 0.0)
	var boss_at: Vector3 = arena.dummy.global_position

	# Walk into Vesper's view cone (he faces the altar): no ambush, the fight starts on his terms.
	_place(arena.hero, boss_at + Vector3(0, 0.05, -1.9), 0.0)
	var by := Time.get_ticks_msec() + 2000
	while not arena.encounter_started and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	_check(arena.spotted and arena.encounter_started and not arena.rules.ambush_started
		and not arena._ambush_free_special, "PEWS SPOTTED PASS (walking into Vesper's view starts the fight with no ambush bonus)")

	# Sermon: stand inside its radius and take the hit.
	_place(arena.hero, boss_at + Vector3(0, 0.05, 2.0), PI)
	var hp0: int = arena.hp
	arena._boss_cd = 0.0
	by = Time.get_ticks_msec() + 4000
	while arena.hp == hp0 and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	_check(hp0 - arena.hp == int(cfg.boss.moves.sermon.damage),
		"PEWS SERMON PASS (the sermon cost %d HP inside its radius)" % (hp0 - arena.hp))

	# Flock: the shadows appear and a tick lands on a hero who stays close.
	# The sermon's knockback is still carrying the hero: let it finish, then step back in, and
	# again as the shadows appear (a player who holds their ground).
	await _physics(60)
	boss_at = arena.dummy.global_position       # Vesper walks between powers now (M2 review)
	_place(arena.hero, boss_at + Vector3(0, 0.05, 1.6), PI)
	hp0 = arena.hp
	arena._boss_cd = 0.0
	var saw_shadows := false
	by = Time.get_ticks_msec() + 5000
	while arena.flock_ticks == 0 and Time.get_ticks_msec() < by:
		if not saw_shadows and arena._flock_node != null and arena._flock_node.get_child_count() == 3:
			saw_shadows = true
			_place(arena.hero, arena._flock_node.global_position + Vector3(0, 0.05, 1.6), PI)
		await get_tree().physics_frame
	_check(saw_shadows and arena.flock_ticks >= 1 and hp0 - arena.hp == int(cfg.boss.moves.flock.damage),
		"PEWS FLOCK PASS (three shadows, a tick cost %d HP)" % (hp0 - arena.hp))
	_place(arena.hero, boss_at + Vector3(0, 0.05, 9.0), PI)     # out of the Flock before the next check

	# Laying of Hands: wound Vesper, then his own heal tops him back up, HUD value in sync.
	arena.rules.boss_hp -= 30.0
	arena.dummy_hp = arena.rules.boss_hp
	var boss0: float = arena.rules.boss_hp
	arena._boss_cd = 0.0
	by = Time.get_ticks_msec() + 4000
	while arena.hands_healed == 0.0 and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	_check(arena.hands_healed == float(cfg.boss.moves.laying_of_hands.heal)
		and arena.rules.boss_hp == boss0 + arena.hands_healed and arena.dummy_hp == arena.rules.boss_hp,
		"PEWS HANDS PASS (Vesper healed %d, to %d HP)" % [int(arena.hands_healed), int(arena.rules.boss_hp)])
	arena._boss_cd = 999.0

	# A Zealot with the Choir in buff range (but out of its own chase range) hits harder.
	by = Time.get_ticks_msec() + 5000
	while arena._flock_time > 0.0 and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	var spot := Vector3(0, 0.05, 2.0)
	_place(arena.hero, spot, 0.0)
	_place(zealot.actor, spot + Vector3(0, 0, 1.5), PI)
	_place(choir.actor, spot + Vector3(5.2, 0, 1.5), PI)
	zealot.attack_cd = 0.0
	hp0 = arena.hp
	arena.last_minion_hit = 0
	by = Time.get_ticks_msec() + 4000
	while arena.last_minion_hit == 0 and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	var boosted := int(cfg.minions.zealot_damage) + int(cfg.minions.choir_bonus_damage)
	_check(arena.last_minion_hit == boosted and hp0 - arena.hp == boosted,
		"PEWS CHOIR BUFF PASS (Zealot hit for %d with the Choir singing)" % arena.last_minion_hit)

	# Dying in the church: GAME OVER, and the run's save is gone.
	arena.hp = 1
	by = Time.get_ticks_msec() + 12000
	while not game.over and Time.get_ticks_msec() < by:
		if not arena.hero.dead:
			_place(arena.hero, zealot.actor.global_position + Vector3(0, 0, -1.5), 0.0)
			if zealot.windup <= 0.0:
				zealot.attack_cd = minf(zealot.attack_cd, 0.0)
		await _frames(5)
	await _frames(10)
	await _shot("pews_gameover")
	_check(game.over and _find("TRY AGAIN") != null and not get_node("/root/Save").exists(),
		"PEWS GAMEOVER PASS (the minions can kill; game over screen, save cleared)")
	await _click("TITLE")
	await _wait_scene("Title")


# ---------------------------------------------------------------- Hunter M3: the lair

## Stand the hero by a lair station (on the aisle side of it) and let the context button find it.
func _at_station(arena: Node, id: String) -> void:
	var at: Vector3 = GameData.vec3(arena.cfg.layout.stations[id])
	var off := Vector3(0, 0, 1.1) if id == "map_room" else Vector3(-signf(at.x) * 1.1, 0, 0)
	_place(arena.hero, at + off + Vector3(0, 0.05, 0), PI)
	arena.rig.snap()
	await _physics(3)
	await _frames(3)


func _lair_checks() -> void:
	var game := get_tree().current_scene
	var arena = game.arena
	var prof: Dictionary = get_node("/root/Profile").data
	await _frames(20)
	arena.rig.cam.make_current()
	_check(game.where == "lair" and arena.name == "LairArena" and int(prof.nights) == 1 and int(prof.hunts) == 1,
		"LAIR PASS (RETURN HOME opens the lair; a night passed, heat now %d)" % int(prof.heat))
	_check(game.last_voice_kind == "lair" and game.get_node_or_null("VoiceBox") != null,
		"VOICE LINE PASS (Vesper speaks in the dialogue box on a lair visit)")
	await _shot("lair_voice_box")
	await _click_node(game.get_node("VoiceBox"))
	await _frames(3)
	_check(game.get_node_or_null("VoiceBox") == null, "VOICE BOX TAP PASS (a tap dismisses the line)")
	_check(arena.band == 0 and not arena.horns.visible, "CORRUPTION HOME PASS (corruption %d: look 1 of 3, no horns)" % int(prof.corruption))
	# The whole room from above for the contact sheet.
	arena.rig.distance = 17.0
	_place(arena.hero, Vector3(0, 0.05, -1.5), PI)
	arena.rig.snap()
	await _physics(3)
	await _shot("lair_overview")
	arena.rig.distance = 7.5

	# Trophy wall: CLEAN hung Vesper's collar on the first (offence) slot. Move it to defence.
	await _at_station(arena, "trophy_wall")
	await _shot("lair_trophy_wall")
	await _click("TROPHY WALL")
	_check(prof.wall[0] == "vesper" and _find("OFFENCE\nVESPER") != null, "LAIR WALL PASS (the CLEAN trophy hangs on the wall)")
	await _click_node(get_tree().root.find_child("Slot2", true, false))
	await _click("VESPER'S COLLAR")
	await _secs(0.7)
	_check(prof.wall[2] == "vesper" and prof.wall[0] == "" and arena.max_hp == 115,
		"LAIR TROPHY PASS (moved to the defence row for free: max HP %d, wall %s)" % [arena.max_hp, prof.wall])
	await _click("CLOSE")

	# Workshop: the stained glass and the parts make a trap.
	await _at_station(arena, "workshop")
	await _click("WORKSHOP")
	await _shot("lair_workshop")
	var parts0 := int(prof.parts)
	await _click("CRAFT GLASS SPIKE TRAP")
	_check(int(prof.inventory.get("glass_trap", 0)) == 1 and int(prof.parts) == parts0 - 4 and not prof.inventory.has("stained_glass"),
		"LAIR CRAFT PASS (glass trap crafted: parts %d -> %d)" % [parts0, int(prof.parts)])
	await _click("CLOSE")

	# Set it on the first spot by the door.
	_place(arena.hero, GameData.vec3(arena.cfg.layout.trap_spots[0]) + Vector3(0, 0.05, 0.3), PI)
	await _physics(3)
	await _frames(3)
	await _click("SET TRAP")
	await _frames(3)
	_check(prof.traps[0] == "glass_trap" and not prof.inventory.has("glass_trap") and arena._trap_nodes[0].has_node("Spikes"),
		"LAIR TRAP SET PASS (glass spikes set by the door)")

	# Voices: Vesper took slot 1 (the UP swipe) when he was eaten. Move him to DOWN and back.
	await _at_station(arena, "voices")
	await _click("VOICES")
	await _secs(0.6)
	_check(arena.moves.specials.up.name == "SERMON", "LAIR VOICE EQUIP PASS (Vesper's SERMON is on the UP swipe)")
	await _click("SLOT 2")
	await _click("VESPER")
	await _secs(0.7)
	var moved: bool = arena.moves.specials.down.name == "SERMON" and arena.moves.specials.up.name != "SERMON"
	await _click("SLOT 1")
	await _click("VESPER")
	await _secs(0.7)
	_check(moved and arena.moves.specials.up.name == "SERMON", "LAIR VOICE SWAP PASS (slot 2 takes DOWN; back to UP)")
	await _shot("lair_voices")
	await _click("CLOSE")

	await _at_station(arena, "cold_room")
	await _click("COLD ROOM")
	_check(_has_label("CASH %d   PARTS %d   HEAT %d   CORRUPTION %d" % [int(prof.cash), int(prof.parts), int(prof.heat), int(prof.corruption)]),
		"LAIR COLD ROOM PASS (stores show the profile)")
	await _click("CLOSE")

	await _at_station(arena, "map_room")
	await _shot("lair_map_room")
	await _click("MAP ROOM")
	_check(_find("HUNT THE PEWS") != null and _find("LOCKED: THE CASINO") == null and _has_any_disabled("LOCKED: THE CASINO"),
		"LAIR MAP PASS (The Pews is open, the other realms are locked)")
	await _shot("lair_map_sheet")
	await _click("CLOSE")

	# Quit and CONTINUE: back in the lair with the trophy, the trap and the voice where they were.
	await _click("PAUSE")
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	_check(_find("CONTINUE  (THE LAIR)") != null, "LAIR SAVE PASS (title offers CONTINUE (THE LAIR))")
	await _click("CONTINUE")
	await _wait_scene("Game")
	game = get_tree().current_scene
	arena = game.arena
	prof = get_node("/root/Profile").data
	await _frames(10)
	_check(game.where == "lair" and prof.wall[2] == "vesper" and prof.traps[0] == "glass_trap"
		and arena._trap_nodes[0].has_node("Spikes") and int(prof.nights) == 1,
		"LAIR CONTINUE PASS (trophy, trap and voice kept; no extra night on CONTINUE) %s %s %s %s %d" % [game.where, prof.wall, prof.traps, arena._trap_nodes[0].get_children().map(func(c): return c.name), int(prof.nights)])
	# Map room -> a fresh hunt, the profile intact.
	await _at_station(arena, "map_room")
	await _click("MAP ROOM")
	await _click("HUNT THE PEWS")
	await _wait_scene("Game")
	game = get_tree().current_scene
	_check(game.where == "pews" and not game.arena.rules.boss_defeated and game.arena.max_hp == 115,
		"LAIR HUNT PASS (the map room opens a fresh Pews hunt, perks on)")


## True when a visible button starting with `prefix` exists but is disabled (locked realms).
func _has_any_disabled(prefix: String) -> bool:
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.disabled and b.text.begins_with(prefix):
			return true
	return false


## BRUTAL (M2 review: rule tests only), then heat over the line brings a LAIR RAID. God mode OFF:
## the raiders hit for real, the trap fires on its own, the hero clears both waves with pad taps.
func _brutal_and_raid_checks() -> void:
	await _click("NEW GAME")
	await _wait_scene("Game")
	var game := get_tree().current_scene
	var arena = game.arena
	var prof: Dictionary = get_node("/root/Profile").data
	await _frames(25)
	arena.rig.cam.make_current()
	get_node("/root/DebugMenu").god_mode = false
	for foe in arena._foes:
		_place(foe.actor, Vector3(foe.actor.position.x, 0.05, 40.0), 0.0)
	# Staging: Vesper on his last legs in phase 2, his powers parked; heat 64 so the plate (+8)
	# crosses the raid line. The kill, the plate and both choices are real taps.
	prof.heat = 64
	arena.rules.boss_phase = 2
	arena.rules.boss_hp = 6.0
	arena.dummy_hp = 6.0
	arena._boss_cd = 999.0
	_place(arena.hero, arena.dummy.global_position + Vector3(0, 0.05, -1.4), 0.0)
	var by := Time.get_ticks_msec() + 3000
	while not arena.encounter_started and Time.get_ticks_msec() < by:
		await get_tree().physics_frame
	await _fight_vesper_phase(game, 2)
	var corr0 := int(prof.corruption)
	_place(arena.hero, arena.get_node("CollectionPlate").position + Vector3.UP * 0.05, PI)
	await _frames(3)
	await _click("COLLECT PLATE")
	_place(arena.hero, arena.get_node("candle").position + Vector3.UP * 0.05, PI)
	await _frames(3)
	await _click("SCAVENGE")
	await _frames(2)
	await _click("FINISH")
	await _click("BRUTAL")
	_check(arena.boss_defeated and int(prof.voice_levels.get("vesper", 0)) == 1 and int(prof.corruption) == corr0 + 15
		and not arena.rules.trophies.has("vesper"),
		"PEWS BRUTAL PASS (no trophy, Vesper's voice +1 level, corruption +15)")
	await _frames(2)
	await _click("EAT")
	await _click("CLOSE")
	_check(int(prof.heat) >= int(GameData.load_json("lair").heat.raid_at), "HEAT PASS (the plate pushed heat to %d)" % int(prof.heat))
	await _click("RETURN HOME")
	await _wait_scene("Game")
	game = get_tree().current_scene
	arena = game.arena
	prof = get_node("/root/Profile").data
	await _frames(10)
	arena.rig.cam.make_current()
	_check(bool(prof.raid_pending) and _find("FIGHT") != null, "LAIR RAID WARNING PASS (heat %d brought a raid home)" % int(prof.heat))
	_check(arena.band == 1 and arena.horns.visible and arena.hero.tint != Color.WHITE,
		"CORRUPTION PASS (corruption %d: the lair turns STAINED, the hero tints and grows horns)" % int(prof.corruption))
	var heat0 := int(prof.heat)
	await _click("FIGHT")
	await _frames(5)
	await _shot("lair_raid")
	var point := _pad_point(game)
	by = Time.get_ticks_msec() + 60000
	while arena.raid_active and not game.over and Time.get_ticks_msec() < by:
		var target: Node = arena._attack_target()
		if target == null:
			# Nobody in reach: walk to the nearest raider with the bot stick.
			var near: Node3D = null
			for foe in arena._foes:
				if not foe.dead and (near == null or arena.hero.global_position.distance_to(foe.actor.global_position) < arena.hero.global_position.distance_to(near.global_position)):
					near = foe.actor
			if near != null and arena.hero.global_position.distance_to(near.global_position) > 1.3:
				var to: Vector3 = near.global_position - arena.hero.global_position
				arena.bot_stick = Vector2(to.x, to.z).normalized()
			else:
				arena.bot_stick = Vector2.INF
			await _physics(3)
			continue
		arena.bot_stick = Vector2.INF
		_mouse(point, true)
		_mouse(point, false)
		await _secs(0.35)
	arena.bot_stick = Vector2.INF
	await _frames(5)
	_check(not arena.raid_active and int(prof.raids_won) == 1 and arena.traps_fired >= 1 and prof.traps[0] == ""
		and int(prof.heat) < heat0 and _find("CLOSE") != null and arena.hero_hits_taken > 0,
		"LAIR RAID PASS (%d waves cleared, %d trap fired, heat %d -> %d)" % [arena.raid_wave, arena.traps_fired, heat0, int(prof.heat)])
	await _shot("lair_raid_won")
	await _click("CLOSE")
	# HEAL: the candle from this hunt becomes a poultice; the raid's real damage gets healed.
	await _at_station(arena, "workshop")
	await _click("WORKSHOP")
	await _click("CRAFT WAX POULTICE")
	await _click("CLOSE")
	var hp_hurt: int = arena.hp
	await _frames(3)
	await _click("HEAL")
	_check(hp_hurt < arena.max_hp and arena.hp > hp_hurt and not prof.inventory.has("wax_poultice"),
		"HEAL PASS (crafted poultice: HP %d -> %d)" % [hp_hurt, arena.hp])
	# Another raid (staged arrival: heat over the line). Back on the warning can't dodge it, and the
	# map room is shut until it's fought. Then the hero falls: parts lost, no GAME OVER.
	prof.heat = 80
	prof.raid_pending = true
	await _at_station(arena, "map_room")
	await _click("MAP ROOM")
	_check(_has_any_disabled("HUNT THE PEWS"), "RAID LOCK PASS (no hunting while a raid is coming)")
	await _click("CLOSE")
	game._raid_warning()
	await _frames(3)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(arena.raid_active and _find("FIGHT") == null, "RAID BACK PASS (Back on the warning starts the raid, it can't dodge it)")
	var parts0 := int(prof.parts)
	var lost0 := int(prof.raids_lost)
	arena.hp = 1
	by = Time.get_ticks_msec() + 20000
	while int(prof.raids_lost) == lost0 and Time.get_ticks_msec() < by:
		var near: Node3D = null
		for foe in arena._foes:
			if not foe.dead:
				near = foe.actor
		if near != null and not arena.hero.dead:
			_place(arena.hero, near.global_position + Vector3(0, 0.05, -1.4), 0.0)
		await _frames(5)
	await _frames(10)
	_check(int(prof.raids_lost) == lost0 + 1 and int(prof.parts) < parts0 and not game.over
		and get_node("/root/Save").exists() and not arena.hero.dead and _find("CLOSE") != null,
		"LAIR RAID LOST PASS (the hero fell: parts %d -> %d, no GAME OVER, save kept)" % [parts0, int(prof.parts)])
	await _click("CLOSE")
	await _shot("lair_stained")
	# The third look, staged for the render only.
	prof.corruption = 80
	arena.refresh()
	arena.apply_corruption(80)
	await _frames(5)
	arena.rig.distance = 17.0
	_place(arena.hero, Vector3(0, 0.05, -1.5), PI)
	arena.rig.snap()
	await _physics(3)
	await _shot("lair_hellmouth")
	_check(arena.band == 2 and arena.get_node_or_null("Vein13") != null,
		"CORRUPTION LOOKS PASS (all three lair looks build: HOME, STAINED, HELLMOUTH)")
	arena.rig.distance = 7.5
	await _click("PAUSE")
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")


func _fight_vesper_phase(game: Node, phase: int) -> void:
	var arena: Node = game.arena
	var point := _pad_point(game)
	for attempt in 14:
		if arena.rules.boss_phase != phase or arena.boss_defeated:
			return
		var ready_by := Time.get_ticks_msec() + 2500
		while (not arena._free() or arena.dummy.is_acting("knockback")) and Time.get_ticks_msec() < ready_by:
			await get_tree().process_frame
		await _face_dummy(arena)
		var before: float = arena.dummy_hp
		_mouse(point, true)
		await _secs(0.45)
		_mouse(point, false)
		var hit_by := Time.get_ticks_msec() + 1200
		while arena.dummy_hp == before and Time.get_ticks_msec() < hit_by:
			await get_tree().process_frame


# ---------------------------------------------------------------- 3D movement checks

var _bones := {}


func _snap_bones(sk: Skeleton3D) -> void:
	if not is_instance_valid(sk) or not sk.is_inside_tree():
		return
	var d := {}
	for b in ["foot_l", "foot_r", "pelvis", "Head"]:
		d[b] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
	d["head_fwd"] = (sk.global_transform.basis * sk.get_bone_global_pose(sk.find_bone("Head")).basis.z).normalized()
	_bones[sk.get_instance_id()] = d


## Bone positions as drawn (after animation, IK and ragdoll), not before the modifiers ran.
func _bone(c: Node, b: String) -> Variant:
	var sk: Skeleton3D = c.skeleton
	if not sk.skeleton_updated.is_connected(_snap_bones.bind(sk)):
		sk.skeleton_updated.connect(_snap_bones.bind(sk))
		await _frames(2)
	await _frames(1)
	return _bones[sk.get_instance_id()][b]


func _place(c: Node, p: Vector3, h: float) -> void:
	c.global_position = p
	c.velocity = Vector3.ZERO
	c.heading = h
	c.model.rotation.y = h
	var sc := get_tree().current_scene
	if sc.has_method("snap_camera") and c == sc.get("hero"):
		sc.snap_camera()                       # cut, don't pan, after a teleport


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ground_gap(c: Node, foot: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(foot + Vector3.UP, foot + Vector3.DOWN * 2.0, 2)
	var r: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
	return foot.y - float(r.position.y) if not r.is_empty() else 99.0


func _movement_checks(ct: Node) -> void:
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	# 360 degrees of movement with real limb animation.
	var top_speed := 0.0
	var foot_travel := 0.0
	var last_foot: Vector3 = await _bone(hero, "foot_l")
	var ang := 0.0
	while ang < TAU * 1.15:
		ct.bot_stick = Vector2(cos(ang), sin(ang))
		await _frames(1)
		ang += 0.06
		top_speed = maxf(top_speed, hero.speed())
		var f: Vector3 = _bones[hero.skeleton.get_instance_id()]["foot_l"] - hero.global_position
		foot_travel += f.distance_to(last_foot)
		last_foot = f
		if absf(ang - PI) < 0.03:
			_shot("char_run")
	ct.bot_stick = Vector2.ZERO
	_check(hero.turned > 5.6 and top_speed > 4.0,
		"MOVE360 PASS (turned %.1f rad, top speed %.1f m/s)" % [hero.turned, top_speed])
	_check(foot_travel > 2.0, "LIMBS PASS (left foot travelled %.1f m against the hips: real animation)" % foot_travel)
	# The drawn body follows the skeleton (a stale import can leave a T-pose mesh over a live rig).
	var bound := 0
	var skinned := 0
	for c in [ct.hero, ct.dummy]:
		for m in c.model.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).skin != null:
				skinned += 1
				if m.get_node_or_null(m.skeleton) == c.skeleton:
					bound += 1
	_check(skinned > 0 and bound == skinned, "SKIN PASS (%d of %d body meshes follow their skeleton)" % [bound, skinned])
	# Feet planted on a slope and on stairs (foot IK): both ankles at ankle height over the ground.
	for spot in [["SLOPE", Vector3(5, 1.5, -3), PI], ["STAIRS", Vector3(-3.5, 1.2, 3), -PI / 2]]:
		_place(hero, spot[1], spot[2])
		await _physics(50)
		var gl := _ground_gap(hero, await _bone(hero, "foot_l"))
		var gr := _ground_gap(hero, _bones[hero.skeleton.get_instance_id()]["foot_r"])
		_check(absf(gl - gr) < 0.04 and gl < 0.16 and gr < 0.16,
			"FOOTIK %s PASS (feet %.2f / %.2f m over the ground)" % [spot[0], gl, gr])
		if spot[0] == "STAIRS":
			_shot("char_stairs")
	# Jump: take-off, fall, land.
	_place(hero, Vector3(0, 0.05, 0), 0.0)
	await _physics(10)
	hero.jump()
	var peak := 0.0
	var phases := {}
	for i in 90:
		await _physics(1)
		peak = maxf(peak, hero.global_position.y)
		phases[hero.air_phase] = true
		if i == 20:
			_shot("char_jump")
	_check(peak > 0.6 and phases.has("start") and phases.has("fall") and phases.has("land") and hero.mode == "ground",
		"JUMP PASS (peak %.2f m, start/fall/land)" % peak)
	# Crouch walk.
	ct.toggle_crouch()
	ct.bot_stick = Vector2(1, 0)
	await _physics(30)
	_check(hero.mode == "crouch" and hero.speed() < 2.0 and hero._cap.height < 1.3, "CROUCH PASS (speed %.1f)" % hero.speed())
	_shot("char_crouch")
	ct.bot_stick = Vector2.ZERO
	ct.toggle_crouch()
	# Aim: turn in place, strafe (chest on target, legs sideways), backpedal, head looks at it.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	await _physics(5)
	var turned0: float = hero.turned
	await _click("AIM")
	await _physics(60)
	var start_pos: Vector3 = hero.global_position
	var to_d: Vector3 = (dummy.global_position - hero.global_position).normalized()
	_check(hero.turned - turned0 > 1.0 and start_pos.distance_to(Vector3(0, 0, 2)) < 0.2, "TURN PASS (turned on the spot)")
	var head_fwd: Vector3 = await _bone(hero, "head_fwd")
	_check(Vector2(head_fwd.x, head_fwd.z).normalized().dot(Vector2(to_d.x, to_d.z)) > 0.85, "LOOKAT PASS (head on target)")
	ct.bot_stick = Vector2(1, 0)
	await _physics(25)
	_check(absf(hero.twist.yaw) > 0.5 and hero.speed() > 3.0, "STRAFE PASS (chest twisted %.0f deg)" % rad_to_deg(hero.twist.yaw))
	_shot("char_strafe")
	_place(hero, Vector3(0, 0.05, 1), PI)
	ct.bot_stick = Vector2(0, 1)
	await _physics(25)
	_check(hero.backpedal and hero.speed() > 3.0, "BACKPEDAL PASS")
	ct.bot_stick = Vector2.ZERO
	await _click("AIM")
	# Punch combo: jab, cross, hook (a real tap, then the same function the button calls); the hook
	# knocks the dummy back (root motion).
	_place(hero, dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	await _physics(5)
	await _click("PUNCH")
	await _physics(4)
	_check(hero.is_acting("punch") and dummy.is_acting("hit_chest"), "ACTION PASS (punch lands, dummy flinches)")
	_shot("char_punch")
	await _physics(20)
	ct.punch()
	await _physics(25)
	var d0: Vector3 = dummy.global_position
	_place(hero, dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	ct.punch()
	await _physics(60)
	_check(ct.combo == 3 and dummy.global_position.distance_to(d0) > 0.6, "KNOCKBACK PASS (combo hook threw the dummy %.1f m)" % dummy.global_position.distance_to(d0))
	await _click("DODGE")
	await _physics(4)
	_check(hero.is_acting("dodge"), "DODGE PASS")
	await _physics(60)
	# Climb a 1 m ledge, vault a 0.8 m wall, swim, climb out of the water.
	_place(hero, Vector3(0, 0.05, -6.4), PI)
	await _physics(10)
	await _click("JUMP")
	await _physics(12)
	_shot("char_climb")
	await _physics(60)
	_check(hero.global_position.y > 0.9 and hero.mode == "ground", "CLIMB PASS (on the ledge at %.2f m)" % hero.global_position.y)
	_place(hero, Vector3(9.25, 0.05, 0.9), 0.0)
	await _physics(10)
	await _click("JUMP")
	await _physics(80)
	_check(hero.global_position.z > 2.0 and hero.global_position.y < 0.2, "VAULT PASS (over the wall)")
	_place(hero, Vector3(-6.5, 0.5, -7.5), 0.0)
	await _physics(90)
	_check(hero.mode == "swim", "SWIM PASS")
	_shot("char_swim")
	_place(hero, Vector3(-6.5, -1.6, -5.8), 0.0)
	await _physics(5)
	await _click("JUMP")
	await _physics(90)
	_check(hero.mode == "ground" and hero.global_position.y > -0.1, "SWIMOUT PASS (climbed out of the pool)")
	# Ragdoll death: the body falls under physics, the pelvis ends near the floor.
	ct.reset_dummy()
	_place(hero, Vector3(2, 0.05, 0), 0.0)
	await _physics(10)
	dummy.die(Vector3(0, 3, -8))
	await _physics(150)
	var pel: Vector3 = await _bone(dummy, "pelvis")
	_check(dummy.is_ragdoll() and pel.y < 0.4, "RAGDOLL PASS (pelvis down to %.2f m)" % pel.y)
	_shot("char_ragdoll")
	var inked := true
	for m in hero.model.find_children("*", "MeshInstance3D", true, false):
		for i in (m as MeshInstance3D).mesh.get_surface_count():
			var mat := (m as MeshInstance3D).get_surface_override_material(i) as ShaderMaterial
			inked = inked and mat != null and mat.next_pass != null
	_check(inked, "INK PASS (toon + outline on every surface)")


# ---------------------------------------------------------------- Hunter M1 arena checks
# Why (Hunter M1, Nov 21): BUILD_SPEC M1 "Autoplay: move, light string, special, weapon break",
# plus one PASS line per M1 feature. Real input events on the stick and the pad; real-time waits.

func _secs(t: float) -> void:
	var until := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _mouse(p: Vector2, down: Variant) -> void:
	var w := get_viewport().get_final_transform() * p
	var e: InputEvent
	if down == null:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		e = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		e = b
	e.position = w
	e.global_position = w
	Input.parse_input_event(e)


func _pad_point(game: Node) -> Vector2:
	return game.pad.get_global_rect().get_center()


## Hero 1 m in front of the dummy, facing it; camera cut.
func _face_dummy(a: Node) -> void:
	_place(a.hero, a.dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	a.rig.snap()
	await _physics(3)


## One pad tap; waits up to `t` s for it to land. True if a new hit landed.
func _pad_tap(game: Node, t := 2.0) -> bool:
	var a: Node = game.arena
	var before: int = a.hits_landed
	var p := _pad_point(game)
	# A tap is short even when a software-rendered frame takes longer than a hold.
	_mouse(p, true)
	_mouse(p, false)
	var until := Time.get_ticks_msec() + int(t * 1000.0)
	while a.hits_landed == before and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return a.hits_landed > before


func _arena_checks(game: Node) -> void:
	var a: Node = game.arena
	var hero: Node = a.hero
	var dummy: Node = a.dummy
	var feel: Node = get_node("/root/Feel")
	a.enemy_attack_every = 999.0             # the dummy holds still until the ENEMY check
	a._enemy_t = 999.0
	await _frames(10)
	# Camera: fixed high three-quarter, about 50 degrees down.
	var look: Vector3 = -a.rig.cam.global_transform.basis.z
	var pitch := rad_to_deg(asin(-look.y))
	_check(absf(pitch - 50.0) < 3.0, "ARENA CAMERA PASS (looking %.0f degrees down)" % pitch)
	_shot("arena")
	# Move: drag the virtual stick in a full circle; the hero runs and turns all the way round.
	var turned0: float = hero.turned
	var p0: Vector3 = hero.global_position
	var top := 0.0
	var c: Vector2 = game.stick.get_global_rect().get_center()
	_mouse(c, true)
	await _frames(2)
	for i in 48:
		var ang := TAU * i / 32.0
		_mouse(c + Vector2(cos(ang), sin(ang)) * 90.0, null)
		await _secs(0.05)
		top = maxf(top, hero.speed())
	_mouse(c, false)
	await _secs(0.3)
	var moved: float = hero.global_position.distance_to(p0)
	_check(top > 3.0 and hero.turned - turned0 > TAU and moved > 0.5,
		"STICK PASS (top speed %.1f m/s, turned %.1f rad, any direction)" % [top, hero.turned - turned0])
	# Light string: three taps in rhythm; the third (hook) knocks back. Hit-stop, shake, counter.
	await _face_dummy(a)
	var shakes0: int = feel.shakes
	var hero_stops0: int = hero.stops
	var dummy_stops0: int = dummy.stops
	var landed: Array[String] = []
	var trauma := 0.0
	var before_hook: Vector3 = dummy.global_position
	for i in 3:
		if i == 2:
			before_hook = dummy.global_position
		if await _pad_tap(game):
			landed.append(str(a._move.get("id", "")))
			trauma = maxf(trauma, a.rig.trauma)
		if i < 2:
			# Wait for recovery in game time. Render stalls can make a wall-clock delay
			# expire the string and land three jabs, each of which still counts as a hit.
			var recover_by := Time.get_ticks_msec() + 2000
			while not a._free() and Time.get_ticks_msec() < recover_by:
				await get_tree().process_frame
	var hook: Dictionary = a.last_hit
	await _frames(2)
	_shot("arena_combo")
	var combo_seen := _has_label("3 HITS")
	var settle_by := Time.get_ticks_msec() + 2500
	while (dummy.time_scale < 1.0 or dummy.is_acting("knockback")) and Time.get_ticks_msec() < settle_by:
		await get_tree().process_frame
	var knockback: float = dummy.global_position.distance_to(before_hook)
	_check(landed == ["jab", "cross", "hook"] and float(hook.get("power", 0)) >= 0.5 and knockback > 0.3,
		"LIGHT STRING PASS (%s, the third knocked the dummy %.1f m)" % [", ".join(landed), knockback])
	_check(combo_seen, "COMBO PASS (counter showed 3 HITS)")
	# Counted, not sampled: on a slow CI box 60 ms is shorter than a frame (Nov 21: it flaked).
	var want: float = 0.06 * feel.stop_scale
	_check(hero.stops - hero_stops0 >= 3 and dummy.stops - dummy_stops0 >= 3
		and is_equal_approx(hero.last_stop, want) and is_equal_approx(dummy.last_stop, want),
		"HITSTOP PASS (attacker and victim froze %d / %d times, %.0f ms each)" % [hero.stops - hero_stops0, dummy.stops - dummy_stops0, want * 1000.0])
	_check(feel.shakes > shakes0 and trauma > 0.0, "SHAKE PASS (camera trauma %.2f per hit)" % trauma)
	# Heavy: hold 0.3 s, release.
	await _face_dummy(a)
	var hp0: float = a.dummy_hp
	var pp := _pad_point(game)
	_mouse(pp, true)
	await _secs(0.45)
	_mouse(pp, false)
	await _secs(0.6)
	_check(a.last_hit.get("kind", "") == "heavy" and is_equal_approx(hp0 - a.dummy_hp, 20.0),
		"HEAVY PASS (hold and release: %.0f damage)" % (hp0 - a.dummy_hp))
	# Special: a light, then a swipe toward the dummy inside the cancel window.
	# Let the heavy's knockback clip finish first: it slides the dummy, and with contact at hit_at
	# (not the first frame) a drifting dummy walks out of jab reach (Nov 21 review fixes).
	a.reset_dummy()
	await _secs(1.0)
	await _face_dummy(a)
	await _secs(0.1)
	var hit_ok := await _pad_tap(game)
	var to: Vector2 = a.rig.cam.unproject_position(dummy.global_position) - a.rig.cam.unproject_position(hero.global_position)
	var sw := pp + to.normalized() * 120.0
	_mouse(pp, true)
	_mouse(sw, null)
	_mouse(sw, false)
	await _secs(0.7)
	_shot("arena_special")
	var sp: Dictionary = a.last_special
	# Review of 95847e0: the cancel is the point of this check, so it's required, with its +25 %.
	var base := float(a.moves.specials.toward.damage)
	_check(hit_ok and sp.get("dir", "") == "toward" and sp.get("cancel", false) and a.last_hit.get("kind", "") == "special"
		and is_equal_approx(float(a.last_hit.get("damage", 0)), base * (1.0 + a.cancel_bonus)),
		"SPECIAL PASS (light, then swipe toward = %s inside the cancel window: %.0f damage, +25%%)" % [sp.get("name", "?"),
		float(a.last_hit.get("damage", 0))])
	# Dodge: a real enemy swing (review of 95847e0: no calling _swing by hand). The hero stands 1.62 m
	# off: past the jab's 1.5 m reach, inside the dummy's 1.7 m. Double-tap late in the telegraph.
	# Use 0.5 s of i-frames for this check so the upcoming swing can land during the roll.
	a.reset_dummy()
	await _secs(1.0)
	_place(hero, dummy.global_position + Vector3(0, 0.05, 1.62), PI)
	a.rig.snap()
	await _secs(0.3)
	var hp_before: int = a.hp
	var dodged0: int = a.dodged
	var SwipePad = preload("res://scripts/swipe_pad.gd")
	var gesture_kind: String = SwipePad.classify(0.05, Vector2.ZERO, 0.1, a.hold_time, a.double_tap, a.swipe_min)
	_check(gesture_kind == "dodge", "DODGE CLASSIFIER PASS (two quick taps classify as dodge)")
	# The SPECIAL above ended the string, so the last tap's light no longer counts (no setting it by
	# hand, M2 review): the documented double-tap path is dodge.
	_check(not a._last_light_landed, "DODGE SETUP PASS (the special ended the light string)")
	a.dodge_iframes = 0.5
	a.enemy_telegraph = 1.0
	a.enemy_attack_every = 0.2
	a._enemy_t = 0.2
	var rolling := false
	var wait_until := Time.get_ticks_msec() + 4000
	while not (a.telegraphing and a._tele_t < 0.35) and Time.get_ticks_msec() < wait_until:
		await get_tree().process_frame
	# Dispatch both taps immediately. Waiting on render frames can miss the double-tap
	# window or let the dummy finish its wind-up before the second release reaches the pad.
	for pressed: bool in [true, false, true, false]:
		_mouse(pp, pressed)
		Input.flush_buffered_events()
	wait_until = Time.get_ticks_msec() + 2000
	while a.telegraphing and Time.get_ticks_msec() < wait_until:
		rolling = rolling or hero.is_acting("dodge")      # the roll clip itself, not i-frames (M2 review)
		await get_tree().process_frame
	await _physics(2)
	rolling = rolling or hero.is_acting("dodge")
	a.enemy_attack_every = 999.0
	a._enemy_t = 999.0
	a.enemy_telegraph = float(a.enemy.telegraph)
	a.dodge_iframes = float(a.moves.player.dodge_iframes)
	_check(rolling and a.dodged > dodged0 and a.hp == hp_before,
		"DODGE PASS (double-tap rolled through the dummy's own swing: missed in the i-frames, HP %d)" % a.hp)
	await _secs(0.8)
	# Weapon: pick up the pipe, 4 hits spend it, the 5th snaps it (x2.5, big knockback) and KOs.
	a.reset_dummy()
	_place(hero, a._pickup.global_position + Vector3(0, 0.05, 0.5), PI)
	a.rig.snap()
	await _secs(0.3)
	var can: bool = _find("PICK UP") != null
	await _click("PICK UP")
	await _frames(3)
	_check(can and a.combat.weapon == "pipe" and _has_label("PIPE 4/4"), "PICKUP PASS (PICK UP button, PIPE 4/4)")
	_shot("arena_weapon")
	var kos0: int = a.kos
	var broke := false
	var break_dmg := 0.0
	for i in 8:
		if a.kos > kos0:
			break
		await _face_dummy(a)
		if await _pad_tap(game) and a.last_hit.get("broke", false):
			broke = true
			break_dmg = float(a.last_hit.damage)
			await _frames(2)
			_shot("arena_break")
		await _secs(0.4)
	_check(broke and a.combat.weapon == "" and absf(break_dmg - (8.0 + 4.0) * 2.5) < 0.01,
		"WEAPON BREAK PASS (4 hits spent the pipe, the 5th snapped it for %.0f damage)" % break_dmg)
	_check(a.kos > kos0 and dummy.dead, "KO PASS (dummy down, round %d)" % game.level)
	await _secs(float(a.enemy.respawn) + 0.5)
	# The dummy fights back: telegraph (red ! + caption) for >= 0.5 s, then a swing that hurts.
	a.enemy_attack_every = 0.3
	a._enemy_t = 0.3
	a.enemy_telegraph = float(a.enemy.telegraph)
	var hp1: int = a.hp
	var hits_before_enemy: int = a.hero_hits_taken
	var tele_seen := false
	var until := Time.get_ticks_msec() + 6000
	while a.hero_hits_taken == hits_before_enemy and Time.get_ticks_msec() < until:
		_place(hero, dummy.global_position + Vector3(0, 0.05, 1.0), PI)
		if a.telegraphing and a._warn.visible:
			if not tele_seen:
				_shot("arena_telegraph")
			tele_seen = true
		await _frames(2)
	_check(tele_seen and a.hero_hits_taken > hits_before_enemy and a.hp < hp1, "ENEMY PASS (red ! telegraph, then the swing took %d HP)" % (hp1 - a.hp))
	a.enemy_attack_every = float(a.enemy.attack_every)
	a._enemy_t = a.enemy_attack_every


# ---------------------------------------------------------------- house standards (GROK_STANDARDS.md)

func _contrast(img: Image, cam: Camera3D, c: Node) -> float:
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var lum := func(p: Vector2) -> float:
		var tot := 0.0
		for dx in range(-3, 4, 3):
			for dy in range(-3, 4, 3):
				var q := Vector2i((p * scale) + Vector2(dx, dy))
				q = q.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
				tot += img.get_pixelv(q).get_luminance()
		return tot / 9.0
	var chest: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 1.15, 0))
	var feet: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 0.05, 0))
	var hips: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 0.95, 0))
	var hero_l: float = (lum.call(chest) + lum.call(hips)) / 2.0
	var floor_l := 0.0
	for o in [Vector2(-90, 0), Vector2(90, 0), Vector2(-90, 40), Vector2(90, 40)]:
		floor_l += lum.call(feet + o) / 4.0
	return (maxf(hero_l, floor_l) + 0.05) / (minf(hero_l, floor_l) + 0.05)


func _standards_checks(ct: Node, coach_was: bool) -> void:
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	var feel: Node = get_node("/root/Feel")
	var audio: Node = get_node("/root/Audio")
	var controls: Node = get_node("/root/Controls")
	# 7. First 60 seconds: the move hint showed, and went away once the player moved.
	_check(coach_was and not ct.has_node("UI/Root/Coach_move") and preload("res://scripts/coach.gd").seen("move"),
		"COACH PASS (DRAG TO MOVE shown, learned by doing)")
	# 1 + 10. Game feel: the punches earlier fired every part.
	_check(feel.shakes >= 3 and feel.bursts >= 3 and feel.buzzes >= 3 and feel.sounds >= 3,
		"FEEL PASS (hit-stop, shake x%d, sparks x%d, sound, buzz x%d)" % [feel.shakes, feel.bursts, feel.buzzes])
	# 2. Camera: smooth, never through a wall, frames the target.
	ct.reset_dummy()
	_place(hero, Vector3(0, 0.05, 0), 0.0)
	await _physics(10)
	var last: Vector3 = ct.rig.cam.global_position
	var fastest := 0.0
	ct.bot_stick = Vector2(1, 0)
	# Smooth = the camera glides: never faster than twice the hero's top speed (no jump cuts).
	# Why real time (Hunter, Nov 21): per-frame speed flaked on slow boxes (one hitch frame read as
	# 15 m/s, tasks/lessons.md). Speed over >= 0.1 s of wall-clock time still catches a cut (a cut
	# moves metres at once) but ignores frame-time jitter.
	var last_us := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await _frames(1)
		var us := Time.get_ticks_usec()
		if us - last_us >= 100000:
			fastest = maxf(fastest, ct.rig.cam.global_position.distance_to(last) / ((us - last_us) / 1000000.0))
			last = ct.rig.cam.global_position
			last_us = us
	ct.bot_stick = Vector2.ZERO
	_check(fastest < hero.max_speed * 2.0, "CAMERA SMOOTH PASS (camera top speed %.1f m/s)" % fastest)
	_place(hero, Vector3(-12, 0.05, 2.2), 0.0)
	await _physics(30)
	var cam: Camera3D = ct.rig.cam
	var see: Dictionary = get_tree().current_scene.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(cam.global_position, hero.global_position + Vector3(0, 1.2, 0), 1, [hero.get_rid()]))
	_check(ct.rig.blocked and see.is_empty(), "CAMERA WALL PASS (camera came in front of the wall)")
	_shot("std_camera_wall")
	_place(hero, Vector3(0, 0.05, 4), PI)
	dummy.global_position = Vector3(0, 0, -5)
	ct.toggle_aim()
	await _physics(120)
	var vp := get_viewport().get_visible_rect()
	var both: bool = vp.has_point(cam.unproject_position(hero.global_position + Vector3(0, 1, 0))) \
		and vp.has_point(cam.unproject_position(dummy.global_position + Vector3(0, 1, 0))) \
		and not cam.is_position_behind(dummy.global_position)
	_check(both, "CAMERA FRAME PASS (hero and target both on screen)")
	_shot("std_camera_frame")
	# 6. Music shifts to the combat layer when fighting.
	_check(audio.intensity > 0.9, "MUSIC PASS (combat layer at %d%%)" % int(audio.intensity * 100))
	ct.toggle_aim()
	ct.reset_dummy()
	# 6. Footsteps per surface: stone floor, wooden ramp, grass.
	hero.steps.clear()
	for spot in [[Vector3(-2, 0.05, -1), Vector2(1, 0)], [Vector3(5, 0.05, 0.5), Vector2(0, -1)], [Vector3(-2, 0.1, 8), Vector2(1, 0)]]:
		_place(hero, spot[0], 0.0)
		ct.bot_stick = spot[1] * 0.5
		await _physics(70)
	ct.bot_stick = Vector2.ZERO
	_check(hero.steps.has("stone") and hero.steps.has("wood") and hero.steps.has("grass"),
		"STEPS PASS (%s)" % str(hero.steps))
	# 6. Ducking: check the dip while it happens, before the music recovers.
	feel.impact(hero.global_position, 0.8, ct)
	var duck_by := Time.get_ticks_msec() + 1000
	while audio.duck_db >= -4.0 and Time.get_ticks_msec() < duck_by:
		await get_tree().process_frame
	_check(audio.duck_db < -4.0, "DUCK PASS (music dipped %.0f dB)" % audio.duck_db)
	# 4. Responsive: input buffer, coyote time, dodge cancels anything.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	await _physics(10)
	hero.jump()
	var buffered := false
	var takeoffs := 0
	var prev_vy := 0.0
	for i in 120:
		await _physics(1)
		if hero.velocity.y > 3.0 and prev_vy <= 3.0:
			takeoffs += 1
		prev_vy = hero.velocity.y
		if not buffered and hero.velocity.y < -2.0 and hero.global_position.y < 0.35:
			hero.jump()                         # pressed before landing: must still jump
			buffered = true
	_check(takeoffs >= 2, "BUFFER PASS (jump pressed in the air fired on landing)")
	_place(hero, Vector3(0, 1.05, -8.0), 0.0)
	await _physics(10)
	ct.bot_stick = Vector2(0, 1)
	var coyote_ok := false
	for i in 90:
		await _physics(1)
		if not hero.is_on_floor() and hero.velocity.y <= 0.0 and hero.global_position.y < 0.98:
			await _physics(2)
			hero.jump()
			await _physics(1)
			coyote_ok = hero.velocity.y > 3.0
			break
	ct.bot_stick = Vector2.ZERO
	_check(coyote_ok, "COYOTE PASS (jumped just after leaving the edge)")
	await _physics(60)
	hero.act("punch")
	await _physics(3)
	hero.act("dodge")
	await _physics(3)
	_check(hero.is_acting("dodge") and not hero.is_acting("punch"), "CANCEL PASS (punch cancelled into a dodge)")
	await _physics(110)
	# 11. Gamepad + remapping, through the real input system.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	ct.bot_stick = Vector2.INF                # hand control back to the real inputs
	await _physics(5)
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 1.0
	Input.parse_input_event(m)
	await _physics(30)
	var pad_speed: float = hero.velocity.x
	m.axis_value = 0.0
	Input.parse_input_event(m)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	await _physics(20)
	Input.parse_input_event(b)
	await _frames(3)                           # parsed input is delivered on the next frame
	var pad_jump: bool = hero.mode == "air" or hero.velocity.y > 1.0
	b.pressed = false
	Input.parse_input_event(b)
	_check(pad_speed > 3.0 and pad_jump, "PAD PASS (stick moves %.1f m/s, A jumps)" % pad_speed)
	await _physics(80)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_T
	controls.rebind("jump", k)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	var remap_ok: bool = (hero.mode == "air" or hero.velocity.y > 1.0) and FileAccess.file_exists("user://controls.cfg")
	press.pressed = false
	Input.parse_input_event(press)
	controls.reset()
	_check(remap_ok,
		"REMAP PASS (jump moved to T, saved, reset)")
	await _physics(80)
	# Controls legend: hidden for touch players, shows on the first key/pad press, follows remaps,
	# and the Settings toggle hides it.
	var lg: PanelContainer = preload("res://scripts/controls_legend.gd").make(["jump", "pause"])
	lg.top = 420                              # below the scene's own legend
	ct.ui.add_child(lg)
	await _frames(2)
	var hidden_touch := not lg.visible
	var kp := InputEventKey.new()
	kp.physical_keycode = KEY_Z
	kp.pressed = true
	Input.parse_input_event(kp)
	kp.pressed = false
	Input.parse_input_event(kp)
	await _frames(3)
	var shown := lg.visible
	await _frames(2)
	_shot("legend")
	var kt := InputEventKey.new()
	kt.physical_keycode = KEY_T
	controls.rebind("jump", kt)
	lg.refresh()
	var follows: bool = "T" in lg._label.text.split("\n")[0]
	controls.reset()
	var settings: Node = get_node("/root/Settings")
	settings.set_value("show_legend", false)
	var off := not lg.visible
	settings.set_value("show_legend", true)
	_check(hidden_touch and shown and follows and off and ct.legend != null,
		"LEGEND PASS (hidden on touch, shows on key, follows remap, toggle hides)")
	lg.queue_free()
	# 5. The hero reads against the floor, in normal light and in the dark.
	_place(hero, Vector3(-2, 0.05, 0.5), 0.0)
	await _physics(20)
	await RenderingServer.frame_post_draw
	var c1: float = _contrast(get_viewport().get_texture().get_image(), cam, hero)
	ct.sun.light_energy = 0.08
	await _frames(3)
	await RenderingServer.frame_post_draw
	var c2: float = _contrast(get_viewport().get_texture().get_image(), cam, hero)
	_shot("std_dark")
	ct.sun.light_energy = 1.2
	_check(c1 >= 2.0 and c2 >= 2.0, "READ PASS (hero vs floor contrast %.1f lit, %.1f dark)" % [c1, c2])
	# 3. Frame budget: draw calls, triangles, code time with 6 characters running.
	var r: Dictionary = await ct.perf_test(3.0, false)
	_check(r.budget_ok, "PERF PASS (%d draw calls, %dk tris, %.1f ms code; budget %s)" % [
		r.draw_calls, r.primitives / 1000.0, r.cpu_ms, str(ct.BUDGET)])
	# 9. Telemetry stays on the phone unless allowed.
	var tel: Node = get_node("/root/Telemetry")
	_check(not tel.allowed() and tel.events().size() > 0, "TELEMETRY PASS (%d events kept on the phone, nothing sent)" % tel.events().size())


# ---------------------------------------------------------------- 15 s gameplay clip (vertical)

## Plays a 15 s scripted fight (run, jump, punch combo, dodge, knockback) and saves every drawn
## frame as JPG in `clip` + fps.txt (frames / real seconds). tools/autoplay.sh turns it into
## gameplay.mp4; CI attaches it to the build. Watch it to see a build without installing it.
func _record_clip(ct: Node) -> void:
	DirAccess.make_dir_recursive_absolute(clip)
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	ct.reset_dummy()
	ct.legend.visible = false                   # the clip shows the game, not the key list
	ct.legend.set_process_input(false)
	_place(hero, Vector3(1.5, 0.05, 1.0), PI)
	ct.bot_stick = Vector2.ZERO
	await _physics(10)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var beats := [   # [seconds from start, what]
		[0.0, "run_circle"], [1.4, "toward"], [1.5, "aim"], [3.0, "punch"], [3.5, "punch"], [4.0, "punch"],
		[4.8, "jump"], [5.6, "dodge"], [6.2, "toward"], [7.2, "punch"], [7.7, "punch"], [8.2, "punch"],
		[9.0, "strafe"], [11.0, "dodge"], [11.6, "toward"], [12.4, "punch"], [12.9, "punch"], [13.4, "punch"],
		[14.2, "back"]]
	var next := 0
	var mode := "stop"
	while true:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t >= CLIP_SECS:
			break
		while next < beats.size() and t >= beats[next][0]:
			var what: String = beats[next][1]
			next += 1
			match what:
				"punch": ct.punch()
				"jump": hero.jump()
				"dodge": hero.act("dodge")
				"aim": hero.aim_at(dummy)
				_: mode = what
		var to_dummy: Vector3 = dummy.global_position - hero.global_position
		match mode:
			"run_circle": ct.bot_stick = Vector2(cos(t * 1.6), sin(t * 1.6)) * 0.9
			"toward": ct.bot_stick = Vector2(to_dummy.x, to_dummy.z).normalized() * 0.8 if Vector2(to_dummy.x, to_dummy.z).length() > 1.1 else Vector2.ZERO
			"back": ct.bot_stick = -Vector2(to_dummy.x, to_dummy.z).normalized() * 0.5
			"strafe": ct.bot_stick = Vector2(-to_dummy.z, to_dummy.x).normalized() * 0.7
			_: ct.bot_stick = Vector2.ZERO
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2 * 2, img.get_height() / 2 * 2)   # even size for video
		img.save_jpg(clip.path_join("f%04d.jpg" % frames), 0.85)
		frames += 1
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	ct.bot_stick = Vector2.INF
	hero.aim_at(null)
	var f := FileAccess.open(clip.path_join("fps.txt"), FileAccess.WRITE)
	f.store_string("%.3f" % (frames / secs))
	f.close()
	_check(frames >= 60 and secs >= CLIP_SECS, "CLIP PASS (%d frames over %.1f s saved for the build video)" % [frames, secs])


# ---------------------------------------------------------------- helpers

## Live tuning (DEV MENU -> TUNE): a slider moves every live node of its kind, and the value sticks.
func _tune_checks(ct: Node) -> void:
	var dm: Node = get_node("/root/DebugMenu")
	var Tune = preload("res://scripts/tune_panel.gd")
	dm.open()
	await _frames(5)
	await _click("TUNE")
	await _frames(10)
	var panel: Node = dm.tune_panel
	var sl: HSlider = panel.find_child("character3d__max_speed", true, false) if panel != null else null
	var cam_sl: HSlider = panel.find_child("camera_rig__distance", true, false) if panel != null else null
	var feel_sl: HSlider = panel.find_child("feel__stop_scale", true, false) if panel != null else null
	var was: float = ct.hero.max_speed
	if sl != null:
		sl.value = was + 1.5
	await _frames(3)
	_shot("tune_panel")
	var moved: bool = sl != null and absf(ct.hero.max_speed - (was + 1.5)) < 0.02
	var kept: bool = Tune.saved("character3d", "max_speed") != null
	var all_kinds: bool = cam_sl != null and feel_sl != null
	var shared: bool = "character3d.max_speed" in "\n".join(Tune.changed_lines(get_tree(), dm.tune_defaults))
	await _click("RESET TO CODE VALUES")
	await _frames(3)
	_check(moved and kept and shared and all_kinds and dm.tune_panel == null
		and is_equal_approx(ct.hero.max_speed, was) and Tune.saved("character3d", "max_speed") == null,
		"TUNE PASS (live sliders for hero, camera, feel; saved, shared, reset)")


func _check(ok: bool, line: String) -> void:
	if ok:
		print(line)
	else:
		failed = true
		print("FAIL: " + line)


func _fail(step: String) -> void:
	print("AUTOPLAY FAIL " + step)
	get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(node_name: String) -> void:
	for i in 600:
		var s := get_tree().current_scene
		if s != null and s.name == node_name:
			await _frames(2)
			return
		await _frames(1)
	_fail("scene " + node_name)


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join("flow_%s.png" % name))


# Why here (Nov 21 review): above `_find`'s doc comment, not between it and `func _find`.
## True when a visible Label shows exactly this text (Hunter M0: the title check).
func _has_label(text: String) -> bool:
	for l in get_tree().root.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text == text:
			return true
	return false


## The visible, enabled button whose text starts with `prefix` (topmost sheet wins).
func _find(prefix: String) -> Button:
	var found: Button = null
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix) and not b.is_queued_for_deletion():
			found = b
	return found


func _click(prefix: String) -> void:
	var b := _find(prefix)
	if b == null:
		_fail("no button " + prefix)
		return
	await _click_node(b)


func _click_node(c: Control) -> void:
	if c == null:
		_fail("no node")
		return
	var sc := c.get_parent()
	while sc != null and not sc is ScrollContainer:
		sc = sc.get_parent()
	if sc != null:
		(sc as ScrollContainer).ensure_control_visible(c)
		await _frames(3)
	await _tap_at(c.get_global_rect().get_center())


## A real tap at a canvas point: converted to window pixels and sent through Input.
func _tap_at(p: Vector2) -> void:
	var w := get_viewport().get_final_transform() * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = w
		e.global_position = w
		Input.parse_input_event(e)
		await _frames(2)

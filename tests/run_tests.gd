extends SceneTree
## Rule tests, headless: godot --headless --path . --script tests/run_tests.gd
## Last line is "ALL PASS (N)" or "FAILED k of N". Add a test_* function for every rule.
## A new test only counts once you've seen it fail (break the code, watch it go red, restore).

const Config = preload("res://scripts/config.gd")
const UI = preload("res://scripts/ui.gd")
const Updater = preload("res://scripts/updater.gd")
const BugReport = preload("res://scripts/bug_report.gd")
const Combat = preload("res://scripts/combat.gd")
const GameData = preload("res://scripts/game_data.gd")
const SwipePad = preload("res://scripts/swipe_pad.gd")
const VirtualStick = preload("res://scripts/virtual_stick.gd")
const Arena = preload("res://scripts/arena.gd")

var n := 0
var bad := 0


func _initialize() -> void:
	await process_frame   # autoloads are ready after the first frame
	for m in get_method_list():
		if m.name.begins_with("test_"):
			n += 1
			var before := bad
			await call(m.name)
			print(("ok   " if bad == before else "FAIL ") + m.name)
	print("ALL PASS (%d)" % n if bad == 0 else "FAILED %d of %d" % [bad, n])
	quit(1 if bad > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("  failed: " + what)


func test_save_roundtrip() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_run.json"
	save.clear()
	check(not save.exists(), "no save at start")
	check(save.write({"level": 3, "score": 27, "lives": 1}), "write ok")
	var d: Dictionary = save.read()
	check(int(d.get("level")) == 3 and int(d.get("score")) == 27, "same values back")
	check(int(d.get("_version")) == save.VERSION, "version stamped")
	save.clear()
	check(not save.exists(), "cleared")
	save.path = "user://run.json"


func test_corrupt_save_is_ignored() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_bad.json"
	var f := FileAccess.open(save.path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(save.read().is_empty(), "garbage save reads as empty, no crash")
	save.clear()
	save.path = "user://run.json"


func test_settings_defaults_and_persist() -> void:
	var s: Node = root.get_node("Settings")
	s.reset_for_tests()
	for k in ["music", "sfx", "vibration", "gamma", "text_size", "invert_y", "sensitivity",
			"low_graphics", "left_handed", "subtitles", "high_contrast", "colorblind"]:
		check(s.DEFAULTS.has(k), "setting exists: " + k)
	s.set_value("music", 0.25)
	s.values["music"] = 0.9
	s.load_settings()
	check(absf(float(s.get_value("music")) - 0.25) < 0.001, "music volume saved to disk")
	var bus := AudioServer.get_bus_index("Music")
	check(bus > 0, "Music bus exists at boot")
	check(AudioServer.get_bus_index("SFX") > 0, "SFX bus exists at boot")
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.1, "music slider moves the bus")
	s.reset_for_tests()
	s.save_settings()


func test_text_scale_steps() -> void:
	var s: Node = root.get_node("Settings")
	s.values["text_size"] = 3
	check(UI.font_size(20) > 20, "large text is larger")
	s.values["text_size"] = 1
	check(UI.font_size(20) == 20, "normal is unchanged")


func test_colorblind_swaps_key_colors() -> void:
	var s: Node = root.get_node("Settings")
	s.values["colorblind"] = false
	var a := UI.key("good")
	s.values["colorblind"] = true
	check(UI.key("good") != a, "colorblind palette differs")
	s.values["colorblind"] = false


func test_touch_targets() -> void:
	check(UI.MIN_TOUCH >= 62, "min touch >= 48dp (~62 base units)")
	var b := UI.button("X")
	check(b.custom_minimum_size.y >= UI.MIN_TOUCH, "buttons use the minimum")
	b.free()


func test_updater_compare() -> void:
	check(Updater.is_newer(5, 4), "newer build offered")
	check(not Updater.is_newer(4, 4), "same build not offered")
	check(not Updater.is_newer(9, 0), "editor build (0) never offered")


func test_config_paths() -> void:
	check(Config.apk_name().ends_with(".apk"), "apk name")
	check(Config.release_url().begins_with("https://github.com/") and Config.release_url().ends_with("/releases/download/dev/"), "release url")


## Hunter M0 (docs/BUILD_SPEC.md hard rules): named Hunter, portrait 720x1280, canvas_items stretch,
## expand aspect, Compatibility renderer, engine 4.6. Why (Nov 21): these were the copy's only
## edits to the starter's settings, so a later copy or merge must not undo them silently.
func test_hunter_project_settings() -> void:
	var g := func(k: String): return ProjectSettings.get_setting(k)
	check(g.call("application/config/name") == "Hunter", "config/name is Hunter")
	check(int(g.call("display/window/size/viewport_width")) == 720 and int(g.call("display/window/size/viewport_height")) == 1280, "base canvas 720x1280")
	check(g.call("display/window/stretch/mode") == "canvas_items", "canvas_items stretch")
	check(g.call("display/window/stretch/aspect") == "expand", "expand aspect")
	check(is_equal_approx(float(g.call("display/window/stretch/scale")), 1.3333), "UI scale keeps the 540-wide UI canvas (touch rule)")
	check(g.call("rendering/renderer/rendering_method") == "gl_compatibility" and g.call("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "Compatibility renderer")
	check("4.6" in PackedStringArray(g.call("application/config/features")), "engine 4.6")
	check(Config.FALLBACK_REPO == "duffpowell-commits/hunter", "updater points at the hunter repo")


func test_bug_report_text() -> void:
	var t := BugReport.report_text("it broke", self)
	check(t.begins_with("it broke"), "note first")
	check("build:" in t and "device:" in t, "build + device added")
	check(BugReport.issue_url(t).contains("/issues/new?"), "issue link")


# ---------------------------------------------------------------- house standards (GROK_STANDARDS.md)

## 11. Every game action works on keyboard AND gamepad, and remaps survive a restart.
func test_controls_keyboard_and_pad() -> void:
	var c: Node = root.get_node("Controls")
	for a in c.ACTIONS:
		var has_key := false
		var has_pad := false
		for e in InputMap.action_get_events(a):
			has_key = has_key or e is InputEventKey
			has_pad = has_pad or c.is_pad(e)
		check(has_key and has_pad, a + " has a key and a pad input")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_G
	c.rebind("attack", k)
	var fresh: Node = load("res://scripts/controls.gd").new()
	fresh._load()
	check(fresh._custom.has("attack") and (fresh._custom.attack.key as InputEventKey).physical_keycode == KEY_G, "remap saved and loaded")
	fresh.free()
	c.reset()
	check(not InputMap.action_has_event("attack", k), "reset restores defaults")


## 9 + 12. Stats stay on the phone unless the player opts in AND an endpoint is set; a run that
## didn't close cleanly is spotted next launch.
func test_telemetry_offline_and_crash_flag() -> void:
	var t: Node = root.get_node("Telemetry")
	check(not t.allowed(), "nothing is sent by default")
	var before: int = t.events().size()
	t.event("unit_test", {"x": 1})
	check(t.events().size() == before + 1, "event kept locally")
	var f := FileAccess.open(t.RUN_FLAG, FileAccess.WRITE)
	f.store_string("Game v0.1.0")
	f = null
	var fresh: Node = load("res://scripts/telemetry.gd").new()
	root.add_child(fresh)
	check(fresh.crashed_last_run, "unclean exit detected")
	fresh.clean_exit()
	check(not FileAccess.file_exists(t.RUN_FLAG), "clean exit clears the flag")
	fresh.queue_free()
	var http := 0
	for n in root.find_children("*", "HTTPRequest", true, false):
		if t.is_ancestor_of(n):
			http += 1
	check(http == 0, "no network request without consent")


## 8. Portable assets: every model is glTF on the standard humanoid skeleton and listed in SOURCES.
func test_models_portable() -> void:
	var sources := FileAccess.get_file_as_string("res://assets/models/SOURCES.md")
	var d := DirAccess.open("res://assets/models")
	var count := 0
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".md"):
			continue
		count += 1
		check(f.ends_with(".glb") or f.ends_with(".gltf"), f + " is glTF")
		check(f in sources, f + " listed in SOURCES.md")
		var scene: Node = (load("res://assets/models/" + f) as PackedScene).instantiate()
		var sk := scene.find_children("*", "Skeleton3D", true, false)
		check(sk.size() == 1, f + " has one skeleton")
		if sk.size() == 1:
			for b in ["pelvis", "spine_01", "Head", "thigh_l", "calf_l", "foot_l", "upperarm_r", "hand_r"]:
				check((sk[0] as Skeleton3D).find_bone(b) >= 0, f + " has bone " + b)
			_check_model_scale(f, scene as Node3D, sk[0] as Skeleton3D)
		scene.free()
	check(count > 0, "models found")


## Normalised import: 1 unit = 1 m, root scale 1, feet on y = 0, same facing as the mannequin
## (glTF +Z forward; Character3D turns it). Catches 100x centimetre roots and floating feet.
func _check_model_scale(f: String, root: Node3D, sk: Skeleton3D) -> void:
	check(root.scale.is_equal_approx(Vector3.ONE), f + " root scale is 1")
	var xf := Transform3D.IDENTITY
	var n: Node = sk
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var head := (xf * sk.get_bone_global_rest(sk.find_bone("Head"))).origin
	var foot := (xf * sk.get_bone_global_rest(sk.find_bone("foot_l"))).origin
	var toe_i := sk.find_bone("ball_l")
	var toe := (xf * sk.get_bone_global_rest(toe_i)).origin if toe_i >= 0 else foot
	check(head.y > 1.2 and head.y < 2.2, f + " is human height in metres (head at %.2f)" % head.y)
	check(minf(toe.y, foot.y) > -0.05 and minf(toe.y, foot.y) < 0.12, f + " feet on y = 0 (%.2f)" % minf(toe.y, foot.y))
	check(toe_i < 0 or toe.z > foot.z, f + " faces +Z like the mannequin")


## Texture imports are explicit: colour maps are sRGB and never normal maps; only *_n / *_normal
## files may be normal maps. (Godot's "detect" setting can flip a colour map to a normal map.)
func test_texture_imports_explicit() -> void:
	for path: String in _files("res://assets", [".png.import", ".jpg.import", ".jpeg.import", ".webp.import"]):
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		var base: String = path.get_file().get_basename().get_basename()
		var is_normal: bool = base.ends_with("_n") or base.ends_with("_normal")
		var nm: int = cfg.get_value("params", "compress/normal_map", 0)
		check(nm == (1 if is_normal else 2), "%s normal_map is %s (set it, don't detect)" % [path, "on" if is_normal else "off"])


func _files(dir: String, ends: Array) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		for e in ends:
			if f.ends_with(e):
				out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub, ends))
	return out


## Phone textures: 3D textures import as ETC2/ASTC (the VRAM formats Android phones read directly).
func test_mobile_texture_compression() -> void:
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false),
		"ETC2/ASTC texture compression is on for phones")


## Atlases: a sheet + json made by tools/pack_atlas.py hands back the right piece.
func test_atlas_regions() -> void:
	var Atlas = preload("res://scripts/atlas.gd")
	var t: AtlasTexture = Atlas.tex("res://tests/fixtures/atlas_demo", "coin")
	check(t != null and t.region == Rect2(26, 0, 16, 16), "coin region read from the json")
	if t != null:
		var c := t.atlas.get_image().get_pixel(26 + 8, 8)
		check(c.r > 0.85 and c.g > 0.7 and c.b < 0.3, "coin pixel is gold (%s)" % c)
	check(Atlas.names("res://tests/fixtures/atlas_demo").size() == 3, "three images in the sheet")
	check(Atlas.tex("res://tests/fixtures/atlas_demo", "coin") == t, "atlas pieces are cached")


## Quality tiers: LOW sets low graphics + a smaller 3D render, HIGH undoes it, the pick is saved.
func test_quality_tiers() -> void:
	var Q = preload("res://scripts/quality.gd")
	var st: Node = root.get_node_or_null("Settings")
	check(st != null, "Settings autoload present")
	if st == null:
		return
	Q.apply(self, 0)
	check(st.get_value("low_graphics") == true and st.get_value("tier") == 0 and is_equal_approx(root.scaling_3d_scale, 0.7), "LOW applies")
	Q.apply(self, 2)
	check(st.get_value("low_graphics") == false and st.get_value("tier") == 2 and is_equal_approx(root.scaling_3d_scale, 1.0), "HIGH applies")
	check(Q.NAMES.size() == 3 and Q.SCALE.size() == 3, "three tiers")


## The rulebook stays split: every standards/ file is listed in the GROK_STANDARDS.md index,
## every link in the index exists, and no topic file grows past 60 lines (load only what you need).
func test_standards_index() -> void:
	var index := FileAccess.get_file_as_string("res://GROK_STANDARDS.md")
	check(index.length() > 0, "GROK_STANDARDS.md index exists")
	var d := DirAccess.open("res://standards")
	check(d != null, "standards/ folder exists")
	if d == null:
		return
	var count := 0
	for f in d.get_files():
		if not f.ends_with(".md"):
			continue
		count += 1
		check(("standards/" + f) in index, f + " is listed in the index")
		var lines := FileAccess.get_file_as_string("res://standards/" + f).split("\n").size()
		check(lines <= 60, "%s is short (%d lines)" % [f, lines])
	check(count >= 10, "topic files present")
	for m in RegEx.create_from_string("\\((standards/[^)]+)\\)").search_all(index):
		check(FileAccess.file_exists("res://" + m.get_string(1)), m.get_string(1) + " exists")


## Your own music: GAME MUSIC off mutes only the Music bus; sound effects keep playing. On iPhone
## the game mixes with other apps' audio. (Android: Godot never grabs audio focus, so Spotify etc.
## keep playing; never add a plugin that does.)
func test_play_your_own_music() -> void:
	var s: Node = root.get_node("Settings")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	s.set_value("game_music", false)
	check(AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(sfx), "GAME MUSIC off mutes music only")
	s.set_value("game_music", true)
	check(not AudioServer.is_bus_mute(music), "GAME MUSIC on brings it back")
	check(ProjectSettings.get_setting("audio/general/ios/mix_with_others", false), "iPhone mixes with other apps' music")


## Battery saver: paused/menu/idle = 30 fps, background = 5 fps + low-processor, play = full speed.
func test_battery_saver_states() -> void:
	var b: Node = root.get_node("Battery")
	b.set_state("saver")
	check(Engine.max_fps == 30, "saver caps at 30 fps")
	b.set_state("background")
	check(Engine.max_fps == 5 and OS.low_processor_usage_mode, "background drops to 5 fps, low-processor mode")
	b.set_state("play")
	check(Engine.max_fps == 60 and not OS.low_processor_usage_mode, "play is full speed")


## 7. Coach hints are short (no text walls).
func test_coach_hints_short() -> void:
	var re := RegEx.create_from_string('Coach\\.teach\\([^,]+,\\s*"[^"]+",\\s*"([^"]+)"')
	for f in ["res://scripts/character_test.gd", "res://scripts/game.gd"]:
		if not FileAccess.file_exists(f):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			check(m.get_string(1).split(" ", false).size() <= 4, "hint '%s' is 4 words or fewer" % m.get_string(1))


func test_tune_saves_applies_and_reports() -> void:
	var Tune = preload("res://scripts/tune_panel.gd")
	var feel: Node = root.get_node("Feel")
	var dm: Node = root.get_node("DebugMenu")
	Tune.clear()
	check(feel.is_in_group("tunable") and "feel" in Tune.kinds(self), "Feel is tunable")
	check(dm.tune_defaults.get("feel.shake_scale") == 1.0, "code value remembered")
	Tune.save_value("feel", "shake_scale", 2.0)
	feel.shake_scale = 1.0
	Tune.apply(feel)
	check(is_equal_approx(feel.shake_scale, 2.0), "saved value applied")
	var lines: PackedStringArray = Tune.changed_lines(self, dm.tune_defaults)
	check("feel.shake_scale = 2.0 (code 1.0)" in lines, "changed value reported: %s" % [lines])
	check("labels=tuning" in Tune.share_url("x"), "share link files a tuning issue")
	Tune.clear()
	feel.shake_scale = 1.0
	check(Tune.saved("feel", "shake_scale") == null, "reset clears saved values")


# ---------------------------------------------------------------- Hunter M1 (docs/BUILD_SPEC.md)
# Why (Nov 21): one rule test per M1 feature; the autoplay bot proves the same features in play.

func _combat() -> Combat:
	return Combat.new(GameData.load_json("moves"), GameData.load_json("weapons"))


## Tap, tap, tap = the L, L, L string; only the third knocks back (power >= 0.5).
func test_light_string() -> void:
	var c := _combat()
	var a := c.light()
	var b := c.light()
	var h := c.light()
	check(a.index == 0 and b.index == 1 and h.index == 2, "three taps walk the string")
	check(float(a.power) < 0.5 and float(b.power) < 0.5 and float(h.power) >= 0.5, "third hit knocks back")
	check(float(a.damage) == 8.0, "light = 8 damage")
	c.tick(c.string_gap + 0.1)
	check(c.light().index == 0, "a slow tap restarts the string")


## Hold and release = heavy: 20 damage, guard break.
func test_heavy() -> void:
	var h := _combat().heavy()
	check(float(h.damage) == 20.0 and h.get("guard_break", false) and h.kind == "heavy", "heavy = 20, guard break")


## A special swiped within 0.35 s of a landed hit cancels into it for +25 %; specials cool down.
func test_special_cancel() -> void:
	var c := _combat()
	c.land(c.light())
	var s := c.special("toward")
	c.commit(s)
	check(s.cancel and is_equal_approx(float(s.damage), 20.0 * 1.25), "cancel bonus inside the window")
	check(c.special("toward").is_empty(), "cooldown blocks a repeat")
	c.tick(1.0)
	var u := c.special("up")
	check(not u.cancel and float(u.damage) == 25.0, "no bonus outside the window")
	for d in ["up", "down", "toward", "away"]:
		check(c.moves.specials.has(d), "special for swipe " + d)
	# Review of 95847e0: the bonus is for the first special in a window, and asking spends nothing.
	c = _combat()
	c.land(c.light())
	var first := c.special("toward")
	c.commit(first)
	check(first.cancel and not c.special("away").cancel, "only the first special in a window gets +25%")
	c = _combat()
	c.special("down")                       # refused: never committed
	check(not c.special("down").is_empty(), "a refused special doesn't spend its cooldown")
	c.commit(c.special("down"))
	check(c.special("down").is_empty(), "a started special does")


## Every landed hit counts; the counter drops after the gap or when the hero is hit.
func test_combo_counter() -> void:
	var c := _combat()
	for i in 3:
		c.land(c.light())
	check(c.combo == 3, "three hits = 3")
	c.tick(c.combo_gap + 0.05)
	check(c.combo == 0, "resets after the gap")
	c.land(c.light())
	c.drop_combo()
	check(c.combo == 0, "getting hit drops it")


## The pipe: 4 durability, each hit costs 1, the next hit at 0 breaks it for x2.5 and a big knockback.
func test_weapon_breaks() -> void:
	var c := _combat()
	check(c.pick_up("pipe") and c.weapon == "pipe", "picked up")
	var w: Dictionary = c.weapons.pipe
	check(int(w.durability) >= 3 and int(w.durability) <= 5, "durability 3-5 (spec)")
	check(c.light().action == "slash_a", "armed swings use the weapon clips")
	for i in int(w.durability):
		var r := c.land({"kind": "light", "damage": 8, "power": 0.3})
		check(not r.broke and float(r.damage) == 8.0 + float(w.damage_bonus), "hit %d spends durability" % (i + 1))
	check(c.durability == 0 and c.weapon == "pipe", "spent, still held")
	var last := c.land({"kind": "light", "damage": 8, "power": 0.3})
	check(last.broke and is_equal_approx(float(last.damage), (8.0 + float(w.damage_bonus)) * 2.5) and float(last.power) >= 1.0, "break = x2.5, big knockback")
	check(c.weapon == "", "unarmed after the break")


## Pad gestures and swipe directions, without a screen.
func test_pad_gestures() -> void:
	check(SwipePad.classify(0.1, Vector2(5, 0), 9.0) == "light", "tap = light")
	check(SwipePad.classify(0.1, Vector2.ZERO, 0.15) == "dodge", "double-tap = dodge")
	check(SwipePad.classify(0.4, Vector2(10, 0), 9.0) == "heavy", "hold 0.3 s = heavy")
	check(SwipePad.classify(0.15, Vector2(0, -90), 9.0) == "swipe", "drag = swipe")
	var to := Vector2(0, -200)          # dummy straight up the screen
	check(Combat.swipe_dir(Vector2(0, -80), to) == "toward", "swipe at the target = toward")
	check(Combat.swipe_dir(Vector2(0, 80), to) == "away", "swipe from it = away")
	var side := Vector2(200, 0)         # dummy to the right
	check(Combat.swipe_dir(Vector2(0, -80), side) == "up" and Combat.swipe_dir(Vector2(0, 80), side) == "down", "up / down")


func test_virtual_stick() -> void:
	check(VirtualStick.stick_vector(Vector2(100, 100), Vector2(145, 100)).is_equal_approx(Vector2(0.5, 0)), "half push = 0.5")
	check(is_equal_approx(VirtualStick.stick_vector(Vector2.ZERO, Vector2(0, 500)).length(), 1.0), "capped at 1")


## Content is data, and the data ships in the APK.
func test_data_files_ship() -> void:
	for f in ["moves", "enemies", "weapons"]:
		check(not GameData.load_json(f).is_empty(), "data/%s.json loads" % f)
	var e: Dictionary = GameData.load_json("enemies").dummy
	check(float(e.telegraph) >= 0.5, "enemy telegraph >= 0.5 s (spec)")
	check(int(GameData.load_json("moves").player.hp) == 100, "player HP 100")
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	check("data/*.json" in str(cfg.get_value("preset.0", "include_filter", "")), "export includes data/*.json")


## Save v1 (Orb Catch) still loads as v2.
func test_save_migrates_v1() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_v1.json"
	var f := FileAccess.open(save.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"level": 3, "score": 7, "lives": 2, "_version": 1}))
	f.close()
	var d: Dictionary = save.read()
	check(save.VERSION == 2 and int(d.get("hp", 0)) == 100 and not d.has("lives") and int(d.level) == 3, "v1 -> v2")
	save.clear()
	save.path = "user://run.json"


## The arena: ink look on every surface, the 50-degree camera, the hero's rim, tunable.
func test_arena_setup() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	check(is_equal_approx(a.rig.pitch_deg, 50.0), "camera 50 degrees down")
	check(a.hero.rim > 0.0 and a.dummy.rim == 0.0, "orange rim on the hero only")
	var inked := 0
	var all := 0
	for m in a.find_children("*", "MeshInstance3D", true, false):
		if m.get_parent() is StaticBody3D:
			all += 1
			var mat := (m as MeshInstance3D).material_override as ShaderMaterial
			if mat != null and mat.shader.resource_path.ends_with("toon.gdshader") and mat.next_pass != null:
				inked += 1
	check(all > 0 and inked == all, "toon + outline on every arena surface (%d/%d)" % [inked, all])
	check(a.is_in_group("tunable") and a.TUNE.has("enemy_telegraph"), "arena numbers are TUNE sliders")
	check(a.hero.actions.has("heavy") and a.hero.actions.has("lunge"), "Hunter clips added to Character3D")
	a.queue_free()
	await process_frame


## Review of 95847e0: every number you feel in a fight is a live TUNE slider and acts at once.
func test_arena_tune_live() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	for k in ["dodge_iframes", "dodge_cooldown", "double_tap", "string_gap", "cancel_bonus", "damage_scale",
			"dummy_max_hp", "pipe_durability", "break_mult", "hold_time", "swipe_min", "combo_gap", "cancel_window"]:
		check(a.TUNE.has(k) and k in a, "TUNE slider " + k)
	a.damage_scale = 2.0
	a.cancel_bonus = 0.5
	a.string_gap = 0.4
	a.pipe_durability = 7.0
	a.break_mult = 4.0
	a.dummy_max_hp = 20.0
	await process_frame
	var c: Combat = a.combat
	check(c.damage_scale == 2.0 and c.cancel_bonus == 0.5 and c.string_gap == 0.4, "sliders reach the rules live")
	check(float(c.land(c.light()).damage) == 16.0, "damage_scale doubles a jab")
	check(c.pick_up("pipe") and c.durability == 7, "pipe durability slider")
	check(a.dummy_hp <= 20.0, "dummy HP slider caps the dummy")
	a.dodge_iframes = 0.5
	a.dodge_cooldown = 1.5
	a.dodge()
	check(is_equal_approx(a._iframes, 0.5) and is_equal_approx(a._dodge_cd, 1.5), "dodge sliders")
	a.queue_free()
	await process_frame


## Review of 95847e0: a swing connects at its hit_at, not the first frame, and mashing waits for recover.
func test_hit_timing_and_buffer() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	a.dummy.position = a.hero.position + Vector3(0, 0, 1.0)
	a.enemy_attack_every = 99.0
	a._enemy_t = 99.0
	await physics_frame
	a.light()
	check(a._move.get("id", "") == "jab", "jab started")
	a.light()
	check(a._move.id == "jab" and a._queued.get("kind", "") == "light", "a mashed tap waits in the buffer")
	await physics_frame
	await process_frame
	check(a.hits_landed == 0, "no contact on the first frame")
	var t := 0.0
	while a.hits_landed == 0 and t < 1.0:
		await process_frame
		t += a.get_process_delta_time()
	check(a.hits_landed == 1 and a._move_age >= float(a._move.get("hit_at", 9.0)) - 0.001, "jab lands at its hit_at")
	t = 0.0
	while a._move.get("id", "") == "jab" and t < 1.5:
		await process_frame
		t += a.get_process_delta_time()
	check(a._move.get("id", "") == "cross", "the buffered tap becomes the cross after recover")
	a.queue_free()
	await process_frame


## Review of 95847e0: a special cancels a roll's i-frames, and waits out a stagger instead of breaking it.
func test_special_rules_in_arena() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	a.enemy_attack_every = 99.0
	a._enemy_t = 99.0
	a.dodge()
	await physics_frame
	await process_frame
	check(a._iframes > 0.0, "the roll gives i-frames")
	a.special("toward")
	check(a._iframes == 0.0 and a.last_special.get("id", "") != "", "a special out of a roll drops the i-frames")
	a.hero.tree.set("parameters/shot_lunge/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	a.combat.cooldowns.clear()
	a._move = {}
	a.hero.act("knockback")
	await physics_frame
	await process_frame
	a.last_special = {}
	a.special("away")
	check(a.hero.is_acting("knockback") and a.last_special.is_empty() and a._queued.get("dir", "") == "away",
		"a special during a stagger is queued, the knockback plays on")
	a.queue_free()
	await process_frame


## Review of 95847e0: the double-tap is a dodge unless the tap before it was a light that connected.
func test_double_tap_resolves() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	a._last_light_landed = false
	a.double_tap_input()
	check(a._dodge_cd > 0.0, "double-tap after a whiff = dodge")
	a._dodge_cd = 0.0
	a._move = {}
	a._last_light_landed = true
	a.double_tap_input()
	check(a._dodge_cd == 0.0 and a._move.get("kind", "") == "light", "double-tap after a landed light = light")
	a.queue_free()
	await process_frame


## Review of 95847e0: keyboard and pad reach all four specials and the heavy, and the legend shows them.
func test_keyboard_reaches_every_special() -> void:
	var a := Arena.new()
	root.add_child(a)
	await process_frame
	a.dummy.position = a.hero.position + Vector3(2.0, 0, 0)
	await process_frame
	var t: Vector2 = a.target_screen_dir()
	check(t.length() > 1.0, "dummy on screen")
	var got := {}
	for v in [t.normalized(), -t.normalized(), Vector2(0, -1).rotated(0.0), Vector2(0, 1), Vector2.ZERO]:
		a.combat.cooldowns.clear()
		a._move = {}
		a._queued = {}
		a.last_special = {}
		a.stick_special(v)
		got[a.last_special.get("id", "?")] = true
	for id in ["lunge", "spin", "launcher", "sweep"]:
		check(got.has(id), "keyboard reaches " + id)
	var ctl: Node = root.get_node("Controls")
	for act in ["heavy", "special"]:
		check(InputMap.has_action(act) and ctl.ACTIONS.has(act), "action " + act)
	a.queue_free()
	await process_frame
	var g: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var text := ""
	for l in g.find_children("*", "Label", true, false):
		text += (l as Label).text + " "
	check("HEAVY" in text and "SPECIAL" in text, "legend lists HEAVY and SPECIAL")
	g.arena.hold_time = 0.55
	g.arena.swipe_min = 99.0
	g.arena.double_tap = 0.33
	await process_frame
	check(g.pad.hold_time == 0.55 and g.pad.swipe_min == 99.0 and g.pad.double_tap == 0.33, "pad sliders act live")
	g.queue_free()
	await process_frame


## Review of 95847e0: dying, then PAUSE -> QUIT -> CONTINUE, must not bring the run back.
func test_death_cannot_escape_through_save() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_death.json"
	save.clear()
	var g: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.arena.hp = 0
	g.arena.hero.die(Vector3.ZERO)
	g.arena.hero_died.emit()
	g.pause()
	g.save_for_quit()
	check(not save.exists(), "no save survives a death (pause + quit)")
	g.queue_free()
	await process_frame
	save.write({"level": 2, "score": 3, "hp": 0})
	g = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await process_frame
	check(g.arena.hp == g.arena.max_hp and int(g.level) == 1, "a 0 HP save starts a new run")
	g.queue_free()
	await process_frame
	save.clear()
	save.path = "user://run.json"


# ---------------------------------------------------------------- Hunter M2: The Pews domain rules

func test_pews_stalking_rules() -> void:
	var Pews = preload("res://scripts/pews_rules.gd")
	var p = Pews.new()
	var studied := 0.0
	studied = p.tick_stalking(studied, 4.0, PI, false, false, 1.0)
	check(studied > 0.0 and studied < 100.0, "target behind the enemy inside 6m and outside its 60-degree view cone studies")
	var sneaking := p.tick_stalking(0.0, 4.0, PI, true, false, 1.0)
	check(sneaking > studied, "sneaking studies faster")
	var reset := p.tick_stalking(80.0, 4.0, 0.0, false, true, 0.1)
	check(reset == 0.0, "being seen resets stalking")
	var full := p.tick_stalking(99.0, 4.0, PI, false, false, 1.0)
	check(full == 100.0, "studied meter caps at 100")
	var outside := p.tick_stalking(0.0, 7.0, PI, false, false, 1.0)
	check(outside == 0.0, "outside study radius does not fill meter")

func test_pews_boss_two_phases_and_finishers() -> void:
	var Pews = preload("res://scripts/pews_rules.gd")
	var p = Pews.new()
	var first: Dictionary = p.hit_boss(999.0)
	check(first.get("phase_changed", false) and int(first.get("phase", 0)) == 2, "Vesper enters phase two instead of dying after phase one")
	var second: Dictionary = p.hit_boss(999.0)
	check(second.get("defeated", false), "Vesper is defeated only after phase two")
	var clean = Pews.new()
	clean.hit_boss(999.0)
	clean.hit_boss(999.0)
	var clean_result: Dictionary = clean.finish("CLEAN")
	check(clean_result.get("corruption", -1) == 5 and clean_result.get("parts", 0) > 0 and clean_result.get("trophy", false), "CLEAN gives intact trophy, parts and +5 corruption")
	check(clean_result.get("extra_special_slots", 0) == 0, "CLEAN does not grant a brutal slot")
	var trophies: Variant = clean.get("trophies")
	check(trophies is Array and trophies.has("vesper"), "CLEAN permanently records Vesper's intact trophy")
	var brutal = Pews.new()
	brutal.hit_boss(999.0)
	brutal.hit_boss(999.0)
	var brutal_result: Dictionary = brutal.finish("BRUTAL")
	check(brutal_result.get("corruption", -1) == 15 and brutal_result.get("extra_special_slots", 0) == 1, "BRUTAL grants +1 special slot and +15 corruption")
	check(brutal_result.get("parts", 999) < clean_result.get("parts", 0), "BRUTAL yields fewer crafting parts")
	var slots: Variant = brutal.get("extra_special_slots")
	check(slots is Dictionary and int(slots.get("vesper", 0)) == 1, "BRUTAL permanently records Vesper's extra special slot")
	check(brutal.eat().get("voice_unlocked", false), "EAT unlocks Vesper as a voice")
	var voices: Variant = brutal.get("unlocked_voices")
	check(voices is Array and voices.has("vesper"), "EAT permanently records Vesper in the voice collection")
	check(not brutal.eat().get("voice_unlocked", true), "EAT cannot unlock the same voice twice")
	check(brutal.heal_boss(999.0) == 0.0, "defeated boss cannot heal")
	var wounded = Pews.new()
	wounded.hit_boss(30.0)
	check(wounded.heal_boss(999.0) == 30.0, "Laying of Hands heals only missing HP up to the phase cap")
	check(wounded.boss_hp == 140.0, "boss healing cannot exceed current phase maximum")

func test_pews_collection_plate_hazard() -> void:
	var Pews = preload("res://scripts/pews_rules.gd")
	var p = Pews.new()
	var result: Dictionary = p.collect_plate()
	check(result.get("cash", 0) > 0, "collection plate yields cash")
	check(result.get("heat", 0) > 0, "collection plate raises heat")


func test_pews_ambush_and_scavenging() -> void:
	var Pews = preload("res://scripts/pews_rules.gd")
	var p = Pews.new()
	p.tick_stalking(0.0, 4.0, PI, false, false, 20.0)
	check(p.ambush_ready(), "full study enables an ambush")
	check(p.start_ambush().get("free_first_special", false), "ambush staggers the target and grants a free opener")
	var loot: Dictionary = p.scavenge("stained_glass")
	check(loot.get("item", "") == "stained_glass" and loot.get("parts", 0) == 2, "scavenge collects realm-specific materials")
	check(not p.scavenge("not_real").has("item"), "unknown loot cannot be collected")


func test_pews_content_is_data_driven() -> void:
	var data: Dictionary = GameData.load_json("pews")
	check(data.get("boss", {}).get("id", "") == "vesper", "Pews boss comes from data")
	check(data.get("boss", {}).get("phase_hp", []).size() == 2, "Vesper has exactly two data-driven phases")
	for move: Dictionary in data.get("boss", {}).get("moves", {}).values():
		check(float(move.get("telegraph", 0.0)) >= 0.5, "every Vesper move has a telegraph of at least half a second")
	check(data.get("loot", []).size() >= 3, "Pews has realm-specific scavenging loot")


func test_pews_arena_starts_in_the_church() -> void:
	var PewsArena = preload("res://scripts/pews_arena.gd")
	var arena = PewsArena.new()
	root.add_child(arena)
	await process_frame
	check(arena.dummy.name == "Vesper", "Pews arena loads Vesper instead of the training dummy")
	check(arena.rules != null and arena.rules.boss_phase == 1, "Pews arena owns a fresh two-phase boss encounter")
	check(arena.get_node_or_null("Pews/Altar") != null, "Pews arena builds the church altar")
	arena.queue_free()
	await process_frame


## Review regression: inherited Arena applies damage to dummy_hp before invoking _ko.
## A lethal hit must consume the accumulated phase damage, not just the last blow.
func test_pews_boss_health_stays_in_sync() -> void:
	var PewsArena = preload("res://scripts/pews_arena.gd")
	var a = PewsArena.new()
	root.add_child(a)
	await process_frame
	a.encounter_started = true
	a.rules.engaged = true
	a.dummy_hp = 110.0
	a.sync_boss_health()
	check(is_equal_approx(a.rules.boss_hp, 110.0), "partial hits update boss rules HP and HUD")
	a.dummy_hp = -5.0
	a._ko({"damage": 10.0})
	check(a.rules.boss_phase == 2 and not a.rules.boss_defeated, "phase one KO transitions after cumulative damage")
	check(is_equal_approx(a.dummy_hp, a.rules.boss_hp) and a.dummy_hp > 0.0, "phase two HP is synchronized")
	a.dummy_hp = -2.0
	a._ko({"damage": 12.0})
	check(a.rules.boss_defeated and a.boss_defeated, "phase two KO defeats Vesper")
	a.queue_free()
	await process_frame

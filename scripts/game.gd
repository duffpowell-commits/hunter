extends Control
## The game screen. Hunter Milestone 1 (Nov 21, 2026): the 3D test arena (scripts/arena.gd) with
## the virtual stick (left thumb) and the swipe pad (right thumb). Why: BUILD_SPEC says replace the
## starter's placeholder "Orb Catch" PLAY section with Hunter and keep the rest; the rest is the
## starter's, unchanged: PAUSE button, Android back = pause, auto-pause + save when the app goes to
## the background, pause menu, GAME OVER -> try again / title, checkpoint autosave + CONTINUE,
## left-handed layout (mirrors stick and pad), subtitles for sound cues, vibration.
##   Knock the dummy out = next round = checkpoint (autosave). Hero HP 0 = GAME OVER.
## Keyboard / pad: move, ATTACK = light, HEAVY = heavy, SPECIAL + stick direction = the special
## (no direction = toward), DODGE = dodge. Actions, so remaps work (review of 95847e0: SPIN and
## SWEEP couldn't be reached without touch).

const UI = preload("res://scripts/ui.gd")
const SettingsSheet = preload("res://scripts/settings_sheet.gd")
const BugReport = preload("res://scripts/bug_report.gd")
const ControlsLegend = preload("res://scripts/controls_legend.gd")
const Arena = preload("res://scripts/arena.gd")
const PewsArena = preload("res://scripts/pews_arena.gd")
const LairArena = preload("res://scripts/lair_arena.gd")
const LairRules = preload("res://scripts/lair_rules.gd")
const LairSheets = preload("res://scripts/lair_sheets.gd")
const VoiceBox = preload("res://scripts/voice_box.gd")
const GameData = preload("res://scripts/game_data.gd")
const VirtualStick = preload("res://scripts/virtual_stick.gd")
const SwipePad = preload("res://scripts/swipe_pad.gd")

var level := 1               # the round: +1 for every knockout
var score := 0               # knockouts
var paused := false
var over := false

var arena: Arena
var hud: Label
var profile_label: Label     # cash, heat, parts, corruption (M3: the profile on the HUD)
var heal_btn: Button
var where := "pews"          # "pews" or "lair" (Save v4); the training arena is autoplay-only
var arrived := false         # came home through the portal this load (a night, or a raid)
var combo_label: Label
var weapon_label: Label
var pause_btn: Button
var pick_btn: Button
var stick: VirtualStick
var pad: SwipePad
var sheet_box: VBoxContainer
var _settings: Node
var _save: Node
var _saved_hp := -1
var leaving := false         # a portal/map-room save was written: nothing may overwrite it
var dying := false           # the hero is down: no more saves; GAME OVER follows (review of 95847e0)


func _ready() -> void:
	_settings = get_node("/root/Settings")
	_save = get_node("/root/Save")
	_settings.changed.connect(_on_setting)
	var d: Dictionary = _save.read()
	if not d.is_empty() and int(d.get("hp", 1)) <= 0:
		# A save written at 0 HP is a run that already ended: start fresh, never revive it.
		_save.clear()
		d = {}
	if not d.is_empty():
		level = int(d.get("level", 1))
		score = int(d.get("score", 0))
		_saved_hp = int(d.get("hp", -1))
		where = str(d.get("where", "pews"))
		arrived = bool(d.get("arrived", false))
	# The 3D arena lives for the whole scene; _build() only rebuilds the 2D layer on top.
	var autoplay := get_node_or_null("/root/Autoplay")
	if autoplay != null and autoplay.training_arena:
		where = "training"
		arena = Arena.new()
	elif where == "lair":
		arena = LairArena.new()
	else:
		where = "pews"
		arena = PewsArena.new()
	arena.add_to_group("keep")
	add_child(arena)
	if _saved_hp > 0:
		arena.hp = mini(_saved_hp, arena.max_hp)
	arena.ko.connect(_on_ko)
	arena.hero_died.connect(_on_hero_died)
	if arena.has_signal("finish_requested"):
		arena.connect("finish_requested", Callable(self, "_on_finish_requested"))
		arena.connect("voice_unlocked", Callable(self, "_on_voice_unlocked"))
		arena.connect("portal_opened", Callable(self, "_on_portal_opened"))
		arena.connect("phase_changed", checkpoint)
	if arena.has_signal("voice_moment"):
		arena.connect("voice_moment", Callable(self, "speak"))
	if arena.has_signal("station_requested"):
		arena.connect("station_requested", Callable(self, "_on_station"))
		arena.connect("raid_finished", Callable(self, "_on_raid_finished"))
	if arena.has_method("restore_state"):
		arena.call("restore_state", d.get("pews", {}))
	_build()
	checkpoint()
	get_node("/root/Audio").music_layers("music_loop", "music_combat")
	if where == "lair":
		_enter_lair.call_deferred()


# ---------------------------------------------------------------- state + saving

func state() -> Dictionary:
	var result := {"level": level, "score": score, "hp": arena.hp if arena != null else 100, "where": where}
	if arena != null and arena.has_method("save_state"):
		result["pews"] = arena.call("save_state")
	return result


## Never saves a dead hero: dying escaped GAME OVER through PAUSE -> QUIT -> CONTINUE (review of 95847e0).
func checkpoint() -> void:
	if leaving or dying or over or (arena != null and (arena.hp <= 0 or arena.hero.dead)):
		return
	_save.write(state())


func bug_state() -> String:
	return "round %d kos %d paused %s over %s %s" % [level, score, paused, over, arena.bug_state() if arena != null else ""]


# ---------------------------------------------------------------- layout

func _on_setting(key: String) -> void:
	if key in ["text_size", "high_contrast", "left_handed"]:
		_build()


func _build() -> void:
	for c in get_children():
		if not c.is_in_group("sheet") and not c.is_in_group("keep"):
			c.queue_free()
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left: bool = _settings.get_value("left_handed")
	# Left-handed mirrors the halves: stick on the right, pad on the left.
	stick = VirtualStick.new()
	stick.name = "Stick"
	_half(stick, left)
	pad = SwipePad.new()
	pad.name = "Pad"
	pad.hold_time = arena.hold_time
	pad.swipe_min = arena.swipe_min
	pad.double_tap = float(arena.moves.pad.double_tap)
	pad.gesture.connect(_on_gesture)
	_half(pad, not left)
	hud = UI.label("", 24)
	hud.anchor_right = 1.0
	hud.offset_left = 190      # clear of the PAUSE button on either side
	hud.offset_right = -190
	hud.offset_top = 30
	hud.offset_bottom = 30 + UI.MIN_TOUCH
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	profile_label = UI.label("", 17, UI.DIM)
	profile_label.name = "Profile"
	profile_label.anchor_right = 1.0
	profile_label.offset_top = 30 + UI.MIN_TOUCH + 4
	profile_label.offset_bottom = 30 + UI.MIN_TOUCH + 58
	profile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(profile_label)
	combo_label = UI.label("", 40, UI.ACCENT)
	combo_label.name = "Combo"
	combo_label.anchor_right = 1.0
	combo_label.offset_top = 166
	combo_label.offset_bottom = 222
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_label)
	weapon_label = UI.label("", 22)
	weapon_label.name = "Weapon"
	weapon_label.anchor_right = 1.0
	weapon_label.offset_top = 222
	weapon_label.offset_bottom = 258
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_label)
	var legend := ControlsLegend.make(["move_up", "attack", "heavy", "special", "dodge", "pause"])
	legend.name = "Legend"
	legend.top = 30 + UI.MIN_TOUCH + 64
	add_child(legend)
	pause_btn = UI.button("PAUSE", pause)
	_corner(pause_btn, left, true, 150)
	# A crafted poultice, in the field or a raid (hidden when there's none or HP is full).
	heal_btn = UI.button("HEAL", heal)
	heal_btn.name = "Heal"
	# Opposite corner from the context button, clear of the voice box at the top (it ate the tap).
	_corner(heal_btn, left, false, 150)
	heal_btn.offset_top -= 260
	heal_btn.offset_bottom -= 260
	# Context button above the pad (BUILD_SPEC: INTERACT / SCAVENGE / FINISH go here).
	pick_btn = UI.button("PICK UP", _context_action, 96)
	pick_btn.name = "PickUp"
	# 260 wide: COLLECT PLATE and RETURN HOME didn't fit in 200 (M2 review).
	_corner(pick_btn, not left, false, CONTEXT_W)
	pick_btn.offset_top -= 260
	pick_btn.offset_bottom -= 260
	for sh in get_tree().get_nodes_in_group("sheet"):   # open sheets stay on top of the rebuilt HUD
		if sh.get_parent() == self:
			move_child(sh, -1)
	_refresh_hud()


## One thumb half of the screen, below the HUD.
func _half(c: Control, right: bool) -> void:
	c.anchor_left = 0.5 if right else 0.0
	c.anchor_right = 1.0 if right else 0.5
	c.anchor_bottom = 1.0
	c.offset_top = 260
	add_child(c)


## Put a button in a corner. right=true -> right side. top=true -> top.
func _corner(b: Button, right: bool, top: bool, w: int) -> void:
	var h := int(b.custom_minimum_size.y)
	b.anchor_left = 1.0 if right else 0.0
	b.anchor_right = b.anchor_left
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = b.anchor_top
	var x := -24 - w if right else 24
	var y := 30 if top else -40 - h
	b.offset_left = x
	b.offset_right = x + w
	b.offset_top = y
	b.offset_bottom = y + h
	add_child(b)


const CONTEXT_W := 260


func _refresh_hud() -> void:
	if hud == null or arena == null:
		return
	var god := " GOD" if get_node("/root/DebugMenu").god_mode else ""
	var status := str(arena.call("status_text")) if arena.has_method("status_text") else ""
	# "ROUND n" is the training arena's; the hunt and the lair show HP and the profile (M2 review).
	# The status line moved to the full-width row under it: in the 160-wide centre it wrapped onto
	# the profile line (M3 renders).
	var p: Dictionary = get_node("/root/Profile").data
	if where == "training":
		hud.text = "ROUND %d\nHP %d%s%s" % [level, arena.hp, god, "\n" + status if not status.is_empty() else ""]
		profile_label.text = ""
	else:
		hud.text = "HP %d/%d%s" % [arena.hp, arena.max_hp, god]
		profile_label.text = "$%d  HEAT %d  PARTS %d  CORR %d%s" % [int(p.cash), int(p.heat), int(p.parts), int(p.corruption),
			"\n" + status if not status.is_empty() else ""]
	heal_btn.visible = where != "training" and int(p.inventory.get("wax_poultice", 0)) > 0 and arena.hp < arena.max_hp and not arena.hero.dead
	var c: int = arena.combo_count()
	combo_label.text = "%d HITS" % c if c >= 2 else ""
	var w: String = arena.combat.weapon
	weapon_label.text = "%s %d/%d" % [arena.weapon_data[w].name, arena.combat.durability, int(arena.weapon_data[w].durability)] if w != "" else ""
	if arena.has_method("context_label"):
		pick_btn.text = str(arena.call("context_label"))
		pick_btn.visible = bool(arena.call("context_visible"))
	else:
		pick_btn.text = "PICK UP"
		pick_btn.visible = arena.can_pick_up


# ---------------------------------------------------------------- PLAY (Hunter M1)

func _process(_dt: float) -> void:
	if paused or over or arena == null:
		return
	arena.stick = stick.vec if stick != null else Vector2.ZERO
	if pad != null:                  # live TUNE sliders reach the pad every frame
		pad.hold_time = arena.hold_time
		pad.swipe_min = arena.swipe_min
		pad.double_tap = arena.double_tap
	_refresh_hud()


func _on_gesture(kind: String, v: Vector2) -> void:
	if paused or over:
		return
	match kind:
		"light": arena.light()
		"heavy": arena.heavy()
		"dodge": arena.double_tap_input()
		"swipe": arena.swipe(v)


func _unhandled_input(e: InputEvent) -> void:
	if paused or over:
		return
	# Actions, not keys: keyboard, gamepad and remaps (Controls autoload).
	if e.is_action_pressed("attack"):
		arena.light()
	elif e.is_action_pressed("heavy"):
		arena.heavy()
	elif e.is_action_pressed("special"):
		var v := stick.vec if stick != null and stick.held() else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		arena.stick_special(v)
	elif e.is_action_pressed("dodge"):
		arena.dodge()


func _context_action() -> void:
	if arena != null and arena.has_method("context_action"):
		arena.call("context_action")
		checkpoint()
	else:
		arena.pick_up()
	_refresh_hud()


func _on_finish_requested() -> void:
	var sh := UI.sheet(self)
	var pews_rules: Variant = arena.get("rules")
	var outcomes: Dictionary = pews_rules.config.get("finishers", {}) if pews_rules != null else {}
	var clean: Dictionary = outcomes.get("clean", {})
	var brutal: Dictionary = outcomes.get("brutal", {})
	sh.add_child(UI.label("VESPER IS BROKEN", 28, UI.ACCENT))
	sh.add_child(UI.label("Choose what remains of him.", 18))
	sh.add_child(UI.label("CLEAN: intact trophy, %d parts, +%d corruption" % [int(clean.get("parts", 0)), int(clean.get("corruption", 0))], 15))
	sh.add_child(UI.button("CLEAN", func(): _choose_finish(sh, "CLEAN"), 88))
	sh.add_child(UI.label("BRUTAL: +%d voice slot, %d parts, +%d corruption" % [int(brutal.get("extra_special_slots", 0)), int(brutal.get("parts", 0)), int(brutal.get("corruption", 0))], 15))
	sh.add_child(UI.button("BRUTAL", func(): _choose_finish(sh, "BRUTAL"), 88))


func _choose_finish(sh: VBoxContainer, method: String) -> void:
	UI.close_sheet(sh)
	var result: Dictionary = arena.call("choose_finisher", method)
	if not result.is_empty():
		get_node("/root/Subs").cue("[%s finisher]" % method.to_lower())
		checkpoint()
	_refresh_hud()


func _on_voice_unlocked() -> void:
	var sh := UI.sheet(self)
	var pews_rules: Variant = arena.get("rules")
	var voice: Dictionary = pews_rules.config.get("voice", {}) if pews_rules != null else {}
	sh.add_child(UI.label(str(voice.get("name", "BROTHER VESPER LYLE")), 26, UI.ACCENT))
	sh.add_child(UI.label(str(voice.get("dialogue", "You ate me mid-sermon. The congregation will hear of this.")), 19))
	sh.add_child(UI.button("CLOSE", func(): UI.close_sheet(sh), 88))
	get_node("/root/Subs").cue("[a new voice speaks in your head]")
	checkpoint()


func _on_portal_opened() -> void:
	get_node("/root/Subs").cue("[portal home opens]")
	# M3: home is the lair. The run save says where CONTINUE goes; "arrived" makes the night pass
	# (or the raid start) once, when the lair loads.
	leaving = true
	_save.write({"where": "lair", "arrived": true, "level": level, "score": score})
	get_node("/root/Loader").go("res://scenes/game.tscn")


## Map room: a fresh hunt in that realm. The profile goes along; the run starts at full HP.
func start_hunt(realm: String) -> void:
	if realm != "pews" or bool(get_node("/root/Profile").data.raid_pending):
		return
	leaving = true
	_save.write({"where": "pews"})
	get_node("/root/Loader").go("res://scenes/game.tscn")


func _on_ko(_count: int) -> void:
	if where != "training":
		# Vesper's death is his own moment (cue + voice line in pews_arena); no round chime.
		get_node("/root/Audio").sfx("hit_heavy", 0.6)
		UI.buzz(60)
		checkpoint()
		return
	score += 1
	level += 1
	get_node("/root/Audio").sfx("level")
	get_node("/root/Subs").cue("[chime: round %d]" % level)
	UI.buzz(40)
	checkpoint()


func _on_hero_died() -> void:
	if where == "lair" and bool(arena.get("raid_active")):
		# BUILD_SPEC: losing a raid costs stored parts, not the save. The hero gets back up.
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(arena) and bool(arena.get("raid_active")):
				arena.call("raid_failed"))
		return
	dying = true                     # from this moment nothing saves, and the run is over
	_save.clear()
	if where == "pews":
		# A real failed hunt (BUILD_SPEC Furfur: VENT unlocks one combo per real failure, M4).
		var prof := get_node("/root/Profile")
		prof.data.failures_unvented = int(prof.data.failures_unvented) + 1
		prof.save()
	get_tree().create_timer(1.2).timeout.connect(func():
		if not over:
			game_over())


## SKIP LEVEL in the dev menu: the next round in training, Vesper down in the Pews, raid won in the lair.
func debug_skip_level() -> void:
	if where == "pews" and arena.has_method("debug_defeat"):
		arena.call("debug_defeat")
	elif where == "lair" and bool(arena.get("raid_active")):
		arena.call("_end_raid", true)
	elif where == "training":
		_on_ko(score + 1)


# ---------------------------------------------------------------- the lair (M3)

func _enter_lair() -> void:
	var prof := get_node("/root/Profile")
	var lair := GameData.load_json("lair")
	var perk := LairRules.perks(prof.data, GameData.load_json("trophies"))
	if arrived:
		arrived = false
		var r := LairRules.arrive_home(prof.data, lair, perk)
		checkpoint()             # run save first: a kill between the two loses a night, never doubles one
		prof.save()
		if not r.raid:
			get_node("/root/Subs").cue("[a night in the lair: heat -%d]" % int(r.heat_drop))
	arena.call("refresh")
	if bool(prof.data.raid_pending):
		_raid_warning()
	else:
		speak("lair")


func _raid_warning() -> void:
	var sh := UI.sheet(self)
	sh.get_meta("sheet").name = "RaidWarning"
	sh.add_child(UI.label("LAIR RAID", 34, UI.key("bad")))
	sh.add_child(UI.label("Your heat led them home. Hold the lair: set traps fire on their own.", 18))
	sh.add_child(UI.button("FIGHT", func():
		UI.close_sheet(sh)
		arena.call("start_raid"), 88))


func _on_raid_finished(won: bool, result: Dictionary) -> void:
	checkpoint()
	var sh := UI.sheet(self)
	sh.get_meta("sheet").name = "RaidResult"
	sh.add_child(UI.label("THE LAIR HOLDS" if won else "THEY RANSACKED THE COLD ROOM", 28, UI.key("good") if won else UI.key("bad")))
	sh.add_child(UI.label("Heat falls. A night passes." if won else "You lost %d parts. The save is safe." % int(result.get("parts_lost", 0)), 18))
	sh.add_child(UI.button("CLOSE", func(): UI.close_sheet(sh), 88))
	if won:
		speak("kill")


func _on_station(id: String) -> void:
	LairSheets.open(self, id)


## A crafted poultice: +heal HP, never past max.
func heal() -> void:
	var prof := get_node("/root/Profile")
	var r: Dictionary = LairRules.recipe(GameData.load_json("recipes"), "wax_poultice")
	if not arena.has_method("heal") or arena.hero.dead or arena.hp >= arena.max_hp \
			or not LairRules.take_item(prof.data, "wax_poultice"):
		return
	var got: int = arena.call("heal", int(r.get("heal", 30)))
	prof.save()
	get_node("/root/Subs").cue("[poultice: +%d HP]" % got)
	checkpoint()
	_refresh_hud()


## An equipped voice says a line for this moment (fight, low_hp, combo, kill, lair) in the box at
## the top. Slot 1 speaks first. Nothing when no voice is equipped.
func speak(kind: String) -> void:
	var prof := get_node("/root/Profile")
	for id in prof.data.equipped:
		if str(id).is_empty():
			continue
		var lines: Array = GameData.load_json("voices/" + str(id)).get("lines", {}).get(kind, [])
		if lines.is_empty():
			continue
		var old := get_node_or_null("VoiceBox")
		if old != null:
			old.free()
		var box := VoiceBox.make(str(id), str(lines[randi() % lines.size()]))
		box.set_meta("kind", kind)
		add_child(box)
		last_voice_kind = kind
		return


var last_voice_kind := ""     # read by autoplay (VOICE LINE PASS)


# ---------------------------------------------------------------- pause + game over

func pause() -> void:
	if paused or over:
		return
	paused = true
	arena.process_mode = Node.PROCESS_MODE_DISABLED     # the fight freezes under the menu
	checkpoint()
	get_node("/root/Subs").clear()
	sheet_box = UI.sheet(self)
	sheet_box.add_child(UI.label("PAUSED", 30, UI.ACCENT))
	sheet_box.add_child(UI.button("RESUME", resume, 88))
	sheet_box.add_child(UI.button("SETTINGS", func(): SettingsSheet.open(self)))
	sheet_box.add_child(UI.button("REPORT A BUG", func(): BugReport.open(self)))
	sheet_box.add_child(UI.button("QUIT TO TITLE", quit_to_title))


func resume() -> void:
	UI.close_sheet(sheet_box)
	sheet_box = null
	paused = false
	arena.process_mode = Node.PROCESS_MODE_INHERIT


func quit_to_title() -> void:
	save_for_quit()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


## What QUIT TO TITLE saves (a rule test calls this): nothing once the hero is down.
func save_for_quit() -> void:
	checkpoint()


func game_over() -> void:
	over = true
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	_save.clear()
	get_node("/root/Audio").sfx("gameover")
	get_node("/root/Subs").cue("[game over sting]")
	sheet_box = UI.sheet(self)
	sheet_box.add_child(UI.label("GAME OVER", 40, UI.key("bad")))
	if where == "pews":
		# Training-arena wording ("Round 1, 0 knockouts") left over in the church (M2 review).
		var phase := int(arena.get("rules").boss_phase) if arena.get("rules") != null else 1
		sheet_box.add_child(UI.label("You fell in The Pews. Vesper, phase %d." % phase, 22))
		sheet_box.add_child(UI.label("What you earned is still yours.", 18, UI.DIM))
	else:
		sheet_box.add_child(UI.label("Round %d, %d knockouts" % [level, score], 24))
	sheet_box.add_child(UI.button("TRY AGAIN", func(): get_tree().reload_current_scene(), 88))
	sheet_box.add_child(UI.button("TITLE", quit_to_title))


func _notification(what: int) -> void:
	match what:
		# The phone took the app away (call, home button, notification shade): pause + save.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause.call_deferred()
		# Android back / back gesture: close the top sheet, else pause. Never quits.
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back.call_deferred()


func _go_back() -> void:
	var sheets := get_tree().get_nodes_in_group("sheet")
	var base_sheet: Node = sheet_box.get_meta("sheet") if is_instance_valid(sheet_box) else null
	if not sheets.is_empty() and sheets[-1].name == "RaidWarning":
		# Back can't dodge a raid (fresh-eyes on PR #23): it means FIGHT.
		sheets[-1].queue_free()
		arena.call("start_raid")
	elif not sheets.is_empty() and sheets[-1] != base_sheet:
		sheets[-1].queue_free()
	elif paused and not over:
		resume()
	else:
		pause()

extends Control
## The game screen. Placeholder game "Orb Catch" shows every foundation piece working; swap
## the PLAY section for the real game and keep the rest.
##   Tap green orbs (+1). Don't tap red spiky ones (-1 life). A green orb that falls = -1 life.
##   10 points = next level = checkpoint (autosave). 0 lives = GAME OVER.
## Foundation pieces here: PAUSE button, Android back = pause, auto-pause + save when the app
## goes to the background (call, home button), pause menu (resume / settings / bug / quit),
## GAME OVER -> try again / title, checkpoint autosave + CONTINUE, left-handed layout, low
## graphics, colorblind-safe colours with shape cues, subtitles for sound cues, vibration.

const UI = preload("res://scripts/ui.gd")
const SettingsSheet = preload("res://scripts/settings_sheet.gd")
const BugReport = preload("res://scripts/bug_report.gd")
const ControlsLegend = preload("res://scripts/controls_legend.gd")

const LIVES := 3
const PER_LEVEL := 10
const ORB_R := 40.0          # tap target radius in base units (80 wide, above the 72 rule)

var level := 1
var score := 0
var lives := LIVES
var orbs: Array = []         # {pos, vel, bad}
var spawn_t := 0.0
var slow_left := 0.0
var slow_used := false
var paused := false
var over := false
var rng := RandomNumberGenerator.new()

var hud: Label
var pause_btn: Button
var slow_btn: Button
var field: Control
var sheet_box: VBoxContainer
var _settings: Node
var _save: Node


func _ready() -> void:
	_settings = get_node("/root/Settings")
	_save = get_node("/root/Save")
	_settings.changed.connect(_on_setting)
	rng.randomize()
	var d: Dictionary = _save.read()
	if not d.is_empty():
		level = int(d.get("level", 1))
		score = int(d.get("score", 0))
		lives = int(d.get("lives", LIVES))
	_build()
	checkpoint()
	get_node("/root/Audio").music("music_loop")


# ---------------------------------------------------------------- state + saving

func state() -> Dictionary:
	return {"level": level, "score": score, "lives": lives}


func checkpoint() -> void:
	_save.write(state())


func bug_state() -> String:
	return "level %d score %d lives %d orbs %d paused %s over %s" % [level, score, lives, orbs.size(), paused, over]


# ---------------------------------------------------------------- layout

func _on_setting(key: String) -> void:
	if key in ["text_size", "high_contrast", "left_handed"]:
		_build()


func _build() -> void:
	for c in get_children():
		if not c.is_in_group("sheet"):
			c.queue_free()
	theme = UI.theme()
	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	var f := field
	field.draw.connect(func(): _draw_field(f))
	field.gui_input.connect(_field_input)
	add_child(field)
	move_child(field, 0)
	hud = UI.label("", 24)
	hud.anchor_right = 1.0
	hud.offset_left = 190      # clear of the PAUSE button on either side
	hud.offset_right = -190
	hud.offset_top = 30
	hud.offset_bottom = 30 + UI.MIN_TOUCH
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var legend := ControlsLegend.make(["pause"])
	legend.name = "Legend"
	legend.top = 30 + UI.MIN_TOUCH + 12
	add_child(legend)
	# Thumb buttons: PAUSE top corner, SLOW bottom corner, both on the thumb's side.
	var left: bool = _settings.get_value("left_handed")
	pause_btn = UI.button("PAUSE", pause)
	_corner(pause_btn, left, true, 150)
	slow_btn = UI.button("SLOW", _slow, 96)
	_corner(slow_btn, not left, false, 170)
	for sh in get_tree().get_nodes_in_group("sheet"):   # open sheets stay on top of the rebuilt HUD
		if sh.get_parent() == self:
			move_child(sh, -1)
	_refresh_hud()


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


func _refresh_hud() -> void:
	if hud == null:
		return
	var god := " GOD" if get_node("/root/DebugMenu").god_mode else ""
	hud.text = "LV %d  %d pts\nLIVES %d%s" % [level, score, lives, god]
	slow_btn.disabled = slow_used


# ---------------------------------------------------------------- PLAY (replace this part)

func _process(dt: float) -> void:
	if paused or over:
		return
	var k := 0.4 if slow_left > 0.0 else 1.0
	slow_left = maxf(0.0, slow_left - dt)
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = maxf(0.35, 1.1 - 0.08 * level)
		var w := field.size.x
		orbs.append({"pos": Vector2(rng.randf_range(ORB_R + 10, w - ORB_R - 10), -ORB_R),
			"vel": rng.randf_range(160, 220) + 25 * level, "bad": rng.randf() < 0.3, "t": 0.0})
	var bottom := field.size.y - 150
	for o in orbs.duplicate():
		o.pos.y += o.vel * dt * k
		o.t += dt
		if o.pos.y > bottom:
			orbs.erase(o)
			if not o.bad:
				_lose_life("missed")
	field.queue_redraw()


func _field_input(e: InputEvent) -> void:
	if paused or over:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tap(e.position)


## A tap at a point on the field (also used by the autoplay bot).
func tap(p: Vector2) -> void:
	for o in orbs:
		if o.pos.distance_to(p) <= ORB_R:
			orbs.erase(o)
			if o.bad:
				_lose_life("tapped a bad orb")
			else:
				score += 1
				get_node("/root/Audio").sfx("good", 1.0 + 0.02 * (score % PER_LEVEL))
				UI.buzz(15)
				if score % PER_LEVEL == 0:
					_level_up()
			_refresh_hud()
			field.queue_redraw()
			return


func _lose_life(why: String) -> void:
	if get_node("/root/DebugMenu").god_mode:
		return
	lives -= 1
	get_node("/root/Audio").sfx("bad")
	get_node("/root/Subs").cue("[buzz: %s]" % why)
	UI.buzz(80)
	_refresh_hud()
	if lives <= 0:
		game_over()


func _level_up() -> void:
	level += 1
	slow_used = false
	orbs.clear()
	get_node("/root/Audio").sfx("level")
	get_node("/root/Subs").cue("[chime: level %d]" % level)
	checkpoint()
	_refresh_hud()


func debug_skip_level() -> void:
	score += PER_LEVEL - score % PER_LEVEL
	_level_up()


func _slow() -> void:
	if slow_used or paused or over:
		return
	slow_used = true
	slow_left = 3.0
	_refresh_hud()


func _draw_field(f: Control) -> void:
	f.draw_rect(Rect2(Vector2.ZERO, f.size), UI.BG)
	var bottom := f.size.y - 150
	f.draw_line(Vector2(0, bottom), Vector2(f.size.x, bottom), UI.DIM, 2.0)
	var low: bool = _settings.get_value("low_graphics")
	for o in orbs:
		var c := UI.key("bad" if o.bad else "good")
		if not low:   # the "fancy" part low graphics turns off: a soft glow
			f.draw_circle(o.pos, ORB_R * 1.25, Color(c, 0.18))
		if o.bad:
			# Shape cue, not only colour: a spiky star with an X.
			var pts := PackedVector2Array()
			for i in 16:
				var a: float = TAU * i / 16.0 + o.t
				pts.append(o.pos + Vector2.from_angle(a) * (ORB_R if i % 2 == 0 else ORB_R * 0.6))
			f.draw_colored_polygon(pts, c)
			var d := ORB_R * 0.35
			f.draw_line(o.pos - Vector2(d, d), o.pos + Vector2(d, d), Color.BLACK, 5.0)
			f.draw_line(o.pos + Vector2(-d, d), o.pos + Vector2(d, -d), Color.BLACK, 5.0)
		else:
			f.draw_circle(o.pos, ORB_R, c)
			f.draw_circle(o.pos, ORB_R * 0.35, Color(1, 1, 1, 0.6))


# ---------------------------------------------------------------- pause + game over

func pause() -> void:
	if paused or over:
		return
	paused = true
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


func quit_to_title() -> void:
	if not over:
		checkpoint()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func game_over() -> void:
	over = true
	orbs.clear()
	_save.clear()
	get_node("/root/Audio").sfx("gameover")
	get_node("/root/Subs").cue("[game over sting]")
	sheet_box = UI.sheet(self)
	sheet_box.add_child(UI.label("GAME OVER", 40, UI.key("bad")))
	sheet_box.add_child(UI.label("Level %d, %d points" % [level, score], 24))
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
	if sheets.size() > 1:
		sheets[-1].queue_free()
	elif paused and not over:
		resume()
	else:
		pause()

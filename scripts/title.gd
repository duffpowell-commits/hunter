extends Control
## Title: CONTINUE (when a run is saved), NEW GAME, SETTINGS, REPORT A BUG, version number.
## Tap the version number 5 times for the dev menu (dev builds only).

const UI = preload("res://scripts/ui.gd")
const Config = preload("res://scripts/config.gd")
const SettingsSheet = preload("res://scripts/settings_sheet.gd")
const BugReport = preload("res://scripts/bug_report.gd")

var _ver_taps := 0


func _ready() -> void:
	get_node("/root/Settings").changed.connect(_on_setting)
	get_node("/root/Audio").music("music_loop")
	_build()


func _on_setting(key: String) -> void:
	if key in ["text_size", "high_contrast"]:
		_build()


func _build() -> void:
	for c in get_children():
		if not c.is_in_group("sheet"):
			c.queue_free()
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	# Nov 26 (8.5 pass, item 7): a key image instead of a bare menu. Brother Vesper, the first
	# hunt, looms behind the title (docs/art/explore-20261120/vesper-ink-0.png, green keyed out).
	var key := TextureRect.new()
	key.name = "KeyArt"
	key.texture = load("res://assets/art/title_vesper.png")
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.anchor_right = 1.0
	key.anchor_bottom = 0.66
	key.offset_top = 10
	key.modulate = Color(1, 1, 1, 0.5)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key)
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(UI.BG, 0.0))
	grad.gradient.set_color(1, Color(UI.BG, 1.0))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	var fade := TextureRect.new()
	fade.texture = grad
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.anchor_right = 1.0
	fade.anchor_top = 0.3
	fade.anchor_bottom = 0.66
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var col := VBoxContainer.new()
	# Bottom-anchored, growing up: the menu always fits under the art, whatever the text size.
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_bottom = -76
	col.custom_minimum_size = Vector2(440, 0)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", UI.GAP)
	add_child(col)
	# Why 32 (Nov 23): the longer title "THE DEVIL YOU OWE" needs margin on the 540-wide UI canvas.
	var title := UI.label(Config.game_title().to_upper(), 36, UI.ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 12)
	col.add_child(title)
	col.add_child(UI.label("You owe the Devil. Collect for him.", 17, UI.DIM))
	col.add_child(Control.new())
	var save: Node = get_node("/root/Save")
	if save.exists():
		var d: Dictionary = save.read()
		# M3: the run save says where you are (Save v4 "where").
		var at := "THE LAIR" if str(d.get("where", "pews")) == "lair" else "THE PEWS"
		col.add_child(UI.button("CONTINUE  (%s)" % at, func(): _play(true), 88))
	col.add_child(UI.button("NEW GAME", func(): _play(false), 88 if not save.exists() else UI.MIN_TOUCH))
	col.add_child(UI.button("SETTINGS", func(): SettingsSheet.open(self)))
	col.add_child(UI.button("REPORT A BUG", func(): BugReport.open(self)))
	var ver := UI.label(Config.version_label(), 18, UI.DIM)
	ver.name = "Version"
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.anchor_right = 1.0
	ver.offset_top = -64
	ver.offset_bottom = -16
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_ver_taps += 1
			if _ver_taps >= 5:
				_ver_taps = 0
				get_node("/root/DebugMenu").open())
	add_child(ver)
	for sh in get_tree().get_nodes_in_group("sheet"):
		if sh.get_parent() == self:
			move_child(sh, -1)


func _play(resume: bool) -> void:
	if not resume:
		get_node("/root/Save").clear()
	get_node("/root/Loader").go("res://scenes/game.tscn")


func _notification(what: int) -> void:
	# Android back on the title closes the top sheet; it never quits by accident.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var sheets := get_tree().get_nodes_in_group("sheet")
		if sheets.size() > 0:
			sheets[-1].queue_free()


func bug_state() -> String:
	return "title, save=%s" % get_node("/root/Save").exists()

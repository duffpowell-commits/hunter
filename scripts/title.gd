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
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.custom_minimum_size = Vector2(380, 0)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", UI.GAP)
	add_child(col)
	# Why to_upper (Hunter, Nov 21): docs/BUILD_SPEC.md M0 says the title shows "HUNTER" while
	# config/name stays "Hunter" (that name also goes on the APK and in bug reports).
	col.add_child(UI.label(Config.game_title().to_upper(), 44, UI.ACCENT))
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

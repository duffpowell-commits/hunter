extends PanelContainer
## Hunter M3 (Nov 23): the voice dialogue box (BUILD_SPEC Voices): top of the screen, portrait,
## name, line; it goes after voice_box.secs (data/lair.json, 3 s) or on a tap. The line also goes
## through Subs (spoken line), so the Subtitles setting and its log see it.
## Portrait: a coloured disc with the voice's initial until Duff approves portrait art.

const UI = preload("res://scripts/ui.gd")
const GameData = preload("res://scripts/game_data.gd")

var voice_id := ""
var line := ""
var _left := 0.0


static func make(id: String, text: String) -> PanelContainer:
	var box: PanelContainer = load("res://scripts/voice_box.gd").new()
	box.voice_id = id
	box.line = text
	return box


func _ready() -> void:
	name = "VoiceBox"
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	offset_left = 16
	offset_right = -16
	offset_top = 168
	mouse_filter = Control.MOUSE_FILTER_STOP
	var voice := GameData.load_json("voices/" + voice_id)
	var colour := Color(str(voice.get("color", "8b718f")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.9)
	sb.border_color = colour
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var portrait := PanelContainer.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(64, 64)
	var ps := StyleBoxFlat.new()
	ps.bg_color = colour
	ps.set_corner_radius_all(32)
	portrait.add_theme_stylebox_override("panel", ps)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := UI.label(str(voice.get("name", "?")).split(" ")[-1].left(1), 30, Color.BLACK)
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(initial)
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var who := UI.label(str(voice.get("name", "")), 16, colour)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(who)
	var said := UI.label(line, 18)
	said.name = "Line"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(said)
	_left = float(GameData.load_json("lair").get("voice_box", {}).get("secs", 3.0))
	var subs := get_node_or_null("/root/Subs")
	if subs != null:
		subs.say("%s: %s" % [str(voice.get("name", "")).capitalize(), line])


func _process(dt: float) -> void:
	_left -= dt
	if _left <= 0.0:
		queue_free()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		accept_event()
		queue_free()

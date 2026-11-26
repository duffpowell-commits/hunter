extends PanelContainer
## One-line explainers (Nov 26, 8.5 pass, item 6). The blind first-timer saw HEAT, PARTS, CORR,
## STUDY and the weapon count change and never learned what they meant. The first time each one
## changes, a single line slides in under the HUD for a few seconds, once ever
## (user://explain.cfg). game.gd calls watch(values) every frame with what the HUD shows.

const UI = preload("res://scripts/ui.gd")
const PATH := "user://explain.cfg"
const SHOW_FOR := 5.0
const LINES := {
	"cash": "$ CASH: pay for crafting and Furfur's mercies.",
	"heat": "HEAT: bodies and stolen plates raise it. At 70, demons raid your lair.",
	"parts": "PARTS: scavenged scrap. Craft with them at the workshop.",
	"corruption": "CORR: the demon in you. Brutal kills and eating bosses raise it.",
	"study": "STUDY: watch Vesper unseen. 100% opens an ambush.",
	"wear": "WEAPON: each hit wears it. At 0 the next hit breaks it for big damage.",
}

var _last := {}
var _left := 0.0
var _label: Label
var queue: Array[String] = []
var shown: Array[String] = []          # ids explained this session (autoplay reads it)


static func seen(id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("seen", id, false)


static func forget_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _ready() -> void:
	name = "Explainer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.04
	anchor_right = 0.96
	offset_top = 262
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.88)
	sb.border_color = UI.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	_label = UI.label("", 17)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	visible = false


## values: id -> number (or anything comparable). A change from the first value seen counts.
func watch(values: Dictionary) -> void:
	for id in values:
		var v: Variant = values[id]
		if not _last.has(id):
			_last[id] = v
			continue
		if v != _last[id]:
			_last[id] = v
			if not seen(id) and not queue.has(id) and LINES.has(id):
				queue.append(id)


func _process(dt: float) -> void:
	if _left > 0.0:
		_left -= dt
		if _left <= 0.0:
			visible = false
		return
	if queue.is_empty():
		return
	var id: String = queue.pop_front()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("seen", id, true)
	cfg.save(PATH)
	shown.append(id)
	_label.text = LINES[id]
	visible = true
	_left = SHOW_FOR

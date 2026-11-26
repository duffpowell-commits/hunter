extends Control
## Floating virtual stick for the left thumb (docs/BUILD_SPEC.md Controls): touch anywhere in
## this half, drag; `vec` is the stick (length 0..1, y down = toward the camera, like a pad).
## Touch: follows its own finger so it works together with the swipe pad. Mouse: desktop and
## the autoplay bot, only when there's no touchscreen.
## Why (Hunter M1, Nov 21): the starter's 3D test has a stick inside its scene; Hunter needs it
## as a reusable piece for every realm.

const UI = preload("res://scripts/ui.gd")
const RADIUS := 90.0

var vec := Vector2.ZERO
var _finger := -1
var _origin := Vector2.ZERO


## The stick value for a finger at `p` that went down at `origin`.
static func stick_vector(origin: Vector2, p: Vector2, radius: float = RADIUS) -> Vector2:
	return ((p - origin) / radius).limit_length(1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	var touch := DisplayServer.is_touchscreen_available()
	if e is InputEventScreenTouch:
		if e.pressed and _finger == -1:
			_finger = e.index
			_origin = e.position
			vec = Vector2.ZERO
		elif not e.pressed and e.index == _finger:
			_release()
	elif e is InputEventScreenDrag and e.index == _finger:
		vec = stick_vector(_origin, e.position)
	elif not touch and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_finger = -2
			_origin = e.position
			vec = Vector2.ZERO
		elif _finger == -2:
			_release()
	elif not touch and e is InputEventMouseMotion and _finger == -2:
		vec = stick_vector(_origin, e.position)
	queue_redraw()


func _release() -> void:
	_finger = -1
	vec = Vector2.ZERO
	queue_redraw()


func held() -> bool:
	return _finger != -1


func _draw() -> void:
	if _finger == -1:
		# Nov 26 (8.5 pass): an idle hint so a first-timer sees where to move (it was blank).
		var c := size * Vector2(0.5, 0.62)
		draw_arc(c, 60, 0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)
		draw_circle(c, 24, Color(1, 1, 1, 0.18))
		draw_string(ThemeDB.fallback_font, c + Vector2(-60, 92), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color(1, 1, 1, 0.55))
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
	draw_circle(_origin + vec * RADIUS, 36, Color(UI.ACCENT, 0.7))

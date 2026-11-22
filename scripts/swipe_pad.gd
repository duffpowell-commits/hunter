extends Control
## The right-thumb action pad (docs/BUILD_SPEC.md Controls). Gestures, no buttons:
##   tap = light, hold >= hold_time then release = heavy, swipe = special, double-tap = dodge.
## Emits `gesture(kind, swipe)`; kind is "light", "heavy", "swipe" or "dodge"; swipe is the
## drag vector in canvas units (for "swipe"). Touch: tracks its own finger, so the stick and the
## pad work at the same time. Mouse (desktop, the autoplay bot): only when there's no touchscreen.
## Why (Hunter M1, Nov 21): one thumb plays the whole moveset; gestures are pure logic in
## classify() so tests check them without a screen.

signal gesture(kind: String, swipe: Vector2)

var hold_time := 0.3
var double_tap := 0.25
var swipe_min := 60.0
var _finger := -1               # touch index we follow (-2 = mouse)
var _start := Vector2.ZERO
var _now := Vector2.ZERO
var _t0 := 0
var _last_tap := -100000


## What a finished touch was. duration and since_last_tap in seconds, delta in canvas units.
static func classify(duration: float, delta: Vector2, since_last_tap: float,
		hold: float = 0.3, dbl: float = 0.25, swipe: float = 60.0) -> String:
	if delta.length() >= swipe:
		return "swipe"
	if duration >= hold:
		return "heavy"
	if since_last_tap <= dbl:
		return "dodge"
	return "light"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	var touch := DisplayServer.is_touchscreen_available()
	if e is InputEventScreenTouch:
		if e.pressed and _finger == -1:
			_down(e.index, e.position)
		elif not e.pressed and e.index == _finger:
			_up(e.position)
	elif e is InputEventScreenDrag and e.index == _finger:
		_now = e.position
	elif not touch and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and _finger == -1:
			_down(-2, e.position)
		elif not e.pressed and _finger == -2:
			_up(e.position)
	elif not touch and e is InputEventMouseMotion and _finger == -2:
		_now = e.position


func _down(idx: int, p: Vector2) -> void:
	_finger = idx
	_start = p
	_now = p
	_t0 = Time.get_ticks_msec()


func _up(p: Vector2) -> void:
	_finger = -1
	var now := Time.get_ticks_msec()
	var kind := classify((now - _t0) / 1000.0, p - _start, (now - _last_tap) / 1000.0, hold_time, double_tap, swipe_min)
	if kind == "light":
		_last_tap = now
	elif kind == "dodge":
		_last_tap = -100000         # a third tap starts fresh
	gesture.emit(kind, p - _start)
	queue_redraw()


func _process(_dt: float) -> void:
	if _finger != -1:
		queue_redraw()


func _draw() -> void:
	# A faint home for the thumb, and a ring that fills while a heavy charges.
	var c := size * Vector2(0.5, 0.62)
	draw_arc(c, 70, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0)
	if _finger != -1:
		var held := (Time.get_ticks_msec() - _t0) / 1000.0
		draw_arc(_start, 50, -PI / 2, -PI / 2 + TAU * clampf(held / hold_time, 0.0, 1.0), 40, Color(1, 1, 1, 0.5), 6.0)
		draw_line(_start, _now, Color(1, 1, 1, 0.35), 4.0)

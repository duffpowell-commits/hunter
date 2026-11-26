extends Node
## The guided first hunt (Nov 26, 8.5 pass, item 1). The blind first-timer got no controls and no
## goal (s08). This runs Coach prompts one at a time in the Pews, each gone once you do it:
##   move -> sneak (light tilt) -> attack (tap) -> heavy (hold) -> dodge (double tap) -> special (swipe)
## The fight prompts wait until there's someone to hit (the fight started or a minion is close).
## Each prompt is learned once, ever (user://coach.cfg), so a second hunt shows none of them.
## game.gd adds it in the Pews and calls saw(kind) for every pad gesture.

const Coach = preload("res://scripts/coach.gd")

## [id, text (4 words max), needs a target]
const STEPS := [
	["hunt_move", "DRAG {stick} TO MOVE", false],
	["hunt_sneak", "TILT LIGHTLY TO SNEAK", false],
	["hunt_light", "TAP {pad} TO ATTACK", true],
	["hunt_heavy", "HOLD FOR HEAVY", true],
	["hunt_dodge", "DOUBLE-TAP TO DODGE", true],
	["hunt_special", "SWIPE FOR SPECIAL", true],
]

var arena: Node
var left_handed := false
var ui_parent: Control
var seen_kinds := {}
var _current: Label
var _step := -1
var _sneak_t := 0.0
var _learned := {}                    # cache of coach.cfg, so no disk read every frame


func _ready() -> void:
	for st in STEPS:
		if Coach.seen(st[0]):
			_learned[st[0]] = true


static func all_learned() -> bool:
	for s in STEPS:
		if not Coach.seen(s[0]):
			return false
	return true


func saw(kind: String) -> void:
	seen_kinds[kind] = true


## The step on screen now ("" when none).
func current_id() -> String:
	return STEPS[_step][0] if _step >= 0 and _step < STEPS.size() and is_instance_valid(_current) else ""


func _check(id: String) -> bool:
	match id:
		"hunt_move":
			return arena.hero.speed() > 1.0
		"hunt_sneak":
			return _sneak_t > 0.6
		"hunt_light":
			return seen_kinds.has("light")
		"hunt_heavy":
			return seen_kinds.has("heavy")
		"hunt_dodge":
			return seen_kinds.has("dodge")
		"hunt_special":
			return seen_kinds.has("swipe")
	return true


func _has_target() -> bool:
	if bool(arena.get("encounter_started")):
		return true
	for foe in arena._foes:
		if not foe.dead and arena.hero.global_position.distance_to(foe.actor.global_position) < 4.5:
			return true
	return false


func _process(dt: float) -> void:
	if arena == null or not is_instance_valid(arena) or ui_parent == null:
		return
	_sneak_t = _sneak_t + dt if arena.hero.crouching and arena.hero.speed() > 0.2 else 0.0
	if is_instance_valid(_current):
		return
	# The first step not yet learned. Starting from 0 (not _step + 1) means a prompt freed by a
	# HUD rebuild (text size, contrast, left-handed) comes back instead of being skipped.
	var next := 0
	while next < STEPS.size() and _learned.has(STEPS[next][0]):
		next += 1
	if next >= STEPS.size():
		set_process(false)
		return
	var step: Array = STEPS[next]
	if bool(step[2]) and not _has_target():
		return
	# Sneaking only makes sense before he's seen you; skip it once the fight is on.
	if step[0] == "hunt_sneak" and bool(arena.get("encounter_started")):
		_learn(step[0])
		return
	if next != _step:
		seen_kinds.clear()
	_step = next
	var id: String = step[0]
	var lh := left_handed
	var st := get_node_or_null("/root/Settings")
	if st != null:
		lh = bool(st.get_value("left_handed"))     # read live: the player may flip it mid-hunt
	var text: String = str(step[1]).replace("{stick}", "RIGHT" if lh else "LEFT").replace("{pad}", "LEFT" if lh else "RIGHT")
	_current = Coach.teach(ui_parent, id, text, func():
		var done := _check(id)
		if done:
			_learned[id] = true
		return done)
	if _current != null:              # above the hero, not across him
		_current.anchor_top = 0.3
		_current.anchor_bottom = 0.3
	else:
		_learned[id] = true


func _learn(id: String) -> void:
	_learned[id] = true
	var cfg := ConfigFile.new()
	cfg.load(Coach.PATH)
	cfg.set_value("seen", id, true)
	cfg.save(Coach.PATH)

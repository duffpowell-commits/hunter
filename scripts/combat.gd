extends RefCounted
## Hunter's combat rules with no nodes in them, so tests can call them directly (docs/BUILD_SPEC.md
## Controls + Improvised weapons). arena.gd plays the animations and hits; this decides the numbers.
##   light()        next hit of the L, L, L string (the third knocks back)
##   heavy()        hold-and-release guard break
##   special(dir)   swipe "up" / "down" / "toward" / "away"; within cancel_window of a landed
##                  light/heavy hit it cancels into it for +cancel_bonus damage
##   land(move)     the move connected: counts the combo, spends weapon durability, returns damage
## Every number comes from data/moves.json and data/weapons.json.
## Why (Hunter M1, Nov 21): rules in one testable place; the scene only reads what it returns.

var moves: Dictionary
var weapons: Dictionary
var combo := 0                  # landed hits in a row (the on-screen counter)
var combo_gap := 1.2            # a hit within this many seconds keeps the combo alive
var cancel_window := 0.35
var cancel_bonus := 0.25
var string_gap := 0.8           # taps further apart restart the L, L, L string
var weapon := ""                # "" = unarmed
var durability := 0
var cooldowns := {}             # special id -> seconds left
var _combo_t := 0.0
var _string_i := 0
var _string_t := 0.0
var _since_hit := INF           # since the last landed light/heavy (cancel window)


func _init(moves_data: Dictionary, weapons_data: Dictionary) -> void:
	moves = moves_data
	weapons = weapons_data
	var c: Dictionary = moves.get("combo", {})
	combo_gap = float(c.get("gap", combo_gap))
	cancel_window = float(c.get("cancel_window", cancel_window))
	cancel_bonus = float(c.get("cancel_bonus", cancel_bonus))
	string_gap = float(c.get("string_gap", string_gap))


func tick(dt: float) -> void:
	_since_hit += dt
	_string_t -= dt
	if combo > 0:
		_combo_t -= dt
		if _combo_t <= 0.0:
			combo = 0
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - dt)


func light() -> Dictionary:
	var list: Array = moves.light
	if _string_t <= 0.0:
		_string_i = 0
	var m: Dictionary = list[_string_i % list.size()].duplicate()
	m["kind"] = "light"
	m["index"] = _string_i % list.size()
	if weapon != "" and m.has("armed_action"):
		m["action"] = m.armed_action
	_string_i += 1
	_string_t = string_gap
	return m


func heavy() -> Dictionary:
	var m: Dictionary = moves.heavy.duplicate()
	m["kind"] = "heavy"
	_string_i = 0
	return m


## {} when that special is still cooling down.
func special(dir: String) -> Dictionary:
	if not moves.specials.has(dir):
		return {}
	var m: Dictionary = moves.specials[dir].duplicate()
	if cooldowns.get(m.id, 0.0) > 0.0:
		return {}
	m["kind"] = "special"
	m["dir"] = dir
	m["cancel"] = _since_hit <= cancel_window
	if m.cancel:
		m["damage"] = float(m.damage) * (1.0 + cancel_bonus)
	cooldowns[m.id] = float(m.get("cooldown", 1.0))
	_string_i = 0
	return m


## How far the move reaches, with the weapon's extra length.
func reach(m: Dictionary) -> float:
	var r := float(m.get("reach", 1.5))
	if weapon != "":
		r += float(weapons[weapon].get("reach_bonus", 0.0))
	return r


## The move hit. Returns {"damage", "power", "broke"}.
func land(m: Dictionary) -> Dictionary:
	var dmg := float(m.get("damage", 0))
	var power := float(m.get("power", 0.3))
	var broke := false
	if weapon != "":
		var w: Dictionary = weapons[weapon]
		if durability <= 0:
			# Spent weapon: this hit snaps it, a combo ender (x2.5 and a big knockback).
			broke = true
			dmg = (dmg + float(w.get("damage_bonus", 0))) * float(w.get("break_mult", 2.5))
			power = maxf(power, float(w.get("break_power", 1.0)))
			weapon = ""
		else:
			durability -= 1
			dmg += float(w.get("damage_bonus", 0))
	combo += 1
	_combo_t = combo_gap
	if m.get("kind", "") in ["light", "heavy"]:
		_since_hit = 0.0
	return {"damage": dmg, "power": power, "broke": broke}


## The hero got hit: the combo is gone.
func drop_combo() -> void:
	combo = 0
	_string_i = 0


func pick_up(id: String) -> bool:
	if not weapons.has(id):
		return false
	weapon = id
	durability = int(weapons[id].get("durability", 4))
	return true


## Which special a swipe means. `swipe` and `to_target` are screen vectors (y down). Toward/away
## win when the swipe is within 45 degrees of the target's direction; otherwise up or down.
static func swipe_dir(swipe: Vector2, to_target: Vector2) -> String:
	if to_target.length() > 0.001:
		var a := absf(swipe.angle_to(to_target))
		if a <= PI / 4.0:
			return "toward"
		if a >= PI * 3.0 / 4.0:
			return "away"
	return "up" if swipe.y < 0.0 else "down"

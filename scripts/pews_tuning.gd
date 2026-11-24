extends Node
## Exposes the Pews rules' live configuration through the shared TUNE panel.

const PATHS := {
	"study_radius": ["stalking", "study_radius"],
	"view_cone_degrees": ["stalking", "view_cone_degrees"],
	"study_per_second": ["stalking", "study_per_second"],
	"sneak_multiplier": ["stalking", "sneak_multiplier"],
	"sneak_stick_max": ["stalking", "sneak_stick_max"],
	"sight_radius": ["stalking", "sight_radius"],
	"zealot_hp": ["minions", "zealot_hp"],
	"zealot_damage": ["minions", "zealot_damage"],
	"choir_hp": ["minions", "choir_hp"],
	"choir_damage": ["minions", "choir_damage"],
	"choir_bonus_damage": ["minions", "choir_bonus_damage"],
	"choir_buff_radius": ["minions", "choir_buff_radius"],
	"minion_attack_cooldown": ["minions", "attack_cooldown"],
	"minion_attack_windup": ["minions", "attack_windup"],
	# Nov 23 (PR #20 review): these were bare numbers in pews_arena.gd with no slider.
	"minion_first_attack_delay": ["minions", "first_attack_delay"],
	"minion_attack_range": ["minions", "attack_range"],
	"minion_hit_range": ["minions", "hit_range"],
	"minion_chase_min": ["minions", "chase_min"],
	"minion_chase_max": ["minions", "chase_max"],
	"minion_chase_speed": ["minions", "chase_speed"],
	"interact_radius": ["field", "interact_radius"],
	"prefight_target_range": ["field", "prefight_target_range"],
	"boss_first_cooldown": ["boss", "first_cooldown"],
	"boss_min_telegraph": ["boss", "min_telegraph"],
	"sermon_radius": ["boss", "moves", "sermon", "radius"],
	"flock_radius": ["boss", "moves", "flock", "radius"],
	"flock_duration": ["boss", "moves", "flock", "duration"],
	"flock_first_tick": ["boss", "moves", "flock", "first_tick"],
	"flock_tick": ["boss", "moves", "flock", "tick"],
	"sermon_damage": ["boss", "moves", "sermon", "damage"],
	"sermon_telegraph": ["boss", "moves", "sermon", "telegraph"],
	"sermon_cooldown": ["boss", "moves", "sermon", "cooldown"],
	"flock_damage": ["boss", "moves", "flock", "damage"],
	"flock_telegraph": ["boss", "moves", "flock", "telegraph"],
	"flock_cooldown": ["boss", "moves", "flock", "cooldown"],
	"hands_heal": ["boss", "moves", "laying_of_hands", "heal"],
	"hands_telegraph": ["boss", "moves", "laying_of_hands", "telegraph"],
	"hands_cooldown": ["boss", "moves", "laying_of_hands", "cooldown"],
	"phase_one_hp": ["boss", "phase_hp", 0],
	"phase_two_hp": ["boss", "phase_hp", 1],
	# Nov 23 (M3 start, M2 review carry-overs).
	"ambush_range": ["stalking", "ambush_range"],
	"boss_turn_speed": ["boss", "turn_speed"],
	"boss_walk_speed": ["boss", "walk_speed"],
	"boss_keep_distance": ["boss", "keep_distance"],
	"phase2_cooldown_scale": ["boss", "phase2_cooldown_scale"],
	"flock_knockback": ["boss", "moves", "flock", "knockback"],
	"minion_steer_probe": ["minions", "steer_probe"],
	"minion_steer_margin": ["minions", "steer_margin"],
	"eat_corruption": ["voice", "eat_corruption"],
	"heat_per_scavenge": ["heat", "scavenge"],
	"heat_per_body": ["heat", "body"],
	"plate_cash": ["collection_plate", "cash"],
	"plate_heat": ["collection_plate", "heat"],
	"clean_corruption": ["finishers", "clean", "corruption"],
	"clean_parts": ["finishers", "clean", "parts"],
	"brutal_corruption": ["finishers", "brutal", "corruption"],
	"brutal_parts": ["finishers", "brutal", "parts"],
}
const TUNE := {
	"study_radius": [2.0, 12.0], "view_cone_degrees": [20.0, 120.0],
	"study_per_second": [1.0, 25.0], "sneak_multiplier": [1.0, 4.0],
	"sneak_stick_max": [0.15, 0.8], "sight_radius": [1.0, 10.0],
	"zealot_hp": [10.0, 150.0, 1.0], "zealot_damage": [0.0, 35.0, 1.0],
	"choir_hp": [10.0, 150.0, 1.0], "choir_damage": [0.0, 35.0, 1.0],
	"choir_bonus_damage": [0.0, 20.0, 1.0], "choir_buff_radius": [1.0, 10.0],
	"minion_attack_cooldown": [0.5, 8.0], "minion_attack_windup": [0.5, 2.0],
	"sermon_damage": [0.0, 50.0, 1.0], "sermon_telegraph": [0.5, 3.0], "sermon_cooldown": [1.0, 15.0],
	"flock_damage": [0.0, 50.0, 1.0], "flock_telegraph": [0.5, 3.0], "flock_cooldown": [1.0, 15.0],
	"hands_heal": [0.0, 80.0, 1.0], "hands_telegraph": [0.5, 3.0], "hands_cooldown": [1.0, 15.0],
	"phase_one_hp": [20.0, 400.0, 1.0], "phase_two_hp": [20.0, 400.0, 1.0],
	"minion_first_attack_delay": [0.0, 5.0], "minion_attack_range": [0.8, 4.0], "minion_hit_range": [0.8, 4.0],
	"minion_chase_min": [0.5, 3.0], "minion_chase_max": [2.0, 12.0], "minion_chase_speed": [0.1, 1.0],
	"interact_radius": [0.5, 4.0], "prefight_target_range": [1.0, 8.0],
	"boss_first_cooldown": [0.0, 6.0], "boss_min_telegraph": [0.2, 1.5],
	"sermon_radius": [1.0, 10.0], "flock_radius": [1.0, 8.0], "flock_duration": [1.0, 10.0],
	"flock_first_tick": [0.1, 2.0], "flock_tick": [0.3, 3.0],
	"ambush_range": [1.0, 6.0], "boss_turn_speed": [0.0, 8.0], "boss_walk_speed": [0.0, 1.0],
	"boss_keep_distance": [1.0, 6.0], "phase2_cooldown_scale": [0.3, 1.5], "flock_knockback": [0.0, 1.0],
	"minion_steer_probe": [0.3, 2.0], "minion_steer_margin": [0.0, 1.0],
	"eat_corruption": [0.0, 30.0, 1.0], "heat_per_scavenge": [0.0, 20.0, 1.0], "heat_per_body": [0.0, 20.0, 1.0],
	"plate_cash": [0.0, 100.0, 1.0], "plate_heat": [0.0, 40.0, 1.0],
	"clean_corruption": [0.0, 40.0, 1.0], "clean_parts": [0.0, 30.0, 1.0],
	"brutal_corruption": [0.0, 40.0, 1.0], "brutal_parts": [0.0, 30.0, 1.0],
}

var config: Dictionary


func _init(data: Dictionary) -> void:
	config = data


func _ready() -> void:
	add_to_group("tunable")
	get_node("/root/DebugMenu").apply_tune(self)


func _container(path: Array) -> Variant:
	var value: Variant = config
	for index in range(path.size() - 1):
		value = value[path[index]]
	return value


func _get(property: StringName) -> Variant:
	var path: Array = PATHS.get(property, [])
	if path.is_empty():
		return null
	return _container(path)[path.back()]


func _set(property: StringName, value: Variant) -> bool:
	var path: Array = PATHS.get(property, [])
	if path.is_empty():
		return false
	_container(path)[path.back()] = float(value)
	return true

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

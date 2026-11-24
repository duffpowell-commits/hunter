extends Node
## Hunter M3 (Nov 23): TUNE sliders for every lair number (data/lair.json), the workshop
## (recipes.json), the trophy perks (trophies.json) and Vesper's voice special (voices/vesper.json).
## The sliders write into GameData's cached copies, so every reader sees the new value at once;
## hunt_arena.gd re-reads the loadout twice a second. Same pattern as pews_tuning.gd.

const GameData = preload("res://scripts/game_data.gd")

const PATHS := {
	"heat_per_night": ["lair", "heat", "per_night"],
	"raid_at_heat": ["lair", "heat", "raid_at"],
	"raid_waves": ["lair", "raid", "waves"],
	"raid_per_wave": ["lair", "raid", "per_wave"],
	"raid_wave_gap": ["lair", "raid", "wave_gap"],
	"raid_win_heat_drop": ["lair", "raid", "win_heat_drop"],
	"raid_lose_heat_drop": ["lair", "raid", "lose_heat_drop"],
	"raid_lose_parts_fraction": ["lair", "raid", "lose_parts_fraction"],
	"trap_damage": ["lair", "raid", "trap_damage"],
	"trap_radius": ["lair", "raid", "trap_radius"],
	"raider_hp": ["lair", "raid", "raider_hp"],
	"raider_damage": ["lair", "raid", "raider_damage"],
	"raider_attack_cooldown": ["lair", "raid", "attack_cooldown"],
	"raider_attack_windup": ["lair", "raid", "attack_windup"],
	"raider_first_attack_delay": ["lair", "raid", "first_attack_delay"],
	"raider_attack_range": ["lair", "raid", "attack_range"],
	"raider_hit_range": ["lair", "raid", "hit_range"],
	"raider_chase_min": ["lair", "raid", "chase_min"],
	"raider_chase_max": ["lair", "raid", "chase_max"],
	"raider_chase_speed": ["lair", "raid", "chase_speed"],
	"raider_steer_probe": ["lair", "raid", "steer_probe"],
	"raider_steer_margin": ["lair", "raid", "steer_margin"],
	"lair_interact_radius": ["lair", "interact_radius"],
	"inventory_slots": ["lair", "inventory", "slots"],
	"inventory_stack": ["lair", "inventory", "stack"],
	"corruption_look_2_at": ["lair", "corruption", "band_at", 0],
	"corruption_look_3_at": ["lair", "corruption", "band_at", 1],
	"voice_box_secs": ["lair", "voice_box", "secs"],
	"grip_parts": ["recipes", "recipes", 0, "cost", "parts"],
	"grip_chains": ["recipes", "recipes", 0, "cost", "censer_chain"],
	"grip_durability": ["recipes", "recipes", 0, "durability"],
	"grip_max_level": ["recipes", "recipes", 0, "max_level"],
	"trap_parts": ["recipes", "recipes", 1, "cost", "parts"],
	"trap_glass": ["recipes", "recipes", 1, "cost", "stained_glass"],
	"poultice_parts": ["recipes", "recipes", 2, "cost", "parts"],
	"poultice_candles": ["recipes", "recipes", 2, "cost", "candle"],
	"poultice_heal": ["recipes", "recipes", 2, "heal"],
	"vesper_offence_special": ["trophies", "trophies", "vesper", "offence", "special_damage"],
	"vesper_defence_hp": ["trophies", "trophies", "vesper", "defence", "max_hp"],
	"vesper_utility_heat": ["trophies", "trophies", "vesper", "utility", "heat_per_night"],
	"vesper_voice_damage": ["voices/vesper", "special", "damage"],
	"vesper_voice_per_level": ["voices/vesper", "special", "per_level"],
	"vesper_voice_cooldown": ["voices/vesper", "special", "cooldown"],
	"vesper_voice_reach": ["voices/vesper", "special", "reach"],
}
const TUNE := {
	"heat_per_night": [0.0, 40.0, 1.0], "raid_at_heat": [10.0, 100.0, 1.0],
	"raid_waves": [1.0, 5.0, 1.0], "raid_per_wave": [1.0, 3.0, 1.0], "raid_wave_gap": [0.0, 6.0],
	"raid_win_heat_drop": [0.0, 100.0, 1.0], "raid_lose_heat_drop": [0.0, 100.0, 1.0],
	"raid_lose_parts_fraction": [0.0, 1.0], "trap_damage": [0.0, 100.0, 1.0], "trap_radius": [0.3, 3.0],
	"raider_hp": [5.0, 150.0, 1.0], "raider_damage": [0.0, 35.0, 1.0],
	"raider_attack_cooldown": [0.5, 8.0], "raider_attack_windup": [0.5, 2.0], "raider_first_attack_delay": [0.0, 5.0],
	"raider_attack_range": [0.8, 4.0], "raider_hit_range": [0.8, 4.0], "raider_chase_min": [0.5, 3.0],
	"raider_chase_max": [2.0, 40.0], "raider_chase_speed": [0.1, 1.0],
	"raider_steer_probe": [0.3, 2.0], "raider_steer_margin": [0.0, 1.0],
	"lair_interact_radius": [0.5, 4.0], "inventory_slots": [4.0, 48.0, 1.0], "inventory_stack": [1.0, 99.0, 1.0],
	"corruption_look_2_at": [1.0, 99.0, 1.0], "corruption_look_3_at": [2.0, 100.0, 1.0], "voice_box_secs": [1.0, 8.0],
	"grip_parts": [0.0, 30.0, 1.0], "grip_chains": [0.0, 5.0, 1.0], "grip_durability": [0.0, 5.0, 1.0],
	"grip_max_level": [1.0, 10.0, 1.0], "trap_parts": [0.0, 30.0, 1.0], "trap_glass": [0.0, 5.0, 1.0],
	"poultice_parts": [0.0, 30.0, 1.0], "poultice_candles": [0.0, 5.0, 1.0], "poultice_heal": [0.0, 100.0, 1.0],
	"vesper_offence_special": [0.0, 1.0], "vesper_defence_hp": [0.0, 60.0, 1.0], "vesper_utility_heat": [0.0, 30.0, 1.0],
	"vesper_voice_damage": [0.0, 80.0, 1.0], "vesper_voice_per_level": [0.0, 30.0, 1.0],
	"vesper_voice_cooldown": [0.5, 15.0], "vesper_voice_reach": [1.0, 5.0],
}


func _ready() -> void:
	add_to_group("tunable")
	get_node("/root/DebugMenu").apply_tune(self)


func _container(path: Array) -> Variant:
	var value: Variant = GameData.load_json(str(path[0]))
	for index in range(1, path.size() - 1):
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

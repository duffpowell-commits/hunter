extends Node
## Hunter M3 (Nov 23): TUNE sliders for every lair number (data/lair.json), the workshop
## (recipes.json), the trophy perks (trophies.json), Vesper's voice special (voices/vesper.json) and
## Furfur (furfur.json: the invasion fight, the mercy price, the VENT string hits; M4).
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
	"raid_revive_hp_fraction": ["lair", "raid", "revive_hp_fraction"],
	"raid_revive_delay": ["lair", "raid", "revive_delay"],
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
	# M4 (Nov 26): Furfur (data/furfur.json).
	"furfur_after_hunts": ["furfur", "trigger", "after_hunts"],
	"furfur_limp_hp_fraction": ["furfur", "trigger", "limp_hp_fraction"],
	"furfur_hp": ["furfur", "invasion", "furfur_hp"],
	"furfur_damage": ["furfur", "invasion", "furfur_damage"],
	"furfur_attack_cooldown": ["furfur", "invasion", "attack_cooldown"],
	"furfur_attack_windup": ["furfur", "invasion", "attack_windup"],
	"furfur_first_attack_delay": ["furfur", "invasion", "first_attack_delay"],
	"furfur_attack_range": ["furfur", "invasion", "attack_range"],
	"furfur_hit_range": ["furfur", "invasion", "hit_range"],
	"furfur_chase_min": ["furfur", "invasion", "chase_min"],
	"furfur_chase_max": ["furfur", "invasion", "chase_max"],
	"furfur_chase_speed": ["furfur", "invasion", "chase_speed"],
	"furfur_steer_probe": ["furfur", "invasion", "steer_probe"],
	"furfur_steer_margin": ["furfur", "invasion", "steer_margin"],
	"furfur_revive_hp_fraction": ["furfur", "invasion", "revive_hp_fraction"],
	"furfur_revive_delay": ["furfur", "invasion", "revive_delay"],
	"furfur_regen_fraction": ["furfur", "invasion", "regen_fraction"],
	"furfur_chain_corruption": ["furfur", "invasion", "chain_corruption"],
	"furfur_mercy_cost": ["furfur", "cage", "mercy_cost"],
	"vent_corruption": ["furfur", "vent", "corruption"],
	"vent_elbow_damage": ["furfur", "vent", "strings", 0, "damage"],
	"vent_elbow_power": ["furfur", "vent", "strings", 0, "power"],
	"vent_elbow_reach": ["furfur", "vent", "strings", 0, "reach"],
	"vent_elbow_hit_at": ["furfur", "vent", "strings", 0, "hit_at"],
	"vent_elbow_recover": ["furfur", "vent", "strings", 0, "recover"],
	"vent_headbutt_damage": ["furfur", "vent", "strings", 1, "damage"],
	"vent_headbutt_power": ["furfur", "vent", "strings", 1, "power"],
	"vent_headbutt_reach": ["furfur", "vent", "strings", 1, "reach"],
	"vent_headbutt_hit_at": ["furfur", "vent", "strings", 1, "hit_at"],
	"vent_headbutt_recover": ["furfur", "vent", "strings", 1, "recover"],
	"vent_hammer_damage": ["furfur", "vent", "strings", 2, "damage"],
	"vent_hammer_power": ["furfur", "vent", "strings", 2, "power"],
	"vent_hammer_reach": ["furfur", "vent", "strings", 2, "reach"],
	"vent_hammer_hit_at": ["furfur", "vent", "strings", 2, "hit_at"],
	"vent_hammer_recover": ["furfur", "vent", "strings", 2, "recover"],
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
	"raid_revive_hp_fraction": [0.1, 1.0], "raid_revive_delay": [0.0, 4.0],
	"lair_interact_radius": [0.5, 4.0], "inventory_slots": [4.0, 48.0, 1.0], "inventory_stack": [1.0, 99.0, 1.0],
	"corruption_look_2_at": [1.0, 99.0, 1.0], "corruption_look_3_at": [2.0, 100.0, 1.0], "voice_box_secs": [1.0, 8.0],
	"grip_parts": [0.0, 30.0, 1.0], "grip_chains": [0.0, 5.0, 1.0], "grip_durability": [0.0, 5.0, 1.0],
	"grip_max_level": [1.0, 10.0, 1.0], "trap_parts": [0.0, 30.0, 1.0], "trap_glass": [0.0, 5.0, 1.0],
	"poultice_parts": [0.0, 30.0, 1.0], "poultice_candles": [0.0, 5.0, 1.0], "poultice_heal": [0.0, 100.0, 1.0],
	"vesper_offence_special": [0.0, 1.0], "vesper_defence_hp": [0.0, 60.0, 1.0], "vesper_utility_heat": [0.0, 30.0, 1.0],
	"vesper_voice_damage": [0.0, 80.0, 1.0], "vesper_voice_per_level": [0.0, 30.0, 1.0],
	"vesper_voice_cooldown": [0.5, 15.0], "vesper_voice_reach": [1.0, 5.0],
	"furfur_after_hunts": [1.0, 10.0, 1.0], "furfur_limp_hp_fraction": [0.1, 1.0],
	"furfur_hp": [20.0, 400.0, 1.0], "furfur_damage": [0.0, 40.0, 1.0],
	"furfur_attack_cooldown": [0.5, 8.0], "furfur_attack_windup": [0.3, 2.0], "furfur_first_attack_delay": [0.0, 5.0],
	"furfur_attack_range": [0.8, 4.0], "furfur_hit_range": [0.8, 4.0], "furfur_chase_min": [0.5, 3.0],
	"furfur_chase_max": [2.0, 40.0], "furfur_chase_speed": [0.1, 1.0],
	"furfur_steer_probe": [0.3, 2.0], "furfur_steer_margin": [0.0, 1.0],
	"furfur_revive_hp_fraction": [0.1, 1.0], "furfur_revive_delay": [0.0, 4.0], "furfur_regen_fraction": [0.0, 1.0],
	"furfur_chain_corruption": [0.0, 30.0, 1.0], "furfur_mercy_cost": [0.0, 100.0, 1.0], "vent_corruption": [0.0, 30.0, 1.0],
	"vent_elbow_damage": [0.0, 60.0, 1.0], "vent_elbow_power": [0.0, 2.0], "vent_elbow_reach": [0.8, 3.0],
	"vent_elbow_hit_at": [0.05, 0.6], "vent_elbow_recover": [0.1, 1.0],
	"vent_headbutt_damage": [0.0, 60.0, 1.0], "vent_headbutt_power": [0.0, 2.0], "vent_headbutt_reach": [0.8, 3.0],
	"vent_headbutt_hit_at": [0.05, 0.6], "vent_headbutt_recover": [0.1, 1.0],
	"vent_hammer_damage": [0.0, 60.0, 1.0], "vent_hammer_power": [0.0, 2.0], "vent_hammer_reach": [0.8, 3.0],
	"vent_hammer_hit_at": [0.05, 0.6], "vent_hammer_recover": [0.1, 1.0],
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

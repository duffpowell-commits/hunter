extends RefCounted
## Milestone 2 domain rules for The Pews. Pure logic, no scene dependencies.
## Values are tuned in data/pews.json so the same rules can be tested without a scene.

const GameData = preload("res://scripts/game_data.gd")

var config: Dictionary
var studied := 0.0
var boss_phase := 1
var boss_hp := 0.0
var boss_defeated := false
var finisher := ""
var eaten := false
var corruption := 0
var parts := 0
var cash := 0
var heat := 0
var plates_collected := 0
var inventory := {}
var engaged := false
var ambush_started := false


func _init(data: Dictionary = {}) -> void:
	config = data if not data.is_empty() else GameData.load_json("pews")
	boss_hp = float(config.get("boss", {}).get("phase_hp", [140, 180])[0])


## angle_rad is the angle between the target's facing direction and the line to the player.
## A target studies the player only when the player is outside its view cone.
func tick_stalking(current: float, distance: float, angle_rad: float, sneaking: bool, seen: bool, dt: float) -> float:
	if seen:
		studied = 0.0
		engaged = true
		return studied
	var rules: Dictionary = config.get("stalking", {})
	var radius := float(rules.get("study_radius", 6.0))
	var half_cone := deg_to_rad(float(rules.get("view_cone_degrees", 60.0)) / 2.0)
	if distance > radius or absf(angle_rad) <= half_cone:
		studied = clampf(current, 0.0, 100.0)
		return studied
	var rate := float(rules.get("study_per_second", 8.0))
	if sneaking:
		rate *= float(rules.get("sneak_multiplier", 2.0))
	studied = clampf(current + rate * maxf(dt, 0.0), 0.0, 100.0)
	return studied


## Apply one hit to Vesper. Phase one breaks into phase two; only phase two can defeat him.
func hit_boss(damage: float) -> Dictionary:
	if boss_defeated or damage <= 0.0:
		return {"phase": boss_phase, "hp": boss_hp, "phase_changed": false, "defeated": boss_defeated}
	boss_hp = maxf(0.0, boss_hp - damage)
	var phase_changed := false
	if boss_hp <= 0.0:
		if boss_phase == 1:
			boss_phase = 2
			var hp_by_phase: Array = config.get("boss", {}).get("phase_hp", [140, 180])
			boss_hp = float(hp_by_phase[1]) if hp_by_phase.size() > 1 else 180.0
			phase_changed = true
		else:
			boss_defeated = true
	return {"phase": boss_phase, "hp": boss_hp, "phase_changed": phase_changed, "defeated": boss_defeated}


## Finishers are mutually exclusive and only available after the boss is defeated.
func finish(method: String) -> Dictionary:
	if not boss_defeated or not finisher.is_empty() or not ["CLEAN", "BRUTAL"].has(method):
		return {}
	finisher = method
	var rules: Dictionary = config.get("finishers", {})
	var outcome: Dictionary = rules.get(method.to_lower(), {})
	corruption += int(outcome.get("corruption", 0))
	parts += int(outcome.get("parts", 0))
	return {
		"method": method,
		"corruption": int(outcome.get("corruption", 0)),
		"parts": int(outcome.get("parts", 0)),
		"trophy": bool(outcome.get("trophy", false)),
		"extra_special_slots": int(outcome.get("extra_special_slots", 0))
	}


## EAT is a separate required action after the finisher. It unlocks Vesper exactly once.
func eat() -> Dictionary:
	if finisher.is_empty() or eaten:
		return {"voice_unlocked": false}
	eaten = true
	return {"voice_unlocked": true, "voice_id": "vesper"}


## Collection plates trade cash for heat. Repeated plates are allowed; each has a real cost.
func collect_plate() -> Dictionary:
	var rules: Dictionary = config.get("collection_plate", {})
	var earned := int(rules.get("cash", 10))
	var gained_heat := int(rules.get("heat", 8))
	cash += earned
	heat += gained_heat
	plates_collected += 1
	return {"cash": earned, "heat": gained_heat, "total_cash": cash, "total_heat": heat}


func ambush_ready() -> bool:
	return studied >= 100.0 and not engaged and not boss_defeated


## Start a studied encounter. The first special is free; the caller staggers Vesper in the scene.
func start_ambush() -> Dictionary:
	if not ambush_ready() or ambush_started:
		return {}
	ambush_started = true
	engaged = true
	return {"started": true, "free_first_special": true, "target_staggered": true}


## Pick up one of the realm's listed materials. Unknown IDs are ignored.
func scavenge(loot_id: String) -> Dictionary:
	for item: Dictionary in config.get("loot", []):
		if str(item.get("id", "")) == loot_id:
			var count := int(inventory.get(loot_id, 0)) + 1
			inventory[loot_id] = count
			var gained := int(item.get("parts", 1))
			parts += gained
			return {"item": loot_id, "count": count, "parts": gained, "total_parts": parts}
	return {}

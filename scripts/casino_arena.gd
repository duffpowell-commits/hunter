extends "res://scripts/pews_arena.gd"
## The Cellar Casino: shared hunt lifecycle, distinct decor and Gus's powers.

var rng := RandomNumberGenerator.new()
var _effect := ""
var _effect_time := 0.0
var _shield := 0
var _counter_stance := false
var _roll_double := false
var _aim := Vector3.ZERO
var _vault_run := false
var _vault: Node3D
var _slot_warning := false
var _dice: Array[Dictionary] = []
var _slots: Array[Node3D] = []
var _roulette_segments: Array[MeshInstance3D] = []
var _coin: MeshInstance3D
var dice_spawned := 0
var slot_rolls := 0

func realm_config() -> Dictionary:
	return GameData.load_json("casino")

func boss_short() -> String:
	return "Gus"

func boss_tint() -> Color:
	return Color("bd294c")

func add_realm_tuning() -> void:
	add_child(preload("res://scripts/casino_tuning.gd").new(rules.config))

func _build_world() -> void:
	# Shared arena collision shell, not church furniture.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("24101b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a28290")
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = 1.1
	add_child(sun)
	_box(Vector3(-9,-1,-9),Vector3(9,0,9),Color("443139"))
	# A single mesh for worn checker tiles, the red carpet and gold inlay.
	var floor_ink := SurfaceTool.new()
	floor_ink.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 18:
		for col in 18:
			var x := float(col)-9
			var z := float(row)-9
			var tint := Color("30242e") if (row+col)%2 == 0 else Color("4e3640")
			if col in [7,8,9,10]:
				tint = Color("76203a") if col in [8,9] else Color("432237")
			_floor_tile(floor_ink,x,z,0.96,tint)
	var pattern := MeshInstance3D.new()
	pattern.mesh = floor_ink.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pattern.material_override = material
	add_child(pattern)
	for x in [-1.04,1.04]:
		_box(Vector3(x-0.025,0.012,-8),Vector3(x+0.025,0.018,8),Color("d5aa59"),false)
	for side in [-1,1]:
		var x := float(side)*9.0
		_box(Vector3(x-0.3,0,-9),Vector3(x+0.3,2,9),Color("231823"))
		for z in [-4.0,0.0,4.0]:
			var cx := float(side)*4.2
			_box(Vector3(cx-0.9,0,z-0.55),Vector3(cx+0.9,0.7,z+0.55),Color("43232f"))
			_box(Vector3(cx-1.0,0.7,z-0.65),Vector3(cx+1.0,0.8,z+0.65),Color("9e1e3d"))
			_box(Vector3(x-side*0.5,1.5,z-1.0),Vector3(x-side*0.4,1.65,z+1.0),Color("f33158"),false)
	_box(Vector3(-9,0,-9.3),Vector3(9,2,-9),Color("231823"))
	_box(Vector3(-9,0,9),Vector3(9,0.5,9.3),Color("231823"))
	for i in 24:
		var angle := float(i)*TAU/24.0
		var segment := _box(Vector3(-0.45,0,-0.13),Vector3(0.45,0.015,0.13),Color("d21e3c") if i%2==0 else Color("d5aa59"),false)
		segment.position = Vector3(sin(angle)*2.7,0.02,cos(angle)*2.7-3.5)
		segment.rotation.y = angle + PI/2
		_roulette_segments.append(segment as MeshInstance3D)

func _ready() -> void:
	super._ready()
	name = "CasinoArena"
	rig.snap()
	_spawn_pickup("roulette_duster")
	pipe_durability = float(weapon_data.roulette_duster.durability)
	add_child(preload("res://scripts/duster_tuning.gd").new(weapon_data.roulette_duster))
	rng.randomize()
	get_node("/root/Subs").cue("[Gus: The house always wins, Cain!]")
	var prof := get_node_or_null("/root/Profile")
	if prof != null and prof.data.voices.has("gus"):
		_vault_run = not prof.data.get("gus_debt_paid", false)
		boss_defeated = true
		rules.boss_defeated = true
		rules.eaten = true
		dummy.die(Vector3.ZERO)
		portal_ready = true

func spawn_realm_foes() -> void:
	_spawn_foe("Loan_Shark",Vector3(-2,0,-1.6),Color("92536a"),float(rules.config.minions.loan_shark_hp))
	_spawn_foe("Dealer",Vector3(2,0,-2),Color("b9a2c3"),float(rules.config.minions.dealer_hp))
	_foes[-1].warn.text = "♦"

func _spawn_realm_props() -> void:
	for location in rules.config.field.slot_at:
		var at := _v3(location)
		var slot := _box(at-Vector3(0.4,0,0.5),at+Vector3(0.4,1.5,0.5),Color("d21e3c"))
		_slots.append(slot)
		_box(at+Vector3(-0.35,0.65,0.49),at+Vector3(0.35,1.25,0.54),Color("1c151d"),false)
		for i in 3:
			_box(at+Vector3(-0.25+i*0.2,0.85,0.54),at+Vector3(-0.12+i*0.2,1.06,0.57),Color("d5aa59"),false)
		_prop_label("★ CURSED SLOT",slot.position + Vector3(0,0.85,0))
	for item in rules.config.loot:
		var at := _v3(rules.config.field.loot_at[item.id])
		var prop := _box(at-Vector3(.25,0,.25),at+Vector3(.25,.2,.25),Color("d5aa59"),false)
		prop.set_meta("loot_id",item.id)
		_loot_nodes.append(prop)
	_vault = _box(Vector3(-.5,0,-8),Vector3(.5,1,-7),Color("d5aa59"))
	_prop_label("VAULT", _vault.position + Vector3(0,0.9,0))

func _prop_label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)

func _windup_cue(kind: String) -> String:
	return "[Loan shark winds up]" if kind == "Loan_Shark" else "[Dealer shuffles cursed cards]"

func _begin_boss_move() -> void:
	var names: Array = rules.config.boss.move_order
	_boss_move = names[_boss_move_index % names.size()]
	_boss_move_index += 1
	var data: Dictionary = rules.config.boss.moves[_boss_move]
	_boss_telegraph = float(data.telegraph)
	_roll_double = rng.randf() < float(rules.config.boss.moves.double_or_nothing.chance)
	_aim = (hero.position-dummy.position).normalized()
	_counter_stance = _boss_move == "house_edge"
	_slot_warning = rules.boss_phase == 2
	_warn.text = "! " + _boss_move.replace("_"," ").to_upper()
	_warn.font_size = 70
	_warn.modulate = UI.key("bad")
	_warn.visible = true
	_set_occult_halo(true)
	if _boss_move == "double_or_nothing":
		_coin = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.22
		mesh.height = 0.045
		_coin.mesh = mesh
		_coin.material_override = _toon(Color("ffd46c"),false)
		dummy.add_child(_coin)
		_coin.position = Vector3(0,2.2,0)
		create_tween().tween_property(_coin,"rotation:x",TAU*2,_boss_telegraph)
	get_node("/root/Subs").cue("[Gus: %s!%s]" % [_boss_move.replace("_"," "), " Slots charging" if _slot_warning else ""])

func _execute_boss_move() -> void:
	_clear_coin()
	_set_occult_halo(false)
	_warn.visible = false
	var data: Dictionary = rules.config.boss.moves[_boss_move]
	var to := hero.position-dummy.position
	dummy.act("enemy_swing")
	if _boss_move == "double_or_nothing":
		get_node("/root/Subs").cue("[Gus: DOUBLE!]" if _roll_double else "[Gus: Nothing...]")
		if _roll_double and to.length() < float(data.radius):
			_damage_hero(int(float(data.damage)*float(data.multiplier)),dummy.position)
	elif _boss_move == "loaded_dice":
		for offset in [-1.0, 0.0, 1.0]:
			var die := _box(Vector3(-0.15,0,-0.15),Vector3(0.15,0.3,0.15),Color("f2d6b1"),false)
			die.position = dummy.position + Vector3(0,0.6,0)
			var direction := _aim.rotated(Vector3.UP,deg_to_rad(float(data.spread))*offset)
			_dice.append({"node":die,"direction":direction,"remaining":float(data.radius),"damage":int(data.damage)})
			dice_spawned += 1
	_counter_stance = false
	if _slot_warning:
		_spin_slot()
	_slot_warning = false
	_boss_cd = _cooldown_of(data)

func _cancel_boss_attack() -> void:
	_clear_coin()
	_counter_stance = false
	_slot_warning = false
	super._cancel_boss_attack()

func _damage_dummy(r: Dictionary) -> void:
	if not encounter_started or boss_defeated or r.get("missed", false):
		return
	if _counter_stance and _boss_telegraph > 0 and r.get("kind","") != "counter":
		_damage_hero(int(rules.config.boss.moves.house_edge.damage),dummy.position)
		_cancel_boss_attack()
		return
	super._damage_dummy(r)

func _land_hit(target: Character3D) -> Dictionary:
	var hit := super._land_hit(target)
	if _effect == "Hot Streak":
		hit.damage *= float(rules.config.hazard.hot_streak)
	elif _effect == "Bad Beat":
		hit.damage *= float(rules.config.hazard.bad_beat)
	return hit

func _damage_hero(amount: int, from_pos: Vector3, power := 0.5) -> bool:
	if _iframes > 0.0 or hero.dead or get_node("/root/DebugMenu").god_mode:
		return false
	var absorbed := mini(_shield, amount)
	_shield -= absorbed
	return super._damage_hero(amount-absorbed,from_pos,power) if amount > absorbed else false

func _spin_slot() -> void:
	slot_rolls += 1
	_effect = ["Hot Streak","Bad Beat","Lucky Break","Cold Streak","Jackpot","House Tax"][rng.randi_range(0,5)]
	_effect_time = float(rules.config.hazard.duration)
	_shield = int(rules.config.hazard.shield) if _effect == "Jackpot" else 0
	if _effect == "House Tax":
		_profile_gain({"heat": int(rules.config.hazard.heat)})
	get_node("/root/Subs").cue("[Cursed slot: %s]" % _effect)

func _process(dt: float) -> void:
	super._process(dt)
	_nearest_plate = null
	var nearest := float(rules.config.field.interact_radius)
	for slot in _slots:
		var distance := hero.position.distance_to(slot.position)
		if distance < nearest:
			nearest = distance
			_nearest_plate = slot
	var speed := float(rules.config.boss.moves.loaded_dice.speed)
	for index in range(_dice.size()-1,-1,-1):
		var die: Dictionary = _dice[index]
		die.node.position += die.direction * dt * speed
		die.remaining -= dt * speed
		var delta: Vector3 = die.node.position - hero.position
		delta.y = 0
		if not boss_defeated and delta.length() < float(rules.config.boss.moves.loaded_dice.hit_radius):
			_damage_hero(die.damage, die.node.position)
			die.remaining = 0
		if die.remaining <= 0 or boss_defeated:
			die.node.queue_free()
			_dice.remove_at(index)
	if _effect_time > 0:
		var rate := float(rules.config.hazard.lucky_break) if _effect == "Lucky Break" else float(rules.config.hazard.cold_streak) if _effect == "Cold Streak" else 1.0
		for k in combat.cooldowns:
			if combat.cooldowns[k] > 0:
				combat.cooldowns[k] = maxf(0, float(combat.cooldowns[k]) - dt * (rate - 1.0))
		_effect_time -= dt
		if _effect_time <= 0:
			_effect = ""
			_shield = 0
			get_node("/root/Subs").cue("[Slot effect ended]")

func context_label() -> String:
	if boss_defeated and not rules.eaten:
		return "FINISH" if rules.finisher.is_empty() else "EAT"
	if not combo_move().is_empty() and realm_combat_active():
		return combo_move()
	if can_pick_up:
		return "PICK UP"
	if _vault_run and hero.position.distance_to(_vault.position) < float(rules.config.field.vault_range) and _foes.all(func(f): return f.dead):
		return "ROB VAULT"
	if _nearest_plate != null and _effect_time <= 0:
		return "SPIN SLOT"
	if _nearest_loot != null:
		return "SCAVENGE"
	if silent_target() >= 0:
		return "SILENT KILL"
	if rules.ambush_ready():
		return "AMBUSH"
	return "RETURN HOME" if portal_ready else ""

func context_action() -> void:
	var action := context_label()
	if action == "ROB VAULT":
		var prof := get_node("/root/Profile")
		prof.data.gus_debt_paid = true
		prof.save()
		_vault_run = false
		get_node("/root/Subs").cue("[Gus: Debt settled!]")
	elif action == "SPIN SLOT":
		_spin_slot()
	elif action == "FINISH":
		finish_requested.emit()
	elif action == "EAT":
		var result := rules.eat()
		var prof := get_node("/root/Profile")
		if LairRules.add_voice(prof.data, "gus"):
			_profile_gain({"corruption": int(result.get("corruption",0))})
		portal_ready = true
		voice_unlocked.emit()
	elif action in ["TAKEDOWN", "FINISHER"]:
		combo_action()
	elif action == "PICK UP":
		pick_up()
	elif action == "SCAVENGE":
		var id := str(_nearest_loot.get_meta("loot_id"))
		var result := rules.scavenge(id)
		if not result.is_empty():
			var prof := get_node("/root/Profile")
			LairRules.add_item(prof.data,id,1,GameData.load_json("lair"))
			_profile_gain({"parts":int(result.parts),"heat":int(rules.config.heat.scavenge)})
		_nearest_loot.queue_free()
		_loot_nodes.erase(_nearest_loot)
		_nearest_loot = null
		get_node("/root/Subs").cue("[Scavenged %s]" % id.replace("_"," "))
	elif action == "SILENT KILL":
		silent_kill()
	elif action == "AMBUSH":
		rules.start_ambush()
		encounter_started = true
		_ambush_free_special = true
		dummy.act("hit_chest")
		voice_moment.emit("fight")
	elif action == "RETURN HOME":
		portal_opened.emit()

func status_text() -> String:
	var status := "GOAL: ROB THE VAULT" if _vault_run else ("RETURN HOME" if portal_ready else "GOAL: HUNT GUS  STUDY %d%%" % int(rules.studied) if not encounter_started else "GUS — %s — %d HP" % ["ALL IN" if rules.boss_phase == 2 else "THE HOUSE ALWAYS WINS",int(rules.boss_hp)])
	return status + ("\n" + _effect + " %ds" % ceili(_effect_time) if not _effect.is_empty() else "")


func save_state() -> Dictionary:
	var state := super.save_state()
	state.merge({"vault_run": _vault_run, "slot_effect": _effect, "slot_time": _effect_time, "slot_shield": _shield, "rng_state": str(rng.state), "duster_taken": _pickup == null, "weapon": combat.weapon, "weapon_wear": combat.durability}, true)
	return state

func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	super.restore_state(state)
	if rules.boss_phase == 2:
		_light_roulette()
	var prof := get_node("/root/Profile")
	if prof.data.voices.has("gus"):
		rules.eaten = true
		rules.boss_defeated = true
		rules.finisher = str(prof.data.get("gus_finisher", "CLEAN"))
		boss_defeated = true
		portal_ready = true
		if not dummy.dead:
			dummy.die(Vector3.ZERO)
	_vault_run = bool(state.get("vault_run", false)) and prof.data.voices.has("gus") and not prof.data.get("gus_debt_paid", false)
	_effect = str(state.get("slot_effect", ""))
	_effect_time = float(state.get("slot_time", 0))
	_shield = int(state.get("slot_shield", 0))
	if state.has("rng_state"):
		rng.state = int(state.rng_state)
	if state.get("weapon", "") == "roulette_duster" and _pickup != null:
		can_pick_up = true
		pick_up()
		combat.durability = int(state.get("weapon_wear", combat.durability))
	elif state.get("duster_taken", false) and _pickup != null:
		_pickup.queue_free()
		_pickup = null


func choose_finisher(method: String) -> Dictionary:
	var prof := get_node("/root/Profile")
	if prof.data.get("gus_finisher", "") != "":
		rules.finisher = str(prof.data.gus_finisher)
		return {}
	var result := rules.finish(method)
	if result.is_empty():
		return result
	if result.trophy:
		LairRules.add_trophy(prof.data, "gus")
	if int(result.extra_special_slots) > 0:
		prof.data.voice_levels.gus = int(prof.data.voice_levels.get("gus", 0)) + int(result.extra_special_slots)
	prof.data.gus_finisher = method
	_profile_gain({"corruption": int(result.corruption), "parts": int(result.parts)})
	return result


func _pipe_mesh(id: String) -> MeshInstance3D:
	if id != "roulette_duster":
		return super._pipe_mesh(id)
	var mesh := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.08
	ring.outer_radius = 0.18
	ring.rings = 12
	ring.ring_segments = 8
	mesh.mesh = ring
	mesh.material_override = _toon(Color("d5aa59"))
	return mesh


func _floor_tile(surface: SurfaceTool,x: float,z: float,size: float,tint: Color) -> void:
	for point in [Vector3(x,0.007,z),Vector3(x+size,0.007,z),Vector3(x+size,0.007,z+size),Vector3(x,0.007,z),Vector3(x+size,0.007,z+size),Vector3(x,0.007,z+size)]:
		surface.set_color(tint)
		surface.add_vertex(point)


func realm_combat_active() -> bool:
	return _vault_run or not boss_defeated

func _enemy(dt: float) -> void:
	if _vault_run and not hero.dead:
		_foe_ai(dt)
	else:
		super._enemy(dt)

func stealth_allowed() -> bool:
	return _vault_run or super.stealth_allowed()


func _foe_ai(dt: float) -> void:
	super._foe_ai(dt)
	for foe in _foes:
		if foe.kind != "Dealer" or foe.dead or not foe.aggro or foe.windup > 0.0:
			continue
		var actor: Character3D = foe.actor
		var to := hero.position - actor.position
		to.y = 0
		if foe.attack_cd > 0 and to.length() < float(rules.config.minions.dealer_cover_range):
			var escape := to.normalized().cross(Vector3.UP)
			var way := steer(actor.position,escape,foe.side,float(rules.config.minions.steer_probe),float(rules.config.minions.steer_margin))
			actor.move_input = Vector2(way[0].x,way[0].z) * float(rules.config.minions.dealer_cover_speed)


func _clear_coin() -> void:
	if is_instance_valid(_coin):
		_coin.queue_free()
	_coin = null

func _ko(result: Dictionary) -> void:
	var previous := rules.boss_phase
	super._ko(result)
	if previous == 1 and rules.boss_phase == 2:
		_light_roulette()
		get_node("/root/Subs").cue("[Gus: No, no, no! I'm ALL IN!]")

func _light_roulette() -> void:
	for i in _roulette_segments.size():
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("ff3158") if i%2==0 else Color("ffdf91")
		_roulette_segments[i].material_override = mat


func default_camera_distance() -> float:
	return float(GameData.load_json("casino").field.camera_distance)

func push_tune() -> void:
	super.push_tune()
	combat.durability_max = int(weapon_data.roulette_duster.durability) + durability_bonus
	combat.break_mult = float(weapon_data.roulette_duster.break_mult)

func _break_weapon() -> void:
	if _held != null:
		get_node("/root/Feel").burst(_held.global_position, 1.0, self)
		_held.queue_free()
		_held = null
	get_node("/root/Audio").sfx("hit_heavy",0.7)
	get_node("/root/Subs").cue("[roulette duster breaks]")
	weapon_changed.emit("",0)

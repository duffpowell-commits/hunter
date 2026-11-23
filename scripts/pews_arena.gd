extends "res://scripts/arena.gd"
## The Pews: a playable church encounter built on Hunter's tested combat controller.
## The training arena remains the autoplay target; normal NEW GAME enters this realm.

const PewsRules = preload("res://scripts/pews_rules.gd")

signal finish_requested
signal voice_unlocked
signal portal_opened

var rules: PewsRules
var encounter_started := false
var boss_defeated := false
var portal_ready := false
var _ambush_free_special := false
var _boss_move_index := 0
var _boss_cd := 1.5
var _boss_telegraph := 0.0
var _boss_move := ""
var _flock_time := 0.0
var _flock_cd := 0.0
var _occult_halo: Node3D
var _flock_node: Node3D
var _nearest_plate: Node3D
var _nearest_loot: Node3D
var _loot_nodes: Array[Node3D] = []
var _foes: Array[Dictionary] = []


func _build_world() -> void:
	super._build_world()
	var church := Node3D.new()
	church.name = "Pews"
	add_child(church)
	var altar := Node3D.new()
	altar.name = "Altar"
	altar.position = Vector3(0, 0, -8.0)
	church.add_child(altar)
	# Keep the altar and pew collision footprints from the encounter blockout.
	var environment: Environment
	for child in get_children():
		if child is WorldEnvironment:
			environment = child.environment
			break
	environment.background_color = Color("151a22")
	environment.ambient_light_color = Color("657181")
	_box(Vector3(-1.1, 0, -9.0), Vector3(1.1, 1.8, -8.7), Color("414653"))
	_box(Vector3(-0.12, 1.8, -9.05), Vector3(0.12, 4.2, -8.85), Color("343842"))
	_ink_box(Vector3(-1.27, 1.46, -9.11), Vector3(1.27, 1.65, -8.51), Color("565b64"))
	_ink_box(Vector3(-1.22, 0.0, -9.1), Vector3(1.22, 0.19, -8.56), Color("30343d"))

	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink := Color("19212b")
	for row in range(3):
		var z := -1.0 - float(row) * 2.1
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 2.5
			_box(Vector3(x - 1.25, 0.0, z), Vector3(x + 1.25, 0.45, z + 0.28), Color("493d39"))
			_box(Vector3(x - 1.25, 0.45, z + 0.22), Vector3(x + 1.25, 1.05, z + 0.48), Color("392f30"))
			_ink_box(Vector3(x - 1.26, 0.38, z - 0.19), Vector3(x + 1.26, 0.5, z + 0.29), Color("5b4c44"))
			for end in [-1.0, 1.0]:
				var post: float = x + end * 1.15
				_ink_box(Vector3(post - 0.09, 0.0, z - 0.18), Vector3(post + 0.09, 0.87, z + 0.47), Color("433638"))
			for scratch in 3:
				var at := Vector3(x - 0.93 + float(scratch) * 0.7, 1.056, z + 0.30 + float(row) * 0.04)
				_ink_stroke(marks, at, at + Vector3(0.43, 0, 0.012), 0.027, Color("242026"))

	# One vertex-colored surface for flagstones, fractures and wear. No collision or shadows.
	for row in 12:
		var z := -8.55 + float(row) * 1.25
		var seam := -0.26 if row % 2 == 0 else 0.28
		for column in 2:
			var left := -1.14 if column == 0 else seam + 0.022
			var right := seam - 0.022 if column == 0 else 1.14
			var tint := [Color("424953"), Color("3a424d"), Color("454c55")][(row + column) % 3] as Color
			_ink_stroke(marks, Vector3(left, 0.002, z + 0.6), Vector3(right, 0.002, z + 0.6), 1.2, tint)
		if row % 3 != 1:
			var direction := 1.0 if row % 2 == 0 else -1.0
			var start := Vector3(-1.12 * direction, 0.005, z + 0.26 + float(row % 4) * 0.09)
			var chip := start + Vector3(0.39 * direction, 0, 0.22)
			var bend := chip + Vector3(0.28 * direction, 0, -0.13)
			_ink_stroke(marks, start, chip, 0.050, ink)
			_ink_stroke(marks, chip, bend, 0.040, ink)
			_ink_stroke(marks, bend, bend + Vector3(0.35 * direction, 0, 0.34), 0.029, ink)
			_ink_stroke(marks, chip, chip + Vector3(0.13 * direction, 0, 0.31), 0.025, ink)
	for side in [-1.0, 1.0]:
		# A warm patch on each candle plinth, baked into the same surface as the aisle.
		var x: float = side * 1.52
		_ink_stroke(marks, Vector3(x - 0.29, 0.685, -8.53), Vector3(x + 0.29, 0.685, -8.53), 0.57, Color("65554a"))
		_ink_stroke(marks, Vector3(x - 0.24, 0.687, -8.45), Vector3(x + 0.24, 0.687, -8.45), 0.28, Color("8c6a49"))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var details := MeshInstance3D.new()
	details.name = "StoneAndWoodWear"
	details.mesh = marks.commit()
	details.material_override = material
	details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	church.add_child(details)

	for side in [-1.0, 1.0]:
		var x: float = side * 2.9
		_ink_box(Vector3(x - 0.94, 0, -9.86), Vector3(x + 0.94, 0.23, -9.29), Color("434853"))
		for offset in [-0.88, 0.88]:
			var edge: float = x + offset
			_ink_box(Vector3(edge - 0.13, 0.23, -9.90), Vector3(edge + 0.13, 2.25, -9.46), Color("3d4551"))
			var cap := _ink_box(Vector3(edge - 0.12, 2.25, -9.81), Vector3(edge + 0.12, 3.47, -9.53), Color("4d5460"))
			cap.position.x -= signf(offset) * 0.40
			cap.rotation.z = signf(offset) * 0.70
		for shard in [Vector3(-0.46, 0.98, -0.22), Vector3(0.0, 1.54, 0.15), Vector3(0.52, 0.99, 0.2)]:
			var center := Vector3(x + shard.x, shard.y, -9.71)
			var glass := _ink_box(center - Vector3(0.16, 0.62, 0.035), center + Vector3(0.16, 0.62, 0.035), Color("4f6672"))
			glass.rotation.z = shard.z
	_add_candles(church)


func _ink_box(a: Vector3, b: Vector3, color: Color) -> MeshInstance3D:
	var mesh := _box(a, b, color, false) as MeshInstance3D
	mesh.material_override = _toon(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func _ink_stroke(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var edge := (b - a).normalized().cross(Vector3.UP) * width * 0.5
	for point in [a - edge, a + edge, b + edge, a - edge, b + edge, b - edge]:
		surface.set_color(color)
		surface.add_vertex(point)


func _add_candles(church: Node3D) -> void:
	var wax := _toon(Color("ae997b"), false)
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color("e6ae55")
	var body := CylinderMesh.new()
	body.top_radius = 0.075
	body.bottom_radius = 0.088
	body.height = 0.30
	body.radial_segments = 8
	body.rings = 0
	var flame := SphereMesh.new()
	flame.radius = 0.055
	flame.height = 0.16
	flame.radial_segments = 8
	flame.rings = 4
	for side in [-1.0, 1.0]:
		var x: float = side * 1.52
		_ink_box(Vector3(x - 0.31, 0, -8.84), Vector3(x + 0.31, 0.68, -8.22), Color("49434a"))
		for offset in [-0.18, 0.02, 0.19]:
			var at := Vector3(x + offset, 0.68, -8.53 + absf(offset))
			var height := 0.84 + (0.28 if offset == 0.02 else 0.0)
			var candle := MeshInstance3D.new()
			candle.mesh = body
			candle.material_override = wax
			candle.position = at + Vector3.UP * body.height * height * 0.5
			candle.scale.y = height
			candle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			church.add_child(candle)
			var wick := MeshInstance3D.new()
			wick.mesh = flame
			wick.material_override = gold
			wick.position = at + Vector3.UP * (body.height * height + 0.06)
			wick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			church.add_child(wick)


func _ready() -> void:
	super._ready()
	name = "PewsArena"
	rules = PewsRules.new()
	dummy.name = "Vesper"
	dummy.tint = Color("8b718f")
	dummy.position = Vector3(0, 0, -6.0)
	dummy.heading = PI
	dummy.model.rotation.y = PI
	dummy_hp = rules.boss_hp
	var phase_hp: Array = rules.config.get("boss", {}).get("phase_hp", [140, 180])
	dummy_max_hp = float(phase_hp[phase_hp.size() - 1]) if not phase_hp.is_empty() else rules.boss_hp
	hero.position = Vector3(0, 0, 5.0)
	hero.heading = PI
	hero.model.rotation.y = PI
	_spawn_foe("Zealot", Vector3(-3.0, 0, -1.0), Color("a84c42"), 36.0, 7)
	_spawn_foe("Choir", Vector3(3.0, 0, -2.0), Color("b5a0d0"), 44.0, 5)
	_spawn_realm_props()
	_build_occult_halo()
	_enemy_t = 999.0


## A tiny mobile-friendly occult halo: unshaded emission, no real-time lights.
## It is deliberately hidden during exploration and ordinary combat.
func _build_occult_halo() -> void:
	_occult_halo = Node3D.new()
	_occult_halo.name = "OccultHalo"
	_occult_halo.position = Vector3(0.0, 2.35, 0.0)
	dummy.add_child(_occult_halo)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("df56bd")
	var candle := SphereMesh.new()
	candle.radius = 0.075
	candle.height = 0.15
	candle.radial_segments = 8
	candle.rings = 4
	var points := MultiMesh.new()
	points.transform_format = MultiMesh.TRANSFORM_3D
	points.mesh = candle
	points.instance_count = 10
	for i in points.instance_count:
		var angle := TAU * float(i) / float(points.instance_count)
		var at := Vector3(cos(angle) * 0.72, sin(angle) * 0.72, 0.0)
		points.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	var wicks := MultiMeshInstance3D.new()
	wicks.multimesh = points
	wicks.material_override = glow
	wicks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_occult_halo.add_child(wicks)
	_occult_halo.visible = false


func _set_occult_halo(active: bool) -> void:
	if _occult_halo != null:
		_occult_halo.visible = active


func _spawn_foe(label: String, at: Vector3, tint: Color, hp_value: float, damage: int) -> void:
	var clips: Dictionary = moves.clips.duplicate()
	clips.erase("_why")
	var actor := Character3D.new()
	actor.name = label
	actor.tint = tint
	actor.extra_actions = clips
	actor.position = at
	actor.look_target = hero
	actor.can_climb = false
	actor.can_vault = false
	add_child(actor)
	var warning := Label3D.new()
	warning.text = "!"
	warning.font_size = 110
	warning.outline_size = 30
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning.no_depth_test = true
	warning.modulate = UI.key("bad")
	warning.position = Vector3(0, 2.2, 0)
	warning.visible = false
	actor.add_child(warning)
	if label == "Choir":
		var aura := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 1.15
		ring.bottom_radius = 1.15
		ring.height = 0.025
		ring.radial_segments = 24
		aura.mesh = ring
		aura.material_override = _toon(Color("74658f"), false)
		aura.position.y = 0.04
		actor.add_child(aura)
	_foes.append({"actor": actor, "warn": warning, "hp": hp_value, "damage": damage, "attack_cd": 1.2, "windup": 0.0, "dead": false, "kind": label})


func _spawn_realm_props() -> void:
	var plate := Node3D.new()
	plate.name = "CollectionPlate"
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.08
	mesh.radial_segments = 16
	disc.mesh = mesh
	disc.material_override = _toon(Color("b69b58"))
	plate.add_child(disc)
	add_child(plate)
	plate.position = Vector3(-5.0, 0.08, 1.5)
	for item in [{"id": "candle", "at": Vector3(5.0, 0.12, 2.0), "color": Color("d8c27a")},
			{"id": "stained_glass", "at": Vector3(-6.0, 0.12, -3.0), "color": Color("5d91a6")},
			{"id": "censer_chain", "at": Vector3(6.0, 0.12, -5.0), "color": Color("8c8580")}]:
		var prop := Node3D.new()
		prop.name = str(item.id)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.22, 0.45)
		mi.mesh = bm
		mi.material_override = _toon(item.color)
		prop.add_child(mi)
		add_child(prop)
		prop.position = item.at
		prop.set_meta("loot_id", item.id)
		_loot_nodes.append(prop)
	_nearest_plate = plate


func _process(dt: float) -> void:
	super._process(dt)
	if rules == null:
		return
	_nearest_plate = null
	_nearest_loot = null
	var best_plate := 1.5
	if has_node("CollectionPlate"):
		var plate := get_node("CollectionPlate") as Node3D
		var d := hero.global_position.distance_to(plate.global_position)
		if d < best_plate:
			best_plate = d
			_nearest_plate = plate
	var best_loot := 1.5
	for prop in _loot_nodes:
		if not is_instance_valid(prop):
			continue
		var d := hero.global_position.distance_to(prop.global_position)
		if d < best_loot:
			best_loot = d
			_nearest_loot = prop


func _enemy(dt: float) -> void:
	if hero.dead or boss_defeated:
		return
	_foe_ai(dt)
	if _flock_time > 0.0:
		_flock_time = maxf(0.0, _flock_time - dt)
		_flock_cd -= dt
		if _flock_cd <= 0.0:
			_flock_cd = 1.25
			if hero.global_position.distance_to(dummy.global_position) < 2.4:
				_damage_hero(5, dummy.global_position)
		if _flock_time <= 0.0 and _flock_node != null:
			_flock_node.queue_free()
			_flock_node = null
	if not encounter_started:
		var to_hero := hero.global_position - dummy.global_position
		to_hero.y = 0.0
		var distance := to_hero.length()
		var forward := Vector3(sin(dummy.heading), 0, cos(dummy.heading))
		var angle := acos(clampf(forward.dot(to_hero.normalized()), -1.0, 1.0)) if distance > 0.001 else 0.0
		var seen := distance <= 5.0 and angle <= deg_to_rad(30.0)
		rules.tick_stalking(rules.studied, distance, angle, hero.crouching, seen, dt)
		if rules.engaged:
			encounter_started = true
			get_node("/root/Subs").cue("[Vesper spots you]")
		else:
			return
	if _boss_telegraph > 0.0:
		_boss_telegraph -= dt
		if _boss_telegraph <= 0.0:
			_execute_boss_move()
		return
	_boss_cd -= dt
	if _boss_cd <= 0.0:
		_begin_boss_move()


func _foe_ai(dt: float) -> void:
	var choir_alive := false
	var choir_pos := Vector3.ZERO
	for foe in _foes:
		if foe.kind == "Choir" and not foe.dead:
			choir_alive = true
			choir_pos = foe.actor.global_position
	for i in _foes.size():
		var foe: Dictionary = _foes[i]
		if foe.dead:
			continue
		var actor: Character3D = foe.actor
		var to := hero.global_position - actor.global_position
		to.y = 0.0
		var d := to.length()
		if d > 1.4 and d < 5.0:
			actor.heading = atan2(to.x, to.z)
			actor.model.rotation.y = actor.heading
			actor.move_input = Vector2(0, 0.7)
		else:
			actor.move_input = Vector2.ZERO
		if foe.windup > 0.0:
			foe.windup -= dt
			if foe.windup <= 0.0:
				actor.act("enemy_swing")
				foe.warn.visible = false
				var boosted: bool = foe.kind == "Zealot" and choir_alive and choir_pos.distance_to(actor.global_position) < 5.5
				if hero.global_position.distance_to(actor.global_position) < 2.1:
					_damage_hero(int(foe.damage) + (4 if boosted else 0), actor.global_position)
				foe.attack_cd = 2.4
		else:
			foe.attack_cd -= dt
			if d < 1.9 and foe.attack_cd <= 0.0:
				foe.windup = 0.55
				foe.warn.visible = true
				get_node("/root/Subs").cue("[zealot raises its hands]" if foe.kind == "Zealot" else "[choir begins to sing]")
		_foes[i] = foe


func _begin_boss_move() -> void:
	var names := ["sermon", "flock", "laying_of_hands"]
	_boss_move = names[_boss_move_index % names.size()]
	_boss_move_index += 1
	var data: Dictionary = rules.config.boss.moves.get(_boss_move, {})
	_boss_telegraph = maxf(0.5, float(data.get("telegraph", 0.7)))
	_set_occult_halo(true)
	_warn.text = "!"
	_warn.modulate = UI.key("bad")
	_warn.visible = true
	get_node("/root/Audio").sfx("whoosh", 0.8)
	get_node("/root/Subs").cue("[Vesper prepares %s]" % _boss_move.replace("_", " "))


func _execute_boss_move() -> void:
	_set_occult_halo(false)
	_warn.visible = false
	var data: Dictionary = rules.config.boss.moves.get(_boss_move, {})
	dummy.act("enemy_swing")
	var distance := hero.global_position.distance_to(dummy.global_position)
	match _boss_move:
		"sermon":
			if distance < 4.0:
				_damage_hero(int(data.get("damage", 14)), dummy.global_position)
		"flock":
			_flock_time = 4.0
			_flock_cd = 0.5
			if _flock_node != null:
				_flock_node.queue_free()
			_flock_node = Node3D.new()
			_flock_node.name = "FlockShadows"
			_flock_node.position = dummy.position
			add_child(_flock_node)
			for i in 3:
				var shadow := MeshInstance3D.new()
				var orb := SphereMesh.new()
				orb.radius = 0.32
				orb.height = 0.64
				shadow.mesh = orb
				shadow.material_override = _toon(Color("302b3d"), false)
				shadow.position = Vector3(cos(float(i) * TAU / 3.0) * 1.4, 0.8, sin(float(i) * TAU / 3.0) * 1.4)
				_flock_node.add_child(shadow)
			get_node("/root/Subs").cue("[shadows answer the sermon]")
		"laying_of_hands":
			var healed := rules.heal_boss(float(data.get("heal", 18)))
			dummy_hp = rules.boss_hp
			get_node("/root/Subs").cue("[Vesper heals %d]" % int(healed))
	_boss_cd = float(data.get("cooldown", 5.0))


func _damage_hero(amount: int, from_pos: Vector3) -> void:
	if amount <= 0 or _iframes > 0.0 or hero.dead:
		return
	hp = maxi(0, hp - amount)
	hero_hits_taken += 1
	combat.drop_combo()
	hero.hit(from_pos + Vector3(0, 1.2, 0), 0.5)
	get_node("/root/Feel").impact(hero.global_position + Vector3(0, 1.3, 0), 0.5, self)
	hero_hurt.emit(hp)
	if hp <= 0:
		hero.die((hero.global_position - from_pos).normalized() * 3.0 + Vector3(0, 1.5, 0))
		hero_died.emit()


func _check_hit() -> void:
	var before := hits_landed
	super._check_hit()
	# Arena subtracts nonlethal damage from dummy_hp. Keep the boss rules,
	# HUD and checkpoint in sync before returning from this hit.
	if hits_landed != before and not boss_defeated and dummy_hp > 0.0:
		rules.boss_hp = dummy_hp
	if hits_landed != before or _move.is_empty() or _landed or hero.dead:
		return
	if not hero.is_acting(_move.action) or _move_age < float(_move.get("hit_at", 0.0)):
		return
	var reach := combat.reach(_move)
	for i in _foes.size():
		var foe: Dictionary = _foes[i]
		if foe.dead:
			continue
		var actor: Character3D = foe.actor
		var to := actor.global_position - hero.global_position
		to.y = 0.0
		var forward := Vector3(sin(hero.heading), 0, cos(hero.heading))
		var arc := float(_move.get("arc", 120))
		if to.length() > reach or (arc < 360.0 and forward.dot(to.normalized()) <= cos(deg_to_rad(arc / 2.0))):
			continue
		_landed = true
		var result := combat.land(_move)
		foe.hp = float(foe.hp) - float(result.damage)
		actor.hit(hero.global_position + Vector3(0, 1.2, 0), float(result.power))
		get_node("/root/Feel").impact(actor.global_position + Vector3(0, 1.3, 0), float(result.power), self)
		if foe.hp <= 0.0:
			foe.dead = true
			foe.warn.visible = false
			actor.die((actor.global_position - hero.global_position).normalized() * 2.0 + Vector3(0, 1.0, 0))
			get_node("/root/Subs").cue("[%s falls]" % foe.kind.to_lower())
		_foes[i] = foe
		return


func _ko(_result: Dictionary) -> void:
	# Arena already subtracted the lethal blow from dummy_hp. Apply the
	# accumulated phase damage, not just the last hit.
	var state := rules.hit_boss(maxf(0.0, rules.boss_hp - dummy_hp))
	dummy_hp = rules.boss_hp
	if state.phase_changed:
		_set_occult_halo(false)
		dummy.revive()
		dummy.position = Vector3(0, 0, -6.0)
		dummy.heading = PI
		dummy.model.rotation.y = PI
		_warn.visible = false
		get_node("/root/Subs").cue("[Vesper reveals his second form]")
	elif state.defeated:
		_set_occult_halo(false)
		boss_defeated = true
		if _flock_node != null:
			_flock_node.queue_free()
			_flock_node = null
		dummy.die(Vector3(0, 1.2, 2.0))
		_warn.visible = false
		get_node("/root/Subs").cue("[Vesper collapses]")
		ko.emit(kos + 1)


func _input_move(q: Dictionary) -> void:
	if boss_defeated:
		return
	if not encounter_started:
		var nearby_foe := false
		for foe in _foes:
			if not foe.dead and hero.global_position.distance_to(foe.actor.global_position) < 3.2:
				nearby_foe = true
				break
		if not nearby_foe:
			return
	var free_opener: bool = _ambush_free_special and q.get("kind", "") == "special"
	super._input_move(q)
	if free_opener and not last_special.is_empty():
		combat.cooldowns.erase(last_special.get("id", ""))
		_ambush_free_special = false


func context_label() -> String:
	if can_pick_up:
		return "PICK UP"
	if _nearest_plate != null:
		return "COLLECT PLATE"
	if _nearest_loot != null:
		return "SCAVENGE"
	if rules != null and rules.ambush_ready():
		return "AMBUSH"
	if boss_defeated and rules.finisher.is_empty():
		return "FINISH"
	if boss_defeated and not rules.finisher.is_empty() and not rules.eaten:
		return "EAT"
	if portal_ready:
		return "RETURN HOME"
	return ""


func context_visible() -> bool:
	return not context_label().is_empty()


func context_action() -> void:
	if can_pick_up:
		pick_up()
	elif _nearest_plate != null:
		var result := rules.collect_plate()
		_nearest_plate.queue_free()
		_nearest_plate = null
		get_node("/root/Subs").cue("[collection plate: %d cash, %d heat]" % [result.cash, result.heat])
	elif _nearest_loot != null:
		var id := str(_nearest_loot.get_meta("loot_id"))
		var result := rules.scavenge(id)
		_nearest_loot.queue_free()
		_loot_nodes.erase(_nearest_loot)
		_nearest_loot = null
		get_node("/root/Subs").cue("[scavenged %s]" % id.replace("_", " "))
	elif rules.ambush_ready():
		var result := rules.start_ambush()
		encounter_started = true
		_ambush_free_special = bool(result.get("free_first_special", false))
		dummy.act("hit_chest")
		get_node("/root/Subs").cue("[AMBUSH: Vesper is staggered]")
	elif boss_defeated and rules.finisher.is_empty():
		finish_requested.emit()
	elif boss_defeated and not rules.eaten:
		var result := rules.eat()
		if result.get("voice_unlocked", false):
			portal_ready = true
			voice_unlocked.emit()
	elif portal_ready:
		portal_opened.emit()


func choose_finisher(method: String) -> Dictionary:
	return rules.finish(method)


func status_text() -> String:
	if rules == null:
		return ""
	if not encounter_started:
		return "STUDY %d%%" % int(round(rules.studied))
	return "VESPER  PHASE %d  %d HP" % [rules.boss_phase, int(round(rules.boss_hp))]


func save_state() -> Dictionary:
	return {"studied": rules.studied, "phase": rules.boss_phase, "boss_hp": rules.boss_hp,
		"boss_defeated": rules.boss_defeated, "engaged": rules.engaged, "ambush_started": rules.ambush_started,
		"cash": rules.cash, "heat": rules.heat, "parts": rules.parts, "corruption": rules.corruption,
		"inventory": rules.inventory.duplicate(), "trophies": rules.trophies.duplicate(),
		"unlocked_voices": rules.unlocked_voices.duplicate(), "extra_special_slots": rules.extra_special_slots.duplicate(),
		"finisher": rules.finisher, "eaten": rules.eaten, "plates_collected": rules.plates_collected}


func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	rules.studied = float(state.get("studied", 0.0))
	rules.boss_phase = clampi(int(state.get("phase", 1)), 1, 2)
	rules.boss_hp = float(state.get("boss_hp", rules.boss_hp))
	rules.boss_defeated = bool(state.get("boss_defeated", false))
	rules.engaged = bool(state.get("engaged", false))
	rules.ambush_started = bool(state.get("ambush_started", false))
	rules.cash = int(state.get("cash", 0))
	rules.heat = int(state.get("heat", 0))
	rules.parts = int(state.get("parts", 0))
	rules.corruption = int(state.get("corruption", 0))
	rules.inventory = state.get("inventory", {}).duplicate()
	rules.trophies.clear()
	for trophy in state.get("trophies", []):
		rules.trophies.append(str(trophy))
	rules.unlocked_voices.clear()
	for voice_id in state.get("unlocked_voices", []):
		rules.unlocked_voices.append(str(voice_id))
	rules.extra_special_slots = state.get("extra_special_slots", {}).duplicate()
	rules.finisher = str(state.get("finisher", ""))
	rules.eaten = bool(state.get("eaten", false))
	rules.plates_collected = int(state.get("plates_collected", 0))
	encounter_started = rules.engaged
	boss_defeated = rules.boss_defeated
	portal_ready = rules.eaten
	dummy_hp = rules.boss_hp
	if boss_defeated:
		dummy.die(Vector3.ZERO)
	if rules.plates_collected > 0 and has_node("CollectionPlate"):
		get_node("CollectionPlate").queue_free()
	for prop in _loot_nodes.duplicate():
		if rules.inventory.has(str(prop.get_meta("loot_id"))):
			prop.queue_free()
			_loot_nodes.erase(prop)

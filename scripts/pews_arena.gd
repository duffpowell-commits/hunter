extends "res://scripts/hunt_arena.gd"
## The Pews: a playable church encounter built on Hunter's tested combat controller.
## NEW GAME enters this realm. Autoplay also visits the original training arena.

const PewsRules = preload("res://scripts/pews_rules.gd")

signal finish_requested
signal voice_unlocked
signal portal_opened
signal phase_changed            # Vesper's phase break: game.gd checkpoints (M2 review)

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
var hands_healed := 0.0      # last Laying of Hands heal; read by autoplay (PEWS HANDS PASS)
var flock_ticks := 0         # Flock damage ticks that reached the hero; read by autoplay
var last_minion_hit := 0     # damage of the last minion hit on the hero; read by autoplay
var _boss_bar: Node3D
var _heal_pop: Label3D
var heals_broken := 0         # Laying of Hands prayers broken by a hit; read by autoplay
var spotted := false         # Vesper saw the hero before an ambush; read by autoplay


## Layout points live in data/pews.json as [x, y, z]. Why (Nov 23 review): content is data.
static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


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
		elif child is DirectionalLight3D:
			# The fixed top-down camera needs shadows only across the nearby aisle.
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			child.directional_shadow_max_distance = 22.0
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
	add_child(preload("res://scripts/pews_tuning.gd").new(rules.config))
	rules.boss_hp = float(rules.config.boss.phase_hp[0])
	dummy.name = "Vesper"
	# Why re-apply (Nov 23 review): Character3D reads `tint` only while it sets up, so setting it on
	# a dummy already in the tree left Vesper the training dummy's orange.
	dummy.tint = Color("8b718f")
	dummy._mats = Character3D.apply_toon(dummy.model, dummy.tint, dummy.rim, dummy.outline_px)
	_boss_cd = float(rules.config.boss.first_cooldown)
	dummy.position = _v3(rules.config.boss.spawn)
	dummy.heading = PI
	dummy.model.rotation.y = PI
	dummy_hp = rules.boss_hp
	dummy_max_hp = rules.boss_hp
	hero.position = _v3(rules.config.field.hero_spawn)
	hero.heading = PI
	hero.model.rotation.y = PI
	# Zealot spawn moved off the pew collider (was z -1.0, inside it; Nov 23 review).
	_spawn_foe("Zealot", _v3(rules.config.minions.zealot_spawn), Color("a84c42"), float(rules.config.minions.zealot_hp))
	_spawn_foe("Choir", _v3(rules.config.minions.choir_spawn), Color("b5a0d0"), float(rules.config.minions.choir_hp))
	_spawn_realm_props()
	_build_occult_halo()
	_boss_bar = hp_bar(dummy, 2.15, 1.3)
	_enemy_t = 999.0
	apply_profile()


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
	var field: Dictionary = rules.config.field
	plate.position = _v3(field.plate_at)
	for item in [{"id": "candle", "at": _v3(field.loot_at.candle), "color": Color("d8c27a")},
			{"id": "stained_glass", "at": _v3(field.loot_at.stained_glass), "color": Color("5d91a6")},
			{"id": "censer_chain", "at": _v3(field.loot_at.censer_chain), "color": Color("8c8580")}]:
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


func push_tune() -> void:
	dummy_max_hp = float(rules.config.boss.phase_hp[rules.boss_phase - 1])
	super.push_tune()
	rules.boss_hp = minf(rules.boss_hp, dummy_max_hp)


func _process(dt: float) -> void:
	# Nov 26 free-flow pass: SNEAK is a button now (Duff: tilting the stick lightly was too hard).
	# The fight starting stands you up.
	if encounter_started:
		sneak = false
	hero.set_crouch(sneak and not hero.dead)
	super._process(dt)
	if rules != null:
		var phase_max := float(rules.config.boss.phase_hp[clampi(rules.boss_phase - 1, 0, 1)])
		set_hp_bar(_boss_bar, 0.0 if boss_defeated else rules.boss_hp / maxf(phase_max, 1.0))
	_nearest_plate = null
	_nearest_loot = null
	var best_plate := float(rules.config.field.interact_radius)
	if has_node("CollectionPlate"):
		var plate := get_node("CollectionPlate") as Node3D
		var d := hero.global_position.distance_to(plate.global_position)
		if d < best_plate:
			best_plate = d
			_nearest_plate = plate
	var best_loot := float(rules.config.field.interact_radius)
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
			var flock: Dictionary = rules.config.boss.moves.flock
			_flock_cd = float(flock.tick)
			# Why (M2 review): the shadows stayed where they were cast while the damage followed
			# Vesper, and the first tick's knockback threw the hero out of the radius. The damage
			# now sits on the shadows, and a tick's knockback is its own slider (default 0).
			var centre: Vector3 = _flock_node.global_position if _flock_node != null else dummy.global_position
			var flat := hero.global_position - centre
			flat.y = 0.0
			if flat.length() < float(flock.radius):
				if _damage_hero(int(flock.damage), centre, float(flock.knockback)):
					flock_ticks += 1
		if _flock_time <= 0.0 and _flock_node != null:
			_flock_node.queue_free()
			_flock_node = null
	if not encounter_started:
		var to_hero := hero.global_position - dummy.global_position
		to_hero.y = 0.0
		var distance := to_hero.length()
		var forward := Vector3(sin(dummy.heading), 0, cos(dummy.heading))
		var angle := acos(clampf(forward.dot(to_hero.normalized()), -1.0, 1.0)) if distance > 0.001 else 0.0
		var seen := distance <= float(rules.config.stalking.sight_radius) and angle <= deg_to_rad(float(rules.config.stalking.view_cone_degrees) / 2.0)
		rules.tick_stalking(rules.studied, distance, angle, hero.crouching, seen, dt)
		if rules.engaged:
			encounter_started = true
			spotted = true
			get_node("/root/Subs").cue("[Vesper spots you]")
			voice_moment.emit("fight")
		else:
			return
	if _boss_telegraph > 0.0:
		dummy.move_input = Vector2.ZERO
		_boss_telegraph -= dt
		if _boss_telegraph <= 0.0:
			_execute_boss_move()
		return
	_boss_pursue(dt)
	_boss_cd -= dt
	if _boss_cd <= 0.0:
		_begin_boss_move()


## Vesper turns to the hero and closes in between powers. Why (M2 review): he never moved or
## turned, so the fight was a stationary target. Speeds are sliders (boss.turn_speed, walk_speed).
func _boss_pursue(dt: float) -> void:
	if dummy.dead or dummy.is_acting("knockback") or dummy.is_acting("hit_chest"):
		dummy.move_input = Vector2.ZERO
		return
	var boss: Dictionary = rules.config.boss
	var to := hero.global_position - dummy.global_position
	to.y = 0.0
	var want := atan2(to.x, to.z)
	dummy.heading = rotate_toward(dummy.heading, want, float(boss.turn_speed) * dt)
	dummy.model.rotation.y = dummy.heading
	if to.length() > float(boss.keep_distance):
		var way: Array = steer(dummy.global_position, to.normalized(), 0.0, float(rules.config.minions.steer_probe), float(rules.config.minions.steer_margin))
		dummy.move_input = Vector2(way[0].x, way[0].z) * float(boss.walk_speed)
	else:
		dummy.move_input = Vector2.ZERO


## Phase two is the same moveset, faster (boss.phase2_cooldown_scale).
func _cooldown_of(data: Dictionary) -> float:
	var cd := float(data.get("cooldown", 5.0))
	return cd * float(rules.config.boss.phase2_cooldown_scale) if rules.boss_phase >= 2 else cd


func foe_rules() -> Dictionary:
	return rules.config.minions


func _windup_cue(kind: String) -> String:
	return "[zealot raises its hands]" if kind == "Zealot" else "[choir begins to sing]"


func _on_minion_hit(damage: int) -> void:
	last_minion_hit = damage


## A body left in the church is heat (BUILD_SPEC Heat: "leave bodies").
func _on_foe_killed(_foe: Dictionary) -> void:
	_profile_gain({"heat": int(rules.config.heat.body)})


func _begin_boss_move() -> void:
	var names: Array = rules.config.boss.move_order
	_boss_move = names[_boss_move_index % names.size()]
	_boss_move_index += 1
	var data: Dictionary = rules.config.boss.moves.get(_boss_move, {})
	_boss_telegraph = maxf(float(rules.config.boss.min_telegraph), float(data.get("telegraph", 0.7)))
	_set_occult_halo(true)
	# Nov 26 (8.5 pass): the heal gets its own tell (green "+ HEALING", a shape and a word, not
	# just colour), so a first-timer sees it coming and knows to hit him.
	var healing := _boss_move == "laying_of_hands"
	_warn.text = "+ HEALING" if healing else "!"
	_warn.font_size = 90 if healing else 160
	_warn.modulate = UI.key("good") if healing else UI.key("bad")
	_warn.visible = true
	get_node("/root/Audio").sfx("whoosh", 0.8)
	if healing:
		get_node("/root/Subs").cue("[Vesper starts healing: hit him]")
	else:
		get_node("/root/Subs").cue("[Vesper prepares %s]" % _boss_move.replace("_", " "))


func _execute_boss_move() -> void:
	_set_occult_halo(false)
	_warn.visible = false
	var data: Dictionary = rules.config.boss.moves.get(_boss_move, {})
	dummy.act("enemy_swing")
	var distance := hero.global_position.distance_to(dummy.global_position)
	match _boss_move:
		"sermon":
			if distance < float(data.radius):
				_damage_hero(int(data.get("damage", 14)), dummy.global_position)
		"flock":
			_flock_time = float(data.duration)
			_flock_cd = float(data.first_tick)
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
			hands_healed = healed
			dummy_hp = rules.boss_hp
			get_node("/root/Subs").cue("[Vesper heals %d]" % int(healed))
			_pop_heal(healed)
	_boss_cd = _cooldown_of(data)


func _check_hit() -> void:
	var before := hits_landed
	# Until the hunt starts, defensive attacks can hit minions only.
	if encounter_started:
		super._check_hit()
	# Arena subtracts nonlethal damage from dummy_hp. Keep the boss rules,
	# HUD and checkpoint in sync before returning from this hit.
	if hits_landed != before and not boss_defeated and dummy_hp > 0.0:
		rules.boss_hp = dummy_hp
	if hits_landed != before:
		break_heal()
	if hits_landed != before:
		return
	_check_foe_hits()


func _ko(_result: Dictionary) -> void:
	# Arena already subtracted the lethal blow from dummy_hp. Apply the
	# accumulated phase damage, not just the last hit.
	var state := rules.hit_boss(maxf(0.0, rules.boss_hp - dummy_hp))
	dummy_hp = rules.boss_hp
	if state.phase_changed:
		_cancel_boss_attack()
		_clear_flock()
		dummy.revive()
		dummy.position = _v3(rules.config.boss.spawn)
		dummy.heading = PI
		dummy.model.rotation.y = PI
		get_node("/root/Subs").cue("[Vesper reveals his second form]")
		phase_changed.emit()
	elif state.defeated:
		_cancel_boss_attack()
		_clear_flock()
		boss_defeated = true
		for foe in _foes:
			foe.actor.move_input = Vector2.ZERO
			foe.warn.visible = false
		dummy.move_input = Vector2.ZERO
		dummy.die(Vector3(0, 1.2, 2.0))
		get_node("/root/Subs").cue("[Vesper collapses]")
		voice_moment.emit("kill")
		ko.emit(kos + 1)


## DEV MENU SKIP LEVEL: Vesper goes down through the normal phase rules (M2 review: it only
## bumped the training round).
func debug_defeat() -> void:
	if boss_defeated:
		return
	encounter_started = true
	rules.engaged = true
	if rules.boss_phase == 1:
		dummy_hp = 0.0
		_ko({})
	dummy_hp = 0.0
	_ko({})


func _cancel_boss_attack() -> void:
	if _boss_telegraph > 0.0:
		_boss_cd = _cooldown_of(rules.config.boss.moves[_boss_move])
	_boss_telegraph = 0.0
	_boss_move = ""
	_set_occult_halo(false)
	_warn.visible = false


func _clear_flock() -> void:
	_flock_time = 0.0
	if _flock_node != null:
		_flock_node.queue_free()
		_flock_node = null


## A hit on Vesper while he prays breaks the heal (8.5 pass). Returns true when it did.
func break_heal() -> bool:
	if _boss_move != "laying_of_hands" or _boss_telegraph <= 0.0 \
			or int(rules.config.boss.moves.laying_of_hands.get("interrupt", 0)) <= 0:
		return false
	_cancel_boss_attack()
	heals_broken += 1
	get_node("/root/Subs").cue("[you break his prayer]")
	return true


## Floating "+18" over Vesper when a heal lands.
func _pop_heal(amount: float) -> void:
	if amount <= 0.0:
		return
	if _heal_pop == null:
		_heal_pop = Label3D.new()
		_heal_pop.font_size = 96
		_heal_pop.outline_size = 28
		_heal_pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_heal_pop.no_depth_test = true
		dummy.add_child(_heal_pop)
	_heal_pop.text = "+%d" % int(amount)
	_heal_pop.modulate = UI.key("good")
	_heal_pop.position = Vector3(0, 2.4, 0)
	_heal_pop.visible = true
	var tw := create_tween()
	tw.tween_property(_heal_pop, "position:y", 3.2, 0.9)
	tw.tween_callback(func(): _heal_pop.visible = false)


func foes_all_aggro() -> bool:
	return encounter_started


## Soft aim (Nov 26, 8.5 pass): in the fight, a swing turns to the nearest enemy in reach,
## Vesper or a minion, instead of always Vesper.
func _attack_target() -> Character3D:
	if encounter_started:
		var best: Character3D = super._attack_target()
		var nearest := INF if best == null else hero.global_position.distance_to(best.global_position)
		for foe in _foes:
			if foe.dead:
				continue
			var d: float = hero.global_position.distance_to(foe.actor.global_position)
			if d < nearest:
				nearest = d
				best = foe.actor
		return best
	var target: Character3D
	var nearest := float(rules.config.field.prefight_target_range)
	for foe in _foes:
		if foe.dead:
			continue
		var distance: float = hero.global_position.distance_to(foe.actor.global_position)
		if distance < nearest:
			nearest = distance
			target = foe.actor
	return target


func _input_move(q: Dictionary) -> void:
	if boss_defeated or (not encounter_started and lunge_target() == null):
		return
	var previous_special := last_special
	super._input_move(q)
	if _ambush_free_special and not is_same(last_special, previous_special):
		combat.cooldowns.erase(last_special.get("id", ""))
		_ambush_free_special = false


# ---------------------------------------------------------------- free-flow hooks (Nov 26)

## Before the fight a strike can only reach the minions: Vesper is stalked, not struck.
func _targets() -> Array[Character3D]:
	var out := super._targets()
	if not encounter_started or boss_defeated:
		out.erase(dummy)
	return out


func _sight_targets() -> Array[Character3D]:
	var out := super._sight_targets()
	if boss_defeated:
		out.erase(dummy)
	return out


func stealth_allowed() -> bool:
	return not encounter_started and not boss_defeated


func alertness(t: Character3D) -> String:
	if t == dummy:
		if not encounter_started:
			return "unaware"
		return "attacking" if _boss_telegraph > 0.0 else "hunting"
	return super.alertness(t)


## Vesper's powers can be countered while his warning is up; a countered prayer counts as broken.
func _counter_threat() -> Character3D:
	# A prayer set to unbreakable (hands_interrupt 0) can't be countered either (fresh-eyes).
	var unbreakable: bool = _boss_move == "laying_of_hands" \
		and int(rules.config.boss.moves.laying_of_hands.get("interrupt", 0)) <= 0
	if encounter_started and not boss_defeated and _boss_telegraph > 0.0 and not dummy.dead \
			and not unbreakable and _flat_dist(dummy) <= counter_range:
		return dummy
	return super._counter_threat()


func _cancel_threat(t: Character3D) -> void:
	if t != dummy:
		super._cancel_threat(t)
		return
	if not break_heal():
		_cancel_boss_attack()
	dummy.act("hit_chest")


func _damage_dummy(r: Dictionary) -> void:
	if not encounter_started or boss_defeated:
		return
	super._damage_dummy(r)
	if not boss_defeated and dummy_hp > 0.0:
		rules.boss_hp = dummy_hp
	break_heal()


func _special_move(dir: String) -> Dictionary:
	return combat.special(dir, _ambush_free_special)


func context_label() -> String:
	var combo_c := combo_move()
	if not combo_c.is_empty() and not boss_defeated:
		return combo_c
	if can_pick_up:
		return "PICK UP"
	if _nearest_plate != null:
		return "COLLECT PLATE"
	if _nearest_loot != null:
		return "SCAVENGE"
	if silent_target() >= 0:
		return "SILENT KILL"
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
	if not combo_move().is_empty() and not boss_defeated:
		combo_action()
	elif can_pick_up:
		pick_up()
	elif _nearest_plate != null:
		var result := rules.collect_plate()
		_nearest_plate.queue_free()
		_nearest_plate = null
		_profile_gain({"cash": result.cash, "heat": result.heat})
		get_node("/root/Subs").cue("[collection plate: %d cash, %d heat]" % [result.cash, result.heat])
	elif _nearest_loot != null:
		var id := str(_nearest_loot.get_meta("loot_id"))
		var result := rules.scavenge(id)
		# Searching is noisy (BUILD_SPEC Heat). The item goes in the bag if it fits; parts always count.
		var prof := get_node_or_null("/root/Profile")
		if prof != null and not result.is_empty():
			LairRules.add_item(prof.data, id, 1, GameData.load_json("lair"))
		_profile_gain({"parts": int(result.get("parts", 0)), "heat": int(rules.config.heat.scavenge)})
		_nearest_loot.queue_free()
		_loot_nodes.erase(_nearest_loot)
		_nearest_loot = null
		get_node("/root/Subs").cue("[scavenged %s]" % id.replace("_", " "))
	elif silent_target() >= 0:
		silent_kill()
	elif rules.ambush_ready():
		var result := rules.start_ambush()
		encounter_started = true
		_ambush_free_special = bool(result.get("free_first_special", false))
		dummy.act("hit_chest")
		get_node("/root/Subs").cue("[AMBUSH: Vesper is staggered]")
		voice_moment.emit("fight")
	elif boss_defeated and rules.finisher.is_empty():
		finish_requested.emit()
	elif boss_defeated and not rules.eaten:
		var result := rules.eat()
		if result.get("voice_unlocked", false):
			var prof := get_node_or_null("/root/Profile")
			if prof != null:
				LairRules.add_voice(prof.data, str(result.voice_id))
			_profile_gain({"corruption": int(result.get("corruption", 0))})
			portal_ready = true
			voice_unlocked.emit()
	elif portal_ready:
		portal_opened.emit()


func choose_finisher(method: String) -> Dictionary:
	var result := rules.finish(method)
	if result.is_empty():
		return result
	var prof := get_node_or_null("/root/Profile")
	if prof != null:
		if bool(result.trophy):
			LairRules.add_trophy(prof.data, str(result.trophy_id))
		if int(result.extra_special_slots) > 0:
			var voice_id := str(rules.config.voice.id)
			prof.data.voice_levels[voice_id] = int(prof.data.voice_levels.get(voice_id, 0)) + int(result.extra_special_slots)
	_profile_gain({"corruption": int(result.corruption), "parts": int(result.parts)})
	return result


## Rewards go straight into the profile, so NEW GAME and GAME OVER can't take them (M2 review).
func _profile_gain(delta: Dictionary) -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return
	LairRules.gain(prof.data, delta)
	prof.save()


func status_text() -> String:
	if rules == null:
		return ""
	if not encounter_started:
		return "GOAL: HUNT VESPER  STUDY %d%%" % int(round(rules.studied))
	return "VESPER  PHASE %d  %d HP" % [rules.boss_phase, int(round(rules.boss_hp))]


func save_state() -> Dictionary:
	return {"studied": rules.studied, "phase": rules.boss_phase, "boss_hp": rules.boss_hp,
		"boss_defeated": rules.boss_defeated, "engaged": rules.engaged, "ambush_started": rules.ambush_started,
		"ambush_free_special": _ambush_free_special,
		"finisher": rules.finisher, "eaten": rules.eaten, "plates_collected": rules.plates_collected,
		# Save v4 (M3): rewards live in Profile now; the run keeps only what it looted, so the
		# props stay gone on CONTINUE.
		"looted": rules.inventory.keys(),
		# Why (Nov 23 review): a mid-fight CONTINUE brought dead minions back.
		"dead_foes": _foes.filter(func(f): return f.dead).map(func(f): return f.kind),
		# Why (M2 review): a mid-fight CONTINUE put the hero back at the door.
		"hero_at": [hero.position.x, hero.position.y, hero.position.z],
		"boss_at": [dummy.position.x, dummy.position.y, dummy.position.z]}


func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	rules.studied = float(state.get("studied", 0.0))
	rules.boss_phase = clampi(int(state.get("phase", 1)), 1, 2)
	rules.boss_hp = float(state.get("boss_hp", rules.boss_hp))
	rules.boss_defeated = bool(state.get("boss_defeated", false))
	rules.engaged = bool(state.get("engaged", false))
	rules.ambush_started = bool(state.get("ambush_started", false))
	_ambush_free_special = bool(state.get("ambush_free_special", false))
	rules.inventory = {}
	for id in state.get("looted", state.get("inventory", {}).keys()):
		rules.inventory[str(id)] = 1
	rules.finisher = str(state.get("finisher", ""))
	rules.eaten = bool(state.get("eaten", false))
	rules.plates_collected = int(state.get("plates_collected", 0))
	encounter_started = rules.engaged
	boss_defeated = rules.boss_defeated
	portal_ready = rules.eaten
	dummy_hp = rules.boss_hp
	if state.has("hero_at"):
		hero.position = _v3(state.hero_at)
	if state.has("boss_at") and not boss_defeated:
		dummy.position = _v3(state.boss_at)
	if boss_defeated:
		dummy.die(Vector3.ZERO)
	var dead_foes: Array = state.get("dead_foes", [])
	for i in _foes.size():
		if dead_foes.has(_foes[i].kind):
			_foes[i].dead = true
			_foes[i].warn.visible = false
			_foes[i].actor.die(Vector3.ZERO)
	if rules.plates_collected > 0 and has_node("CollectionPlate"):
		get_node("CollectionPlate").queue_free()
	for prop in _loot_nodes.duplicate():
		if rules.inventory.has(str(prop.get_meta("loot_id"))):
			prop.queue_free()
			_loot_nodes.erase(prop)

extends "res://scripts/arena.gd"
## Hunter M3 (Nov 23): what The Pews and the lair share on top of the training arena.
##   - Minions (`_foes`): spawn, chase with simple steering round solid props, wind up, hit.
##     Moved here from pews_arena.gd so the lair raid uses the same fight code. Why steering (M2
##     review): minions walked straight at the hero and snagged on pews.
##   - The profile reaches the fight: trophy perks (special damage, max HP), workshop durability,
##     equipped voices on the UP/DOWN swipes (BRUTAL levels add damage), corruption tint and horns.
##   - Voice moments (fight start, low HP, big combo, boss kill) go out as `voice_moment`;
##     game.gd shows the line of an equipped voice.
##   - tune_spec(): the training dummy's sliders are dropped here (they did nothing; M2 review).

const LairRules = preload("res://scripts/lair_rules.gd")

signal voice_moment(kind: String)

const DUMMY_ONLY := ["enemy_attack_every", "enemy_telegraph", "enemy_damage", "dummy_max_hp"]

var _foes: Array[Dictionary] = []
var obstacles: Array[AABB] = []          # solid props foes steer round (filled by _box)
var durability_bonus := 0                # workshop upgrades (reinforced grip)
var low_hp_said := false
var combo_said := false
var horns: Node3D
var low_hp_at := 0.3                     # share of max HP that triggers the low-HP voice line
var combo_line_at := 5.0                   # hits in a combo that trigger the big-combo voice line
var _equipped_dirs := {}                 # swipe dir -> voice id (read by tests and the HUD)


func tune_spec() -> Dictionary:
	var spec: Dictionary = TUNE.duplicate()
	for k in DUMMY_ONLY:
		spec.erase(k)
	spec.merge(EXTRA_TUNE)
	return spec


const EXTRA_TUNE := {"low_hp_at": [0.1, 0.6], "combo_line_at": [2.0, 15.0, 1.0]}


## Every solid box also becomes an obstacle for foe steering (the floor is ignored: it's low).
func _box(a: Vector3, b: Vector3, c: Color, solid := true) -> Node3D:
	var n := super._box(a, b, c, solid)
	if solid and maxf(a.y, b.y) > 0.3:
		var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
		var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
		obstacles.append(AABB(lo, hi - lo))
	return n


## The minion numbers this arena uses (pews.json "minions" or lair.json "raid").
func foe_rules() -> Dictionary:
	return {}


# ---------------------------------------------------------------- the profile in the fight

func _ready() -> void:
	super._ready()
	add_child(preload("res://scripts/lair_tuning.gd").new())


## Reads Profile at the start of the scene: full HP at the perk-raised max, the loadout, the look.
## Works without the autoload (tests on a bare arena).
func apply_profile() -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return
	_apply_loadout()
	hp = max_hp
	apply_corruption(int(prof.data.corruption))


## Voices on the swipes, trophy perks, workshop durability. Re-run twice a second from push_tune so
## the lair_tuning sliders act live.
func _apply_loadout() -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return
	var p: Dictionary = prof.data
	var perk := LairRules.perks(p, GameData.load_json("trophies"))
	# Our own copy: GameData caches moves.json, and the training arena must keep the base kit.
	moves = GameData.load_json("moves").duplicate(true)
	combat.moves = moves
	_equipped_dirs = LairRules.voice_slots(p)
	for dir in _equipped_dirs:
		var id: String = _equipped_dirs[dir]
		var m := LairRules.voice_move(GameData.load_json("voices/" + id), int(p.voice_levels.get(id, 0)))
		if not m.is_empty():
			moves.specials[dir] = m
	for dir in moves.specials:
		var s: Dictionary = moves.specials[dir]
		s.damage = float(s.damage) * (1.0 + float(perk.special_damage))
	max_hp = int(moves.player.hp) + int(perk.max_hp)
	hp = mini(hp, max_hp)
	durability_bonus = LairRules.durability_bonus(p, GameData.load_json("recipes"))


## The hero's tint and horns follow corruption (BUILD_SPEC: 3 looks).
func apply_corruption(corruption: int) -> void:
	var lair := GameData.load_json("lair")
	var band := LairRules.corruption_band(corruption, lair)
	var look: Dictionary = lair.corruption.looks[band]
	hero.tint = Color(str(look.hero_tint))
	hero._mats = Character3D.apply_toon(hero.model, hero.tint, hero.rim, hero.outline_px)
	_set_horns(float(look.horn_scale))


func _set_horns(s: float) -> void:
	if horns == null:
		var att := BoneAttachment3D.new()
		att.name = "Horns"
		att.bone_name = "Head"
		hero.skeleton.add_child(att)
		horns = att
		for side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.045
			cone.height = 0.22
			cone.radial_segments = 8
			horn.mesh = cone
			horn.material_override = _toon(Color("2a1414"))
			horn.position = Vector3(side * 0.07, 0.17, 0.02)
			horn.rotation = Vector3(-0.35, 0, -side * 0.45)
			att.add_child(horn)
	horns.visible = s > 0.01
	horns.scale = Vector3.ONE * maxf(s, 0.01)


var _loadout_t := 0.0


func push_tune() -> void:
	super.push_tune()
	_loadout_t -= get_process_delta_time()
	if _loadout_t <= 0.0:
		_loadout_t = 0.5
		_apply_loadout()
	combat.durability_max += durability_bonus


func _process(dt: float) -> void:
	super._process(dt)
	if not low_hp_said and hp > 0 and float(hp) <= float(max_hp) * low_hp_at:
		low_hp_said = true
		voice_moment.emit("low_hp")
	if not combo_said and combo_count() >= int(combo_line_at):
		combo_said = true
		voice_moment.emit("combo")


# ---------------------------------------------------------------- minions

func _spawn_foe(label: String, at: Vector3, tint: Color, hp_value: float) -> void:
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
	_foes.append({"actor": actor, "warn": warning, "hp": hp_value, "max_hp": hp_value,
		"attack_cd": float(foe_rules().first_attack_delay), "windup": 0.0, "dead": false, "kind": label, "side": 0.0})


## A point is blocked when it is inside a solid prop grown by `margin` (top-down, y ignored).
func blocked(p: Vector3, margin: float) -> bool:
	for box in obstacles:
		if p.x > box.position.x - margin and p.x < box.end.x + margin \
				and p.z > box.position.z - margin and p.z < box.end.z + margin:
			return true
	return false


## Which way to walk from `from` when the hero is along `dir` (flat, unit). Straight when clear;
## else the first clear heading turning to `side` (+1 left / -1 right; 0 = pick one and keep it).
## Returns [heading, side] so the foe keeps turning the same way round a pew instead of dithering.
func steer(from: Vector3, dir: Vector3, side: float, probe: float, margin: float) -> Array:
	if not blocked(from + dir * probe, margin):
		return [dir, 0.0]
	var sides := [side] if side != 0.0 else [1.0, -1.0]
	for s: float in sides:
		for step in [0.6, 1.1, 1.57, 2.1]:
			var d := dir.rotated(Vector3.UP, s * float(step))
			if not blocked(from + d * probe, margin):
				return [d, s]
	return [dir.rotated(Vector3.UP, (sides[0] as float) * 1.57), sides[0]]


func _foe_ai(dt: float) -> void:
	var minions := foe_rules()
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
		var key: String = foe.kind.to_lower()
		var tuned_hp := float(minions[key + "_hp"])
		foe.hp = clampf(foe.hp + tuned_hp - foe.max_hp, 1.0, tuned_hp)
		foe.max_hp = tuned_hp
		var actor: Character3D = foe.actor
		var to := hero.global_position - actor.global_position
		to.y = 0.0
		var d := to.length()
		if d > float(minions.chase_min) and d < float(minions.chase_max):
			var way: Array = steer(actor.global_position, to / d, float(foe.get("side", 0.0)),
				float(minions.get("steer_probe", 0.8)), float(minions.get("steer_margin", 0.35)))
			var heading: Vector3 = way[0]
			foe.side = way[1]
			actor.heading = atan2(heading.x, heading.z)
			actor.model.rotation.y = actor.heading
			actor.move_input = Vector2(heading.x, heading.z) * float(minions.chase_speed)
		else:
			actor.move_input = Vector2.ZERO
		if foe.windup > 0.0:
			foe.windup -= dt
			if foe.windup <= 0.0:
				actor.act("enemy_swing")
				foe.warn.visible = false
				var boosted: bool = foe.kind == "Zealot" and choir_alive and choir_pos.distance_to(actor.global_position) < float(minions.choir_buff_radius)
				if hero.global_position.distance_to(actor.global_position) < float(minions.hit_range):
					var damage := int(minions[key + "_damage"]) + (int(minions.choir_bonus_damage) if boosted else 0)
					if _damage_hero(damage, actor.global_position):
						_on_minion_hit(damage)
				foe.attack_cd = float(minions.attack_cooldown)
		else:
			foe.attack_cd -= dt
			if d < float(minions.attack_range) and foe.attack_cd <= 0.0:
				foe.windup = float(minions.attack_windup)
				foe.warn.visible = true
				get_node("/root/Subs").cue(_windup_cue(foe.kind))
		_foes[i] = foe


func _windup_cue(kind: String) -> String:
	return "[%s winds up]" % kind.to_lower()


func _on_minion_hit(_damage: int) -> void:
	pass


func _on_foe_killed(_foe: Dictionary) -> void:
	pass


## The swing in progress lands on the first foe in reach and in front (once per swing).
func _check_foe_hits() -> void:
	if _move.is_empty() or _landed or hero.dead:
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
		var result := _land_hit(actor)
		foe.hp = float(foe.hp) - float(result.damage)
		if foe.hp <= 0.0:
			kill_foe(i)
		else:
			_foes[i] = foe
		return


func kill_foe(i: int) -> void:
	var foe: Dictionary = _foes[i]
	foe.dead = true
	foe.warn.visible = false
	foe.windup = 0.0
	foe.actor.move_input = Vector2.ZERO
	foe.actor.die((foe.actor.global_position - hero.global_position).normalized() * 2.0 + Vector3(0, 1.0, 0))
	get_node("/root/Subs").cue("[%s falls]" % foe.kind.to_lower())
	_foes[i] = foe
	_on_foe_killed(foe)


## Returns true when the hit landed (not dodged, not God mode), so callers can count real hits.
## `power` is the knockback (Flock ticks pass their own, M2 review).
func _damage_hero(amount: int, from_pos: Vector3, power := 0.5) -> bool:
	if amount <= 0 or _iframes > 0.0 or hero.dead or get_node("/root/DebugMenu").god_mode:
		return false
	hp = maxi(0, hp - amount)
	hero_hits_taken += 1
	combat.drop_combo()
	hero.hit(from_pos + Vector3(0, 1.2, 0), power)
	get_node("/root/Feel").impact(hero.global_position + Vector3(0, 1.3, 0), maxf(power, 0.2), self)
	hero_hurt.emit(hp)
	if hp <= 0:
		hero.die((hero.global_position - from_pos).normalized() * 3.0 + Vector3(0, 1.5, 0))
		hero_died.emit()
	return true


## A crafted poultice: heals, never past max HP. Returns HP gained.
func heal(amount: int) -> int:
	if hero.dead or amount <= 0:
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp > before:
		low_hp_said = float(hp) <= float(max_hp) * low_hp_at
	return hp - before

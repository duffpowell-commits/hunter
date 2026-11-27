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
const FurfurRules = preload("res://scripts/furfur_rules.gd")

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
var silent_kills := 0                    # SILENT KILLs (sneak up on an unaware minion; Nov 26)
var fox: Node3D                          # Cain's pet (fox_pet.gd; Nov 26), in the Pews and the lair


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
	add_child(preload("res://scripts/gus_tuning.gd").new(GameData.load_json("voices/gus")))
	fox = preload("res://scripts/fox_pet.gd").new()
	fox.setup(self, hero)
	add_child(fox)


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
	# M4: every VENT on Furfur adds a hit to the end of the light string (L, L, L, then these).
	moves.light.append_array(FurfurRules.light_extras(p, GameData.load_json("furfur")))
	_equipped_dirs = LairRules.voice_slots(p)
	for dir in _equipped_dirs:
		var id: String = _equipped_dirs[dir]
		var m := LairRules.voice_move(GameData.load_json("voices/" + id), int(p.voice_levels.get(id, 0)))
		if not m.is_empty():
			moves.specials[dir] = m
			if id == "gus":
				var extra: Dictionary = GameData.load_json("voices/gus").get("extra_specials", {})
				for other in extra:
					moves.specials[other] = LairRules.voice_move({"special": extra[other]}, int(p.voice_levels.get(id, 0)))
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
	var bar := hp_bar(actor, 2.0, 0.9)
	_foes.append({"actor": actor, "warn": warning, "hp": hp_value, "max_hp": hp_value, "bar": bar,
		"aggro": float(foe_rules().get("aggro_radius", 0.0)) <= 0.0,
		"attack_cd": float(foe_rules().first_attack_delay), "windup": 0.0, "dead": false, "kind": label, "side": 0.0})


## A billboard HP bar over a character (Nov 26, 8.5 pass: the first-timer couldn't tell who was
## hurt). The camera never turns, so the fill shrinks toward world -x, which is screen-left.
func hp_bar(parent: Node3D, height: float, width: float) -> Node3D:
	var bar := Node3D.new()
	bar.name = "HPBar"
	bar.position = Vector3(0, height, 0)
	bar.set_meta("width", width)
	for part in [["Back", Color(0, 0, 0, 0.75), 0.13, 0], ["Fill", UI.key("bad"), 0.08, 1]]:
		var q := MeshInstance3D.new()
		q.name = part[0]
		var m := QuadMesh.new()
		m.size = Vector2(width + (0.06 if part[3] == 0 else 0.0), part[2])
		q.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.no_depth_test = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = part[1]
		mat.render_priority = part[3]
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.add_child(q)
	parent.add_child(bar)
	return bar


static func set_hp_bar(bar: Node3D, ratio: float) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	ratio = clampf(ratio, 0.0, 1.0)
	bar.visible = ratio > 0.0
	var fill := bar.get_node("Fill") as Node3D
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -(1.0 - ratio) * float(bar.get_meta("width")) / 2.0


## True when every minion should fight now (the Pews: once Vesper's fight starts).
func foes_all_aggro() -> bool:
	return false


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
		set_hp_bar(foe.get("bar"), foe.hp / foe.max_hp)
		var to := hero.global_position - actor.global_position
		to.y = 0.0
		var d := to.length()
		# Nov 26 (8.5 pass): minions wait until you come close, hit them, or the fight starts.
		# Free-flow pass: SNEAK shrinks how close you can get (sneak_aggro_scale).
		if foe.get("aggro", true) != true:
			var notice := float(minions.get("aggro_radius", 0.0))
			if hero.crouching:
				notice *= float(minions.get("sneak_aggro_scale", 1.0))
			if d < notice or foe.hp < foe.max_hp or foes_all_aggro():
				foe.aggro = true
				get_node("/root/Subs").cue("[%s turns on you]" % foe.kind.to_lower())
			else:
				actor.move_input = Vector2.ZERO
				_foes[i] = foe
				continue
		if d > float(minions.get(key + "_chase_min", minions.chase_min)) and d < float(minions.chase_max):
			var way: Array = steer(actor.global_position, to / d, float(foe.get("side", 0.0)),
				float(minions.get("steer_probe", 0.8)), float(minions.get("steer_margin", 0.35)))
			var heading: Vector3 = way[0]
			foe.side = way[1]
			actor.heading = atan2(heading.x, heading.z)
			actor.model.rotation.y = actor.heading
			actor.move_input = Vector2(heading.x, heading.z) * float(minions.get(key + "_chase_speed", minions.chase_speed))
		else:
			actor.move_input = Vector2.ZERO
		if foe.windup > 0.0:
			foe.windup -= dt
			if foe.windup <= 0.0:
				actor.act("enemy_swing")
				foe.warn.visible = false
				var boosted: bool = foe.kind == "Zealot" and choir_alive and choir_pos.distance_to(actor.global_position) < float(minions.choir_buff_radius)
				if hero.global_position.distance_to(actor.global_position) < float(minions.get(key + "_hit_range", minions.hit_range)):
					var damage := int(minions[key + "_damage"]) + (int(minions.choir_bonus_damage) if boosted else 0)
					if _damage_hero(damage, actor.global_position):
						_on_minion_hit(damage)
				foe.attack_cd = float(minions.attack_cooldown)
		else:
			foe.attack_cd -= dt
			if d < float(minions.get(key + "_attack_range", minions.attack_range)) and foe.attack_cd <= 0.0:
				foe.windup = float(minions.get(key + "_attack_windup", minions.attack_windup))
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
	if _move.is_empty() or _landed or hero.dead or _move.get("id", "") == "voice_gus_edge":
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
		_damage_foe(i, float(result.damage))
		return


func _damage_foe(i: int, damage: float) -> void:
	var foe: Dictionary = _foes[i]
	if foe.dead:
		return
	foe.hp = float(foe.hp) - damage
	if foe.hp <= 0.0:
		_foes[i] = foe
		kill_foe(i)
	else:
		_foes[i] = foe


func _foe_index(actor: Node) -> int:
	for i in _foes.size():
		if _foes[i].actor == actor:
			return i
	return -1


func _apply_damage(target: Character3D, r: Dictionary) -> void:
	var i := _foe_index(target)
	if i >= 0:
		_damage_foe(i, float(r.damage))
	else:
		super._apply_damage(target, r)


# ---------------------------------------------------------------- free-flow hooks (Nov 26)

func _sight_targets() -> Array[Character3D]:
	var out := super._sight_targets()
	for foe in _foes:
		if not foe.dead:
			out.append(foe.actor)
	return out


func _counter_threat() -> Character3D:
	var best: Character3D = null
	var best_d := counter_range
	for foe in _foes:
		if foe.dead or float(foe.windup) <= 0.0:
			continue
		var d := _flat_dist(foe.actor)
		if d <= best_d:
			best_d = d
			best = foe.actor
	return best if best != null else super._counter_threat()


func _cancel_threat(t: Character3D) -> void:
	var i := _foe_index(t)
	if i < 0:
		super._cancel_threat(t)
		return
	var foe: Dictionary = _foes[i]
	foe.windup = 0.0
	foe.warn.visible = false
	foe.attack_cd = float(foe_rules().get("attack_cooldown", 2.0))
	_foes[i] = foe


func alertness(t: Character3D) -> String:
	var i := _foe_index(t)
	if i < 0:
		return super.alertness(t)
	var foe: Dictionary = _foes[i]
	if float(foe.windup) > 0.0:
		return "attacking"
	return "hunting" if foe.get("aggro", true) == true else "unaware"


## True where sneaking up on minions counts (the Pews before the fight).
func stealth_allowed() -> bool:
	return false


## The unaware minion a SILENT KILL would take (-1 = none): sneaking, within silent_range.
func silent_target() -> int:
	if not stealth_allowed() or not hero.crouching or hero.dead:
		return -1
	var best := -1
	var best_d := silent_range
	for i in _foes.size():
		var foe: Dictionary = _foes[i]
		if foe.dead or foe.get("aggro", true) == true:
			continue
		var d := _flat_dist(foe.actor)
		if d <= best_d:
			best_d = d
			best = i
	return best


## Sneak up on an unaware minion and drop it without a sound: nobody else turns.
func silent_kill() -> bool:
	var i := silent_target()
	if i < 0:
		return false
	var actor: Character3D = _foes[i].actor
	_face(actor.global_position - hero.global_position)
	hero.act("heavy")
	silent_kills += 1
	get_node("/root/Subs").cue("[silent takedown]")
	kill_foe(i)
	return true


func kill_foe(i: int) -> void:
	var foe: Dictionary = _foes[i]
	foe.dead = true
	foe.warn.visible = false
	set_hp_bar(foe.get("bar"), 0.0)
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
	if _move.get("id", "") == "voice_gus_edge" and _move_age < float(_move.get("recover", 0.0)) and not _landed:
		var attacker: Character3D
		var nearest := float(_move.get("counter_range", 1.0))
		for target in _targets():
			var distance := target.global_position.distance_to(from_pos)
			if distance < nearest and hero.global_position.distance_to(target.global_position) <= float(_move.get("reach",2.5)):
				nearest = distance
				attacker = target
		if is_instance_valid(attacker):
			_apply_damage(attacker, _land_hit(attacker))
			get_node("/root/Subs").cue("[House Edge counter]")
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


func _check_hit() -> void:
	if _move.get("id", "") == "voice_gus_edge":
		return
	if _move.get("id", "") != "voice_gus_dice":
		super._check_hit()
		return
	if _landed or hero.dead or not hero.is_acting(_move.action) or _move_age < float(_move.get("hit_at", 0.0)):
		return
	var forward := Vector3(sin(hero.heading), 0, cos(hero.heading))
	var reach := combat.reach(_move)
	var targets: Array[Character3D] = []
	for target in _targets():
		var delta := target.position - hero.position
		delta.y = 0
		if delta.length() <= reach and forward.dot(delta.normalized()) >= cos(deg_to_rad(float(_move.arc)/2.0)):
			targets.append(target)
	if not targets.is_empty():
		var hit := _land_hit(targets[0])
		_dice_shot_fx(forward, reach)
		for target in targets:
			if target != targets[0]:
				target.hit(hero.global_position + Vector3(0,1.2,0),float(hit.power))
			_apply_damage(target, hit)


func _dice_shot_fx(forward: Vector3, reach: float) -> void:
	for offset in [-1.0,0.0,1.0]:
		var die := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18,0.18,0.18)
		die.mesh = mesh
		die.material_override = _toon(Color("f2d6b1"))
		add_child(die)
		die.position = hero.position + Vector3(0,0.8,0)
		var direction := forward.rotated(Vector3.UP, deg_to_rad(float(_move.arc)*0.4)*offset)
		var tween := create_tween()
		tween.tween_property(die,"position",die.position + direction*reach,float(_move.get("recover",0.5)))
		tween.tween_callback(die.queue_free)

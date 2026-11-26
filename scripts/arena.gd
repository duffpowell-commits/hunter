extends Node3D
## Hunter Milestone 1: the 3D test arena (docs/BUILD_SPEC.md M1). game.gd puts it under the game
## screen and feeds it the stick and pad. Ink-and-blood look (toon + outline, orange rim on the
## hero), fixed high three-quarter camera (CameraRig, 50 degrees down), the template's Character3D
## for the hero and the dummy, one improvised weapon (a pipe) that breaks, combo counting,
## hit-stop and shake through Feel. Every number comes from data/*.json; the live ones are in TUNE.
## Why (Nov 21): reuse the starter's Character3D, CameraRig and Feel instead of rebuilding them;
## this file only adds Hunter's rules (combat.gd) and the arena.

signal ko(count: int)
signal hero_hurt(hp: int)
signal hero_died
signal weapon_changed(id: String, durability: int)

const Character3D = preload("res://scripts/character3d.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Combat = preload("res://scripts/combat.gd")
const GameData = preload("res://scripts/game_data.gd")
const UI = preload("res://scripts/ui.gd")
const TOON = preload("res://shaders/toon.gdshader")
const OUTLINE = preload("res://shaders/outline.gdshader")
const SIZE := 12.0                     # half-width of the arena floor (m)

## Live sliders in DEV MENU -> TUNE. Hit-stop, shake and sparks are Feel's sliders. push_tune()
## copies these into combat and the dummy every frame; game.gd copies the pad ones every frame.
## Why (review of 95847e0): every number you feel gets a live slider (AGENTS.md, standards/03).
const TUNE := {"enemy_attack_every": [0.5, 8.0], "enemy_telegraph": [0.2, 1.5], "enemy_damage": [0.0, 40.0],
	"combo_gap": [0.4, 3.0], "cancel_window": [0.1, 1.0], "cancel_bonus": [0.0, 1.0], "string_gap": [0.3, 2.0],
	"hold_time": [0.15, 0.8], "swipe_min": [20.0, 160.0], "double_tap": [0.0, 0.4],
	"dodge_iframes": [0.0, 0.6], "dodge_cooldown": [0.1, 2.0], "damage_scale": [0.25, 4.0],
	"dummy_max_hp": [10.0, 300.0], "pipe_durability": [1.0, 20.0], "break_mult": [1.0, 5.0],
	# Nov 26 free-flow pass (data/moves.json "freeflow").
	"lunge_range": [0.0, 10.0], "lunge_speed": [4.0, 30.0], "lunge_cone": [10.0, 120.0],
	"counter_range": [1.0, 8.0], "counter_damage": [0.0, 60.0], "counter_iframes": [0.0, 1.0],
	"counter_whiff_lock": [0.0, 2.0], "takedown_at": [2.0, 15.0, 1.0], "finisher_at": [3.0, 25.0, 1.0],
	"takedown_damage": [0.0, 150.0], "finisher_damage": [0.0, 150.0], "finisher_radius": [1.0, 8.0],
	"lunge_max_time": [0.1, 1.5], "counter_power": [0.0, 1.5], "silent_range": [0.5, 4.0]}

var enemy_attack_every := 2.5
var enemy_telegraph := 0.6
var enemy_damage := 10.0
var combo_gap := 1.2
var cancel_window := 0.35
var cancel_bonus := 0.25
var string_gap := 0.8
var hold_time := 0.3
var swipe_min := 60.0
var double_tap := 0.2
var dodge_iframes := 0.25
var dodge_cooldown := 0.6
var damage_scale := 1.0
var dummy_max_hp := 60.0
var pipe_durability := 4.0
var break_mult := 2.5
var lunge_range := 6.0
var lunge_speed := 14.0
var lunge_cone := 70.0
var counter_range := 4.5
var counter_damage := 14.0
var counter_iframes := 0.45
var counter_whiff_lock := 0.6
var takedown_at := 5.0
var finisher_at := 8.0
var takedown_damage := 40.0
var finisher_damage := 45.0
var finisher_radius := 3.2
var lunge_max_time := 0.5
var counter_power := 0.8
var silent_range := 1.8

var moves: Dictionary
var enemy: Dictionary
var weapon_data: Dictionary
var combat: Combat
var hero: Character3D
var dummy: Character3D
var rig: CameraRig
var stick := Vector2.ZERO              # game.gd sets this from the virtual stick
var bot_stick := Vector2.INF           # the autoplay bot steers through this when set
var hp := 100
var max_hp := 100
var dummy_hp := 60.0
var kos := 0
var hits_landed := 0
var last_hit := {}                     # the last landed hit: damage, power, broke, cancel (tests read it)
var last_special := {}
var hero_hits_taken := 0
var dodged := 0                        # enemy swings that missed because of i-frames
var telegraphing := false
var can_pick_up := false
var _move := {}                        # the swing in progress
var _landed := false
var _move_age := 0.0                   # seconds of hero time since the swing started (hit_at, recover)
var _queued := {}                      # one buffered input while a swing recovers or the hero staggers
var _last_light_landed := false        # the previous tap's light connected (double-tap rule)
var _dodge_cd := 0.0
var _iframes := 0.0
var _enemy_t := 2.5
var _tele_t := 0.0
var _respawn_t := 0.0
var _pickup: Node3D
var _held: Node3D
var _warn: Label3D
# Free-flow (Nov 26). Counters below are read by tests, autoplay and the first-hunt prompts.
var freeflow: Dictionary
var sneak := false                     # the SNEAK toggle (the Pews reads it before the fight)
var demon_sight := false               # the SIGHT toggle: enemies marked through walls
var lunges := 0
var counters := 0                      # COUNTER presses that caught an attack
var counters_tried := 0                # every COUNTER press
var dodges := 0                        # DODGE presses that rolled
var takedowns := 0
var finishers := 0
var _lunge := {}                       # {"move", "target"} while the hero dashes in to swing
var _counter_lock := 0.0               # a whiffed COUNTER locks it out briefly (no mashing)
var _marks := {}                       # actor instance id -> its Demon Sight marker


func _ready() -> void:
	name = "Arena"
	moves = GameData.load_json("moves")
	enemy = GameData.load_json("enemies").get("dummy", {})
	weapon_data = GameData.load_json("weapons")
	combat = Combat.new(moves, weapon_data)
	max_hp = int(moves.player.hp)
	hp = max_hp
	enemy_attack_every = float(enemy.attack_every)
	enemy_telegraph = float(enemy.telegraph)
	enemy_damage = float(enemy.attack_damage)
	combo_gap = combat.combo_gap
	cancel_window = combat.cancel_window
	cancel_bonus = combat.cancel_bonus
	string_gap = combat.string_gap
	hold_time = float(moves.pad.hold_time)
	swipe_min = float(moves.pad.swipe_min)
	double_tap = float(moves.pad.double_tap)
	dodge_iframes = float(moves.player.dodge_iframes)
	dodge_cooldown = float(moves.player.dodge_cooldown)
	dummy_max_hp = float(enemy.hp)
	pipe_durability = float(weapon_data.pipe.durability)
	break_mult = float(weapon_data.pipe.break_mult)
	freeflow = moves.get("freeflow", {})
	for k in ["lunge_range", "lunge_speed", "lunge_cone", "counter_range", "counter_damage", "counter_iframes",
			"counter_whiff_lock", "takedown_at", "finisher_at", "takedown_damage", "finisher_damage", "finisher_radius",
			"lunge_max_time", "counter_power", "silent_range"]:
		if freeflow.has(k):
			set(k, float(freeflow[k]))
	_enemy_t = enemy_attack_every
	dummy_hp = dummy_max_hp
	_build_world()
	var clips: Dictionary = moves.clips.duplicate()
	clips.erase("_why")
	hero = Character3D.new()
	hero.name = "Hero"
	hero.rim = 1.4                     # the orange demon rim (style guide)
	hero.hero_light = true
	hero.can_swim = false
	hero.extra_actions = clips
	add_child(hero)
	dummy = Character3D.new()
	dummy.name = "Dummy"
	dummy.tint = GameData.color(enemy.tint)
	dummy.extra_actions = clips
	dummy.position = GameData.vec3(enemy.spawn)
	dummy.can_climb = false
	dummy.can_vault = false
	add_child(dummy)
	dummy.look_target = hero
	_warn = Label3D.new()
	_warn.text = "!"
	_warn.font_size = 160
	_warn.outline_size = 36
	_warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warn.no_depth_test = true
	_warn.position = Vector3(0, 2.4, 0)
	_warn.visible = false
	dummy.add_child(_warn)
	rig = CameraRig.new()
	rig.pitch_deg = 50.0               # BUILD_SPEC: fixed high three-quarter, about 50 degrees down
	rig.follow = hero
	add_child(rig)
	rig.snap()
	_spawn_pickup("pipe")
	add_to_group("tunable")
	var dm := get_node_or_null("/root/DebugMenu")
	if dm != null:
		dm.apply_tune(self)


# ---------------------------------------------------------------- the arena

func _build_world() -> void:
	var low: bool = get_node("/root/Settings").get_value("low_graphics")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("15121a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5b5670")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = not low
	add_child(sun)
	# Ink-and-blood palette (docs/style-guide.md): dark desaturated floor and props with drawn
	# crack lines, blood red splats; the characters stay the brightest things on screen.
	_box(Vector3(-SIZE, -1, -SIZE), Vector3(SIZE, 0, SIZE), Color("3a383d"))
	_box(Vector3(-SIZE, 0, -SIZE - 0.6), Vector3(SIZE, 2.0, -SIZE), Color("1c1a1e"))
	_box(Vector3(-SIZE - 0.6, 0, -SIZE), Vector3(-SIZE, 2.0, SIZE), Color("1c1a1e"))
	_box(Vector3(SIZE, 0, -SIZE), Vector3(SIZE + 0.6, 2.0, SIZE), Color("1c1a1e"))
	_box(Vector3(-SIZE, 0, SIZE), Vector3(SIZE, 0.6, SIZE + 0.6), Color("1c1a1e"))
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 5), Vector3(6, 0, 5)]:
		_box(p - Vector3(0.5, 0, 0.5), p + Vector3(0.5, 3.0, 0.5), Color("2b2a2e"))        # pillars
	_box(Vector3(-8.5, 0, 0), Vector3(-7.3, 1.0, 1.2), Color("4a3f36"))                     # crates
	_box(Vector3(7.2, 0, -1.5), Vector3(8.4, 1.0, -0.3), Color("4a3f36"))
	# Crack lines: thin ink strokes on the floor (no textures, style guide).
	for c in [[Vector3(-3, 0, 2), 0.4, 2.2], [Vector3(2.5, 0, -1), -0.7, 1.6], [Vector3(-1, 0, -7), 1.2, 2.6],
			[Vector3(4, 0, 4), 0.2, 1.8], [Vector3(-5, 0, -2), -0.3, 1.4]]:
		var crack := _box(Vector3(-0.025, 0, -c[2] / 2.0), Vector3(0.025, 0.006, c[2] / 2.0), Color("0d0c0c"), false)
		crack.position = c[0] + Vector3(0, 0.003, 0)
		crack.rotation.y = c[1]
	# Old blood splats where the dummy stands.
	for b in [[Vector3(0.6, 0, -3.6), 0.6], [Vector3(-1.0, 0, -2.4), 0.3], [Vector3(1.4, 0, -1.8), 0.2]]:
		var splat := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = b[1]
		cm.bottom_radius = b[1]
		cm.height = 0.01
		cm.radial_segments = 16
		splat.mesh = cm
		splat.material_override = _toon(Color("6e1212"), false)          # dried blood: darker than #B01818 so characters read first
		splat.position = b[0] + Vector3(0, 0.005, 0)
		splat.scale = Vector3(1.0, 1.0, 0.7)
		add_child(splat)


func _toon(c: Color, outline := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width_px", 3.0)
		m.next_pass = o
	return m


func _box(a: Vector3, b: Vector3, c: Color, solid := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.material_override = _toon(c, solid)
	if not solid:
		mi.position = (a + b) * 0.5
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 2
	body.position = (a + b) * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bm.size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mi)
	add_child(body)
	return body


func _pipe_mesh(id: String) -> MeshInstance3D:
	var w: Dictionary = weapon_data[id]
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = float(w.length)
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _toon(GameData.color(w.color))
	return mi


func _spawn_pickup(id: String) -> void:
	if _pickup != null:
		_pickup.queue_free()
	_pickup = Node3D.new()
	_pickup.name = "Pickup"
	_pickup.set_meta("weapon", id)
	var mi := _pipe_mesh(id)
	mi.rotation.z = PI / 2              # lying on the floor
	mi.position.y = 0.05
	_pickup.add_child(mi)
	add_child(_pickup)
	_pickup.position = GameData.vec3(weapon_data[id].spawn)


# ---------------------------------------------------------------- frame

## TUNE values -> the rules, every frame, so a dragged slider acts at once.
func push_tune() -> void:
	combat.combo_gap = combo_gap
	combat.cancel_window = cancel_window
	combat.cancel_bonus = cancel_bonus
	combat.string_gap = string_gap
	combat.damage_scale = damage_scale
	combat.durability_max = int(round(pipe_durability))
	combat.break_mult = break_mult
	dummy_hp = minf(dummy_hp, dummy_max_hp)


func _process(dt: float) -> void:
	push_tune()
	combat.tick(dt)
	_dodge_cd -= dt
	_iframes -= dt
	_counter_lock -= dt
	var v := bot_stick if bot_stick != Vector2.INF else stick
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")   # keys + pad
	hero.move_input = v.limit_length(1.0) if not hero.dead else Vector2.ZERO
	can_pick_up = _pickup != null and not hero.dead and combat.weapon == "" \
		and hero.global_position.distance_to(_pickup.global_position) < float(moves.arena.pickup_radius)
	_move_age += dt * hero.time_scale        # hero time: hit-stop pauses the swing's clock too
	if not _lunge.is_empty():
		_update_lunge()
	if _move.get("kind", "") == "finisher":
		_check_finisher()
	else:
		_check_hit()
	if not _queued.is_empty() and hero.dead:
		_queued = {}
	elif not _queued.is_empty() and _free():
		var q: Dictionary = _queued
		_queued = {}
		_input_move(q)
	_enemy(dt)
	var near := not dummy.dead and hero.global_position.distance_to(dummy.global_position) < 5.0
	get_node("/root/Audio").set_intensity(1.0 if near else 0.0)
	_update_sight()


## A swing lands once, while it plays, if the dummy is within reach and in front (or all
## round for 360-degree moves).
func _check_hit() -> void:
	if _move.is_empty() or _landed or dummy.dead:
		return
	if not hero.is_acting(_move.action):
		if _move_age > 0.2:                  # the clip starts on the next physics step: allow for it
			_move = {}
		return
	if _move_age < float(_move.get("hit_at", 0.0)):
		return                               # contact lands mid-swing, not on the first frame
	var to := dummy.global_position - hero.global_position
	to.y = 0.0
	var fwd := Vector3(sin(hero.heading), 0, cos(hero.heading))
	var arc := float(_move.get("arc", 120))
	var in_arc := arc >= 360.0 or fwd.dot(to.normalized()) > cos(deg_to_rad(arc / 2.0))
	if to.length() > combat.reach(_move) or not in_arc:
		return
	var r := _land_hit(dummy)
	_damage_dummy(r)


## The dummy (or a boss using it) takes a landed hit. The Pews keeps its boss rules in sync.
func _damage_dummy(r: Dictionary) -> void:
	dummy_hp -= float(r.damage)
	if dummy_hp <= 0.0:
		_ko(r)


## A landed hit's damage reaches `target`, whoever it is (the finisher hits several).
func _apply_damage(target: Character3D, r: Dictionary) -> void:
	if target == dummy and not dummy.dead:
		_damage_dummy(r)


## Bosses survive a TAKEDOWN (they take takedown_damage); anyone else goes down.
func _is_boss(target: Character3D) -> bool:
	return target == dummy


func _land_hit(target: Character3D) -> Dictionary:
	_landed = true
	var r := combat.land(_move)
	r["cancel"] = _move.get("cancel", false)
	r["kind"] = _move.kind
	if r.kind == "takedown" and not _is_boss(target):
		r["damage"] = 99999.0
	last_hit = r
	hits_landed += 1
	var feel: Node = get_node("/root/Feel")
	target.hit(hero.global_position + Vector3(0, 1.2, 0), float(r.power))
	hero.hit_stop(0.06 * feel.stop_scale)
	feel.impact(target.global_position + Vector3(0, 1.3, 0), float(r.power), self)
	if r.kind == "light":
		_last_light_landed = true
	if r.broke:
		_break_weapon()
	else:
		weapon_changed.emit(combat.weapon, combat.durability)
	return r


func _ko(r: Dictionary) -> void:
	var away := (dummy.global_position - hero.global_position).normalized()
	dummy.die(away * (float(moves.arena.ko_knockback) + float(moves.arena.ko_knockback_per_power) * float(r.power)) + Vector3(0, 2, 0))
	_warn.visible = false
	telegraphing = false
	kos += 1
	_respawn_t = float(enemy.respawn)
	get_node("/root/Subs").cue("[dummy goes down]")
	ko.emit(kos)


func _break_weapon() -> void:
	if _held != null:
		get_node("/root/Feel").burst(_held.global_position, 1.0, self)
		_held.queue_free()
		_held = null
	get_node("/root/Audio").sfx("hit_heavy", 0.7)
	get_node("/root/Subs").cue("[pipe snaps]")
	weapon_changed.emit("", 0)
	_spawn_pickup("pipe")               # M1 test arena: a fresh pipe appears so you can try again


# ---------------------------------------------------------------- the dummy fights back

func _enemy(dt: float) -> void:
	if dummy.dead:
		_respawn_t -= dt
		if _respawn_t <= 0.0:
			reset_dummy()
		return
	if hero.dead:
		return
	var d := hero.global_position.distance_to(dummy.global_position)
	if telegraphing:
		_tele_t -= dt
		if _tele_t <= 0.0:
			_swing(d)
		return
	if d < float(enemy.attack_reach) + float(enemy.approach_margin):
		_enemy_t -= dt
		if _enemy_t <= 0.0:
			# Telegraph >= 0.5 s: red "!" (colour + shape) and a whoosh with a caption.
			telegraphing = true
			_tele_t = enemy_telegraph
			_warn.modulate = UI.key("bad")
			_warn.visible = true
			get_node("/root/Audio").sfx("whoosh", 0.8)
			get_node("/root/Subs").cue("[dummy winds up]")


func _swing(d: float) -> void:
	telegraphing = false
	_warn.visible = false
	_enemy_t = enemy_attack_every
	var to := hero.global_position - dummy.global_position
	dummy.heading = atan2(to.x, to.z)
	dummy.model.rotation.y = dummy.heading
	dummy.act("enemy_swing")
	if d > float(enemy.attack_reach) or get_node("/root/DebugMenu").god_mode:
		return
	if _iframes > 0.0:
		dodged += 1
		get_node("/root/Subs").cue("[dodged]")
		return
	hp = maxi(0, hp - int(enemy_damage))
	hero_hits_taken += 1
	combat.drop_combo()
	hero.hit(dummy.global_position + Vector3(0, 1.2, 0), float(enemy.hit_power))
	get_node("/root/Feel").impact(hero.global_position + Vector3(0, 1.3, 0), float(enemy.hit_power), self)
	hero_hurt.emit(hp)
	if hp <= 0:
		hero.die(-to.normalized() * 3.0 + Vector3(0, 1.5, 0))
		hero_died.emit()


func reset_dummy() -> void:
	dummy.revive()
	dummy.global_position = GameData.vec3(enemy.spawn)
	dummy.velocity = Vector3.ZERO
	dummy_hp = dummy_max_hp
	_enemy_t = enemy_attack_every


# ---------------------------------------------------------------- the player's moves
# Inputs go through _input_move: a move starts when the hero is free (the last swing recovered
# and no stagger). Otherwise it waits in a one-slot buffer (newest wins) if the swing is within
# input_buffer seconds of recovering, or until a stagger ends; earlier presses are dropped.
# Why (review of 95847e0): mashing used to restart swings every tap, and a special could break
# out of a stagger. A special still cancels a swing that has landed (the combo cancel).

const STAGGER := ["knockback", "hit_chest", "hit_head"]


func light() -> void:
	_input_move({"kind": "light"})


func heavy() -> void:
	_input_move({"kind": "heavy"})


## dir: "up", "down", "toward" or "away" (see Combat.swipe_dir).
func special(dir: String) -> void:
	_input_move({"kind": "special", "dir": dir})


## A double-tap on the pad. It's a dodge, unless the tap before it was a light that connected:
## then it's another light, so mashing light in a fight stays a string (DECISIONS, Nov 21).
func double_tap_input() -> void:
	if _last_light_landed:
		light()
	else:
		dodge()


func _staggered() -> bool:
	for a in STAGGER:
		if hero.is_acting(a):
			return true
	return false


## Free to start a new swing: no stagger, no lunge under way, and the current swing has recovered.
func _free() -> bool:
	if hero.dead or _staggered() or not _lunge.is_empty():
		return false
	return _move.is_empty() or _move_age >= float(_move.get("recover", 0.0))


func _input_move(q: Dictionary) -> void:
	if hero.dead:
		return
	var can_cancel: bool = q.kind == "special" and _landed and not _move.is_empty() and not _staggered()
	if not (_free() or can_cancel):
		var left := float(_move.get("recover", 0.0)) - _move_age if not _move.is_empty() else 0.0
		if _staggered() or left <= float(moves.arena.input_buffer) + 0.001:
			_queued = q
		return
	var m := {}
	match q.kind:
		"light": m = combat.light()
		"heavy": m = combat.heavy()
		"special": m = _special_move(q.dir)
	if m.is_empty():
		return                                # special on cooldown: nothing spent
	if m.kind != "light":
		_last_light_landed = false
	if m.kind == "special":
		last_special = m
		if hero.is_acting("dodge"):
			_iframes = 0.0                    # cancelling the roll gives up its i-frames
		for a in hero.actions:
			if a != m.action and not a in STAGGER and hero.is_acting(a):
				hero.tree.set("parameters/shot_%s/request" % a, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		combat.commit(m)
	elif m.kind == "light":
		_last_light_landed = false
	_start(m)


func _special_move(dir: String) -> Dictionary:
	return combat.special(dir)


## A swipe on the pad (canvas vector) -> the special it means, relative to the dummy on screen.
func swipe(v: Vector2) -> void:
	special(Combat.swipe_dir(v, target_screen_dir()))


## Keyboard / gamepad special: the stick direction picks it (no stick = toward). Same rule as a swipe.
func stick_special(v: Vector2) -> void:
	special(Combat.swipe_dir(v, target_screen_dir()) if v.length() >= 0.3 else "toward")


## From the hero to the dummy on screen (canvas units, y down); zero when the dummy is down.
func _attack_target() -> Character3D:
	return null if dummy.dead else dummy


func target_screen_dir() -> Vector2:
	var cam := rig.cam
	var target := _attack_target()
	if cam == null or target == null:
		return Vector2.ZERO
	return cam.unproject_position(target.global_position) - cam.unproject_position(hero.global_position)


func dodge() -> void:
	if _dodge_cd > 0.0 or hero.dead:
		return
	_dodge_cd = dodge_cooldown
	_iframes = dodge_iframes
	_move = {}
	_queued = {}
	_end_lunge()
	_last_light_landed = false
	dodges += 1
	hero.act("dodge")


## The DODGE button (Nov 26): roll along the stick, or with no stick away from whoever is
## attacking (else the nearest enemy), so one tap gets you out of a swing.
func dodge_toward(v: Vector2) -> void:
	if _dodge_cd > 0.0 or hero.dead:
		return
	var dir := Vector3(v.x, 0, v.y)
	if v.length() < 0.3:
		dir = Vector3.ZERO
		var t := _counter_threat()
		if t == null:
			t = lunge_target()
		if t != null:
			dir = hero.global_position - t.global_position
			dir.y = 0.0
	if dir.length() > 0.01:
		hero.heading = atan2(dir.x, dir.z)
		hero.model.rotation.y = hero.heading
	dodge()


func pick_up() -> void:
	if not can_pick_up:
		return
	var id: String = _pickup.get_meta("weapon")
	combat.pick_up(id)
	_pickup.queue_free()
	_pickup = null
	can_pick_up = false
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	hero.skeleton.add_child(att)
	var mi := _pipe_mesh(id)
	mi.rotation.x = PI / 2
	mi.position = Vector3(0, 0.04, float(weapon_data[id].length) * 0.35)
	att.add_child(mi)
	_held = att
	get_node("/root/Audio").sfx("click")
	weapon_changed.emit(combat.weapon, combat.durability)


## Free-flow (Nov 26): face the target the stick points at (else the nearest). If it's past the
## swing's reach but inside lunge_range, dash to it first and swing on arrival (_update_lunge).
func _start(m: Dictionary, forced: Character3D = null) -> void:
	if m.is_empty() or hero.dead:
		return
	var target := forced if forced != null else lunge_target()
	if target == null:
		target = _attack_target()
	if target != null:
		var to := target.global_position - hero.global_position
		to.y = 0.0
		var d := to.length()
		if d < maxf(float(moves.arena.auto_face), lunge_range):
			_face(to)
		if lunge_range > 0.0 and d > combat.reach(m) * 0.9 and d <= lunge_range:
			_lunge = {"move": m, "target": target}
			lunges += 1
			_move = {}
			_landed = false
			hero.dash_t = lunge_max_time
			hero.dash_velocity = to.normalized() * lunge_speed
			return
	_begin(m)


func _begin(m: Dictionary) -> void:
	_move = m
	_landed = false
	_move_age = 0.0
	hero.act(m.action)


func _face(to: Vector3) -> void:
	if Vector2(to.x, to.z).length() < 0.001:
		return
	hero.heading = atan2(to.x, to.z)
	hero.model.rotation.y = hero.heading


func _update_lunge() -> void:
	var t: Character3D = _lunge.target
	if hero.dead or _staggered() or not hero.mode in ["ground", "crouch"]:
		_end_lunge()                           # climbing, swimming or airborne: no dash (fresh-eyes)
		return
	var m: Dictionary = _lunge.move
	if not is_instance_valid(t) or t.dead:
		_end_lunge()
		_begin(m)                              # swing where you are: the input still counts
		return
	var to := t.global_position - hero.global_position
	to.y = 0.0
	_face(to)
	if to.length() <= combat.reach(m) * 0.8 or hero.dash_t <= 0.0:
		_end_lunge()
		_begin(m)
	else:
		hero.dash_velocity = to.normalized() * lunge_speed


func _end_lunge() -> void:
	_lunge = {}
	hero.dash_t = 0.0


func lunging() -> bool:
	return not _lunge.is_empty()


## Who a strike can lunge to (alive, in this fight). The Pews leaves Vesper out before the fight.
func _targets() -> Array[Character3D]:
	return _sight_targets()


## Everyone Demon Sight marks: the dummy here; hunts add their minions.
func _sight_targets() -> Array[Character3D]:
	var out: Array[Character3D] = []
	if not dummy.dead and dummy.visible:
		out.append(dummy)
	return out


func lunge_target() -> Character3D:
	var ts := _targets()
	var pts: Array = []
	for t in ts:
		pts.append(t.global_position)
	var v := hero.move_input
	var i := Combat.pick_target(hero.global_position, Vector3(v.x, 0, v.y), pts, lunge_range, lunge_cone)
	return ts[i] if i >= 0 else null


func _flat_dist(t: Node3D) -> float:
	var to := t.global_position - hero.global_position
	to.y = 0.0
	return to.length()


func _abort_actions() -> void:
	for a in hero.actions:
		if not a in STAGGER and a != "dodge" and hero.is_acting(a):
			hero.tree.set("parameters/shot_%s/request" % a, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


# ---------------------------------------------------------------- COUNTER (Nov 26)

## The nearest enemy showing its attack warning inside counter_range (null = nothing to counter).
func _counter_threat() -> Character3D:
	if telegraphing and not dummy.dead and _flat_dist(dummy) <= counter_range:
		return dummy
	return null


## The countered attack never lands.
func _cancel_threat(t: Character3D) -> void:
	if t == dummy:
		telegraphing = false
		_warn.visible = false
		_enemy_t = enemy_attack_every


func counter_ready() -> bool:
	return _counter_lock <= 0.0 and not hero.dead and not _staggered() and _counter_threat() != null


## COUNTER: while an enemy shows "!", cancel its attack, lunge in and hit back (+1 combo, a moment
## of i-frames). Pressed with nothing to counter, it locks out for counter_whiff_lock.
func counter() -> void:
	if hero.dead or _staggered():
		return
	counters_tried += 1
	if _counter_lock > 0.0:
		return
	var t := _counter_threat()
	if t == null:
		_counter_lock = counter_whiff_lock
		get_node("/root/Subs").cue("[counter misses: wait for the !]")
		return
	_cancel_threat(t)
	counters += 1
	_iframes = maxf(_iframes, counter_iframes)
	_queued = {}
	_end_lunge()
	_abort_actions()
	var armed := combat.weapon != ""
	var m := {"id": "counter", "kind": "counter", "action": "slash_c" if armed else "hook",
		"damage": counter_damage, "power": counter_power, "reach": 1.6,
		"arc": 140, "hit_at": 0.12, "recover": 0.35}
	get_node("/root/Audio").sfx("hit_heavy", 0.5)
	get_node("/root/Subs").cue("[counter]")
	_start(m, t)


# ---------------------------------------------------------------- TAKEDOWN / FINISHER (Nov 26)

## What the combo meter offers now: "FINISHER" at finisher_at hits, "TAKEDOWN" at takedown_at,
## else "". Needs someone to lunge to.
func combo_move() -> String:
	if hero.dead or _staggered():
		return ""
	var c := combat.combo
	if c < int(takedown_at) or lunge_target() == null:
		return ""
	return "FINISHER" if c >= int(finisher_at) else "TAKEDOWN"


## Spends the combo. TAKEDOWN: one enemy goes down (a boss takes takedown_damage). FINISHER: a
## spin that hits everyone within finisher_radius for finisher_damage.
func combo_action() -> void:
	var what := combo_move()
	if what.is_empty():
		return
	combat.combo = 0
	_queued = {}
	_end_lunge()
	_abort_actions()
	_iframes = maxf(_iframes, 0.6)
	var m: Dictionary
	if what == "FINISHER":
		finishers += 1
		m = {"id": "finisher", "kind": "finisher", "action": "spin", "damage": finisher_damage, "power": 1.0,
			"reach": finisher_radius, "arc": 360, "hit_at": 0.3, "recover": 0.55}
	else:
		takedowns += 1
		m = {"id": "takedown", "kind": "takedown", "action": "heavy", "damage": takedown_damage, "power": 1.0,
			"reach": 1.8, "hit_at": 0.3, "recover": 0.55}
	get_node("/root/Subs").cue("[%s]" % what.to_lower())
	_start(m)


func _check_finisher() -> void:
	if _landed or hero.dead:
		return
	if not hero.is_acting(_move.action):
		if _move_age > 0.2:
			_move = {}
		return
	if _move_age < float(_move.get("hit_at", 0.0)):
		return
	var victims: Array[Character3D] = []
	for t in _targets():
		if _flat_dist(t) <= combat.reach(_move):
			victims.append(t)
	if victims.is_empty():
		_landed = true
		return
	var r := _land_hit(victims[0])
	for v in victims:
		if v != victims[0]:
			v.hit(hero.global_position + Vector3(0, 1.2, 0), float(r.power))
		_apply_damage(v, r)


# ---------------------------------------------------------------- SNEAK + DEMON SIGHT (Nov 26)

func toggle_sneak() -> void:
	sneak = not sneak


func set_demon_sight(on: bool) -> void:
	demon_sight = on
	get_node("/root/Subs").cue("[demon sight on]" if on else "[demon sight off]")
	if not on:
		for id in _marks:
			if is_instance_valid(_marks[id]):
				_marks[id].visible = false


## "unaware", "hunting" or "attacking" (Demon Sight colours and shapes).
func alertness(t: Character3D) -> String:
	if t == dummy:
		return "attacking" if telegraphing else "hunting"
	return "hunting"


const SIGHT := {"unaware": ["?", "info"], "hunting": ["!", "warn"], "attacking": ["!!", "bad"]}


func _update_sight() -> void:
	if not demon_sight:
		return
	var live := {}
	for t in _sight_targets():
		var id := t.get_instance_id()
		live[id] = true
		var mk: Node3D = _marks.get(id)
		if mk == null or not is_instance_valid(mk):
			mk = _make_mark(t)
			_marks[id] = mk
		var look: Array = SIGHT[alertness(t)]
		var label := mk.get_node("Text") as Label3D
		label.text = look[0]
		label.modulate = UI.key(look[1])
		(mk.get_node("Ring") as MeshInstance3D).material_override.albedo_color = Color(UI.key(look[1]), 0.55)
		mk.visible = true
	for id in _marks:
		if not live.has(id) and is_instance_valid(_marks[id]):
			_marks[id].visible = false


## A Demon Sight marker: a ring at the feet and a sign over the head, both drawn over walls.
func _make_mark(t: Character3D) -> Node3D:
	var mk := Node3D.new()
	mk.name = "SightMark"
	var label := Label3D.new()
	label.name = "Text"
	label.font_size = 120
	label.outline_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 2.9, 0)
	mk.add_child(label)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 0.02
	cm.radial_segments = 24
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.05
	mk.add_child(ring)
	t.add_child(mk)
	return mk


# ---------------------------------------------------------------- context button

## The context button in a plain arena: TAKEDOWN / FINISHER when the combo allows, else PICK UP.
func context_label() -> String:
	var c := combo_move()
	if not c.is_empty():
		return c
	return "PICK UP" if can_pick_up else ""


func context_visible() -> bool:
	return not context_label().is_empty()


func context_action() -> void:
	if not combo_move().is_empty():
		combo_action()
	elif can_pick_up:
		pick_up()


func combo_count() -> int:
	return combat.combo


func bug_state() -> String:
	return "arena: hp %d dummy %.0f kos %d combo %d weapon %s/%d" % [hp, dummy_hp, kos, combat.combo, combat.weapon, combat.durability]

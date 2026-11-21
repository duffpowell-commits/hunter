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
	"dummy_max_hp": [10.0, 300.0], "pipe_durability": [1.0, 10.0], "break_mult": [1.0, 5.0]}

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
	var v := bot_stick if bot_stick != Vector2.INF else stick
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")   # keys + pad
	hero.move_input = v.limit_length(1.0) if not hero.dead else Vector2.ZERO
	can_pick_up = _pickup != null and not hero.dead and combat.weapon == "" \
		and hero.global_position.distance_to(_pickup.global_position) < float(moves.arena.pickup_radius)
	_move_age += dt * hero.time_scale        # hero time: hit-stop pauses the swing's clock too
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
	_landed = true
	var r := combat.land(_move)
	r["cancel"] = _move.get("cancel", false)
	r["kind"] = _move.kind
	last_hit = r
	hits_landed += 1
	dummy_hp -= float(r.damage)
	var feel: Node = get_node("/root/Feel")
	dummy.hit(hero.global_position + Vector3(0, 1.2, 0), float(r.power))    # victim: flash + 60 ms stop
	hero.hit_stop(0.06 * feel.stop_scale)                                  # attacker freezes too
	feel.impact(dummy.global_position + Vector3(0, 1.3, 0), float(r.power), self)
	if r.kind == "light":
		_last_light_landed = true
	if r.broke:
		_break_weapon()
	else:
		weapon_changed.emit(combat.weapon, combat.durability)
	if dummy_hp <= 0.0:
		_ko(r)


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


## Free to start a new swing: no stagger, and the current swing has recovered.
func _free() -> bool:
	if hero.dead or _staggered():
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
		"special": m = combat.special(q.dir)
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


## A swipe on the pad (canvas vector) -> the special it means, relative to the dummy on screen.
func swipe(v: Vector2) -> void:
	special(Combat.swipe_dir(v, target_screen_dir()))


## Keyboard / gamepad special: the stick direction picks it (no stick = toward). Same rule as a swipe.
func stick_special(v: Vector2) -> void:
	special(Combat.swipe_dir(v, target_screen_dir()) if v.length() >= 0.3 else "toward")


## From the hero to the dummy on screen (canvas units, y down); zero when the dummy is down.
func target_screen_dir() -> Vector2:
	var cam := rig.cam
	if cam == null or dummy.dead:
		return Vector2.ZERO
	return cam.unproject_position(dummy.global_position) - cam.unproject_position(hero.global_position)


func dodge() -> void:
	if _dodge_cd > 0.0 or hero.dead:
		return
	_dodge_cd = dodge_cooldown
	_iframes = dodge_iframes
	_move = {}
	_queued = {}
	_last_light_landed = false
	hero.act("dodge")


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


func _start(m: Dictionary) -> void:
	if m.is_empty() or hero.dead:
		return
	# Snap to face the dummy when it's close: touch players can't aim a swing precisely.
	if not dummy.dead:
		var to := dummy.global_position - hero.global_position
		if Vector2(to.x, to.z).length() < float(moves.arena.auto_face):
			hero.heading = atan2(to.x, to.z)
			hero.model.rotation.y = hero.heading
	_move = m
	_landed = false
	_move_age = 0.0
	hero.act(m.action)


func combo_count() -> int:
	return combat.combo


func bug_state() -> String:
	return "arena: hp %d dummy %.0f kos %d combo %d weapon %s/%d" % [hp, dummy_hp, kos, combat.combo, combat.weapon, combat.durability]

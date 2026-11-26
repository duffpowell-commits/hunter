extends Node3D
## Cain's pet, the three-eyed fox (Duff, Nov 26; look B: soot black, bone white, an upright ember
## third eye). docs/MASCOT.md has the design. Numbers: data/fox.json (TUNE sliders in lair_tuning.gd).
##   - Follows Cain on hunts and in the lair: walks, runs to catch up, idles (clip Survey) beside him.
##   - Can't be hurt and never fights: it's not in any target list, and it backs off to
##     fight_distance while a fight is on.
##   - SNEAK: it slows down and keeps low with Cain.
##   - Demon Sight is the fox's third eye: the eye opens and flares while SIGHT is on.
##   - Once a hunt it yips toward an unaware enemy nearby (Subs caption), then looks at it.
##   - Lair: it waits at the door and runs to greet Cain; with more corruption it keeps a wider,
##     warier distance (wary_follow per corruption look).
## Model: CC0 fox from Khronos glTF-Sample-Assets (assets/pets/SOURCES.md), recoloured by
## tools/recolor_fox.py. Real clips only: Survey, Walk, Run.

const GameData = preload("res://scripts/game_data.gd")
const LairRules = preload("res://scripts/lair_rules.gd")
const Character3D = preload("res://scripts/character3d.gd")
const MODEL := preload("res://assets/pets/fox.glb")
const INK := preload("res://assets/pets/fox_ink.png")
const EYE_COLOR := Color(1.0, 0.45, 0.08)
## Forehead point in the model's own units (cm), found from a render (docs/renders/flow_fox_*.png).
const EYE_AT := Vector3(0, 68.0, 53.0)

var arena: Node3D
var hero: Node3D
var model: Node3D
var anim: AnimationPlayer
var eye: MeshInstance3D
var eye_mat: StandardMaterial3D
var state := "follow"          # "greet" (lair door) or "follow"
var clip := ""
var speed := 0.0
var greeted := false
var yipped := false
var yip_t := 0.0
var yip_at := Vector3.ZERO
var band := 0                  # corruption look (0 warm .. 2 wary)
var side := 1.0                # which side of Cain it walks on (screen right = 1)
var moving := false


func cfg() -> Dictionary:
	return GameData.load_json("fox")


func setup(a: Node3D, h: Node3D) -> void:
	arena = a
	hero = h


func _ready() -> void:
	name = "FoxPet"
	model = MODEL.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * float(cfg().scale)
	var mats: Array[ShaderMaterial] = Character3D.apply_toon(model, Color.WHITE, float(cfg().rim), float(cfg().outline_px))
	for m in mats:
		m.set_shader_parameter("albedo", Color.WHITE)
		m.set_shader_parameter("albedo_tex", INK)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Survey", "Walk", "Run"]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_build_eye()
	_play("Survey")
	var prof := get_node_or_null("/root/Profile")
	if prof != null:
		band = LairRules.corruption_band(int(prof.data.corruption), GameData.load_json("lair"))


## The third eye: an upright ember slit on the forehead, riding the head bone.
func _build_eye() -> void:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var head := sk.find_bone("b_Head_05")
	var att := BoneAttachment3D.new()
	att.name = "ThirdEye"
	att.bone_name = "b_Head_05"
	sk.add_child(att)
	eye = MeshInstance3D.new()
	eye.name = "Eye"
	var s := SphereMesh.new()
	s.radius = 4.0
	s.height = 8.0
	s.radial_segments = 12
	s.rings = 6
	eye.mesh = s
	eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = EYE_COLOR
	eye_mat.emission_enabled = true
	eye_mat.emission = EYE_COLOR
	eye.material_override = eye_mat
	eye.position = sk.get_bone_global_rest(head).affine_inverse() * EYE_AT
	att.add_child(eye)
	_set_eye(false)


func sight_on() -> bool:
	return arena != null and arena.get("demon_sight") == true


func _set_eye(open: bool) -> void:
	var c := cfg()
	var k: float = float(c.eye_sight_scale) if open else 1.0
	eye.scale = Vector3(0.45 * k, 1.0 * k, 0.8 * k)
	eye_mat.emission_energy_multiplier = float(c.eye_sight_glow if open else c.eye_idle_glow)
	eye_mat.albedo_color = EYE_COLOR if open else EYE_COLOR.darkened(0.45)


## The eye's glow right now (read by tests and autoplay).
func eye_glow() -> float:
	return eye_mat.emission_energy_multiplier


## True while any enemy is fighting Cain: the fox keeps clear.
func in_fight() -> bool:
	if arena == null:
		return false
	if arena.get("raid_active") == true or arena.get("invasion_active") == true or arena.get("encounter_started") == true:
		return true
	for f: Dictionary in arena.get("_foes") if arena.get("_foes") != null else []:
		if not f.dead and f.aggro:
			return true
	return false


func follow_distance() -> float:
	var c := cfg()
	if in_fight():
		return float(c.fight_distance)
	var w: Array = c.wary_follow
	return float(w[clampi(band, 0, w.size() - 1)])


## Hunts: start just behind Cain, a little to his right.
func place_behind() -> void:
	var h := float(hero.heading)
	var back := -Vector3(sin(h), 0, cos(h))
	var right := Vector3(-cos(h), 0, sin(h))
	global_position = hero.global_position + back * 1.2 + right * 0.7
	model.rotation.y = h


## Lair: wait at the door greet_distance in front of Cain, then run to him.
func start_greet() -> void:
	state = "greet"
	greeted = false
	var fwd := Vector3(sin(float(hero.heading)), 0, cos(float(hero.heading)))
	global_position = hero.global_position + fwd * float(cfg().greet_distance)
	_face(hero.global_position, 100.0)


func _process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var c := cfg()
	model.scale = Vector3.ONE * float(c.scale)
	_set_eye(sight_on())
	_try_yip()
	if yip_t > 0.0:
		yip_t -= dt
		_face(yip_at, float(c.turn_rate) * dt)
		_move(Vector3.ZERO, 0.0, dt)
		return
	var hp: Vector3 = hero.global_position
	var goal := goal_point()
	var to := goal - global_position
	to.y = 0
	var d := to.length()
	if hp.distance_to(global_position) > float(c.catch_up_at):
		global_position = goal
		return
	# Hysteresis: start walking past 0.6 m from the spot, stop inside 0.15 m (no jitter).
	if d > 0.6 or (moving and d > 0.15):
		moving = true
		var sp: float = float(c.run_speed) if d > float(c.run_at) else float(c.walk_speed)
		if sneaking():
			sp *= float(c.sneak_speed_scale)
		var dir := to / d
		if arena != null and arena.has_method("steer"):
			var r: Array = arena.steer(global_position, dir, 0.0, 0.8, 0.25)
			dir = r[0]
		_move(dir, minf(sp, d / maxf(dt, 0.001)), dt)
		_face(global_position + dir, float(c.turn_rate) * dt)
	else:
		moving = false
		_move(Vector3.ZERO, 0.0, dt)
		_face(hp, float(c.turn_rate) * 0.5 * dt)
		if state == "greet" and not greeted:
			greeted = true
			state = "follow"
			_cue("[the fox yips hello]")


## Where the fox wants to stand: beside Cain on the screen (the camera never turns), a touch toward
## the camera so his body never hides it. It keeps its side unless that spot is inside a wall.
func goal_point() -> Vector3:
	var hp: Vector3 = hero.global_position
	var want: float = 0.9 if state == "greet" else follow_distance()
	if global_position.x < hp.x - 0.3:
		side = -1.0
	elif global_position.x > hp.x + 0.3:
		side = 1.0
	var goal := hp + Vector3(side * want, 0, 0.35)
	if arena != null and arena.has_method("blocked") and arena.blocked(goal, 0.25):
		var other := hp + Vector3(-side * want, 0, 0.35)
		if not arena.blocked(other, 0.25):
			goal = other
	goal.y = global_position.y
	return goal


func sneaking() -> bool:
	return arena != null and arena.get("sneak") == true


func _move(dir: Vector3, sp: float, dt: float) -> void:
	speed = sp
	global_position += dir * sp * dt
	var c := cfg()
	model.scale.y = float(c.scale) * (float(c.sneak_crouch) if sneaking() else 1.0)
	if sp < 0.2:
		_play("Survey")
	elif sp > float(c.walk_speed) * 1.3:
		_play("Run")
		anim.speed_scale = clampf(sp / float(c.run_speed), 0.6, 1.4)
	else:
		_play("Walk")
		anim.speed_scale = clampf(sp / float(c.walk_speed), 0.5, 1.4)


func _face(at: Vector3, step: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var h := atan2(to.x, to.z)
	model.rotation.y = lerp_angle(model.rotation.y, h, clampf(step, 0.0, 1.0))


func _play(n: String) -> void:
	if clip == n:
		return
	clip = n
	anim.speed_scale = 1.0
	anim.play(n, 0.2)


## Once a hunt: an unaware enemy within yip_range of Cain gets a yip and a look.
func _try_yip() -> void:
	if yipped or arena == null or in_fight() or arena.get("_foes") == null:
		return
	for f: Dictionary in arena.get("_foes"):
		if f.dead or f.aggro:
			continue
		var p: Vector3 = f.actor.global_position
		if p.distance_to(hero.global_position) <= float(cfg().yip_range):
			yipped = true
			yip_at = p
			yip_t = float(cfg().yip_hold)
			_cue("[the fox yips: something close]")
			return


func _cue(text: String) -> void:
	var subs := get_node_or_null("/root/Subs")
	if subs != null:
		subs.cue(text)

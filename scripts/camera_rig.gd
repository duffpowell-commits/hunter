extends Node3D
## The house 3D camera: smooth follow with look-ahead, frames a second target (pulls back to keep
## both on screen), rises over walls instead of diving into the hero, and shakes on impacts.
## Why (Nov 26, 8.5 pass): the blind first-timer saw the camera cut in front of a wall right
## inside Cain (s100) and felt it turn mid-fight. It now keeps its distance and only tilts up
## (pitch) when a wall is in the way, and it looks at the smoothed point it follows, so the view
## never swings and the stick never flips.
##   var rig := CameraRig.new(); add_child(rig); rig.follow = hero; rig.frame_target = enemy
##   rig.add_trauma(0.4)      # impact shake (Feel.impact does this for you)
## Fixed high three-quarter angle by default; a game changes pitch/distance, not the behaviour.

@export var pitch_deg := 50.0
@export var distance := 7.5
@export var look_ahead := 0.35        # seconds of velocity the camera leads by
@export var smooth := 6.0             # 1/s; higher = tighter follow
@export var frame_extra := 0.55       # extra distance per metre between hero and frame_target
@export var frame_max := 6.0          # never pull back more than this (m)
@export var wall_mask := 1            # what the camera may not pass through
@export var wall_margin := 0.35
@export var fov := 45.0
@export var max_pitch := 82.0         # how far it may tilt up to see over a wall
@export var min_distance := 4.0       # never closer to the hero than this, even behind a wall
## Live sliders in DEV MENU -> TUNE (scripts/tune_panel.gd).
const TUNE := {"pitch_deg": [20.0, 85.0], "distance": [3.0, 16.0], "look_ahead": [0.0, 1.0],
	"smooth": [1.0, 20.0], "fov": [25.0, 80.0], "max_pitch": [50.0, 88.0], "min_distance": [1.0, 8.0]}

var follow: Node3D
var frame_target: Node3D
var cam: Camera3D
var trauma := 0.0                     # 0..1, decays; shake = trauma^2
var blocked := false                  # last frame a wall pushed the camera in (tests read this)
var _noise := FastNoiseLite.new()
var _t := 0.0
var _base := Vector3.ZERO
var _look := Vector3.ZERO             # smoothed point the camera follows and looks at
var _pitch := 50.0                    # current pitch; above pitch_deg only while a wall is in the way
var _d := 7.5


func _ready() -> void:
	add_to_group("camera_rig")
	add_to_group("tunable")
	var dm := get_node_or_null("/root/DebugMenu")
	if dm != null:
		dm.apply_tune(self)
	cam = Camera3D.new()
	cam.fov = fov
	cam.current = true
	add_child(cam)
	_noise.frequency = 2.0
	snap()


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


## Cut straight to the wanted spot (after a teleport or a scene start).
func snap() -> void:
	if follow == null:
		return
	_look = _focus()
	_d = _dist()
	_pitch = _clear_pitch(_look, _d)
	_place()
	_apply(0.0)


func _focus() -> Vector3:
	var v := Vector3.ZERO
	if follow is CharacterBody3D:
		v = (follow as CharacterBody3D).velocity
	var f := follow.global_position + Vector3(v.x, 0, v.z) * look_ahead + Vector3(0, 1.0, 0)
	if frame_target != null and is_instance_valid(frame_target):
		f = f.lerp(frame_target.global_position + Vector3(0, 1.0, 0), 0.5)
	return f


func _dist() -> float:
	var d := distance
	if frame_target != null and is_instance_valid(frame_target):
		d += minf(follow.global_position.distance_to(frame_target.global_position) * frame_extra, frame_max)
	return d


func _dir(p_deg: float = -1.0) -> Vector3:
	var p := deg_to_rad(pitch_deg if p_deg < 0.0 else p_deg)
	return Vector3(0, sin(p), cos(p))


func _desired() -> Vector3:
	return _focus() + _dir() * _dist()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var ex: Array[RID] = []
	for c in get_tree().get_nodes_in_group("characters"):
		if c is CollisionObject3D:
			ex.append((c as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, wall_mask, ex))


## The lowest pitch, from pitch_deg up to max_pitch, that sees the focus past every wall.
func _clear_pitch(from: Vector3, d: float) -> float:
	var p := pitch_deg
	var top := maxf(max_pitch, pitch_deg)      # a TUNE pitch above the cap still works with no wall
	while p < top:
		if _ray(from, from + _dir(p) * d).is_empty():
			return p
		p += 4.0
	return top


## Old behaviour, kept as the last resort: a wall still in the way even at max_pitch puts the
## camera in front of it, but never nearer the hero than min_distance.
func _unclip(from: Vector3, to: Vector3) -> Vector3:
	var hit := _ray(from, to)
	if hit.is_empty():
		return to
	var at: Vector3 = hit.position + (from - to).normalized() * wall_margin
	if at.distance_to(from) < min_distance:
		at = from + (to - from).normalized() * min_distance
	return at


func _place() -> void:
	var want := _look + _dir(_pitch) * _d
	_base = _unclip(_look, want)
	blocked = _pitch > pitch_deg + 0.5 or not _base.is_equal_approx(want)


func _process(dt: float) -> void:
	if follow == null or not is_instance_valid(follow):
		return
	_t += dt
	var k := 1.0 - exp(-smooth * dt)
	_look = _look.lerp(_focus(), k)
	_d = lerpf(_d, _dist(), k)
	var target := _clear_pitch(_look, _d)
	# Up fast (a wall is coming), down slow (no bobbing as you pass a pillar).
	_pitch = lerpf(_pitch, target, 1.0 - exp(-(10.0 if target > _pitch else 2.0) * dt))
	_place()
	trauma = maxf(0.0, trauma - dt * 1.6)
	_apply(dt)


func _apply(_dt: float) -> void:
	cam.fov = fov
	var s := trauma * trauma
	var off := Vector3(_noise.get_noise_2d(_t * 40.0, 0), _noise.get_noise_2d(0, _t * 40.0), 0) * 0.35 * s
	cam.global_position = _base + off
	# Look at the smoothed point, not the raw one: the view direction then depends only on the
	# pitch, so the camera never turns and the stick's "up" is always screen-up.
	cam.look_at(_look, Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, _noise.get_noise_2d(_t * 40.0, 99) * 0.05 * s)

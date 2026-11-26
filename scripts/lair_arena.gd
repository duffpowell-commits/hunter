extends "res://scripts/hunt_arena.gd"
## Hunter M3 (Nov 23): the lair, the hub between hunts (docs/BUILD_SPEC.md "Lair (hub)").
## One room that scrolls vertically: you arrive through the portal at the bottom, and walk up past
## the trophy wall, the workshop, the cold room and the voice shrine to the map room at the top.
## Walk up to a station and the context button names it; tapping it asks game.gd for that sheet.
## Trap spots by the door take crafted traps. Heat at the raid line brings a LAIR RAID: waves of
## raiders come in through the portal and set traps fire on them. Losing costs stored parts, never
## the save. Corruption picks one of three looks for the room (light, floor, ink veins, candles).
## M4 (Nov 26): Furfur Kemp. After a lost hunt (or a few nights home) he follows you through the
## portal: a fight you can't lose, only win ugly (drop and you get back up, he heals a little). Beat
## him and CHAIN HIM: he lives in the cage by the door from then on, watching you, and the cage
## station opens his talk menu (lair_sheets.gd). Rules: furfur_rules.gd. Numbers: data/furfur.json.

signal station_requested(id: String)
signal raid_finished(won: bool, result: Dictionary)
signal raid_started
signal furfur_beaten
signal furfur_line(kind: String)       # game.gd shows one of Furfur's lines (data/voices/furfur.json)

const STATION_NAMES := {"trophy_wall": "TROPHY WALL", "workshop": "WORKSHOP", "cold_room": "COLD ROOM",
	"voices": "VOICES", "map_room": "MAP ROOM", "cage": "FURFUR'S CAGE"}

var cfg: Dictionary
var band := 0
var raid_active := false
var raid_wave := 0
var traps_fired := 0                   # read by autoplay (LAIR RAID TRAP PASS)
var _wave_t := 0.0
var resume_wave := 0                   # a raid left mid-way (run save): CONTINUE picks it up here
var _near_station := ""
var _near_trap := -1
var _env: Environment
var _sun: DirectionalLight3D
var _look_nodes: Array[Node] = []      # rebuilt when the look changes
var _trap_nodes: Array[Node3D] = []
var _wall: Node3D
var _shrine: Node3D
var _cold: Node3D
var furfur_cfg: Dictionary
var invasion_active := false
var knockdowns := 0                    # times the hero dropped in the invasion (read by autoplay)
var caged_furfur: Character3D          # Furfur in the cage once chained


func _build_world() -> void:
	cfg = GameData.load_json("lair")
	furfur_cfg = GameData.load_json("furfur")
	var low: bool = get_node("/root/Settings").get_value("low_graphics")
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("0e0b10")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Nov 26 (8.5 pass): the first-timer found the lair too dark to read. Brighter ambient + sun,
	# a lit ring at every station, bigger labels, and a NEXT HUNT marker over the map room.
	_env.ambient_light_energy = 1.05
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-30), 0)
	_sun.light_energy = 1.4
	_sun.shadow_enabled = not low
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 22.0
	add_child(_sun)
	var lay: Dictionary = cfg.layout
	var w := float(lay.half_width)
	var s := float(lay.south)
	var n := float(lay.north)
	# Shell: floor, side walls, the far wall. The south end stays open for the portal and camera.
	_box(Vector3(-w, -1, n), Vector3(w, 0, s + 2.0), Color("3b3a40"))
	_box(Vector3(-w - 0.5, 0, n), Vector3(-w, 2.6, s + 2.0), Color("26252b"))
	_box(Vector3(w, 0, n), Vector3(w + 0.5, 2.6, s + 2.0), Color("26252b"))
	_box(Vector3(-w, 0, n - 0.5), Vector3(w, 2.6, n), Color("26252b"))
	_build_portal(GameData.vec3(lay.portal_at))
	_build_trophy_wall(GameData.vec3(lay.stations.trophy_wall))
	_build_workshop(GameData.vec3(lay.stations.workshop))
	_build_cold_room(GameData.vec3(lay.stations.cold_room))
	_build_shrine(GameData.vec3(lay.stations.voices))
	_build_map_room(GameData.vec3(lay.stations.map_room))
	_build_cage(GameData.vec3(lay.stations.cage))
	for id in lay.stations:
		var ring := _glow_ring(GameData.vec3(lay.stations[id]) + Vector3(0, 0.03, 0), 0.8)
		ring.name = "Marker_" + str(id)
	_build_next_marker(GameData.vec3(lay.stations.map_room))
	for i in lay.trap_spots.size():
		var plate := _ink_disc(GameData.vec3(lay.trap_spots[i]) + Vector3(0, 0.01, 0), 0.5, Color("2f2a2c"))
		plate.name = "TrapSpot%d" % i
		_trap_nodes.append(plate)


func _ready() -> void:
	super._ready()
	name = "LairArena"
	# No training dummy in the lair: it is parked out of the way and asleep.
	dummy.visible = false
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	dummy.position = Vector3(0, 0, 60)
	dummy_hp = 1.0
	hero.position = GameData.vec3(cfg.layout.hero_spawn)
	hero.heading = PI
	hero.model.rotation.y = PI
	rig.snap()
	_enemy_t = 999.0
	apply_profile()
	refresh()


func foe_rules() -> Dictionary:
	return furfur_cfg.invasion if invasion_active else cfg.raid


func _attack_target() -> Character3D:
	var best: Character3D
	var nearest := 4.0
	for foe in _foes:
		if foe.dead:
			continue
		var d: float = hero.global_position.distance_to(foe.actor.global_position)
		if d < nearest:
			nearest = d
			best = foe.actor
	return best


## Re-reads the profile: the look, the wall, the cold room, the shrine, the traps.
func refresh() -> void:
	var prof := get_node_or_null("/root/Profile")
	var p: Dictionary = prof.data if prof != null else LairRules.blank()
	set_look(LairRules.corruption_band(int(p.corruption), cfg))
	_fill_wall(p)
	_fill_cold_room(p)
	_fill_shrine(p)
	_fill_cage(p)
	for i in _trap_nodes.size():
		var spot := _trap_nodes[i]
		for c in spot.get_children():
			if c.name == "Spikes":
				_drop(c)
		if i < p.traps.size() and not str(p.traps[i]).is_empty():
			var spikes := Node3D.new()
			spikes.name = "Spikes"
			for k in 5:
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.07
				cm.height = 0.38
				cm.radial_segments = 6
				cone.mesh = cm
				cone.material_override = _toon(Color("7fa3b0"))
				var a := float(k) * TAU / 5.0
				cone.position = Vector3(cos(a) * 0.25, 0.19, sin(a) * 0.25)
				spikes.add_child(cone)
			spot.add_child(spikes)


## BUILD_SPEC Corruption: three looks (0-33, 34-66, 67-100).
func set_look(b: int) -> void:
	band = clampi(b, 0, 2)
	var look: Dictionary = cfg.corruption.looks[band]
	_env.ambient_light_color = Color(str(look.ambient))
	_sun.light_color = Color(str(look.light))
	for node in _look_nodes:
		_drop(node)
	_look_nodes.clear()
	var floor_tint := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(cfg.layout.half_width) * 2.0, float(cfg.layout.south) - float(cfg.layout.north) + 2.0)
	floor_tint.mesh = pm
	floor_tint.material_override = _toon(Color(str(look.floor)), false)
	floor_tint.position = Vector3(0, 0.004, (float(cfg.layout.south) + float(cfg.layout.north)) / 2.0 + 1.0)
	floor_tint.name = "LookFloor"
	add_child(floor_tint)
	_look_nodes.append(floor_tint)
	# Ink veins: red strokes that creep up the floor from the portal as corruption grows.
	var veins := int(look.veins)
	for i in veins:
		var t := float(i) / maxf(1.0, float(veins))
		var vein := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.006, 1.2 + fmod(float(i) * 0.37, 1.1))
		vein.mesh = bm
		vein.material_override = _toon(Color("8a1414"), false)
		vein.position = Vector3(sin(float(i) * 2.3) * (float(cfg.layout.half_width) - 0.6), 0.01, float(cfg.layout.south) - t * 15.0)
		vein.rotation.y = sin(float(i) * 1.7) * 0.9
		vein.name = "Vein%d" % i
		add_child(vein)
		_look_nodes.append(vein)
	# Candles along the walls: warm wax at home, blood red as the lair turns.
	var candle_c := Color("d9c48a") if band == 0 else (Color("a83a2a") if band == 1 else Color("c0101a"))
	for z in [4.5, 1.5, -1.8, -4.6, -7.6]:
		for x in [-float(cfg.layout.half_width) + 0.25, float(cfg.layout.half_width) - 0.25]:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.07
			cm.height = 0.3 + 0.15 * band
			cm.radial_segments = 8
			c.mesh = cm
			c.material_override = _toon(candle_c)
			c.position = Vector3(x, cm.height / 2.0, z)
			add_child(c)
			_look_nodes.append(c)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.05
			fm.height = 0.12
			flame.mesh = fm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color("ffcf70") if band == 0 else Color("ff5a30")
			flame.material_override = mat
			flame.position = Vector3(x, cm.height + 0.06, z)
			add_child(flame)
			_look_nodes.append(flame)


## Out of the tree now, freed later: refresh() can run twice in a frame, and a node still waiting
## to be freed would make its replacement get an auto-generated name.
func _drop(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


# ---------------------------------------------------------------- stations (built once)

func _ink_disc(at: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = _toon(c)
	mi.position = at
	add_child(mi)
	return mi


func _label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 52
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("f3d9a4")
	l.position = at
	add_child(l)


## A flat lit ring on the floor: "stand here" for a station. Unshaded, so it reads in every look.
func _glow_ring(at: Vector3, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.09
	tm.outer_radius = r
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	mi.scale = Vector3(1, 0.15, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("e8a33d")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	add_child(mi)
	return mi


var next_marker: Node3D               # bobbing NEXT HUNT over the map room (8.5 pass)


func _build_next_marker(at: Vector3) -> void:
	next_marker = Node3D.new()
	next_marker.name = "NextHunt"
	next_marker.position = at + Vector3(0, 2.3, 0)
	add_child(next_marker)
	var l := Label3D.new()
	l.text = "NEXT HUNT"
	l.font_size = 60
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = UI.key("warn")
	l.position = Vector3(0, 0.55, 0)
	next_marker.add_child(l)
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.0
	cm.height = 0.45
	cm.radial_segments = 4
	arrow.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = UI.key("warn")
	arrow.material_override = mat
	next_marker.add_child(arrow)


## The lair is quiet: no raid, no invasion, nothing pending. Then the map room is what's next.
func idle() -> bool:
	var prof_ := get_node_or_null("/root/Profile")
	return not raid_active and not invasion_active and prof_ != null \
		and not bool(prof_.data.get("raid_pending", false)) and FurfurRules.stage(prof_.data) != "invading"


func _build_portal(at: Vector3) -> void:
	var ring := _ink_disc(at + Vector3(0, 0.02, 0), 0.9, Color("4a1d2a"))
	ring.name = "Portal"
	_ink_disc(at + Vector3(0, 0.05, 0), 0.6, Color("120a10"))


func _build_trophy_wall(at: Vector3) -> void:
	_wall = Node3D.new()
	_wall.name = "TrophyWall"
	_wall.position = at
	add_child(_wall)
	var side := -1.0 if at.x < 0 else 1.0
	var x := side * (float(cfg.layout.half_width) - 0.15)
	_box(Vector3(x - 0.15, 0, at.z - 1.3), Vector3(x + 0.15, 2.4, at.z + 1.3), Color("3a2e26"))
	_label("TROPHIES", at + Vector3(side * 0.3, 2.0, 0))


func _fill_wall(p: Dictionary) -> void:
	for c in _wall.get_children():
		_drop(c)
	var side := -1.0 if _wall.position.x < 0 else 1.0
	var x := side * (float(cfg.layout.half_width) - 0.32) - _wall.position.x
	var wall: Array = p.wall
	for i in wall.size():
		var row := floori(float(i) / 2.0)
		var col := i % 2
		var spot := Vector3(x, 2.0 - float(row) * 0.7, -0.55 + float(col) * 1.1)
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.05, 0.5, 0.6)
		frame.mesh = fm
		frame.material_override = _toon([Color("8c3a2a"), Color("3a5a7a"), Color("5a7a3a")][row])
		frame.position = spot
		_wall.add_child(frame)
		if not str(wall[i]).is_empty():
			var trophy := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.18
			trophy.mesh = tm
			trophy.material_override = _toon(Color("8b718f"))
			trophy.position = spot + Vector3(-side * 0.1, 0, 0)
			trophy.rotation.z = PI / 2.0
			trophy.name = "Trophy_%s" % wall[i]
			_wall.add_child(trophy)


func _build_workshop(at: Vector3) -> void:
	_box(at + Vector3(-0.6, 0, -1.0), at + Vector3(0.9, 0.9, 1.0), Color("4a3f36"))
	_box(at + Vector3(0.2, 0.9, -0.3), at + Vector3(0.5, 1.15, 0.0), Color("55595f"), false)
	_box(at + Vector3(-0.3, 0.9, 0.3), at + Vector3(0.6, 0.94, 0.38), Color("8c8580"), false)
	_label("WORKSHOP", at + Vector3(0, 1.5, 0))


func _build_cold_room(at: Vector3) -> void:
	_cold = Node3D.new()
	_cold.name = "ColdRoom"
	_cold.position = at
	add_child(_cold)
	_box(at + Vector3(-1.1, 0, -1.0), at + Vector3(-0.4, 2.2, 1.0), Color("5c6a74"))
	_label("COLD ROOM", at + Vector3(0, 2.0, 0))


## Crates stack up with stored parts (one per 5, up to 6), so the cold room shows the haul.
func _fill_cold_room(p: Dictionary) -> void:
	for c in _cold.get_children():
		_drop(c)
	var crates := mini(6, ceili(float(p.parts) / 5.0))
	for i in crates:
		var crate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.4, 0.45)
		crate.mesh = bm
		crate.material_override = _toon(Color("6a5a48"))
		crate.position = Vector3(0.1 + float(i % 2) * 0.5, 0.2 + float(floori(float(i) / 4.0)) * 0.4, -0.6 + float(floori(float(i) / 2.0) % 2) * 0.55)
		crate.name = "Crate%d" % i
		_cold.add_child(crate)


func _build_shrine(at: Vector3) -> void:
	_shrine = Node3D.new()
	_shrine.name = "VoiceShrine"
	_shrine.position = at
	add_child(_shrine)
	_box(at + Vector3(0.7, 0, -0.7), at + Vector3(1.1, 2.3, 0.7), Color("1e1a22"))
	_label("VOICES", at + Vector3(0, 2.0, 0))


func _fill_shrine(p: Dictionary) -> void:
	for c in _shrine.get_children():
		_drop(c)
	for i in p.equipped.size():
		var id := str(p.equipped[i])
		if id.is_empty():
			continue
		var voice := GameData.load_json("voices/" + id)
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		orb.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(str(voice.get("color", "8b718f")))
		orb.material_override = mat
		orb.position = Vector3(0.4, 1.5 - float(i) * 0.5, 0)
		orb.name = "Voice_%s" % id
		_shrine.add_child(orb)


func _build_map_room(at: Vector3) -> void:
	_box(at + Vector3(-1.0, 0, -0.5), at + Vector3(1.0, 0.85, 0.5), Color("3c3228"))
	var map := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 0.85)
	map.mesh = pm
	map.material_override = _toon(Color("b8a47a"), false)
	map.position = at + Vector3(0, 0.86, 0)
	add_child(map)
	var gate := _ink_disc(at + Vector3(0, 0.02, -1.2), 0.7, Color("5a1d2a"))
	gate.name = "RealmGate"
	_label("MAP ROOM", at + Vector3(0, 1.5, 0))


# ---------------------------------------------------------------- walking about

func _process(dt: float) -> void:
	super._process(dt)
	if next_marker != null:
		next_marker.visible = idle()
		next_marker.position.y = 2.3 + 0.12 * sin(Time.get_ticks_msec() * 0.004)
	_near_station = ""
	_near_trap = -1
	if raid_active or invasion_active or hero.dead:
		return
	var radius := float(cfg.interact_radius)
	var best := radius
	var prof_ := get_node_or_null("/root/Profile")
	var is_caged := prof_ != null and FurfurRules.caged(prof_.data)
	for id in cfg.layout.stations:
		if id == "cage" and not is_caged:
			continue
		var d := hero.global_position.distance_to(GameData.vec3(cfg.layout.stations[id]))
		if d < best:
			best = d
			_near_station = id
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return
	for i in _trap_nodes.size():
		var d := hero.global_position.distance_to(_trap_nodes[i].global_position)
		if d < best and i < prof.data.traps.size() and str(prof.data.traps[i]).is_empty() \
				and int(prof.data.inventory.get("glass_trap", 0)) > 0:
			best = d
			_near_trap = i
			_near_station = ""


func context_label() -> String:
	if can_pick_up:
		return "PICK UP"
	if _near_trap >= 0:
		return "SET TRAP"
	if not _near_station.is_empty():
		return STATION_NAMES[_near_station]
	return ""


func context_visible() -> bool:
	return not context_label().is_empty()


func context_action() -> void:
	if can_pick_up:
		pick_up()
	elif _near_trap >= 0:
		var prof := get_node("/root/Profile")
		if LairRules.set_trap(prof.data, _near_trap, "glass_trap"):
			prof.save()
			get_node("/root/Subs").cue("[glass spikes set by the door]")
			refresh()
	elif not _near_station.is_empty():
		station_requested.emit(_near_station)


func status_text() -> String:
	if invasion_active:
		for foe in _foes:
			if foe.kind == "Furfur" and not foe.dead:
				return "FURFUR KEMP  %d/%d" % [ceili(float(foe.hp)), int(foe.max_hp)]
	if raid_active:
		var left := _foes.filter(func(f): return not f.dead).size()
		return "RAID  WAVE %d/%d  %d LEFT" % [raid_wave, int(cfg.raid.waves), left]
	return "THE LAIR: " + str(cfg.corruption.looks[band].name)


# ---------------------------------------------------------------- the raid

## from_wave > 1: CONTINUE after quitting mid-raid. That wave comes in fresh; waves already
## beaten stay beaten, spent traps stay spent. Why (second fresh-eyes note on PR #23, Duff Nov 24):
## a reload used to restart the whole raid from wave 1.
func start_raid(from_wave := 1) -> void:
	if raid_active:
		return
	raid_active = true
	raid_wave = maxi(0, from_wave - 1)
	resume_wave = 0
	_wave_t = 0.0
	hero.position = GameData.vec3(cfg.layout.stations.trophy_wall) + Vector3(2.4, 0, 0.6)
	get_node("/root/Subs").cue("[LAIR RAID: they followed your heat home]")
	get_node("/root/Audio").music_layers("music_loop", "music_combat")
	raid_started.emit()
	voice_moment.emit("fight")
	_next_wave()


func _next_wave() -> void:
	raid_wave += 1
	var spawns: Array = cfg.layout.raid_spawns
	for k in int(cfg.raid.per_wave):
		var at := GameData.vec3(spawns[k % spawns.size()])
		_spawn_foe("Raider", at, Color("7a2a2a"), float(cfg.raid.raider_hp))
	get_node("/root/Subs").cue("[wave %d comes through the portal]" % raid_wave)


func _check_hit() -> void:
	super._check_hit()
	_check_foe_hits()


func _enemy(dt: float) -> void:
	if invasion_active and not hero.dead:
		_foe_ai(dt)
		return
	if not raid_active or hero.dead:
		return
	_foe_ai(dt)
	_traps()
	if _foes.any(func(f): return not f.dead):
		return
	if raid_wave < int(cfg.raid.waves):
		_wave_t += dt
		if _wave_t >= float(cfg.raid.wave_gap):
			_wave_t = 0.0
			_next_wave()
		return
	_end_raid(true)


## The run save's encounter blob (game.gd stores it under "pews" for every arena).
# ---------------------------------------------------------------- Furfur (M4)

func _build_cage(at: Vector3) -> void:
	# Bars on three sides against the right-hand wall; the open side faces the aisle (its station).
	var x0 := at.x + 0.6
	var x1 := float(cfg.layout.half_width)
	var z0 := at.z - 0.8
	var z1 := at.z + 0.8
	_box(Vector3(x0, 2.3, z0), Vector3(x1, 2.45, z1), Color("2b2622"), false)
	for k in 7:
		var z := lerpf(z0, z1, float(k) / 6.0)
		_box(Vector3(x0 - 0.04, 0, z - 0.04), Vector3(x0 + 0.04, 2.3, z + 0.04), Color("4a443e"))
	for k in 5:
		var x := lerpf(x0, x1, float(k) / 4.0)
		_box(Vector3(x - 0.04, 0, z0 - 0.04), Vector3(x + 0.04, 2.3, z0 + 0.04), Color("4a443e"))
		_box(Vector3(x - 0.04, 0, z1 - 0.04), Vector3(x + 0.04, 2.3, z1 + 0.04), Color("4a443e"))
	var floor_ := _ink_disc(Vector3((x0 + x1) / 2.0, 0.01, at.z), 0.7, Color("2a1414"))
	floor_.name = "CageFloor"
	_label("CAGE", Vector3((x0 + x1) / 2.0, 2.7, at.z))


## Furfur stands in the cage once chained, his head following the hero.
func _fill_cage(p: Dictionary) -> void:
	if not FurfurRules.caged(p) or caged_furfur != null:
		return
	var clips: Dictionary = moves.clips.duplicate()
	clips.erase("_why")
	caged_furfur = Character3D.new()
	caged_furfur.name = "CagedFurfur"
	caged_furfur.tint = Color("c0502a")
	caged_furfur.extra_actions = clips
	caged_furfur.position = GameData.vec3(furfur_cfg.cage.furfur_at)
	caged_furfur.look_target = hero
	caged_furfur.can_climb = false
	caged_furfur.can_vault = false
	add_child(caged_furfur)
	caged_furfur.heading = -PI / 2.0
	caged_furfur.model.rotation.y = -PI / 2.0


## He followed you home. One foe, the whole lair to fight in; the stations are shut until he's down.
func start_invasion() -> void:
	if invasion_active or raid_active:
		return
	invasion_active = true
	knockdowns = 0
	hero.position = GameData.vec3(cfg.layout.hero_spawn) + Vector3(0, 0, -2.0)
	_spawn_foe("Furfur", GameData.vec3(furfur_cfg.invasion.spawn), Color("c0502a"), float(furfur_cfg.invasion.furfur_hp))
	get_node("/root/Subs").cue("[FURFUR KEMP comes through the portal]")
	get_node("/root/Audio").music_layers("music_loop", "music_combat")


func furfur_foe() -> Dictionary:
	for foe in _foes:
		if foe.kind == "Furfur":
			return foe
	return {}


## The hero dropped: not GAME OVER. Back up at revive_hp_fraction; Furfur heals regen_fraction.
func invasion_knockdown() -> void:
	if not invasion_active:
		return
	knockdowns += 1
	var inv: Dictionary = furfur_cfg.invasion
	hero.revive()
	hp = maxi(1, int(float(max_hp) * float(inv.revive_hp_fraction)))
	for i in _foes.size():
		var foe: Dictionary = _foes[i]
		if foe.kind == "Furfur" and not foe.dead:
			foe.hp = minf(float(foe.max_hp), float(foe.hp) + float(foe.max_hp) * float(inv.regen_fraction))
			foe.attack_cd = float(inv.first_attack_delay)
			_foes[i] = foe
	get_node("/root/Subs").cue("[you get back up. Furfur laughs]")
	furfur_line.emit("knockdown")


func _on_foe_killed(foe: Dictionary) -> void:
	if foe.kind != "Furfur" or not invasion_active:
		return
	# He can't die: he goes down, and stays down long enough for the chains.
	invasion_active = false
	get_node("/root/Subs").cue("[Furfur goes down, still laughing]")
	furfur_beaten.emit()


## CHAIN HIM: the body on the floor goes, and he's in the cage.
func chain_furfur() -> void:
	for i in range(_foes.size() - 1, -1, -1):
		if _foes[i].kind == "Furfur":
			_drop(_foes[i].actor)
			_foes.remove_at(i)
	refresh()


## VENT: the hero takes it out on him with the hit it just unlocked.
func vent_on_furfur(hit: Dictionary) -> void:
	if caged_furfur == null:
		return
	var to := caged_furfur.global_position - hero.global_position
	hero.heading = atan2(to.x, to.z)
	hero.model.rotation.y = hero.heading
	hero.act(str(hit.get("action", "hook")))
	caged_furfur.hit(hero.global_position + Vector3(0, 1.2, 0), float(hit.get("power", 0.5)))
	get_node("/root/Feel").impact(caged_furfur.global_position + Vector3(0, 1.3, 0), 0.5, self)
	get_node("/root/Subs").cue("[you take it out on Furfur: %s]" % str(hit.get("name", "")).to_lower())


func save_state() -> Dictionary:
	return {"raid_wave": raid_wave if raid_active else resume_wave}


func restore_state(state: Dictionary) -> void:
	resume_wave = clampi(int(state.get("raid_wave", 0)), 0, int(cfg.raid.waves))


## A set trap fires on the first raider inside its radius, then it is spent.
func _traps() -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof == null:
		return
	for i in _trap_nodes.size():
		if i >= prof.data.traps.size() or str(prof.data.traps[i]).is_empty():
			continue
		for k in _foes.size():
			var foe: Dictionary = _foes[k]
			if foe.dead or foe.actor.global_position.distance_to(_trap_nodes[i].global_position) > float(cfg.raid.trap_radius):
				continue
			foe.hp = float(foe.hp) - float(cfg.raid.trap_damage)
			foe.actor.hit(_trap_nodes[i].global_position, 0.6)
			get_node("/root/Feel").burst(_trap_nodes[i].global_position + Vector3(0, 0.4, 0), 0.8, self)
			get_node("/root/Subs").cue("[glass trap fires]")
			traps_fired += 1
			LairRules.spend_trap(prof.data, i)
			prof.save()
			if foe.hp <= 0.0:
				kill_foe(k)
			else:
				_foes[k] = foe
			refresh()
			break


func _end_raid(won: bool) -> void:
	raid_active = false
	for foe in _foes:
		foe.actor.move_input = Vector2.ZERO
		foe.warn.visible = false
	var prof := get_node_or_null("/root/Profile")
	var result := {}
	if prof != null:
		result = LairRules.raid_over(prof.data, won, cfg, LairRules.perks(prof.data, GameData.load_json("trophies")))
		prof.save()
	get_node("/root/Subs").cue("[the lair holds]" if won else "[they ransack the cold room]")
	refresh()
	raid_finished.emit(won, result)


## The hero fell in the raid: not GAME OVER (BUILD_SPEC). Parts are lost; the hero gets back up.
func raid_failed() -> Dictionary:
	for i in _foes.size():
		if not _foes[i].dead:
			kill_foe(i)
	# Up first, then end the raid: its checkpoint skips a dead hero (fresh-eyes on PR #23).
	hero.revive()
	hero.position = GameData.vec3(cfg.layout.hero_spawn)
	hp = maxi(1, int(float(max_hp) * float(cfg.raid.revive_hp_fraction)))
	_end_raid(false)
	return {}


func bug_state() -> String:
	return "lair: hp %d band %d raid %s wave %d invasion %s near %s" % [hp, band, raid_active, raid_wave, invasion_active, _near_station]

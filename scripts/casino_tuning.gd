extends Node
## Dynamic numeric sliders scoped to Casino-only data.
var config: Dictionary
var paths := {}
var TUNE := {}
func _init(data: Dictionary) -> void:
	config = data
	_scan(data, [])
func _scan(data: Dictionary, path: Array) -> void:
	for key in data:
		if key == "camera_distance": # CameraRig already exposes its live distance slider.
			continue
		var next := path + [key]
		if data[key] is Dictionary:
			_scan(data[key], next)
		elif key == "phase_hp" and data[key] is Array:
			for index in data[key].size():
				var id := "casino_phase_%d_hp" % (index+1)
				paths[id] = next + [index]
				TUNE[id] = [20.0, 400.0, 1.0]
		elif data[key] is float or data[key] is int:
			var id := "casino_" + "_".join(PackedStringArray(next))
			paths[id] = next
			var minimum := 0.0
			var maximum := maxf(float(data[key])*3,1.0)
			if str(key).ends_with("_hp") or key == "durability":
				minimum = 1.0
			elif str(key).contains("telegraph") or str(key).contains("windup"):
				minimum = 0.5
			elif str(key).contains("cooldown") or str(key).contains("duration") or str(key).contains("speed"):
				minimum = 0.1
			elif key == "chance":
				maximum = 1.0
			TUNE[id] = [minimum, maximum]
func _ready() -> void:
	add_to_group("tunable")
	get_node("/root/DebugMenu").apply_tune(self)
func _get(property: StringName) -> Variant:
	if not paths.has(property):
		return null
	var v: Variant = config
	for key in paths[property]:
		v = v[key]
	return v
func _set(property: StringName, value: Variant) -> bool:
	if not paths.has(property):
		return false
	var path: Array = paths[property]
	var v: Variant = config
	for i in range(path.size()-1):
		v = v[path[i]]
	v[path.back()] = value
	return true

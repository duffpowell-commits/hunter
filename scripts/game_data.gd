extends RefCounted
## Reads Hunter's content files in data/ (JSON). Content is data, not code (docs/BUILD_SPEC.md):
## adding an enemy or a weapon means editing data/*.json, not scripts.
##   var moves := GameData.load_json("moves")      # data/moves.json as a Dictionary
## Why (Hunter M1, Nov 21): one place that reads and caches the files. export_presets.cfg must
## list data/*.json in include_filter, or the APK ships without them (test_data_files_ship).

static var _cache := {}


static func load_json(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := "res://data/%s.json" % name
	var d := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			d = parsed
	if d.is_empty():
		push_error("missing or broken " + path)
	_cache[name] = d
	return d


## [r, g, b] from JSON -> Color.
static func color(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))


## [x, y, z] from JSON -> Vector3.
static func vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

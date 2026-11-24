extends Node
## Autoload "Save": the run in progress, one JSON file. Games call Save.write(state) at every
## checkpoint and the game scene calls it again on pause and when the phone sends the app to
## the background (a call, a notification, the home button). Title shows CONTINUE when
## Save.exists(). GAME OVER calls Save.clear().
##
## Writes go to a temp file first, then replace the real one, so a kill mid-write can't leave
## a half-written save.

## 2 = Hunter M1 (Nov 21): {"level" = round, "score" = knockouts, "hp"}; v1 had Orb Catch "lives".
## 3 = Hunter M2: optional encounter checkpoint under "pews".
## 4 = Hunter M3 (Nov 23): "where" ("pews" or "lair") says which scene CONTINUE opens; the rewards
##     (cash, heat, parts, corruption, inventory, trophies, voices, BRUTAL slots) moved out of the run
##     into Profile (user://profile.json), which NEW GAME and GAME OVER never clear.
const VERSION := 4
## The reward keys a v3 run kept inside "pews"; v4 hands them to Profile once.
const CARRY := ["cash", "heat", "parts", "corruption", "inventory", "trophies", "unlocked_voices", "extra_special_slots"]
var path := "user://run.json"


func exists() -> bool:
	return FileAccess.file_exists(path)


func write(state: Dictionary) -> bool:
	var data := state.duplicate(true)
	data["_version"] = VERSION
	data["_saved_at"] = Time.get_unix_time_from_system()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	return DirAccess.rename_absolute(abs_tmp, abs_path) == OK


## The saved state, or {} if there's none (or it's unreadable).
func read() -> Dictionary:
	if not exists():
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {}
	var d := _migrate(j.data)
	if d.has("carry"):
		# Hand an old run's rewards to the profile, then rewrite the run without them so they
		# can't be absorbed twice.
		var profile := get_node_or_null("/root/Profile")
		if profile != null:
			profile.absorb(d.carry)
		d.erase("carry")
		write(d)
	return d


func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Old saves keep loading: bump VERSION and upgrade here when the save format changes.
func _migrate(d: Dictionary) -> Dictionary:
	if int(d.get("_version", 1)) < 2:
		# Why (Hunter M1): Orb Catch's lives mean nothing in the arena; start at full HP.
		d.erase("lives")
		d["hp"] = 100
		d["_version"] = 2
	if int(d.get("_version", 1)) < 3:
		if not d.has("pews"):
			d["pews"] = {}
		d["_version"] = 3
	if int(d.get("_version", 1)) < 4:
		var pews: Dictionary = d.get("pews", {})
		var carry := {}
		for k in CARRY:
			if pews.has(k):
				carry[k] = pews[k]
				pews.erase(k)
		if not carry.is_empty():
			d["carry"] = carry
		d["where"] = "pews"
		d["_version"] = 4
	return d

extends Node
## Autoload "Save": the run in progress, one JSON file. Games call Save.write(state) at every
## checkpoint and the game scene calls it again on pause and when the phone sends the app to
## the background (a call, a notification, the home button). Title shows CONTINUE when
## Save.exists(). GAME OVER calls Save.clear().
##
## Writes go to a temp file first, then replace the real one, so a kill mid-write can't leave
## a half-written save.

## 2 = Hunter M1 (Nov 21): {"level" = round, "score" = knockouts, "hp"}; v1 had Orb Catch "lives".
const VERSION := 2
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
	return _migrate(j.data)


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
	return d

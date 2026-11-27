extends Node
## Autoload "Profile": everything the hunter keeps between runs, in its own file
## (user://profile.json). Cash, heat, parts, corruption, the inventory, trophies and where they hang,
## voices and which are equipped, workshop upgrades, set traps, nights, raids.
## Why (Nov 23, M2 review): rewards lived only in the run save's "pews" blob, so NEW GAME and
## GAME OVER wiped them. The run save (Save) now holds only the run in progress; this file is never
## cleared by NEW GAME or a death. The rules that change it live in lair_rules.gd (no nodes).
##
## Old run saves (Save v3) carried the rewards; Save._migrate lifts them out and Save.read() hands
## them to absorb() once, so a player who updates mid-run keeps what they earned.

const LairRules = preload("res://scripts/lair_rules.gd")

## 1 = Hunter M3 (Nov 23).
const VERSION := 2
var path := "user://profile.json"
var data: Dictionary = {}

signal changed


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	data = LairRules.blank()
	if not FileAccess.file_exists(path):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return
	data = _migrate(j.data)


## Writes through a temp file, like Save, so a kill mid-write can't corrupt the profile.
func save() -> bool:
	var d := data.duplicate(true)
	d["_version"] = VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("profile save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ok := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK
	changed.emit()
	return ok


## Tests and the dev menu only. A player never loses the profile.
func reset() -> void:
	data = LairRules.blank()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	changed.emit()


## Rewards from an old run save (Save v3 "pews" blob). Adds, never replaces.
func absorb(carry: Dictionary) -> void:
	LairRules.gain(data, {"cash": int(carry.get("cash", 0)), "heat": int(carry.get("heat", 0)),
		"parts": int(carry.get("parts", 0)), "corruption": int(carry.get("corruption", 0))})
	var inv: Dictionary = carry.get("inventory", {})
	for id in inv:
		data.inventory[id] = int(data.inventory.get(id, 0)) + int(inv[id])
	for t in carry.get("trophies", []):
		LairRules.add_trophy(data, str(t))
	for v in carry.get("unlocked_voices", []):
		LairRules.add_voice(data, str(v))
	var slots: Dictionary = carry.get("extra_special_slots", {})
	for v in slots:
		data.voice_levels[v] = int(data.voice_levels.get(v, 0)) + int(slots[v])
	save()


func _migrate(d: Dictionary) -> Dictionary:
	# Fill any key a newer build added, so old profiles keep loading.
	var blank := LairRules.blank()
	for k in blank:
		if not d.has(k):
			d[k] = blank[k]
	d["_version"] = VERSION
	return d

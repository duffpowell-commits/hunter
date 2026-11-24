extends RefCounted
## Hunter M3 (Nov 23): the lair stations' sheets, opened by game.gd when the hero taps a station's
## context button. Every change goes through lair_rules.gd, saves the profile, refreshes the room
## and reopens the sheet so it always shows the new state. Thumb-sized buttons, one column (540 UI).

const UI = preload("res://scripts/ui.gd")
const GameData = preload("res://scripts/game_data.gd")
const LairRules = preload("res://scripts/lair_rules.gd")


static func open(game: Control, id: String) -> VBoxContainer:
	var sh := UI.sheet(game)
	sh.get_meta("sheet").name = "Station_" + id
	match id:
		"trophy_wall": _trophies(game, sh)
		"workshop": _workshop(game, sh)
		"cold_room": _cold_room(game, sh)
		"voices": _voices(game, sh)
		"map_room": _map(game, sh)
	sh.add_child(UI.button("CLOSE", func(): UI.close_sheet(sh)))
	return sh


static func _p(game: Node) -> Dictionary:
	return game.get_node("/root/Profile").data


static func _changed(game: Control, sh: VBoxContainer, id: String) -> void:
	game.get_node("/root/Profile").save()
	if game.arena != null and game.arena.has_method("refresh"):
		game.arena.call("refresh")
	UI.close_sheet(sh)
	open(game, id)


static func _title(sh: VBoxContainer, text: String, sub: String) -> void:
	sh.add_child(UI.label(text, 28, UI.ACCENT))
	if not sub.is_empty():
		sh.add_child(UI.label(sub, 16, UI.DIM))


# ---------------------------------------------------------------- trophy wall

static func _trophies(game: Control, sh: VBoxContainer) -> void:
	var p := _p(game)
	var tro := GameData.load_json("trophies")
	var perk := LairRules.perks(p, tro)
	_title(sh, "TROPHY WALL", "Row 1 offence, row 2 defence, row 3 utility. Moving is free.")
	sh.add_child(UI.label("NOW: +%d%% special dmg, +%d max HP, heat -%d more a night" % [
		int(round(float(perk.special_damage) * 100.0)), int(perk.max_hp), int(perk.heat_per_night)], 16))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UI.GAP)
	grid.add_theme_constant_override("v_separation", UI.GAP)
	sh.add_child(grid)
	for i in p.wall.size():
		var id := str(p.wall[i])
		var row := LairRules.row_of(i, tro).to_upper()
		var text := "%s\n%s" % [row, "EMPTY" if id.is_empty() else str(tro.trophies.get(id, {}).get("name", id))]
		var b := UI.button(text, func(): _pick_trophy(game, sh, i), 96)
		b.name = "Slot%d" % i
		b.custom_minimum_size.x = 200
		b.add_theme_font_size_override("font_size", UI.font_size(16))
		grid.add_child(b)


static func _pick_trophy(game: Control, sh: VBoxContainer, slot: int) -> void:
	var p := _p(game)
	var tro := GameData.load_json("trophies")
	var row := LairRules.row_of(slot, tro)
	var pick := UI.sheet(game)
	pick.add_child(UI.label("%s SLOT" % row.to_upper(), 24, UI.ACCENT))
	if p.trophies.is_empty():
		pick.add_child(UI.label("No trophies yet. A CLEAN finisher leaves one intact.", 18))
	for id in p.trophies:
		var t: Dictionary = tro.trophies.get(id, {})
		var what := str(t.get(row, {}).get("what", ""))
		pick.add_child(UI.button("%s: %s" % [t.get("name", id), what], func():
			LairRules.place_trophy(p, slot, str(id))
			UI.close_sheet(pick)
			_changed(game, sh, "trophy_wall"), 88))
	pick.add_child(UI.button("EMPTY THIS SLOT", func():
		LairRules.place_trophy(p, slot, "")
		UI.close_sheet(pick)
		_changed(game, sh, "trophy_wall")))
	pick.add_child(UI.button("BACK", func(): UI.close_sheet(pick)))


# ---------------------------------------------------------------- workshop

static func _workshop(game: Control, sh: VBoxContainer) -> void:
	var p := _p(game)
	var lair := GameData.load_json("lair")
	var rec := GameData.load_json("recipes")
	_title(sh, "WORKSHOP", "PARTS %d   BAG %d/%d" % [int(p.parts), LairRules.slots_used(p, int(lair.inventory.stack)), int(lair.inventory.slots)])
	for r: Dictionary in rec.recipes:
		var cost := PackedStringArray()
		for k in r.cost:
			cost.append("%d %s" % [int(r.cost[k]), str(k).replace("_", " ")])
		var level := " (LV %d/%d)" % [int(p.upgrades.get(r.id, 0)), int(r.get("max_level", 1))] if r.kind == "upgrade" else ""
		sh.add_child(UI.label("%s%s: %s. Costs %s." % [r.name, level, r.what, ", ".join(cost)], 16))
		var block := LairRules.craft_block(p, r, lair)
		var b := UI.button("CRAFT " + str(r.name) if block.is_empty() else block, func():
			if LairRules.craft(p, r, lair):
				game.get_node("/root/Subs").cue("[crafted %s]" % str(r.name).to_lower())
				_changed(game, sh, "workshop"))
		b.name = "Craft_" + str(r.id)
		b.disabled = not block.is_empty()
		b.add_theme_font_size_override("font_size", UI.font_size(18))
		sh.add_child(b)


# ---------------------------------------------------------------- cold room (stores)

static func _cold_room(game: Control, sh: VBoxContainer) -> void:
	var p := _p(game)
	var lair := GameData.load_json("lair")
	var items: Dictionary = GameData.load_json("recipes").items
	_title(sh, "COLD ROOM", "What you've dragged home. Raids eat into it.")
	sh.add_child(UI.label("CASH %d   PARTS %d   HEAT %d   CORRUPTION %d" % [int(p.cash), int(p.parts), int(p.heat), int(p.corruption)], 18))
	sh.add_child(UI.label("BAG %d/%d SLOTS (stacks of %d)" % [LairRules.slots_used(p, int(lair.inventory.stack)), int(lair.inventory.slots), int(lair.inventory.stack)], 16, UI.DIM))
	if p.inventory.is_empty():
		sh.add_child(UI.label("Empty.", 18))
	for id in p.inventory:
		sh.add_child(UI.label("%s x%d" % [items.get(id, {}).get("name", str(id).to_upper()), int(p.inventory[id])], 18))
	sh.add_child(UI.label("Nights %d   Raids won %d, lost %d" % [int(p.nights), int(p.raids_won), int(p.raids_lost)], 16, UI.DIM))


# ---------------------------------------------------------------- voices

static func _voices(game: Control, sh: VBoxContainer) -> void:
	var p := _p(game)
	_title(sh, "VOICES", "Up to 2. Slot 1 takes your UP swipe, slot 2 your DOWN swipe.")
	for slot in 2:
		var id := str(p.equipped[slot]) if slot < p.equipped.size() else ""
		var text := "SLOT %d (%s): %s" % [slot + 1, ["UP", "DOWN"][slot], "EMPTY" if id.is_empty() else _voice_label(p, id)]
		var b := UI.button(text, func(): _pick_voice(game, sh, slot), 88)
		b.name = "VoiceSlot%d" % slot
		b.add_theme_font_size_override("font_size", UI.font_size(17))
		sh.add_child(b)


static func _voice_label(p: Dictionary, id: String) -> String:
	var v := GameData.load_json("voices/" + id)
	var m := LairRules.voice_move(v, int(p.voice_levels.get(id, 0)))
	return "%s: %s %d" % [str(v.get("short", id)).to_upper(), m.get("name", ""), int(m.get("damage", 0))]


static func _pick_voice(game: Control, sh: VBoxContainer, slot: int) -> void:
	var p := _p(game)
	var pick := UI.sheet(game)
	pick.add_child(UI.label("SLOT %d" % (slot + 1), 24, UI.ACCENT))
	if p.voices.is_empty():
		pick.add_child(UI.label("No voices yet. EAT a boss.", 18))
	for id in p.voices:
		pick.add_child(UI.button(_voice_label(p, str(id)), func():
			LairRules.equip_voice(p, slot, str(id))
			UI.close_sheet(pick)
			_changed(game, sh, "voices"), 88))
	pick.add_child(UI.button("EMPTY THIS SLOT", func():
		LairRules.equip_voice(p, slot, "")
		UI.close_sheet(pick)
		_changed(game, sh, "voices")))
	pick.add_child(UI.button("BACK", func(): UI.close_sheet(pick)))


# ---------------------------------------------------------------- map room

static func _map(game: Control, sh: VBoxContainer) -> void:
	var pending := bool(_p(game).raid_pending)
	_title(sh, "MAP ROOM", "Hold the lair first: a raid is coming." if pending else "Pick a realm and a target.")
	for r: Dictionary in GameData.load_json("realms").realms:
		var open_: bool = bool(r.open)
		var b := UI.button(("HUNT %s: %s" % [r.name, r.target]) if open_ else ("LOCKED: %s" % r.name), func():
			UI.close_sheet(sh)
			game.call("start_hunt", str(r.id)), 80)
		b.name = "Realm_" + str(r.id)
		b.disabled = not open_ or pending
		b.add_theme_font_size_override("font_size", UI.font_size(17))
		sh.add_child(b)

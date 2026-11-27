extends RefCounted
## Hunter M3 (Nov 23): the rules of the lair and the profile, no nodes. Every function takes the
## profile dictionary (Profile.data) and the config it needs (data/lair.json, recipes.json,
## trophies.json), so tests run them without a scene. Numbers come from data with TUNE sliders.
##   gain / spend        cash, heat, parts, corruption (heat and corruption stay 0-100)
##   inventory           24 slots, stacks of 9 (BUILD_SPEC); parts are a pool, not a slot item
##   craft               workshop recipes: upgrade, trap, heal
##   place_trophy        the 3-row wall; moving is free; perks() sums what the rows give
##   equip_voice         up to 2 voices; slot 1 takes the UP swipe, slot 2 the DOWN swipe
##   arrive_home         a night passes (heat -10 and the utility perks), unless heat is at the raid
##                       line: then a raid is pending and the night waits until it is fought
##   raid_over           won: heat drops; lost: some stored parts are lost, never the save

const GameData = preload("res://scripts/game_data.gd")


static func blank() -> Dictionary:
	return {"cash": 0, "heat": 0, "parts": 0, "corruption": 0, "inventory": {},
		"trophies": [], "wall": ["", "", "", "", "", ""],
		"voices": [], "equipped": [], "voice_levels": {}, "gus_debt_paid": false, "gus_finisher": "",
		"upgrades": {}, "traps": ["", "", ""],
		"nights": 0, "hunts": 0, "raid_pending": false, "raids_won": 0, "raids_lost": 0,
		"failures_unvented": 0,
		# M4 (Nov 26): Furfur Kemp (furfur_rules.gd). Stage "none" | "invading" | "caged".
		"furfur": "none", "furfur_lore": 0, "furfur_talk_night": -1, "clauses_read": 0, "vent_unlocks": 0}


static func gain(p: Dictionary, delta: Dictionary) -> void:
	for k in delta:
		var v := int(p.get(k, 0)) + int(delta[k])
		if k in ["heat", "corruption"]:
			v = clampi(v, 0, 100)
		elif k in ["cash", "parts"]:
			v = maxi(v, 0)
		p[k] = v


static func add_trophy(p: Dictionary, id: String) -> bool:
	if id.is_empty() or p.trophies.has(id):
		return false
	p.trophies.append(id)
	# A new trophy goes on the first free slot so the player sees it at once; moving it is free.
	var wall: Array = p.wall
	for i in wall.size():
		if str(wall[i]).is_empty():
			wall[i] = id
			break
	return true


static func add_voice(p: Dictionary, id: String) -> bool:
	if id.is_empty() or p.voices.has(id):
		return false
	p.voices.append(id)
	if p.equipped.size() < 2:
		p.equipped.append(id)
	return true


# ---------------------------------------------------------------- inventory

static func slots_used(p: Dictionary, stack: int) -> int:
	var used := 0
	for id in p.inventory:
		used += ceili(float(int(p.inventory[id])) / float(maxi(stack, 1)))
	return used


static func can_add(p: Dictionary, id: String, count: int, cfg: Dictionary) -> bool:
	var inv: Dictionary = cfg.get("inventory", {})
	var stack := int(inv.get("stack", 9))
	var trial := p.duplicate(true)
	trial.inventory[id] = int(trial.inventory.get(id, 0)) + count
	return slots_used(trial, stack) <= int(inv.get("slots", 24))


## Adds what fits; returns how many went in.
static func add_item(p: Dictionary, id: String, count: int, cfg: Dictionary) -> int:
	var added := 0
	for i in count:
		if not can_add(p, id, 1, cfg):
			break
		p.inventory[id] = int(p.inventory.get(id, 0)) + 1
		added += 1
	return added


static func take_item(p: Dictionary, id: String, count := 1) -> bool:
	if int(p.inventory.get(id, 0)) < count:
		return false
	p.inventory[id] = int(p.inventory[id]) - count
	if int(p.inventory[id]) <= 0:
		p.inventory.erase(id)
	return true


# ---------------------------------------------------------------- workshop

static func recipe(recipes: Dictionary, id: String) -> Dictionary:
	for r: Dictionary in recipes.get("recipes", []):
		if str(r.id) == id:
			return r
	return {}


## "" when it can be crafted, else the reason the button shows.
static func craft_block(p: Dictionary, r: Dictionary, cfg: Dictionary) -> String:
	if r.is_empty():
		return "UNKNOWN"
	if r.kind == "upgrade" and int(p.upgrades.get(r.id, 0)) >= int(r.get("max_level", 1)):
		return "MAXED"
	for k in r.cost:
		var have := int(p.parts) if k == "parts" else int(p.inventory.get(k, 0))
		if have < int(r.cost[k]):
			return "NEED %s" % ("PARTS" if k == "parts" else str(k).replace("_", " ").to_upper())
	if r.has("makes"):
		# The materials leave first, so a full inventory can still make room for the result.
		var trial := p.duplicate(true)
		for k in r.cost:
			if k != "parts":
				take_item(trial, k, int(r.cost[k]))
		if not can_add(trial, str(r.makes), 1, cfg):
			return "BAG FULL"
	return ""


static func craft(p: Dictionary, r: Dictionary, cfg: Dictionary) -> bool:
	if not craft_block(p, r, cfg).is_empty():
		return false
	for k in r.cost:
		if k == "parts":
			p.parts = int(p.parts) - int(r.cost[k])
		else:
			take_item(p, k, int(r.cost[k]))
	if r.kind == "upgrade":
		p.upgrades[r.id] = int(p.upgrades.get(r.id, 0)) + 1
	else:
		add_item(p, str(r.makes), 1, cfg)
	return true


## Extra durability every improvised weapon gets from workshop upgrades.
static func durability_bonus(p: Dictionary, recipes: Dictionary) -> int:
	var total := 0
	for r: Dictionary in recipes.get("recipes", []):
		if r.kind == "upgrade":
			total += int(p.upgrades.get(r.id, 0)) * int(r.get("durability", 0))
	return total


# ---------------------------------------------------------------- trophy wall

## Slot i sits on row i / 2 (2 slots per row). Placing a trophy that hangs elsewhere moves it.
static func place_trophy(p: Dictionary, slot: int, id: String) -> bool:
	var wall: Array = p.wall
	if slot < 0 or slot >= wall.size() or (not id.is_empty() and not p.trophies.has(id)):
		return false
	for i in wall.size():
		if str(wall[i]) == id:
			wall[i] = ""
	wall[slot] = id
	return true


static func row_of(slot: int, trophies: Dictionary) -> String:
	var rows: Array = trophies.get("rows", ["OFFENCE", "DEFENCE", "UTILITY"])
	var per_row := maxi(1, floori(float(trophies.get("slots", 6)) / float(rows.size())))
	return str(rows[mini(floori(float(slot) / float(per_row)), rows.size() - 1)]).to_lower()


## {"special_damage": 0.15, "max_hp": 15, "heat_per_night": 5}: the sum of every hung trophy's
## perk for the row it hangs on.
static func perks(p: Dictionary, trophies: Dictionary) -> Dictionary:
	var out := {"special_damage": 0.0, "max_hp": 0, "heat_per_night": 0}
	var wall: Array = p.wall
	for i in wall.size():
		var id := str(wall[i])
		if id.is_empty() or not trophies.get("trophies", {}).has(id):
			continue
		var perk: Dictionary = trophies.trophies[id].get(row_of(i, trophies), {})
		for k in perk:
			if out.has(k):
				out[k] = out[k] + perk[k]
	out.max_hp = int(out.max_hp)
	out.heat_per_night = int(out.heat_per_night)
	return out


# ---------------------------------------------------------------- voices

## Puts a voice in slot 0 or 1 (it leaves the other slot if it was there). "" empties the slot.
static func equip_voice(p: Dictionary, slot: int, id: String) -> bool:
	if slot < 0 or slot > 1 or (not id.is_empty() and not p.voices.has(id)):
		return false
	var eq: Array = p.equipped.duplicate()
	while eq.size() < 2:
		eq.append("")
	for i in 2:
		if eq[i] == id:
			eq[i] = ""
	eq[slot] = id
	p.equipped = eq
	return true


## The swipe each equipped voice takes: {"up": "vesper"}.
static func voice_slots(p: Dictionary) -> Dictionary:
	var out := {}
	var dirs := ["up", "down"]
	for i in mini(p.equipped.size(), 2):
		if not str(p.equipped[i]).is_empty() and (p.equipped[i] != "gus" or p.get("gus_debt_paid", false)):
			out[dirs[i]] = str(p.equipped[i])
	return out


## The special a voice gives at its BRUTAL level: base damage + per_level for each level.
static func voice_move(voice: Dictionary, level: int) -> Dictionary:
	var m: Dictionary = voice.get("special", {}).duplicate()
	if m.is_empty():
		return m
	m.damage = float(m.damage) + float(m.get("per_level", 0)) * level
	m.erase("per_level")
	return m


# ---------------------------------------------------------------- heat, nights, raids

static func corruption_band(corruption: int, cfg: Dictionary) -> int:
	var at: Array = cfg.get("corruption", {}).get("band_at", [34, 67])
	var band := 0
	for v in at:
		if corruption >= int(v):
			band += 1
	return band


## A night in the lair: heat falls by per_night plus the utility perks.
static func night(p: Dictionary, cfg: Dictionary, perk: Dictionary) -> int:
	var drop := int(cfg.heat.per_night) + int(perk.get("heat_per_night", 0))
	gain(p, {"heat": -drop})
	p.nights = int(p.nights) + 1
	return drop


## Coming home through the portal. Returns {"raid": true} when heat is at the raid line.
static func arrive_home(p: Dictionary, cfg: Dictionary, perk: Dictionary) -> Dictionary:
	p.hunts = int(p.hunts) + 1
	if int(p.heat) >= int(cfg.heat.raid_at):
		p.raid_pending = true
		return {"raid": true}
	return {"raid": false, "heat_drop": night(p, cfg, perk)}


## The raid is over. Won: heat drops by win_heat_drop. Lost: a fraction of stored parts is gone and
## heat drops less. The night passes either way. Returns what changed.
static func raid_over(p: Dictionary, won: bool, cfg: Dictionary, perk: Dictionary) -> Dictionary:
	var raid: Dictionary = cfg.raid
	var lost := 0
	if won:
		p.raids_won = int(p.raids_won) + 1
		gain(p, {"heat": -int(raid.win_heat_drop)})
	else:
		p.raids_lost = int(p.raids_lost) + 1
		lost = int(floor(float(p.parts) * float(raid.lose_parts_fraction)))
		gain(p, {"parts": -lost, "heat": -int(raid.lose_heat_drop)})
	p.raid_pending = false
	night(p, cfg, perk)
	return {"won": won, "parts_lost": lost}


## Sets a trap from the inventory on a free spot.
static func set_trap(p: Dictionary, spot: int, item: String) -> bool:
	var traps: Array = p.traps
	if spot < 0 or spot >= traps.size() or not str(traps[spot]).is_empty():
		return false
	if not take_item(p, item):
		return false
	traps[spot] = item
	return true


static func spend_trap(p: Dictionary, spot: int) -> void:
	if spot >= 0 and spot < p.traps.size():
		p.traps[spot] = ""


static func realm_open(p: Dictionary, id: String) -> bool:
	for realm in GameData.load_json("realms").realms:
		if realm.id == id:
			return bool(realm.open) or p.voices.has(realm.get("requires_voice", ""))
	return false

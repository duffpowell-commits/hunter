extends RefCounted
## Hunter M4 (Nov 26): the rules of Furfur Kemp, no nodes (DESIGN.md "Furfur Kemp", BUILD_SPEC M4).
## Every function takes the profile dictionary (Profile.data) and data/furfur.json, so tests run
## them without a scene.
##   stage            "none" -> "invading" (he followed you home) -> "caged" (chained in the lair)
##   arrive           on the way home: a lost hunt (LIMP HOME), or after_hunts arrivals, starts the
##                    invasion once. Saved as a stage, so quitting mid-fight restarts the fight.
##   chain            you won ugly: he's caged, corruption rises, the cage station opens
##   talk             one lore leak a night, in order
##   mercy            costs cash; he reads the next hidden clause of Price's contract to you
##   vent             only with a real failure unvented; each one adds the next hit to the light
##                    string and some corruption. One unlock per real failure, so it can't be farmed.

const LairRules = preload("res://scripts/lair_rules.gd")


static func stage(p: Dictionary) -> String:
	return str(p.get("furfur", "none"))


static func caged(p: Dictionary) -> bool:
	return stage(p) == "caged"


## Called once per arrival home, after LairRules.arrive_home. Returns true when he invades now.
static func arrive(p: Dictionary, limped: bool, cfg: Dictionary) -> bool:
	if stage(p) != "none":
		return stage(p) == "invading"
	if limped or int(p.get("hunts", 0)) >= int(cfg.trigger.after_hunts):
		p.furfur = "invading"
		return true
	return false


static func chain(p: Dictionary, cfg: Dictionary) -> bool:
	if stage(p) != "invading":
		return false
	p.furfur = "caged"
	LairRules.gain(p, {"corruption": int(cfg.invasion.chain_corruption)})
	return true


# ---------------------------------------------------------------- talk

## "" when he'll talk, else why not (the button shows it).
static func talk_block(p: Dictionary, cfg: Dictionary) -> String:
	if not caged(p):
		return "NOT CAGED"
	if int(p.furfur_lore) >= cfg.lore.size():
		return "HE'S TOLD YOU ALL HE WILL"
	if int(p.furfur_talk_night) == int(p.nights):
		return "HE'S DONE TALKING TONIGHT"
	return ""


## The next lore line, or "" when he won't talk.
static func talk(p: Dictionary, cfg: Dictionary) -> String:
	if not talk_block(p, cfg).is_empty():
		return ""
	var line := str(cfg.lore[int(p.furfur_lore)])
	p.furfur_lore = int(p.furfur_lore) + 1
	p.furfur_talk_night = int(p.nights)
	return line


static func heard(p: Dictionary, cfg: Dictionary) -> Array:
	return cfg.lore.slice(0, mini(int(p.furfur_lore), cfg.lore.size()))


# ---------------------------------------------------------------- mercies and the contract

static func mercy_block(p: Dictionary, cfg: Dictionary) -> String:
	if not caged(p):
		return "NOT CAGED"
	if int(p.clauses_read) >= cfg.contract.hidden.size():
		return "NO CLAUSES LEFT TO READ"
	if int(p.cash) < int(cfg.cage.mercy_cost):
		return "NEED $%d" % int(cfg.cage.mercy_cost)
	return ""


## The next mercy's name ("A BLANKET"), for the button.
static func next_mercy(p: Dictionary, cfg: Dictionary) -> String:
	var m: Array = cfg.contract.mercies
	return str(m[mini(int(p.clauses_read), m.size() - 1)])


## Pays the mercy and returns the clause he reads, or "".
static func mercy(p: Dictionary, cfg: Dictionary) -> String:
	if not mercy_block(p, cfg).is_empty():
		return ""
	LairRules.gain(p, {"cash": -int(cfg.cage.mercy_cost)})
	var clause := str(cfg.contract.hidden[int(p.clauses_read)])
	p.clauses_read = int(p.clauses_read) + 1
	return clause


## Every clause: [text, revealed]. Hidden ones not yet read come back as ["", false].
static func clauses(p: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	for c in cfg.contract.open:
		out.append([str(c), true])
	for i in cfg.contract.hidden.size():
		out.append([str(cfg.contract.hidden[i]), true] if i < int(p.clauses_read) else ["", false])
	return out


# ---------------------------------------------------------------- vent

static func vent_block(p: Dictionary, cfg: Dictionary) -> String:
	if not caged(p):
		return "NOT CAGED"
	if int(p.vent_unlocks) >= cfg.vent.strings.size():
		return "NOTHING LEFT TO LEARN"
	if int(p.failures_unvented) <= 0:
		return "ONLY AFTER A REAL LOSS"
	return ""


## Spends one real failure: +1 string hit and corruption. Returns the hit it unlocked, or {}.
static func vent(p: Dictionary, cfg: Dictionary) -> Dictionary:
	if not vent_block(p, cfg).is_empty():
		return {}
	var hit: Dictionary = cfg.vent.strings[int(p.vent_unlocks)]
	p.vent_unlocks = int(p.vent_unlocks) + 1
	p.failures_unvented = int(p.failures_unvented) - 1
	LairRules.gain(p, {"corruption": int(cfg.vent.corruption)})
	return hit


## The hits venting has added to the end of the light string, in order.
static func light_extras(p: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	for i in mini(int(p.get("vent_unlocks", 0)), cfg.vent.strings.size()):
		out.append((cfg.vent.strings[i] as Dictionary).duplicate())
	return out

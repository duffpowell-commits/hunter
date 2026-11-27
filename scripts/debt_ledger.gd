extends RefCounted
## Read-only journal. The contract and milestones are projections of existing profile state.
const UI = preload("res://scripts/ui.gd")
const GameData = preload("res://scripts/game_data.gd")
const FurfurRules = preload("res://scripts/furfur_rules.gd")

static func entries(p: Dictionary, cfg: Dictionary) -> Array[String]:
	var obligation := "Current account: Brother Vesper, the Pews."
	if p.trophies.has("vesper"):
		obligation = "Vesper’s account recorded. Consult the map room for available work."
	var pages: Array[String] = ["CAIN VANTRE\n\n" + obligation + "\n\nThe Firm spared my life. I collect its accounts for the promised freedom of my guarantor and me.\n\nNo balance has been disclosed."]
	for clause in FurfurRules.clauses(p, cfg):
		if clause[1]:
			pages.append("CONTRACT\n\n" + str(clause[0]))
	for line in FurfurRules.heard(p, cfg):
		pages.append("FURFUR'S WORDS\n\n" + str(line))
	var done: Array[String] = []
	if p.trophies.has("vesper"):
		done.append("Vesper's collar recovered")
	if int(p.get("hunts", 0)) > 0:
		done.append("Returned from a hunt")
	if p.get("furfur", "none") == "caged":
		done.append("Furfur confined in the lair")
	pages.append("MILESTONES\n\n" + ("No milestones recorded yet." if done.is_empty() else "\n\n".join(done)))
	return pages

static func open(game: Control, page := 0) -> VBoxContainer:
	var pages := entries(game.get_node("/root/Profile").data, GameData.load_json("furfur"))
	var sh := UI.sheet(game)
	sh.get_meta("sheet").name = "DebtLedger"
	var panel := sh.get_parent() as PanelContainer
	var parchment := StyleBoxFlat.new()
	parchment.bg_color = Color.BLACK if UI.contrast() else Color("282019")
	parchment.border_color = Color.WHITE if UI.contrast() else Color("a38a55")
	parchment.set_border_width_all(3)
	parchment.set_corner_radius_all(12)
	parchment.content_margin_left = 24
	parchment.content_margin_right = 24
	parchment.content_margin_top = 24
	parchment.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", parchment)
	sh.add_child(UI.label("DEBT LEDGER", 30, UI.ink()))
	sh.add_child(UI.label("PRICE & PARTNERS  •  %02d / %02d" % [page + 1, pages.size()], 16, UI.ink()))
	var body := UI.label(pages[page], 22)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	sh.add_child(scroll)
	var nav := HBoxContainer.new()
	sh.add_child(nav)
	var prev := UI.button("PREVIOUS", func(): UI.close_sheet(sh); open(game, page - 1))
	var nxt := UI.button("NEXT", func(): UI.close_sheet(sh); open(game, page + 1))
	for b in [prev, nxt]:
		b.add_theme_font_size_override("font_size", UI.font_size(18))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
	prev.disabled = page == 0
	nxt.disabled = page == pages.size() - 1
	sh.add_child(UI.button("CLOSE", func(): UI.close_sheet(sh)))
	return sh

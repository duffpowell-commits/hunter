extends Control
## Intro: the cold open. Tap to go to the next card, SKIP to jump to the title.
## Plays once; after that boot goes straight to the title, so a second play never forces it.
## Nov 26 (8.5 pass, item 4): the template's placeholder cards are gone. Four cards tell a
## first-timer who they are, who they owe, what they do and who to kill first (DESIGN.md story
## spine; writing is placeholder until Duff signs it off).

const UI = preload("res://scripts/ui.gd")
## [line, small line under it]
const CARDS := [
	["Cain Vantre.\nA life borrowed.", "Your mother made a deal to keep you breathing."],
	["Samael Price.\nPrice & Partners.", "The Firm spared your life. You are half demon."],
	["A debt without a balance.", "Price promises freedom for you and your mother when the account is settled."],
	["First name on the list:\nBROTHER VESPER.", "Your first obligation awaits in the Pews. Read the Debt Ledger from Pause."],
]

var i := 0
var text: Label
var sub: Label
var dots: Label


func _ready() -> void:
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			next())
	add_child(bg)
	text = UI.label("", 30)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.custom_minimum_size = Vector2(440, 0)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.grow_vertical = Control.GROW_DIRECTION_BOTH
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
	sub = UI.label("", 18, UI.DIM)
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.custom_minimum_size = Vector2(440, 0)
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub.offset_top = 140
	sub.offset_bottom = 240
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)
	dots = UI.label("", 18, UI.DIM)
	dots.anchor_top = 1.0
	dots.anchor_bottom = 1.0
	dots.anchor_right = 1.0
	dots.offset_top = -120
	dots.offset_bottom = -70
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)
	var skip := UI.button("SKIP", done)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -170
	skip.offset_right = -24
	skip.offset_top = 28
	skip.offset_bottom = 28 + UI.MIN_TOUCH
	add_child(skip)
	_show()


func _show() -> void:
	text.text = CARDS[i][0]
	sub.text = CARDS[i][1]
	dots.text = "%d / %d   TAP TO GO ON" % [i + 1, CARDS.size()]
	text.add_theme_color_override("font_color", UI.ACCENT if i == CARDS.size() - 1 else UI.ink())
	get_node("/root/Subs").clear()


func next() -> void:
	i += 1
	if i >= CARDS.size():
		done()
	else:
		_show()


func done() -> void:
	get_node("/root/Settings").set_value("intro_seen", true)
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		done()

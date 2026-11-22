extends "res://scripts/arena.gd"
## The Pews playable realm. Keeps the training arena available to the autoplay harness.

const PewsRules = preload("res://scripts/pews_rules.gd")
var rules: PewsRules

func _ready() -> void:
	super._ready()
	rules = PewsRules.new()

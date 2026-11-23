extends Control
## Boot: a short splash, then the intro (first launch only) or the title.

const UI = preload("res://scripts/ui.gd")
const Quality = preload("res://scripts/quality.gd")


func _ready() -> void:
	theme = UI.theme()
	$StudioSplash/Skip.add_theme_font_size_override("font_size", UI.font_size(24))
	if int(get_node("/root/Settings").get_value("tier")) < 0:
		await Quality.pick(self)               # first launch: time the GPU, pick LOW / MEDIUM / HIGH
	else:
		Quality.restore(get_tree())
	if not $StudioSplash.finished:
		await $StudioSplash.dismissed
	var seen: bool = get_node("/root/Settings").get_value("intro_seen")
	get_node("/root/Loader").go("res://scenes/title.tscn" if seen else "res://scenes/intro.tscn")

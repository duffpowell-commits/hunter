extends RefCounted
## Milestone 2 domain rules for The Pews. Pure logic, no scene dependencies.
## Values are tuned in data/pews.json.

func tick_stalking(studied: float, distance: float, angle_rad: float, sneaking: bool, seen: bool, dt: float) -> float:
	return 0.0

func hit_boss(damage: float) -> Dictionary:
	return {}

func finish(method: String) -> Dictionary:
	return {}

func eat() -> Dictionary:
	return {}

func collect_plate() -> Dictionary:
	return {}

extends CanvasLayer
## Autoload "Updater": in-app updates for the Android APK. Does nothing on web, desktop,
## headless tests and the editor (no build number there).
##
## CI stamps every APK with a counting build number (res://build_code.txt + Android
## version/code = the workflow run number) and on main uploads <repo>.apk plus version.json
## ({"code": N, "sha": "abc1234"}) to the repo's public "dev" release, version.json LAST.
## On launch, when the app comes back to the front, and every RECHECK_S while it stays open, this
## reads version.json; if its code is higher it offers UPDATE NOW, downloads the APK into user:// and hands it to Android's
## installer (OS.shell_open; Godot's FileProvider makes the content:// URI).
##
## Needs: REQUEST_INSTALL_PACKAGES + INTERNET in the Android preset, and every build signed
## with the SAME key (the keystone, signing/keystone.keystore.enc, unlocked by KEYSTONE_PASS).
## Off-phone check: UPDATER_TEST=1 UPDATER_CODE=1 UPDATER_URL=<json url> UPDATER_SHOT=<png>.

const UI = preload("res://scripts/ui.gd")
const Config = preload("res://scripts/config.gd")
const APK_PATH := "user://update.apk"
const RECHECK_S := 120.0
## Why POLL_S < RECHECK_S (Nov 23 review): a 120 s timer against a 120 s gate skipped every other
## tick, so checks really came every ~240 s. Tick often, let _check_if_due decide.
const POLL_S := 30.0
const PLAY_SCENE := "Game"

var my_code := 0
var new_code := 0
var busy := false
var last_check := -1e9
var http: HTTPRequest
var box: VBoxContainer
var line: Label
var go_btn: Button
var installing := false
## Build the player said LATER to. Why (Nov 23 review): LATER has to hold; without this the
## open-app poll re-offered the same build every few minutes. Holds until the app restarts.
var dismissed := 0
var _withdrawing := false          # closing the sheet ourselves, not the player's LATER


static func is_newer(remote: int, local: int) -> bool:
	return local > 0 and remote > local


## Offer only a newer build the player hasn't already put off.
static func should_offer(remote: int, local: int, put_off: int) -> bool:
	return is_newer(remote, local) and remote > put_off


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _enabled():
		return
	my_code = _local_code()
	if my_code <= 0:
		return
	if FileAccess.file_exists(APK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(APK_PATH))
	await get_tree().create_timer(1.5).timeout
	check()
	var poll := Timer.new()
	poll.wait_time = POLL_S
	poll.timeout.connect(_on_poll)
	add_child(poll)
	poll.start()
	get_tree().scene_changed.connect(_on_scene_changed)


func _enabled() -> bool:
	return OS.get_environment("UPDATER_TEST") == "1" or OS.get_name() == "Android"


func _local_code() -> int:
	if OS.get_environment("UPDATER_CODE") != "":
		return OS.get_environment("UPDATER_CODE").to_int()
	return Config.build_code()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_check_if_due()


## Why (Nov 23 reviews): the sheet is a full-screen input blocker that doesn't pause the game, and
## back on game.gd's pause sheet resumes play under it. So no offer ever opens in the Game scene,
## pause screen included; it waits for the title or another menu, whatever started the check.
func _on_poll() -> void:
	if not _in_play():
		_check_if_due()


## Why (Nov 24 review): NEW GAME loads Game in the background while the title is still current, so
## a reply landing mid-load counts as play too; and if a sheet is already up when Game enters, it goes.
func _in_play() -> bool:
	var loader := get_node_or_null("/root/Loader")
	if loader != null and loader.busy():
		return true
	var scene := get_tree().current_scene
	return scene != null and scene.name == PLAY_SCENE


func _on_scene_changed() -> void:
	if box != null and _in_play():
		_withdrawing = true
		UI.close_sheet(box)


func _check_if_due() -> void:
	if my_code > 0 and box == null and Time.get_ticks_msec() / 1000.0 - last_check >= RECHECK_S:
		check()


func check() -> void:
	if busy:
		return
	busy = true
	last_check = Time.get_ticks_msec() / 1000.0
	var url := OS.get_environment("UPDATER_URL")
	if url == "":
		url = Config.release_url() + "version.json"
	url += ("&" if "?" in url else "?") + "t=%d" % Time.get_unix_time_from_system()
	var req := _request()
	req.request_completed.connect(_on_version, CONNECT_ONE_SHOT)
	if req.request(url) != OK:
		busy = false


func _request() -> HTTPRequest:
	if http != null:
		http.queue_free()
	http = HTTPRequest.new()
	http.max_redirects = 8
	http.timeout = 20.0
	add_child(http)
	return http


func _on_version(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("code"):
		return
	new_code = int(data["code"])
	print("UPDATER mine %d, release %d" % [my_code, new_code])
	# Why (Nov 23 re-review): any reply (launch, resume, poll) can land after play has started.
	if _in_play():
		return
	if should_offer(new_code, my_code, dismissed):
		_offer()


func _offer() -> void:
	if box != null:
		return
	box = UI.sheet(self)
	# Why (Nov 23 re-review): Android back frees sheets directly (title.gd, game.gd), skipping
	# LATER; this runs the same bookkeeping however the sheet goes.
	box.tree_exiting.connect(_on_sheet_gone)
	box.add_child(UI.label("UPDATE AVAILABLE", 28, UI.ACCENT))
	line = UI.label("Build %d is out. You have build %d." % [new_code, my_code])
	box.add_child(line)
	go_btn = UI.button("UPDATE NOW", _go, 84)
	box.add_child(go_btn)
	box.add_child(UI.button("LATER", _close))
	if OS.get_environment("UPDATER_SHOT") != "":
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("UPDATER_SHOT"))
		print("UPDATER SHOT")


func _close() -> void:
	UI.close_sheet(box)


## LATER, back or any other close: hold this build off for the session and drop the download.
func _on_sheet_gone() -> void:
	if not _withdrawing:
		dismissed = new_code
	_withdrawing = false
	installing = false
	if http != null and busy:
		http.cancel_request()
		busy = false
	box = null


func _go() -> void:
	if installing:
		_install()
		return
	if busy:
		return
	busy = true
	go_btn.disabled = true
	line.text = "Downloading build %d..." % new_code
	var req := _request()
	req.timeout = 0.0
	req.download_file = APK_PATH
	req.request_completed.connect(_on_apk, CONNECT_ONE_SHOT)
	if req.request(Config.release_url() + Config.apk_name() + "?t=%d" % Time.get_unix_time_from_system()) != OK:
		_failed()


func _process(_dt: float) -> void:
	if busy and box != null and http != null and http.download_file != "":
		var total := http.get_body_size()
		if total > 0:
			line.text = "Downloading build %d... %d%%" % [new_code, int(100.0 * http.get_downloaded_bytes() / total)]


func _on_apk(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	busy = false
	if box == null:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_failed()
		return
	installing = true
	go_btn.disabled = false
	go_btn.text = "INSTALL"
	line.text = "Android will ask you to confirm. First time only: allow this app to install apps, then come back and tap INSTALL."
	_install()


func _install() -> void:
	if OS.shell_open(ProjectSettings.globalize_path(APK_PATH)) != OK:
		line.text = "Android wouldn't open the installer. Tap INSTALL to try again."


func _failed() -> void:
	busy = false
	go_btn.disabled = false
	line.text = "Download failed. Check your signal and tap UPDATE NOW again."

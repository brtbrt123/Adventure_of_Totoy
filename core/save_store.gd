extends RefCounted
## Reads and writes the save file. The profile is written to a temporary file first and the previous save is
## kept as `<path>.bak` until the new one is in place, so a crash mid-write never loses the last good save.
## No rendering or UI; usable headless.

const SaveProfile := preload("res://core/save_profile.gd")

const DEFAULT_PATH: String = "user://totoy_save.json"
## Set this environment variable to redirect saves (the test runner points it at a throwaway file).
const PATH_ENV: String = "TOTOY_SAVE_PATH"


static func default_path() -> String:
	var override: String = OS.get_environment(PATH_ENV)
	return override if override != "" else DEFAULT_PATH


## Returns OK or a Godot error code.
static func save(profile: SaveProfile, path: String = "") -> int:
	var target: String = path if path != "" else default_path()
	var temp: String = target + ".tmp"
	var backup: String = target + ".bak"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(profile.to_json())
	file.close()
	if FileAccess.get_open_error() != OK:
		return FileAccess.get_open_error()
	if FileAccess.file_exists(target):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		var moved: int = DirAccess.rename_absolute(target, backup)
		if moved != OK:
			return moved
	var renamed: int = DirAccess.rename_absolute(temp, target)
	if renamed != OK:
		return renamed
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return OK


## Always returns a profile: the saved one, the backup if the main file is unreadable, or a fresh one.
static func load_profile(path: String = "") -> SaveProfile:
	var target: String = path if path != "" else default_path()
	var main: SaveProfile = _read(target)
	if main != null:
		return main
	var backup: SaveProfile = _read(target + ".bak")
	if backup != null:
		backup.load_note = "restored from backup"
		return backup
	var fresh: SaveProfile = SaveProfile.new()
	if FileAccess.file_exists(target):
		fresh.load_note = "save file unreadable, starting fresh"
	return fresh


## The profile in `path`, or null when the file is missing or is not a readable save.
static func _read(path: String) -> SaveProfile:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var profile: SaveProfile = SaveProfile.from_json(text) as SaveProfile
	return profile if profile.load_note == "" else null


static func delete(path: String = "") -> void:
	var target: String = path if path != "" else default_path()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(target + suffix):
			DirAccess.remove_absolute(target + suffix)

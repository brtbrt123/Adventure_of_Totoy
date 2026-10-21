extends "res://tests/test_case.gd"
## The save profile and the save store: round trips, forgiving reads, safe writes.

const SaveProfile := preload("res://core/save_profile.gd")
const SaveStore := preload("res://core/save_store.gd")

const PATH: String = "user://test_save_profile.json"


func _clean() -> void:
	SaveStore.delete(PATH)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_new_profile_is_empty() -> void:
	var p: SaveProfile = SaveProfile.new()
	assert_eq(p.runs_started, 0)
	assert_eq(p.victories, 0)
	assert_eq(p.defeats, 0)
	assert_eq(p.best_victory_ticks, 0)
	assert_eq(p.last_result, &"")
	assert_eq(p.weapon_id, &"black_katana")
	assert_eq(p.load_note, "")


func test_results_are_counted_and_the_best_time_is_kept() -> void:
	var p: SaveProfile = SaveProfile.new()
	p.record_run_started()
	p.record_run_started()
	assert_eq(p.runs_started, 2)
	assert_true(p.record_result(&"victory", 3000), "the first victory is a best")
	assert_eq(p.best_victory_ticks, 3000)
	assert_false(p.record_result(&"victory", 3500), "a slower victory is not")
	assert_eq(p.best_victory_ticks, 3000)
	assert_true(p.record_result(&"victory", 2400), "a faster one is")
	assert_eq(p.best_victory_ticks, 2400)
	assert_false(p.record_result(&"defeat", 100), "a defeat is never a best time")
	assert_eq(p.victories, 3)
	assert_eq(p.defeats, 1)
	assert_eq(p.best_victory_ticks, 2400)
	assert_eq(p.last_result, &"defeat")


func test_a_zero_tick_victory_still_counts_as_a_time() -> void:
	var p: SaveProfile = SaveProfile.new()
	p.record_result(&"victory", 0)
	assert_eq(p.best_victory_ticks, 1, "0 means 'no victory yet', so a real time is at least 1")


func test_json_round_trip_keeps_everything() -> void:
	var p: SaveProfile = SaveProfile.new()
	p.record_run_started()
	p.record_result(&"victory", 1234)
	p.record_result(&"defeat", 99)
	var back: SaveProfile = SaveProfile.from_json(p.to_json()) as SaveProfile
	assert_eq(back.load_note, "")
	assert_eq(back.runs_started, 1)
	assert_eq(back.victories, 1)
	assert_eq(back.defeats, 1)
	assert_eq(back.best_victory_ticks, 1234)
	assert_eq(back.last_result, &"defeat")
	assert_eq(back.to_json(), p.to_json(), "stable output")
	assert_eq(int(JSON.parse_string(p.to_json())["version"]), SaveProfile.VERSION)


func test_garbage_and_wrong_shapes_give_a_fresh_profile_with_a_reason() -> void:
	for text: String in ["", "not json", "[1, 2]", "42", "null", "{\"victories\": 5}"]:
		var p: SaveProfile = SaveProfile.from_json(text) as SaveProfile
		assert_true(p.load_note != "", "'%s' is reported" % text)
		assert_eq(p.victories, 0, "'%s' does not keep stray numbers" % text)


func test_a_newer_version_is_not_trusted() -> void:
	var p: SaveProfile = SaveProfile.from_json("{\"version\": 99, \"victories\": 7}") as SaveProfile
	assert_true(p.load_note.contains("newer"))
	assert_eq(p.victories, 0)


func test_bad_field_values_are_cleaned() -> void:
	var text: String = "{\"version\": 1, \"runs_started\": -4, \"victories\": \"many\", \"defeats\": 3.9, \"best_victory_ticks\": null, \"last_result\": \"flawless\", \"weapon_id\": \"axe\"}"
	var p: SaveProfile = SaveProfile.from_json(text) as SaveProfile
	assert_eq(p.load_note, "", "still a readable save")
	assert_eq(p.runs_started, 0, "negative becomes 0")
	assert_eq(p.victories, 0, "a string becomes 0")
	assert_eq(p.defeats, 3, "a fraction is cut")
	assert_eq(p.best_victory_ticks, 0)
	assert_eq(p.last_result, &"", "an unknown result is dropped")
	assert_eq(p.weapon_id, &"black_katana", "an unknown weapon falls back")


func test_integer_fields_are_clamped_too() -> void:
	var p: SaveProfile = SaveProfile.from_dict({"version": 1, "runs_started": -4, "victories": -1, "best_victory_ticks": -9}) as SaveProfile
	assert_eq(p.runs_started, 0)
	assert_eq(p.victories, 0)
	assert_eq(p.best_victory_ticks, 0)


func test_the_store_round_trips_through_a_file_and_leaves_no_temp_files() -> void:
	_clean()
	var p: SaveProfile = SaveProfile.new()
	p.record_run_started()
	p.record_result(&"victory", 777)
	assert_eq(SaveStore.save(p, PATH), OK)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "no temp file left")
	assert_false(FileAccess.file_exists(PATH + ".bak"), "no backup left after a clean write")
	var back: SaveProfile = SaveStore.load_profile(PATH)
	assert_eq(back.load_note, "")
	assert_eq(back.best_victory_ticks, 777)
	p.record_result(&"victory", 700)
	assert_eq(SaveStore.save(p, PATH), OK, "saving again over an existing file works")
	assert_eq(SaveStore.load_profile(PATH).best_victory_ticks, 700)
	assert_false(FileAccess.file_exists(PATH + ".bak"))
	_clean()


func test_a_missing_save_is_a_quiet_fresh_profile() -> void:
	_clean()
	var p: SaveProfile = SaveStore.load_profile(PATH)
	assert_eq(p.load_note, "", "a first run is not an error")
	assert_eq(p.runs_started, 0)


func test_a_corrupt_save_falls_back_to_the_backup() -> void:
	_clean()
	var good: SaveProfile = SaveProfile.new()
	good.record_result(&"victory", 555)
	_write_raw(PATH + ".bak", good.to_json())
	_write_raw(PATH, "{ half a file")  # a crash in the middle of a write
	var p: SaveProfile = SaveStore.load_profile(PATH)
	assert_eq(p.best_victory_ticks, 555, "the previous good save is restored")
	assert_eq(p.load_note, "restored from backup")
	_clean()


func test_a_corrupt_save_without_a_backup_starts_fresh_and_says_so() -> void:
	_clean()
	_write_raw(PATH, "garbage")
	var p: SaveProfile = SaveStore.load_profile(PATH)
	assert_eq(p.victories, 0)
	assert_true(p.load_note.contains("unreadable"))
	_clean()


func test_saving_to_an_impossible_path_reports_an_error() -> void:
	var result: int = SaveStore.save(SaveProfile.new(), "user://no_such_folder_for_tests/save.json")
	assert_true(result != OK, "an error code, not a silent success")


func test_the_environment_variable_redirects_the_default_path() -> void:
	OS.set_environment(SaveStore.PATH_ENV, "user://redirected_test_save.json")
	assert_eq(SaveStore.default_path(), "user://redirected_test_save.json")
	OS.set_environment(SaveStore.PATH_ENV, "")
	assert_eq(SaveStore.default_path(), SaveStore.DEFAULT_PATH)

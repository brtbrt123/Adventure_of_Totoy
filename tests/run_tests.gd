extends SceneTree
## Headless test runner (no addon). Runs every test_* method in tests/core/test_*.gd.
## Run: godot_console --headless --path . --script res://tests/run_tests.gd
## Exits 0 when all pass, 1 when any fail.

const TEST_DIR: String = "res://tests/core"
const TestCase := preload("res://tests/test_case.gd")


func _init() -> void:
	var total: int = 0
	var failed: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(TEST_DIR)
	files.sort()
	# optional: TOTOY_TEST_FILTER=glade runs only the files whose name contains "glade" (quick local runs)
	var only: String = OS.get_environment("TOTOY_TEST_FILTER")
	for file_name: String in files:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		if only != "" and not file_name.contains(only):
			continue
		var script: GDScript = load(TEST_DIR + "/" + file_name) as GDScript
		if script == null or not script.can_instantiate():  # a parse error still returns a script object
			printerr("FAIL %s: script did not load" % file_name)
			failed += 1
			total += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var test: TestCase = script.new() as TestCase
			test.call(method_name)
			if test.failures.is_empty():
				print("ok    %s :: %s" % [file_name, method_name])
			else:
				failed += 1
				for message: String in test.failures:
					printerr("FAIL  %s :: %s -> %s" % [file_name, method_name, message])
	print("%d test(s), %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)

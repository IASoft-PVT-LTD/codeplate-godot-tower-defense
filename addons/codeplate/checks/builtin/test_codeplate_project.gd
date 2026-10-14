extends CheckCase
## Project-wide checks every CodePlate Godot project gets:
## - every file listed in assets.json exists, is imported and has the listed size
## - every file under assets/ is listed in assets.json
## - every res:// path written in code, scenes and resources exists
## Part of the CodePlate add-on.

const SCAN_EXTENSIONS := ["gd", "tscn", "tres", "godot"]


func test_assets_json_matches_files() -> void:
	if not FileAccess.file_exists("res://assets.json"):
		return # projects without assets.json have nothing to check
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets.json"))
	if not expect(data is Dictionary and data.has("assets"), "assets.json parses and has an \"assets\" list"):
		return
	var listed: Dictionary[String, bool] = {}
	for a: Dictionary in data["assets"]:
		var path := "res://" + str(a["path"])
		listed[path] = true
		if not expect(FileAccess.file_exists(path), "%s exists" % path):
			continue
		if str(a.get("kind", "")) == "image" and path.ends_with(".png"):
			var size := png_size(path)
			if expect(size != Vector2i.ZERO, "%s is a PNG" % path) and a.has("width") and a.has("height"):
				var want := Vector2i(int(a["width"]) * int(a.get("frames", 1)), int(a["height"]))
				expect_eq(size, want, "%s size in assets.json (width x frames, height)" % path)
		expect(ResourceLoader.exists(path), "%s is imported (run godot --headless --import)" % path)
	for path: String in files_under("res://assets"):
		if not (path.ends_with(".import") or path.ends_with(".uid")):
			expect(listed.has(path), "%s is listed in assets.json" % path)


func test_every_res_path_exists() -> void:
	# Catches references broken by renaming or moving files.
	var re := RegEx.create_from_string("res://[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+")
	for f: String in files_under("res://", SCAN_EXTENSIONS):
		if f.begins_with("res://checks/") or f.begins_with("res://addons/codeplate/"):
			continue
		var text := FileAccess.get_file_as_string(f)
		for m: RegExMatch in re.search_all(text):
			var path := m.get_string()
			if "%" in path:
				continue
			expect(FileAccess.file_exists(path) or ResourceLoader.exists(path), "%s refers to missing %s" % [f, path])


## Width and height from a PNG header, or ZERO if the file is not a PNG.
static func png_size(path: String) -> Vector2i:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 24:
		return Vector2i.ZERO
	f.big_endian = true
	if f.get_buffer(8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return Vector2i.ZERO
	f.get_32() # chunk length
	if f.get_buffer(4).get_string_from_ascii() != "IHDR":
		return Vector2i.ZERO
	return Vector2i(f.get_32(), f.get_32())


## Every file under `dir` (recursively, skipping hidden folders), optionally
## only those with one of `exts`.
static func files_under(dir: String, exts: Array = []) -> PackedStringArray:
	var out: PackedStringArray = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for sub: String in da.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(files_under(dir.path_join(sub), exts))
	for f: String in da.get_files():
		if exts.is_empty() or f.get_extension() in exts:
			out.append(dir.path_join(f))
	return out

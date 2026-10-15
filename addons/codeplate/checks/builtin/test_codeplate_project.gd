extends CheckCase
## Project-wide checks every CodePlate Godot project gets:
## - every file listed in assets.json exists, is imported and has the listed size
## - its licence is one a game may ship; CodePlate's files credit CodePlate, the
##   user's own files are "user-owned" and credit their owner; a file whose `use`
##   calls it a placeholder or stand-in says "placeholder": true
## - every file under assets/ is listed in assets.json
## - every res:// path written in code, scenes and resources exists
## - every export preset in export_presets.cfg ships the data files the game reads
##   at runtime (JSON, text, CSV, Markdown: none of them is a Godot resource, so an
##   export drops them unless the preset's include_filter names them)
## - export/ and shots/ (local output) are hidden from Godot's import and from
##   every preset; a Web preset is single-threaded (no special server headers)
## - the save folder (user://) has a fixed name, so renaming the game keeps saves
## - an Android preset's app name matches the game's name
## Part of the CodePlate add-on.

const SCAN_EXTENSIONS := ["gd", "tscn", "tres", "godot"]
## Files with these extensions are data, not Godot resources: exports leave them out unless included.
const DATA_EXTENSIONS := ["json", "txt", "csv", "md", "xml", "yaml", "yml"]
## Folders whose data files never ship in a game (docs, the checks, tools, local output).
const NON_RUNTIME_DIRS := ["docs/", "checks/", "tools/", "shots/", "export/", "build/", "node_modules/",
	"addons/codeplate/checks/", "addons/codeplate/tools/", "addons/codeplate/README.md"]
## Licences a file in a game's assets.json may have.
const ASSET_LICENSES := ["CodePlate-original", "CC0-1.0", "OFL-1.1", "user-owned"]
## Local output folders: never imported (a .gdignore inside) and never exported.
const OUTPUT_DIRS := ["export", "shots"]
## Data files at the project root the game reads (the credits page, the license check, the sprite sizes).
const ROOT_RUNTIME_FILES := ["CREDITS.md", "LICENSE.md", "assets.json"]


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
		for problem: String in asset_licence_problems(a):
			expect(false, "assets.json %s: %s" % [a["path"], problem])
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


func test_export_presets_ship_runtime_data() -> void:
	# A preset that leaves out levels or content exports a game that starts empty
	# ("0 LEVELS"). This runs for every preset in export_presets.cfg, so it also
	# catches a new data folder or file type added later.
	if not FileAccess.file_exists("res://export_presets.cfg"):
		return
	var cfg := ConfigFile.new()
	if not expect(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg parses"):
		return
	var needed := runtime_data_files()
	for section: String in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var preset := str(cfg.get_value(section, "name", section))
		if str(cfg.get_value(section, "export_filter", "all_resources")) != "all_resources":
			continue # a hand-picked list of resources: the user chose what ships
		var include := str(cfg.get_value(section, "include_filter", ""))
		var exclude := str(cfg.get_value(section, "exclude_filter", ""))
		for rel: String in needed:
			expect(filter_matches(rel, include) and not filter_matches(rel, exclude),
				"export preset \"%s\" ships %s (add its type to include_filter, or take it off exclude_filter)" % [preset, rel])
		var options := section + ".options"
		if cfg.has_section(options):
			for key: String in cfg.get_section_keys(options):
				var v: Variant = cfg.get_value(options, key)
				if v is String and (v as String).begins_with("res://"):
					expect(FileAccess.file_exists(v), "export preset \"%s\": %s = %s exists" % [preset, key, v])


func test_local_output_stays_out_of_the_game() -> void:
	# Without .gdignore, Godot imports the exported web icons and every screenshot,
	# and the next export packs them into the game.
	for d: String in OUTPUT_DIRS:
		expect(FileAccess.file_exists("res://%s/.gdignore" % d),
			"res://%s/.gdignore exists (an empty file: Godot then never imports %s/)" % [d, d])
	var cfg := _export_presets()
	if cfg == null:
		return
	for section: String in _presets(cfg):
		var preset := str(cfg.get_value(section, "name", section))
		var exclude := str(cfg.get_value(section, "exclude_filter", "")).replace(" ", "").split(",")
		for d: String in OUTPUT_DIRS:
			expect(("%s/*" % d) in exclude, "export preset \"%s\": exclude_filter has %s/*" % [preset, d])
		if str(cfg.get_value(section, "platform", "")) == "Web":
			expect(cfg.get_value(section + ".options", "variant/thread_support", true) == false,
				"export preset \"%s\": variant/thread_support=false (threads need special server headers)" % preset)


func test_save_folder_has_a_fixed_name() -> void:
	# Without a custom user dir, user:// is named after config/name, so renaming
	# the game would start every player on an empty save.
	expect(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)),
		"project.godot: application/config/use_custom_user_dir=true")
	expect(not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).strip_edges().is_empty(),
		"project.godot: application/config/custom_user_dir_name is set (a fixed folder name; never change it once people play)")


func test_android_app_name_matches_the_game() -> void:
	var cfg := _export_presets()
	if cfg == null:
		return
	var game_name := str(ProjectSettings.get_setting("application/config/name", ""))
	for section: String in _presets(cfg):
		var app_name := str(cfg.get_value(section + ".options", "package/name", ""))
		if str(cfg.get_value(section, "platform", "")) == "Android" and app_name != "":
			expect_eq(app_name, game_name, "export preset \"%s\": package/name matches config/name (the rebrand recipe)"
				% cfg.get_value(section, "name", section))


## export_presets.cfg, or null when the project has none.
static func _export_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists("res://export_presets.cfg") or cfg.load("res://export_presets.cfg") != OK:
		return null
	return cfg


## The preset sections ("preset.0", ...) of an export_presets.cfg.
static func _presets(cfg: ConfigFile) -> PackedStringArray:
	var out: PackedStringArray = []
	for section: String in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			out.append(section)
	return out


## What's wrong with one assets.json entry's licence, credit and placeholder flag.
static func asset_licence_problems(a: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var licence := str(a.get("license", ""))
	var credit := str(a.get("credit", "")).strip_edges()
	var by_codeplate := credit.to_lower().begins_with("codeplate")
	if licence not in ASSET_LICENSES:
		out.append("license \"%s\" is not one of %s" % [licence, ", ".join(ASSET_LICENSES)])
	if licence == "CodePlate-original" and not by_codeplate:
		out.append("\"CodePlate-original\" files are credited to CodePlate, not \"%s\": a file the user gave you or made for them is \"license\": \"user-owned\" with the owner's name as \"credit\"" % credit)
	if licence == "user-owned" and (credit.is_empty() or by_codeplate):
		out.append("\"user-owned\" files credit their owner (the person or company), not CodePlate")
	if licence == "OFL-1.1" and str(a.get("kind", "")) != "font":
		out.append("only fonts may be OFL-1.1")
	var use := str(a.get("use", "")).to_lower()
	if ("placeholder" in use or "stand-in" in use) and a.get("placeholder", false) != true:
		out.append("its use calls it a placeholder: add \"placeholder\": true (and remove both when the real file arrives)")
	return out


## Data files (relative to res://) a game ships: every JSON, text, CSV or Markdown
## file outside the docs, checks and tools folders, and at the project root only
## CREDITS.md, LICENSE.md and assets.json.
static func runtime_data_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for path: String in files_under("res://", DATA_EXTENSIONS):
		var rel := path.trim_prefix("res://")
		var skip := false
		for d: String in NON_RUNTIME_DIRS:
			if rel.begins_with(d):
				skip = true
		if "/" not in rel and rel not in ROOT_RUNTIME_FILES:
			skip = true
		if not skip:
			out.append(rel)
	return out


## Whether `rel` (a path relative to res://) matches one of the comma-separated
## export filters: a glob over the whole path or over the file name, as in Godot's
## export dialog ("*.json", "levels/*.txt", "CREDITS.md"). `*` also matches "/".
static func filter_matches(rel: String, filters: String) -> bool:
	for raw: String in filters.split(","):
		var f := raw.strip_edges().trim_prefix("res://")
		if not f.is_empty() and (rel.matchn(f) or rel.get_file().matchn(f)):
			return true
	return false


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


func test_asset_licence_rules() -> void:
	var ok := func(a: Dictionary) -> bool: return asset_licence_problems(a).is_empty()
	expect(ok.call({"kind": "image", "use": "Hero", "license": "CodePlate-original", "credit": "CodePlate"}), "CodePlate's own file passes")
	expect(ok.call({"kind": "image", "use": "Logo", "license": "user-owned", "credit": "Rock Pool Studio"}), "a user-owned file credited to its owner passes")
	expect(not ok.call({"kind": "image", "use": "Logo", "license": "CodePlate-original", "credit": "Rock Pool Studio"}), "CodePlate-original credited to someone else fails")
	expect(not ok.call({"kind": "image", "use": "Logo", "license": "user-owned", "credit": "CodePlate"}), "user-owned credited to CodePlate fails")
	expect(not ok.call({"kind": "image", "use": "Rain cloud (placeholder)", "license": "CodePlate-original", "credit": "CodePlate"}), "a placeholder without the flag fails")
	expect(ok.call({"kind": "image", "use": "Rain cloud (stand-in)", "license": "CodePlate-original", "credit": "CodePlate", "placeholder": true}), "a flagged placeholder passes")
	expect(not ok.call({"kind": "image", "use": "Hero", "license": "MIT", "credit": "Someone"}), "a licence games don't ship fails")

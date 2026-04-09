extends Node;

signal locale_changed(locale: String);


const DEFAULT_LOCALE: String = "en";
const SUPPORTED_LOCALES: PackedStringArray = ["en", "ru"];
const TRANSLATIONS_CSV_PATH: String = "res://translations/UI.csv";
const UI_KEY_REGEX_PATTERN: String = "\"(UI_[A-Z0-9_]+)\"";
const LOCALIZATION_SCAN_ROOTS: PackedStringArray = [
	"res://core",
	"res://features",
	"res://shared",
];
const LOCALE_DISPLAY_NAMES: Dictionary = {
	"en": "English",
	"ru": "Русский",
};


func _ready() -> void:
	apply_current_locale();


func get_supported_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate();


func get_current_locale() -> String:
	return TranslationServer.get_locale();


func get_display_name(locale: String) -> String:
	var normalized_locale: String = normalize_locale(locale);
	return String(LOCALE_DISPLAY_NAMES.get(normalized_locale, normalized_locale));


func normalize_locale(locale: String) -> String:
	var normalized_locale: String = locale.strip_edges().to_lower();
	if normalized_locale.is_empty():
		return DEFAULT_LOCALE;
	if SUPPORTED_LOCALES.has(normalized_locale):
		return normalized_locale;

	for separator: String in ["_", "-"]:
		if not normalized_locale.contains(separator):
			continue;
		var base_locale: String = normalized_locale.get_slice(separator, 0);
		if SUPPORTED_LOCALES.has(base_locale):
			return base_locale;

	return DEFAULT_LOCALE;


func set_locale(locale: String, persist_to_settings: bool = true) -> void:
	AppContext.ensure_defaults();
	var normalized_locale: String = normalize_locale(locale);
	TranslationServer.set_locale(normalized_locale);
	_notify_runtime_ui_locale_changed();
	if persist_to_settings:
		AppContext.settings.language = normalized_locale;
	locale_changed.emit(normalized_locale);


func apply_current_locale() -> void:
	AppContext.ensure_defaults();
	var normalized_locale: String = normalize_locale(AppContext.settings.language);
	AppContext.settings.language = normalized_locale;
	set_locale(normalized_locale, false);


func get_static_key_coverage_report() -> Dictionary:
	var used_keys: Array[String] = _collect_static_ui_keys();
	var translations: Dictionary = _read_translation_table();
	var missing_by_locale: Dictionary = {};
	for locale: String in SUPPORTED_LOCALES:
		missing_by_locale[locale] = [];

	for ui_key: String in used_keys:
		var locale_values: Variant = translations.get(ui_key, {});
		if not (locale_values is Dictionary):
			for locale: String in SUPPORTED_LOCALES:
				_append_missing_key(missing_by_locale, locale, ui_key);
			continue;

		var typed_values: Dictionary = locale_values as Dictionary;
		for locale: String in SUPPORTED_LOCALES:
			var localized_text: String = String(typed_values.get(locale, "")).strip_edges();
			if localized_text.is_empty():
				_append_missing_key(missing_by_locale, locale, ui_key);

	for locale: String in SUPPORTED_LOCALES:
		var missing_keys: Variant = missing_by_locale.get(locale, []);
		if missing_keys is Array:
			(missing_keys as Array).sort();

	return {
		"complete": _is_coverage_complete(missing_by_locale),
		"used_keys": used_keys,
		"missing_by_locale": missing_by_locale,
	};


func _notify_runtime_ui_locale_changed() -> void:
	var tree: SceneTree = get_tree();
	if tree == null:
		return;
	var root: Window = tree.root;
	if root == null:
		return;
	root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED);


func _collect_static_ui_keys() -> Array[String]:
	var regex: RegEx = RegEx.new();
	if regex.compile(UI_KEY_REGEX_PATTERN) != OK:
		return [];

	var key_set: Dictionary = {};
	for root_path: String in LOCALIZATION_SCAN_ROOTS:
		_collect_static_ui_keys_from_directory(root_path, regex, key_set);

	var keys: Array[String] = [];
	for key_variant: Variant in key_set.keys():
		keys.append(String(key_variant));
	keys.sort();
	return keys;


func _collect_static_ui_keys_from_directory(path: String, regex: RegEx, key_set: Dictionary) -> void:
	var directory: DirAccess = DirAccess.open(path);
	if directory == null:
		return;

	directory.list_dir_begin();
	while true:
		var entry_name: String = directory.get_next();
		if entry_name.is_empty():
			break;
		if entry_name.begins_with("."):
			continue;
		var entry_path: String = "%s/%s" % [path, entry_name];
		if directory.current_is_dir():
			_collect_static_ui_keys_from_directory(entry_path, regex, key_set);
			continue;
		if not entry_name.ends_with(".tscn"):
			continue;
		_collect_static_ui_keys_from_file(entry_path, regex, key_set);
	directory.list_dir_end();


func _collect_static_ui_keys_from_file(path: String, regex: RegEx, key_set: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ);
	if file == null:
		return;
	var content: String = file.get_as_text();
	file.close();
	for match: RegExMatch in regex.search_all(content):
		if match == null:
			continue;
		var ui_key: String = match.get_string(1);
		if ui_key.is_empty():
			ui_key = match.get_string().trim_prefix("\"").trim_suffix("\"");
		if ui_key.is_empty():
			continue;
		key_set[ui_key] = true;


func _read_translation_table() -> Dictionary:
	var table: Dictionary = {};
	var file: FileAccess = FileAccess.open(TRANSLATIONS_CSV_PATH, FileAccess.READ);
	if file == null:
		return table;
	var lines: PackedStringArray = file.get_as_text().split("\n", false);
	file.close();
	if lines.is_empty():
		return table;

	var locale_column_indices: Dictionary = _resolve_locale_column_indices(lines[0]);
	for line_index: int in range(1, lines.size()):
		var raw_line: String = lines[line_index].strip_edges();
		if raw_line.is_empty():
			continue;
		var cells: PackedStringArray = raw_line.split(",", false);
		if cells.is_empty():
			continue;
		var ui_key: String = cells[0].strip_edges();
		if not ui_key.begins_with("UI_"):
			continue;

		var locale_values: Dictionary = {};
		for locale: String in SUPPORTED_LOCALES:
			var column_index: int = int(locale_column_indices.get(locale, -1));
			var localized_text: String = "";
			if column_index >= 0 and column_index < cells.size():
				localized_text = cells[column_index].strip_edges();
			locale_values[locale] = localized_text;
		table[ui_key] = locale_values;

	return table;


func _resolve_locale_column_indices(header_line: String) -> Dictionary:
	var locale_column_indices: Dictionary = {};
	var header_cells: PackedStringArray = header_line.strip_edges().split(",", false);
	for locale: String in SUPPORTED_LOCALES:
		locale_column_indices[locale] = -1;
	for column_index: int in range(header_cells.size()):
		var column_name: String = header_cells[column_index].strip_edges().to_lower();
		for locale: String in SUPPORTED_LOCALES:
			if column_name == locale.to_lower():
				locale_column_indices[locale] = column_index;
	return locale_column_indices;


func _append_missing_key(missing_by_locale: Dictionary, locale: String, ui_key: String) -> void:
	var missing_keys: Variant = missing_by_locale.get(locale, []);
	if not (missing_keys is Array):
		missing_by_locale[locale] = [ui_key];
		return;
	if (missing_keys as Array).has(ui_key):
		return;
	(missing_keys as Array).append(ui_key);
	missing_by_locale[locale] = missing_keys;


func _is_coverage_complete(missing_by_locale: Dictionary) -> bool:
	for locale: String in SUPPORTED_LOCALES:
		var missing_keys: Variant = missing_by_locale.get(locale, []);
		if missing_keys is Array and not (missing_keys as Array).is_empty():
			return false;
	return true;

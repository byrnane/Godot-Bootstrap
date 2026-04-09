extends Node;

const SLOT_DIRECTORY: String = "user://saves";
const SLOT_FILE_TEMPLATE: String = "slot_%02d.save";
const LEGACY_SAVE_PATH: String = "user://savegame.save";
const DEFAULT_SLOT_ID: int = 0;
const MIN_SLOT_ID: int = 0;
const MAX_SLOT_ID: int = 99;


var _reported_slot_issues: Dictionary = {};


func has_save(slot_id: int = DEFAULT_SLOT_ID) -> bool:
	var normalized_slot_id: int = _normalize_slot_id(slot_id);
	if FileAccess.file_exists(_get_slot_path(normalized_slot_id)):
		return true;
	return normalized_slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH);


func load_game(slot_id: int = DEFAULT_SLOT_ID) -> SaveData:
	var normalized_slot_id: int = _normalize_slot_id(slot_id);
	var load_path: String = _resolve_load_path(normalized_slot_id);
	if load_path.is_empty():
		return null;

	var file: FileAccess = FileAccess.open(load_path, FileAccess.READ);
	if file == null:
		return null;

	var data: Variant = file.get_var(true);
	file.close();

	var save_data: SaveData = _normalize_save_data(data);
	if save_data == null:
		return null;

	# Old snapshots are normalized on load and immediately rewritten so the next
	# boot no longer needs to pass through migration paths.
	if _should_resave_data(data) or load_path != _get_slot_path(normalized_slot_id):
		save_game(save_data, normalized_slot_id);
	return save_data;


func save_game(data: SaveData, slot_id: int = DEFAULT_SLOT_ID) -> bool:
	if data == null:
		return false;
	var normalized_slot_id: int = _normalize_slot_id(slot_id);
	if not _ensure_slot_directory():
		return false;

	var normalized_data: SaveData = _normalize_save_data(data.to_dictionary());
	if normalized_data == null:
		return false;

	var save_path: String = _get_slot_path(normalized_slot_id);
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE);
	if file == null:
		return false;

	file.store_var(normalized_data.to_dictionary(), true);
	file.close();
	_cleanup_legacy_save_if_needed(normalized_slot_id);
	return true;


func save_current_session(slot_id: int = DEFAULT_SLOT_ID) -> bool:
	return save_game(SessionContext.to_save_data(), slot_id);


func delete_save(slot_id: int = DEFAULT_SLOT_ID) -> void:
	var normalized_slot_id: int = _normalize_slot_id(slot_id);
	var slot_path: String = _get_slot_path(normalized_slot_id);
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path);
	if normalized_slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(LEGACY_SAVE_PATH);


func list_slots() -> Array[int]:
	var slot_ids: Array[int] = [];
	var directory: DirAccess = DirAccess.open(SLOT_DIRECTORY);
	if directory != null:
		directory.list_dir_begin();
		while true:
			var entry_name: String = directory.get_next();
			if entry_name.is_empty():
				break;
			if directory.current_is_dir():
				continue;
			var parsed_slot_id: int = _parse_slot_id(entry_name);
			if parsed_slot_id >= 0 and not slot_ids.has(parsed_slot_id):
				slot_ids.append(parsed_slot_id);
		directory.list_dir_end();

	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not slot_ids.has(DEFAULT_SLOT_ID):
		slot_ids.append(DEFAULT_SLOT_ID);

	slot_ids.sort();
	return slot_ids;


func _normalize_save_data(data: Variant) -> SaveData:
	return SaveData.from_variant(data);


func _should_resave_data(data: Variant) -> bool:
	if data is SaveData:
		return true;
	if data is Dictionary:
		return int((data as Dictionary).get("version", 0)) != SaveData.CURRENT_VERSION;
	return false;


func _resolve_load_path(slot_id: int) -> String:
	var slot_path: String = _get_slot_path(slot_id);
	if FileAccess.file_exists(slot_path):
		return slot_path;
	if slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH):
		return LEGACY_SAVE_PATH;
	return "";


func _get_slot_path(slot_id: int) -> String:
	return "%s/%s" % [SLOT_DIRECTORY, SLOT_FILE_TEMPLATE % [slot_id]];


func _parse_slot_id(file_name: String) -> int:
	if not file_name.begins_with("slot_"):
		return -1;
	if not file_name.ends_with(".save"):
		return -1;
	var slot_number_text: String = file_name.substr(5, file_name.length() - 10);
	if not slot_number_text.is_valid_int():
		return -1;
	var slot_id: int = int(slot_number_text);
	return slot_id if _is_valid_slot_id(slot_id) else -1;


func _normalize_slot_id(slot_id: int) -> int:
	if _is_valid_slot_id(slot_id):
		return slot_id;
	_warn_slot_issue(
		"slot_id/%s" % [slot_id],
		"slot id '%d' is out of range [%d..%d], fallback to default slot %d." % [
			slot_id,
			MIN_SLOT_ID,
			MAX_SLOT_ID,
			DEFAULT_SLOT_ID,
		]
	);
	return DEFAULT_SLOT_ID;


func _is_valid_slot_id(slot_id: int) -> bool:
	return slot_id >= MIN_SLOT_ID and slot_id <= MAX_SLOT_ID;


func _ensure_slot_directory() -> bool:
	if DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		return true;
	var result: Error = DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY);
	if result == OK:
		return true;
	_warn_slot_issue("slot_dir", "failed to create slot directory at '%s'." % [SLOT_DIRECTORY]);
	return false;


func _cleanup_legacy_save_if_needed(slot_id: int) -> void:
	if slot_id != DEFAULT_SLOT_ID:
		return;
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(LEGACY_SAVE_PATH);


func _warn_slot_issue(issue_key: String, message: String) -> void:
	if _reported_slot_issues.has(issue_key):
		return;
	_reported_slot_issues[issue_key] = true;
	push_warning("SaveManager: %s" % [message]);

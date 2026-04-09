extends Node;

const SLOT_DIRECTORY: String = "user://saves";
const SLOT_FILE_TEMPLATE: String = "slot_%02d.save";
const LEGACY_SAVE_PATH: String = "user://savegame.save";
const BACKUP_SUFFIX: String = ".bak";
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

	var loaded_data: Dictionary = _load_and_recover_data(load_path, normalized_slot_id);
	if loaded_data.is_empty():
		return null;
	var save_data: SaveData = loaded_data.get("save_data", null) as SaveData;
	var source_data: Variant = loaded_data.get("source_data", null);
	var source_path: String = String(loaded_data.get("source_path", load_path));
	if save_data == null:
		return null;

	# Old snapshots are normalized on load and immediately rewritten so the next
	# boot no longer needs to pass through migration paths.
	if _should_resave_data(source_data) or source_path != _get_slot_path(normalized_slot_id):
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
	_create_backup(save_path);
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE);
	if file == null:
		_warn_slot_issue("write/%s" % [save_path], "failed to open save path '%s' for writing." % [save_path]);
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
	var slot_backup_path: String = _get_backup_path(slot_path);
	if FileAccess.file_exists(slot_backup_path):
		DirAccess.remove_absolute(slot_backup_path);
	if normalized_slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(LEGACY_SAVE_PATH);
	var legacy_backup_path: String = _get_backup_path(LEGACY_SAVE_PATH);
	if normalized_slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(legacy_backup_path):
		DirAccess.remove_absolute(legacy_backup_path);

func clear_all_saves() -> int:
	var cleared_slot_ids: Dictionary = {};
	for slot_id: int in list_slots():
		delete_save(slot_id);
		cleared_slot_ids[slot_id] = true;
	if not cleared_slot_ids.has(DEFAULT_SLOT_ID):
		var had_default_save: bool = has_save(DEFAULT_SLOT_ID);
		delete_save(DEFAULT_SLOT_ID);
		if had_default_save:
			cleared_slot_ids[DEFAULT_SLOT_ID] = true;
	return cleared_slot_ids.size();


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


func _load_and_recover_data(load_path: String, slot_id: int) -> Dictionary:
	var loaded_data: Dictionary = _read_save_data(load_path);
	var save_data: SaveData = loaded_data.get("save_data", null) as SaveData;
	if save_data != null:
		return loaded_data;

	var backup_path: String = _resolve_backup_path(load_path, slot_id);
	if backup_path.is_empty():
		return {};
	var backup_data: Dictionary = _read_save_data(backup_path);
	var backup_save_data: SaveData = backup_data.get("save_data", null) as SaveData;
	if backup_save_data == null:
		return {};
	_warn_slot_issue(
		"recover/%s" % [load_path],
		"failed to read save '%s', recovered data from backup '%s'." % [load_path, backup_path]
	);
	return backup_data;


func _resolve_backup_path(load_path: String, slot_id: int) -> String:
	var primary_backup_path: String = _get_backup_path(load_path);
	if FileAccess.file_exists(primary_backup_path):
		return primary_backup_path;
	if slot_id != DEFAULT_SLOT_ID:
		return "";
	var legacy_backup_path: String = _get_backup_path(LEGACY_SAVE_PATH);
	if FileAccess.file_exists(legacy_backup_path):
		return legacy_backup_path;
	return "";


func _read_save_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {};
	var file: FileAccess = FileAccess.open(path, FileAccess.READ);
	if file == null:
		return {};
	var source_data: Variant = file.get_var(true);
	file.close();
	var save_data: SaveData = _normalize_save_data(source_data);
	if save_data == null:
		var incompatibility_reason: String = SaveData.get_incompatibility_reason(source_data);
		if incompatibility_reason.is_empty():
			incompatibility_reason = "save payload failed validation.";
		_warn_slot_issue("read/%s" % [path], "failed to read save '%s': %s" % [path, incompatibility_reason]);
		return {};
	return {
		"save_data": save_data,
		"source_data": source_data,
		"source_path": path,
	};


func _get_slot_path(slot_id: int) -> String:
	return "%s/%s" % [SLOT_DIRECTORY, SLOT_FILE_TEMPLATE % [slot_id]];


func _get_backup_path(path: String) -> String:
	return "%s%s" % [path, BACKUP_SUFFIX];


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


func _create_backup(path: String) -> void:
	if not FileAccess.file_exists(path):
		return;
	var backup_path: String = _get_backup_path(path);
	if not _copy_file(path, backup_path):
		_warn_slot_issue("backup/%s" % [path], "failed to create backup '%s'." % [backup_path]);


func _copy_file(source_path: String, target_path: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ);
	if source_file == null:
		return false;
	var bytes: PackedByteArray = source_file.get_buffer(source_file.get_length());
	source_file.close();
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE);
	if target_file == null:
		return false;
	target_file.store_buffer(bytes);
	target_file.close();
	return true;


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

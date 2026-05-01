extends Node;

const SLOT_DIRECTORY: String = "user://saves";
const THUMBNAIL_DIRECTORY: String = "user://saves/thumbnails";
const MANUAL_FILE_TEMPLATE: String = "manual_%d.save";
const LEGACY_FILE_TEMPLATE: String = "slot_%02d.save";
const QUICK_FILE_NAME: String = "quick.save";
const AUTOSAVE_FILE_NAME: String = "autosave.save";
const LEGACY_DEFAULT_SAVE_PATH: String = "user://savegame.save";
const BACKUP_SUFFIX: String = ".bak";
const CONTAINER_VERSION: int = 1;
const DEFAULT_SLOT_ID: int = 0;
const MIN_SLOT_ID: int = 0;
const MAX_SLOT_ID: int = 99;
const SLOT_KIND_MANUAL: StringName = &"manual";
const SLOT_KIND_QUICK: StringName = &"quick";
const SLOT_KIND_AUTOSAVE: StringName = &"autosave";
const THUMBNAIL_WIDTH: int = 320;
const THUMBNAIL_HEIGHT: int = 180;


var _reported_slot_issues: Dictionary = {};


func descriptor_for_manual(slot_id: int) -> Dictionary:
	return {"kind": SLOT_KIND_MANUAL, "id": maxi(slot_id, 0)};


func descriptor_for_quick() -> Dictionary:
	return {"kind": SLOT_KIND_QUICK};


func descriptor_for_autosave() -> Dictionary:
	return {"kind": SLOT_KIND_AUTOSAVE};


func has_save(slot_id: int = DEFAULT_SLOT_ID) -> bool:
	return has_save_descriptor(descriptor_for_manual(_normalize_slot_id(slot_id)));


func has_continue_save() -> bool:
	return not get_latest_slot_for_continue().is_empty();


func has_save_descriptor(slot_descriptor: Dictionary) -> bool:
	return not _resolve_load_path(_normalize_descriptor(slot_descriptor)).is_empty();


func load_game(slot_id: int = DEFAULT_SLOT_ID) -> SaveData:
	return load_game_from_descriptor(descriptor_for_manual(_normalize_slot_id(slot_id)));


func load_latest_for_continue() -> SaveData:
	var descriptor: Dictionary = get_latest_slot_for_continue();
	if descriptor.is_empty():
		return null;
	return load_game_from_descriptor(descriptor);


func load_game_from_descriptor(slot_descriptor: Dictionary) -> SaveData:
	var descriptor: Dictionary = _normalize_descriptor(slot_descriptor);
	if descriptor.is_empty():
		return null;
	var load_path: String = _resolve_load_path(descriptor);
	if load_path.is_empty():
		return null;

	var loaded_data: Dictionary = _read_and_recover_payload(load_path, descriptor);
	if loaded_data.is_empty():
		return null;

	var save_data: SaveData = loaded_data.get("save_data", null) as SaveData;
	if save_data == null:
		return null;

	var metadata: Dictionary = loaded_data.get("metadata", {});
	var source_path: String = String(loaded_data.get("source_path", load_path));
	var should_resave: bool = bool(loaded_data.get("should_resave", false));
	if should_resave or source_path != _get_primary_path(descriptor):
		save_game_to_descriptor(save_data, descriptor, metadata);
	return save_data;


func save_game(data: SaveData, slot_id: int = DEFAULT_SLOT_ID) -> bool:
	return save_game_to_descriptor(data, descriptor_for_manual(_normalize_slot_id(slot_id)));


func save_game_to_descriptor(data: SaveData, slot_descriptor: Dictionary, options: Dictionary = {}) -> bool:
	if data == null:
		return false;
	var descriptor: Dictionary = _normalize_descriptor(slot_descriptor);
	if descriptor.is_empty():
		return false;
	if not _ensure_slot_directory():
		return false;

	var normalized_data: SaveData = SaveData.from_variant(data.to_dictionary());
	if normalized_data == null:
		return false;

	var metadata: Dictionary = _build_metadata(descriptor, normalized_data, options);
	var payload: Dictionary = {
		"container_version": CONTAINER_VERSION,
		"save_data": normalized_data.to_dictionary(),
		"metadata": metadata,
	};
	var save_path: String = _get_primary_path(descriptor);
	_create_backup(save_path);
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE);
	if file == null:
		_warn_slot_issue("write/%s" % [save_path], "failed to open '%s' for writing." % [save_path]);
		return false;
	file.store_var(payload, true);
	file.close();
	_cleanup_legacy_paths_after_save(descriptor);
	return true;


func save_current_session(slot_id: int = DEFAULT_SLOT_ID) -> bool:
	return save_game(SessionContext.to_save_data(), slot_id);


func save_current_session_to_descriptor(slot_descriptor: Dictionary, options: Dictionary = {}) -> bool:
	return save_game_to_descriptor(SessionContext.to_save_data(), slot_descriptor, options);


func save_current_session_to_quick(options: Dictionary = {}) -> bool:
	return save_current_session_to_descriptor(descriptor_for_quick(), options);


func save_current_session_autosave(options: Dictionary = {}) -> bool:
	return save_current_session_to_descriptor(descriptor_for_autosave(), options);


func save_current_session_to_new_manual_slot(options: Dictionary = {}) -> Dictionary:
	var descriptor: Dictionary = descriptor_for_manual(_get_next_manual_slot_id());
	if save_current_session_to_descriptor(descriptor, options):
		return descriptor;
	return {};


func delete_save(slot_id: int = DEFAULT_SLOT_ID) -> void:
	delete_save_descriptor(descriptor_for_manual(_normalize_slot_id(slot_id)));


func delete_save_descriptor(slot_descriptor: Dictionary) -> void:
	var descriptor: Dictionary = _normalize_descriptor(slot_descriptor);
	if descriptor.is_empty():
		return;
	for path: String in _get_related_paths(descriptor):
		_delete_path_and_backup(path);


func clear_all_saves() -> int:
	var descriptors: Array[Dictionary] = list_slot_descriptors(true);
	for descriptor: Dictionary in descriptors:
		delete_save_descriptor(descriptor);
	return descriptors.size();


func list_slots() -> Array[int]:
	return _list_manual_slot_ids();


func list_slot_descriptors(include_system_slots: bool = true) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = [];
	for slot_id: int in _list_manual_slot_ids():
		descriptors.append(descriptor_for_manual(slot_id));
	if include_system_slots:
		var quick_descriptor: Dictionary = descriptor_for_quick();
		var autosave_descriptor: Dictionary = descriptor_for_autosave();
		if has_save_descriptor(quick_descriptor):
			descriptors.append(quick_descriptor);
		if has_save_descriptor(autosave_descriptor):
			descriptors.append(autosave_descriptor);
	return descriptors;


func list_slot_entries(include_system_slots: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = [];
	for descriptor: Dictionary in list_slot_descriptors(include_system_slots):
		var entry: Dictionary = get_slot_metadata(descriptor);
		if entry.is_empty():
			continue;
		entries.append(entry);
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time: int = int(a.get("timestamp_unix", 0));
		var b_time: int = int(b.get("timestamp_unix", 0));
		if a_time == b_time:
			return String(a.get("slot_key", "")) < String(b.get("slot_key", ""));
		return a_time > b_time;
	);
	return entries;


func get_slot_metadata(slot_descriptor: Dictionary) -> Dictionary:
	var descriptor: Dictionary = _normalize_descriptor(slot_descriptor);
	if descriptor.is_empty():
		return {};
	var load_path: String = _resolve_load_path(descriptor);
	if load_path.is_empty():
		return {};
	var loaded_data: Dictionary = _read_and_recover_payload(load_path, descriptor);
	if loaded_data.is_empty():
		return {};
	var save_data: SaveData = loaded_data.get("save_data", null) as SaveData;
	if save_data == null:
		return {};
	return _build_entry(descriptor, loaded_data.get("metadata", {}), save_data);


func get_latest_slot_for_continue() -> Dictionary:
	var best_descriptor: Dictionary = {};
	var best_timestamp: int = -1;
	for entry: Dictionary in list_slot_entries(true):
		if not bool(entry.get("session_exists", false)):
			continue;
		var timestamp_unix: int = int(entry.get("timestamp_unix", 0));
		if timestamp_unix < best_timestamp:
			continue;
		best_timestamp = timestamp_unix;
		best_descriptor = _normalize_descriptor(entry.get("descriptor", {}));
	return best_descriptor;


func _read_and_recover_payload(load_path: String, descriptor: Dictionary) -> Dictionary:
	var loaded_data: Dictionary = _read_payload(load_path, descriptor);
	if not loaded_data.is_empty():
		return loaded_data;
	var backup_path: String = _resolve_backup_path(load_path, descriptor);
	if backup_path.is_empty():
		return {};
	var backup_data: Dictionary = _read_payload(backup_path, descriptor);
	if backup_data.is_empty():
		return {};
	_warn_slot_issue("recover/%s" % [load_path], "recovered '%s' from backup '%s'." % [load_path, backup_path]);
	return backup_data;


func _read_payload(path: String, descriptor: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {};
	var file: FileAccess = FileAccess.open(path, FileAccess.READ);
	if file == null:
		return {};
	var source_data: Variant = file.get_var(true);
	file.close();
	return _parse_payload(source_data, descriptor, path);


func _parse_payload(source_data: Variant, descriptor: Dictionary, source_path: String) -> Dictionary:
	if source_data is Dictionary and (source_data as Dictionary).has("save_data"):
		var payload: Dictionary = source_data as Dictionary;
		var save_data: SaveData = SaveData.from_variant(payload.get("save_data"));
		if save_data == null:
			return {};
		return {
			"save_data": save_data,
			"metadata": _normalize_metadata(payload.get("metadata", {}), descriptor, save_data, source_path),
			"source_path": source_path,
			"should_resave": int(payload.get("container_version", 0)) != CONTAINER_VERSION,
		};

	var legacy_data: SaveData = SaveData.from_variant(source_data);
	if legacy_data == null:
		return {};
	return {
		"save_data": legacy_data,
		"metadata": _normalize_metadata({}, descriptor, legacy_data, source_path),
		"source_path": source_path,
		"should_resave": true,
	};


func _normalize_metadata(raw_metadata: Variant, descriptor: Dictionary, save_data: SaveData, source_path: String) -> Dictionary:
	var metadata: Dictionary = raw_metadata if raw_metadata is Dictionary else {};
	var kind: StringName = _get_descriptor_kind(descriptor);
	var slot_id: int = int(descriptor.get("id", -1));
	var timestamp_unix: int = int(metadata.get("timestamp_unix", FileAccess.get_modified_time(source_path)));
	if timestamp_unix <= 0:
		timestamp_unix = int(Time.get_unix_time_from_system());
	var reason: String = String(metadata.get("reason", "manual")).strip_edges();
	var title: String = String(metadata.get("title", "")).strip_edges();
	if title.is_empty():
		title = _default_title(kind, slot_id, reason);
	return {
		"kind": String(kind),
		"manual_slot_id": slot_id,
		"title": title,
		"timestamp_unix": timestamp_unix,
		"reason": reason,
		"thumbnail_path": String(metadata.get("thumbnail_path", "")),
		"level_id": String(save_data.current_level_id),
		"score": save_data.score,
		"session_exists": save_data.session_exists,
	};


func _build_metadata(descriptor: Dictionary, save_data: SaveData, options: Dictionary) -> Dictionary:
	var kind: StringName = _get_descriptor_kind(descriptor);
	var slot_id: int = int(descriptor.get("id", -1));
	var reason: String = String(options.get("reason", "manual")).strip_edges();
	var title: String = String(options.get("title", "")).strip_edges();
	if title.is_empty():
		title = _default_title(kind, slot_id, reason);
	return {
		"kind": String(kind),
		"manual_slot_id": slot_id,
		"title": title,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"reason": reason,
		"thumbnail_path": _capture_thumbnail(descriptor, options),
		"level_id": String(save_data.current_level_id),
		"score": save_data.score,
		"session_exists": save_data.session_exists,
	};


func _build_entry(descriptor: Dictionary, metadata: Dictionary, save_data: SaveData) -> Dictionary:
	var kind: StringName = _get_descriptor_kind(descriptor);
	return {
		"descriptor": descriptor.duplicate(true),
		"slot_key": _descriptor_key(descriptor),
		"kind": String(kind),
		"kind_label_key": _kind_label_key(kind),
		"title": String(metadata.get("title", _default_title(kind, int(descriptor.get("id", -1)), ""))),
		"timestamp_unix": int(metadata.get("timestamp_unix", 0)),
		"timestamp_text": _format_time(int(metadata.get("timestamp_unix", 0))),
		"reason": String(metadata.get("reason", "")),
		"level_id": StringName(String(metadata.get("level_id", String(save_data.current_level_id)))),
		"score": int(metadata.get("score", save_data.score)),
		"session_exists": bool(metadata.get("session_exists", save_data.session_exists)),
		"thumbnail_path": String(metadata.get("thumbnail_path", "")),
	};


func _kind_label_key(kind: StringName) -> String:
	if kind == SLOT_KIND_QUICK:
		return "UI_SAVE_SLOT_KIND_QUICK";
	if kind == SLOT_KIND_AUTOSAVE:
		return "UI_SAVE_SLOT_KIND_AUTOSAVE";
	return "UI_SAVE_SLOT_KIND_MANUAL";


func _default_title(kind: StringName, slot_id: int, reason: String) -> String:
	if kind == SLOT_KIND_QUICK:
		return "Quick Save";
	if kind == SLOT_KIND_AUTOSAVE:
		if reason == "exit":
			return "Autosave (Exit)";
		if reason == "checkpoint":
			return "Autosave (Checkpoint)";
		if reason == "timer":
			return "Autosave (Timer)";
		return "Autosave";
	return "Manual %d" % [maxi(slot_id, 0)];


func _format_time(timestamp_unix: int) -> String:
	if timestamp_unix <= 0:
		return "-";
	return Time.get_datetime_string_from_unix_time(timestamp_unix, true);


func _normalize_descriptor(slot_descriptor: Variant) -> Dictionary:
	if slot_descriptor is int:
		return descriptor_for_manual(_normalize_slot_id(int(slot_descriptor)));
	if not (slot_descriptor is Dictionary):
		return descriptor_for_manual(DEFAULT_SLOT_ID);
	var source: Dictionary = slot_descriptor as Dictionary;
	var kind: StringName = StringName(String(source.get("kind", String(SLOT_KIND_MANUAL))).to_lower().strip_edges());
	if kind == SLOT_KIND_QUICK or kind == SLOT_KIND_AUTOSAVE:
		return {"kind": kind};
	return descriptor_for_manual(int(source.get("id", DEFAULT_SLOT_ID)));


func _get_descriptor_kind(descriptor: Dictionary) -> StringName:
	return StringName(String(descriptor.get("kind", String(SLOT_KIND_MANUAL))).to_lower().strip_edges());


func _descriptor_key(descriptor: Dictionary) -> String:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind == SLOT_KIND_MANUAL:
		return "manual:%d" % [int(descriptor.get("id", 0))];
	return String(kind);


func _resolve_load_path(descriptor: Dictionary) -> String:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind == SLOT_KIND_QUICK:
		var quick_path: String = _get_quick_path();
		return quick_path if FileAccess.file_exists(quick_path) else "";
	if kind == SLOT_KIND_AUTOSAVE:
		var autosave_path: String = _get_autosave_path();
		return autosave_path if FileAccess.file_exists(autosave_path) else "";

	var slot_id: int = int(descriptor.get("id", DEFAULT_SLOT_ID));
	var manual_path: String = _get_manual_path(slot_id);
	if FileAccess.file_exists(manual_path):
		return manual_path;
	var legacy_slot_path: String = _get_legacy_slot_path(slot_id);
	if FileAccess.file_exists(legacy_slot_path):
		return legacy_slot_path;
	if slot_id == DEFAULT_SLOT_ID and FileAccess.file_exists(LEGACY_DEFAULT_SAVE_PATH):
		return LEGACY_DEFAULT_SAVE_PATH;
	return "";


func _resolve_backup_path(load_path: String, descriptor: Dictionary) -> String:
	var backup_path: String = _get_backup_path(load_path);
	if FileAccess.file_exists(backup_path):
		return backup_path;
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind != SLOT_KIND_MANUAL:
		return "";
	var slot_id: int = int(descriptor.get("id", DEFAULT_SLOT_ID));
	var legacy_slot_backup: String = _get_backup_path(_get_legacy_slot_path(slot_id));
	if FileAccess.file_exists(legacy_slot_backup):
		return legacy_slot_backup;
	if slot_id == DEFAULT_SLOT_ID:
		var legacy_default_backup: String = _get_backup_path(LEGACY_DEFAULT_SAVE_PATH);
		if FileAccess.file_exists(legacy_default_backup):
			return legacy_default_backup;
	return "";


func _get_primary_path(descriptor: Dictionary) -> String:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind == SLOT_KIND_QUICK:
		return _get_quick_path();
	if kind == SLOT_KIND_AUTOSAVE:
		return _get_autosave_path();
	return _get_manual_path(int(descriptor.get("id", DEFAULT_SLOT_ID)));


func _get_related_paths(descriptor: Dictionary) -> Array[String]:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind == SLOT_KIND_QUICK:
		return [_get_quick_path(), _get_thumbnail_path(descriptor)];
	if kind == SLOT_KIND_AUTOSAVE:
		return [_get_autosave_path(), _get_thumbnail_path(descriptor)];
	var slot_id: int = int(descriptor.get("id", DEFAULT_SLOT_ID));
	var paths: Array[String] = [_get_manual_path(slot_id), _get_legacy_slot_path(slot_id), _get_thumbnail_path(descriptor)];
	if slot_id == DEFAULT_SLOT_ID:
		paths.append(LEGACY_DEFAULT_SAVE_PATH);
	return paths;


func _cleanup_legacy_paths_after_save(descriptor: Dictionary) -> void:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind != SLOT_KIND_MANUAL:
		return;
	var slot_id: int = int(descriptor.get("id", DEFAULT_SLOT_ID));
	_delete_path_and_backup(_get_legacy_slot_path(slot_id));
	if slot_id == DEFAULT_SLOT_ID:
		_delete_path_and_backup(LEGACY_DEFAULT_SAVE_PATH);


func _get_manual_path(slot_id: int) -> String:
	return "%s/%s" % [SLOT_DIRECTORY, MANUAL_FILE_TEMPLATE % [maxi(slot_id, 0)]];


func _get_legacy_slot_path(slot_id: int) -> String:
	return "%s/%s" % [SLOT_DIRECTORY, LEGACY_FILE_TEMPLATE % [_normalize_slot_id(slot_id)]];


func _get_quick_path() -> String:
	return "%s/%s" % [SLOT_DIRECTORY, QUICK_FILE_NAME];


func _get_autosave_path() -> String:
	return "%s/%s" % [SLOT_DIRECTORY, AUTOSAVE_FILE_NAME];


func _get_thumbnail_path(descriptor: Dictionary) -> String:
	var kind: StringName = _get_descriptor_kind(descriptor);
	if kind == SLOT_KIND_QUICK:
		return "%s/quick.png" % [THUMBNAIL_DIRECTORY];
	if kind == SLOT_KIND_AUTOSAVE:
		return "%s/autosave.png" % [THUMBNAIL_DIRECTORY];
	return "%s/manual_%d.png" % [THUMBNAIL_DIRECTORY, int(descriptor.get("id", 0))];


func _capture_thumbnail(descriptor: Dictionary, options: Dictionary) -> String:
	if not _should_capture_thumbnail(options):
		return "";
	if not _ensure_thumbnail_directory():
		return "";
	var viewport: Viewport = get_viewport();
	if viewport == null:
		return "";
	var texture: Texture2D = viewport.get_texture();
	if texture == null:
		return "";
	var image: Image = texture.get_image();
	if image == null or image.is_empty():
		return "";
	image.resize(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, Image.INTERPOLATE_LANCZOS);
	var thumbnail_path: String = _get_thumbnail_path(descriptor);
	if image.save_png(thumbnail_path) != OK:
		return "";
	return thumbnail_path;


func _should_capture_thumbnail(options: Dictionary) -> bool:
	if options.has("capture_thumbnail"):
		return bool(options.get("capture_thumbnail", false));
	return AppContext != null and AppContext.settings != null and bool(AppContext.settings.autosave_capture_thumbnail);


func _list_manual_slot_ids() -> Array[int]:
	var map: Dictionary = {};
	var directory: DirAccess = DirAccess.open(SLOT_DIRECTORY);
	if directory != null:
		directory.list_dir_begin();
		while true:
			var entry_name: String = directory.get_next();
			if entry_name.is_empty():
				break;
			if directory.current_is_dir() or entry_name.ends_with(BACKUP_SUFFIX):
				continue;
			if entry_name.begins_with("manual_") and entry_name.ends_with(".save"):
				var manual_text: String = entry_name.substr(7, entry_name.length() - 12);
				if manual_text.is_valid_int():
					map[maxi(int(manual_text), 0)] = true;
			elif entry_name.begins_with("slot_") and entry_name.ends_with(".save"):
				var legacy_text: String = entry_name.substr(5, entry_name.length() - 10);
				if legacy_text.is_valid_int():
					map[_normalize_slot_id(int(legacy_text))] = true;
		directory.list_dir_end();
	if FileAccess.file_exists(LEGACY_DEFAULT_SAVE_PATH):
		map[DEFAULT_SLOT_ID] = true;
	var slots: Array[int] = [];
	for key: Variant in map.keys():
		slots.append(int(key));
	slots.sort();
	return slots;


func _get_next_manual_slot_id() -> int:
	var max_id: int = -1;
	for slot_id: int in _list_manual_slot_ids():
		max_id = maxi(max_id, slot_id);
	return max_id + 1;


func _get_backup_path(path: String) -> String:
	return "%s%s" % [path, BACKUP_SUFFIX];


func _create_backup(path: String) -> void:
	if not FileAccess.file_exists(path):
		return;
	var source_file: FileAccess = FileAccess.open(path, FileAccess.READ);
	if source_file == null:
		return;
	var bytes: PackedByteArray = source_file.get_buffer(source_file.get_length());
	source_file.close();
	var target_file: FileAccess = FileAccess.open(_get_backup_path(path), FileAccess.WRITE);
	if target_file == null:
		return;
	target_file.store_buffer(bytes);
	target_file.close();


func _delete_path_and_backup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path);
	var backup_path: String = _get_backup_path(path);
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path);


func _normalize_slot_id(slot_id: int) -> int:
	if slot_id >= MIN_SLOT_ID and slot_id <= MAX_SLOT_ID:
		return slot_id;
	_warn_slot_issue("slot_id/%s" % [slot_id], "slot id '%d' is out of range, fallback to %d." % [slot_id, DEFAULT_SLOT_ID]);
	return DEFAULT_SLOT_ID;


func _ensure_slot_directory() -> bool:
	if DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		return true;
	return DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY) == OK;


func _ensure_thumbnail_directory() -> bool:
	if DirAccess.dir_exists_absolute(THUMBNAIL_DIRECTORY):
		return true;
	return DirAccess.make_dir_recursive_absolute(THUMBNAIL_DIRECTORY) == OK;


func _warn_slot_issue(issue_key: String, message: String) -> void:
	if _reported_slot_issues.has(issue_key):
		return;
	_reported_slot_issues[issue_key] = true;
	push_warning("SaveManager: %s" % [message]);

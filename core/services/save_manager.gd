extends Node;

const SAVE_PATH: String = "user://savegame.save";

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH);

func load_game() -> SaveData:
	if not has_save():
		return null;

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ);
	if file == null:
		return null;

	var data: Variant = file.get_var(true);
	file.close();

	var save_data: SaveData = SaveData.from_variant(data);
	if save_data == null:
		return null;

	var needs_resave: bool = data is SaveData;
	if data is Dictionary:
		needs_resave = int((data as Dictionary).get("version", 0)) != SaveData.CURRENT_VERSION;
	if needs_resave:
		save_game(save_data);
	return save_data;

func save_game(data: SaveData) -> bool:
	if data == null:
		return false;

	var normalized_data: SaveData = SaveData.from_variant(data.to_dictionary());
	if normalized_data == null:
		return false;

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE);
	if file == null:
		return false;

	file.store_var(normalized_data.to_dictionary(), true);
	file.close();
	return true;

func save_current_session() -> bool:
	return save_game(SessionContext.to_save_data());

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH);

extends Node;

const DEFAULT_PLAYER_HEALTH: int = SaveData.DEFAULT_PLAYER_HEALTH;
const DEFAULT_SCORE: int = SaveData.DEFAULT_SCORE;
const DEFAULT_LEVEL_ID: StringName = SaveData.DEFAULT_LEVEL_ID;

var current_level_id: StringName = DEFAULT_LEVEL_ID;
var player_health: int = DEFAULT_PLAYER_HEALTH;
var score: int = DEFAULT_SCORE;
var is_new_session: bool = true;

func reset() -> void:
	current_level_id = DEFAULT_LEVEL_ID;
	player_health = DEFAULT_PLAYER_HEALTH;
	score = DEFAULT_SCORE;
	is_new_session = true;

func apply_save_data(data: SaveData) -> void:
	if data == null:
		reset();
		return;

	# SessionContext mirrors the validated SaveData snapshot and should not
	# re-implement migration or fallback rules on its own.
	current_level_id = data.current_level_id;
	player_health = data.player_health;
	score = data.score;
	is_new_session = false;

func to_save_data() -> SaveData:
	var data: SaveData = SaveData.new();
	data.session_exists = true;
	data.current_level_id = current_level_id;
	data.player_health = player_health;
	data.score = score;
	return data;

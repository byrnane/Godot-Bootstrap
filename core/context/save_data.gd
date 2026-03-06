extends Resource;
class_name SaveData;

const CURRENT_VERSION: int = 2;
const DEFAULT_LEVEL_ID: StringName = &"level_stub_a";
const DEFAULT_PLAYER_HEALTH: int = 100;
const DEFAULT_SCORE: int = 0;

@export var version: int = CURRENT_VERSION;
@export var session_exists: bool = false;
@export var current_level_id: StringName = DEFAULT_LEVEL_ID;
@export var player_health: int = DEFAULT_PLAYER_HEALTH;
@export var score: int = DEFAULT_SCORE;

func clear() -> void:
	version = CURRENT_VERSION;
	session_exists = false;
	current_level_id = DEFAULT_LEVEL_ID;
	player_health = DEFAULT_PLAYER_HEALTH;
	score = DEFAULT_SCORE;

func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"session_exists": session_exists,
		"current_level_id": String(current_level_id),
		"player_health": player_health,
		"score": score,
	};

static func from_variant(data: Variant) -> SaveData:
	if data is SaveData:
		return _from_resource(data as SaveData);
	if data is Dictionary:
		return _from_dictionary(data as Dictionary);
	return null;

static func _from_resource(resource: SaveData) -> SaveData:
	if resource == null:
		return null;
	if resource.version > CURRENT_VERSION:
		return null;
	var migrated: SaveData = SaveData.new();
	migrated.version = resource.version;
	migrated.session_exists = resource.session_exists;
	migrated.current_level_id = resource.current_level_id;
	migrated.player_health = resource.player_health;
	migrated.score = resource.score;
	migrated._sanitize();
	return migrated;

static func _from_dictionary(data: Dictionary) -> SaveData:
	var source_version: int = int(data.get("version", 0));
	if source_version > CURRENT_VERSION:
		return null;
	var migrated: SaveData = SaveData.new();
	migrated.version = source_version;
	migrated.session_exists = bool(data.get("session_exists", false));
	migrated.current_level_id = StringName(String(data.get("current_level_id", String(DEFAULT_LEVEL_ID))));
	migrated.player_health = int(data.get("player_health", DEFAULT_PLAYER_HEALTH));
	migrated.score = int(data.get("score", DEFAULT_SCORE));
	migrated._sanitize();
	return migrated;

func _sanitize() -> void:
	version = CURRENT_VERSION;
	if not Scenes.has(current_level_id):
		current_level_id = DEFAULT_LEVEL_ID;
	player_health = max(player_health, 0);
	score = max(score, 0);
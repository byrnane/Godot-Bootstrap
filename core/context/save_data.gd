extends Resource;
class_name SaveData;


const CURRENT_VERSION: int = 2;
const MIN_COMPATIBLE_VERSION: int = 0;
const INVALID_SOURCE_VERSION: int = -1;
const DEFAULT_LEVEL_ID: StringName = &"level_stub_a";
const DEFAULT_PLAYER_HEALTH: int = 100;
const DEFAULT_SCORE: int = 0;


enum VersionCompatibility {
	COMPATIBLE,
	TOO_OLD,
	TOO_NEW,
	INVALID,
}


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
	if _classify_source_version(resource.version) != VersionCompatibility.COMPATIBLE:
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
	var source_version: int = _extract_source_version(data);
	if _classify_source_version(source_version) != VersionCompatibility.COMPATIBLE:
		return null;
	var migrated: SaveData = SaveData.new();
	migrated.version = source_version;
	migrated.session_exists = bool(data.get("session_exists", false));
	migrated.current_level_id = StringName(String(data.get("current_level_id", String(DEFAULT_LEVEL_ID))));
	migrated.player_health = int(data.get("player_health", DEFAULT_PLAYER_HEALTH));
	migrated.score = int(data.get("score", DEFAULT_SCORE));
	migrated._sanitize();
	return migrated;


static func get_incompatibility_reason(data: Variant) -> String:
	if not (data is SaveData or data is Dictionary):
		return "unsupported payload type '%s'." % [type_string(typeof(data))];
	var source_version: int = _extract_source_version(data);
	var compatibility: int = _classify_source_version(source_version);
	match compatibility:
		VersionCompatibility.COMPATIBLE:
			return "";
		VersionCompatibility.INVALID:
			return "save version is missing or invalid.";
		VersionCompatibility.TOO_OLD:
			return "save version '%d' is below minimum compatible '%d'." % [
				source_version,
				MIN_COMPATIBLE_VERSION,
			];
		VersionCompatibility.TOO_NEW:
			return "save version '%d' is newer than runtime version '%d'." % [
				source_version,
				CURRENT_VERSION,
			];
	return "save payload is incompatible.";


static func _extract_source_version(data: Variant) -> int:
	if data is SaveData:
		return (data as SaveData).version;
	if data is Dictionary:
		var dictionary_data: Dictionary = data as Dictionary;
		if not dictionary_data.has("version"):
			return MIN_COMPATIBLE_VERSION;
		var raw_version: Variant = dictionary_data.get("version");
		if raw_version is int:
			return raw_version;
		if raw_version is float:
			return int(raw_version);
		if raw_version is String and (raw_version as String).is_valid_int():
			return int(raw_version);
	return INVALID_SOURCE_VERSION;


static func _classify_source_version(source_version: int) -> int:
	if source_version == INVALID_SOURCE_VERSION:
		return VersionCompatibility.INVALID;
	if source_version < MIN_COMPATIBLE_VERSION:
		return VersionCompatibility.TOO_OLD;
	if source_version > CURRENT_VERSION:
		return VersionCompatibility.TOO_NEW;
	return VersionCompatibility.COMPATIBLE;


func _sanitize() -> void:
	# Keep normalization here so callers can treat loaded saves as trusted data.
	version = CURRENT_VERSION;
	if not Scenes.has(current_level_id):
		current_level_id = DEFAULT_LEVEL_ID;
	player_health = max(player_health, 0);
	score = max(score, 0);

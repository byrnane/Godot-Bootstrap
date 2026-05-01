extends Node;


const GAME_CONFIG_DATA_TYPE = preload("res://core/types/game_config_data.gd");
const DEFAULT_CONFIG_PATH: String = "res://core/config/default_game_config.tres";
const OVERRIDE_CONFIG_PATH: String = "res://core/config/game_config_override.tres";
const DEFAULT_START_SCENE_ID: StringName = Scenes.MAIN_MENU;
const DEFAULT_GAMEPLAY_SCENE_ID: StringName = Scenes.GAMEPLAY;
const DEFAULT_MAIN_MENU_MUSIC_PATH: String = "res://assets/music/main_menu.mp3";


var start_scene_id: StringName = DEFAULT_START_SCENE_ID;
var gameplay_scene_id: StringName = DEFAULT_GAMEPLAY_SCENE_ID;
var main_menu_music: AudioStream = null;


var _reported_issues: Dictionary = {};


func _ready() -> void:
	reload();


func _exit_tree() -> void:
	main_menu_music = null;


func get_start_scene_id() -> StringName:
	return _resolve_scene_id(start_scene_id, DEFAULT_START_SCENE_ID, "start_scene_id");


func get_gameplay_scene_id() -> StringName:
	return _resolve_scene_id(gameplay_scene_id, DEFAULT_GAMEPLAY_SCENE_ID, "gameplay_scene_id");


func get_main_menu_music() -> AudioStream:
	if main_menu_music != null:
		return main_menu_music;
	_warn_config_issue("main_menu_music", "main_menu_music is null, fallback to default stream.");
	return load(DEFAULT_MAIN_MENU_MUSIC_PATH) as AudioStream;


func reset_to_defaults() -> void:
	start_scene_id = DEFAULT_START_SCENE_ID;
	gameplay_scene_id = DEFAULT_GAMEPLAY_SCENE_ID;
	main_menu_music = load(DEFAULT_MAIN_MENU_MUSIC_PATH) as AudioStream;


func reload() -> void:
	var default_data: GAME_CONFIG_DATA_TYPE = _load_config_data(DEFAULT_CONFIG_PATH, true);
	var override_data: GAME_CONFIG_DATA_TYPE = _load_config_data(OVERRIDE_CONFIG_PATH, false);
	var resolved_start_scene_id: StringName = DEFAULT_START_SCENE_ID;
	var resolved_gameplay_scene_id: StringName = DEFAULT_GAMEPLAY_SCENE_ID;
	var resolved_main_menu_music: AudioStream = load(DEFAULT_MAIN_MENU_MUSIC_PATH) as AudioStream;

	if default_data != null:
		resolved_start_scene_id = default_data.start_scene_id;
		resolved_gameplay_scene_id = default_data.gameplay_scene_id;
		resolved_main_menu_music = default_data.main_menu_music;

	if override_data != null:
		if override_data.start_scene_id != StringName():
			resolved_start_scene_id = override_data.start_scene_id;
		if override_data.gameplay_scene_id != StringName():
			resolved_gameplay_scene_id = override_data.gameplay_scene_id;
		if override_data.main_menu_music != null:
			resolved_main_menu_music = override_data.main_menu_music;

	start_scene_id = resolved_start_scene_id;
	gameplay_scene_id = resolved_gameplay_scene_id;
	main_menu_music = resolved_main_menu_music;


func _resolve_scene_id(scene_id: StringName, fallback_scene_id: StringName, field_name: String) -> StringName:
	if Scenes.has(scene_id):
		return scene_id;
	_warn_config_issue(
		field_name,
		"%s value '%s' is unknown, fallback to '%s'." % [
			field_name,
			String(scene_id),
			String(fallback_scene_id),
		]
	);
	return fallback_scene_id;


func _load_config_data(path: String, is_required: bool) -> GAME_CONFIG_DATA_TYPE:
	if not ResourceLoader.exists(path):
		if is_required:
			_warn_config_issue(path, "required config resource is missing at '%s'." % [path]);
		return null;
	var resource: Resource = load(path);
	var data: GAME_CONFIG_DATA_TYPE = resource as GAME_CONFIG_DATA_TYPE;
	if data != null:
		return data;
	if is_required:
		_warn_config_issue(path, "resource at '%s' has invalid type, expected GameConfigData." % [path]);
	return null;


func _warn_config_issue(issue_key: String, message: String) -> void:
	if _reported_issues.has(issue_key):
		return;
	_reported_issues[issue_key] = true;
	push_warning("GameConfig: %s" % [message]);

extends Node;


const DEFAULT_START_SCENE_ID: StringName = Scenes.MAIN_MENU;
const DEFAULT_GAMEPLAY_SCENE_ID: StringName = Scenes.GAMEPLAY;
const DEFAULT_MAIN_MENU_MUSIC: AudioStream = preload("res://assets/music/main_menu.mp3");


var start_scene_id: StringName = DEFAULT_START_SCENE_ID;
var gameplay_scene_id: StringName = DEFAULT_GAMEPLAY_SCENE_ID;
var main_menu_music: AudioStream = DEFAULT_MAIN_MENU_MUSIC;


var _reported_issues: Dictionary = {};


func get_start_scene_id() -> StringName:
	return _resolve_scene_id(start_scene_id, DEFAULT_START_SCENE_ID, "start_scene_id");


func get_gameplay_scene_id() -> StringName:
	return _resolve_scene_id(gameplay_scene_id, DEFAULT_GAMEPLAY_SCENE_ID, "gameplay_scene_id");


func get_main_menu_music() -> AudioStream:
	if main_menu_music != null:
		return main_menu_music;
	_warn_config_issue("main_menu_music", "main_menu_music is null, fallback to default stream.");
	return DEFAULT_MAIN_MENU_MUSIC;


func reset_to_defaults() -> void:
	start_scene_id = DEFAULT_START_SCENE_ID;
	gameplay_scene_id = DEFAULT_GAMEPLAY_SCENE_ID;
	main_menu_music = DEFAULT_MAIN_MENU_MUSIC;


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


func _warn_config_issue(issue_key: String, message: String) -> void:
	if _reported_issues.has(issue_key):
		return;
	_reported_issues[issue_key] = true;
	push_warning("GameConfig: %s" % [message]);

extends Resource;
class_name GameConfigData;


@export var start_scene_id: StringName = Scenes.MAIN_MENU;
@export var gameplay_scene_id: StringName = Scenes.GAMEPLAY;
@export var main_menu_music: AudioStream;
## Optional InputMap metadata: label_key, group_key, conflict_group.
@export var input_actions: Dictionary = {};

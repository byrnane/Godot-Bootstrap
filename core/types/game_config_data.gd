extends Resource;
class_name GameConfigData;


const DEFAULT_MAIN_MENU_MUSIC: AudioStream = preload("res://assets/music/main_menu.mp3");


@export var start_scene_id: StringName = Scenes.MAIN_MENU;
@export var gameplay_scene_id: StringName = Scenes.GAMEPLAY;
@export var main_menu_music: AudioStream = DEFAULT_MAIN_MENU_MUSIC;

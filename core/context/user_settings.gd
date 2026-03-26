extends Resource;
class_name UserSettings;


const CURRENT_VERSION: int = 3;
const DEFAULT_LANGUAGE: String = "en";
const DEFAULT_MASTER_VOLUME: float = 1.0;
const DEFAULT_MUSIC_VOLUME: float = 1.0;
const DEFAULT_UI_VOLUME: float = 1.0;
const DEFAULT_SFX_VOLUME: float = 1.0;


@export var version: int = CURRENT_VERSION;
@export var language: String = DEFAULT_LANGUAGE;
@export_range(0.0, 1.0, 0.01) var master_volume: float = DEFAULT_MASTER_VOLUME;
@export_range(0.0, 1.0, 0.01) var music_volume: float = DEFAULT_MUSIC_VOLUME;
@export_range(0.0, 1.0, 0.01) var ui_volume: float = DEFAULT_UI_VOLUME;
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = DEFAULT_SFX_VOLUME;
@export var fullscreen: bool = false;
@export var vsync_enabled: bool = true;


func reset_to_defaults() -> void:
	version = CURRENT_VERSION;
	language = DEFAULT_LANGUAGE;
	master_volume = DEFAULT_MASTER_VOLUME;
	music_volume = DEFAULT_MUSIC_VOLUME;
	ui_volume = DEFAULT_UI_VOLUME;
	sfx_volume = DEFAULT_SFX_VOLUME;
	fullscreen = false;
	vsync_enabled = true;

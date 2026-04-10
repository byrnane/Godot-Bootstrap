extends Resource;
class_name UserSettings;


const CURRENT_VERSION: int = 4;
const DEFAULT_LANGUAGE: String = "en";
const DEFAULT_MASTER_VOLUME: float = 1.0;
const DEFAULT_MUSIC_VOLUME: float = 1.0;
const DEFAULT_UI_VOLUME: float = 1.0;
const DEFAULT_SFX_VOLUME: float = 1.0;
const DEFAULT_AUTOSAVE_ENABLED: bool = true;
const DEFAULT_AUTOSAVE_INTERVAL_SECONDS: int = 120;
const DEFAULT_AUTOSAVE_ON_EXIT: bool = true;
const DEFAULT_AUTOSAVE_ON_CHECKPOINT: bool = true;
const DEFAULT_AUTOSAVE_SCORE_STEP: int = 100;
const DEFAULT_AUTOSAVE_CAPTURE_THUMBNAIL: bool = false;


@export var version: int = CURRENT_VERSION;
@export var language: String = DEFAULT_LANGUAGE;
@export_range(0.0, 1.0, 0.01) var master_volume: float = DEFAULT_MASTER_VOLUME;
@export_range(0.0, 1.0, 0.01) var music_volume: float = DEFAULT_MUSIC_VOLUME;
@export_range(0.0, 1.0, 0.01) var ui_volume: float = DEFAULT_UI_VOLUME;
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = DEFAULT_SFX_VOLUME;
@export var fullscreen: bool = false;
@export var vsync_enabled: bool = true;
@export var autosave_enabled: bool = DEFAULT_AUTOSAVE_ENABLED;
@export_range(15, 3600, 5) var autosave_interval_seconds: int = DEFAULT_AUTOSAVE_INTERVAL_SECONDS;
@export var autosave_on_exit: bool = DEFAULT_AUTOSAVE_ON_EXIT;
@export var autosave_on_checkpoint: bool = DEFAULT_AUTOSAVE_ON_CHECKPOINT;
@export_range(1, 100000, 1) var autosave_score_step: int = DEFAULT_AUTOSAVE_SCORE_STEP;
@export var autosave_capture_thumbnail: bool = DEFAULT_AUTOSAVE_CAPTURE_THUMBNAIL;


func reset_to_defaults() -> void:
	version = CURRENT_VERSION;
	language = DEFAULT_LANGUAGE;
	master_volume = DEFAULT_MASTER_VOLUME;
	music_volume = DEFAULT_MUSIC_VOLUME;
	ui_volume = DEFAULT_UI_VOLUME;
	sfx_volume = DEFAULT_SFX_VOLUME;
	fullscreen = false;
	vsync_enabled = true;
	autosave_enabled = DEFAULT_AUTOSAVE_ENABLED;
	autosave_interval_seconds = DEFAULT_AUTOSAVE_INTERVAL_SECONDS;
	autosave_on_exit = DEFAULT_AUTOSAVE_ON_EXIT;
	autosave_on_checkpoint = DEFAULT_AUTOSAVE_ON_CHECKPOINT;
	autosave_score_step = DEFAULT_AUTOSAVE_SCORE_STEP;
	autosave_capture_thumbnail = DEFAULT_AUTOSAVE_CAPTURE_THUMBNAIL;

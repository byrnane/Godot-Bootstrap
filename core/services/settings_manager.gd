extends Node;

signal settings_applied(settings: UserSettings);


const SETTINGS_PATH: String = "user://settings.cfg";
const SETTINGS_SECTION: String = "settings";


func _ready() -> void:
	AppContext.ensure_defaults();
	load_settings();
	apply_settings();


func load_settings() -> void:
	AppContext.ensure_defaults();
	AppContext.settings = _read_settings_file();


func save_settings() -> void:
	AppContext.ensure_defaults();
	_sanitize_settings(AppContext.settings);
	var config: ConfigFile = ConfigFile.new();
	_write_settings_values(config, AppContext.settings);
	config.save(SETTINGS_PATH);


func apply_settings() -> void:
	AppContext.ensure_defaults();
	_sanitize_settings(AppContext.settings);
	LocalizationManager.apply_current_locale();
	AudioManager.apply_from_settings();
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if AppContext.settings.vsync_enabled else DisplayServer.VSYNC_DISABLED);
	if AppContext.settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
	settings_applied.emit(AppContext.settings);


func _read_settings_file() -> UserSettings:
	var settings: UserSettings = UserSettings.new();
	if not FileAccess.file_exists(SETTINGS_PATH):
		return settings;

	var config: ConfigFile = ConfigFile.new();
	var result: Error = config.load(SETTINGS_PATH);
	if result != OK:
		return settings;

	var source_version: int = int(config.get_value(SETTINGS_SECTION, "version", 0));
	if source_version > UserSettings.CURRENT_VERSION:
		return settings;

	settings.version = int(config.get_value(SETTINGS_SECTION, "version", UserSettings.CURRENT_VERSION));
	_read_common_settings_values(config, settings);
	_sanitize_settings(settings);
	return settings;


func _read_common_settings_values(config: ConfigFile, settings: UserSettings) -> void:
	settings.language = String(config.get_value(SETTINGS_SECTION, "language", settings.language));
	settings.master_volume = float(config.get_value(SETTINGS_SECTION, "master_volume", settings.master_volume));
	settings.music_volume = float(config.get_value(SETTINGS_SECTION, "music_volume", settings.music_volume));
	settings.ui_volume = float(config.get_value(SETTINGS_SECTION, "ui_volume", settings.ui_volume));
	settings.sfx_volume = float(config.get_value(SETTINGS_SECTION, "sfx_volume", settings.sfx_volume));
	settings.fullscreen = bool(config.get_value(SETTINGS_SECTION, "fullscreen", settings.fullscreen));
	settings.vsync_enabled = bool(config.get_value(SETTINGS_SECTION, "vsync_enabled", settings.vsync_enabled));


func _write_settings_values(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION, "version", settings.version);
	config.set_value(SETTINGS_SECTION, "language", settings.language);
	config.set_value(SETTINGS_SECTION, "master_volume", settings.master_volume);
	config.set_value(SETTINGS_SECTION, "music_volume", settings.music_volume);
	config.set_value(SETTINGS_SECTION, "ui_volume", settings.ui_volume);
	config.set_value(SETTINGS_SECTION, "sfx_volume", settings.sfx_volume);
	config.set_value(SETTINGS_SECTION, "fullscreen", settings.fullscreen);
	config.set_value(SETTINGS_SECTION, "vsync_enabled", settings.vsync_enabled);


func _sanitize_settings(settings: UserSettings) -> void:
	if settings == null:
		return;
	# Settings may come from disk, editor defaults, or UI controls; clamp once
	# here so the rest of the runtime can use them without extra guards.
	settings.version = UserSettings.CURRENT_VERSION;
	settings.language = LocalizationManager.normalize_locale(settings.language);
	settings.master_volume = clampf(settings.master_volume, 0.0, 1.0);
	settings.music_volume = clampf(settings.music_volume, 0.0, 1.0);
	settings.ui_volume = clampf(settings.ui_volume, 0.0, 1.0);
	settings.sfx_volume = clampf(settings.sfx_volume, 0.0, 1.0);

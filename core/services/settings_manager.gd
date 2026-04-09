extends Node;

signal settings_applied(settings: UserSettings);


const SETTINGS_PATH: String = "user://settings.cfg";
const SETTINGS_SECTION_LEGACY: String = "settings";
const SETTINGS_SECTION_META: String = "settings_meta";
const SETTINGS_SECTION_LANGUAGE: String = "settings_language";
const SETTINGS_SECTION_AUDIO: String = "settings_audio";
const SETTINGS_SECTION_VIDEO: String = "settings_video";
const SETTINGS_SECTION_INPUT: String = "settings_input";
const INPUT_SETTINGS_DOMAIN_VERSION: int = 1;


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
	_write_settings_version(config, AppContext.settings);
	_write_language_settings(config, AppContext.settings);
	_write_audio_settings(config, AppContext.settings);
	_write_video_settings(config, AppContext.settings);
	_write_input_settings(config, AppContext.settings);
	config.save(SETTINGS_PATH);


func apply_settings() -> void:
	AppContext.ensure_defaults();
	_sanitize_settings(AppContext.settings);
	_apply_language_settings(AppContext.settings);
	_apply_audio_settings(AppContext.settings);
	_apply_video_settings(AppContext.settings);
	_apply_input_settings(AppContext.settings);
	settings_applied.emit(AppContext.settings);


func _read_settings_file() -> UserSettings:
	var settings: UserSettings = UserSettings.new();
	if not FileAccess.file_exists(SETTINGS_PATH):
		return settings;

	var config: ConfigFile = ConfigFile.new();
	var result: Error = config.load(SETTINGS_PATH);
	if result != OK:
		return settings;

	var source_version: int = _read_settings_version(config);
	if source_version > UserSettings.CURRENT_VERSION:
		return settings;

	settings.version = source_version;
	_read_language_settings(config, settings);
	_read_audio_settings(config, settings);
	_read_video_settings(config, settings);
	_read_input_settings(config, settings);
	_sanitize_settings(settings);
	return settings;


func _read_settings_version(config: ConfigFile) -> int:
	if config.has_section_key(SETTINGS_SECTION_META, "version"):
		return int(config.get_value(SETTINGS_SECTION_META, "version", UserSettings.CURRENT_VERSION));
	if config.has_section_key(SETTINGS_SECTION_LEGACY, "version"):
		return int(config.get_value(SETTINGS_SECTION_LEGACY, "version", UserSettings.CURRENT_VERSION));
	return UserSettings.CURRENT_VERSION;


func _read_language_settings(config: ConfigFile, settings: UserSettings) -> void:
	settings.language = String(_get_domain_value(
		config,
		SETTINGS_SECTION_LANGUAGE,
		"locale",
		"language",
		settings.language
	));


func _read_audio_settings(config: ConfigFile, settings: UserSettings) -> void:
	settings.master_volume = float(_get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"master_volume",
		"master_volume",
		settings.master_volume
	));
	settings.music_volume = float(_get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"music_volume",
		"music_volume",
		settings.music_volume
	));
	settings.ui_volume = float(_get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"ui_volume",
		"ui_volume",
		settings.ui_volume
	));
	settings.sfx_volume = float(_get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"sfx_volume",
		"sfx_volume",
		settings.sfx_volume
	));


func _read_video_settings(config: ConfigFile, settings: UserSettings) -> void:
	settings.fullscreen = bool(_get_domain_value(
		config,
		SETTINGS_SECTION_VIDEO,
		"fullscreen",
		"fullscreen",
		settings.fullscreen
	));
	settings.vsync_enabled = bool(_get_domain_value(
		config,
		SETTINGS_SECTION_VIDEO,
		"vsync_enabled",
		"vsync_enabled",
		settings.vsync_enabled
	));


func _read_input_settings(_config: ConfigFile, _settings: UserSettings) -> void:
	# Input bindings are owned by `InputManager` and persisted in a dedicated file.
	return;


func _get_domain_value(config: ConfigFile, section: String, key: String, legacy_key: String, default_value: Variant) -> Variant:
	if config.has_section_key(section, key):
		return config.get_value(section, key, default_value);
	return config.get_value(SETTINGS_SECTION_LEGACY, legacy_key, default_value);


func _write_settings_version(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_META, "version", settings.version);


func _write_language_settings(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_LANGUAGE, "locale", settings.language);


func _write_audio_settings(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_AUDIO, "master_volume", settings.master_volume);
	config.set_value(SETTINGS_SECTION_AUDIO, "music_volume", settings.music_volume);
	config.set_value(SETTINGS_SECTION_AUDIO, "ui_volume", settings.ui_volume);
	config.set_value(SETTINGS_SECTION_AUDIO, "sfx_volume", settings.sfx_volume);


func _write_video_settings(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_VIDEO, "fullscreen", settings.fullscreen);
	config.set_value(SETTINGS_SECTION_VIDEO, "vsync_enabled", settings.vsync_enabled);


func _write_input_settings(config: ConfigFile, _settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_INPUT, "bindings_domain_version", INPUT_SETTINGS_DOMAIN_VERSION);


func _sanitize_settings(settings: UserSettings) -> void:
	if settings == null:
		return;
	# Settings may come from disk, editor defaults, or UI controls; clamp once
	# here so the rest of the runtime can use them without extra guards.
	settings.version = UserSettings.CURRENT_VERSION;
	_sanitize_language_settings(settings);
	_sanitize_audio_settings(settings);
	_sanitize_video_settings(settings);
	_sanitize_input_settings(settings);


func _sanitize_language_settings(settings: UserSettings) -> void:
	settings.language = LocalizationManager.normalize_locale(settings.language);


func _sanitize_audio_settings(settings: UserSettings) -> void:
	settings.master_volume = clampf(settings.master_volume, 0.0, 1.0);
	settings.music_volume = clampf(settings.music_volume, 0.0, 1.0);
	settings.ui_volume = clampf(settings.ui_volume, 0.0, 1.0);
	settings.sfx_volume = clampf(settings.sfx_volume, 0.0, 1.0);


func _sanitize_video_settings(_settings: UserSettings) -> void:
	return;


func _sanitize_input_settings(_settings: UserSettings) -> void:
	return;


func _apply_language_settings(_settings: UserSettings) -> void:
	LocalizationManager.apply_current_locale();


func _apply_audio_settings(_settings: UserSettings) -> void:
	AudioManager.apply_from_settings();


func _apply_video_settings(settings: UserSettings) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync_enabled else DisplayServer.VSYNC_DISABLED);
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);


func _apply_input_settings(_settings: UserSettings) -> void:
	return;

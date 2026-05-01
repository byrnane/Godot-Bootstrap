extends Node;

signal settings_applied(settings: UserSettings);
signal settings_apply_report(report: Dictionary);


const SETTINGS_PATH: String = "user://settings.cfg";
const SETTINGS_SECTION_LEGACY: String = "settings";
const SETTINGS_SECTION_META: String = "settings_meta";
const SETTINGS_SECTION_LANGUAGE: String = "settings_language";
const SETTINGS_SECTION_AUDIO: String = "settings_audio";
const SETTINGS_SECTION_VIDEO: String = "settings_video";
const SETTINGS_SECTION_INPUT: String = "settings_input";
const SETTINGS_SECTION_AUTOSAVE: String = "settings_autosave";
const INPUT_SETTINGS_DOMAIN_VERSION: int = 1;
const BOOL_TRUE_STRINGS: PackedStringArray = ["1", "true", "yes", "on"];
const BOOL_FALSE_STRINGS: PackedStringArray = ["0", "false", "no", "off"];


var _reported_settings_issues: Dictionary = {};


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
	_write_autosave_settings(config, AppContext.settings);
	config.save(SETTINGS_PATH);


func apply_settings() -> Dictionary:
	AppContext.ensure_defaults();
	_sanitize_settings(AppContext.settings);
	var report: Dictionary = {
		"language": _apply_domain_with_recovery(
			"language",
			_apply_language_settings.bind(AppContext.settings),
			_recover_language_settings.bind(AppContext.settings)
		),
		"audio": _apply_domain_with_recovery(
			"audio",
			_apply_audio_settings.bind(AppContext.settings),
			_recover_audio_settings.bind(AppContext.settings)
		),
		"video": _apply_domain_with_recovery(
			"video",
			_apply_video_settings.bind(AppContext.settings),
			_recover_video_settings.bind(AppContext.settings)
		),
		"input": _apply_domain_with_recovery(
			"input",
			_apply_input_settings.bind(AppContext.settings),
			_recover_input_settings.bind(AppContext.settings)
		),
		"autosave": _apply_domain_with_recovery(
			"autosave",
			_apply_autosave_settings.bind(AppContext.settings),
			_recover_autosave_settings.bind(AppContext.settings)
		),
	};
	report["ok"] = _is_apply_report_successful(report);
	if not bool(report.get("ok", true)):
		push_warning("SettingsManager: settings apply completed with failures: %s" % [_build_report_summary(report)]);
	elif _has_recovered_domains(report):
		push_warning("SettingsManager: settings apply recovered with fallback: %s" % [_build_report_summary(report)]);
	settings_applied.emit(AppContext.settings);
	settings_apply_report.emit(report);
	return report;


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
	_read_autosave_settings(config, settings);
	_sanitize_settings(settings);
	return settings;


func _read_settings_version(config: ConfigFile) -> int:
	if config.has_section_key(SETTINGS_SECTION_META, "version"):
		return _parse_int_setting(
			config.get_value(SETTINGS_SECTION_META, "version", UserSettings.CURRENT_VERSION),
			UserSettings.CURRENT_VERSION,
			"%s.version" % [SETTINGS_SECTION_META]
		);
	if config.has_section_key(SETTINGS_SECTION_LEGACY, "version"):
		return _parse_int_setting(
			config.get_value(SETTINGS_SECTION_LEGACY, "version", UserSettings.CURRENT_VERSION),
			UserSettings.CURRENT_VERSION,
			"%s.version" % [SETTINGS_SECTION_LEGACY]
		);
	return UserSettings.CURRENT_VERSION;


func _read_language_settings(config: ConfigFile, settings: UserSettings) -> void:
	var raw_locale: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_LANGUAGE,
		"locale",
		"language",
		settings.language
	);
	settings.language = _parse_locale_setting(raw_locale, settings.language, "settings.language");


func _read_audio_settings(config: ConfigFile, settings: UserSettings) -> void:
	var master_volume: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"master_volume",
		"master_volume",
		settings.master_volume
	);
	var music_volume: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"music_volume",
		"music_volume",
		settings.music_volume
	);
	var ui_volume: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"ui_volume",
		"ui_volume",
		settings.ui_volume
	);
	var sfx_volume: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUDIO,
		"sfx_volume",
		"sfx_volume",
		settings.sfx_volume
	);
	settings.master_volume = _parse_volume_setting(master_volume, settings.master_volume, "settings.audio.master_volume");
	settings.music_volume = _parse_volume_setting(music_volume, settings.music_volume, "settings.audio.music_volume");
	settings.ui_volume = _parse_volume_setting(ui_volume, settings.ui_volume, "settings.audio.ui_volume");
	settings.sfx_volume = _parse_volume_setting(sfx_volume, settings.sfx_volume, "settings.audio.sfx_volume");


func _read_video_settings(config: ConfigFile, settings: UserSettings) -> void:
	var fullscreen: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_VIDEO,
		"fullscreen",
		"fullscreen",
		settings.fullscreen
	);
	var vsync_enabled: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_VIDEO,
		"vsync_enabled",
		"vsync_enabled",
		settings.vsync_enabled
	);
	settings.fullscreen = _parse_bool_setting(fullscreen, settings.fullscreen, "settings.video.fullscreen");
	settings.vsync_enabled = _parse_bool_setting(vsync_enabled, settings.vsync_enabled, "settings.video.vsync_enabled");


func _read_input_settings(_config: ConfigFile, _settings: UserSettings) -> void:
	# Input bindings are owned by `InputManager` and persisted in a dedicated file.
	return;


func _read_autosave_settings(config: ConfigFile, settings: UserSettings) -> void:
	var autosave_enabled: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"enabled",
		"autosave_enabled",
		settings.autosave_enabled
	);
	var autosave_interval_seconds: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"interval_seconds",
		"autosave_interval_seconds",
		settings.autosave_interval_seconds
	);
	var autosave_on_exit: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"on_exit",
		"autosave_on_exit",
		settings.autosave_on_exit
	);
	var autosave_on_checkpoint: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"on_checkpoint",
		"autosave_on_checkpoint",
		settings.autosave_on_checkpoint
	);
	var autosave_score_step: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"score_step",
		"autosave_score_step",
		settings.autosave_score_step
	);
	var autosave_capture_thumbnail: Variant = _get_domain_value(
		config,
		SETTINGS_SECTION_AUTOSAVE,
		"capture_thumbnail",
		"autosave_capture_thumbnail",
		settings.autosave_capture_thumbnail
	);
	settings.autosave_enabled = _parse_bool_setting(autosave_enabled, settings.autosave_enabled, "settings.autosave.enabled");
	settings.autosave_interval_seconds = _parse_int_setting(
		autosave_interval_seconds,
		settings.autosave_interval_seconds,
		"settings.autosave.interval_seconds"
	);
	settings.autosave_on_exit = _parse_bool_setting(autosave_on_exit, settings.autosave_on_exit, "settings.autosave.on_exit");
	settings.autosave_on_checkpoint = _parse_bool_setting(
		autosave_on_checkpoint,
		settings.autosave_on_checkpoint,
		"settings.autosave.on_checkpoint"
	);
	settings.autosave_score_step = _parse_int_setting(autosave_score_step, settings.autosave_score_step, "settings.autosave.score_step");
	settings.autosave_capture_thumbnail = _parse_bool_setting(
		autosave_capture_thumbnail,
		settings.autosave_capture_thumbnail,
		"settings.autosave.capture_thumbnail"
	);


func _get_domain_value(config: ConfigFile, section: String, key: String, legacy_key: String, default_value: Variant) -> Variant:
	if config.has_section_key(section, key):
		return config.get_value(section, key, default_value);
	return config.get_value(SETTINGS_SECTION_LEGACY, legacy_key, default_value);


func _parse_locale_setting(value: Variant, fallback: String, issue_key: String) -> String:
	if not (value is String):
		_warn_settings_issue(issue_key, "expected string locale, got '%s'." % [type_string(typeof(value))]);
		return LocalizationManager.normalize_locale(fallback);
	var locale: String = String(value).strip_edges();
	if locale.is_empty():
		_warn_settings_issue(issue_key, "locale value is empty, fallback is used.");
		return LocalizationManager.normalize_locale(fallback);
	return LocalizationManager.normalize_locale(locale);


func _parse_volume_setting(value: Variant, fallback: float, issue_key: String) -> float:
	var parsed_value: float = _parse_float_setting(value, fallback, issue_key);
	return clampf(parsed_value, 0.0, 1.0);


func _parse_float_setting(value: Variant, fallback: float, issue_key: String) -> float:
	if value is float:
		return value;
	if value is int:
		return float(value);
	if value is String and (value as String).is_valid_float():
		return float(value);
	_warn_settings_issue(issue_key, "expected float value, got '%s'." % [type_string(typeof(value))]);
	return fallback;


func _parse_bool_setting(value: Variant, fallback: bool, issue_key: String) -> bool:
	if value is bool:
		return value;
	if value is int:
		return value != 0;
	if value is String:
		var normalized_value: String = String(value).strip_edges().to_lower();
		if BOOL_TRUE_STRINGS.has(normalized_value):
			return true;
		if BOOL_FALSE_STRINGS.has(normalized_value):
			return false;
	_warn_settings_issue(issue_key, "expected bool value, got '%s'." % [type_string(typeof(value))]);
	return fallback;


func _parse_int_setting(value: Variant, fallback: int, issue_key: String) -> int:
	if value is int:
		return value;
	if value is float:
		return int(value);
	if value is String and (value as String).is_valid_int():
		return int(value);
	_warn_settings_issue(issue_key, "expected int value, got '%s'." % [type_string(typeof(value))]);
	return fallback;


func _warn_settings_issue(issue_key: String, message: String) -> void:
	if _reported_settings_issues.has(issue_key):
		return;
	_reported_settings_issues[issue_key] = true;
	push_warning("SettingsManager: %s" % [message]);


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


func _write_autosave_settings(config: ConfigFile, settings: UserSettings) -> void:
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "enabled", settings.autosave_enabled);
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "interval_seconds", settings.autosave_interval_seconds);
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "on_exit", settings.autosave_on_exit);
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "on_checkpoint", settings.autosave_on_checkpoint);
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "score_step", settings.autosave_score_step);
	config.set_value(SETTINGS_SECTION_AUTOSAVE, "capture_thumbnail", settings.autosave_capture_thumbnail);


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
	_sanitize_autosave_settings(settings);


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


func _sanitize_autosave_settings(settings: UserSettings) -> void:
	settings.autosave_interval_seconds = clampi(settings.autosave_interval_seconds, 15, 3600);
	settings.autosave_score_step = maxi(1, settings.autosave_score_step);


func _apply_domain_with_recovery(domain_name: String, apply_step: Callable, recover_step: Callable) -> Dictionary:
	var initial_ok: bool = bool(apply_step.call());
	if initial_ok:
		return {
			"ok": true,
			"recovered": false,
		};

	recover_step.call();
	var recovered_ok: bool = bool(apply_step.call());
	return {
		"ok": recovered_ok,
		"recovered": true,
		"domain": domain_name,
	};


func _is_apply_report_successful(report: Dictionary) -> bool:
	for domain_name: String in ["language", "audio", "video", "input", "autosave"]:
		var domain_report: Variant = report.get(domain_name, {});
		if not (domain_report is Dictionary):
			return false;
		if not bool((domain_report as Dictionary).get("ok", false)):
			return false;
	return true;


func _has_recovered_domains(report: Dictionary) -> bool:
	for domain_name: String in ["language", "audio", "video", "input", "autosave"]:
		var domain_report: Variant = report.get(domain_name, {});
		if not (domain_report is Dictionary):
			continue;
		if bool((domain_report as Dictionary).get("recovered", false)):
			return true;
	return false;


func _build_report_summary(report: Dictionary) -> String:
	var fragments: PackedStringArray = [];
	for domain_name: String in ["language", "audio", "video", "input", "autosave"]:
		var domain_report: Variant = report.get(domain_name, {});
		if not (domain_report is Dictionary):
			fragments.append("%s=invalid" % [domain_name]);
			continue;
		var typed_report: Dictionary = domain_report as Dictionary;
		var status_text: String = "ok" if bool(typed_report.get("ok", false)) else "failed";
		if bool(typed_report.get("recovered", false)):
			status_text += "(recovered)";
		fragments.append("%s=%s" % [domain_name, status_text]);
	return ", ".join(fragments);


func _apply_language_settings(settings: UserSettings) -> bool:
	LocalizationManager.apply_current_locale();
	var expected_locale: String = LocalizationManager.normalize_locale(settings.language);
	var active_locale: String = LocalizationManager.normalize_locale(TranslationServer.get_locale());
	return active_locale == expected_locale;


func _recover_language_settings(settings: UserSettings) -> void:
	settings.language = LocalizationManager.DEFAULT_LOCALE;


func _apply_audio_settings(_settings: UserSettings) -> bool:
	if AudioManager == null:
		return false;
	if AudioManager.has_method("_ensure_bus_layout"):
		AudioManager.call("_ensure_bus_layout");
	AudioManager.apply_from_settings();
	for bus_name: String in [
		AudioManager.MASTER_BUS_NAME,
		AudioManager.MUSIC_BUS_NAME,
		AudioManager.UI_BUS_NAME,
		AudioManager.SFX_BUS_NAME,
	]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return false;
	return true;


func _recover_audio_settings(settings: UserSettings) -> void:
	settings.master_volume = UserSettings.DEFAULT_MASTER_VOLUME;
	settings.music_volume = UserSettings.DEFAULT_MUSIC_VOLUME;
	settings.ui_volume = UserSettings.DEFAULT_UI_VOLUME;
	settings.sfx_volume = UserSettings.DEFAULT_SFX_VOLUME;


func _apply_video_settings(settings: UserSettings) -> bool:
	# Headless runs have no real window surface, so window-mode validation would
	# report a false failure and pollute smoke output.
	if DisplayServer.get_name().to_lower() == "headless":
		return true;
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync_enabled else DisplayServer.VSYNC_DISABLED);
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
	var expected_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED;
	return DisplayServer.window_get_mode() == expected_mode;


func _recover_video_settings(settings: UserSettings) -> void:
	settings.fullscreen = false;
	settings.vsync_enabled = true;


func _apply_input_settings(_settings: UserSettings) -> bool:
	return InputManager != null;


func _recover_input_settings(_settings: UserSettings) -> void:
	return;


func _apply_autosave_settings(_settings: UserSettings) -> bool:
	if AutosaveManager == null:
		return true;
	if AutosaveManager.has_method("refresh_policy"):
		AutosaveManager.call("refresh_policy");
	return true;


func _recover_autosave_settings(settings: UserSettings) -> void:
	settings.autosave_enabled = UserSettings.DEFAULT_AUTOSAVE_ENABLED;
	settings.autosave_interval_seconds = UserSettings.DEFAULT_AUTOSAVE_INTERVAL_SECONDS;
	settings.autosave_on_exit = UserSettings.DEFAULT_AUTOSAVE_ON_EXIT;
	settings.autosave_on_checkpoint = UserSettings.DEFAULT_AUTOSAVE_ON_CHECKPOINT;
	settings.autosave_score_step = UserSettings.DEFAULT_AUTOSAVE_SCORE_STEP;
	settings.autosave_capture_thumbnail = UserSettings.DEFAULT_AUTOSAVE_CAPTURE_THUMBNAIL;

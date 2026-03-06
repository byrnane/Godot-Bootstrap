extends Node;

signal locale_changed(locale: String);

const DEFAULT_LOCALE: String = "en";
const SUPPORTED_LOCALES: PackedStringArray = ["en", "ru"];
const LOCALE_DISPLAY_NAMES: Dictionary = {
	"en": "English",
	"ru": "Русский",
};

func _ready() -> void:
	apply_current_locale();

func get_supported_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate();

func get_current_locale() -> String:
	return TranslationServer.get_locale();

func get_display_name(locale: String) -> String:
	var normalized_locale: String = normalize_locale(locale);
	return String(LOCALE_DISPLAY_NAMES.get(normalized_locale, normalized_locale));

func normalize_locale(locale: String) -> String:
	var normalized_locale: String = locale.strip_edges().to_lower();
	if normalized_locale.is_empty():
		return DEFAULT_LOCALE;
	if SUPPORTED_LOCALES.has(normalized_locale):
		return normalized_locale;
	if normalized_locale.contains("_"):
		normalized_locale = normalized_locale.get_slice("_", 0);
		if SUPPORTED_LOCALES.has(normalized_locale):
			return normalized_locale;
	if normalized_locale.contains("-"):
		normalized_locale = normalized_locale.get_slice("-", 0);
		if SUPPORTED_LOCALES.has(normalized_locale):
			return normalized_locale;
	return DEFAULT_LOCALE;

func set_locale(locale: String, persist_to_settings: bool = true) -> void:
	AppContext.ensure_defaults();
	var normalized_locale: String = normalize_locale(locale);
	TranslationServer.set_locale(normalized_locale);
	if persist_to_settings:
		AppContext.settings.language = normalized_locale;
	locale_changed.emit(normalized_locale);

func apply_current_locale() -> void:
	AppContext.ensure_defaults();
	var normalized_locale: String = normalize_locale(AppContext.settings.language);
	AppContext.settings.language = normalized_locale;
	set_locale(normalized_locale, false);

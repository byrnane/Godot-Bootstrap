extends BaseModal;
class_name SettingsModal;

var _is_syncing_controls: bool = false;
var _is_dirty: bool = false;

@onready var language_option_button: OptionButton = %LanguageOptionButton;
@onready var master_volume_slider: HSlider = %MasterVolumeSlider;
@onready var music_volume_slider: HSlider = %MusicVolumeSlider;
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider;
@onready var fullscreen_check_box: CheckBox = %FullscreenCheckBox;
@onready var vsync_check_box: CheckBox = %VSyncCheckBox;
@onready var apply_button: Button = %ApplyButton;
@onready var reset_button: Button = %ResetButton;

func _ready() -> void:
	super._ready();
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed);
	language_option_button.item_selected.connect(_on_controls_changed);
	master_volume_slider.value_changed.connect(_on_controls_changed);
	music_volume_slider.value_changed.connect(_on_controls_changed);
	sfx_volume_slider.value_changed.connect(_on_controls_changed);
	fullscreen_check_box.toggled.connect(_on_controls_changed);
	vsync_check_box.toggled.connect(_on_controls_changed);
	_populate_locales();
	_sync_from_settings();

func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed);

func open_modal() -> void:
	_populate_locales();
	_sync_from_settings();
	super.open_modal();

func _sync_ui_state() -> void:
	_refresh_action_state();

func _populate_locales() -> void:
	var selected_locale: String = LocalizationManager.normalize_locale(_get_selected_locale_value());
	if selected_locale.is_empty():
		selected_locale = LocalizationManager.normalize_locale(AppContext.settings.language);
	_is_syncing_controls = true;
	language_option_button.clear();
	# Rebuild labels on every open/locale change so the dropdown itself is also
	# translated instead of freezing in the language used at startup.
	for locale: String in LocalizationManager.get_supported_locales():
		language_option_button.add_item(LocalizationManager.get_display_name(locale));
		var item_index: int = language_option_button.item_count - 1;
		language_option_button.set_item_metadata(item_index, locale);
		if locale == selected_locale:
			language_option_button.select(item_index);
	_is_syncing_controls = false;

func _sync_from_settings() -> void:
	_is_syncing_controls = true;
	var selected_locale: String = LocalizationManager.normalize_locale(AppContext.settings.language);
	for item_index: int in range(language_option_button.item_count):
		if String(language_option_button.get_item_metadata(item_index)) == selected_locale:
			language_option_button.select(item_index);
			break;
	master_volume_slider.value = AppContext.settings.master_volume;
	music_volume_slider.value = AppContext.settings.music_volume;
	sfx_volume_slider.value = AppContext.settings.sfx_volume;
	fullscreen_check_box.button_pressed = AppContext.settings.fullscreen;
	vsync_check_box.button_pressed = AppContext.settings.vsync_enabled;
	_is_syncing_controls = false;
	_is_dirty = false;
	_refresh_action_state();

func _apply_values() -> void:
	AppContext.settings.language = _get_selected_locale_value();
	AppContext.settings.master_volume = float(master_volume_slider.value);
	AppContext.settings.music_volume = float(music_volume_slider.value);
	AppContext.settings.sfx_volume = float(sfx_volume_slider.value);
	AppContext.settings.fullscreen = fullscreen_check_box.button_pressed;
	AppContext.settings.vsync_enabled = vsync_check_box.button_pressed;
	SettingsManager.apply_settings();
	SettingsManager.save_settings();
	_is_dirty = false;
	_refresh_action_state();

func _get_selected_locale_value() -> String:
	var selected_index: int = language_option_button.selected;
	if selected_index < 0:
		return LocalizationManager.normalize_locale(AppContext.settings.language);
	return LocalizationManager.normalize_locale(String(language_option_button.get_item_metadata(selected_index)));

func _refresh_action_state() -> void:
	apply_button.disabled = not _is_dirty;
	reset_button.disabled = _is_syncing_controls;

func _on_apply_button_pressed() -> void:
	_apply_values();
	close_requested.emit();

func _on_reset_button_pressed() -> void:
	AppContext.settings.reset_to_defaults();
	SettingsManager.apply_settings();
	SettingsManager.save_settings();
	_populate_locales();
	_sync_from_settings();

func _on_close_button_pressed() -> void:
	close_requested.emit();

func _on_controls_changed(_value: Variant = null) -> void:
	if _is_syncing_controls:
		return;
	_is_dirty = true;
	_refresh_action_state();

func _on_locale_changed(_locale: String) -> void:
	_populate_locales();

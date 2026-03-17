extends BaseModal;
class_name SettingsModal;

var _is_syncing_controls: bool = false;
var _is_dirty: bool = false;
var _binding_buttons: Dictionary = {};
var _binding_labels: Dictionary = {};

@onready var language_option_button: OptionButton = %LanguageOptionButton;
@onready var master_volume_slider: HSlider = %MasterVolumeSlider;
@onready var music_volume_slider: HSlider = %MusicVolumeSlider;
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider;
@onready var fullscreen_check_box: CheckBox = %FullscreenCheckBox;
@onready var vsync_check_box: CheckBox = %VSyncCheckBox;
@onready var bindings_container: VBoxContainer = %BindingsContainer;
@onready var bindings_status_label: Label = %BindingsStatusLabel;
@onready var reset_bindings_button: Button = %ResetBindingsButton;
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
	reset_bindings_button.pressed.connect(_on_reset_bindings_button_pressed);
	if not InputManager.bindings_changed.is_connected(_on_bindings_changed):
		InputManager.bindings_changed.connect(_on_bindings_changed);
	if not InputManager.rebind_started.is_connected(_on_rebind_started):
		InputManager.rebind_started.connect(_on_rebind_started);
	if not InputManager.rebind_completed.is_connected(_on_rebind_finished):
		InputManager.rebind_completed.connect(_on_rebind_finished);
	if not InputManager.rebind_canceled.is_connected(_on_rebind_finished):
		InputManager.rebind_canceled.connect(_on_rebind_finished);
	_build_bindings_ui();
	_populate_locales();
	_sync_from_settings();

func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed);
	if InputManager.bindings_changed.is_connected(_on_bindings_changed):
		InputManager.bindings_changed.disconnect(_on_bindings_changed);
	if InputManager.rebind_started.is_connected(_on_rebind_started):
		InputManager.rebind_started.disconnect(_on_rebind_started);
	if InputManager.rebind_completed.is_connected(_on_rebind_finished):
		InputManager.rebind_completed.disconnect(_on_rebind_finished);
	if InputManager.rebind_canceled.is_connected(_on_rebind_finished):
		InputManager.rebind_canceled.disconnect(_on_rebind_finished);

func open_modal() -> void:
	_populate_locales();
	_sync_from_settings();
	super.open_modal();

func _sync_ui_state() -> void:
	_refresh_action_state();
	_refresh_bindings_ui();

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

func _build_bindings_ui() -> void:
	for child: Node in bindings_container.get_children():
		bindings_container.remove_child(child);
		child.queue_free();

	_binding_buttons.clear();
	_binding_labels.clear();
	for action_name: StringName in InputManager.get_rebindable_actions():
		var row: HBoxContainer = HBoxContainer.new();
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		row.theme_override_constants.separation = 8;

		var label: Label = Label.new();
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		row.add_child(label);

		var button: Button = Button.new();
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		button.pressed.connect(_on_binding_button_pressed.bind(action_name));
		row.add_child(button);

		bindings_container.add_child(row);
		_binding_buttons[action_name] = button;
		_binding_labels[action_name] = label;

	_refresh_bindings_ui();

func _refresh_bindings_ui() -> void:
	for action_name_variant: Variant in _binding_buttons.keys():
		var action_name: StringName = StringName(String(action_name_variant));
		var label: Label = _binding_labels.get(action_name) as Label;
		var button: Button = _binding_buttons[action_name] as Button;
		if label != null:
			label.text = tr(InputManager.get_action_label_key(action_name));
		if button == null:
			continue;
		if InputManager.is_rebinding_action(action_name):
			button.text = tr("UI_INPUT_WAITING");
		else:
			button.text = InputManager.get_action_binding_text(action_name);
		button.disabled = InputManager.is_rebinding() and not InputManager.is_rebinding_action(action_name);

	if InputManager.is_rebinding():
		bindings_status_label.text = tr("UI_INPUT_REBIND_HINT");
	else:
		bindings_status_label.text = tr("UI_INPUT_BINDINGS_HINT");
	reset_bindings_button.disabled = InputManager.is_rebinding();

func _on_apply_button_pressed() -> void:
	InputManager.cancel_rebind();
	_apply_values();
	close_requested.emit();

func _on_reset_button_pressed() -> void:
	AppContext.settings.reset_to_defaults();
	SettingsManager.apply_settings();
	SettingsManager.save_settings();
	_populate_locales();
	_sync_from_settings();

func _on_close_button_pressed() -> void:
	InputManager.cancel_rebind();
	close_requested.emit();

func _on_controls_changed(_value: Variant = null) -> void:
	if _is_syncing_controls:
		return;
	_is_dirty = true;
	_refresh_action_state();

func _on_locale_changed(_locale: String) -> void:
	_populate_locales();
	_refresh_bindings_ui();

func _on_binding_button_pressed(action_name: StringName) -> void:
	InputManager.start_rebind(action_name);
	_refresh_bindings_ui();

func _on_reset_bindings_button_pressed() -> void:
	InputManager.reset_to_defaults();
	_refresh_bindings_ui();

func _on_bindings_changed(_action_name: StringName) -> void:
	_refresh_bindings_ui();

func _on_rebind_started(_action_name: StringName) -> void:
	_refresh_bindings_ui();

func _on_rebind_finished(_action_name: StringName) -> void:
	_refresh_bindings_ui();

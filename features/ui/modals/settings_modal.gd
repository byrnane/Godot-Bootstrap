extends BaseModal;
class_name SettingsModal;


const UI_CARD_SCENE: PackedScene = preload("res://shared/ui/components/ui_card.tscn");
const UI_SECTION_HEADER_SCENE: PackedScene = preload("res://shared/ui/components/ui_section_header.tscn");
const UI_FORM_ROW_SCENE: PackedScene = preload("res://shared/ui/components/ui_form_row.tscn");


var _is_syncing_controls: bool = false;
var _is_dirty: bool = false;
var _is_close_confirmation_pending: bool = false;
var _binding_buttons: Dictionary = {};


@onready var settings_tabs = %SettingsTabs;
@onready var language_option_button: OptionButton = %LanguageOptionButton;
@onready var master_volume_slider: HSlider = %MasterVolumeSlider;
@onready var music_volume_slider: HSlider = %MusicVolumeSlider;
@onready var ui_volume_slider: HSlider = %UiVolumeSlider;
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
	ui_volume_slider.value_changed.connect(_on_controls_changed);
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
	_refresh_tab_titles();
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
	_is_close_confirmation_pending = false;
	_populate_locales();
	_sync_from_settings();
	super.open_modal();


func request_close() -> void:
	InputManager.cancel_rebind();
	if not _is_dirty:
		close_requested.emit();
		return;
	if _is_close_confirmation_pending:
		return;

	_is_close_confirmation_pending = true;
	UiFeedback.confirm(
		tr("UI_SETTINGS_DISCARD_MESSAGE"),
		_on_confirm_close_with_unsaved_changes,
		_on_cancel_close_with_unsaved_changes,
		{
			"title": tr("UI_SETTINGS_DISCARD_TITLE"),
			"confirm_text": tr("UI_SETTINGS_DISCARD_CONFIRM"),
			"cancel_text": tr("UI_SETTINGS_DISCARD_CANCEL"),
			"close_on_backdrop": true,
			"close_on_cancel": true,
		}
	);


func _sync_ui_state() -> void:
	_refresh_action_state();
	_refresh_tab_titles();
	_refresh_bindings_ui();


func _populate_locales() -> void:
	var selected_locale: String = LocalizationManager.normalize_locale(_get_selected_locale_value());
	if selected_locale.is_empty():
		selected_locale = LocalizationManager.normalize_locale(AppContext.settings.language);
	_is_syncing_controls = true;
	language_option_button.clear();
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
	ui_volume_slider.value = AppContext.settings.ui_volume;
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
	AppContext.settings.ui_volume = float(ui_volume_slider.value);
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


func _refresh_tab_titles() -> void:
	if settings_tabs == null:
		return;
	settings_tabs.refresh_titles();


func _build_bindings_ui() -> void:
	for child: Node in bindings_container.get_children():
		bindings_container.remove_child(child);
		child.queue_free();

	_binding_buttons.clear();
	for group_key: StringName in InputManager.get_action_groups():
		var group_actions: Array[StringName] = InputManager.get_actions_for_group(group_key);
		if group_actions.is_empty():
			continue;

		var group_card = UI_CARD_SCENE.instantiate();
		if group_card == null:
			continue;

		group_card.elevated = true;
		bindings_container.add_child(group_card);
		var group_content: VBoxContainer = group_card.get_node("%Content") as VBoxContainer;
		var group_header = UI_SECTION_HEADER_SCENE.instantiate();
		group_header.title_key = String(group_key);
		group_content.add_child(group_header);

		for action_name: StringName in group_actions:
			var row = UI_FORM_ROW_SCENE.instantiate();
			if row == null:
				continue;

			row.title_key = InputManager.get_action_label_key(action_name);
			group_content.add_child(row);
			var content_container: HBoxContainer = row.get_node("%Content") as HBoxContainer;

			var buttons: Array[Button] = [];
			for binding_slot: int in range(InputManager.get_binding_slot_count()):
				var button: Button = Button.new();
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
				button.pressed.connect(_on_binding_button_pressed.bind(action_name, binding_slot));
				content_container.add_child(button);
				buttons.append(button);

			_binding_buttons[action_name] = buttons;

	_refresh_bindings_ui();


func _refresh_bindings_ui() -> void:
	for action_name_variant: Variant in _binding_buttons.keys():
		var action_name: StringName = StringName(action_name_variant);
		var buttons: Variant = _binding_buttons.get(action_name, []);
		if not (buttons is Array):
			continue;
		for binding_slot: int in range((buttons as Array).size()):
			var button: Button = buttons[binding_slot] as Button;
			if button == null:
				continue;
			if InputManager.is_rebinding_slot(action_name, binding_slot):
				button.text = tr("UI_INPUT_WAITING");
			else:
				button.text = InputManager.get_action_binding_text(action_name, binding_slot);
			button.disabled = InputManager.is_rebinding() and not InputManager.is_rebinding_slot(action_name, binding_slot);

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
	request_close();


func _on_controls_changed(_value: Variant = null) -> void:
	if _is_syncing_controls:
		return;
	_is_dirty = true;
	_refresh_action_state();


func _on_locale_changed(_locale: String) -> void:
	_populate_locales();
	_refresh_tab_titles();
	_build_bindings_ui();


func _on_binding_button_pressed(action_name: StringName, binding_slot: int) -> void:
	InputManager.start_rebind(action_name, binding_slot);
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


func _on_confirm_close_with_unsaved_changes() -> void:
	_is_close_confirmation_pending = false;
	_populate_locales();
	_sync_from_settings();
	close_requested.emit();


func _on_cancel_close_with_unsaved_changes() -> void:
	_is_close_confirmation_pending = false;
	focus_default_control();

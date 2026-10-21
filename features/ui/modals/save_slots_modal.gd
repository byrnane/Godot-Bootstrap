extends BaseModal;
class_name SaveSlotsModal;

signal load_slot_requested(slot_descriptor: Dictionary);


enum Mode {
	LOAD,
	SAVE,
}


const SLOT_SCENE: PackedScene = preload("res://shared/ui/components/ui_save_slot.tscn");

var _selected_index: int = -1;
var _slot_buttons: Array[Button] = [];

var _mode: int = Mode.LOAD;
var _entries: Array[Dictionary] = [];
var _pending_action: StringName = &"";
var _pending_descriptor: Dictionary = {};


@onready var mode_hint_label: Label = %ModeHintLabel;
@onready var slot_list: VBoxContainer = %SlotList;
@onready var title_line_edit: LineEdit = %TitleLineEdit;
@onready var slot_title_label: Label = %SlotTitleLabel;
@onready var slot_kind_label: Label = %SlotKindLabel;
@onready var slot_time_label: Label = %SlotTimeLabel;
@onready var slot_level_label: Label = %SlotLevelLabel;
@onready var slot_score_label: Label = %SlotScoreLabel;
@onready var preview_texture_rect: TextureRect = %PreviewTextureRect;
@onready var load_button: Button = %LoadButton;
@onready var save_button: Button = %SaveButton;
@onready var new_slot_button: Button = %NewSlotButton;
@onready var quick_save_button: Button = %QuickSaveButton;
@onready var delete_button: Button = %DeleteButton;
@onready var refresh_button: Button = %RefreshButton;
@onready var close_button: Button = %CloseButton;


func _ready() -> void:
	super._ready();
	if preload("res://shared/ui/theme/ui_density.gd").is_compact(self):
		var main_row: BoxContainer = slot_list.get_parent().get_parent();
		main_row.vertical = true;
		slot_list.get_parent().custom_minimum_size = Vector2.ZERO;
		# One scroll owner prevents competing focus-follow adjustments in the stacked layout.
		slot_list.get_parent().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;
		slot_list.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		preview_texture_rect.custom_minimum_size = Vector2(0, 96);
		var details: Control = main_row.get_node("Details");
		details.custom_minimum_size = Vector2.ZERO;
		for label: Label in [slot_title_label, slot_kind_label, slot_time_label, slot_level_label, slot_score_label]:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	%LoadModeButton.pressed.connect(set_mode.bind(&"load"));
	%SaveModeButton.pressed.connect(set_mode.bind(&"save"));
	load_button.pressed.connect(_on_load_button_pressed);
	save_button.pressed.connect(_on_save_button_pressed);
	new_slot_button.pressed.connect(_on_new_slot_button_pressed);
	quick_save_button.pressed.connect(_on_quick_save_button_pressed);
	delete_button.pressed.connect(_on_delete_button_pressed);
	refresh_button.pressed.connect(_reload_entries);
	close_button.pressed.connect(request_close);


func set_mode(mode_name: StringName) -> void:
	_mode = Mode.LOAD if mode_name == &"load" else Mode.SAVE;
	_sync_ui_state();


func _sync_ui_state() -> void:
	_reload_entries();
	_refresh_mode_state();
	_refresh_selection_state();


func _reload_entries(preferred_descriptor: Dictionary = {}) -> void:
	var selected_key: String = _get_selected_slot_key();
	_entries = SaveManager.list_slot_entries(true);
	for child: Node in slot_list.get_children():
		slot_list.remove_child(child);
		child.queue_free();
	_slot_buttons.clear();
	_selected_index = -1;
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index];
		var slot: UiSaveSlot = SLOT_SCENE.instantiate() as UiSaveSlot;
		slot.title = String(entry.get("title", ""));
		slot.detail = "%s · %s" % [tr(String(entry.get("kind_label_key", "UI_SAVE_SLOT_KIND_MANUAL"))), String(entry.get("timestamp_text", ""))];
		slot.preview = _load_thumbnail_texture(String(entry.get("thumbnail_path", "")));
		slot.pressed.connect(_on_slot_list_item_selected.bind(index));
		slot_list.add_child(slot);
		_slot_buttons.append(slot);
		var matches_preferred: bool = not preferred_descriptor.is_empty() and entry.get("descriptor", {}) == preferred_descriptor;
		var matches_previous: bool = preferred_descriptor.is_empty() and String(entry.get("slot_key", "")) == selected_key;
		if matches_preferred or matches_previous:
			_selected_index = index;
	if not _entries.is_empty() and _selected_index < 0:
		_selected_index = 0;
	if _entries.is_empty():
		var empty: Label = Label.new();
		empty.text = tr("UI_SAVE_SLOT_EMPTY");
		empty.theme_type_variation = &"UiMuted";
		slot_list.add_child(empty);
	_update_slot_buttons();
	_refresh_selection_state();


func _refresh_mode_state() -> void:
	var is_save_mode: bool = _mode == Mode.SAVE;
	mode_hint_label.text = tr("UI_SAVE_SLOT_MODE_SAVE") if is_save_mode else tr("UI_SAVE_SLOT_MODE_LOAD");
	var can_write: bool = _can_write_session();
	%LoadModeButton.set_pressed_no_signal(not is_save_mode);
	%SaveModeButton.set_pressed_no_signal(is_save_mode);
	%SaveModeButton.disabled = not can_write;
	title_line_edit.visible = is_save_mode;
	title_line_edit.editable = is_save_mode and can_write;
	save_button.visible = is_save_mode;
	new_slot_button.visible = is_save_mode;
	quick_save_button.visible = is_save_mode;
	save_button.disabled = not is_save_mode or not can_write;
	new_slot_button.disabled = not is_save_mode or not can_write;
	quick_save_button.disabled = not is_save_mode or not can_write;


func _refresh_selection_state() -> void:
	var selected_entry: Dictionary = _get_selected_entry();
	var has_selection: bool = not selected_entry.is_empty();
	load_button.disabled = not has_selection;
	delete_button.disabled = not has_selection;
	if _mode == Mode.SAVE:
		save_button.disabled = not _can_write_session() or not has_selection;

	if not has_selection:
		slot_title_label.text = tr("UI_SAVE_SLOT_EMPTY");
		slot_kind_label.text = tr("UI_SAVE_SLOT_KIND_LABEL").format({"value": "-"});
		slot_time_label.text = tr("UI_SAVE_SLOT_TIME_LABEL").format({"value": "-"});
		slot_level_label.text = tr("UI_SAVE_SLOT_LEVEL_LABEL").format({"value": "-"});
		slot_score_label.text = tr("UI_SAVE_SLOT_SCORE_LABEL").format({"value": 0});
		preview_texture_rect.texture = null;
		return;

	slot_title_label.text = String(selected_entry.get("title", ""));
	slot_kind_label.text = tr("UI_SAVE_SLOT_KIND_LABEL").format({
		"value": tr(String(selected_entry.get("kind_label_key", "UI_SAVE_SLOT_KIND_MANUAL"))),
	});
	slot_time_label.text = tr("UI_SAVE_SLOT_TIME_LABEL").format({"value": String(selected_entry.get("timestamp_text", "-"))});
	slot_level_label.text = tr("UI_SAVE_SLOT_LEVEL_LABEL").format({"value": String(selected_entry.get("level_id", "-"))});
	slot_score_label.text = tr("UI_SAVE_SLOT_SCORE_LABEL").format({"value": int(selected_entry.get("score", 0))});
	preview_texture_rect.texture = _load_thumbnail_texture(String(selected_entry.get("thumbnail_path", "")));


func _load_thumbnail_texture(thumbnail_path: String) -> Texture2D:
	if thumbnail_path.is_empty():
		return null;
	if not FileAccess.file_exists(thumbnail_path):
		return null;
	var image: Image = Image.new();
	if image.load(thumbnail_path) != OK:
		return null;
	return ImageTexture.create_from_image(image);


func _get_selected_entry() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _entries.size():
		return {};
	return _entries[_selected_index];


func _get_selected_slot_key() -> String:
	var selected_entry: Dictionary = _get_selected_entry();
	if selected_entry.is_empty():
		return "";
	return String(selected_entry.get("slot_key", ""));


func _update_slot_buttons() -> void:
	for index: int in range(_slot_buttons.size()):
		_slot_buttons[index].set_pressed_no_signal(index == _selected_index);


func _on_slot_list_item_selected(index: int) -> void:
	_selected_index = index;
	_update_slot_buttons();
	_refresh_mode_state();
	_refresh_selection_state();


func _on_load_button_pressed() -> void:
	var selected_entry: Dictionary = _get_selected_entry();
	if selected_entry.is_empty():
		UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SELECT_SLOT"), {"variant": "warning"});
		return;
	load_slot_requested.emit(selected_entry.get("descriptor", {}));


func _on_save_button_pressed() -> void:
	var selected_entry: Dictionary = _get_selected_entry();
	if selected_entry.is_empty():
		UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SELECT_SLOT"), {"variant": "warning"});
		return;
	_pending_action = &"save_selected";
	_pending_descriptor = SaveManager.descriptor_for_manual(0);
	_pending_descriptor = selected_entry.get("descriptor", {}).duplicate(true);
	UiFeedback.confirm(
		tr("UI_SAVE_SLOT_CONFIRM_OVERWRITE_MESSAGE"),
		_on_confirm_pending_action,
		_on_cancel_pending_action,
		{
			"title": tr("UI_SAVE_SLOT_CONFIRM_OVERWRITE_TITLE"),
			"confirm_text": tr("UI_SAVE_SLOT_CONFIRM_OVERWRITE_ACTION"),
			"cancel_text": tr("UI_FEEDBACK_CANCEL_BUTTON"),
		}
	);


func _on_new_slot_button_pressed() -> void:
	var descriptor: Dictionary = SaveManager.save_current_session_to_new_manual_slot({
		"title": _get_title_input(),
		"reason": "manual",
	});
	if descriptor.is_empty():
		UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_FAILED"), {"variant": "error"});
		return;
	UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_SUCCESS"), {"variant": "success"});
	_reload_entries(descriptor);


func _on_quick_save_button_pressed() -> void:
	_pending_action = &"quick_save";
	_pending_descriptor = {};
	UiFeedback.confirm(
		tr("UI_SAVE_SLOT_CONFIRM_QUICK_OVERWRITE_MESSAGE"),
		_on_confirm_pending_action,
		_on_cancel_pending_action,
		{
			"title": tr("UI_SAVE_SLOT_CONFIRM_QUICK_OVERWRITE_TITLE"),
			"confirm_text": tr("UI_SAVE_SLOT_CONFIRM_OVERWRITE_ACTION"),
			"cancel_text": tr("UI_FEEDBACK_CANCEL_BUTTON"),
		}
	);


func _on_delete_button_pressed() -> void:
	var selected_entry: Dictionary = _get_selected_entry();
	if selected_entry.is_empty():
		UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SELECT_SLOT"), {"variant": "warning"});
		return;
	_pending_action = &"delete_selected";
	_pending_descriptor = selected_entry.get("descriptor", {}).duplicate(true);
	UiFeedback.confirm(
		tr("UI_SAVE_SLOT_CONFIRM_DELETE_MESSAGE"),
		_on_confirm_pending_action,
		_on_cancel_pending_action,
		{
			"title": tr("UI_SAVE_SLOT_CONFIRM_DELETE_TITLE"),
			"destructive": true,
			"confirm_text": tr("UI_SAVE_SLOT_CONFIRM_DELETE_ACTION"),
			"cancel_text": tr("UI_FEEDBACK_CANCEL_BUTTON"),
		}
	);


func _on_confirm_pending_action() -> void:
	match _pending_action:
		&"save_selected":
			var overwrite_success: bool = SaveManager.save_current_session_to_descriptor(_pending_descriptor, {
				"title": _get_title_input(),
				"reason": "manual",
			});
			if overwrite_success:
				UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_SUCCESS"), {"variant": "success"});
			else:
				UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_FAILED"), {"variant": "error"});
		&"quick_save":
			var quick_success: bool = SaveManager.save_current_session_to_quick({
				"title": _get_title_input(),
				"reason": "manual",
			});
			if quick_success:
				UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_QUICK_SAVE_DONE"), {"variant": "success"});
			else:
				UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_FAILED"), {"variant": "error"});
		&"delete_selected":
			SaveManager.delete_save_descriptor(_pending_descriptor);
			UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_DELETE_SUCCESS"), {"variant": "warning"});
	_clear_pending_action();
	_reload_entries();


func _on_cancel_pending_action() -> void:
	_clear_pending_action();


func _clear_pending_action() -> void:
	_pending_action = &"";
	_pending_descriptor = {};


func _get_title_input() -> String:
	return title_line_edit.text.strip_edges();


func _can_write_session() -> bool:
	return AppContext.state == AppState.Value.IN_GAME or AppContext.state == AppState.Value.PAUSED;

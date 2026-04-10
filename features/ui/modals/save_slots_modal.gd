extends BaseModal;
class_name SaveSlotsModal;

signal load_slot_requested(slot_descriptor: Dictionary);


enum Mode {
	LOAD,
	SAVE,
}


var _mode: int = Mode.LOAD;
var _entries: Array[Dictionary] = [];
var _pending_action: StringName = &"";
var _pending_descriptor: Dictionary = {};


@onready var mode_hint_label: Label = %ModeHintLabel;
@onready var slot_list: ItemList = %SlotList;
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
	slot_list.item_selected.connect(_on_slot_list_item_selected);
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


func _reload_entries() -> void:
	var selected_key: String = _get_selected_slot_key();
	_entries = SaveManager.list_slot_entries(true);
	slot_list.clear();
	var selected_index: int = -1;
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index];
		var label_text: String = _build_list_item_label(entry);
		slot_list.add_item(label_text);
		slot_list.set_item_metadata(index, String(entry.get("slot_key", "")));
		if String(entry.get("slot_key", "")) == selected_key:
			selected_index = index;

	if _entries.is_empty():
		selected_index = -1;
	elif selected_index < 0:
		selected_index = 0;

	if selected_index >= 0:
		slot_list.select(selected_index);
	_refresh_selection_state();


func _build_list_item_label(entry: Dictionary) -> String:
	var kind_label: String = tr(String(entry.get("kind_label_key", "UI_SAVE_SLOT_KIND_MANUAL")));
	var title_text: String = String(entry.get("title", ""));
	var time_text: String = String(entry.get("timestamp_text", "-"));
	return "[%s] %s (%s)" % [kind_label, title_text, time_text];


func _refresh_mode_state() -> void:
	var is_save_mode: bool = _mode == Mode.SAVE;
	mode_hint_label.text = tr("UI_SAVE_SLOT_MODE_SAVE") if is_save_mode else tr("UI_SAVE_SLOT_MODE_LOAD");
	var can_write: bool = _can_write_session();
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
		save_button.disabled = save_button.disabled or not has_selection;

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
	var selected_items: PackedInt32Array = slot_list.get_selected_items();
	if selected_items.is_empty():
		return {};
	var selected_index: int = selected_items[0];
	if selected_index < 0 or selected_index >= _entries.size():
		return {};
	return _entries[selected_index];


func _get_selected_slot_key() -> String:
	var selected_entry: Dictionary = _get_selected_entry();
	if selected_entry.is_empty():
		return "";
	return String(selected_entry.get("slot_key", ""));


func _on_slot_list_item_selected(_index: int) -> void:
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
	_reload_entries();


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

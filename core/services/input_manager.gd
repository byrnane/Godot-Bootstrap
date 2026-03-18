extends Node;

signal bindings_changed(action_name: StringName);
signal rebind_started(action_name: StringName);
signal rebind_completed(action_name: StringName);
signal rebind_canceled(action_name: StringName);


const INPUT_SETTINGS_PATH: String = "user://input_bindings.save";
const KEY_NONE: int = 0;
const KEYCODE_ESCAPE: int = 4194305;
const KEYCODE_F10: int = 4194310;
const KEYCODE_F3: int = 4194334;
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"ui_pause",
	&"ui_cancel",
	&"ui_debug_overlay",
];
const COMPATIBLE_BINDING_PAIRS: Array[Array] = [
	[&"ui_pause", &"ui_cancel"],
];
const ACTION_LABEL_KEYS: Dictionary = {
	&"ui_pause": "UI_INPUT_ACTION_PAUSE",
	&"ui_cancel": "UI_INPUT_ACTION_CANCEL",
	&"ui_debug_overlay": "UI_INPUT_ACTION_DEBUG_OVERLAY",
};


var _default_bindings: Dictionary = {};
var _pending_rebind_action: StringName = &"";


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	_cache_default_bindings();
	load_bindings();


func _input(event: InputEvent) -> void:
	if not is_rebinding():
		return;

	if not _is_supported_rebind_event(event):
		return;

	_apply_rebind(_pending_rebind_action, event);
	get_viewport().set_input_as_handled();


func get_rebindable_actions() -> Array[StringName]:
	return REBINDABLE_ACTIONS.duplicate();


func get_action_label_key(action_name: StringName) -> String:
	return String(ACTION_LABEL_KEYS.get(action_name, String(action_name)));


func get_action_events(action_name: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = [];
	for event: InputEvent in InputMap.action_get_events(action_name):
		events.append(event);
	return events;


func get_action_binding_text(action_name: StringName) -> String:
	var events: Array[InputEvent] = get_action_events(action_name);
	if events.is_empty():
		return tr("UI_INPUT_UNBOUND");
	return _get_event_display_text(events[0]);


func is_rebinding() -> bool:
	return _pending_rebind_action != StringName();


func is_rebinding_action(action_name: StringName) -> bool:
	return _pending_rebind_action == action_name;


func start_rebind(action_name: StringName) -> bool:
	if not REBINDABLE_ACTIONS.has(action_name):
		return false;

	if is_rebinding_action(action_name):
		cancel_rebind();
		return false;

	if is_rebinding():
		cancel_rebind();

	_pending_rebind_action = action_name;
	rebind_started.emit(action_name);
	return true;


func cancel_rebind() -> void:
	if not is_rebinding():
		return;

	var canceled_action: StringName = _pending_rebind_action;
	_pending_rebind_action = &"";
	rebind_canceled.emit(canceled_action);


func reset_to_defaults() -> void:
	cancel_rebind();
	for action_name: StringName in REBINDABLE_ACTIONS:
		_restore_default_action(action_name);
		bindings_changed.emit(action_name);
	save_bindings();


func save_bindings() -> bool:
	var file: FileAccess = FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.WRITE);
	if file == null:
		return false;

	file.store_var(_serialize_bindings(), true);
	file.close();
	return true;


func load_bindings() -> void:
	_restore_defaults();
	if not FileAccess.file_exists(INPUT_SETTINGS_PATH):
		_emit_all_bindings_changed();
		return;

	var file: FileAccess = FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.READ);
	if file == null:
		_emit_all_bindings_changed();
		return;

	var data: Variant = file.get_var(true);
	file.close();
	if not (data is Dictionary):
		_emit_all_bindings_changed();
		return;

	var bindings: Dictionary = data as Dictionary;
	for action_name: StringName in REBINDABLE_ACTIONS:
		if not bindings.has(String(action_name)):
			bindings_changed.emit(action_name);
			continue;

		var raw_events: Variant = bindings[String(action_name)];
		if not (raw_events is Array):
			_restore_default_action(action_name);
			bindings_changed.emit(action_name);
			continue;

		var loaded_events: Array[InputEvent] = _deserialize_events(raw_events as Array);
		if loaded_events.is_empty():
			_restore_default_action(action_name);
			bindings_changed.emit(action_name);
			continue;

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name);
		InputMap.action_erase_events(action_name);
		for input_event: InputEvent in loaded_events:
			InputMap.action_add_event(action_name, input_event);
		bindings_changed.emit(action_name);


func _cache_default_bindings() -> void:
	_default_bindings.clear();
	for action_name: StringName in REBINDABLE_ACTIONS:
		var action_events: Array[InputEvent] = _duplicate_events(InputMap.action_get_events(action_name));
		if action_events.is_empty():
			action_events = _get_builtin_default_events(action_name);
		_default_bindings[action_name] = action_events;


func _restore_defaults() -> void:
	for action_name: StringName in REBINDABLE_ACTIONS:
		_restore_default_action(action_name);


func _serialize_bindings() -> Dictionary:
	var serialized: Dictionary = {};
	for action_name: StringName in REBINDABLE_ACTIONS:
		serialized[String(action_name)] = _duplicate_events(InputMap.action_get_events(action_name));
	return serialized;


func _get_default_events(action_name: StringName) -> Array[InputEvent]:
	var raw_events: Variant = _default_bindings.get(action_name, []);
	if not (raw_events is Array):
		return _get_builtin_default_events(action_name);

	var default_events: Array[InputEvent] = _duplicate_events(raw_events as Array);
	if default_events.is_empty():
		return _get_builtin_default_events(action_name);
	return default_events;


func _duplicate_events(source_events: Array) -> Array[InputEvent]:
	var duplicated: Array[InputEvent] = [];
	for source_event: Variant in source_events:
		var input_event: InputEvent = source_event as InputEvent;
		if input_event == null:
			continue;
		duplicated.append(input_event.duplicate());
	return duplicated;


func _deserialize_events(source_events: Array) -> Array[InputEvent]:
	var deserialized: Array[InputEvent] = [];
	for source_event: Variant in source_events:
		var input_event: InputEvent = source_event as InputEvent;
		if input_event == null:
			continue;
		deserialized.append(input_event);
	return deserialized;


func _restore_default_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name);
	InputMap.action_erase_events(action_name);
	for default_event: InputEvent in _get_default_events(action_name):
		InputMap.action_add_event(action_name, default_event);


func _emit_all_bindings_changed() -> void:
	for action_name: StringName in REBINDABLE_ACTIONS:
		bindings_changed.emit(action_name);


func _is_supported_rebind_event(event: InputEvent) -> bool:
	var key_event: InputEventKey = event as InputEventKey;
	if key_event != null:
		return key_event.pressed and not key_event.echo;

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton;
	if mouse_button_event != null:
		var is_supported_button: bool = mouse_button_event.button_index in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_XBUTTON1,
			MOUSE_BUTTON_XBUTTON2,
		];
		return mouse_button_event.pressed and is_supported_button;

	var joypad_button_event: InputEventJoypadButton = event as InputEventJoypadButton;
	if joypad_button_event != null:
		return joypad_button_event.pressed;

	return false;


func _apply_rebind(action_name: StringName, event: InputEvent) -> void:
	if not REBINDABLE_ACTIONS.has(action_name):
		cancel_rebind();
		return;

	for other_action_name: StringName in REBINDABLE_ACTIONS:
		if other_action_name == action_name:
			continue;
		if _can_actions_share_binding(action_name, other_action_name):
			continue;
		InputMap.action_erase_event(other_action_name, event);
		bindings_changed.emit(other_action_name);

	InputMap.action_erase_events(action_name);
	InputMap.action_add_event(action_name, event);
	save_bindings();
	_pending_rebind_action = &"";
	bindings_changed.emit(action_name);
	rebind_completed.emit(action_name);


func _can_actions_share_binding(first_action: StringName, second_action: StringName) -> bool:
	for compatible_pair: Array in COMPATIBLE_BINDING_PAIRS:
		if compatible_pair.size() != 2:
			continue;
		var left_action: StringName = compatible_pair[0];
		var right_action: StringName = compatible_pair[1];
		var matches_direct_order: bool = left_action == first_action and right_action == second_action;
		var matches_reverse_order: bool = left_action == second_action and right_action == first_action;
		if matches_direct_order or matches_reverse_order:
			return true;
	return false;


func _get_event_display_text(event: InputEvent) -> String:
	var key_event: InputEventKey = event as InputEventKey;
	if key_event != null:
		if int(key_event.physical_keycode) != KEY_NONE:
			var physical_text: String = key_event.as_text_physical_keycode();
			if not physical_text.is_empty():
				return physical_text;

		if int(key_event.keycode) != KEY_NONE:
			var keycode_text: String = key_event.as_text_keycode();
			if not keycode_text.is_empty():
				return keycode_text;

		if int(key_event.key_label) != KEY_NONE:
			return OS.get_keycode_string(key_event.key_label);

		return key_event.as_text();

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton;
	if mouse_button_event != null:
		match mouse_button_event.button_index:
			MOUSE_BUTTON_LEFT:
				return tr("UI_INPUT_MOUSE_LEFT");
			MOUSE_BUTTON_RIGHT:
				return tr("UI_INPUT_MOUSE_RIGHT");
			MOUSE_BUTTON_MIDDLE:
				return tr("UI_INPUT_MOUSE_MIDDLE");
			MOUSE_BUTTON_XBUTTON1:
				return tr("UI_INPUT_MOUSE_X1");
			MOUSE_BUTTON_XBUTTON2:
				return tr("UI_INPUT_MOUSE_X2");
			_:
				return mouse_button_event.as_text();

	var joypad_button_event: InputEventJoypadButton = event as InputEventJoypadButton;
	if joypad_button_event != null:
		return "%s %d" % [tr("UI_INPUT_GAMEPAD_BUTTON"), joypad_button_event.button_index];

	return event.as_text();


func _get_builtin_default_events(action_name: StringName) -> Array[InputEvent]:
	match action_name:
		&"ui_pause":
			return [_create_key_event(KEYCODE_F10)];
		&"ui_cancel":
			return [_create_key_event(KEYCODE_ESCAPE)];
		&"ui_debug_overlay":
			return [_create_key_event(KEYCODE_F3)];
		_:
			return [];


func _create_key_event(keycode: int) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new();
	key_event.keycode = keycode as Key;
	key_event.key_label = keycode as Key;
	return key_event;

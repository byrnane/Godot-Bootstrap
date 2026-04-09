extends Node;

signal bindings_changed(action_name: StringName);
signal rebind_started(action_name: StringName);
signal rebind_completed(action_name: StringName);
signal rebind_canceled(action_name: StringName);
signal rebind_conflicts_resolved(action_name: StringName, replaced_actions: Array[StringName]);


const INPUT_SETTINGS_PATH: String = "user://input_bindings.save";
const KEY_NONE: int = 0;
const DEFAULT_KEY_ESCAPE: Key = KEY_ESCAPE as Key;
const DEFAULT_KEY_F10: Key = KEY_F10 as Key;
const DEFAULT_KEY_F3: Key = KEY_F3 as Key;
const DEFAULT_KEY_ENTER: Key = KEY_ENTER as Key;
const DEFAULT_KEY_SPACE: Key = KEY_SPACE as Key;
const DEFAULT_KEY_UP: Key = KEY_UP as Key;
const DEFAULT_KEY_W: Key = KEY_W as Key;
const DEFAULT_KEY_DOWN: Key = KEY_DOWN as Key;
const DEFAULT_KEY_S: Key = KEY_S as Key;
const DEFAULT_KEY_LEFT: Key = KEY_LEFT as Key;
const DEFAULT_KEY_A: Key = KEY_A as Key;
const DEFAULT_KEY_RIGHT: Key = KEY_RIGHT as Key;
const DEFAULT_KEY_D: Key = KEY_D as Key;
const MAX_BINDINGS_PER_ACTION: int = 2;
const ACTION_GROUP_ORDER: Array[StringName] = [
	&"UI_INPUT_GROUP_NAVIGATION",
	&"UI_INPUT_GROUP_SYSTEM",
	&"UI_INPUT_GROUP_DEBUG",
];
# `InputManager` owns metadata for the actions the settings UI is allowed to edit.
# The actual runtime bindings still live in Godot's `InputMap`.
const ACTION_METADATA: Dictionary = {
	&"ui_accept": {
		"label_key": "UI_INPUT_ACTION_ACCEPT",
		"group_key": "UI_INPUT_GROUP_NAVIGATION",
		"conflict_group": "navigation_confirm",
	},
	&"ui_up": {
		"label_key": "UI_INPUT_ACTION_UP",
		"group_key": "UI_INPUT_GROUP_NAVIGATION",
		"conflict_group": "navigation_vertical",
	},
	&"ui_down": {
		"label_key": "UI_INPUT_ACTION_DOWN",
		"group_key": "UI_INPUT_GROUP_NAVIGATION",
		"conflict_group": "navigation_vertical",
	},
	&"ui_left": {
		"label_key": "UI_INPUT_ACTION_LEFT",
		"group_key": "UI_INPUT_GROUP_NAVIGATION",
		"conflict_group": "navigation_horizontal",
	},
	&"ui_right": {
		"label_key": "UI_INPUT_ACTION_RIGHT",
		"group_key": "UI_INPUT_GROUP_NAVIGATION",
		"conflict_group": "navigation_horizontal",
	},
	&"ui_cancel": {
		"label_key": "UI_INPUT_ACTION_CANCEL",
		"group_key": "UI_INPUT_GROUP_SYSTEM",
		"conflict_group": "system_contextual",
	},
	&"ui_pause": {
		"label_key": "UI_INPUT_ACTION_PAUSE",
		"group_key": "UI_INPUT_GROUP_SYSTEM",
		"conflict_group": "system_contextual",
	},
	&"ui_debug_overlay": {
		"label_key": "UI_INPUT_ACTION_DEBUG_OVERLAY",
		"group_key": "UI_INPUT_GROUP_DEBUG",
		"conflict_group": "debug_tools",
	},
};
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"ui_accept",
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_cancel",
	&"ui_pause",
	&"ui_debug_overlay",
];


var _default_bindings: Dictionary = {};
var _pending_rebind_action: StringName = &"";
var _pending_rebind_slot: int = -1;


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


func get_binding_slot_count() -> int:
	return MAX_BINDINGS_PER_ACTION;


func get_action_groups() -> Array[StringName]:
	var groups: Array[StringName] = [];
	for group_key: StringName in ACTION_GROUP_ORDER:
		if not get_actions_for_group(group_key).is_empty():
			groups.append(group_key);
	return groups;


func get_actions_for_group(group_key: StringName) -> Array[StringName]:
	var actions: Array[StringName] = [];
	for action_name: StringName in REBINDABLE_ACTIONS:
		if get_action_group_key(action_name) == group_key:
			actions.append(action_name);
	return actions;


func get_action_group_key(action_name: StringName) -> StringName:
	return StringName(_get_action_metadata(action_name).get("group_key", &"UI_INPUT_GROUP_SYSTEM"));


func get_action_label_key(action_name: StringName) -> String:
	return String(_get_action_metadata(action_name).get("label_key", String(action_name)));


func get_action_events(action_name: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = [];
	for event: InputEvent in InputMap.action_get_events(action_name):
		if _is_supported_stored_event(event):
			events.append(event);
	return events;


func get_action_binding_text(action_name: StringName, binding_slot: int = 0) -> String:
	var events: Array[InputEvent] = get_action_events(action_name);
	if binding_slot < 0 or binding_slot >= events.size():
		return tr("UI_INPUT_UNBOUND");
	return _get_event_display_text(events[binding_slot]);


func is_rebinding() -> bool:
	return _pending_rebind_action != StringName();


func is_rebinding_action(action_name: StringName) -> bool:
	return _pending_rebind_action == action_name;


func is_rebinding_slot(action_name: StringName, binding_slot: int) -> bool:
	return _pending_rebind_action == action_name and _pending_rebind_slot == binding_slot;


func get_pending_rebind_action() -> StringName:
	return _pending_rebind_action;


func get_pending_rebind_slot() -> int:
	return _pending_rebind_slot;


func start_rebind(action_name: StringName, binding_slot: int = 0) -> bool:
	if not REBINDABLE_ACTIONS.has(action_name):
		return false;
	if binding_slot < 0 or binding_slot >= MAX_BINDINGS_PER_ACTION:
		return false;

	if is_rebinding_slot(action_name, binding_slot):
		cancel_rebind();
		return false;

	if is_rebinding():
		cancel_rebind();

	_pending_rebind_action = action_name;
	_pending_rebind_slot = binding_slot;
	rebind_started.emit(action_name);
	return true;


func cancel_rebind() -> void:
	if not is_rebinding():
		return;

	var canceled_action: StringName = _pending_rebind_action;
	_pending_rebind_action = &"";
	_pending_rebind_slot = -1;
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

		_set_action_events(action_name, loaded_events);
		bindings_changed.emit(action_name);


func _cache_default_bindings() -> void:
	_default_bindings.clear();
	for action_name: StringName in REBINDABLE_ACTIONS:
		var action_events: Array[InputEvent] = _duplicate_events(get_action_events(action_name));
		if action_events.is_empty():
			action_events = _get_builtin_default_events(action_name);
		_default_bindings[action_name] = action_events;


func _restore_defaults() -> void:
	for action_name: StringName in REBINDABLE_ACTIONS:
		_restore_default_action(action_name);


func _serialize_bindings() -> Dictionary:
	var serialized: Dictionary = {};
	for action_name: StringName in REBINDABLE_ACTIONS:
		serialized[String(action_name)] = _duplicate_events(get_action_events(action_name));
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
		if input_event == null or not _is_supported_stored_event(input_event):
			continue;
		deserialized.append(input_event);
	return deserialized;


func _restore_default_action(action_name: StringName) -> void:
	_set_action_events(action_name, _get_default_events(action_name));


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

	return false;


func _is_supported_stored_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton;


func _apply_rebind(action_name: StringName, event: InputEvent) -> void:
	if not REBINDABLE_ACTIONS.has(action_name):
		cancel_rebind();
		return;

	# We edit the shared Godot `InputMap` in place, so gameplay and UI keep using
	# the native `Input.is_action_*` API without knowing about `InputManager`.
	var replaced_actions: Array[StringName] = [];
	for other_action_name: StringName in REBINDABLE_ACTIONS:
		if other_action_name == action_name:
			continue;
		if _can_actions_share_binding(action_name, other_action_name):
			continue;
		if not _action_has_matching_event(other_action_name, event):
			continue;
		InputMap.action_erase_event(other_action_name, event);
		replaced_actions.append(other_action_name);
		bindings_changed.emit(other_action_name);

	var updated_events: Array[InputEvent] = _build_rebound_event_list(action_name, event, _pending_rebind_slot);
	_set_action_events(action_name, updated_events);
	save_bindings();
	_pending_rebind_action = &"";
	_pending_rebind_slot = -1;
	bindings_changed.emit(action_name);
	if not replaced_actions.is_empty():
		rebind_conflicts_resolved.emit(action_name, replaced_actions);
	rebind_completed.emit(action_name);


func _can_actions_share_binding(first_action: StringName, second_action: StringName) -> bool:
	var first_conflict_group: String = _get_action_conflict_group(first_action);
	var second_conflict_group: String = _get_action_conflict_group(second_action);
	if first_conflict_group.is_empty() or second_conflict_group.is_empty():
		return false;
	# Matching groups mean "contextually compatible", for example `ui_pause`
	# and `ui_cancel` on `Escape`.
	return first_conflict_group == second_conflict_group;


func _get_action_conflict_group(action_name: StringName) -> String:
	return String(_get_action_metadata(action_name).get("conflict_group", ""));


func _get_action_metadata(action_name: StringName) -> Dictionary:
	return ACTION_METADATA.get(action_name, {});


func _build_rebound_event_list(action_name: StringName, event: InputEvent, binding_slot: int) -> Array[InputEvent]:
	var updated_events: Array[InputEvent] = _duplicate_events(get_action_events(action_name));
	var normalized_event: InputEvent = event.duplicate();
	var insert_index: int = clampi(binding_slot, 0, MAX_BINDINGS_PER_ACTION - 1);
	_remove_matching_event(updated_events, normalized_event);
	if insert_index < updated_events.size():
		updated_events[insert_index] = normalized_event;
	else:
		updated_events.append(normalized_event);
	if updated_events.size() > MAX_BINDINGS_PER_ACTION:
		updated_events.resize(MAX_BINDINGS_PER_ACTION);
	return updated_events;


func _remove_matching_event(events: Array[InputEvent], event: InputEvent) -> void:
	for event_index: int in range(events.size() - 1, -1, -1):
		if events[event_index] != null and events[event_index].is_match(event):
			events.remove_at(event_index);


func _action_has_matching_event(action_name: StringName, event: InputEvent) -> bool:
	for existing_event: InputEvent in get_action_events(action_name):
		if existing_event != null and existing_event.is_match(event):
			return true;
	return false;


func _set_action_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name);
	InputMap.action_erase_events(action_name);
	for input_event: InputEvent in events:
		if input_event == null:
			continue;
		InputMap.action_add_event(action_name, input_event);


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

	return event.as_text();


func _get_builtin_default_events(action_name: StringName) -> Array[InputEvent]:
	match action_name:
		&"ui_accept":
			return [
				_create_key_event(DEFAULT_KEY_ENTER),
				_create_key_event(DEFAULT_KEY_SPACE),
			];
		&"ui_up":
			return [
				_create_key_event(DEFAULT_KEY_UP),
				_create_key_event(DEFAULT_KEY_W),
			];
		&"ui_down":
			return [
				_create_key_event(DEFAULT_KEY_DOWN),
				_create_key_event(DEFAULT_KEY_S),
			];
		&"ui_left":
			return [
				_create_key_event(DEFAULT_KEY_LEFT),
				_create_key_event(DEFAULT_KEY_A),
			];
		&"ui_right":
			return [
				_create_key_event(DEFAULT_KEY_RIGHT),
				_create_key_event(DEFAULT_KEY_D),
			];
		&"ui_pause":
			return [_create_key_event(DEFAULT_KEY_F10)];
		&"ui_cancel":
			return [_create_key_event(DEFAULT_KEY_ESCAPE)];
		&"ui_debug_overlay":
			return [_create_key_event(DEFAULT_KEY_F3)];
		_:
			return [];


func _create_key_event(keycode: Key) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new();
	key_event.keycode = keycode;
	key_event.key_label = keycode;
	return key_event;

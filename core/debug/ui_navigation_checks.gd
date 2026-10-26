extends RefCounted;


## Synthetic pointer, keyboard and gamepad events in the isolated UI suite.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	var tree: SceneTree = host.get_tree();
	var viewport: Viewport = host.get_viewport();
	var manager: Node = tree.root.get_node("InputManager");
	var shell: Node = tree.root.get_node("UiShell");
	var menu: Control = tree.root.get_node("SceneRouter").current_scene_root as Control;
	if menu == null:
		failures.append("ui navigation: expected main menu entry point");
		return failures;
	var settings_button: Button = null;
	for node: Node in menu.find_children("*", "Button", true, false):
		var button: Button = node as Button;
		if button.text == "UI_SETTINGS":
			settings_button = button;
			break;
	if settings_button == null:
		failures.append("ui navigation: menu has no UI_SETTINGS button");
		return failures;
	var old_navigation: bool = manager.ui_navigation_active;
	var old_device: StringName = manager.last_device;
	var old_focus: Control = UiFocus.capture(viewport);
	await _click_at(host, Vector2(4, 4));
	_check(not manager.ui_navigation_active and UiFocus.capture(viewport) == null, "mouse entry retained a navigation focus", failures);
	await _key(host, KEY_W);
	_check(not manager.ui_navigation_active and UiFocus.capture(viewport) == null, "gameplay W enabled UI navigation", failures);
	await _key(host, KEY_TAB);
	var first: Control = UiFocus.capture(viewport);
	if menu is MainMenu:
		var standard_menu: MainMenu = menu as MainMenu;
		first = standard_menu.new_game_button if standard_menu.continue_button.disabled else standard_menu.continue_button;
		_check(manager.ui_navigation_active and first.has_focus(), "first Tab skipped the first available menu button", failures);
	else:
		_check(manager.ui_navigation_active and first != null and menu.is_ancestor_of(first)
			and first.is_visible_in_tree() and first.get_focus_mode_with_override() != Control.FOCUS_NONE
			and not (first is BaseButton and (first as BaseButton).disabled), "first Tab did not enter an available menu control", failures);
	await _key(host, KEY_TAB);
	_check(UiFocus.capture(viewport) != first and UiFocus.capture(viewport) != null, "second Tab did not advance", failures);
	await _key(host, KEY_TAB, true);
	_check(first != null and first.has_focus(), "Shift+Tab did not return to the previous menu item", failures);
	await _click_at(host, Vector2(4, 4));
	_check(not manager.ui_navigation_active and UiFocus.capture(viewport) == null, "mouse did not clear keyboard focus on empty space", failures);
	# Use a real menu action to cover focus acquired during GUI dispatch.
	await preload("res://core/debug/settings_ui_checks.gd").click(settings_button, host, false);
	await tree.create_timer(0.3).timeout;
	var settings: Control = shell.get_node("ModalLayer/SettingsModal");
	_check(settings.visible and UiFocus.capture(viewport) == null, "mouse-opened modal stole navigation focus", failures);
	await _key(host, KEY_TAB);
	var modal_focus: Control = UiFocus.capture(viewport);
	_check(modal_focus != null and settings.is_ancestor_of(modal_focus), "Tab did not enter mouse-opened modal", failures);
	shell.close_settings();
	await tree.create_timer(0.3).timeout;
	# Keyboard-opened modals remember and restore the exact originating control.
	settings_button.grab_focus();
	shell.open_settings();
	await tree.create_timer(0.3).timeout;
	modal_focus = UiFocus.capture(viewport);
	_check(modal_focus != null and settings.is_ancestor_of(modal_focus), "keyboard modal lost its default focus", failures);
	shell.close_settings();
	await tree.create_timer(0.3).timeout;
	_check(settings_button.has_focus(), "keyboard modal did not restore the originating button", failures);
	# A mouse click can still place a caret and typing must keep it there.
	var edit: LineEdit = LineEdit.new();
	edit.position = Vector2(20, 70);
	edit.size = Vector2(180, 36);
	menu.add_child(edit);
	await _settle(host);
	await _click_at(host, edit.get_global_rect().get_center());
	_check(edit.has_focus() and not manager.ui_navigation_active, "pointer text field lost its caret", failures);
	await _key(host, KEY_W);
	await _key(host, KEY_LEFT);
	_check(edit.has_focus() and edit.text == "w" and not manager.ui_navigation_active, "typing or caret movement enabled navigation", failures);
	var second_edit: LineEdit = LineEdit.new();
	second_edit.position = Vector2(20, 120);
	second_edit.size = Vector2(180, 36);
	menu.add_child(second_edit);
	await _settle(host);
	await _click_at(host, second_edit.get_global_rect().get_center());
	_check(second_edit.has_focus() and not edit.has_focus(), "mouse did not move caret between text fields", failures);
	await _click_at(host, Vector2(4, 4));
	_check(UiFocus.capture(viewport) == null, "click outside text field retained its caret focus", failures);
	edit.queue_free();
	second_edit.queue_free();
	await _settle(host);
	var held_button: Button = Button.new();
	held_button.position = Vector2(20, 70);
	held_button.size = Vector2(180, 36);
	menu.add_child(held_button);
	var activations: Array[bool] = [];
	held_button.pressed.connect(func() -> void: activations.append(true));
	await _settle(host);
	await _button_at(host, held_button.get_global_rect().get_center(), true);
	_check(held_button.has_focus() and activations.is_empty(), "mouse press lost its active button before release", failures);
	await _button_at(host, held_button.get_global_rect().get_center(), false);
	_check(activations.size() == 1 and not held_button.has_focus(), "mouse release canceled button activation or retained its focus", failures);
	held_button.queue_free();
	await _settle(host);
	var slider: HSlider = HSlider.new();
	slider.position = Vector2(20, 70);
	slider.size = Vector2(180, 36);
	slider.value = 50.0;
	menu.add_child(slider);
	await _settle(host);
	await _button_at(host, slider.get_global_rect().get_center(), true);
	var drag: InputEventMouseMotion = InputEventMouseMotion.new();
	drag.position = viewport.get_final_transform() * (slider.get_global_rect().position + Vector2(140, 18));
	drag.relative = Vector2(50, 0);
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT;
	viewport.push_input(drag);
	await _settle(host);
	_check(slider.has_focus() and slider.value > 50.0, "slider lost its active drag before release", failures);
	await _button_at(host, slider.get_global_rect().position + Vector2(140, 18), false);
	_check(slider.value > 50.0 and not manager.ui_navigation_active and not slider.has_focus(), "pointer slider lost input or retained its navigation frame", failures);
	slider.queue_free();
	await _settle(host);
	var gamepad: InputEventJoypadButton = InputEventJoypadButton.new();
	gamepad.button_index = JOY_BUTTON_DPAD_DOWN;
	gamepad.pressed = true;
	viewport.push_input(gamepad);
	await _settle(host);
	_check(manager.ui_navigation_active and first != null and first.has_focus(), "gamepad navigation did not enter menu", failures);
	gamepad = gamepad.duplicate();
	gamepad.pressed = false;
	viewport.push_input(gamepad);
	await _settle(host);
	shell.open_settings();
	await tree.create_timer(0.3).timeout;
	modal_focus = UiFocus.capture(viewport);
	_check(modal_focus != null and settings.is_ancestor_of(modal_focus), "gamepad modal lost its default focus", failures);
	await _click_at(host, Vector2(4, 4));
	# Backdrop may close the clean modal itself; explicit close is idempotent.
	if settings.visible:
		shell.close_settings();
	await tree.create_timer(0.3).timeout;
	_check(not manager.ui_navigation_active and UiFocus.capture(viewport) == null, "mouse close restored a stale navigation frame", failures);
	manager.ui_navigation_active = old_navigation;
	manager.last_device = old_device;
	if old_navigation:
		UiFocus.restore(old_focus);
	return failures;


static func _key(host: Node, keycode: Key, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new();
	event.keycode = keycode;
	event.physical_keycode = keycode;
	event.shift_pressed = shift;
	event.unicode = 119 if keycode == KEY_W else 0;
	event.pressed = true;
	host.get_viewport().push_input(event);
	await _settle(host);
	event = event.duplicate();
	event.pressed = false;
	host.get_viewport().push_input(event);
	await _settle(host);


static func _click_at(host: Node, position: Vector2) -> void:
	var viewport: Viewport = host.get_viewport();
	var point: Vector2 = viewport.get_final_transform() * position;
	var motion: InputEventMouseMotion = InputEventMouseMotion.new();
	motion.position = point;
	motion.relative = Vector2(4, 0);
	viewport.push_input(motion);
	await _button_at(host, position, true);
	await _button_at(host, position, false);


static func _button_at(host: Node, position: Vector2, pressed: bool) -> void:
	var viewport: Viewport = host.get_viewport();
	var event: InputEventMouseButton = InputEventMouseButton.new();
	event.position = viewport.get_final_transform() * position;
	event.button_index = MOUSE_BUTTON_LEFT;
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0;
	event.pressed = pressed;
	viewport.push_input(event);
	await _settle(host);


static func _settle(host: Node) -> void:
	for frame: int in range(3):
		await host.get_tree().process_frame;


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ui navigation: " + message);

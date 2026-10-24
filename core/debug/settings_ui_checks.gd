extends RefCounted;


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	var tree: SceneTree = host.get_tree();
	var shell: Node = tree.root.get_node("UiShell");
	var locale_manager: Node = tree.root.get_node("LocalizationManager");
	var old_locale: String = locale_manager.get_current_locale();
	tree.root.get_node("AppFlow").open_settings();
	await tree.create_timer(0.3).timeout;
	var settings: Node = shell.get_node("ModalLayer/SettingsModal");
	var stack: Node = shell.get_node("ToastLayer/ToastMargin/ToastStack");
	_check(stack.get_child_count() == 0, "pointer check requires an empty toast area", failures);
	settings.settings_tabs.set_current_tab(0);
	await _settle(host);
	await _check_toggle(settings.autosave_enabled_check_box, host, failures);
	settings.settings_tabs.set_current_tab(1);
	await _settle(host);
	await _check_toggle(settings.fullscreen_check_box, host, failures);
	await _check_toggle(settings.vsync_check_box, host, failures);
	tree.root.get_node("UiFeedback").toast("Pointer regression", {"duration": 30.0});
	await tree.create_timer(0.3).timeout;
	_check(stack.get_child_count() == 1, "toast did not appear", failures);
	if stack.get_child_count() == 1:
		await click(stack.get_child(0).get_node("%DismissButton"), host);
		_check(stack.get_child_count() == 0, "toast dismiss lost pointer input", failures);
	await _check_toggle(settings.fullscreen_check_box, host, failures);
	for locale: String in ["ru", "en"]:
		locale_manager.set_locale(locale, false);
		settings.settings_tabs.set_current_tab(2);
		await _settle(host);
		check_binding_layout(settings, failures);
		var action: Variant = settings._binding_buttons.keys().front();
		var button: Button = settings._binding_buttons[action][0];
		var previous_width: float = button.size.x;
		tree.root.get_node("InputManager").start_rebind(action, 0);
		await _settle(host);
		check_binding_layout(settings, failures);
		tree.root.get_node("InputManager").cancel_rebind();
		await _settle(host);
		_check(absf(button.size.x - previous_width) <= 1.0, "binding width accumulated after cancel", failures);
	locale_manager.set_locale(old_locale, false);
	settings._sync_from_settings();
	settings.request_close();
	await tree.create_timer(0.3).timeout;
	return failures;


static func check_binding_layout(settings: Node, failures: Array[String]) -> void:
	var columns: Array[float] = [];
	var scroll: ScrollContainer = settings.bindings_container.get_parent();
	var scrollbar: VScrollBar = scroll.get_v_scroll_bar();
	for buttons: Array in settings._binding_buttons.values():
		for slot: int in range(buttons.size()):
			var button: Button = buttons[slot];
			var rect: Rect2 = button.get_global_rect();
			if columns.size() <= slot:
				columns.append(rect.position.x);
			_check(absf(rect.position.x - columns[slot]) <= 1.0, "binding columns depend on caption width", failures);
			_check(rect.end.x <= scroll.get_global_rect().end.x + 1.0, "binding is clipped horizontally", failures);
			if scrollbar.is_visible_in_tree():
				_check(rect.end.x <= scrollbar.get_global_rect().position.x - scroll.get_theme_constant("scrollbar_h_separation") + 1.0,
					"binding overlaps the scrollbar gap", failures);
	_check(scroll.get_theme_constant("scrollbar_h_separation") > 0, "scrollbar touches binding content", failures);
	var last_action: Variant = settings._binding_buttons.keys().back();
	var last_button: Button = settings._binding_buttons[last_action][1];
	var visible_rect: Rect2 = scroll.get_global_rect();
	if last_button.has_focus():
		_check(last_button.get_global_rect().position.y >= visible_rect.position.y - 1.0
			and last_button.get_global_rect().end.y <= visible_rect.end.y + 1.0, "last binding is outside scroll view", failures);


static func _check_toggle(button: BaseButton, host: Node, failures: Array[String]) -> void:
	var before: bool = button.button_pressed;
	await click(button, host);
	_check(button.button_pressed != before, "%s did not receive a coordinate click" % button.name, failures);
	await click(button, host);
	_check(button.button_pressed == before, "%s did not toggle back" % button.name, failures);


static func click(control: Control, host: Node, focus_before_click: bool = true) -> void:
	if focus_before_click:
		control.grab_focus();
	await _settle(host);
	var viewport: Viewport = control.get_viewport();
	var position: Vector2 = viewport.get_final_transform() * control.get_global_rect().get_center();
	var motion: InputEventMouseMotion = InputEventMouseMotion.new();
	motion.position = position;
	viewport.push_input(motion);
	await host.get_tree().process_frame;
	var event: InputEventMouseButton = InputEventMouseButton.new();
	event.position = position;
	event.button_index = MOUSE_BUTTON_LEFT;
	event.button_mask = MOUSE_BUTTON_MASK_LEFT;
	event.pressed = true;
	viewport.push_input(event);
	await host.get_tree().process_frame;
	event = event.duplicate();
	event.pressed = false;
	event.button_mask = 0;
	viewport.push_input(event);
	await _settle(host);


static func _settle(host: Node) -> void:
	for frame: int in range(6):
		await host.get_tree().process_frame;


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("settings ui: " + message);

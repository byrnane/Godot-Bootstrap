extends RefCounted;

## UI contracts, exercised through the isolated smoke wrapper.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	var freed_focus: Variant = Button.new();
	freed_focus.free();
	_check(not UiFocus.restore(freed_focus), "closing modal restored a freed scene control", failures);
	var mount: Control = Control.new();
	host.add_child(mount);
	var focus_button: Button = Button.new();
	mount.add_child(focus_button);
	mount.hide();
	_check(not UiFocus.restore(focus_button), "focus restored a control under a hidden parent", failures);
	mount.show();
	mount.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED;
	_check(not UiFocus.restore(focus_button), "focus restored a recursively blocked control", failures);
	mount.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED;
	var resources: UiResources = load("res://shared/ui/components/ui_resources.tscn").instantiate();
	mount.add_child(resources);
	resources.apply_resources({"health": 150.0, "max_health": 100.0, "mana": -20.0});
	var health: UiResourceBar = resources.get_node("Margin/Bars/HealthBar");
	var mana: UiResourceBar = resources.get_node("Margin/Bars/ManaBar");
	_check(health.get_node("%Bar").value == 100.0, "resource overflow was not clamped", failures);
	_check(mana.get_node("%Bar").value == 0.0, "negative resource was not clamped", failures);
	_check(not resources.get_node("Margin/Bars/StaminaBar").visible, "absent resource must be hidden", failures);
	health.set_amount(10.0, 0.0);
	_check(health.get_node("%Value").text == "0 / 0", "zero capacity must remain finite", failures);
	# A second skin changes rendering through inheritance without component edits.
	var replacement: Theme = load("res://shared/ui/theme/neutral_theme.tres").duplicate(true);
	var fill: StyleBoxFlat = StyleBoxFlat.new();
	fill.bg_color = Color.MAGENTA;
	replacement.set_stylebox("fill", "UiHealthBar", fill);
	mount.theme = replacement;
	await host.get_tree().process_frame;
	_check(health.get_node("%Bar").get_theme_stylebox("fill") == fill, "resource froze the old skin", failures);
	var themed_button: UiButton = UiButton.new();
	themed_button.icon_role = &"pause";
	mount.add_child(themed_button);
	_check(themed_button.icon == replacement.get_icon("pause", "UiIcons"), "button did not resolve its semantic icon", failures);
	var custom_button: UiButton = UiButton.new();
	custom_button.icon = replacement.get_icon("coin", "UiIcons");
	mount.add_child(custom_button);
	_check(custom_button.icon == replacement.get_icon("coin", "UiIcons"), "button lost its custom icon without a semantic role", failures);
	themed_button.icon_role = &"";
	_check(themed_button.icon == null, "cleared semantic role retained its icon", failures);
	var counter: UiCounter = load("res://shared/ui/components/ui_counter.tscn").instantiate();
	counter.icon = replacement.get_icon("clock", "UiIcons");
	counter.icon_role = &"coin";
	mount.add_child(counter);
	_check(counter.get_node("%Icon").texture == replacement.get_icon("coin", "UiIcons"), "counter ignored its semantic icon", failures);
	var changed_icon: Texture2D = replacement.get_icon("crystal", "UiIcons");
	replacement.set_icon("coin", "UiIcons", changed_icon);
	await host.get_tree().process_frame;
	_check(counter.get_node("%Icon").texture == changed_icon, "counter froze its old theme icon", failures);
	counter.icon_role = &"";
	_check(counter.get_node("%Icon").texture == counter.icon, "counter lost its custom icon fallback", failures);
	var binding: UiBindingRow = load("res://shared/ui/components/ui_binding_row.tscn").instantiate();
	mount.add_child(binding);
	var requested: Array[int] = [];
	binding.binding_requested.connect(func(slot: int) -> void: requested.append(slot));
	binding.get_binding_buttons()[1].pressed.emit();
	_check(requested == [1], "binding row lost its secondary slot intent", failures);
	var objective: UiTextPanel = load("res://shared/ui/components/ui_objective.tscn").instantiate();
	mount.add_child(objective);
	_check(not objective.caption_key.is_empty() and objective.get_node("%Caption").visible, "objective lost its exported caption", failures);
	var result: UiResultContent = load("res://shared/ui/components/ui_result_content.tscn").instantiate();
	mount.add_child(result);
	result.configure("one", "", {"score": 10, "time": 20}, "next", "menu");
	result.configure("two", "", {"score": 30}, "retry", "menu");
	_check(result.get_node("%Metrics").get_child_count() == 1, "result retained previous metrics", failures);
	mount.queue_free();
	await host.get_tree().process_frame;
	failures.append_array(await preload("res://core/debug/settings_ui_checks.gd").run(host));
	await _check_screen_actions(host, failures);
	failures.append_array(await preload("res://core/debug/compact_ui_checks.gd").run(host));
	return failures;


static func _check_screen_actions(host: Node, failures: Array[String]) -> void:
	var tree: SceneTree = host.get_tree();
	var flow: Node = tree.root.get_node("AppFlow");
	var shell: Node = tree.root.get_node("UiShell");
	var input_manager: Node = tree.root.get_node("InputManager");
	var app: Node = tree.root.get_node("AppContext");
	var old_volume: float = app.settings.master_volume;
	flow.open_settings();
	await tree.create_timer(0.3).timeout;
	var settings: Node = shell.get_node("ModalLayer/SettingsModal");
	settings.settings_tabs.set_current_tab(2);
	await tree.process_frame;
	var last_action: Variant = settings._binding_buttons.keys().back();
	await _check_scrolled_focus(host, settings._binding_buttons[last_action][1], settings.bindings_container.get_parent(), failures);
	# Rebuilt rows must preserve every action's two-slot binding ownership.
	for action: Variant in settings._binding_buttons:
		settings._binding_buttons[action][1].pressed.emit();
		_check(input_manager.get_pending_rebind_action() == action, "binding row dispatched another action", failures);
		input_manager.cancel_rebind();
	settings.master_volume_slider.value = 0.37 if old_volume != 0.37 else 0.42;
	settings.request_close();
	await tree.create_timer(0.3).timeout;
	var feedback: Node = shell.get_node("ModalLayer/FeedbackModal");
	_check(feedback.visible and settings.visible, "dirty close did not ask to discard", failures);
	feedback.request_close();
	await tree.create_timer(0.3).timeout;
	_check(settings.visible and not feedback.visible, "cancel discard lost settings context", failures);
	settings.request_close();
	await tree.create_timer(0.3).timeout;
	feedback.get_node("%ConfirmButton").pressed.emit();
	for frame: int in range(120):
		await tree.process_frame;
		if not settings.visible:
			break;
	_check(not settings.visible and is_equal_approx(app.settings.master_volume, old_volume), "discard applied draft settings", failures);
	flow.start_new_game();
	await _wait_for_route(host);
	flow.open_save_slots();
	await tree.create_timer(0.3).timeout;
	var saves: Node = shell.get_node("ModalLayer/SaveSlotsModal");
	saves.set_mode(&"save");
	var last_slot: Button;
	for index: int in range(8):
		last_slot = load("res://shared/ui/components/ui_save_slot.tscn").instantiate();
		last_slot.title = "Focus check " + str(index);
		saves.slot_list.add_child(last_slot);
	await tree.process_frame;
	await _check_scrolled_focus(host, last_slot, saves.slot_list.get_parent(), failures);
	saves._reload_entries();
	# The wrapper uses a fresh profile; creating a first slot must enable overwrite.
	saves.get_node("%NewSlotButton").pressed.emit();
	await tree.process_frame;
	_check(not saves._get_selected_entry().is_empty(), "new slot was not selected", failures);
	_check(not saves.get_node("%SaveButton").disabled, "save stayed disabled after first slot appeared", failures);
	var first_key: String = saves._get_selected_entry().get("slot_key", "");
	saves.get_node("%TitleLineEdit").text = "second slot";
	saves.get_node("%NewSlotButton").pressed.emit();
	await tree.process_frame;
	_check(saves._get_selected_entry().get("slot_key", "") != first_key, "new slot left the old slot selected", failures);
	await preload("res://core/debug/settings_ui_checks.gd").click(saves.get_node("%SaveButton"), host);
	await tree.create_timer(0.3).timeout;
	_check(feedback.visible, "overwrite confirmation did not open", failures);
	var pending_descriptor: Dictionary = saves.get("_pending_descriptor").duplicate(true);
	var delete_button: Button = saves.get_node("%DeleteButton");
	_check(delete_button.get_focus_mode_with_override() == Control.FOCUS_NONE, "covered modal retained keyboard focus", failures);
	await preload("res://core/debug/settings_ui_checks.gd").click(delete_button, host, false);
	_check(saves.get("_pending_action") == &"save_selected" and saves.get("_pending_descriptor") == pending_descriptor,
		"covered modal changed the action being confirmed", failures);
	feedback.request_close();
	await tree.create_timer(0.3).timeout;
	_check(delete_button.get_focus_mode_with_override() != Control.FOCUS_NONE, "uncovered modal did not regain focus", failures);
	# Discard queued requests from a failed regression before continuing the suite.
	shell.close_all_modals();
	await tree.create_timer(0.3).timeout;
	shell.open_save_slots(&"load");
	await tree.create_timer(0.3).timeout;
	saves.set_mode(&"load");
	_check(not saves.get_node("%LoadButton").disabled, "load mode lost selected slot", failures);
	_check(not saves.get_node("%SaveButton").visible, "load mode exposes overwrite action", failures);
	saves.request_close();
	await tree.create_timer(0.3).timeout;
	flow.return_to_main_menu();
	await _wait_for_route(host);
	var menu: Node = tree.root.get_node("SceneRouter").current_scene_root;
	if menu is MainMenu:
		_check(not menu.continue_button.disabled, "menu lost Continue while saves exist", failures);
		tree.root.get_node("SaveManager").clear_all_saves();
		_check(menu.continue_button.disabled, "menu retained Continue after the last save was removed", failures);
	var debug: Node = shell.get("_debug_overlay");
	var option: OptionButton = debug.scene_option_button;
	var target: int = (option.selected + 1) % option.item_count;
	option.select(target);
	shell._refresh_debug_overlay();
	_check(option.selected == target, "debug refresh discarded the selected jump target", failures);


static func _wait_for_route(host: Node) -> void:
	var router: Node = host.get_tree().root.get_node("SceneRouter");
	for frame: int in range(600):
		await host.get_tree().process_frame;
		if not router.is_loading():
			return;


static func _check_scrolled_focus(host: Node, button: Control, scroll: ScrollContainer, failures: Array[String]) -> void:
	button.grab_focus();
	await host.get_tree().process_frame;
	await host.get_tree().process_frame;
	var visible_area: Rect2 = scroll.get_global_rect();
	var focused_area: Rect2 = button.get_global_rect();
	_check(focused_area.position.y >= visible_area.position.y - 1.0 and focused_area.end.y <= visible_area.end.y + 1.0,
		"keyboard focus left the visible scroll area", failures);


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ui: " + message);


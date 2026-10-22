extends RefCounted;

## Exercise real shared screens in a low-resolution viewport, without changing player data.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	var viewport: SubViewport = SubViewport.new();
	viewport.size = Vector2i(640, 360);
	host.add_child(viewport);
	var actions: UiActionBar = load("res://shared/ui/components/ui_action_bar.tscn").instantiate();
	actions.size = Vector2(600, 40);
	var action: Button = Button.new();
	action.custom_minimum_size = Vector2(80, 32);
	actions.add_child(action);
	viewport.add_child(actions);
	for alignment: String in ["start", "center", "end"]:
		actions.content_alignment = alignment;
		await _settle(host);
		var available: float = actions.size.x - action.size.x;
		var expected_x: float = 0.0 if alignment == "start" else (available / 2.0 if alignment == "center" else available);
		if absf(action.get_global_rect().position.x - expected_x) > 1.0:
			failures.append("compact: action bar ignored " + alignment + " alignment");
	actions.queue_free();
	await _settle(host);
	var old_locale: String = LocalizationManager.get_current_locale();
	for locale: String in ["ru", "en"]:
		LocalizationManager.set_locale(locale, false);
		var settings: Control = load("res://features/ui/modals/settings_modal.tscn").instantiate();
		viewport.add_child(settings);
		settings.show();
		await _settle(host);
		for tab: Control in settings.settings_tabs.tabs_container.get_children():
			if tab.theme_type_variation != &"UiTabItem" or tab.alignment != HORIZONTAL_ALIGNMENT_CENTER:
				failures.append("compact: horizontal tab retained sidebar styling");
		for index: int in range(3):
			settings.settings_tabs.set_current_tab(index);
			await _settle(host);
			_check_bounds(settings.get_node("%CloseButton"), failures);
			_check_bounds(settings.get_node("%ApplyButton"), failures);
			_check_bounds(settings.get_node("%ResetButton"), failures);
			for tab: Control in settings.settings_tabs.tabs_container.get_children():
				_check_bounds(tab, failures);
		var last_action: Variant = settings._binding_buttons.keys().back();
		var binding: Control = settings._binding_buttons[last_action][1];
		binding.grab_focus();
		await _settle(host);
		_check_bounds(binding, failures);
		preload("res://core/debug/settings_ui_checks.gd").check_binding_layout(settings, failures);
		settings.queue_free();
		await _settle(host);
		var saves: Control = load("res://features/ui/modals/save_slots_modal.tscn").instantiate();
		viewport.add_child(saves);
		saves.show();
		for mode: StringName in [&"save", &"load"]:
			saves.set_mode(mode);
			await _settle(host);
			for name: String in ["CloseButton", "NewSlotButton", "QuickSaveButton", "RefreshButton", "LoadButton", "DeleteButton", "SaveButton"]:
				var button: Control = saves.get_node("%" + name);
				if button.is_visible_in_tree():
					_check_bounds(button, failures);
		var last_slot: Button;
		for index: int in range(12):
			last_slot = load("res://shared/ui/components/ui_save_slot.tscn").instantiate();
			last_slot.title = "Long save list " + str(index);
			saves.slot_list.add_child(last_slot);
		await _settle(host);
		last_slot.grab_focus();
		await _settle(host);
		_check_bounds(last_slot, failures);
		saves.queue_free();
		await _settle(host);
		for path: String in ["res://features/main_menu/main_menu.tscn", "res://features/gameplay/gameplay_hud.tscn", "res://features/ui/modals/pause_modal.tscn", "res://shared/ui/feedback/feedback_modal.tscn", "res://shared/ui/catalog/ui_catalog.tscn"]:
			var screen: Control = load(path).instantiate();
			viewport.add_child(screen);
			screen.show();
			if screen is FeedbackModal:
				screen.configure_confirm(1, {"title": "Confirmation", "message": "Long confirmation message to verify wrapping and reachable actions in the compact viewport."});
			await _settle(host);
			if screen is MainMenu:
				for button: Button in screen._collect_focusable_buttons():
					_check_bounds(button, failures);
			elif screen is GameplayHud:
				screen.apply_view_model({"health": 100, "mana": 50, "stamina": 30, "score": 123, "objective": "Objective", "interaction_text": "Interact", "time_text": "00:30"});
				await _settle(host);
				_check_bounds(screen.get_node("%PauseButton"), failures);
				_check_bounds(screen.get_node("%Resources"), failures);
				if screen.get_node("%Objective").get_global_rect().intersects(screen.get_node("%Interaction").get_global_rect()):
					failures.append("compact: objective overlaps interaction prompt");
				screen.get_node("%DemoToggle").button_pressed = true;
				await _settle(host);
				_check_bounds(screen.get_node("%DemoPanel"), failures);
				for button_name: String in ["DamageButton", "HealButton", "ScoreButton", "LevelAButton", "LevelBButton"]:
					_check_bounds(screen.get_node("%" + button_name), failures);
			elif screen is BaseModal:
				_check_bounds(screen, failures);
				if screen is FeedbackModal:
					_check_bounds(screen.confirm_button, failures);
					_check_bounds(screen.cancel_button, failures);
			screen.queue_free();
			await _settle(host);
	LocalizationManager.set_locale(old_locale, false);
	viewport.queue_free();
	await _settle(host);
	return failures;


static func _settle(host: Node) -> void:
	for frame: int in range(6):
		await host.get_tree().process_frame;


static func _check_bounds(control: Control, failures: Array[String]) -> void:
	if not Rect2(-1, -1, 642, 362).encloses(control.get_global_rect()):
		failures.append("compact: %s is outside viewport: %s" % [control.name, control.get_global_rect()]);

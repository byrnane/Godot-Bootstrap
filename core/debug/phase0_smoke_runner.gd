extends Node;


const LOAD_TIMEOUT_SECONDS: float = 8.0;
const STATE_TIMEOUT_SECONDS: float = 4.0;
const TRANSITION_DELAY_SECONDS: float = 2.0;
const CYCLE_COUNT: int = 2;
const RESULT_PATH: String = "user://phase0_smoke_result.txt";
const MIN_CONTRAST_RATIO: float = 4.5;
const MIN_CONTRAST_RATIO_DISABLED: float = 2.5;
const CONTRAST_BASE_BACKGROUND: Color = Color(0.03, 0.04, 0.06, 1.0);


@onready var scene_root: Node = $SceneRoot;


var _failures: Array[String] = [];


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	SceneRouter.configure(scene_root);
	call_deferred("_run");


func _run() -> void:
	await get_tree().process_frame;
	await _expect_transition(
		Callable(AppFlow, "startup"),
		Scenes.MAIN_MENU,
		AppState.Value.MAIN_MENU,
		"startup to main menu"
	);
	_check_localization_coverage();
	await _expect_locale_switch_updates_shared_components();
	_validate_main_menu_focus_navigation();
	_check_default_theme_contrast();

	for cycle_index: int in range(CYCLE_COUNT):
		var cycle_number: int = cycle_index + 1;
		await _expect_transition(
			Callable(AppFlow, "start_new_game"),
			Scenes.GAMEPLAY,
			AppState.Value.IN_GAME,
			"cycle %d: start new game" % [cycle_number]
		);
		_check(not get_tree().paused, "cycle %d: tree should not stay paused after gameplay load" % [cycle_number]);
		_validate_gameplay_hud_focus_navigation(cycle_number);

		AppFlow.request_pause();
		var paused_state_reached: bool = await _wait_until(
			func() -> bool:
				return AppContext.state == AppState.Value.PAUSED and get_tree().paused,
			STATE_TIMEOUT_SECONDS
		);
		_check(paused_state_reached, "cycle %d: pause request did not set PAUSED state" % [cycle_number]);
		_validate_pause_modal_focus_navigation(cycle_number);

		AppFlow.open_settings();
		await get_tree().process_frame;
		_check(get_tree().paused, "cycle %d: settings open should keep paused tree" % [cycle_number]);
		await _expect_backdrop_behavior_while_paused(cycle_number);

		AppFlow.request_resume();
		var resumed_state_reached: bool = await _wait_until(
			func() -> bool:
				return AppContext.state == AppState.Value.IN_GAME and not get_tree().paused,
			STATE_TIMEOUT_SECONDS
		);
		_check(resumed_state_reached, "cycle %d: resume request did not restore IN_GAME state" % [cycle_number]);

		var save_success: bool = SaveManager.save_current_session();
		_check(save_success, "cycle %d: failed to save current session" % [cycle_number]);

		await _expect_transition(
			Callable(AppFlow, "return_to_main_menu"),
			Scenes.MAIN_MENU,
			AppState.Value.MAIN_MENU,
			"cycle %d: return to menu" % [cycle_number]
		);

		await _expect_transition(
			Callable(AppFlow, "continue_game"),
			Scenes.GAMEPLAY,
			AppState.Value.IN_GAME,
			"cycle %d: continue game" % [cycle_number]
		);

		await _expect_transition(
			Callable(AppFlow, "return_to_main_menu"),
			Scenes.MAIN_MENU,
			AppState.Value.MAIN_MENU,
			"cycle %d: return to menu after continue" % [cycle_number]
		);

	await _expect_pause_ignored_during_transition();
	await _expect_feedback_modal_backdrop_behavior();
	_finish();


func _expect_transition(action: Callable, expected_scene_id: StringName, expected_state: AppState.Value, label: String) -> void:
	if action.is_valid():
		action.call();

	var loading_seen: bool = await _wait_until(
		func() -> bool:
			return AppContext.state == AppState.Value.LOADING or SceneRouter.is_loading(),
		TRANSITION_DELAY_SECONDS
	);
	_check(loading_seen, "%s: loading state was not observed" % [label]);

	var target_scene_reached: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.current_scene_id == expected_scene_id and not SceneRouter.is_loading(),
		LOAD_TIMEOUT_SECONDS
	);
	_check(target_scene_reached, "%s: expected scene '%s' was not reached" % [label, String(expected_scene_id)]);
	_check(AppContext.state == expected_state, "%s: app state mismatch after transition" % [label]);
	_check(not TransitionManager.is_active(), "%s: transition manager still active" % [label]);
	_check(not get_tree().paused, "%s: tree remained paused after transition" % [label]);


func _expect_pause_ignored_during_transition() -> void:
	AppFlow.start_new_game();
	AppFlow.request_pause();

	var gameplay_reached: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.current_scene_id == Scenes.GAMEPLAY and not SceneRouter.is_loading(),
		LOAD_TIMEOUT_SECONDS
	);
	_check(gameplay_reached, "pause during transition test: gameplay scene was not reached");
	_check(AppContext.state == AppState.Value.IN_GAME, "pause during transition test: app state should be IN_GAME");
	_check(not get_tree().paused, "pause during transition test: tree should end unpaused");

	await _expect_transition(
		Callable(AppFlow, "return_to_main_menu"),
		Scenes.MAIN_MENU,
		AppState.Value.MAIN_MENU,
		"pause during transition test: return to menu"
	);


func _expect_backdrop_behavior_while_paused(cycle_number: int) -> void:
	var settings_modal: BaseModal = UiShell.get_node_or_null("ModalLayer/SettingsModal") as BaseModal;
	var pause_modal: BaseModal = UiShell.get_node_or_null("ModalLayer/PauseModal") as BaseModal;
	_check(settings_modal != null, "cycle %d: settings modal node is missing" % [cycle_number]);
	_check(pause_modal != null, "cycle %d: pause modal node is missing" % [cycle_number]);
	if settings_modal == null or pause_modal == null:
		return;

	_check(not pause_modal.can_close_from_backdrop(), "cycle %d: pause modal should not close from backdrop" % [cycle_number]);
	_check(settings_modal.can_close_from_backdrop(), "cycle %d: settings modal should close from backdrop" % [cycle_number]);

	var settings_visible: bool = await _wait_until(
		func() -> bool:
			return settings_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(settings_visible, "cycle %d: settings modal did not open" % [cycle_number]);
	if not settings_visible:
		return;

	_click_modal_backdrop();
	var settings_closed: bool = await _wait_until(
		func() -> bool:
			return not settings_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(settings_closed, "cycle %d: settings modal did not close from backdrop click" % [cycle_number]);
	_check(pause_modal.visible, "cycle %d: pause modal should remain visible after settings closes from backdrop" % [cycle_number]);

	_click_modal_backdrop();
	await get_tree().process_frame;
	_check(pause_modal.visible, "cycle %d: pause modal should ignore backdrop close" % [cycle_number]);


func _expect_feedback_modal_backdrop_behavior() -> void:
	var feedback_modal: FeedbackModal = UiShell.get_node_or_null("ModalLayer/FeedbackModal") as FeedbackModal;
	_check(feedback_modal != null, "feedback modal test: feedback modal node is missing");
	if feedback_modal == null:
		return;

	UiFeedback.confirm("smoke confirm", Callable(), Callable(), {"close_on_backdrop": false});
	var confirm_visible: bool = await _wait_until(
		func() -> bool:
			return feedback_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(confirm_visible, "feedback modal test: confirm dialog did not open");
	if not confirm_visible:
		return;

	_click_modal_backdrop();
	await get_tree().process_frame;
	_check(feedback_modal.visible, "feedback modal test: confirm dialog should ignore backdrop when close_on_backdrop=false");
	feedback_modal.request_close();
	var confirm_closed: bool = await _wait_until(
		func() -> bool:
			return not feedback_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(confirm_closed, "feedback modal test: confirm dialog did not close after request_close");

	UiFeedback.alert("smoke alert", Callable(), {"close_on_backdrop": true});
	var alert_visible: bool = await _wait_until(
		func() -> bool:
			return feedback_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(alert_visible, "feedback modal test: alert dialog did not open");
	if not alert_visible:
		return;

	_click_modal_backdrop();
	var alert_closed: bool = await _wait_until(
		func() -> bool:
			return not feedback_modal.visible,
		STATE_TIMEOUT_SECONDS
	);
	_check(alert_closed, "feedback modal test: alert dialog did not close from backdrop click");


func _click_modal_backdrop() -> void:
	var click_event: InputEventMouseButton = InputEventMouseButton.new();
	click_event.button_index = MOUSE_BUTTON_LEFT;
	click_event.pressed = true;
	UiShell.call("_on_modal_backdrop_gui_input", click_event);


func _check_localization_coverage() -> void:
	var report: Dictionary = LocalizationManager.get_static_key_coverage_report();
	var is_complete: bool = bool(report.get("complete", false));
	if is_complete:
		return;
	var missing_by_locale: Dictionary = report.get("missing_by_locale", {}) as Dictionary;
	_check(false, "localization coverage check failed: %s" % [JSON.stringify(missing_by_locale)]);


func _check_default_theme_contrast() -> void:
	var theme: Theme = load("res://shared/ui/theme/scifi_dark_theme.tres") as Theme;
	_check(theme != null, "contrast test: failed to load default theme");
	if theme == null:
		return;

	_assert_theme_contrast(theme, "Button normal", "Button", "font_color", "normal", MIN_CONTRAST_RATIO);
	_assert_theme_contrast(theme, "Button hover", "Button", "font_hover_color", "hover", MIN_CONTRAST_RATIO);
	_assert_theme_contrast(theme, "Button pressed", "Button", "font_pressed_color", "pressed", MIN_CONTRAST_RATIO);
	_assert_theme_contrast(theme, "Button disabled", "Button", "font_disabled_color", "disabled", MIN_CONTRAST_RATIO_DISABLED);
	_assert_theme_contrast(theme, "Input normal", "LineEdit", "font_color", "normal", MIN_CONTRAST_RATIO);
	_assert_theme_contrast(theme, "Input placeholder", "LineEdit", "font_placeholder_color", "normal", MIN_CONTRAST_RATIO_DISABLED);
	_assert_theme_contrast(theme, "Tab selected", "TabBar", "font_selected_color", "tab_selected", MIN_CONTRAST_RATIO);
	_assert_theme_contrast(theme, "Tab unselected", "TabBar", "font_unselected_color", "tab_unselected", MIN_CONTRAST_RATIO_DISABLED);
	_assert_theme_color_on_style(
		theme,
		"Panel label",
		"Label",
		"font_color",
		"PanelContainer",
		"panel",
		MIN_CONTRAST_RATIO
	);


func _validate_main_menu_focus_navigation() -> void:
	var main_menu: MainMenu = SceneRouter.current_scene_root as MainMenu;
	_check(main_menu != null, "focus test: main menu scene root is missing");
	if main_menu == null:
		return;
	var focusable_buttons: Array[Button] = [];
	for button_name: String in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var button: Button = main_menu.get_node_or_null("MarginContainer/VBoxContainer/MenuCard/ContentMargin/Content/%s" % [button_name]) as Button;
		if button == null:
			continue;
		if button.disabled:
			continue;
		focusable_buttons.append(button);
	_assert_vertical_focus_cycle(focusable_buttons, "focus test: main menu");


func _validate_gameplay_hud_focus_navigation(cycle_number: int) -> void:
	var hud: GameplayHud = UiShell.get_current_hud() as GameplayHud;
	_check(hud != null, "cycle %d: focus test: gameplay HUD is missing" % [cycle_number]);
	if hud == null:
		return;
	var buttons: Array[Button] = [];
	for button_name: String in ["DamageButton", "HealButton", "ScoreButton", "LevelAButton", "LevelBButton", "PauseButton"]:
		var button: Button = hud.get_node_or_null("%%%s" % [button_name]) as Button;
		if button == null:
			continue;
		buttons.append(button);
	_assert_vertical_focus_cycle(buttons, "cycle %d: focus test: gameplay HUD" % [cycle_number]);


func _validate_pause_modal_focus_navigation(cycle_number: int) -> void:
	var pause_modal: PauseModal = UiShell.get_node_or_null("ModalLayer/PauseModal") as PauseModal;
	_check(pause_modal != null, "cycle %d: focus test: pause modal is missing" % [cycle_number]);
	if pause_modal == null:
		return;
	var buttons: Array[Button] = [];
	for button_name: String in ["ResumeButton", "SaveButton", "SettingsButton", "BackButton"]:
		var button: Button = pause_modal.get_node_or_null(
			"MarginContainer/VBoxContainer/BodyScroll/BodyContentMargin/Body/PauseActionsCard/ContentMargin/Content/%s" % [button_name]
		) as Button;
		if button == null:
			continue;
		buttons.append(button);
	_assert_vertical_focus_cycle(buttons, "cycle %d: focus test: pause modal" % [cycle_number]);


func _assert_vertical_focus_cycle(buttons: Array[Button], label: String) -> void:
	_check(buttons.size() > 1, "%s: not enough focusable buttons for cycle" % [label]);
	if buttons.size() <= 1:
		return;
	for button_index: int in range(buttons.size()):
		var current_button: Button = buttons[button_index];
		var previous_button: Button = buttons[(button_index - 1 + buttons.size()) % buttons.size()];
		var next_button: Button = buttons[(button_index + 1) % buttons.size()];
		var expected_top: NodePath = current_button.get_path_to(previous_button);
		var expected_bottom: NodePath = current_button.get_path_to(next_button);
		_check(
			current_button.focus_neighbor_top == expected_top,
			"%s: invalid top focus neighbor for '%s'" % [label, current_button.name]
		);
		_check(
			current_button.focus_neighbor_bottom == expected_bottom,
			"%s: invalid bottom focus neighbor for '%s'" % [label, current_button.name]
		);


func _assert_theme_contrast(
	theme: Theme,
	label: String,
	type_name: String,
	font_color_name: String,
	background_style_name: String,
	minimum_ratio: float
) -> void:
	var foreground: Color = theme.get_color(font_color_name, type_name);
	var style_box: StyleBoxFlat = theme.get_stylebox(background_style_name, type_name) as StyleBoxFlat;
	_check(style_box != null, "contrast test: missing stylebox '%s/%s'" % [type_name, background_style_name]);
	if style_box == null:
		return;
	var background: Color = _flatten_color(style_box.bg_color, CONTRAST_BASE_BACKGROUND);
	var ratio: float = _contrast_ratio(_flatten_color(foreground, background), background);
	_check(
		ratio >= minimum_ratio,
		"contrast test: %s ratio %.2f is below %.2f" % [label, ratio, minimum_ratio]
	);


func _assert_theme_color_on_style(
	theme: Theme,
	label: String,
	color_type_name: String,
	font_color_name: String,
	style_type_name: String,
	background_style_name: String,
	minimum_ratio: float
) -> void:
	var foreground: Color = theme.get_color(font_color_name, color_type_name);
	var style_box: StyleBoxFlat = theme.get_stylebox(background_style_name, style_type_name) as StyleBoxFlat;
	_check(style_box != null, "contrast test: missing stylebox '%s/%s'" % [style_type_name, background_style_name]);
	if style_box == null:
		return;
	var background: Color = _flatten_color(style_box.bg_color, CONTRAST_BASE_BACKGROUND);
	var ratio: float = _contrast_ratio(_flatten_color(foreground, background), background);
	_check(
		ratio >= minimum_ratio,
		"contrast test: %s ratio %.2f is below %.2f" % [label, ratio, minimum_ratio]
	);


func _flatten_color(color: Color, background: Color) -> Color:
	var alpha: float = clampf(color.a, 0.0, 1.0);
	var inverse_alpha: float = 1.0 - alpha;
	return Color(
		color.r * alpha + background.r * inverse_alpha,
		color.g * alpha + background.g * inverse_alpha,
		color.b * alpha + background.b * inverse_alpha,
		1.0
	);


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance: float = _relative_luminance(first);
	var second_luminance: float = _relative_luminance(second);
	var lighter: float = maxf(first_luminance, second_luminance);
	var darker: float = minf(first_luminance, second_luminance);
	return (lighter + 0.05) / (darker + 0.05);


func _relative_luminance(color: Color) -> float:
	var red: float = _to_linear_channel(color.r);
	var green: float = _to_linear_channel(color.g);
	var blue: float = _to_linear_channel(color.b);
	return red * 0.2126 + green * 0.7152 + blue * 0.0722;


func _to_linear_channel(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92;
	return pow((channel + 0.055) / 1.055, 2.4);


func _expect_locale_switch_updates_shared_components() -> void:
	var section_header_scene: PackedScene = load("res://shared/ui/components/ui_section_header.tscn") as PackedScene;
	if section_header_scene == null:
		_check(false, "locale switch test: failed to load UiSectionHeader scene");
		return;
	var section_header: UiSectionHeader = section_header_scene.instantiate() as UiSectionHeader;
	if section_header == null:
		_check(false, "locale switch test: failed to instantiate UiSectionHeader");
		return;
	scene_root.add_child(section_header);
	section_header.title_key = "UI_SETTINGS";
	await get_tree().process_frame;
	var title_label: Label = section_header.get_node_or_null("%TitleLabel") as Label;
	if title_label == null:
		_check(false, "locale switch test: UiSectionHeader title label is missing");
		section_header.queue_free();
		return;

	var initial_locale: String = LocalizationManager.get_current_locale();
	LocalizationManager.set_locale("ru", false);
	await get_tree().process_frame;
	_check(
		title_label.text == tr("UI_SETTINGS"),
		"locale switch test: UiSectionHeader text did not update for ru locale"
	);

	LocalizationManager.set_locale("en", false);
	await get_tree().process_frame;
	_check(
		title_label.text == tr("UI_SETTINGS"),
		"locale switch test: UiSectionHeader text did not update for en locale"
	);

	LocalizationManager.set_locale(initial_locale, false);
	await get_tree().process_frame;
	section_header.queue_free();


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0);
	while Time.get_ticks_msec() <= deadline_msec:
		if predicate.is_valid() and bool(predicate.call()):
			return true;
		await get_tree().process_frame;
	return false;


func _check(condition: bool, message: String) -> void:
	if condition:
		return;
	_failures.append(message);
	push_error("[PHASE0_SMOKE] %s" % [message]);


func _finish() -> void:
	if _failures.is_empty():
		_write_result_file(true, []);
		print("[PHASE0_SMOKE] PASS");
		get_tree().quit(0);
		return;

	_write_result_file(false, _failures);
	push_error("[PHASE0_SMOKE] FAILURES: %d" % [_failures.size()]);
	for failure: String in _failures:
		push_error("[PHASE0_SMOKE] - %s" % [failure]);
	get_tree().quit(1);


func _write_result_file(is_success: bool, failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE);
	if file == null:
		return;
	if is_success:
		file.store_string("PASS");
		file.close();
		return;
	file.store_string("FAIL\n");
	for failure: String in failures:
		file.store_string("%s\n" % [failure]);
	file.close();

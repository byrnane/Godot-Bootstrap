extends Node;


const LOAD_TIMEOUT_SECONDS: float = 8.0;
const STATE_TIMEOUT_SECONDS: float = 4.0;
const TRANSITION_DELAY_SECONDS: float = 2.0;
const CYCLE_COUNT: int = 2;
const RESULT_PATH: String = "user://phase0_smoke_result.txt";
const MIN_CONTRAST_RATIO: float = 4.5;
const MIN_CONTRAST_RATIO_DISABLED: float = 2.5;
const CONTRAST_BASE_BACKGROUND: Color = Color(0.03, 0.04, 0.06, 1.0);
const RUNTIME_LOCALIZATION_KEYS: PackedStringArray = [
	"UI_DEBUG_ACTIONS_HEADER",
	"UI_DEBUG_ACTION_CLEAR_SAVE",
	"UI_DEBUG_ACTION_JUMP_SCENE",
	"UI_DEBUG_ACTION_RESTART_SESSION",
	"UI_DEBUG_TOAST_SAVE_CLEARED",
	"UI_DEBUG_TOAST_SCENE_JUMPED",
	"UI_DEBUG_TOAST_TRANSITION_BLOCKED",
	"UI_LOADING_STATE_LOADING",
	"UI_LOADING_STATE_SUCCESS",
	"UI_LOADING_STATE_ERROR",
	"UI_FEEDBACK_CONFIRM_TITLE",
	"UI_FEEDBACK_ALERT_TITLE",
];


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
	await _check_localization_runtime_sanity();
	await _expect_locale_switch_updates_shared_components();
	_validate_main_menu_focus_navigation();
	_check_default_theme_contrast();
	_check_core_data_containers();
	await _check_scene_loading_pipeline_contract();
	await _check_audio_pipeline_contract();

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


func _check_scene_loading_pipeline_contract() -> void:
	SceneRouter.go_to(Scenes.GAMEPLAY);
	var loading_started: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.is_loading(),
		TRANSITION_DELAY_SECONDS
	);
	_check(loading_started, "scene pipeline test: gameplay transition did not enter loading state");
	if not loading_started:
		return;

	SceneRouter.go_to(Scenes.MAIN_MENU);
	var queued_detected: bool = await _wait_until(
		func() -> bool:
			return bool(SceneRouter.get_debug_snapshot().get("has_queued_transition", false)),
		TRANSITION_DELAY_SECONDS
	);
	_check(queued_detected, "scene pipeline test: queued transition was not detected");

	var queue_drained: bool = await _wait_until(
		func() -> bool:
			var snapshot: Dictionary = SceneRouter.get_debug_snapshot();
			return (
				not bool(snapshot.get("is_loading", true))
				and not bool(snapshot.get("has_queued_transition", true))
				and SceneRouter.current_scene_id == Scenes.MAIN_MENU
			),
		LOAD_TIMEOUT_SECONDS * 2.0
	);
	_check(queue_drained, "scene pipeline test: queued transition did not resolve to main menu");
	_check(not TransitionManager.is_active(), "scene pipeline test: transition manager stayed active after queue drain");
	_check(AppContext.state == AppState.Value.MAIN_MENU, "scene pipeline test: app state should be MAIN_MENU after queue drain");

	SceneRouter.go_to(&"__smoke_unknown_scene__");
	var fallback_loaded: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.current_scene_id == Scenes.MAIN_MENU and not SceneRouter.is_loading(),
		LOAD_TIMEOUT_SECONDS
	);
	_check(fallback_loaded, "scene pipeline test: unknown scene fallback did not resolve to default scene");


func _check_core_data_containers() -> void:
	var migrated_save: SaveData = SaveData.from_variant({
		"version": SaveData.CURRENT_VERSION - 1,
		"session_exists": true,
		"current_level_id": "__missing_level__",
		"player_health": -24,
		"score": -13,
	});
	_check(migrated_save != null, "data container test: SaveData migration returned null for compatible payload");
	if migrated_save != null:
		_check(
			migrated_save.version == SaveData.CURRENT_VERSION,
			"data container test: SaveData migration should normalize to current version"
		);
		_check(
			migrated_save.current_level_id == SaveData.DEFAULT_LEVEL_ID,
			"data container test: SaveData should fallback to default level id"
		);
		_check(migrated_save.player_health == 0, "data container test: SaveData should clamp negative health to zero");
		_check(migrated_save.score == 0, "data container test: SaveData should clamp negative score to zero");

	var incompatible_save: SaveData = SaveData.from_variant({
		"version": SaveData.CURRENT_VERSION + 1,
		"session_exists": true,
	});
	_check(incompatible_save == null, "data container test: SaveData should reject too-new payload versions");
	_check(
		not SaveData.get_incompatibility_reason({"version": SaveData.CURRENT_VERSION + 1}).is_empty(),
		"data container test: SaveData should provide incompatibility reason for too-new versions"
	);

	var sanitized_settings: UserSettings = UserSettings.new();
	sanitized_settings.language = "pt_BR";
	sanitized_settings.master_volume = 1.3;
	sanitized_settings.music_volume = -0.2;
	sanitized_settings.ui_volume = 9.0;
	sanitized_settings.sfx_volume = -5.0;
	sanitized_settings.version = -99;
	SettingsManager.call("_sanitize_settings", sanitized_settings);
	_check(
		sanitized_settings.version == UserSettings.CURRENT_VERSION,
		"data container test: UserSettings version should normalize to current value"
	);
	_check(
		sanitized_settings.language == LocalizationManager.DEFAULT_LOCALE,
		"data container test: UserSettings locale should normalize to default supported locale"
	);
	_check(
		is_equal_approx(sanitized_settings.master_volume, 1.0),
		"data container test: UserSettings master volume should clamp to 1.0"
	);
	_check(
		is_equal_approx(sanitized_settings.music_volume, 0.0),
		"data container test: UserSettings music volume should clamp to 0.0"
	);
	_check(
		is_equal_approx(sanitized_settings.ui_volume, 1.0),
		"data container test: UserSettings UI volume should clamp to 1.0"
	);
	_check(
		is_equal_approx(sanitized_settings.sfx_volume, 0.0),
		"data container test: UserSettings SFX volume should clamp to 0.0"
	);

	var startup_params: AppStartupParams = AppStartupParams.new();
	startup_params.main_menu_scene_id = &"__unknown_menu_scene__";
	var resolved_startup: AppStartupParams = AppFlow.call("_resolve_startup_params", startup_params) as AppStartupParams;
	_check(resolved_startup != null, "data container test: startup params resolution returned null");
	if resolved_startup != null:
		_check(
			resolved_startup.main_menu_scene_id == GameConfig.get_start_scene_id(),
			"data container test: startup params should fallback to configured start scene"
		);

	var session_params: SessionStartParams = SessionStartParams.new();
	session_params.gameplay_scene_id = &"__unknown_gameplay_scene__";
	var resolved_session: SessionStartParams = AppFlow.call("_resolve_session_start_params", session_params) as SessionStartParams;
	_check(resolved_session != null, "data container test: session params resolution returned null");
	if resolved_session != null:
		_check(
			resolved_session.gameplay_scene_id == GameConfig.get_gameplay_scene_id(),
			"data container test: session params should fallback to configured gameplay scene"
		);


func _check_audio_pipeline_contract() -> void:
	_check_audio_bus_layout();
	_check_one_shot_audio_path();
	await _check_music_audio_path();


func _check_audio_bus_layout() -> void:
	for bus_name: String in [
		AudioManager.MASTER_BUS_NAME,
		AudioManager.MUSIC_BUS_NAME,
		AudioManager.UI_BUS_NAME,
		AudioManager.SFX_BUS_NAME,
	]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "audio test: missing audio bus '%s'" % [bus_name]);

	for bus_name: String in [
		AudioManager.MUSIC_BUS_NAME,
		AudioManager.UI_BUS_NAME,
		AudioManager.SFX_BUS_NAME,
	]:
		var bus_index: int = AudioServer.get_bus_index(bus_name);
		if bus_index < 0:
			continue;
		var send_bus_name: String = AudioServer.get_bus_send(bus_index);
		_check(
			send_bus_name == AudioManager.MASTER_BUS_NAME,
			"audio test: bus '%s' should send to '%s'" % [bus_name, AudioManager.MASTER_BUS_NAME]
		);


func _check_one_shot_audio_path() -> void:
	var player: AudioStreamPlayer = AudioManager.play_ui_click();
	_check(player != null, "audio test: play_ui_click did not create one-shot player");
	if player == null:
		return;
	_check(player.bus == AudioManager.UI_BUS_NAME, "audio test: one-shot UI click used wrong audio bus");
	_check(player.playing, "audio test: one-shot UI click player did not start playback");


func _check_music_audio_path() -> void:
	var music_stream: AudioStream = GameConfig.get_main_menu_music();
	_check(music_stream != null, "audio test: main menu music stream is missing");
	if music_stream == null:
		return;

	AudioManager.stop_music(0.0);
	AudioManager.play_music(music_stream, {"fade_duration": 0.0});
	var playback_started: bool = await _wait_until(
		func() -> bool:
			return _find_active_music_player() != null,
		TRANSITION_DELAY_SECONDS
	);
	_check(playback_started, "audio test: play_music did not start active music playback");
	if not playback_started:
		return;

	var active_player: AudioStreamPlayer = _find_active_music_player();
	_check(active_player != null, "audio test: active music player node was not found");
	if active_player != null:
		_check(active_player.bus == AudioManager.MUSIC_BUS_NAME, "audio test: active music player uses wrong bus");
		_check(active_player.stream == music_stream, "audio test: active music player stream mismatch");
		_check(active_player.playing, "audio test: active music player is not playing");
	AudioManager.stop_music(0.0);


func _find_active_music_player() -> AudioStreamPlayer:
	for player_name: String in ["MusicPlayer0", "MusicPlayer1"]:
		var player: AudioStreamPlayer = AudioManager.get_node_or_null(player_name) as AudioStreamPlayer;
		if player == null:
			continue;
		if not player.playing:
			continue;
		return player;
	return null;


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


func _check_localization_runtime_sanity() -> void:
	var initial_locale: String = LocalizationManager.get_current_locale();
	for locale: String in LocalizationManager.get_supported_locales():
		LocalizationManager.set_locale(locale, false);
		await get_tree().process_frame;
		for key: String in RUNTIME_LOCALIZATION_KEYS:
			var localized_value: String = tr(key).strip_edges();
			_check(
				not localized_value.is_empty() and localized_value != key,
				"localization runtime test: missing key '%s' for locale '%s'" % [key, locale]
			);
	LocalizationManager.set_locale(initial_locale, false);
	await get_tree().process_frame;


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

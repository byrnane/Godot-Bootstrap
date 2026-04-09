extends Node;


const LOAD_TIMEOUT_SECONDS: float = 8.0;
const STATE_TIMEOUT_SECONDS: float = 4.0;
const TRANSITION_DELAY_SECONDS: float = 2.0;
const CYCLE_COUNT: int = 2;
const RESULT_PATH: String = "user://phase0_smoke_result.txt";


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

	for cycle_index: int in range(CYCLE_COUNT):
		var cycle_number: int = cycle_index + 1;
		await _expect_transition(
			Callable(AppFlow, "start_new_game"),
			Scenes.GAMEPLAY,
			AppState.Value.IN_GAME,
			"cycle %d: start new game" % [cycle_number]
		);
		_check(not get_tree().paused, "cycle %d: tree should not stay paused after gameplay load" % [cycle_number]);

		AppFlow.request_pause();
		var paused_state_reached: bool = await _wait_until(
			func() -> bool:
				return AppContext.state == AppState.Value.PAUSED and get_tree().paused,
			STATE_TIMEOUT_SECONDS
		);
		_check(paused_state_reached, "cycle %d: pause request did not set PAUSED state" % [cycle_number]);

		AppFlow.open_settings();
		await get_tree().process_frame;
		_check(get_tree().paused, "cycle %d: settings open should keep paused tree" % [cycle_number]);

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


func _check_localization_coverage() -> void:
	var report: Dictionary = LocalizationManager.get_static_key_coverage_report();
	var is_complete: bool = bool(report.get("complete", false));
	if is_complete:
		return;
	var missing_by_locale: Dictionary = report.get("missing_by_locale", {}) as Dictionary;
	_check(false, "localization coverage check failed: %s" % [JSON.stringify(missing_by_locale)]);


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

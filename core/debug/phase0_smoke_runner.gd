extends Node;


const LOAD_TIMEOUT_SECONDS: float = 8.0;
const STATE_TIMEOUT_SECONDS: float = 4.0;
const TRANSITION_DELAY_SECONDS: float = 2.0;
const RESULT_PATH: String = "user://phase0_smoke_result.txt";
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
	if OS.get_environment("GAME_TEMPLATE_SMOKE_ISOLATED") != "1":
		push_error("Run smoke through scripts/run_smoke.ps1 (isolated user data required).");
		get_tree().quit(1);
		return;
	process_mode = Node.PROCESS_MODE_ALWAYS;
	SceneRouter.configure(scene_root);
	call_deferred("_run");


func _run() -> void:
	var suite: String = OS.get_environment("GAME_TEMPLATE_SMOKE_SUITE");
	if suite not in ["flow", "persistence", "transitions", "audio", "localization", "all"]:
		_check(false, "Unknown smoke suite: " + suite);
		_finish();
		return;
	print("[PHASE0_SMOKE] suite: " + suite);
	await get_tree().process_frame;
	await _expect_transition(
		Callable(AppFlow, "startup"),
		Scenes.MAIN_MENU,
		AppState.Value.MAIN_MENU,
		"startup to main menu"
	);
	if suite in ["localization", "all"]:
		_check_localization_coverage();
		await _check_localization_runtime_sanity();
		await _expect_locale_switch_updates_shared_components();
	if suite in ["persistence", "all"]:
		_check_core_data_containers();
		_check_persistence_regressions();
		_check_settings_write_retry();
	if suite in ["transitions", "all"]:
		await _check_scene_loading_pipeline_contract();
		await _check_session_scene_override();
		await _expect_pause_ignored_during_transition();
		await _expect_feedback_modal_backdrop_behavior();
	if suite in ["audio", "all"]:
		await _check_audio_pipeline_contract();
	if suite in ["flow", "all"]:
		await _check_game_flow();
	# Retry can quit the application, so it must remain the last check.
	if suite in ["persistence", "all"]:
		await _check_exit_save_retry();
	_finish();


func _check_game_flow() -> void:
	var cycle_number: int = 1;
	await _expect_transition(
		Callable(AppFlow, "start_new_game"),
		Scenes.GAMEPLAY,
		AppState.Value.IN_GAME,
		"cycle %d: start new game" % [cycle_number]
	);
	_check(not get_tree().paused, "cycle %d: tree should not stay paused after gameplay load" % [cycle_number]);
	await _check_template_scenes();

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


func _check_template_scenes() -> void:
	var gameplay: Node = SceneRouter.current_scene_root;
	if gameplay == null:
		_check(false, "template: gameplay is missing");
		return;
	var level_root_path: NodePath = gameplay.get("level_scene_root_path");
	var level_root: Node = gameplay.get_node_or_null(level_root_path);
	if level_root == null:
		_check(false, "template: level root is missing");
		return;
	var world_type: String = gameplay.get_class();
	for level_id: StringName in [Scenes.LEVEL_STUB_A, Scenes.LEVEL_STUB_B]:
		gameplay.call("load_level_a" if level_id == Scenes.LEVEL_STUB_A else "load_level_b");
		await get_tree().process_frame;
		_check(SessionContext.current_level_id == level_id, "template: level id did not change");
		_check(level_root.get_child_count() == 1, "template: expected one active level");
		if level_root.get_child_count() != 1:
			continue;
		var level: Node = level_root.get_child(0);
		_check(level.get_class() == world_type, "template: gameplay and level dimensions differ");
		if world_type in ["Node2D", "Node3D"]:
			var suffix: String = "2D" if world_type == "Node2D" else "3D";
			for node_type: String in ["Camera", "StaticBody", "RigidBody"]:
				_check(
					not level.find_children("*", node_type + suffix, true, false).is_empty(),
					"template: level is missing " + node_type + suffix
				);
	gameplay.call("load_level_a");
	await get_tree().process_frame;

	# Maintainer validation supplies the branch; game copies can use smoke without Git.
	var variant: String = OS.get_environment("GAME_TEMPLATE_VARIANT");
	if variant not in ["main", "3d", "2d", "2d-pixelart"]:
		return;
	var expected_type: String = "Control" if variant == "main" else ("Node3D" if variant == "3d" else "Node2D");
	_check(world_type == expected_type, "template: wrong world type for " + variant);
	var pixel_art: bool = variant == "2d-pixelart";
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "template: expected Compatibility renderer");
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == (640 if pixel_art else 1280), "template: wrong viewport width");
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == (360 if pixel_art else 720), "template: wrong viewport height");
	_check(ProjectSettings.get_setting("display/window/size/window_width_override") == 1280, "template: wrong initial window width");
	_check(ProjectSettings.get_setting("display/window/size/window_height_override") == 720, "template: wrong initial window height");
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == ("viewport" if pixel_art else "canvas_items"), "template: wrong stretch mode");
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "template: aspect ratio must be preserved");
	_check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == ("integer" if pixel_art else "fractional"), "template: wrong scale mode");
	var expected_filter: int = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST if pixel_art else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR;
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == expected_filter, "template: wrong texture filter");
	_check(ProjectSettings.has_setting("autoload/CyclopsAutoload") == (variant == "3d"), "template: wrong Cyclops autoload configuration");
	_check(FileAccess.file_exists("res://features/props/demo_crate.tscn") == (variant == "3d"), "template: wrong 3D resource composition");
	if variant == "3d":
		_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "template: expected Jolt physics");


func _check_exit_save_retry() -> void:
	SessionContext.reset();
	SessionContext.score = 37;
	AppContext.set_state(AppState.Value.IN_GAME);
	AppContext.settings.autosave_enabled = true;
	AppContext.settings.autosave_on_exit = true;
	AutosaveManager.start_for_session();
	# A directory at the temporary filename causes a real write failure.
	var blocked_path: String = "user://saves/autosave.save.tmp";
	DirAccess.make_dir_recursive_absolute(blocked_path);
	get_tree().root.close_requested.emit();
	await get_tree().process_frame;
	_check(bool(AppFlow.get("_quit_dialog_open")), "exit regression: save failure did not open a choice");
	_check(not bool(AppFlow.get("_quitting")), "exit regression: game exited after a failed save");
	var modal: FeedbackModal = UiShell.get("_feedback_modal") as FeedbackModal;
	_check(modal != null and not modal.close_on_cancel and not modal.close_on_backdrop,
		"exit regression: Escape/backdrop can discard the failed save");
	DirAccess.remove_absolute(blocked_path);
	if modal == null or not bool(AppFlow.get("_quit_dialog_open")):
		return;
	modal.confirm_button.pressed.emit();
	await _wait_until(func() -> bool: return bool(AppFlow.get("_quitting")), STATE_TIMEOUT_SECONDS);
	var saved: SaveData = SaveManager.load_game_from_descriptor(SaveManager.descriptor_for_autosave());
	_check(saved != null and saved.score == 37, "exit regression: Retry did not save the active session");


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
	SceneRouter.go_to(Scenes.GAMEPLAY, null, {"warn_if_queued": false});
	var loading_started: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.is_loading(),
		TRANSITION_DELAY_SECONDS
	);
	_check(loading_started, "scene pipeline test: gameplay transition did not enter loading state");
	if not loading_started:
		return;

	SceneRouter.go_to(Scenes.MAIN_MENU, null, {"warn_if_queued": false});
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
				and not TransitionManager.is_active()
				and SceneRouter.current_scene_id == Scenes.MAIN_MENU
			),
		LOAD_TIMEOUT_SECONDS * 2.0
	);
	_check(queue_drained, "scene pipeline test: queued transition did not resolve to main menu");
	_check(not TransitionManager.is_active(), "scene pipeline test: transition manager stayed active after queue drain");
	_check(AppContext.state == AppState.Value.MAIN_MENU, "scene pipeline test: app state should be MAIN_MENU after queue drain");

	SceneRouter.go_to(&"__smoke_unknown_scene__", null, {"warn_if_unknown": false});
	var fallback_loading_started: bool = await _wait_until(
		func() -> bool:
			return SceneRouter.is_loading() or AppContext.state == AppState.Value.LOADING,
		TRANSITION_DELAY_SECONDS
	);
	_check(fallback_loading_started, "scene pipeline test: unknown scene fallback did not start loading");
	if not fallback_loading_started:
		return;

	var fallback_loaded: bool = await _wait_until(
		func() -> bool:
			return (
				SceneRouter.current_scene_id == Scenes.MAIN_MENU
				and not SceneRouter.is_loading()
				and not TransitionManager.is_active()
			),
		LOAD_TIMEOUT_SECONDS
	);
	_check(fallback_loaded, "scene pipeline test: unknown scene fallback did not resolve to default scene");


func _check_persistence_regressions() -> void:
	var pause_key: InputEventKey = InputEventKey.new();
	pause_key.keycode = KEY_F10;
	_check(InputMap.action_has_event(&"ui_pause", pause_key), "input regression: default pause key must be F10");
	var data: SaveData = SaveData.new();
	data.session_exists = true;
	data.score = 10;
	_check(SaveManager.save_game(data, 98), "save regression: first write failed");
	data.score = 20;
	_check(SaveManager.save_game(data, 98), "save regression: replacement failed");
	var path: String = "user://saves/manual_98.save";
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(path + ".bak");
	var broken: FileAccess = FileAccess.open(path, FileAccess.WRITE);
	broken.store_var({"version": SaveData.CURRENT_VERSION + 1});
	broken.close();
	var recovered: SaveData = SaveManager.load_game(98);
	_check(recovered != null and recovered.score == 10, "save regression: backup recovery failed");
	_check(FileAccess.get_file_as_bytes(path + ".bak") == backup, "save regression: recovery damaged backup");
	DirAccess.remove_absolute(path);
	_check(SaveManager.list_slots().has(98), "save regression: backup-only slot is missing");
	_check(SaveManager.load_game(98) != null, "save regression: backup-only slot cannot load");
	SaveManager.delete_save(98);
	for legacy_path: String in ["user://saves/slot_97.save.bak", "user://savegame.save.bak"]:
		var legacy_slot: int = 97 if legacy_path.contains("slot_97") else 0;
		var legacy: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE);
		legacy.store_var(data.to_dictionary());
		legacy.close();
		var legacy_bytes: PackedByteArray = FileAccess.get_file_as_bytes(legacy_path);
		var legacy_recovered: SaveData = SaveManager.load_game(legacy_slot);
		_check(legacy_recovered != null and legacy_recovered.score == 20, "save regression: legacy backup-only recovery failed");
		_check(FileAccess.file_exists(legacy_path) and FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes,
			"save regression: migration deleted the only recovery copy");
		SaveManager.delete_save(legacy_slot);

	var previous_state: AppState.Value = AppContext.state;
	AppContext.set_state(AppState.Value.IN_GAME);
	AutosaveManager.start_for_session();
	AutosaveManager.set("_last_autosave_time_sec", Time.get_unix_time_from_system());
	_check(not AutosaveManager.emit_checkpoint("smoke_retry"), "autosave regression: cooldown not applied");
	AutosaveManager.set("_last_autosave_time_sec", -9999.0);
	_check(AutosaveManager.emit_checkpoint("smoke_retry"), "autosave regression: rejected checkpoint cannot retry");
	_check(AutosaveManager.request_autosave(AutosaveManager.REASON_EXIT), "autosave regression: cooldown blocks exit save");
	AutosaveManager.stop_for_session();
	SaveManager.delete_save_descriptor(SaveManager.descriptor_for_autosave());
	AppContext.set_state(previous_state);

	var key: InputEventKey = InputEventKey.new();
	key.physical_keycode = KEY_W;
	InputManager.call("_apply_rebind", &"ui_down", key);
	_check(not InputManager.call("_action_has_matching_event", &"ui_up", key), "input regression: opposite directions share a key");
	var no_events: Array[InputEvent] = [];
	InputManager.call("_set_action_events", &"ui_up", no_events);
	_check(InputManager.save_bindings(), "input regression: save failed");
	InputManager.load_bindings();
	_check(InputManager.get_action_events(&"ui_up").is_empty(), "input regression: unbound action reverted on load");
	var previous_bindings: PackedByteArray = FileAccess.get_file_as_bytes(InputManager.INPUT_SETTINGS_PATH);
	var blocked_bindings: String = InputManager.INPUT_SETTINGS_PATH + ".tmp";
	DirAccess.make_dir_absolute(blocked_bindings);
	_check(not InputManager.save_bindings(), "input regression: blocked write reported success");
	_check(FileAccess.get_file_as_bytes(InputManager.INPUT_SETTINGS_PATH) == previous_bindings,
		"input regression: failed write damaged saved bindings");
	DirAccess.remove_absolute(blocked_bindings);
	InputManager.reset_to_defaults();


func _check_settings_write_retry() -> void:
	var modal: Control = UiShell.get("_settings_modal") as Control;
	_check(modal != null, "settings regression: settings modal is missing");
	if modal == null:
		return;
	var blocked_path: String = SettingsManager.SETTINGS_PATH + ".tmp";
	DirAccess.make_dir_absolute(blocked_path);
	modal.call("_on_reset_button_pressed");
	_check(bool(modal.get("_is_dirty")), "settings regression: failed reset cannot be retried");
	var apply_button: Button = modal.get("apply_button") as Button;
	_check(apply_button != null and not apply_button.disabled, "settings regression: Apply disabled after failed reset");
	DirAccess.remove_absolute(blocked_path);
	_check(bool(modal.call("_apply_values")), "settings regression: retry did not save settings");


func _check_session_scene_override() -> void:
	var params: SessionStartParams = SessionStartParams.new();
	params.gameplay_scene_id = Scenes.LEVEL_STUB_A;
	await _expect_transition(Callable(AppFlow, "start_session").bind(params), Scenes.LEVEL_STUB_A,
		AppState.Value.IN_GAME, "session scene override");
	_check(bool(AutosaveManager.get("_session_active")), "session regression: scene override disabled autosave");
	await _expect_transition(Callable(AppFlow, "return_to_main_menu"), Scenes.MAIN_MENU,
		AppState.Value.MAIN_MENU, "return from session scene override");


func _check_core_data_containers() -> void:
	# Intentionally feed partially invalid payloads to verify migration and
	# fallback contracts of persistence/runtime parameter containers.
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
	sanitized_settings.autosave_interval_seconds = -15;
	sanitized_settings.autosave_score_step = -25;
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
	_check(
		sanitized_settings.autosave_interval_seconds >= 15,
		"data container test: UserSettings autosave interval should clamp to minimum value"
	);
	_check(
		sanitized_settings.autosave_score_step >= 1,
		"data container test: UserSettings autosave score step should clamp to minimum value"
	);

	var startup_params: AppStartupParams = AppStartupParams.new();
	startup_params.main_menu_scene_id = &"__unknown_menu_scene__";
	var resolved_startup: AppStartupParams = AppFlow.call("_resolve_startup_params", startup_params, false) as AppStartupParams;
	_check(resolved_startup != null, "data container test: startup params resolution returned null");
	if resolved_startup != null:
		_check(
			resolved_startup.main_menu_scene_id == GameConfig.get_start_scene_id(),
			"data container test: startup params should fallback to configured start scene"
		);

	var session_params: SessionStartParams = SessionStartParams.new();
	session_params.gameplay_scene_id = &"__unknown_gameplay_scene__";
	var resolved_session: SessionStartParams = AppFlow.call("_resolve_session_start_params", session_params, false) as SessionStartParams;
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
	if player.get_parent() != null:
		player.get_parent().remove_child(player);
	player.queue_free();


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
	_prepare_runtime_for_shutdown();
	if _failures.is_empty():
		_write_result_file(true, []);
		print("[PHASE0_SMOKE] PASS");
		call_deferred("_quit_smoke", 0);
		return;

	_write_result_file(false, _failures);
	push_error("[PHASE0_SMOKE] FAILURES: %d" % [_failures.size()]);
	for failure: String in _failures:
		push_error("[PHASE0_SMOKE] - %s" % [failure]);
	call_deferred("_quit_smoke", 1);


func _prepare_runtime_for_shutdown() -> void:
	# Smoke keeps long-lived autoloads alive until process exit, so release
	# audio/config references explicitly before quitting to keep the run clean.
	if AudioManager != null:
		AudioManager.stop_music(0.0);
		if AudioManager.has_method("_release_runtime_players"):
			AudioManager.call("_release_runtime_players");
	if GameConfig != null:
		GameConfig.main_menu_music = null;


func _quit_smoke(exit_code: int) -> void:
	# The Retry scenario already owns a normal application exit.
	if bool(AppFlow.get("_quitting")):
		return;
	# Let queued frees from smoke helpers flush before shutdown to keep output clean.
	await get_tree().process_frame;
	# AudioServer releases stopped playback on its next mixer tick, not a scene frame.
	await get_tree().create_timer(0.1, true, false, true).timeout;
	get_tree().quit(exit_code);


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

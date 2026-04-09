extends Node;

@export var start_scene_id: StringName = Scenes.MAIN_MENU;
@export var gameplay_scene_id: StringName = Scenes.GAMEPLAY;


const MAIN_MENU_MUSIC: AudioStream = preload("res://assets/music/main_menu.mp3");
const SCENE_TRANSITION_PAYLOAD_TYPE = preload("res://core/types/scene_transition_payload.gd");
const APP_STARTUP_PARAMS_TYPE = preload("res://core/types/app_startup_params.gd");
const SESSION_START_PARAMS_TYPE = preload("res://core/types/session_start_params.gd");


var _started: bool = false;
var _reported_missing_scene_signals: Dictionary = {};


func _ready() -> void:
	_connect_ui_shell();
	_connect_app_context();
	_connect_transition_manager();
	if not SceneRouter.scene_changed.is_connected(_on_scene_changed):
		SceneRouter.scene_changed.connect(_on_scene_changed);


func startup(params: APP_STARTUP_PARAMS_TYPE = null) -> void:
	if _started:
		return;

	_started = true;
	AppContext.ensure_defaults();
	var startup_params: APP_STARTUP_PARAMS_TYPE = _resolve_startup_params(params);
	match startup_params.launch_mode:
		APP_STARTUP_PARAMS_TYPE.LaunchMode.START_SESSION:
			start_session(startup_params.session_start_params as SESSION_START_PARAMS_TYPE);
		_:
			_go_to_main_menu(SCENE_TRANSITION_PAYLOAD_TYPE.Kind.STARTUP, startup_params.main_menu_scene_id);


func start_new_game() -> void:
	start_session(_create_session_start_params(SESSION_START_PARAMS_TYPE.Mode.NEW_GAME));


func continue_game() -> void:
	start_session(_create_session_start_params(SESSION_START_PARAMS_TYPE.Mode.CONTINUE_OR_NEW));


func start_session(params: SESSION_START_PARAMS_TYPE = null) -> void:
	if _is_transition_blocked():
		return;

	var session_params: SESSION_START_PARAMS_TYPE = _resolve_session_start_params(params);
	var transition_kind: int = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.NEW_GAME;
	match session_params.mode:
		SESSION_START_PARAMS_TYPE.Mode.NEW_GAME:
			SessionContext.reset();
			transition_kind = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.NEW_GAME;
		SESSION_START_PARAMS_TYPE.Mode.CONTINUE_ONLY, SESSION_START_PARAMS_TYPE.Mode.CONTINUE_OR_NEW:
			var save_data: SaveData = SaveManager.load_game();
			if save_data == null or not save_data.session_exists:
				if session_params.mode == SESSION_START_PARAMS_TYPE.Mode.CONTINUE_ONLY:
					push_warning("AppFlow: continue-only session start requested but no save exists.");
					return;
				SessionContext.reset();
				transition_kind = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.NEW_GAME;
			else:
				SessionContext.apply_save_data(save_data);
				transition_kind = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.CONTINUE_GAME;
		_:
			SessionContext.reset();
			transition_kind = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.NEW_GAME;

	AppContext.set_state(AppState.Value.IN_GAME);
	SceneRouter.go_to(
		session_params.gameplay_scene_id,
		_build_gameplay_payload(transition_kind, session_params.gameplay_scene_id, session_params.payload_data)
	);


func return_to_main_menu() -> void:
	_go_to_main_menu(SCENE_TRANSITION_PAYLOAD_TYPE.Kind.RETURN_TO_MENU);


func request_pause() -> void:
	if AppContext.state != AppState.Value.IN_GAME:
		return;
	if SceneRouter.current_scene_id != gameplay_scene_id:
		return;
	if SceneRouter.is_loading() or TransitionManager.is_active():
		return;
	if get_tree().paused:
		return;

	AppContext.set_state(AppState.Value.PAUSED);
	get_tree().paused = true;
	UiShell.open_pause();


func request_resume() -> void:
	if AppContext.state != AppState.Value.PAUSED:
		if get_tree().paused and not TransitionManager.is_active():
			_reset_pause_ui();
		return;

	_reset_pause_ui();
	AppContext.set_state(AppState.Value.IN_GAME);


func open_settings() -> void:
	UiShell.open_settings();


func quit_game() -> void:
	get_tree().quit();


func _go_to_main_menu(
	transition_kind: int = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.RETURN_TO_MENU,
	target_scene_id: StringName = &""
) -> void:
	if _is_transition_blocked():
		return;
	if target_scene_id == StringName():
		target_scene_id = start_scene_id;
	_reset_pause_ui();
	AppContext.set_state(AppState.Value.MAIN_MENU);
	SceneRouter.go_to(target_scene_id, _build_main_menu_payload(transition_kind, target_scene_id));


func _connect_ui_shell() -> void:
	if UiShell == null:
		return;

	if not UiShell.pause_requested.is_connected(request_pause):
		UiShell.pause_requested.connect(request_pause);
	if not UiShell.resume_requested.is_connected(request_resume):
		UiShell.resume_requested.connect(request_resume);
	if not UiShell.settings_requested.is_connected(open_settings):
		UiShell.settings_requested.connect(open_settings);
	if not UiShell.back_to_menu_requested.is_connected(return_to_main_menu):
		UiShell.back_to_menu_requested.connect(return_to_main_menu);
	if not UiShell.save_requested.is_connected(SaveManager.save_current_session):
		UiShell.save_requested.connect(SaveManager.save_current_session);


func _connect_transition_manager() -> void:
	if TransitionManager == null:
		return;
	if not TransitionManager.transition_started.is_connected(_on_transition_started):
		TransitionManager.transition_started.connect(_on_transition_started);


func _connect_app_context() -> void:
	if AppContext == null:
		return;
	if not AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.connect(_on_app_state_changed);
	_apply_tree_pause_from_state(AppContext.state);


func _on_scene_changed(_scene_id: StringName, scene_root: Node) -> void:
	if scene_root == null:
		return;

	var current_scene_id: StringName = SceneRouter.current_scene_id;
	_sync_scene_music(current_scene_id);
	match current_scene_id:
		Scenes.MAIN_MENU:
			_connect_main_menu(scene_root);
		Scenes.GAMEPLAY:
			_connect_gameplay(scene_root);


func _connect_main_menu(scene_root: Node) -> void:
	_connect_scene_signal(scene_root, &"new_game_requested", Callable(self, "start_new_game"));
	_connect_scene_signal(scene_root, &"continue_requested", Callable(self, "continue_game"));
	_connect_scene_signal(scene_root, &"settings_requested", Callable(self, "open_settings"));
	_connect_scene_signal(scene_root, &"quit_requested", Callable(self, "quit_game"));


func _connect_gameplay(scene_root: Node) -> void:
	_connect_scene_signal(scene_root, &"pause_requested", Callable(self, "request_pause"));
	_connect_scene_signal(scene_root, &"resume_requested", Callable(self, "request_resume"));
	_connect_scene_signal(scene_root, &"back_to_menu_requested", Callable(self, "return_to_main_menu"));
	_connect_scene_signal(scene_root, &"save_requested", Callable(SaveManager, "save_current_session"));


func _reset_pause_ui() -> void:
	UiShell.close_pause();
	UiShell.close_settings();
	get_tree().paused = false;


func _sync_scene_music(scene_id: StringName) -> void:
	match scene_id:
		Scenes.MAIN_MENU:
			AudioManager.play_music(MAIN_MENU_MUSIC);
		_:
			return;


func _connect_scene_signal(scene_root: Node, signal_name: StringName, target: Callable) -> void:
	if scene_root == null:
		return;
	if not scene_root.has_signal(signal_name):
		_warn_missing_scene_signal(scene_root, signal_name);
		return;
	if scene_root.is_connected(signal_name, target):
		return;
	scene_root.connect(signal_name, target);


func _warn_missing_scene_signal(scene_root: Node, signal_name: StringName) -> void:
	var scene_source: String = scene_root.get_class();
	var script_resource: Script = scene_root.get_script() as Script;
	if script_resource != null and not script_resource.resource_path.is_empty():
		scene_source = script_resource.resource_path;
	var warning_key: String = "%s::%s" % [scene_source, String(signal_name)];
	if _reported_missing_scene_signals.has(warning_key):
		return;
	_reported_missing_scene_signals[warning_key] = true;
	push_warning("AppFlow: scene '%s' is missing required signal '%s'." % [scene_source, String(signal_name)]);


func _on_transition_started(_data: Dictionary) -> void:
	# Scene transitions should always run with an unpaused tree so loading and
	# scene lifecycle callbacks cannot be stalled by leftover pause state.
	if get_tree().paused:
		_reset_pause_ui();


func _on_app_state_changed(new_state: AppState.Value) -> void:
	_apply_tree_pause_from_state(new_state);


func _apply_tree_pause_from_state(new_state: AppState.Value) -> void:
	var should_pause_tree: bool = new_state == AppState.Value.PAUSED;
	if get_tree().paused == should_pause_tree:
		return;
	get_tree().paused = should_pause_tree;


func _build_main_menu_payload(transition_kind: int, target_scene_id: StringName) -> SCENE_TRANSITION_PAYLOAD_TYPE:
	var payload: SCENE_TRANSITION_PAYLOAD_TYPE = SCENE_TRANSITION_PAYLOAD_TYPE.new();
	payload.target_scene_id = target_scene_id;
	payload.source_scene_id = SceneRouter.current_scene_id;
	payload.kind = transition_kind;
	return payload;


func _build_gameplay_payload(
	transition_kind: int,
	target_scene_id: StringName,
	extra_payload_data: Dictionary = {}
) -> SCENE_TRANSITION_PAYLOAD_TYPE:
	var payload: SCENE_TRANSITION_PAYLOAD_TYPE = SCENE_TRANSITION_PAYLOAD_TYPE.new();
	payload.target_scene_id = target_scene_id;
	payload.source_scene_id = SceneRouter.current_scene_id;
	payload.kind = transition_kind;
	payload.data = {
		"level_id": String(SessionContext.current_level_id),
		"is_new_session": SessionContext.is_new_session,
	};
	payload.data.merge(extra_payload_data, true);
	return payload;


func _is_transition_blocked() -> bool:
	return SceneRouter.is_loading() or TransitionManager.is_active();


func _resolve_startup_params(params: APP_STARTUP_PARAMS_TYPE) -> APP_STARTUP_PARAMS_TYPE:
	var resolved_params: APP_STARTUP_PARAMS_TYPE = params;
	if resolved_params == null:
		resolved_params = APP_STARTUP_PARAMS_TYPE.new();
	if resolved_params.main_menu_scene_id == StringName():
		resolved_params.main_menu_scene_id = start_scene_id;
	if not Scenes.has(resolved_params.main_menu_scene_id):
		push_warning(
			"AppFlow: startup main_menu_scene_id '%s' is unknown, fallback to '%s'." % [
				String(resolved_params.main_menu_scene_id),
				String(start_scene_id),
			]
		);
		resolved_params.main_menu_scene_id = start_scene_id;
	if resolved_params.launch_mode == APP_STARTUP_PARAMS_TYPE.LaunchMode.START_SESSION:
		if resolved_params.session_start_params == null:
			resolved_params.session_start_params = _create_session_start_params(SESSION_START_PARAMS_TYPE.Mode.NEW_GAME);
		elif not (resolved_params.session_start_params is SESSION_START_PARAMS_TYPE):
			push_warning("AppFlow: startup session_start_params has invalid type, fallback to NEW_GAME mode.");
			resolved_params.session_start_params = _create_session_start_params(SESSION_START_PARAMS_TYPE.Mode.NEW_GAME);
	return resolved_params;


func _resolve_session_start_params(params: SESSION_START_PARAMS_TYPE) -> SESSION_START_PARAMS_TYPE:
	var resolved_params: SESSION_START_PARAMS_TYPE = params;
	if resolved_params == null:
		resolved_params = _create_session_start_params(SESSION_START_PARAMS_TYPE.Mode.NEW_GAME);
	if resolved_params.gameplay_scene_id == StringName():
		resolved_params.gameplay_scene_id = gameplay_scene_id;
	if not Scenes.has(resolved_params.gameplay_scene_id):
		push_warning(
			"AppFlow: session gameplay_scene_id '%s' is unknown, fallback to '%s'." % [
				String(resolved_params.gameplay_scene_id),
				String(gameplay_scene_id),
			]
		);
		resolved_params.gameplay_scene_id = gameplay_scene_id;
	return resolved_params;


func _create_session_start_params(mode: int) -> SESSION_START_PARAMS_TYPE:
	var params: SESSION_START_PARAMS_TYPE = SESSION_START_PARAMS_TYPE.new();
	params.mode = mode;
	params.gameplay_scene_id = gameplay_scene_id;
	return params;

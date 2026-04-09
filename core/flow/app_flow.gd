extends Node;

@export var start_scene_id: StringName = Scenes.MAIN_MENU;
@export var gameplay_scene_id: StringName = Scenes.GAMEPLAY;


const MAIN_MENU_MUSIC: AudioStream = preload("res://assets/music/main_menu.mp3");


var _started: bool = false;
var _reported_missing_scene_signals: Dictionary = {};


func _ready() -> void:
	_connect_ui_shell();
	_connect_app_context();
	_connect_transition_manager();
	if not SceneRouter.scene_changed.is_connected(_on_scene_changed):
		SceneRouter.scene_changed.connect(_on_scene_changed);


func startup() -> void:
	if _started:
		return;

	_started = true;
	AppContext.ensure_defaults();
	_go_to_main_menu();


func start_new_game() -> void:
	if SceneRouter.is_loading() or TransitionManager.is_active():
		return;
	SessionContext.reset();
	AppContext.set_state(AppState.Value.IN_GAME);
	SceneRouter.go_to(gameplay_scene_id, SessionContext);


func continue_game() -> void:
	if SceneRouter.is_loading() or TransitionManager.is_active():
		return;
	var save_data: SaveData = SaveManager.load_game();
	if save_data == null or not save_data.session_exists:
		start_new_game();
		return;

	SessionContext.apply_save_data(save_data);
	AppContext.set_state(AppState.Value.IN_GAME);
	SceneRouter.go_to(gameplay_scene_id, SessionContext);


func return_to_main_menu() -> void:
	_go_to_main_menu();


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


func _go_to_main_menu() -> void:
	if SceneRouter.is_loading() or TransitionManager.is_active():
		return;
	_reset_pause_ui();
	AppContext.set_state(AppState.Value.MAIN_MENU);
	SceneRouter.go_to(start_scene_id, null);


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

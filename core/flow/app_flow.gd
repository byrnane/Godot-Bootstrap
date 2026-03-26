extends Node;

@export var start_scene_id: StringName = Scenes.MAIN_MENU;
@export var gameplay_scene_id: StringName = Scenes.GAMEPLAY;


const MAIN_MENU_MUSIC: AudioStream = preload("res://assets/music/main_menu.mp3");


var _started: bool = false;


func _ready() -> void:
	_connect_ui_shell();
	if not SceneRouter.scene_changed.is_connected(_on_scene_changed):
		SceneRouter.scene_changed.connect(_on_scene_changed);


func startup() -> void:
	if _started:
		return;

	_started = true;
	AppContext.ensure_defaults();
	_go_to_main_menu();


func start_new_game() -> void:
	SessionContext.reset();
	AppContext.set_state(AppState.Value.IN_GAME);
	SceneRouter.go_to(gameplay_scene_id, SessionContext);


func continue_game() -> void:
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

	AppContext.set_state(AppState.Value.PAUSED);
	get_tree().paused = true;
	UiShell.open_pause();


func request_resume() -> void:
	if AppContext.state != AppState.Value.PAUSED:
		return;

	_reset_pause_ui();
	AppContext.set_state(AppState.Value.IN_GAME);


func open_settings() -> void:
	UiShell.open_settings();


func quit_game() -> void:
	get_tree().quit();


func _go_to_main_menu() -> void:
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


func _on_scene_changed(_scene_id: StringName, scene_root: Node) -> void:
	if scene_root == null:
		return;

	_sync_scene_music(SceneRouter.current_scene_id);
	_connect_main_menu(scene_root);
	_connect_gameplay(scene_root);


func _connect_main_menu(scene_root: Node) -> void:
	if not scene_root.has_signal("new_game_requested"):
		return;

	if not scene_root.new_game_requested.is_connected(start_new_game):
		scene_root.new_game_requested.connect(start_new_game);
	if not scene_root.continue_requested.is_connected(continue_game):
		scene_root.continue_requested.connect(continue_game);
	if not scene_root.settings_requested.is_connected(open_settings):
		scene_root.settings_requested.connect(open_settings);
	if not scene_root.quit_requested.is_connected(quit_game):
		scene_root.quit_requested.connect(quit_game);


func _connect_gameplay(scene_root: Node) -> void:
	if not scene_root.has_signal("pause_requested"):
		return;

	if not scene_root.pause_requested.is_connected(request_pause):
		scene_root.pause_requested.connect(request_pause);
	if not scene_root.resume_requested.is_connected(request_resume):
		scene_root.resume_requested.connect(request_resume);
	if not scene_root.back_to_menu_requested.is_connected(return_to_main_menu):
		scene_root.back_to_menu_requested.connect(return_to_main_menu);
	if not scene_root.save_requested.is_connected(SaveManager.save_current_session):
		scene_root.save_requested.connect(SaveManager.save_current_session);


func _reset_pause_ui() -> void:
	UiShell.close_pause();
	UiShell.close_settings();
	get_tree().paused = false;


func _sync_scene_music(scene_id: StringName) -> void:
	match scene_id:
		Scenes.MAIN_MENU:
			AudioManager.play_music(MAIN_MENU_MUSIC);
		Scenes.GAMEPLAY:
			pass;

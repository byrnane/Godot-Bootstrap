extends Control;
class_name GameplayStub;

signal pause_requested;
signal resume_requested;
signal back_to_menu_requested;
signal save_requested;
signal view_changed(view_model: Dictionary);


const GAMEPLAY_HUD_SCENE: PackedScene = preload("res://features/gameplay/gameplay_hud.tscn");
const HEALTH_STEP: int = 5;
const SCORE_STEP: int = 10;
const LEVEL_A_MUSIC: AudioStream = preload("res://assets/music/level_a.mp3");
const LEVEL_B_MUSIC: AudioStream = preload("res://assets/music/level_b.mp3");


@export var pause_action_name: StringName = &"ui_pause";
@export var level_scene_root_path: NodePath;

@onready var level_root: Control = get_node_or_null(level_scene_root_path) as Control;


func _ready() -> void:
	if not AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.connect(_on_app_state_changed);
	_refresh_view();


func _exit_tree() -> void:
	if AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.disconnect(_on_app_state_changed);


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(pause_action_name):
		return;
	_toggle_pause();
	get_viewport().set_input_as_handled();


func get_hud_scene() -> PackedScene:
	return GAMEPLAY_HUD_SCENE;


func bind_hud(hud: Control) -> void:
	if hud == null:
		return;
	# The gameplay scene owns the state; HUD only emits user intent and renders
	# the latest snapshot pushed from here.
	_connect_signal_if_needed(hud, &"damage_requested", Callable(self, "apply_damage"));
	_connect_signal_if_needed(hud, &"heal_requested", Callable(self, "apply_heal"));
	_connect_signal_if_needed(hud, &"score_requested", Callable(self, "add_score_points"));
	_connect_signal_if_needed(hud, &"level_a_requested", Callable(self, "load_level_a"));
	_connect_signal_if_needed(hud, &"level_b_requested", Callable(self, "load_level_b"));
	_connect_signal_if_needed(hud, &"pause_toggle_requested", Callable(self, "_toggle_pause"));
	_connect_signal_if_needed(hud, &"save_requested", Callable(self, "_request_save"));
	_connect_signal_if_needed(hud, &"back_to_menu_requested", Callable(self, "_request_back_to_menu"));
	_connect_signal_if_needed(self, &"view_changed", Callable(hud, "apply_view_model"));
	if hud.has_method("apply_view_model"):
		hud.call("apply_view_model", _build_view_model());


func on_enter(_payload: Variant = null) -> void:
	_refresh_view();
	_load_level(SessionContext.current_level_id);


func apply_damage() -> void:
	SessionContext.player_health = max(SessionContext.player_health - HEALTH_STEP, 0);
	_refresh_view();


func apply_heal() -> void:
	SessionContext.player_health += HEALTH_STEP;
	_refresh_view();


func add_score_points() -> void:
	SessionContext.score += SCORE_STEP;
	_refresh_view();


func load_level_a() -> void:
	SessionContext.current_level_id = Scenes.LEVEL_STUB_A;
	_load_level(SessionContext.current_level_id);


func load_level_b() -> void:
	SessionContext.current_level_id = Scenes.LEVEL_STUB_B;
	_load_level(SessionContext.current_level_id);


func _load_level(level_scene_id: StringName) -> void:
	if level_root == null:
		return;
	if not Scenes.has(level_scene_id):
		return;
	# Gameplay keeps level content below its own root instead of using
	# SceneRouter, because this swap is local to the active game scene.
	for child: Node in level_root.get_children():
		level_root.remove_child(child);
		child.queue_free();
	var level_path: String = Scenes.get_scene_path(level_scene_id);
	var packed_scene: PackedScene = load(level_path) as PackedScene;
	if packed_scene == null:
		return;
	var level_instance: Control = packed_scene.instantiate() as Control;
	if level_instance == null:
		return;
	level_root.add_child(level_instance);
	_sync_level_music(level_scene_id);
	_refresh_view();


func _refresh_view() -> void:
	view_changed.emit(_build_view_model());


func _build_view_model() -> Dictionary:
	return {
		"state": AppContext.state,
		"level_id": SessionContext.current_level_id,
		"health": SessionContext.player_health,
		"score": SessionContext.score,
	};


func _connect_signal_if_needed(source: Object, signal_name: StringName, target: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return;
	if source.is_connected(signal_name, target):
		return;
	source.connect(signal_name, target);


func _toggle_pause() -> void:
	if AppContext.state == AppState.Value.PAUSED:
		resume_requested.emit();
		return;
	pause_requested.emit();


func _request_save() -> void:
	save_requested.emit();


func _request_back_to_menu() -> void:
	back_to_menu_requested.emit();


func _on_app_state_changed(_new_state: AppState.Value) -> void:
	_refresh_view();


func _sync_level_music(level_scene_id: StringName) -> void:
	match level_scene_id:
		Scenes.LEVEL_STUB_A:
			AudioManager.play_music(LEVEL_A_MUSIC);
		Scenes.LEVEL_STUB_B:
			AudioManager.play_music(LEVEL_B_MUSIC);

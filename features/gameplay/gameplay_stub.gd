extends Control;
class_name GameplayStub;

signal pause_requested;
signal resume_requested;
signal back_to_menu_requested;
signal save_requested;

const HEALTH_STEP: int = 5;
const SCORE_STEP: int = 10;

@export var pause_action_name: StringName = &"ui_pause";
@export var level_scene_root_path: NodePath;

@onready var state_label: Label = %StateLabel;
@onready var level_label: Label = %LevelLabel;
@onready var health_label: Label = %HealthLabel;
@onready var score_label: Label = %ScoreLabel;
@onready var level_root: Control = get_node_or_null(level_scene_root_path) as Control;

func _ready() -> void:
	if not AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.connect(_on_app_state_changed);
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed);
	_refresh_view();

func _exit_tree() -> void:
	if AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.disconnect(_on_app_state_changed);
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed);

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pause_action_name):
		if AppContext.state == AppState.Value.PAUSED:
			resume_requested.emit();
		else:
			pause_requested.emit();
		get_viewport().set_input_as_handled();

func on_enter(_payload: Variant = null) -> void:
	_refresh_view();
	_load_level(SessionContext.current_level_id);

func _refresh_view() -> void:
	state_label.text = tr("UI_GAMEPLAY_STATE").format({"value": _get_state_label(AppContext.state)});
	level_label.text = tr("UI_GAMEPLAY_LEVEL").format({"value": _get_level_label(SessionContext.current_level_id)});
	health_label.text = tr("UI_GAMEPLAY_HEALTH").format({"value": SessionContext.player_health});
	score_label.text = tr("UI_GAMEPLAY_SCORE").format({"value": SessionContext.score});

func _load_level(level_scene_id: StringName) -> void:
	if level_root == null:
		return;
	if not Scenes.has(level_scene_id):
		return;
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
	_refresh_view();

func _get_state_label(state_value: AppState.Value) -> String:
	match state_value:
		AppState.Value.BOOT:
			return tr("UI_STATE_BOOT");
		AppState.Value.MAIN_MENU:
			return tr("UI_STATE_MAIN_MENU");
		AppState.Value.LOADING:
			return tr("UI_STATE_LOADING");
		AppState.Value.IN_GAME:
			return tr("UI_STATE_IN_GAME");
		AppState.Value.PAUSED:
			return tr("UI_STATE_PAUSED");
		_:
			return str(state_value);

func _get_level_label(level_scene_id: StringName) -> String:
	match level_scene_id:
		Scenes.LEVEL_STUB_A:
			return tr("UI_LEVEL_STUB_A_TITLE");
		Scenes.LEVEL_STUB_B:
			return tr("UI_LEVEL_STUB_B_TITLE");
		_:
			return String(level_scene_id);

func _on_damage_button_pressed() -> void:
	SessionContext.player_health = max(SessionContext.player_health - HEALTH_STEP, 0);
	_refresh_view();

func _on_heal_button_pressed() -> void:
	SessionContext.player_health += HEALTH_STEP;
	_refresh_view();

func _on_score_button_pressed() -> void:
	SessionContext.score += SCORE_STEP;
	_refresh_view();

func _on_level_a_button_pressed() -> void:
	SessionContext.current_level_id = Scenes.LEVEL_STUB_A;
	_load_level(SessionContext.current_level_id);

func _on_level_b_button_pressed() -> void:
	SessionContext.current_level_id = Scenes.LEVEL_STUB_B;
	_load_level(SessionContext.current_level_id);

func _on_save_button_pressed() -> void:
	save_requested.emit();

func _on_pause_button_pressed() -> void:
	if AppContext.state == AppState.Value.PAUSED:
		resume_requested.emit();
	else:
		pause_requested.emit();

func _on_back_button_pressed() -> void:
	back_to_menu_requested.emit();

func _on_app_state_changed(_new_state: AppState.Value) -> void:
	_refresh_view();

func _on_locale_changed(_locale: String) -> void:
	_refresh_view();

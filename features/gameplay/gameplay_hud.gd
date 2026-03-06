extends Control;
class_name GameplayHud;

signal damage_requested;
signal heal_requested;
signal score_requested;
signal level_a_requested;
signal level_b_requested;
signal pause_toggle_requested;
signal save_requested;
signal back_to_menu_requested;

@onready var state_label: Label = %StateLabel;
@onready var level_label: Label = %LevelLabel;
@onready var health_label: Label = %HealthLabel;
@onready var score_label: Label = %ScoreLabel;
@onready var damage_button: Button = %DamageButton;
@onready var heal_button: Button = %HealButton;
@onready var score_button: Button = %ScoreButton;
@onready var level_a_button: Button = %LevelAButton;
@onready var level_b_button: Button = %LevelBButton;
@onready var save_button: Button = %SaveButton;
@onready var pause_button: Button = %PauseButton;
@onready var back_button: Button = %BackButton;

var _view_model: Dictionary = {};

func _ready() -> void:
	damage_button.pressed.connect(_on_damage_button_pressed);
	heal_button.pressed.connect(_on_heal_button_pressed);
	score_button.pressed.connect(_on_score_button_pressed);
	level_a_button.pressed.connect(_on_level_a_button_pressed);
	level_b_button.pressed.connect(_on_level_b_button_pressed);
	save_button.pressed.connect(_on_save_button_pressed);
	pause_button.pressed.connect(_on_pause_button_pressed);
	back_button.pressed.connect(_on_back_button_pressed);
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed);
	_refresh_view();

func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed);

func apply_view_model(view_model: Dictionary) -> void:
	_view_model = view_model.duplicate(true);
	_refresh_view();

func _refresh_view() -> void:
	var state_value: AppState.Value = _view_model.get("state", AppContext.state);
	var level_id: StringName = _view_model.get("level_id", SessionContext.current_level_id);
	var health: int = int(_view_model.get("health", SessionContext.player_health));
	var score: int = int(_view_model.get("score", SessionContext.score));
	state_label.text = tr("UI_GAMEPLAY_STATE").format({"value": _get_state_label(state_value)});
	level_label.text = tr("UI_GAMEPLAY_LEVEL").format({"value": _get_level_label(level_id)});
	health_label.text = tr("UI_GAMEPLAY_HEALTH").format({"value": health});
	score_label.text = tr("UI_GAMEPLAY_SCORE").format({"value": score});

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
	damage_requested.emit();

func _on_heal_button_pressed() -> void:
	heal_requested.emit();

func _on_score_button_pressed() -> void:
	score_requested.emit();

func _on_level_a_button_pressed() -> void:
	level_a_requested.emit();

func _on_level_b_button_pressed() -> void:
	level_b_requested.emit();

func _on_save_button_pressed() -> void:
	save_requested.emit();

func _on_pause_button_pressed() -> void:
	pause_toggle_requested.emit();

func _on_back_button_pressed() -> void:
	back_to_menu_requested.emit();

func _on_locale_changed(_locale: String) -> void:
	_refresh_view();

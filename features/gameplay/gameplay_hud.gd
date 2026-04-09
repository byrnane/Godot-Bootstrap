extends Control;
class_name GameplayHud;

const UI_FOCUS = preload("res://shared/ui/navigation/ui_focus.gd");

signal primary_metric_decrease_requested;
signal primary_metric_increase_requested;
signal secondary_metric_increment_requested;
signal level_a_requested;
signal level_b_requested;
signal pause_toggle_requested;


@onready var state_label: Label = %StateLabel;
@onready var level_label: Label = %LevelLabel;
@onready var health_label: Label = %HealthLabel;
@onready var score_label: Label = %ScoreLabel;
@onready var damage_button: Button = %DamageButton;
@onready var heal_button: Button = %HealButton;
@onready var score_button: Button = %ScoreButton;
@onready var level_a_button: Button = %LevelAButton;
@onready var level_b_button: Button = %LevelBButton;
@onready var pause_button: Button = %PauseButton;


var _view_model: Dictionary = {};


func _ready() -> void:
	AudioManager.bind_ui_sounds(self);
	damage_button.pressed.connect(_on_damage_button_pressed);
	heal_button.pressed.connect(_on_heal_button_pressed);
	score_button.pressed.connect(_on_score_button_pressed);
	level_a_button.pressed.connect(_on_level_a_button_pressed);
	level_b_button.pressed.connect(_on_level_b_button_pressed);
	pause_button.pressed.connect(_on_pause_button_pressed);
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed);
	UI_FOCUS.apply_vertical_focus_cycle([
		damage_button,
		heal_button,
		score_button,
		level_a_button,
		level_b_button,
		pause_button,
	]);
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
	var state_key: String = AppState.to_ui_key(state_value);
	if state_key.is_empty():
		return str(state_value);
	return tr(state_key);


func _get_level_label(level_scene_id: StringName) -> String:
	match level_scene_id:
		Scenes.LEVEL_STUB_A:
			return tr("UI_LEVEL_STUB_A_TITLE");
		Scenes.LEVEL_STUB_B:
			return tr("UI_LEVEL_STUB_B_TITLE");
		_:
			return String(level_scene_id);


func _on_damage_button_pressed() -> void:
	primary_metric_decrease_requested.emit();


func _on_heal_button_pressed() -> void:
	primary_metric_increase_requested.emit();


func _on_score_button_pressed() -> void:
	secondary_metric_increment_requested.emit();


func _on_level_a_button_pressed() -> void:
	level_a_requested.emit();


func _on_level_b_button_pressed() -> void:
	level_b_requested.emit();


func _on_pause_button_pressed() -> void:
	pause_toggle_requested.emit();


func _on_locale_changed(_locale: String) -> void:
	_refresh_view();

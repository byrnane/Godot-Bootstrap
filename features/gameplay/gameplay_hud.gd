extends Control;
class_name GameplayHud;

signal primary_metric_decrease_requested;
signal primary_metric_increase_requested;
signal secondary_metric_increment_requested;
signal level_a_requested;
signal level_b_requested;
signal pause_toggle_requested;



@onready var score_counter: UiCounter = %ScoreCounter;
@onready var damage_button: Button = %DamageButton;
@onready var heal_button: Button = %HealButton;
@onready var score_button: Button = %ScoreButton;
@onready var level_a_button: Button = %LevelAButton;
@onready var level_b_button: Button = %LevelBButton;
@onready var pause_button: Button = %PauseButton;


var _view_model: Dictionary = {};


func _ready() -> void:
	if preload("res://shared/ui/theme/ui_density.gd").apply(self):
		_apply_compact_layout();
	AudioManager.bind_ui_sounds(self);
	%DemoToggle.toggled.connect(func(show_controls: bool) -> void: %DemoPanel.visible = show_controls);
	damage_button.pressed.connect(_on_damage_button_pressed);
	heal_button.pressed.connect(_on_heal_button_pressed);
	score_button.pressed.connect(_on_score_button_pressed);
	level_a_button.pressed.connect(_on_level_a_button_pressed);
	level_b_button.pressed.connect(_on_level_b_button_pressed);
	pause_button.pressed.connect(_on_pause_button_pressed);
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed);
	_refresh_view();


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed);


func _apply_compact_layout() -> void:
	var density = preload("res://shared/ui/theme/ui_density.gd");
	%Resources.custom_minimum_size.x = 252;
	%Objective.custom_minimum_size.x = 0;
	%Interaction.custom_minimum_size.x = 0;
	%Interaction.get_node("%Text").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	%Interaction.get_node("%Text").size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	density.place(%Resources, Control.PRESET_TOP_LEFT, Rect2(16, 16, 252, 0));
	density.place(%Level, Control.PRESET_TOP_LEFT, Rect2(16, 160, 252, 0));
	density.place(%ScoreCounter, Control.PRESET_TOP_RIGHT, Rect2(-172, 16, 156, 32));
	density.place(%PauseButton, Control.PRESET_TOP_RIGHT, Rect2(-48, 56, 32, 32));
	%PauseButton.custom_minimum_size = Vector2(32, 32);
	density.place(%DemoToggle, Control.PRESET_TOP_RIGHT, Rect2(-204, 104, 188, 32));
	density.place(%Objective, Control.PRESET_BOTTOM_LEFT, Rect2(16, -100, 288, 84));
	density.place(%Interaction, Control.PRESET_BOTTOM_RIGHT, Rect2(-304, -100, 288, 84));
	density.place(%TimerLabel, Control.PRESET_BOTTOM_RIGHT, Rect2(-172, -132, 156, 24));
	density.place(%DemoPanel, Control.PRESET_BOTTOM_WIDE, Rect2(16, -160, get_viewport_rect().size.x - 32, 144));
	%DemoPanel.get_node("Margin/Grid").columns = 2;


func apply_view_model(view_model: Dictionary) -> void:
	_view_model = view_model.duplicate(true);
	_refresh_view();


func _refresh_view() -> void:
	var state_value: AppState.Value = _view_model.get("state", AppState.Value.IN_GAME);
	var level_id: StringName = _view_model.get("level_id", Scenes.LEVEL_STUB_A);
	var health: int = int(_view_model.get("health", 0));
	var score: int = int(_view_model.get("score", 0));
	%Level.caption_key = AppState.to_ui_key(state_value);
	%Level.text = _get_level_label(level_id);
	var resource_values: Dictionary = _view_model.duplicate();
	resource_values["health"] = health;
	%Resources.apply_resources(resource_values);
	score_counter.value = str(score);
	%Objective.visible = _view_model.has("objective");
	%Objective.text = str(_view_model.get("objective", ""));
	%Interaction.visible = _view_model.has("interaction_text");
	%Interaction.text = str(_view_model.get("interaction_text", ""));
	%Interaction.key_text = str(_view_model.get("interaction_key", "E"));
	%TimerLabel.visible = _view_model.has("time_text");
	%TimerLabel.text = str(_view_model.get("time_text", ""));


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

extends Control;
class_name LoadingScreen;

signal intro_finished;
signal outro_finished;

const DEFAULT_PROGRESS: float = -1.0;

@export var fade_duration: float = 0.2;

@onready var backdrop: ColorRect = %Backdrop;
@onready var card: PanelContainer = %Card;
@onready var title_label: Label = %TitleLabel;
@onready var message_label: Label = %MessageLabel;
@onready var tip_label: Label = %TipLabel;
@onready var progress_bar: ProgressBar = %ProgressBar;

func _ready() -> void:
	visible = false;
	mouse_filter = Control.MOUSE_FILTER_STOP;
	process_mode = Node.PROCESS_MODE_ALWAYS;
	modulate.a = 0.0;
	card.modulate.a = 0.0;
	progress_bar.visible = false;

func show_screen(data: Dictionary = {}) -> void:
	_apply_content(data);
	visible = true;
	await _fade_to(1.0);
	intro_finished.emit();

func hide_screen() -> void:
	await _fade_to(0.0);
	visible = false;
	outro_finished.emit();

func update_progress(progress: float, status_text: String = "") -> void:
	var normalized_progress: float = clampf(progress, 0.0, 1.0);
	progress_bar.visible = progress >= 0.0;
	progress_bar.value = normalized_progress * 100.0;
	if not status_text.is_empty():
		message_label.text = status_text;

func _apply_content(data: Dictionary) -> void:
	title_label.text = String(data.get("title", tr("UI_LOADING")));
	message_label.text = String(data.get("message", tr("UI_LOADING_MESSAGE")));
	tip_label.text = String(data.get("tip", tr("UI_LOADING_TIP")));
	var progress: float = float(data.get("progress", DEFAULT_PROGRESS));
	progress_bar.visible = progress >= 0.0;
	if progress >= 0.0:
		progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0;
	else:
		progress_bar.value = 0.0;

func _fade_to(target_alpha: float) -> void:
	var tween: Tween = create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.tween_property(self, "modulate:a", target_alpha, fade_duration);
	tween.parallel().tween_property(card, "modulate:a", target_alpha, fade_duration);
	await tween.finished;

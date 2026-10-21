extends PanelContainer;

func _ready() -> void:
	%Result.configure(tr("UI_RESULT_WIN"), tr("UI_RESULT_MESSAGE"), {
		tr("UI_RESOURCE_HEALTH"): "80 / 100",
		tr("UI_RESOURCE_MANA"): "18 / 100",
		tr("UI_RESOURCE_STAMINA"): "0 / 100",
	}, tr("UI_CONTINUE"), tr("UI_BACK_TO_MENU"));
	%ToastButton.pressed.connect(func() -> void:
		UiFeedback.toast(tr("UI_RESULT_MESSAGE"), {"variant": "success"}));
	%DialogButton.pressed.connect(func() -> void:
		UiFeedback.confirm(tr("UI_RESULT_MESSAGE"), Callable(), Callable()));


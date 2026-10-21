extends "res://features/ui/modals/settings_modal.gd"

func _ready() -> void:
	super._ready()
	var content: Node = autosave_enabled_check_box.get_parent().get_parent().get_parent()
	var advanced: Array[Control] = []
	for child: Node in content.get_children():
		if child.name in ["AutosaveIntervalRow", "AutosaveOnExitRow", "AutosaveOnCheckpointRow", "AutosaveThumbnailRow"]:
			advanced.append(child)
			child.hide()
		elif child.name == "AutosaveScoreStepRow":
			child.hide()
	var toggle: CheckBox = CheckBox.new()
	toggle.text = "UI_FOREST_ADVANCED_SHOW"
	toggle.toggled.connect(func(show_advanced: bool) -> void:
		for row: Control in advanced:
			row.visible = show_advanced
	)
	content.add_child(toggle)
	content.move_child(toggle, 2)

extends "res://features/ui/modals/save_slots_modal.gd"

func _refresh_mode_state() -> void:
	super._refresh_mode_state()
	mode_hint_label.text = tr("UI_FOREST_SAVE_NOTE")

func _refresh_selection_state() -> void:
	super._refresh_selection_state()
	preview_texture_rect.visible = preview_texture_rect.texture != null
	slot_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_hint_label.text = tr("UI_FOREST_SAVE_NOTE")
	var entry: Dictionary = _get_selected_entry()
	slot_score_label.visible = not entry.is_empty()
	if entry.is_empty():
		return
	var data: SaveData = SaveManager.load_game_from_descriptor(entry.descriptor)
	if data == null:
		return
	var profile: Dictionary = ForestData.profile_from_save(data)
	var descriptions: PackedStringArray = []
	for mode: String in ForestData.MODES:
		var progress: Dictionary = profile.progress[mode]
		var status: String = tr("UI_FOREST_NOT_STARTED")
		if progress.started:
			status = tr("UI_FOREST_COMPLETE") if progress.completed else tr("UI_FOREST_STAGE") % (int(progress.stage) + 1)
		descriptions.append(tr(ForestData.TITLES[mode]) + ": " + status)
	slot_level_label.text = "\n".join(descriptions)

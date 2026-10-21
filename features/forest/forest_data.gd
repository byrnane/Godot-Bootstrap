extends RefCounted
class_name ForestData

const MODES: Array[String] = ["platformer", "shooter", "puzzle"]
const TITLES: Dictionary = {"platformer": "UI_FOREST_TRAIL", "shooter": "UI_FOREST_DEFENSE", "puzzle": "UI_FOREST_RUINS"}

static func normalized(source: Dictionary, legacy_level: StringName = &"level_stub_a") -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	var mode: String = str(data.get("mode_id", "platformer"))
	if mode not in MODES:
		mode = "platformer"
	data["mode_id"] = mode
	data["revision"] = maxi(0, _integer(data.get("revision", 0)))
	var progress: Variant = data.get("progress", {})
	if not progress is Dictionary:
		progress = {}
	for key: String in MODES:
		var entry: Variant = progress.get(key, {})
		if not entry is Dictionary:
			entry = {}
		var default_stage: int = 1 if source.is_empty() and key == "platformer" and legacy_level == &"level_stub_b" else 0
		progress[key] = {
			"stage": clampi(_integer(entry.get("stage", default_stage), default_stage), 0, 2),
			"checkpoint": clampi(_integer(entry.get("checkpoint", 0)), 0, 1) if key == "platformer" else 0,
			"score": maxi(0, _integer(entry.get("score", 0))),
			"completed": _boolean(entry.get("completed", false)),
			"started": _boolean(entry.get("started", false)),
			"collected": _collected_ids(entry.get("collected", [])),
		}
	data["progress"] = progress
	return data

static func _integer(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is String and value.is_valid_int():
		return int(value)
	return fallback

static func _boolean(value: Variant) -> bool:
	return value if value is bool else false

static func profile_from_save(saved: SaveData) -> Dictionary:
	var data: Dictionary = normalized(saved.game_data, saved.current_level_id)
	if saved.game_data.is_empty() and saved.session_exists:
		data.progress.platformer.started = true
		data.progress.platformer.score = saved.score
	return data

static func _collected_ids(value: Variant) -> Array[int]:
	var ids: Array[int] = []
	if value is Array:
		for id: Variant in value:
			if id is int and id in [0, 1, 2] and not ids.has(id):
				ids.append(id)
	return ids

static func menu_profile() -> Dictionary:
	if SessionContext.session_exists:
		return profile_from_save(SessionContext.to_save_data()) if not SessionContext.is_new_session else normalized(SessionContext.game_data, SessionContext.current_level_id)
	var saved: SaveData = SaveManager.load_latest_for_continue()
	return profile_from_save(saved) if saved != null else normalized({})

static func start_params(mode: String, restart: bool = false) -> SessionStartParams:
	var params: SessionStartParams = SessionStartParams.new()
	params.mode = SessionStartParams.Mode.RESUME_OR_CONTINUE_OR_NEW
	params.payload_data = {"mode_id": mode, "restart_mode": restart}
	return params

static func input_available() -> bool:
	return AppContext.state == AppState.Value.IN_GAME and not InputManager.is_rebinding() and not UiShell.has_open_modals()

extends Node;

signal autosave_completed(reason: StringName, success: bool);


const REASON_TIMER: StringName = &"timer";
const REASON_EXIT: StringName = &"exit";
const REASON_CHECKPOINT: StringName = &"checkpoint";
const MIN_INTERVAL_SECONDS: int = 15;
const MAX_INTERVAL_SECONDS: int = 3600;
const MIN_COOLDOWN_SECONDS: float = 2.0;
const MAX_CHECKPOINT_TOKENS: int = 64;


var _timer: Timer = null;
var _session_active: bool = false;
var _last_autosave_time_sec: float = -9999.0;
var _checkpoint_tokens: Dictionary = {};
var _checkpoint_order: Array[String] = [];
var _last_score_bucket: int = -1;


func _ready() -> void:
	_timer = Timer.new();
	_timer.one_shot = false;
	_timer.autostart = false;
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS;
	_timer.timeout.connect(_on_autosave_timer_timeout);
	add_child(_timer);

	if SettingsManager != null and not SettingsManager.settings_applied.is_connected(_on_settings_applied):
		SettingsManager.settings_applied.connect(_on_settings_applied);


func start_for_session() -> void:
	_session_active = true;
	_checkpoint_tokens.clear();
	_checkpoint_order.clear();
	_last_score_bucket = _compute_score_bucket(SessionContext.score);
	_refresh_timer_state();


func stop_for_session() -> void:
	_session_active = false;
	_checkpoint_tokens.clear();
	_checkpoint_order.clear();
	_last_score_bucket = -1;
	if _timer != null:
		_timer.stop();


func refresh_policy() -> void:
	_refresh_timer_state();


func request_autosave(reason: StringName, payload: Dictionary = {}) -> bool:
	if not _can_autosave(reason):
		return false;
	if _is_in_cooldown():
		return false;

	var options: Dictionary = {
		"reason": String(reason),
		"capture_thumbnail": _is_thumbnail_capture_enabled(),
	};
	if payload.has("title"):
		options["title"] = String(payload.get("title", ""));
	var is_success: bool = SaveManager.save_current_session_autosave(options);
	if is_success:
		_last_autosave_time_sec = Time.get_unix_time_from_system();
	autosave_completed.emit(reason, is_success);
	return is_success;


func emit_checkpoint(checkpoint_id: String, payload: Dictionary = {}) -> bool:
	if checkpoint_id.strip_edges().is_empty():
		return false;
	if not _is_checkpoint_enabled():
		return false;
	var checkpoint_token: String = "%s|%s" % [checkpoint_id, JSON.stringify(payload, "", false)];
	if _checkpoint_tokens.has(checkpoint_token):
		return false;
	_checkpoint_tokens[checkpoint_token] = true;
	_checkpoint_order.append(checkpoint_token);
	while _checkpoint_order.size() > MAX_CHECKPOINT_TOKENS:
		var stale_token: String = _checkpoint_order.pop_front();
		_checkpoint_tokens.erase(stale_token);
	return request_autosave(REASON_CHECKPOINT, payload);


func notify_score_changed(score: int) -> void:
	if not _is_checkpoint_enabled():
		return;
	var score_bucket: int = _compute_score_bucket(score);
	if score_bucket <= 0:
		return;
	if score_bucket <= _last_score_bucket:
		return;
	_last_score_bucket = score_bucket;
	emit_checkpoint("score_step_%d" % [score_bucket], {
		"score": score,
		"bucket": score_bucket,
	});


func _on_autosave_timer_timeout() -> void:
	request_autosave(REASON_TIMER);


func _on_settings_applied(_settings: UserSettings) -> void:
	_refresh_timer_state();


func _refresh_timer_state() -> void:
	if _timer == null:
		return;
	if not _session_active:
		_timer.stop();
		return;
	if not _is_timer_enabled():
		_timer.stop();
		return;
	_timer.wait_time = float(_get_autosave_interval_seconds());
	if _timer.is_stopped():
		_timer.start();


func _can_autosave(reason: StringName) -> bool:
	if not _session_active:
		return false;
	if AppContext == null or AppContext.settings == null:
		return false;
	if not AppContext.settings.autosave_enabled:
		return false;
	if AppContext.state != AppState.Value.IN_GAME and AppContext.state != AppState.Value.PAUSED:
		return false;
	match reason:
		REASON_TIMER:
			return _is_timer_enabled();
		REASON_EXIT:
			return bool(AppContext.settings.autosave_on_exit);
		REASON_CHECKPOINT:
			return bool(AppContext.settings.autosave_on_checkpoint);
	return false;


func _is_in_cooldown() -> bool:
	return Time.get_unix_time_from_system() - _last_autosave_time_sec < MIN_COOLDOWN_SECONDS;


func _is_timer_enabled() -> bool:
	if AppContext == null or AppContext.settings == null:
		return false;
	return AppContext.settings.autosave_enabled and _get_autosave_interval_seconds() >= MIN_INTERVAL_SECONDS;


func _is_checkpoint_enabled() -> bool:
	if AppContext == null or AppContext.settings == null:
		return false;
	return AppContext.settings.autosave_enabled and AppContext.settings.autosave_on_checkpoint;


func _is_thumbnail_capture_enabled() -> bool:
	return AppContext != null and AppContext.settings != null and bool(AppContext.settings.autosave_capture_thumbnail);


func _compute_score_bucket(score: int) -> int:
	var score_step: int = _get_score_step();
	if score_step <= 0:
		return -1;
	return int(floor(float(score) / float(score_step)));


func _get_autosave_interval_seconds() -> int:
	if AppContext == null or AppContext.settings == null:
		return MIN_INTERVAL_SECONDS;
	return clampi(AppContext.settings.autosave_interval_seconds, MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS);


func _get_score_step() -> int:
	if AppContext == null or AppContext.settings == null:
		return 100;
	return maxi(1, AppContext.settings.autosave_score_step);

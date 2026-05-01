extends Node;


const MASTER_BUS_NAME: String = "Master";
const MUSIC_BUS_NAME: String = "Music";
const UI_BUS_NAME: String = "UI";
const SFX_BUS_NAME: String = "SFX";
const MIN_LINEAR_VOLUME: float = 0.0001;
const SILENT_DB: float = -80.0;
const DEFAULT_MUSIC_FADE_DURATION: float = 0.6;
const DEFAULT_ONE_SHOT_PITCH: float = 1.0;
const DEFAULT_ONE_SHOT_VOLUME_DB: float = 0.0;
const MUSIC_PLAYER_COUNT: int = 2;
const DEFAULT_UI_HOVER_STREAM: AudioStream = preload("res://assets/sfx/btn_hover.ogg");
const DEFAULT_UI_CLICK_STREAM: AudioStream = preload("res://assets/sfx/btn_click.ogg");
const UI_SOUND_BOUND_META_KEY: StringName = &"_ui_sound_bound";


var _music_players: Array[AudioStreamPlayer] = [];
var _music_tweens: Array[Tween] = [];
var _active_music_player_index: int = -1;
var _one_shot_root: Node = null;


func _ready() -> void:
	_ensure_bus_layout();
	_ensure_runtime_players();
	apply_from_settings();


func _exit_tree() -> void:
	_release_runtime_players();


func apply_from_settings() -> void:
	AppContext.ensure_defaults();
	for bus_settings: Array in [
		[MASTER_BUS_NAME, AppContext.settings.master_volume],
		[MUSIC_BUS_NAME, AppContext.settings.music_volume],
		[UI_BUS_NAME, AppContext.settings.ui_volume],
		[SFX_BUS_NAME, AppContext.settings.sfx_volume],
	]:
		_apply_bus_volume(String(bus_settings[0]), float(bus_settings[1]));


func play_music(source: Variant, options: Dictionary = {}) -> void:
	_ensure_runtime_players();
	var stream: AudioStream = _resolve_stream(source);
	if stream == null:
		return;
	if _is_music_stream_already_active(stream):
		return;

	var fade_duration: float = maxf(float(options.get("fade_duration", DEFAULT_MUSIC_FADE_DURATION)), 0.0);
	var from_position: float = maxf(float(options.get("from_position", 0.0)), 0.0);
	var target_volume_db: float = float(options.get("volume_db", DEFAULT_ONE_SHOT_VOLUME_DB));
	var next_player_index: int = _get_next_music_player_index();
	var next_player: AudioStreamPlayer = _music_players[next_player_index];
	var previous_player: AudioStreamPlayer = _get_active_music_player();

	_stop_music_tween(next_player_index);
	next_player.stop();
	next_player.stream = stream;
	next_player.bus = MUSIC_BUS_NAME;
	next_player.volume_db = SILENT_DB if fade_duration > 0.0 else target_volume_db;
	next_player.play(from_position);

	if fade_duration > 0.0:
		_music_tweens[next_player_index] = create_tween();
		_music_tweens[next_player_index].tween_property(next_player, "volume_db", target_volume_db, fade_duration);
	else:
		next_player.volume_db = target_volume_db;

	if previous_player != null and previous_player.playing:
		_stop_music_player(previous_player, _active_music_player_index, fade_duration);

	_active_music_player_index = next_player_index;


func stop_music(fade_duration: float = DEFAULT_MUSIC_FADE_DURATION) -> void:
	var active_player: AudioStreamPlayer = _get_active_music_player();
	if active_player == null or not active_player.playing:
		return;

	_stop_music_player(active_player, _active_music_player_index, fade_duration);
	_active_music_player_index = -1;


func play_ui(source: Variant, options: Dictionary = {}) -> AudioStreamPlayer:
	return _play_one_shot(source, UI_BUS_NAME, options);


func play_sfx(source: Variant, options: Dictionary = {}) -> AudioStreamPlayer:
	return _play_one_shot(source, SFX_BUS_NAME, options);


func play_ui_click() -> AudioStreamPlayer:
	return play_ui(DEFAULT_UI_CLICK_STREAM);


func play_ui_hover() -> AudioStreamPlayer:
	return play_ui(DEFAULT_UI_HOVER_STREAM, {"volume_db": -2.0});


func bind_ui_sounds(root: Node) -> void:
	if root == null:
		return;

	for child: Node in root.get_children():
		bind_ui_sounds(child);

	var button: BaseButton = root as BaseButton;
	if button == null:
		return;
	if button.has_meta(UI_SOUND_BOUND_META_KEY):
		return;

	button.pressed.connect(_on_ui_button_pressed.bind(button));
	button.mouse_entered.connect(_on_ui_button_hovered.bind(button));
	button.set_meta(UI_SOUND_BOUND_META_KEY, true);


func _ensure_bus_layout() -> void:
	var bus_order: Array[String] = [
		MUSIC_BUS_NAME,
		UI_BUS_NAME,
		SFX_BUS_NAME,
	];
	for bus_position: int in range(bus_order.size()):
		var bus_name: String = bus_order[bus_position];
		var expected_index: int = bus_position + 1;
		var bus_index: int = AudioServer.get_bus_index(bus_name);
		if bus_index < 0:
			AudioServer.add_bus(expected_index);
			AudioServer.set_bus_name(expected_index, bus_name);
			bus_index = expected_index;
		AudioServer.set_bus_send(bus_index, MASTER_BUS_NAME);


func _ensure_runtime_players() -> void:
	if _music_players.is_empty():
		for player_index: int in range(MUSIC_PLAYER_COUNT):
			var music_player: AudioStreamPlayer = AudioStreamPlayer.new();
			music_player.name = "MusicPlayer%d" % [player_index];
			music_player.bus = MUSIC_BUS_NAME;
			music_player.volume_db = SILENT_DB;
			music_player.process_mode = Node.PROCESS_MODE_ALWAYS;
			add_child(music_player);
			_music_players.append(music_player);
			_music_tweens.append(null);

	if _one_shot_root == null:
		_one_shot_root = Node.new();
		_one_shot_root.name = "OneShotPlayers";
		add_child(_one_shot_root);


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name);
	if bus_index < 0:
		return;

	var safe_volume: float = max(linear_volume, MIN_LINEAR_VOLUME);
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume));


func _play_one_shot(source: Variant, bus_name: String, options: Dictionary = {}) -> AudioStreamPlayer:
	_ensure_runtime_players();
	var stream: AudioStream = _resolve_stream(source);
	if stream == null or _one_shot_root == null:
		return null;

	var player: AudioStreamPlayer = AudioStreamPlayer.new();
	player.stream = stream;
	player.bus = bus_name;
	player.volume_db = float(options.get("volume_db", DEFAULT_ONE_SHOT_VOLUME_DB));
	player.pitch_scale = float(options.get("pitch_scale", DEFAULT_ONE_SHOT_PITCH));
	player.process_mode = Node.PROCESS_MODE_ALWAYS;
	_one_shot_root.add_child(player);
	player.finished.connect(_on_one_shot_finished.bind(player), CONNECT_ONE_SHOT);
	player.play(maxf(float(options.get("from_position", 0.0)), 0.0));
	return player;


func _resolve_stream(source: Variant) -> AudioStream:
	if source is AudioStream:
		return source as AudioStream;

	if source is String:
		var loaded_resource: Resource = load(String(source));
		return loaded_resource as AudioStream;

	return null;


func _get_active_music_player() -> AudioStreamPlayer:
	if _active_music_player_index < 0 or _active_music_player_index >= _music_players.size():
		return null;
	return _music_players[_active_music_player_index];


func _get_next_music_player_index() -> int:
	if _music_players.size() < 2:
		return 0;
	if _active_music_player_index < 0:
		return 0;
	return 1 - _active_music_player_index;


func _is_music_stream_already_active(stream: AudioStream) -> bool:
	var active_player: AudioStreamPlayer = _get_active_music_player();
	if active_player == null:
		return false;
	return active_player.playing and active_player.stream == stream;


func _stop_music_player(player: AudioStreamPlayer, player_index: int, fade_duration: float) -> void:
	if player == null:
		return;

	_stop_music_tween(player_index);
	if fade_duration <= 0.0:
		player.stop();
		player.volume_db = SILENT_DB;
		return;

	_music_tweens[player_index] = create_tween();
	_music_tweens[player_index].tween_property(player, "volume_db", SILENT_DB, fade_duration);
	_music_tweens[player_index].finished.connect(_on_music_fade_out_finished.bind(player, player_index), CONNECT_ONE_SHOT);


func _stop_music_tween(player_index: int) -> void:
	if player_index < 0 or player_index >= _music_tweens.size():
		return;
	var tween: Tween = _music_tweens[player_index];
	if tween == null:
		return;
	if tween.is_running():
		tween.kill();
	_music_tweens[player_index] = null;


func _on_ui_button_pressed(button: BaseButton) -> void:
	if button == null or button.disabled:
		return;
	play_ui_click();


func _on_ui_button_hovered(button: BaseButton) -> void:
	if button == null or button.disabled:
		return;
	play_ui_hover();


func _on_music_fade_out_finished(player: AudioStreamPlayer, player_index: int) -> void:
	if player == null:
		return;
	player.stop();
	player.volume_db = SILENT_DB;
	if player_index >= 0 and player_index < _music_tweens.size():
		_music_tweens[player_index] = null;


func _on_one_shot_finished(player: AudioStreamPlayer) -> void:
	if player == null:
		return;
	if player.get_parent() != null:
		player.get_parent().remove_child(player);
	player.queue_free();


func _release_runtime_players() -> void:
	for tween_index: int in range(_music_tweens.size()):
		_stop_music_tween(tween_index);

	for player: AudioStreamPlayer in _music_players:
		if player == null:
			continue;
		player.stop();
		player.stream = null;
		if player.get_parent() != null:
			player.get_parent().remove_child(player);
		player.queue_free();

	if _one_shot_root != null:
		for child: Node in _one_shot_root.get_children():
			var player: AudioStreamPlayer = child as AudioStreamPlayer;
			if player != null:
				player.stop();
				player.stream = null;
			_one_shot_root.remove_child(child);
			child.queue_free();
		if _one_shot_root.get_parent() != null:
			_one_shot_root.get_parent().remove_child(_one_shot_root);
		_one_shot_root.queue_free();
		_one_shot_root = null;

	_active_music_player_index = -1;
	_music_players.clear();
	_music_tweens.clear();

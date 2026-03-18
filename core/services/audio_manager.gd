extends Node;

const MASTER_BUS_NAME: String = "Master";
const MUSIC_BUS_NAME: String = "Music";
const SFX_BUS_NAME: String = "SFX";
const MIN_LINEAR_VOLUME: float = 0.0001;


func _ready() -> void:
	apply_from_settings();


func apply_from_settings() -> void:
	AppContext.ensure_defaults();
	for bus_settings: Array in [
		[MASTER_BUS_NAME, AppContext.settings.master_volume],
		[MUSIC_BUS_NAME, AppContext.settings.music_volume],
		[SFX_BUS_NAME, AppContext.settings.sfx_volume],
	]:
		_apply_bus_volume(String(bus_settings[0]), float(bus_settings[1]));


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name);
	if bus_index < 0:
		return;

	var safe_volume: float = max(linear_volume, MIN_LINEAR_VOLUME);
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume));

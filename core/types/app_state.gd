extends RefCounted;
class_name AppState;

enum Value {
	BOOT,
	MAIN_MENU,
	LOADING,
	IN_GAME,
	PAUSED,
}

const _STATE_UI_KEYS: Dictionary = {
	Value.BOOT: "UI_STATE_BOOT",
	Value.MAIN_MENU: "UI_STATE_MAIN_MENU",
	Value.LOADING: "UI_STATE_LOADING",
	Value.IN_GAME: "UI_STATE_IN_GAME",
	Value.PAUSED: "UI_STATE_PAUSED",
};


static func to_ui_key(state_value: Value) -> String:
	return String(_STATE_UI_KEYS.get(state_value, ""));

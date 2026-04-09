extends RefCounted;
class_name SessionStartParams;


enum Mode {
	NEW_GAME,
	CONTINUE_ONLY,
	CONTINUE_OR_NEW,
}


var mode: int = Mode.NEW_GAME;
var gameplay_scene_id: StringName = &"";
var payload_data: Dictionary = {};

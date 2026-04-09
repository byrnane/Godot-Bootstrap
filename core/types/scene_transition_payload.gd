extends RefCounted;
class_name SceneTransitionPayload;


enum Kind {
	UNSPECIFIED,
	STARTUP,
	NEW_GAME,
	CONTINUE_GAME,
	RETURN_TO_MENU,
	RELOAD,
}


var source_scene_id: StringName = &"";
var target_scene_id: StringName = &"";
var kind: int = Kind.UNSPECIFIED;
var data: Dictionary = {};

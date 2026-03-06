extends RefCounted;
class_name Scenes;

const MAIN_MENU: StringName = &"main_menu";
const GAMEPLAY: StringName = &"gameplay";
const LEVEL_STUB_A: StringName = &"level_stub_a";
const LEVEL_STUB_B: StringName = &"level_stub_b";

const _SCENE_PATHS: Dictionary = {
	MAIN_MENU: "res://features/main_menu/main_menu.tscn",
	GAMEPLAY: "res://features/gameplay/gameplay_stub.tscn",
	LEVEL_STUB_A: "res://features/levels/level_stub_a.tscn",
	LEVEL_STUB_B: "res://features/levels/level_stub_b.tscn",
};

static func get_scene_path(scene_id: StringName) -> String:
	return _SCENE_PATHS.get(scene_id, "");

static func has(scene_id: StringName) -> bool:
	return _SCENE_PATHS.has(scene_id);

static func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = [];
	for scene_id in _SCENE_PATHS.keys():
		ids.append(scene_id);
	return ids;

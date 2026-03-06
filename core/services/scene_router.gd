extends Node;

signal scene_will_change(scene_id: StringName);
signal scene_changed(scene_id: StringName, scene_root: Node);

const EMPTY_SCENE_PATH: String = "";

@export var default_scene_id: StringName = Scenes.MAIN_MENU;

var current_scene_id: StringName = &"";
var current_scene_root: Node = null;
var _root_container: Node = null;

func configure(root_container: Node) -> void:
	_root_container = root_container;

func has_container() -> bool:
	return _root_container != null;

func go_to(scene_id: StringName, payload: Variant = null) -> Node:
	if not has_container():
		push_error("SceneRouter: root container is not configured.");
		return null;

	var resolved_scene_id: StringName = scene_id;
	if not Scenes.has(resolved_scene_id):
		resolved_scene_id = default_scene_id;

	var scene_path: String = Scenes.get_scene_path(resolved_scene_id);
	if scene_path == EMPTY_SCENE_PATH:
		push_error("SceneRouter: scene path is empty for id '%s'." % [String(resolved_scene_id)]);
		return null;

	scene_will_change.emit(resolved_scene_id);
	_call_on_exit(current_scene_root);
	_clear_container();

	var packed_scene: PackedScene = load(scene_path) as PackedScene;
	if packed_scene == null:
		push_error("SceneRouter: failed to load scene '%s'." % [scene_path]);
		return null;

	var scene_instance: Node = packed_scene.instantiate();
	if scene_instance == null:
		push_error("SceneRouter: failed to instantiate scene '%s'." % [scene_path]);
		return null;

	_root_container.add_child(scene_instance);
	current_scene_id = resolved_scene_id;
	current_scene_root = scene_instance;
	_call_on_enter(scene_instance, payload);
	scene_changed.emit(current_scene_id, current_scene_root);
	return current_scene_root;

func reload_current_scene(payload: Variant = null) -> Node:
	if current_scene_id == StringName():
		return go_to(default_scene_id, payload);

	return go_to(current_scene_id, payload);

func _clear_container() -> void:
	if _root_container == null:
		return;

	for child: Node in _root_container.get_children():
		_root_container.remove_child(child);
		child.queue_free();

func _call_on_enter(target: Node, payload: Variant) -> void:
	if target == null:
		return;

	if target.has_method("on_enter"):
		target.call("on_enter", payload);

func _call_on_exit(target: Node) -> void:
	if target == null:
		return;

	if target.has_method("on_exit"):
		target.call("on_exit");

extends Node;

signal scene_will_change(scene_id: StringName);
signal scene_load_started(scene_id: StringName);
signal scene_load_progress(scene_id: StringName, progress: float);
signal scene_load_failed(scene_id: StringName, error_text: String);
signal scene_changed(scene_id: StringName, scene_root: Node);


const EMPTY_SCENE_PATH: String = "";

@export var default_scene_id: StringName = Scenes.MAIN_MENU;


var current_scene_id: StringName = &"";
var current_scene_root: Node = null;
var _root_container: Node = null;
var _is_loading: bool = false;


func configure(root_container: Node) -> void:
	_root_container = root_container;


func has_container() -> bool:
	return _root_container != null;


func go_to(scene_id: StringName, payload: Variant = null) -> Node:
	if _is_loading:
		return null;

	if not has_container():
		push_error("SceneRouter: root container is not configured.");
		return null;

	call_deferred("_go_to_async", scene_id, payload);
	return null;


func is_loading() -> bool:
	return _is_loading;


func _go_to_async(scene_id: StringName, payload: Variant = null) -> void:
	var resolved_scene_id: StringName = scene_id;
	if not Scenes.has(resolved_scene_id):
		resolved_scene_id = default_scene_id;

	var scene_path: String = Scenes.get_scene_path(resolved_scene_id);
	if scene_path == EMPTY_SCENE_PATH:
		push_error("SceneRouter: scene path is empty for id '%s'." % [String(resolved_scene_id)]);
		return;

	_is_loading = true;
	scene_load_started.emit(resolved_scene_id);
	await TransitionManager.begin_loading({
		"title": tr("UI_LOADING"),
		"message": tr("UI_LOADING_MESSAGE"),
		"tip": tr("UI_LOADING_TIP"),
	});

	var load_request: Error = ResourceLoader.load_threaded_request(scene_path);
	if load_request != OK:
		await _fail_scene_load(resolved_scene_id, scene_path, "failed to request threaded load");
		return;

	var progress: Array = [];
	while true:
		progress.clear();
		var load_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path, progress);
		match load_status:
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
				var normalized_progress: float = 0.0;
				if not progress.is_empty():
					normalized_progress = float(progress[0]);
				scene_load_progress.emit(resolved_scene_id, normalized_progress);
				TransitionManager.update_loading_progress(normalized_progress);
				await get_tree().process_frame;
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
				break;
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
				await _fail_scene_load(resolved_scene_id, scene_path, "threaded load failed");
				return;
			_:
				await get_tree().process_frame;

	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene;
	if packed_scene == null:
		await _fail_scene_load(resolved_scene_id, scene_path, "failed to load scene");
		return;

	# Exit hooks run before the node is freed so the outgoing scene can detach
	# from services while its tree is still intact.
	scene_will_change.emit(resolved_scene_id);
	_call_on_exit(current_scene_root);
	_unmount_scene_hud(current_scene_root);
	_clear_container();

	var scene_instance: Node = packed_scene.instantiate();
	if scene_instance == null:
		push_error("SceneRouter: failed to instantiate scene '%s'." % [scene_path]);
		await TransitionManager.fail_loading(tr("UI_LOADING_ERROR"));
		_is_loading = false;
		return;

	_root_container.add_child(scene_instance);
	current_scene_id = resolved_scene_id;
	current_scene_root = scene_instance;
	# HUD is mounted before on_enter so scene code can push an initial snapshot
	# into an already-existing presentation layer.
	_mount_scene_hud(scene_instance);
	_call_on_enter(scene_instance, payload);
	scene_changed.emit(current_scene_id, current_scene_root);
	TransitionManager.update_loading_progress(1.0);
	await TransitionManager.finish_loading();
	_is_loading = false;


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


func _mount_scene_hud(target: Node) -> void:
	if target == null or UiShell == null:
		return;
	var hud_scene: PackedScene = _get_scene_hud_scene(target);
	if hud_scene == null:
		UiShell.clear_hud();
		return;
	var hud_instance: Control = UiShell.set_hud_scene(hud_scene);
	if hud_instance == null:
		return;
	if target.has_method("bind_hud"):
		target.call("bind_hud", hud_instance);


func _unmount_scene_hud(target: Node) -> void:
	if UiShell == null:
		return;
	var hud_instance: Control = UiShell.get_current_hud();
	if target != null and hud_instance != null and target.has_method("unbind_hud"):
		target.call("unbind_hud", hud_instance);
	UiShell.clear_hud();


func _get_scene_hud_scene(target: Node) -> PackedScene:
	if target == null or not target.has_method("get_hud_scene"):
		return null;
	return target.call("get_hud_scene") as PackedScene;


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


func _fail_scene_load(scene_id: StringName, scene_path: String, reason: String) -> void:
	var error_text: String = tr("UI_LOADING_ERROR");
	scene_load_failed.emit(scene_id, error_text);
	push_error("SceneRouter: %s for '%s'." % [reason, scene_path]);
	await TransitionManager.fail_loading(error_text);
	_is_loading = false;

extends Node;

signal scene_will_change(scene_id: StringName);
signal scene_load_started(scene_id: StringName);
signal scene_load_progress(scene_id: StringName, progress: float);
signal scene_load_failed(scene_id: StringName, error_text: String);
signal scene_changed(scene_id: StringName, scene_root: Node);


const EMPTY_SCENE_PATH: String = "";
const SCENE_TRANSITION_PAYLOAD_TYPE = preload("res://core/types/scene_transition_payload.gd");

@export var default_scene_id: StringName = Scenes.MAIN_MENU;


var current_scene_id: StringName = &"";
var current_scene_root: Node = null;
var _root_container: Node = null;
var _is_loading: bool = false;
var _state_before_loading: AppState.Value = AppState.Value.BOOT;
var _should_restore_state_after_loading: bool = false;
var _reported_unknown_scene_ids: Dictionary = {};
var _reported_scene_contract_issues: Dictionary = {};


func configure(root_container: Node) -> void:
	_root_container = root_container;


func has_container() -> bool:
	return _root_container != null;


func go_to(scene_id: StringName, payload: SCENE_TRANSITION_PAYLOAD_TYPE = null) -> Node:
	if _is_loading:
		push_warning("SceneRouter: ignored go_to('%s') while a scene is already loading." % [String(scene_id)]);
		return null;

	if not has_container():
		push_error("SceneRouter: root container is not configured.");
		return null;

	call_deferred("_go_to_async", scene_id, payload);
	return null;


func is_loading() -> bool:
	return _is_loading;


func _go_to_async(scene_id: StringName, payload: SCENE_TRANSITION_PAYLOAD_TYPE = null) -> void:
	var resolved_scene_id: StringName = scene_id;
	if not Scenes.has(resolved_scene_id):
		_warn_unknown_scene_id(resolved_scene_id);
		resolved_scene_id = default_scene_id;
	var transition_payload: SCENE_TRANSITION_PAYLOAD_TYPE = _resolve_transition_payload(resolved_scene_id, payload);

	var scene_path: String = Scenes.get_scene_path(resolved_scene_id);
	if scene_path == EMPTY_SCENE_PATH:
		push_error("SceneRouter: scene path is empty for id '%s'." % [String(resolved_scene_id)]);
		return;

	_is_loading = true;
	_begin_loading_state();
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

	var scene_instance: Node = packed_scene.instantiate();
	if scene_instance == null:
		push_error("SceneRouter: failed to instantiate scene '%s'." % [scene_path]);
		await TransitionManager.fail_loading(tr("UI_LOADING_ERROR"));
		_restore_state_after_loading();
		_is_loading = false;
		return;

	# Exit hooks run before the node is freed so the outgoing scene can detach
	# from services while its tree is still intact.
	scene_will_change.emit(resolved_scene_id);
	_call_on_exit(current_scene_root);
	_unmount_scene_hud(current_scene_root);
	_clear_container();

	_root_container.add_child(scene_instance);
	current_scene_id = resolved_scene_id;
	current_scene_root = scene_instance;
	# HUD is mounted before on_enter so scene code can push an initial snapshot
	# into an already-existing presentation layer.
	_mount_scene_hud(scene_instance);
	_call_on_enter(scene_instance, transition_payload);
	scene_changed.emit(current_scene_id, current_scene_root);
	TransitionManager.update_loading_progress(1.0);
	await TransitionManager.finish_loading();
	_restore_state_after_loading();
	_is_loading = false;


func reload_current_scene(payload: SCENE_TRANSITION_PAYLOAD_TYPE = null) -> Node:
	if current_scene_id == StringName():
		var fallback_payload: SCENE_TRANSITION_PAYLOAD_TYPE = payload;
		if fallback_payload == null:
			fallback_payload = _create_transition_payload(default_scene_id, current_scene_id, SCENE_TRANSITION_PAYLOAD_TYPE.Kind.RELOAD);
		return go_to(default_scene_id, fallback_payload);

	if payload == null:
		payload = _create_transition_payload(current_scene_id, current_scene_id, SCENE_TRANSITION_PAYLOAD_TYPE.Kind.RELOAD);
	return go_to(current_scene_id, payload);


func _clear_container() -> void:
	if _root_container == null:
		return;

	for child: Node in _root_container.get_children():
		_root_container.remove_child(child);
		child.queue_free();
	current_scene_id = &"";
	current_scene_root = null;


func _mount_scene_hud(target: Node) -> void:
	if target == null or UiShell == null:
		return;
	_validate_scene_hud_contract(target);
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
	_validate_scene_hud_contract(target);
	var hud_instance: Control = UiShell.get_current_hud();
	if target != null and hud_instance != null and target.has_method("unbind_hud"):
		target.call("unbind_hud", hud_instance);
	UiShell.clear_hud();


func _get_scene_hud_scene(target: Node) -> PackedScene:
	if target == null or not target.has_method("get_hud_scene"):
		return null;
	var hud_scene_candidate: Variant = target.call("get_hud_scene");
	if hud_scene_candidate == null:
		return null;
	var hud_scene: PackedScene = hud_scene_candidate as PackedScene;
	if hud_scene != null:
		return hud_scene;
	_warn_scene_contract_issue(target, "get_hud_scene", "must return PackedScene or null");
	return null;


func _call_on_enter(target: Node, payload: SCENE_TRANSITION_PAYLOAD_TYPE) -> void:
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
	_restore_state_after_loading();
	_is_loading = false;


func _begin_loading_state() -> void:
	_should_restore_state_after_loading = AppContext.state != AppState.Value.LOADING;
	if not _should_restore_state_after_loading:
		return;
	_state_before_loading = AppContext.state;
	AppContext.set_state(AppState.Value.LOADING);


func _restore_state_after_loading() -> void:
	if not _should_restore_state_after_loading:
		return;
	AppContext.set_state(_state_before_loading);
	_should_restore_state_after_loading = false;


func _warn_unknown_scene_id(scene_id: StringName) -> void:
	var warning_key: String = String(scene_id);
	if _reported_unknown_scene_ids.has(warning_key):
		return;
	_reported_unknown_scene_ids[warning_key] = true;
	push_warning("SceneRouter: unknown scene id '%s', fallback to default scene '%s'." % [warning_key, String(default_scene_id)]);


func _validate_scene_hud_contract(target: Node) -> void:
	if target == null:
		return;
	var has_get_hud_scene: bool = target.has_method("get_hud_scene");
	var has_bind_hud: bool = target.has_method("bind_hud");
	var has_unbind_hud: bool = target.has_method("unbind_hud");
	if (has_bind_hud or has_unbind_hud) and not has_get_hud_scene:
		_warn_scene_contract_issue(target, "hud_contract", "bind_hud/unbind_hud require get_hud_scene");
	if has_bind_hud != has_unbind_hud:
		_warn_scene_contract_issue(target, "hud_contract", "bind_hud and unbind_hud should be implemented together");


func _warn_scene_contract_issue(target: Node, issue_key: String, message: String) -> void:
	if target == null:
		return;
	var target_source: String = target.get_class();
	var script_resource: Script = target.get_script() as Script;
	if script_resource != null and not script_resource.resource_path.is_empty():
		target_source = script_resource.resource_path;
	var warning_key: String = "%s::%s" % [target_source, issue_key];
	if _reported_scene_contract_issues.has(warning_key):
		return;
	_reported_scene_contract_issues[warning_key] = true;
	push_warning("SceneRouter: scene '%s' has invalid contract: %s." % [target_source, message]);


func _resolve_transition_payload(scene_id: StringName, payload: SCENE_TRANSITION_PAYLOAD_TYPE) -> SCENE_TRANSITION_PAYLOAD_TYPE:
	if payload == null:
		return _create_transition_payload(scene_id, current_scene_id);

	if payload.target_scene_id == StringName():
		payload.target_scene_id = scene_id;
	if payload.source_scene_id == StringName():
		payload.source_scene_id = current_scene_id;
	return payload;


func _create_transition_payload(
	target_scene_id: StringName,
	source_scene_id: StringName,
	kind: int = SCENE_TRANSITION_PAYLOAD_TYPE.Kind.UNSPECIFIED,
	extra_data: Dictionary = {}
) -> SCENE_TRANSITION_PAYLOAD_TYPE:
	var payload: SCENE_TRANSITION_PAYLOAD_TYPE = SCENE_TRANSITION_PAYLOAD_TYPE.new();
	payload.target_scene_id = target_scene_id;
	payload.source_scene_id = source_scene_id;
	payload.kind = kind;
	payload.data = extra_data.duplicate(true);
	return payload;

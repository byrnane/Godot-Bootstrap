extends RefCounted;
class_name SceneContracts;


const METHOD_ON_ENTER: StringName = &"on_enter";
const METHOD_ON_EXIT: StringName = &"on_exit";
const METHOD_GET_HUD_SCENE: StringName = &"get_hud_scene";
const METHOD_BIND_HUD: StringName = &"bind_hud";
const METHOD_UNBIND_HUD: StringName = &"unbind_hud";


static func get_scene_source(target: Node) -> String:
	if target == null:
		return "null";
	var target_source: String = target.get_class();
	var script_resource: Script = target.get_script() as Script;
	if script_resource != null and not script_resource.resource_path.is_empty():
		target_source = script_resource.resource_path;
	return target_source;


static func get_hud_contract_issues(target: Node) -> Array[Dictionary]:
	var issues: Array[Dictionary] = [];
	if target == null:
		return issues;

	var has_get_hud_scene: bool = target.has_method(METHOD_GET_HUD_SCENE);
	var has_bind_hud: bool = target.has_method(METHOD_BIND_HUD);
	var has_unbind_hud: bool = target.has_method(METHOD_UNBIND_HUD);

	if (has_bind_hud or has_unbind_hud) and not has_get_hud_scene:
		issues.append({
			"key": "missing_get_hud_scene",
			"message": "bind_hud/unbind_hud require get_hud_scene",
		});
	if has_bind_hud != has_unbind_hud:
		issues.append({
			"key": "bind_unbind_mismatch",
			"message": "bind_hud and unbind_hud should be implemented together",
		});
	return issues;

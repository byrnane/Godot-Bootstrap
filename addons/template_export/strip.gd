@tool
extends EditorExportPlugin;

const KEY = "autoload/CyclopsAutoload";
var _original: Variant;

func _get_name() -> String:
	return "TemplateStripEditorAutoload";

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_original = ProjectSettings.get_setting(KEY);
	ProjectSettings.set_setting(KEY, null);

func _export_end() -> void:
	if _original != null:
		ProjectSettings.set_setting(KEY, _original);

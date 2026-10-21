@tool
extends EditorPlugin;

const EXPORT_STRIP_SCRIPT = preload("res://addons/template_export/strip.gd");
var _export_plugin: EditorExportPlugin;

func _enter_tree() -> void:
	_export_plugin = EXPORT_STRIP_SCRIPT.new();
	add_export_plugin(_export_plugin);

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin);

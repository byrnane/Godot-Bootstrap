extends Node;
class_name Main;

@onready var scene_root: Node = $SceneRoot;

func _ready() -> void:
	SceneRouter.configure(scene_root);
	AppFlow.startup();

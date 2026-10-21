extends Node2D

## Preserve the template A/B entrypoints; actual game flow uses ForestGame.
@export_range(0, 1) var stage: int = 0

func _ready() -> void:
	var level: ForestPlatformer = ForestPlatformer.new()
	var entry: Dictionary = ForestData.normalized({}).progress.platformer
	entry.stage = stage
	level.configure(entry)
	add_child(level)

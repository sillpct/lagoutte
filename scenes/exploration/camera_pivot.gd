extends Node3D

@export var target: Node3D

@export var follow_speed: float = 8.0

func _process(delta: float) -> void:

	if target == null:
		return
	global_position = global_position.lerp(
		target.global_position,
		follow_speed * delta
	)

extends Node

@export var player: Node3D
@export var spawn_point: Marker3D

func _ready() -> void:
	if player == null or spawn_point == null:
		push_warning("PlayerSpawnController a besoin d'un joueur et d'un point de spawn.")
		return
	player.global_transform = spawn_point.global_transform

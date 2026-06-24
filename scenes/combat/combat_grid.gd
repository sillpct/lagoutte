class_name CombatGrid
extends Node3D

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var cell_size: float = 1.0

var _occupants: Dictionary = {}

@onready var cell_visuals: Node3D = $CellVisuals

# --- Logique de coordonnées ---

## Conversion de référence pour placer toute entité sur une case de la grille.
func cell_to_world(col: int, row: int) -> Vector3:
	return global_position + Vector3(col * cell_size, 0.0, row * cell_size)

func world_to_cell(world_position: Vector3) -> Vector2i:
	var offset := world_position - global_position
	return Vector2i(
		roundi(offset.x / cell_size),
		roundi(offset.z / cell_size)
	)

func is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < grid_width and row >= 0 and row < grid_height

# --- Occupation des cases ---

func get_occupant(col: int, row: int) -> Node3D:
	return _occupants.get(Vector2i(col, row), null)

func is_cell_free(col: int, row: int) -> bool:
	return is_valid_cell(col, row) and get_occupant(col, row) == null

func place_unit(unit: Node3D, col: int, row: int) -> bool:
	if unit == null or not is_cell_free(col, row):
		return false

	var previous_cell: Variant = null
	for occupied_cell in _occupants:
		if _occupants[occupied_cell] == unit:
			previous_cell = occupied_cell
			break
	if previous_cell != null:
		_occupants.erase(previous_cell)

	var destination := Vector2i(col, row)
	_occupants[destination] = unit
	unit.global_position = cell_to_world(col, row)
	return true

func clear_cell(col: int, row: int) -> void:
	_occupants.erase(Vector2i(col, row))

# --- Affichage temporaire ---

func _ready() -> void:
	_build_cell_visuals()

func _build_cell_visuals() -> void:
	var cell_mesh := PlaneMesh.new()
	cell_mesh.size = Vector2.ONE * cell_size * 0.9

	var cell_material := StandardMaterial3D.new()
	cell_material.albedo_color = Color(0.22, 0.28, 0.32)
	cell_material.roughness = 1.0
	cell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cell_mesh.material = cell_material

	for row in range(grid_height):
		for col in range(grid_width):
			var cell_visual := MeshInstance3D.new()
			cell_visual.name = "Cell_%d_%d" % [col, row]
			cell_visual.mesh = cell_mesh
			cell_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cell_visuals.add_child(cell_visual)
			cell_visual.global_position = cell_to_world(col, row)

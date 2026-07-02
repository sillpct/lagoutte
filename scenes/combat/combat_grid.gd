class_name CombatGrid
extends Node3D

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var cell_size: float = 1.0
@export var show_cell_visuals := false

const DEFAULT_OCCUPATION_RADIUS := 0.45

var _placed_units: Array[Node3D] = []
var _occupation_radius_by_unit: Dictionary = {}

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
	var target_cell := Vector2i(col, row)
	for unit in _placed_units:
		if unit == null or not is_instance_valid(unit):
			continue
		if world_to_cell(unit.global_position) == target_cell:
			return unit
	return null

func is_cell_free(col: int, row: int) -> bool:
	return is_valid_cell(col, row) and get_occupant(col, row) == null

func place_unit(unit: Node3D, col: int, row: int) -> bool:
	if not is_valid_cell(col, row):
		return false
	return place_unit_at_world(unit, cell_to_world(col, row))

func clear_cell(col: int, row: int) -> void:
	var occupant := get_occupant(col, row)
	if occupant == null:
		return
	_unregister_unit(occupant)

# --- Occupation en positions monde ---

func get_unit_position(unit: Node3D) -> Vector3:
	if unit == null:
		return Vector3.ZERO
	return unit.global_position

func get_unit_occupation_radius(unit: Node3D) -> float:
	return float(_occupation_radius_by_unit.get(unit, DEFAULT_OCCUPATION_RADIUS))

func set_unit_occupation_radius(unit: Node3D, radius: float) -> void:
	if unit == null:
		return
	_occupation_radius_by_unit[unit] = maxf(0.0, radius)

func is_world_position_free(
	position: Vector3,
	radius: float = DEFAULT_OCCUPATION_RADIUS,
	ignore_unit: Node3D = null
) -> bool:
	var safe_radius := maxf(0.0, radius)
	for unit in _placed_units:
		if unit == null or not is_instance_valid(unit) or unit == ignore_unit:
			continue
		var minimum_distance := safe_radius + get_unit_occupation_radius(unit)
		if CombatRules.get_world_distance(position, unit.global_position) < minimum_distance:
			return false
	return true

func place_unit_at_world(
	unit: Node3D,
	world_position: Vector3,
	radius: float = DEFAULT_OCCUPATION_RADIUS
) -> bool:
	if unit == null:
		return false

	var safe_radius := maxf(0.0, radius)
	if not is_world_position_free(world_position, safe_radius, unit):
		return false

	_register_unit(unit)
	set_unit_occupation_radius(unit, safe_radius)
	unit.global_position = world_position
	return true

func get_units_in_radius(position: Vector3, radius: float) -> Array[Node3D]:
	var units_in_radius: Array[Node3D] = []
	var safe_radius := maxf(0.0, radius)
	for unit in _placed_units:
		if unit == null or not is_instance_valid(unit):
			continue
		if CombatRules.get_world_distance(position, unit.global_position) <= safe_radius:
			units_in_radius.append(unit)
	return units_in_radius

func _register_unit(unit: Node3D) -> void:
	if not _placed_units.has(unit):
		_placed_units.append(unit)

func _unregister_unit(unit: Node3D) -> void:
	_placed_units.erase(unit)
	_occupation_radius_by_unit.erase(unit)

# --- Affichage temporaire ---

func _ready() -> void:
	if show_cell_visuals:
		_build_cell_visuals()
	else:
		cell_visuals.hide()

func get_cell_visual(col: int, row: int) -> MeshInstance3D:
	return cell_visuals.get_node_or_null("Cell_%d_%d" % [col, row]) as MeshInstance3D

func set_cell_color(col: int, row: int, color: Color) -> void:
	if not show_cell_visuals:
		return
	var cell_visual := get_cell_visual(col, row)
	if cell_visual == null:
		return
	cell_visual.material_override = _create_cell_material(color)

func _build_cell_visuals() -> void:
	var cell_mesh := PlaneMesh.new()
	cell_mesh.size = Vector2.ONE * cell_size * 0.9

	cell_mesh.material = _create_cell_material(Color(0.22, 0.28, 0.32))

	for row in range(grid_height):
		for col in range(grid_width):
			var cell_visual := MeshInstance3D.new()
			cell_visual.name = "Cell_%d_%d" % [col, row]
			cell_visual.mesh = cell_mesh
			cell_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cell_visuals.add_child(cell_visual)
			cell_visual.global_position = cell_to_world(col, row)

func _create_cell_material(color: Color) -> StandardMaterial3D:
	var cell_material := StandardMaterial3D.new()
	cell_material.albedo_color = color
	cell_material.roughness = 1.0
	cell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return cell_material

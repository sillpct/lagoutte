class_name CombatRangeVisual
extends MeshInstance3D

const BLUE_MOVEMENT_COLOR := Color(0.12, 0.38, 1.0, 0.28)
const RED_ATTACK_COLOR := Color(1.0, 0.12, 0.08, 0.28)
const DISC_HEIGHT := 0.02
const GROUND_OFFSET := 0.025

@export var combat_movement: CombatMovement
@export var combat_manager: CombatManager
@export var active_unit: Node3D
@export var ground_y: float = 0.06

var _disc_mesh: CylinderMesh
var _disc_material: StandardMaterial3D

func _ready() -> void:
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.height = DISC_HEIGHT
	_disc_mesh.radial_segments = 64
	_disc_mesh.rings = 1
	mesh = _disc_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_disc_material = StandardMaterial3D.new()
	_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_material.no_depth_test = false
	material_override = _disc_material

	hide_range()

	if combat_movement != null and not combat_movement.mode_changed.is_connected(_on_combat_mode_changed):
		combat_movement.mode_changed.connect(_on_combat_mode_changed)
	if combat_manager != null and not combat_manager.unit_resources_changed.is_connected(_on_unit_resources_changed):
		combat_manager.unit_resources_changed.connect(_on_unit_resources_changed)

	refresh()

func _process(_delta: float) -> void:
	if visible and active_unit != null and is_instance_valid(active_unit):
		_recenter_on_active_unit()

func refresh() -> void:
	if combat_movement == null or combat_manager == null or active_unit == null or not is_instance_valid(active_unit):
		hide_range()
		return

	if combat_movement.is_movement_mode_active():
		show_range(active_unit.global_position, float(combat_manager.get_pm_current(active_unit)), BLUE_MOVEMENT_COLOR)
	elif combat_movement.is_attack_mode_active():
		show_range(active_unit.global_position, CombatAttack.MELEE_RANGE, RED_ATTACK_COLOR)
	else:
		hide_range()

func show_range(center: Vector3, radius: float, color: Color) -> void:
	var safe_radius := maxf(0.0, radius)
	if is_zero_approx(safe_radius):
		hide_range()
		return

	_disc_mesh.top_radius = safe_radius
	_disc_mesh.bottom_radius = safe_radius
	_disc_material.albedo_color = color
	visible = true
	_recenter_on_position(center)

func hide_range() -> void:
	visible = false

func _recenter_on_active_unit() -> void:
	_recenter_on_position(active_unit.global_position)

func _recenter_on_position(center: Vector3) -> void:
	global_position = Vector3(center.x, ground_y + GROUND_OFFSET, center.z)

func _on_combat_mode_changed(_new_mode: int) -> void:
	refresh()

func _on_unit_resources_changed(unit: Node3D) -> void:
	if unit == active_unit:
		refresh()

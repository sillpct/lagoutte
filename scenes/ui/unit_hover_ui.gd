class_name UnitHoverUI
extends CanvasLayer

const HOVERABLE_UNIT_COLLISION_MASK := 4

@export var combat_manager: CombatManager
@export var ray_length: float = 1000.0

@onready var panel: PanelContainer = $Root/Panel
@onready var name_label: Label = $Root/Panel/Content/NameLabel
@onready var hp_label: Label = $Root/Panel/Content/HPLabel

var hovered_unit: Node3D

func _ready() -> void:
	panel.hide()
	if combat_manager != null and not combat_manager.unit_resources_changed.is_connected(_on_unit_resources_changed):
		combat_manager.unit_resources_changed.connect(_on_unit_resources_changed)

func _process(_delta: float) -> void:
	var detected_unit := _detect_hovered_unit()
	if detected_unit != hovered_unit:
		hovered_unit = detected_unit

	if hovered_unit == null or not is_instance_valid(hovered_unit):
		panel.hide()
		return

	_refresh_panel()

func _detect_hovered_unit() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_position) * ray_length
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		HOVERABLE_UNIT_COLLISION_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	return _get_unit_from_hover_collider(result.get("collider") as Node)

func _get_unit_from_hover_collider(collider: Node) -> Node3D:
	var current := collider
	while current != null:
		if current.is_in_group("hoverable_unit"):
			return current.get_parent() as Node3D
		current = current.get_parent()
	return null

func _refresh_panel() -> void:
	name_label.text = _get_unit_label(hovered_unit)

	var pv := hovered_unit.get("pv") as Stat
	if pv == null:
		hp_label.text = "PV: ?/?"
	else:
		hp_label.text = "PV: %d/%d" % [pv.current_value, pv.max_value]

	panel.show()

func _get_unit_label(unit: Node3D) -> String:
	if unit.name == "Player":
		return "Joueur"

	var incarnation := unit.get("incarnation") as IncarnationData
	if incarnation != null and not incarnation.display_name.is_empty():
		return incarnation.display_name

	return unit.name

func _on_unit_resources_changed(unit: Node3D) -> void:
	if unit == hovered_unit:
		_refresh_panel()

class_name UnitHoverUI
extends CanvasLayer

enum HighlightKind {
	NONE,
	HOVER,
	ATTACK_VALID,
}

@export var combat_manager: CombatManager
@export var world_mouse_query: WorldMouseQuery
## Couplage UI → combat assumé : l'UI lit le mode/portée pour choisir le feedback jaune.
## À extraire vers un SelectionFeedback neutre si un deuxième feedback de ciblage apparaît.
@export var combat_movement: CombatMovement
@export var combat_attack: CombatAttack

@onready var panel: PanelContainer = $Root/Panel
@onready var name_label: Label = $Root/Panel/Content/NameLabel
@onready var hp_label: Label = $Root/Panel/Content/HPLabel

var hovered_unit: Node3D
var _highlighted_mesh: MeshInstance3D
var _original_material_override: Material
var _highlight_material: StandardMaterial3D
var _attack_highlight_material: StandardMaterial3D
var _current_highlight_kind := HighlightKind.NONE

func _ready() -> void:
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.albedo_color = Color.WHITE
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_attack_highlight_material = StandardMaterial3D.new()
	_attack_highlight_material.albedo_color = Color(1.0, 0.86, 0.18)
	_attack_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.hide()
	if combat_manager != null and not combat_manager.unit_resources_changed.is_connected(_on_unit_resources_changed):
		combat_manager.unit_resources_changed.connect(_on_unit_resources_changed)

func _process(_delta: float) -> void:
	var detected_unit := world_mouse_query.get_hovered_unit() if world_mouse_query != null else null
	if detected_unit != hovered_unit:
		_set_hovered_unit(detected_unit)

	if hovered_unit == null or not is_instance_valid(hovered_unit):
		_set_hovered_unit(null)
		panel.hide()
		return

	_apply_highlight(hovered_unit, _get_desired_highlight_kind(hovered_unit))
	_refresh_panel()

func _refresh_panel() -> void:
	name_label.text = _get_unit_label(hovered_unit)

	var pv := hovered_unit.get("pv") as Stat
	if pv == null:
		hp_label.text = "PV: ?/?"
	else:
		hp_label.text = "PV: %d/%d" % [pv.current_value, pv.max_value]

	panel.show()

func _set_hovered_unit(unit: Node3D) -> void:
	_restore_highlight()
	hovered_unit = unit
	if hovered_unit != null and is_instance_valid(hovered_unit):
		_apply_highlight(hovered_unit, _get_desired_highlight_kind(hovered_unit))

func _apply_highlight(unit: Node3D, highlight_kind: HighlightKind) -> void:
	if highlight_kind == HighlightKind.NONE:
		_restore_highlight()
		return
	var mesh := _find_first_mesh_instance(unit)
	if mesh == null:
		return

	if _highlighted_mesh != mesh:
		_restore_highlight()
		_highlighted_mesh = mesh
		_original_material_override = mesh.material_override

	if _current_highlight_kind == highlight_kind:
		return

	_highlighted_mesh.material_override = _get_material_for_highlight(highlight_kind)
	_current_highlight_kind = highlight_kind

func _restore_highlight() -> void:
	if _highlighted_mesh != null and is_instance_valid(_highlighted_mesh):
		_highlighted_mesh.material_override = _original_material_override
	_highlighted_mesh = null
	_original_material_override = null
	_current_highlight_kind = HighlightKind.NONE

func _get_desired_highlight_kind(unit: Node3D) -> HighlightKind:
	if unit == null or not is_instance_valid(unit):
		return HighlightKind.NONE
	if (
		combat_movement != null
		and combat_attack != null
		and combat_movement.is_attack_mode_active()
		and unit != combat_movement.active_unit
		and combat_attack.is_target_in_range(combat_movement.active_unit, unit)
	):
		return HighlightKind.ATTACK_VALID
	return HighlightKind.HOVER

func _get_material_for_highlight(highlight_kind: HighlightKind) -> Material:
	if highlight_kind == HighlightKind.ATTACK_VALID:
		return _attack_highlight_material
	return _highlight_material

func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var found_mesh := _find_first_mesh_instance(child)
		if found_mesh != null:
			return found_mesh
	return null

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

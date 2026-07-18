class_name CombatSession
extends Node

const TEST_ENEMY_START_CELL := Vector2i(8, 5)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var combat_movement: CombatMovement
@export var combat_ui: CombatUI
@export var combat_range_visual: CombatRangeVisual
@export var enemy_brain: EnemyBrain
@export var player: Node3D
@export var renegade: Node3D

func _ready() -> void:
	if combat_manager != null and not combat_manager.combat_ended.is_connected(_on_combat_ended):
		combat_manager.combat_ended.connect(_on_combat_ended)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_test_combat"):
		start_test_combat()
		get_viewport().set_input_as_handled()

func start_test_combat() -> void:
	if not _has_required_references():
		push_warning("CombatSession ne peut pas démarrer le combat de test : référence manquante.")
		return
	if combat_manager.is_combat_active():
		return

	combat_movement.start_combat_control()
	if not grid.place_unit(renegade, TEST_ENEMY_START_CELL.x, TEST_ENEMY_START_CELL.y):
		push_warning("Impossible de placer le renégat de secte sur la case de test (8, 5).")
		combat_movement.stop_combat_control()
		return

	combat_manager.start_combat([player, renegade])
	combat_ui.show_combat_ui()

func stop_combat() -> void:
	if not _has_required_references():
		return

	combat_movement.stop_combat_control()
	combat_ui.hide_combat_ui()
	combat_range_visual.hide_range()
	_clear_unit_from_grid(player)
	_clear_unit_from_grid(renegade)
	combat_manager.stop_combat()

func _has_required_references() -> bool:
	return (
		grid != null
		and combat_manager != null
		and combat_movement != null
		and combat_ui != null
		and combat_range_visual != null
		and enemy_brain != null
		and player != null
		and renegade != null
	)

func _clear_unit_from_grid(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return

	var cell := grid.world_to_cell(unit.global_position)
	if grid.get_occupant(cell.x, cell.y) == unit:
		grid.clear_cell(cell.x, cell.y)

func _on_combat_ended(_issue: int) -> void:
	stop_combat()

class_name EnemyBrain
extends Node

const START_CELL := Vector2i(8, 5)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var combat_attack: CombatAttack
@export var unit: Node3D
@export var target: Node3D

var _event_bus = null

func _ready() -> void:
	if grid == null or combat_manager == null or combat_attack == null or unit == null or target == null:
		push_warning("EnemyBrain a besoin d'une grille, d'un manager, d'une attaque, d'une unité et d'une cible.")
		return

	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null and not _event_bus.turn_started.is_connected(_on_turn_started):
		_event_bus.turn_started.connect(_on_turn_started)

	# Placement de test. À extraire plus tard vers un CombatSetup dédié.
	if not grid.place_unit(unit, START_CELL.x, START_CELL.y):
		push_warning("Impossible de placer le renégat de secte sur la case de test (8, 5).")

func _on_turn_started(active_unit: Node) -> void:
	if active_unit != unit:
		return
	call_deferred("play_turn")

func play_turn() -> void:
	if not is_instance_valid(unit) or not is_instance_valid(target) or not combat_manager.units.has(target):
		print("Renégat de secte : aucune cible active.")
		return
	if combat_manager.get_current_unit() != unit:
		return

	var unit_cell := grid.world_to_cell(unit.global_position)
	var target_cell := grid.world_to_cell(target.global_position)

	if CombatRules.is_adjacent(unit_cell, target_cell):
		combat_attack.try_attack(unit, target_cell)
	else:
		_move_toward_target(unit_cell, target_cell)
		unit_cell = grid.world_to_cell(unit.global_position)
		if CombatRules.is_adjacent(unit_cell, target_cell):
			combat_attack.try_attack(unit, target_cell)

	if is_instance_valid(unit) and combat_manager.units.has(unit):
		if combat_manager.units.has(target):
			combat_manager.end_turn()
		else:
			print("Renégat de secte : cible neutralisée.")

func _move_toward_target(unit_cell: Vector2i, target_cell: Vector2i) -> void:
	var pm_available := combat_manager.get_pm_current(unit)
	var destination := CombatRules.get_step_toward(unit_cell, target_cell, grid, pm_available)
	if destination == unit_cell:
		print("Renégat de secte : aucun déplacement possible.")
		return

	var cost := CombatRules.get_manhattan_distance(unit_cell, destination)
	if cost <= 0:
		return
	if not grid.place_unit(unit, destination.x, destination.y):
		print("Renégat de secte : placement impossible.")
		return
	if not combat_manager.spend_pm(unit, cost):
		print("Renégat de secte : PM insuffisants.")
		return

	print(
		"Renégat de secte avance vers ", destination,
		" — coût: ", cost,
		", PM restants: ", combat_manager.get_pm_current(unit),
		" / ", combat_manager.get_pm_max(unit)
	)

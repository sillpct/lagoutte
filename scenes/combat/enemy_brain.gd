class_name EnemyBrain
extends Node

const START_CELL := Vector2i(8, 5)
const TURN_START_PAUSE := 0.5
const AFTER_MOVE_PAUSE := 0.45
const BEFORE_END_TURN_PAUSE := 0.45

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
	if combat_manager.combat_over:
		return
	if active_unit != unit:
		return
	call_deferred("play_turn")

func play_turn() -> void:
	if combat_manager.combat_over:
		return
	if not is_instance_valid(unit) or not is_instance_valid(target) or not combat_manager.units.has(target):
		print("Renégat de secte : aucune cible active.")
		return
	if combat_manager.get_current_unit() != unit:
		return

	await get_tree().create_timer(TURN_START_PAUSE).timeout
	if not _can_continue_turn():
		return

	var unit_cell := grid.world_to_cell(unit.global_position)
	var target_cell := grid.world_to_cell(target.global_position)

	if CombatRules.is_adjacent(unit_cell, target_cell):
		combat_attack.try_attack(unit, target_cell)
		if combat_manager.combat_over:
			return
	else:
		var cell_before_move := unit_cell
		_move_toward_target(unit_cell, target_cell)
		if combat_manager.combat_over:
			return
		unit_cell = grid.world_to_cell(unit.global_position)
		if unit_cell != cell_before_move:
			await get_tree().create_timer(AFTER_MOVE_PAUSE).timeout
			if not _can_continue_turn():
				return
			target_cell = grid.world_to_cell(target.global_position)
		if CombatRules.is_adjacent(unit_cell, target_cell):
			combat_attack.try_attack(unit, target_cell)
			if combat_manager.combat_over:
				return

	if is_instance_valid(unit) and combat_manager.units.has(unit):
		if combat_manager.units.has(target):
			await get_tree().create_timer(BEFORE_END_TURN_PAUSE).timeout
			if not _can_continue_turn():
				return
			combat_manager.end_turn()
		else:
			print("Renégat de secte : cible neutralisée.")

func _can_continue_turn() -> bool:
	return (
		not combat_manager.combat_over
		and is_instance_valid(unit)
		and is_instance_valid(target)
		and combat_manager.units.has(unit)
		and combat_manager.units.has(target)
		and combat_manager.get_current_unit() == unit
	)

func _move_toward_target(unit_cell: Vector2i, target_cell: Vector2i) -> void:
	if combat_manager.combat_over:
		return
	var pm_available := combat_manager.get_pm_current(unit)
	if pm_available <= 0:
		print("Renégat de secte : PM insuffisants.")
		return

	var origin := unit.global_position
	var destination_cell := _get_best_adjacent_attack_cell(unit_cell, target_cell)
	var destination_world := grid.cell_to_world(destination_cell.x, destination_cell.y) if destination_cell != unit_cell else target.global_position
	var limited_destination := CombatRules.get_world_step_toward(
		origin,
		destination_world,
		float(pm_available)
	)
	var distance_traveled := CombatRules.get_world_distance(origin, limited_destination)
	if is_zero_approx(distance_traveled):
		print("Renégat de secte : aucun déplacement possible.")
		return

	var cost := ceili(clampf(distance_traveled, 0.0, float(pm_available)))
	if cost <= 0:
		return
	if not grid.place_unit_at_world(unit, limited_destination):
		print("Renégat de secte : placement impossible.")
		return
	if not combat_manager.spend_pm(unit, cost):
		print("Renégat de secte : PM insuffisants.")
		return

	print(
		"Renégat de secte avance vers ", unit.global_position,
		" — coût: ", cost,
		", PM restants: ", combat_manager.get_pm_current(unit),
		" / ", combat_manager.get_pm_max(unit)
	)

func _get_best_adjacent_attack_cell(unit_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	var best_cell := unit_cell
	var best_distance := INF
	var adjacent_cells := [
		Vector2i(target_cell.x + 1, target_cell.y),
		Vector2i(target_cell.x - 1, target_cell.y),
		Vector2i(target_cell.x, target_cell.y + 1),
		Vector2i(target_cell.x, target_cell.y - 1),
	]

	for candidate in adjacent_cells:
		if not grid.is_valid_cell(candidate.x, candidate.y):
			continue
		var occupant := grid.get_occupant(candidate.x, candidate.y)
		if occupant != null and occupant != unit:
			continue
		var distance := CombatRules.get_world_distance(
			grid.cell_to_world(unit_cell.x, unit_cell.y),
			grid.cell_to_world(candidate.x, candidate.y)
		)
		if distance < best_distance:
			best_cell = candidate
			best_distance = distance

	return best_cell

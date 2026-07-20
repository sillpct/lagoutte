class_name EnemyBrain
extends Node

const START_CELL := Vector2i(8, 5)
const TURN_START_PAUSE := 0.5
const AFTER_MOVE_PAUSE := 0.45
const BEFORE_END_TURN_PAUSE := 0.45
const MELEE_STOP_MARGIN := 0.1
const OCCUPATION_STOP_MARGIN := 0.05
const FALLBACK_DESTINATION_STEPS := 12

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

func _on_turn_started(active_unit: Node) -> void:
	if not combat_manager.is_combat_active():
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

	if combat_attack.is_target_in_range(unit, target):
		combat_attack.try_attack(unit, target)
		if combat_manager.combat_over:
			return
	else:
		var position_before_move := unit.global_position
		_move_toward_target()
		if combat_manager.combat_over:
			return
		if CombatRules.get_world_distance(position_before_move, unit.global_position) > 0.01:
			await get_tree().create_timer(AFTER_MOVE_PAUSE).timeout
			if not _can_continue_turn():
				return
		if combat_attack.is_target_in_range(unit, target):
			combat_attack.try_attack(unit, target)
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

func _move_toward_target() -> void:
	if combat_manager.combat_over:
		return
	var agility_available := combat_manager.get_agility_current(unit)
	if agility_available <= 0:
		print("Renégat de secte : Agilité insuffisante.")
		return

	var origin := unit.global_position
	var minimum_occupation_distance := (
		grid.get_unit_occupation_radius(unit)
		+ grid.get_unit_occupation_radius(target)
	)
	var stop_distance := maxf(
		minimum_occupation_distance + OCCUPATION_STOP_MARGIN,
		combat_attack.get_effective_melee_range(unit, target) - MELEE_STOP_MARGIN
	)
	var limited_destination := CombatRules.get_world_step_toward(
		origin,
		target.global_position,
		float(agility_available),
		stop_distance
	)
	var distance_traveled := CombatRules.get_world_distance(origin, limited_destination)
	if is_zero_approx(distance_traveled):
		print("Renégat de secte : aucun déplacement possible.")
		return

	var destination := limited_destination
	var used_partial_fallback := false
	if not grid.is_world_position_free(destination, grid.get_unit_occupation_radius(unit), unit):
		destination = _get_closest_valid_destination_toward_target(
			origin,
			float(agility_available),
			minimum_occupation_distance + OCCUPATION_STOP_MARGIN
		)
		used_partial_fallback = true

	destination = grid.get_reachable_position_along_path(unit, origin, destination)

	distance_traveled = CombatRules.get_world_distance(origin, destination)
	if distance_traveled < CombatGrid.MIN_USEFUL_MOVEMENT_DISTANCE:
		print("Renégat de secte : déplacement trop court, refusé.")
		return

	var cost := ceili(clampf(distance_traveled, 0.0, float(agility_available)))
	if cost <= 0:
		return
	if not grid.place_unit_at_world(unit, destination):
		print("Renégat de secte : placement impossible.")
		return
	if not combat_manager.spend_agility(unit, cost):
		print("Renégat de secte : Agilité insuffisante.")
		return

	if used_partial_fallback:
		print("Renégat de secte : rapprochement partiel.")
	print(
		"Renégat de secte avance vers ", unit.global_position,
		" — coût: ", cost,
		", Agilité restante: ", combat_manager.get_agility_current(unit),
		" / ", combat_manager.get_agility_max(unit)
	)

func _get_closest_valid_destination_toward_target(
	origin: Vector3,
	max_distance: float,
	minimum_stop_distance: float
) -> Vector3:
	var distance_to_target := CombatRules.get_world_distance(origin, target.global_position)
	var max_travel_distance := minf(
		max_distance,
		maxf(0.0, distance_to_target - minimum_stop_distance)
	)

	for step in range(FALLBACK_DESTINATION_STEPS, 0, -1):
		var travel_distance := max_travel_distance * float(step) / float(FALLBACK_DESTINATION_STEPS)
		var candidate := CombatRules.get_world_step_toward(origin, target.global_position, travel_distance)
		if grid.is_world_position_free(candidate, grid.get_unit_occupation_radius(unit), unit):
			return candidate

	return origin

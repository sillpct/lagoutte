class_name EnemyBrain
extends Node

const TURN_START_PAUSE := 0.5
const AFTER_MOVE_PAUSE := 0.45
const BEFORE_END_TURN_PAUSE := 0.45
const MELEE_STOP_MARGIN := 0.1
const OCCUPATION_STOP_MARGIN := 0.05

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var combat_attack: CombatAttack
@export var path_service: PathService
@export var unit_path_mover: UnitPathMover
@export var unit: Node3D
@export var target: Node3D
@export var movement_speed := 4.0

var _event_bus = null

func _ready() -> void:
	if grid == null or combat_manager == null or combat_attack == null or path_service == null or unit_path_mover == null or unit == null or target == null:
		push_warning("EnemyBrain a besoin d'une grille, d'un manager, d'une attaque, d'un PathService, d'un UnitPathMover, d'une unité et d'une cible.")
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
		await _move_toward_target()
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
	if path_service == null or unit_path_mover == null:
		print("Renégat de secte : service de chemin manquant.")
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

	var path := path_service.get_world_path(origin, limited_destination)
	var truncated_path := path_service.truncate_path_to_length(path, float(agility_available))
	if truncated_path.size() < 2:
		print("Renégat de secte : aucun déplacement possible.")
		return

	var distance_traveled := path_service.get_path_length(truncated_path)
	if distance_traveled < CombatGrid.MIN_USEFUL_MOVEMENT_DISTANCE:
		print("Renégat de secte : déplacement trop court, refusé.")
		return

	var cost := ceili(clampf(distance_traveled, 0.0, float(agility_available)))
	if cost <= 0:
		return
	var final_position := unit_path_mover.get_adjusted_path_destination(unit, truncated_path)
	if not grid.is_world_position_free(
		final_position,
		grid.get_unit_occupation_radius(unit),
		unit
	):
		print("Renégat de secte : placement impossible.")
		return

	combat_manager.set_action_locked(true)
	var moved := await unit_path_mover.move_along_path(unit, truncated_path, movement_speed)
	combat_manager.set_action_locked(false)
	if not moved:
		print("Renégat de secte : déplacement impossible.")
		return

	if not grid.place_unit_at_world(unit, unit.global_position):
		print("Renégat de secte : placement impossible.")
		return

	if not combat_manager.spend_agility(unit, cost):
		print("Renégat de secte : Agilité insuffisante.")
		return

	print(
		"Renégat de secte avance vers ", unit.global_position,
		" — coût: ", cost,
		", Agilité restante: ", combat_manager.get_agility_current(unit),
		" / ", combat_manager.get_agility_max(unit)
	)

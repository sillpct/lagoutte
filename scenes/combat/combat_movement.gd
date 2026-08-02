class_name CombatMovement
extends Node

enum PlayerCombatMode {
	NEUTRAL,
	MOVEMENT,
	ATTACK,
}

signal mode_changed(new_mode: int)
signal path_movement_started
signal path_movement_finished

const START_CELL := Vector2i(5, 5)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var scripted_sequence_manager: ScriptedSequenceManager
@export var active_unit: Node3D
@export var combat_attack: Node
@export var world_mouse_query: WorldMouseQuery
@export var path_service: PathService
@export var unit_path_mover: UnitPathMover
@export var movement_speed := 4.0

var movement_target_world := Vector3.ZERO
var current_mode := PlayerCombatMode.NEUTRAL
var _event_bus = null

func _ready() -> void:
	if grid == null or combat_manager == null or active_unit == null or world_mouse_query == null or path_service == null or unit_path_mover == null:
		push_warning("CombatMovement a besoin d'une grille, d'un manager de combat, d'une unité active, de WorldMouseQuery, d'un PathService et d'un UnitPathMover.")
		return

	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null and not _event_bus.turn_started.is_connected(_on_turn_started):
		_event_bus.turn_started.connect(_on_turn_started)
	if not combat_manager.unit_resources_changed.is_connected(_on_unit_resources_changed):
		combat_manager.unit_resources_changed.connect(_on_unit_resources_changed)
	if not combat_manager.combat_ended.is_connected(_on_combat_ended):
		combat_manager.combat_ended.connect(_on_combat_ended)

	movement_target_world = active_unit.global_position
	current_mode = PlayerCombatMode.NEUTRAL

func start_combat_control() -> void:
	if grid == null or combat_manager == null or active_unit == null:
		return
	active_unit.set_physics_process(false)

	if not grid.place_unit(active_unit, START_CELL.x, START_CELL.y):
		push_warning("Impossible de placer l'unité active sur la case de départ (5, 5).")
		return

	movement_target_world = active_unit.global_position
	set_combat_mode(PlayerCombatMode.MOVEMENT)

func stop_combat_control() -> void:
	if active_unit != null:
		active_unit.set_physics_process(true)
	current_mode = PlayerCombatMode.NEUTRAL
	mode_changed.emit(current_mode)

func _unhandled_input(event: InputEvent) -> void:
	if grid == null or combat_manager == null or active_unit == null:
		return
	if not combat_manager.is_combat_active():
		return
	if scripted_sequence_manager != null and scripted_sequence_manager.is_sequence_active():
		return
	if combat_manager.is_action_locked():
		return

	if event is InputEventMouseMotion:
		_update_cursor_from_mouse(event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_update_cursor_from_mouse(event.position)
			if is_attack_mode_active() or is_neutral_mode_active():
				return
			_try_move_to_world_target()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("toggle_movement_mode"):
		toggle_movement_mode()
		get_viewport().set_input_as_handled()
		return

func _update_cursor_from_mouse(mouse_position: Vector2) -> void:
	var world_position := world_mouse_query.get_ground_point_at_screen_position(
		mouse_position
	)
	if world_position == WorldMouseQuery.INVALID_WORLD_POSITION:
		return

	if is_movement_mode_active():
		movement_target_world = world_position

func _try_move_to_world_target() -> void:
	if not combat_manager.is_combat_active():
		return
	if scripted_sequence_manager != null and scripted_sequence_manager.is_sequence_active():
		return
	if combat_manager.is_action_locked():
		return
	if combat_manager.get_current_unit() != active_unit:
		print("Déplacement refusé : ce n'est pas le tour de cette unité.")
		return
	if path_service == null or unit_path_mover == null:
		print("Déplacement refusé : service de chemin manquant.")
		return
	if unit_path_mover.is_moving:
		return

	var movement_budget := combat_manager.get_agility_current(active_unit)
	if movement_budget <= 0:
		print("Déplacement refusé : Agilité insuffisante.")
		return

	var origin := active_unit.global_position
	var path := path_service.get_world_path(origin, movement_target_world)
	var truncated_path := path_service.truncate_path_to_length(path, float(movement_budget))
	if truncated_path.size() < 2:
		print("Déplacement trop court : refusé.")
		return

	var distance_traveled := path_service.get_path_length(truncated_path)
	if distance_traveled < CombatGrid.MIN_USEFUL_MOVEMENT_DISTANCE:
		print("Déplacement trop court : refusé.")
		return

	var cost := ceili(clampf(distance_traveled, 0.0, float(movement_budget)))
	if cost > movement_budget:
		print("Déplacement refusé : Agilité insuffisante.")
		return

	var final_position := unit_path_mover.get_adjusted_path_destination(active_unit, truncated_path)
	if not grid.is_world_position_free(
		final_position,
		grid.get_unit_occupation_radius(active_unit),
		active_unit
	):
		print("Déplacement refusé : placement impossible.")
		return

	combat_manager.set_action_locked(true)
	path_movement_started.emit()
	var moved := await unit_path_mover.move_along_path(active_unit, truncated_path, movement_speed)
	combat_manager.set_action_locked(false)
	if not moved:
		path_movement_finished.emit()
		print("Déplacement refusé : déplacement impossible.")
		return

	if not grid.place_unit_at_world(active_unit, active_unit.global_position):
		path_movement_finished.emit()
		print("Déplacement refusé : placement impossible.")
		return

	if not combat_manager.spend_agility(active_unit, cost):
		path_movement_finished.emit()
		print("Déplacement refusé : Agilité insuffisante.")
		return

	path_movement_finished.emit()

	movement_target_world = active_unit.global_position
	print(
		"Déplacement vers ", active_unit.global_position,
		" | coût : ", cost,
		" | Agilité restante : ", combat_manager.get_agility_current(active_unit),
		" / ", combat_manager.get_agility_max(active_unit)
	)

func _on_turn_started(unit: Node) -> void:
	if not combat_manager.is_combat_active():
		return
	if unit == active_unit:
		set_combat_mode(PlayerCombatMode.MOVEMENT)
	else:
		set_combat_mode(PlayerCombatMode.NEUTRAL)

func set_combat_mode(new_mode: PlayerCombatMode) -> void:
	if not combat_manager.is_combat_active() and new_mode != PlayerCombatMode.NEUTRAL:
		return
	if scripted_sequence_manager != null and scripted_sequence_manager.is_sequence_active() and new_mode != PlayerCombatMode.NEUTRAL:
		return
	if combat_manager.is_action_locked() and new_mode != PlayerCombatMode.NEUTRAL:
		return
	if new_mode != PlayerCombatMode.NEUTRAL and combat_manager.get_current_unit() != active_unit:
		return
	if new_mode == PlayerCombatMode.MOVEMENT and not combat_manager.can_unit_move(active_unit):
		return
	if new_mode == PlayerCombatMode.ATTACK and not combat_manager.can_unit_attack(active_unit):
		return

	current_mode = new_mode
	match current_mode:
		PlayerCombatMode.MOVEMENT:
			movement_target_world = active_unit.global_position
	mode_changed.emit(current_mode)

func set_neutral_mode() -> void:
	set_combat_mode(PlayerCombatMode.NEUTRAL)

func toggle_movement_mode() -> void:
	if is_movement_mode_active():
		set_combat_mode(PlayerCombatMode.NEUTRAL)
	else:
		set_combat_mode(PlayerCombatMode.MOVEMENT)

func toggle_attack_mode() -> void:
	if is_attack_mode_active():
		set_combat_mode(PlayerCombatMode.NEUTRAL)
	else:
		set_combat_mode(PlayerCombatMode.ATTACK)

func is_neutral_mode_active() -> bool:
	return current_mode == PlayerCombatMode.NEUTRAL

func is_movement_mode_active() -> bool:
	return current_mode == PlayerCombatMode.MOVEMENT

func is_attack_mode_active() -> bool:
	return current_mode == PlayerCombatMode.ATTACK

func _on_unit_resources_changed(unit: Node3D) -> void:
	if unit != active_unit:
		return
	if is_movement_mode_active() and not combat_manager.can_unit_move(active_unit):
		set_neutral_mode()
	elif is_attack_mode_active() and not combat_manager.can_unit_attack(active_unit):
		set_neutral_mode()

func _on_combat_ended(_issue: int) -> void:
	current_mode = PlayerCombatMode.NEUTRAL
	mode_changed.emit(current_mode)

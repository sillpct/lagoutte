class_name CombatMovement
extends Node

enum PlayerCombatMode {
	NEUTRAL,
	MOVEMENT,
	ATTACK,
}

signal mode_changed(new_mode: int)

const START_CELL := Vector2i(5, 5)
const INVALID_WORLD_POSITION := Vector3(INF, INF, INF)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var active_unit: Node3D
@export var combat_attack: Node

var movement_target_world := Vector3.ZERO
var current_mode := PlayerCombatMode.NEUTRAL
var _event_bus = null

func _ready() -> void:
	if grid == null or combat_manager == null or active_unit == null:
		push_warning("CombatMovement a besoin d'une grille, d'un manager de combat et d'une unité active.")
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
	print(
		"Case (5, 5) — occupant : ", grid.get_occupant(5, 5),
		" | libre : ", grid.is_cell_free(5, 5)
	)

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
	var world_position := get_world_position_from_mouse(mouse_position)
	if world_position == INVALID_WORLD_POSITION:
		return

	if is_movement_mode_active():
		movement_target_world = world_position

func get_world_position_from_mouse(mouse_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_WORLD_POSITION

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if is_zero_approx(ray_direction.y):
		return INVALID_WORLD_POSITION

	var distance_to_grid_plane := (grid.global_position.y - ray_origin.y) / ray_direction.y
	if distance_to_grid_plane < 0.0:
		return INVALID_WORLD_POSITION

	return ray_origin + ray_direction * distance_to_grid_plane

func _try_move_to_world_target() -> void:
	if not combat_manager.is_combat_active():
		return
	if combat_manager.get_current_unit() != active_unit:
		print("Déplacement refusé : ce n'est pas le tour de cette unité.")
		return

	var movement_budget := combat_manager.get_agility_current(active_unit)
	if movement_budget <= 0:
		print("Déplacement refusé : Agilité insuffisante.")
		return

	var origin := active_unit.global_position
	var destination := movement_target_world
	var distance_to_target := CombatRules.get_world_distance(origin, destination)
	if distance_to_target > float(movement_budget):
		destination = CombatRules.get_world_step_toward(origin, destination, float(movement_budget))

	destination = grid.get_reachable_position_along_path(active_unit, origin, destination)

	var distance_traveled := CombatRules.get_world_distance(origin, destination)
	if distance_traveled < CombatGrid.MIN_USEFUL_MOVEMENT_DISTANCE:
		print("Déplacement trop court : refusé.")
		return

	var cost := ceili(clampf(distance_traveled, 0.0, float(movement_budget)))
	if cost > movement_budget:
		print("Déplacement refusé : Agilité insuffisante.")
		return

	if not grid.place_unit_at_world(active_unit, destination):
		print("Déplacement refusé : placement impossible.")
		return

	if not combat_manager.spend_agility(active_unit, cost):
		print("Déplacement refusé : Agilité insuffisante.")
		return

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

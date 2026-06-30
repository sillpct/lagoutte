class_name CombatMovement
extends Node

enum PlayerCombatMode {
	NEUTRAL,
	MOVEMENT,
	ATTACK,
}

signal mode_changed(new_mode: int)

const START_CELL := Vector2i(5, 5)
const NORMAL_CELL_COLOR := Color(0.22, 0.28, 0.32)
const REACHABLE_CELL_COLOR := Color(0.15, 0.35, 0.75)
const CURSOR_CELL_COLOR := Color(1.0, 0.85, 0.15)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var active_unit: Node3D
@export var combat_attack: Node

var cursor_cell := START_CELL
var current_mode := PlayerCombatMode.NEUTRAL
var _reachable_cells: Array[Vector2i] = []
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

	active_unit.set_physics_process(false)

	if not grid.place_unit(active_unit, START_CELL.x, START_CELL.y):
		push_warning("Impossible de placer l'unité active sur la case de départ (5, 5).")
		return

	cursor_cell = START_CELL
	set_combat_mode(PlayerCombatMode.MOVEMENT)
	print(
		"Case (5, 5) — occupant : ", grid.get_occupant(5, 5),
		" | libre : ", grid.is_cell_free(5, 5)
	)

func _unhandled_input(event: InputEvent) -> void:
	if grid == null or combat_manager == null or active_unit == null:
		return

	if event is InputEventMouseMotion:
		_update_cursor_from_mouse(event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_update_cursor_from_mouse(event.position)
			if is_attack_mode_active() or is_neutral_mode_active():
				return
			_try_move_to_cursor()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("toggle_movement_mode"):
		toggle_movement_mode()
		get_viewport().set_input_as_handled()
		return

	var cursor_delta := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		cursor_delta.y -= 1
	elif event.is_action_pressed("ui_down"):
		cursor_delta.y += 1
	elif event.is_action_pressed("ui_left"):
		cursor_delta.x -= 1
	elif event.is_action_pressed("ui_right"):
		cursor_delta.x += 1
	elif event.is_action_pressed("ui_accept"):
		if is_attack_mode_active() or is_neutral_mode_active():
			return
		_try_move_to_cursor()
		get_viewport().set_input_as_handled()
		return

	if cursor_delta == Vector2i.ZERO:
		return
	if is_neutral_mode_active():
		return

	_move_cursor(cursor_delta)
	get_viewport().set_input_as_handled()

func get_reachable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if combat_manager.get_current_unit() != active_unit:
		return result

	var origin := grid.world_to_cell(active_unit.global_position)

	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			if not grid.is_cell_free(col, row):
				continue
			var destination := Vector2i(col, row)
			if CombatRules.get_manhattan_distance(origin, destination) <= combat_manager.get_pm_current(active_unit):
				result.append(destination)

	return result

func _move_cursor(delta: Vector2i) -> void:
	var next_cell := cursor_cell + delta
	next_cell.x = clampi(next_cell.x, 0, grid.grid_width - 1)
	next_cell.y = clampi(next_cell.y, 0, grid.grid_height - 1)

	if next_cell == cursor_cell:
		return

	cursor_cell = next_cell
	_refresh_display()

func _update_cursor_from_mouse(mouse_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if is_zero_approx(ray_direction.y):
		return

	var distance_to_grid_plane := (grid.global_position.y - ray_origin.y) / ray_direction.y
	if distance_to_grid_plane < 0.0:
		return

	var world_position := ray_origin + ray_direction * distance_to_grid_plane
	var cell := grid.world_to_cell(world_position)
	if not grid.is_valid_cell(cell.x, cell.y):
		return
	if cell == cursor_cell:
		return

	cursor_cell = cell
	_refresh_display()

func _try_move_to_cursor() -> void:
	if combat_manager.get_current_unit() != active_unit:
		print("Déplacement refusé : ce n'est pas le tour de cette unité.")
		return

	if not _reachable_cells.has(cursor_cell):
		print("Déplacement refusé : case hors portée, occupée ou invalide.")
		return

	var origin := grid.world_to_cell(active_unit.global_position)
	var cost := CombatRules.get_manhattan_distance(origin, cursor_cell)
	if cost > combat_manager.get_pm_current(active_unit):
		print("Déplacement refusé : PM insuffisants.")
		return

	if not grid.place_unit(active_unit, cursor_cell.x, cursor_cell.y):
		print("Déplacement refusé : placement impossible.")
		return

	if not combat_manager.spend_pm(active_unit, cost):
		print("Déplacement refusé : PM insuffisants.")
		return

	print(
		"Déplacement vers ", cursor_cell,
		" | coût : ", cost,
		" | PM restants : ", combat_manager.get_pm_current(active_unit),
		" / ", combat_manager.get_pm_max(active_unit)
	)
	_refresh_reachable_cells()

func _refresh_reachable_cells() -> void:
	_reachable_cells = get_reachable_cells()
	print("Cases atteignables : ", _reachable_cells)
	_refresh_display()

func _on_turn_started(unit: Node) -> void:
	if unit == active_unit:
		set_combat_mode(PlayerCombatMode.MOVEMENT)
	else:
		set_combat_mode(PlayerCombatMode.NEUTRAL)

func _refresh_display() -> void:
	if is_attack_mode_active():
		combat_attack.refresh_attack_display()
		return

	if is_neutral_mode_active():
		_refresh_neutral_display()
		return

	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			grid.set_cell_color(col, row, NORMAL_CELL_COLOR)

	for cell in _reachable_cells:
		grid.set_cell_color(cell.x, cell.y, REACHABLE_CELL_COLOR)

	grid.set_cell_color(cursor_cell.x, cursor_cell.y, CURSOR_CELL_COLOR)

func _refresh_neutral_display() -> void:
	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			grid.set_cell_color(col, row, NORMAL_CELL_COLOR)

func set_combat_mode(new_mode: PlayerCombatMode) -> void:
	if new_mode != PlayerCombatMode.NEUTRAL and combat_manager.get_current_unit() != active_unit:
		return
	if new_mode == PlayerCombatMode.MOVEMENT and not combat_manager.can_unit_move(active_unit):
		return
	if new_mode == PlayerCombatMode.ATTACK and not combat_manager.can_unit_attack(active_unit):
		return

	current_mode = new_mode
	match current_mode:
		PlayerCombatMode.NEUTRAL:
			print("Mode combat : neutre")
			_refresh_neutral_display()
		PlayerCombatMode.MOVEMENT:
			print("Mode combat : déplacement")
			_refresh_reachable_cells()
		PlayerCombatMode.ATTACK:
			print("Mode combat : attaque")
			if combat_attack != null and combat_attack.has_method("refresh_attack_cells"):
				combat_attack.refresh_attack_cells()
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

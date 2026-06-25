class_name CombatMovement
extends Node

const START_CELL := Vector2i(5, 5)
const NORMAL_CELL_COLOR := Color(0.22, 0.28, 0.32)
const REACHABLE_CELL_COLOR := Color(0.15, 0.35, 0.75)
const CURSOR_CELL_COLOR := Color(1.0, 0.85, 0.15)

@export var grid: CombatGrid
@export var active_unit: Node3D

var pm_max := 0
var pm_current := 0
var cursor_cell := START_CELL
var _reachable_cells: Array[Vector2i] = []

func _ready() -> void:
	if grid == null or active_unit == null:
		push_warning("CombatMovement a besoin d'une grille et d'une unité active.")
		return
	var incarnation := active_unit.get("incarnation") as IncarnationData
	if incarnation == null:
		push_warning("L'unité active n'a pas d'incarnation pour initialiser ses PM.")
		return

	active_unit.set_physics_process(false)
	pm_max = incarnation.points_mouvement
	pm_current = pm_max

	if not grid.place_unit(active_unit, START_CELL.x, START_CELL.y):
		push_warning("Impossible de placer l'unité active sur la case de départ (5, 5).")
		return

	cursor_cell = START_CELL
	_refresh_reachable_cells()
	print(
		"Case (5, 5) — occupant : ", grid.get_occupant(5, 5),
		" | libre : ", grid.is_cell_free(5, 5)
	)
	print("PM : ", pm_current, " / ", pm_max)

func _unhandled_input(event: InputEvent) -> void:
	if grid == null or active_unit == null:
		return

	if event is InputEventMouseMotion:
		_update_cursor_from_mouse(event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_update_cursor_from_mouse(event.position)
			_try_move_to_cursor()
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
		_try_move_to_cursor()
		get_viewport().set_input_as_handled()
		return

	if cursor_delta == Vector2i.ZERO:
		return

	_move_cursor(cursor_delta)
	get_viewport().set_input_as_handled()

func get_reachable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := grid.world_to_cell(active_unit.global_position)

	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			if not grid.is_cell_free(col, row):
				continue
			var destination := Vector2i(col, row)
			if _get_manhattan_distance(origin, destination) <= pm_current:
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
	if not _reachable_cells.has(cursor_cell):
		print("Déplacement refusé : case hors portée, occupée ou invalide.")
		return

	var origin := grid.world_to_cell(active_unit.global_position)
	var cost := _get_manhattan_distance(origin, cursor_cell)
	if cost > pm_current:
		print("Déplacement refusé : PM insuffisants.")
		return

	if not grid.place_unit(active_unit, cursor_cell.x, cursor_cell.y):
		print("Déplacement refusé : placement impossible.")
		return

	pm_current -= cost
	print("Déplacement vers ", cursor_cell, " | coût : ", cost, " | PM restants : ", pm_current, " / ", pm_max)
	_refresh_reachable_cells()

func _refresh_reachable_cells() -> void:
	_reachable_cells = get_reachable_cells()
	print("Cases atteignables : ", _reachable_cells)
	_refresh_display()

func _refresh_display() -> void:
	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			grid.set_cell_color(col, row, NORMAL_CELL_COLOR)

	for cell in _reachable_cells:
		grid.set_cell_color(cell.x, cell.y, REACHABLE_CELL_COLOR)

	grid.set_cell_color(cursor_cell.x, cursor_cell.y, CURSOR_CELL_COLOR)

func _get_manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return abs(to_cell.x - from_cell.x) + abs(to_cell.y - from_cell.y)

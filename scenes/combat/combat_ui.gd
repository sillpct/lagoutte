class_name CombatUI
extends CanvasLayer

const PLAYER_COLOR := Color(0.15, 0.35, 0.85)
const ENEMY_COLOR := Color(0.75, 0.12, 0.10)
const ACTIVE_BORDER_COLOR := Color(1.0, 0.9, 0.25)
const INACTIVE_BORDER_COLOR := Color(0.04, 0.05, 0.07)

@export var combat_manager: CombatManager
@export var combat_movement: CombatMovement

@onready var turn_order_bar: HBoxContainer = $Root/MarginContainer/TurnOrderBar
@onready var movement_button: Button = $Root/ActionBar/ActionButtons/MovementButton
@onready var attack_button: Button = $Root/ActionBar/ActionButtons/AttackButton
@onready var end_turn_button: Button = $Root/BottomBar/EndTurnButton

var _event_bus = null

func _ready() -> void:
	if combat_manager == null:
		push_warning("CombatUI a besoin d'un CombatManager pour afficher l'ordre de tour.")
		return
	if combat_movement == null:
		push_warning("CombatUI a besoin d'un CombatMovement pour afficher les actions de combat.")
		return

	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		if not _event_bus.turn_started.is_connected(_on_turn_changed):
			_event_bus.turn_started.connect(_on_turn_changed)
		if not _event_bus.turn_ended.is_connected(_on_turn_changed):
			_event_bus.turn_ended.connect(_on_turn_changed)
	if not combat_movement.mode_changed.is_connected(_on_combat_mode_changed):
		combat_movement.mode_changed.connect(_on_combat_mode_changed)
	if not combat_manager.unit_resources_changed.is_connected(_on_unit_resources_changed):
		combat_manager.unit_resources_changed.connect(_on_unit_resources_changed)

	refresh_turn_order()
	_refresh_end_turn_button()
	_refresh_action_buttons()

func refresh_turn_order() -> void:
	for child in turn_order_bar.get_children():
		child.queue_free()

	if combat_manager == null:
		return

	var current_unit := combat_manager.get_current_unit()
	for unit in combat_manager.units:
		if unit == null or not is_instance_valid(unit):
			continue
		_listen_to_unit_removal(unit)
		turn_order_bar.add_child(_create_turn_unit_box(unit, unit == current_unit))

func _create_turn_unit_box(unit: Node3D, is_active: bool) -> PanelContainer:
	var unit_box := PanelContainer.new()
	unit_box.custom_minimum_size = Vector2(120.0, 42.0)
	unit_box.add_theme_stylebox_override("panel", _create_unit_style(unit, is_active))

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _get_unit_label(unit)
	unit_box.add_child(label)

	return unit_box

func _create_unit_style(unit: Node3D, is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _get_unit_color(unit)
	if is_active:
		style.bg_color = style.bg_color.lightened(0.18)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = ACTIVE_BORDER_COLOR
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = INACTIVE_BORDER_COLOR
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _get_unit_color(unit: Node3D) -> Color:
	if unit.name == "Player":
		return PLAYER_COLOR
	return ENEMY_COLOR

func _get_unit_label(unit: Node3D) -> String:
	if unit.name == "Player":
		return "Joueur"

	var incarnation := unit.get("incarnation") as IncarnationData
	if incarnation != null and not incarnation.display_name.is_empty():
		return incarnation.display_name

	return unit.name

func _listen_to_unit_removal(unit: Node3D) -> void:
	var callback := Callable(self, "_on_unit_removed_from_tree")
	if not unit.tree_exited.is_connected(callback):
		unit.tree_exited.connect(callback)

func _on_turn_changed(_unit: Node) -> void:
	refresh_turn_order()
	_refresh_end_turn_button()
	_refresh_action_buttons()

func _on_unit_removed_from_tree() -> void:
	call_deferred("refresh_turn_order")
	call_deferred("_refresh_end_turn_button")
	call_deferred("_refresh_action_buttons")

func _refresh_end_turn_button() -> void:
	if combat_manager == null:
		end_turn_button.disabled = true
		return
	end_turn_button.disabled = not combat_manager.can_player_end_turn()

func _on_end_turn_button_pressed() -> void:
	if combat_manager == null:
		return
	combat_manager.request_player_end_turn()
	_refresh_end_turn_button()
	_refresh_action_buttons()

func _refresh_action_buttons() -> void:
	if combat_manager == null or combat_movement == null:
		movement_button.disabled = true
		attack_button.disabled = true
		movement_button.set_pressed_no_signal(false)
		attack_button.set_pressed_no_signal(false)
		return

	var actions_enabled := _can_player_use_actions()
	movement_button.disabled = not actions_enabled or not combat_manager.can_unit_move(combat_movement.active_unit)
	attack_button.disabled = not actions_enabled or not combat_manager.can_unit_attack(combat_movement.active_unit)

	movement_button.set_pressed_no_signal(combat_movement.is_movement_mode_active())
	attack_button.set_pressed_no_signal(combat_movement.is_attack_mode_active())

func _can_player_use_actions() -> bool:
	return (
		combat_manager != null
		and combat_movement != null
		and combat_manager.can_player_end_turn()
	)

func _on_movement_button_pressed() -> void:
	if not _can_player_use_actions() or not combat_manager.can_unit_move(combat_movement.active_unit):
		return
	combat_movement.toggle_movement_mode()
	_refresh_action_buttons()

func _on_attack_button_pressed() -> void:
	if not _can_player_use_actions() or not combat_manager.can_unit_attack(combat_movement.active_unit):
		return
	combat_movement.toggle_attack_mode()
	_refresh_action_buttons()

func _on_combat_mode_changed(_new_mode: int) -> void:
	_refresh_action_buttons()

func _on_unit_resources_changed(_unit: Node3D) -> void:
	_refresh_action_buttons()

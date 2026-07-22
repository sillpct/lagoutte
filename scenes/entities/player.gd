extends CharacterBody3D

@export var incarnation: IncarnationData

var pv: Stat

var current_dialogue_index := 0

var current_interactable = null

var waiting_for_choice := false

var selected_choice := 0

func _ready() -> void:

	pv = Stat.new()
	pv.max_value = incarnation.pv_max
	pv.reset_to_full()

func _input(event: InputEvent) -> void:

	if waiting_for_choice:
		handle_choice_input(event)
		return
	if event.is_action_pressed("interact"):
		check_interaction()

func check_interaction() -> void:

	var dialogue_box = get_tree().current_scene.get_node("DialogueUI/DialogueBox")
	var dialogue_text = get_tree().current_scene.get_node("DialogueUI/DialogueBox/DialogueText")
	var speaker_name = get_tree().current_scene.get_node("DialogueUI/DialogueBox/SpeakerName")
	var choices_container = get_tree().current_scene.get_node("DialogueUI/DialogueBox/ChoicesContainer")
	if waiting_for_choice:
		return
	if dialogue_box.visible and current_interactable != null:
		current_dialogue_index += 1
		if current_dialogue_index < current_interactable.dialogue_lines.size():
			dialogue_text.text = current_interactable.dialogue_lines[current_dialogue_index]
		else:
			if current_interactable.choices.size() > 0:
				show_choices(choices_container)
			else:
				close_dialogue()
		return
	for area in $InteractionArea.get_overlapping_areas():
		if area.is_in_group("interactable"):
			if area.has_method("interact"):
				if area.interact(self):
					return
				continue
			current_interactable = area
			current_dialogue_index = 0
			waiting_for_choice = false
			selected_choice = 0
			clear_choices(choices_container)
			speaker_name.text = area.speaker_name
			dialogue_text.text = area.dialogue_lines[current_dialogue_index]
			dialogue_box.show()
			return

func show_choices(choices_container) -> void:

	waiting_for_choice = true
	selected_choice = 0
	choices_container.show()
	for choice in current_interactable.choices:
		if not GameState.check_condition(choice.get("require", []), choice.get("forbid", [])):
			continue
		var choice_data = choice.duplicate(true)
		add_choice_button(choices_container, choice_data)
	focus_selected_choice(choices_container)

func add_choice_button(choices_container, choice_data: Dictionary) -> void:

	var button_index: int = choices_container.get_child_count()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.text = choice_data["text"]
	button.mouse_entered.connect(func():
		selected_choice = button_index
		focus_selected_choice(choices_container)
	)
	button.pressed.connect(func():
		confirm_choice(choice_data)
	)
	choices_container.add_child(button)

func handle_choice_input(event: InputEvent) -> void:

	var choices_container = get_tree().current_scene.get_node("DialogueUI/DialogueBox/ChoicesContainer")
	if event.is_action_pressed("ui_up"):
		move_choice_selection(choices_container, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		move_choice_selection(choices_container, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		activate_selected_choice(choices_container)
		get_viewport().set_input_as_handled()

func move_choice_selection(choices_container, direction: int) -> void:

	var choice_count: int = choices_container.get_child_count()
	if choice_count == 0:
		return
	selected_choice = wrapi(selected_choice + direction, 0, choice_count)
	focus_selected_choice(choices_container)

func focus_selected_choice(choices_container) -> void:

	var choice_count: int = choices_container.get_child_count()
	if choice_count == 0:
		return
	selected_choice = clampi(selected_choice, 0, choice_count - 1)
	var button := choices_container.get_child(selected_choice) as Button
	if button != null:
		button.grab_focus()

func activate_selected_choice(choices_container) -> void:

	var choice_count: int = choices_container.get_child_count()
	if choice_count == 0:
		return
	selected_choice = clampi(selected_choice, 0, choice_count - 1)
	var button := choices_container.get_child(selected_choice) as Button
	if button != null:
		button.pressed.emit()

func confirm_choice(choice: Dictionary) -> void:

	apply_choice_effect(choice)
	close_dialogue()

func apply_choice_effect(choice) -> void:

	if choice.has("set_flag"):
		GameState.set_flag(choice["set_flag"])
	if choice.has("damage"):
		pv.reduce(int(choice["damage"]))

func clear_choices(choices_container) -> void:

	for child in choices_container.get_children():
		child.queue_free()
	choices_container.hide()

func close_dialogue() -> void:

	var dialogue_box = get_tree().current_scene.get_node("DialogueUI/DialogueBox")
	var choices_container = get_tree().current_scene.get_node("DialogueUI/DialogueBox/ChoicesContainer")
	clear_choices(choices_container)
	dialogue_box.hide()
	current_dialogue_index = 0
	current_interactable = null
	waiting_for_choice = false
	selected_choice = 0

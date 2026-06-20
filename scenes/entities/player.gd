extends CharacterBody3D

@export var move_speed: float = 5.0

var current_dialogue_index := 0

var current_interactable = null

var waiting_for_choice := false

var selected_choice := 0

func _physics_process(delta: float) -> void:

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.z * move_speed
	move_and_slide()

func _input(event: InputEvent) -> void:

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
	choices_container.show()
	for choice in current_interactable.choices:
		if not GameState.check_condition(choice.get("require", []), choice.get("forbid", [])):
			continue
		var choice_data = choice.duplicate(true)
		var button := Button.new()
		button.text = choice_data["text"]
		button.pressed.connect(func():
			apply_choice_effect(choice_data)
			close_dialogue()
		)
		choices_container.add_child(button)

func apply_choice_effect(choice) -> void:

	if choice.has("set_flag"):
		GameState.set_flag(choice["set_flag"])

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

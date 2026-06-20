extends Control

func _on_new_game_button_pressed() -> void:

	GameState.reset()
	SceneManager.change_scene("res://scenes/exploration/exploration.tscn")

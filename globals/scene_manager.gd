extends Node

func change_scene(path: String) -> void:

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error(
			"SceneManager : échec du chargement de '%s' (code %d)"
			% [path, error]
		)

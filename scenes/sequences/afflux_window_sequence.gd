class_name AffluxWindowSequence
extends Node

const FINAL_LINE := "Je dois sortir."
const FINAL_CLEAR_PAUSE := 0.12

@export var subtitle_ui: Node
@export var phase_3_cadence_scale := 1.0

var lines := [
	{ "time": 0.0, "text": "J'étais seulement venu regarder tomber la pluie.", "hold": 2.8 },
	{ "time": 5.2, "text": "Ne bouge pas. Écoute — c'est nous, maintenant.", "hold": 3.0 },
	{ "time": 10.0, "text": "Combien avant toi, tu crois ? On ne sait plus compter.", "hold": 3.2 },
	{ "time": 13.2, "text": "Ne descends pas encore. Écoute-nous d'abord.", "hold": 2.8 },
	{ "time": 18.4, "text": "Assez.", "hold": 1.5 },
	{ "time": 21.0, "text": FINAL_LINE, "hold": 2.8 },
]

func play(sequence_manager: ScriptedSequenceManager) -> void:
	if subtitle_ui == null or sequence_manager == null:
		return

	subtitle_ui.call("clear_subtitle")
	var elapsed := 0.0
	for line in lines:
		if not sequence_manager.is_sequence_active():
			subtitle_ui.call("clear_subtitle")
			return

		var target_time := _get_effective_time(line)
		var wait_time := maxf(0.0, target_time - elapsed)
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout
			elapsed += wait_time
		if not sequence_manager.is_sequence_active():
			subtitle_ui.call("clear_subtitle")
			return

		var text := str(line["text"])
		if text == FINAL_LINE:
			subtitle_ui.call("clear_subtitle")
			await get_tree().create_timer(FINAL_CLEAR_PAUSE).timeout
			elapsed += FINAL_CLEAR_PAUSE
			if not sequence_manager.is_sequence_active():
				subtitle_ui.call("clear_subtitle")
				return

		subtitle_ui.call("show_subtitle", text)
		var hold := float(line["hold"])
		await get_tree().create_timer(hold).timeout
		elapsed += hold

	subtitle_ui.call("clear_subtitle")

func stop() -> void:
	if subtitle_ui != null:
		subtitle_ui.call("clear_subtitle")

func _get_effective_time(line: Dictionary) -> float:
	var base_time := float(line["time"])
	if base_time < 10.0 or base_time > 13.2:
		return base_time
	return 10.0 + (base_time - 10.0) * phase_3_cadence_scale

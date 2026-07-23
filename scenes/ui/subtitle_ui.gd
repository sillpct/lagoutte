class_name SubtitleUI
extends CanvasLayer

@onready var subtitle_label: Label = $Root/SubtitleLabel

func _ready() -> void:
	clear_subtitle()

func show_subtitle(text: String) -> void:
	subtitle_label.text = text
	subtitle_label.show()

func clear_subtitle() -> void:
	subtitle_label.text = ""
	subtitle_label.hide()

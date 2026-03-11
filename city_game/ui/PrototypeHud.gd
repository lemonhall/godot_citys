extends CanvasLayer

var _status_text := "Booting city skeleton..."

func _ready() -> void:
	_apply_status()

func set_status(text: String) -> void:
	_status_text = text
	_apply_status()

func _apply_status() -> void:
	var label := get_node_or_null("Margin/Panel/VBox/Status") as Label
	if label != null:
		label.text = _status_text


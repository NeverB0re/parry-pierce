extends CanvasLayer
## ESC 메뉴. 플레이 중에는 마우스가 창 밖으로 못 나가고, 메뉴를 열어야 풀린다.

signal restart_requested

var font: SystemFont
var ui_scale := 1.0                  # 터치 기기에서는 키운다


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", int(44 * ui_scale))
	box.add_child(title)

	_button(box, "계속하기", resume)
	_button(box, "처음부터 다시", func() -> void:
		restart_requested.emit()
		resume())
	_button(box, "종료", func() -> void: get_tree().quit())


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 54) * ui_scale
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", int(24 * ui_scale))
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

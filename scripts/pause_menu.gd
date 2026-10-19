extends CanvasLayer
## ESC 메뉴. 플레이 중에는 마우스가 창 밖으로 못 나가고, 메뉴를 열어야 풀린다. 열 때마다(그리고 언어를 바꿀 때) 글자를 새로 만든다.
const UiFont := preload("res://scripts/ui_font.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const Loc := preload("res://scripts/loc.gd")

signal restart_requested
signal world_requested
signal title_requested

var font: Font
var ui_scale := 1.0                  # 터치 기기에서는 키운다
var tutorial                         # main.gd 가 연결: 조작법 다시 보기
var title                            # main.gd 가 연결: 타이틀이 열려 있으면 ESC 는 무시한다
var center: CenterContainer
var main_box: Control
var help_box: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = UiFont.make()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_build()
	Loc.on_change(_rebuild_if_open)


func _rebuild_if_open() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in center.get_children():
		center.remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	main_box = _panel(box)

	var tl := Label.new()
	tl.text = Loc.t("일시정지")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.title(tl, int(36 * ui_scale))
	box.add_child(tl)

	_button(box, Loc.t("계속하기"), resume)
	_button(box, Loc.t("처음부터 다시"), func() -> void:
		restart_requested.emit()
		resume())
	_button(box, Loc.t("항로도 (스테이지 선택)"), func() -> void:
		visible = false
		world_requested.emit())
	_button(box, Loc.t("조작법"), func() -> void: _show_help(true))
	_button(box, Loc.t("타이틀 화면"), func() -> void:
		visible = false
		get_tree().paused = false
		title_requested.emit())
	if not OS.has_feature("web"):                              # 브라우저에서는 창을 닫을 수 없다
		_button(box, Loc.t("종료"), func() -> void: get_tree().quit())

	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	help_box = _panel(hbox)
	help_box.visible = false
	var ht := Label.new()
	ht.text = Loc.t("조작법")
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.title(ht, int(36 * ui_scale))
	hbox.add_child(ht)
	if tutorial != null:
		for id in tutorial.ORDER:
			var sid: String = id
			_button(hbox, tutorial.page_title(sid), func() -> void: tutorial.replay(sid))
	_button(hbox, Loc.t("뒤로"), func() -> void: _show_help(false))


## 가운데 판 (UiStyle.panel) 안에 content 를 넣고 판을 돌려준다
func _panel(content: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiStyle.panel(int(24 * ui_scale)))
	pc.add_child(content)
	center.add_child(pc)
	return pc


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(432, 48) * ui_scale
	UiStyle.button(b, font, int(24 * ui_scale))
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if title != null and title.visible:
			return
		if visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func _show_help(on: bool) -> void:
	main_box.visible = not on
	help_box.visible = on


func open() -> void:
	_build()                         # 조작법 목록은 튜토리얼 장 제목에서 읽는다 (언어가 바뀐 뒤에도 맞게)
	_show_help(false)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CONFINED

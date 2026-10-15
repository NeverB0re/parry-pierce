extends CanvasLayer
## 메인 화면: 시작 / 이어하기(ESC 메뉴에서 왔을 때: 멈춰 둔 판으로 돌아감) / 스테이지 선택 / 조작법 / 종료. 우하단의 미국·한국 국기 버튼으로 영어·한국어를 고른다.
## 게임은 뒤에서 돌지만(보스가 대기 자세로 흔들린다) 입력은 막힌다 (main.gd 가 title.visible 을 본다).
## 새 게임은 저장된 진행이 있으면 한 번 더 눌러야 시작한다 (확인).

const Loc := preload("res://scripts/loc.gd")

signal start_requested               # 새 게임 (진행 초기화 후 첫 스테이지로)
signal continue_requested            # 스테이지 선택: 항로도
signal resume_requested              # 이어하기: 멈춰 둔 판으로 돌아간다
signal quit_requested

var profile                          # main.gd 가 연결
var tutorial                         # main.gd 가 연결: 조작법 목록
var ui_scale := 1.0
var font: SystemFont
var root: Control
var _confirm_new := false
var _help := false
var can_resume := false              # ESC 메뉴에서 왔다 = 멈춰 둔 판이 있다 (main.gd 가 정한다)


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Segoe UI", "sans-serif"])
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Loc.on_change(_on_lang)


func open() -> void:
	_confirm_new = false
	_help = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func close() -> void:
	visible = false


func _on_lang() -> void:
	if visible:
		_build()


func _has_progress() -> bool:
	return profile != null and not profile.cleared.is_empty()


func _build() -> void:
	for c in root.get_children():                     # 누른 버튼 자신의 신호 처리 중일 수 있으니 바로 떼고 나중에 지운다
		root.remove_child(c)
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(14 * ui_scale))
	center.add_child(box)

	if _help and tutorial != null:                    # 조작법 목록: 제목 대신 목록만 (화면에 다 들어오게 촘촘히)
		box.add_theme_constant_override("separation", int(8 * ui_scale))
		box.add_child(_label(Loc.t("조작법"), 34, Color(0.9, 0.95, 1.0)))
		for id in tutorial.ORDER:
			var sid: String = id
			var hb := _button(box, tutorial.page_title(sid), func() -> void: tutorial.replay(sid))
			hb.custom_minimum_size = Vector2(560, 46) * ui_scale
		var back := _button(box, Loc.t("뒤로"), func() -> void:
			_help = false
			_build())
		back.custom_minimum_size = Vector2(560, 46) * ui_scale
	else:
		var t1 := _label("PARRY PIERCE", 78, Color(1.0, 0.93, 0.8))
		box.add_child(t1)
		var ver := str(ProjectSettings.get_setting("application/config/version", ""))
		box.add_child(_label("v" + ver, 16, Color(0.7, 0.75, 0.85, 0.8)))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 26 * ui_scale)
		box.add_child(gap)
		var new_text := Loc.t("시작")
		if _has_progress():
			new_text = Loc.t("처음부터 시작 (진행 초기화)")
			if _confirm_new:
				new_text = Loc.t("정말 초기화하고 시작합니다 — 한 번 더 누르세요")
		var b_new := _button(box, new_text, _on_new)
		if _confirm_new:
			b_new.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		var b_res: Button = null
		if can_resume:
			b_res = _button(box, Loc.t("이어하기"), func() -> void:
				close()
				resume_requested.emit())
		var b_cont := _button(box, Loc.t("스테이지 선택 (항로도)"), func() -> void:
			close()
			continue_requested.emit())
		b_cont.disabled = not _has_progress()
		_button(box, Loc.t("조작법"), func() -> void:
			_confirm_new = false
			_help = true
			_build())
		_button(box, Loc.t("종료"), func() -> void: quit_requested.emit())
		if b_res != null:
			b_res.grab_focus()
		elif not _has_progress():
			b_new.grab_focus()
		else:
			b_cont.grab_focus()

	# 좌하단: 전체 화면 안내
	var hint := _label("F11: " + Loc.t("전체 화면"), 15, Color(0.7, 0.75, 0.85, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -44 * ui_scale)
	root.add_child(hint)

	# 아래 가운데: 도트 그림 출처 (CC-BY 3.0 표기)
	var credit := _label("Art: Ravenmore \"Space Rage\" (CC-BY 3.0)", 13, Color(0.7, 0.75, 0.85, 0.55))
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -34.0 * ui_scale
	credit.offset_bottom = -10.0 * ui_scale
	root.add_child(credit)

	# 우하단: 국기 버튼 (미국 = 영어, 한국 = 한국어)
	var flags := HBoxContainer.new()
	flags.add_theme_constant_override("separation", int(14 * ui_scale))
	flags.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	flags.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	flags.grow_vertical = Control.GROW_DIRECTION_BEGIN
	flags.position = Vector2(-24, -24)
	root.add_child(flags)
	for l in ["en", "ko"]:
		var f := FlagButton.new()
		f.lang = l
		f.selected = Loc.lang == l
		f.ui_scale = ui_scale
		f.tooltip_text = "English" if l == "en" else "한국어"
		f.chosen.connect(_on_flag)
		flags.add_child(f)


func _on_flag(l: String) -> void:
	_confirm_new = false
	if Loc.lang != l:
		Loc.set_lang(l)                          # 등록된 메뉴들이 글자를 다시 만든다 (이 메뉴 포함)
	else:
		_build()


func _on_new() -> void:
	if _has_progress() and not _confirm_new:
		_confirm_new = true
		_build()
		return
	_confirm_new = false
	close()
	start_requested.emit()


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(size * ui_scale))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(430, 56) * ui_scale
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", int(23 * ui_scale))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ═══ 국기 버튼 ═══════════════════════════════════════════
## 코드로 그린 작은 국기 (미국 / 한국). 고른 쪽은 밝은 테두리, 아닌 쪽은 어둡게
class FlagButton extends Control:
	signal chosen(lang: String)
	static var _tex := {}

	var lang := "en"
	var selected := false
	var ui_scale := 1.0

	func _ready() -> void:
		custom_minimum_size = Vector2(84, 56) * ui_scale
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(lang)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hover := get_global_rect().has_point(get_global_mouse_position())
		var dim := 1.0 if (selected or hover) else 0.5
		draw_texture_rect(_texture(lang), r, false, Color(dim, dim, dim, 1.0))
		draw_rect(r, Color(1.0, 0.9, 0.55, 1.0) if selected else Color(0.6, 0.65, 0.75, 0.7), false, 4.0 if selected else 2.0)

	func _process(_dt: float) -> void:
		queue_redraw()

	static func _texture(l: String) -> Texture2D:
		if not _tex.has(l):
			_tex[l] = ImageTexture.create_from_image(_us() if l == "en" else _kr())
		return _tex[l]

	const W := 84
	const H := 56

	static func _us() -> Image:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		var red := Color(0.70, 0.13, 0.20)
		var white := Color(0.97, 0.97, 0.97)
		var blue := Color(0.24, 0.23, 0.43)
		var sh := float(H) / 13.0
		for i in 13:
			img.fill_rect(Rect2i(0, int(i * sh), W, int(ceil(sh))), red if i % 2 == 0 else white)
		var cw := int(W * 0.4)
		var ch := int(sh * 7.0)
		img.fill_rect(Rect2i(0, 0, cw, ch), blue)
		for row in 5:                                     # 별 (점으로)
			for col in 6:
				if (row + col) % 2 == 0 or true:
					var x := 6 + col * (cw - 10) / 5
					var y := 5 + row * (ch - 10) / 4
					img.fill_rect(Rect2i(x - 1, y - 1, 3, 3), white)
		return img

	static func _kr() -> Image:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.97, 0.97, 0.97))
		var cx := W * 0.5
		var cy := H * 0.5
		var r := 14.0
		var red := Color(0.80, 0.16, 0.22)
		var blue := Color(0.0, 0.20, 0.47)
		# 태극 (위 빨강 / 아래 파랑 + 좌 빨강 / 우 파랑 작은 원) 을 33도 돌려 그린다
		var ang := deg_to_rad(-33.0)
		var ca := cos(ang)
		var sa := sin(ang)
		for y in H:
			for x in W:
				var dx := x + 0.5 - cx
				var dy := y + 0.5 - cy
				var ux := dx * ca + dy * sa
				var uy := -dx * sa + dy * ca
				if ux * ux + uy * uy > r * r:
					continue
				var c := red if uy < 0.0 else blue
				if (ux + r * 0.5) * (ux + r * 0.5) + uy * uy <= (r * 0.5) * (r * 0.5):
					c = red
				elif (ux - r * 0.5) * (ux - r * 0.5) + uy * uy <= (r * 0.5) * (r * 0.5):
					c = blue
				img.set_pixel(x, y, c)
		# 4괘: 모서리마다 검은 막대 셋 (대각 방향)
		var black := Color(0.08, 0.08, 0.1)
		for corner in 4:
			var sx := -1.0 if corner % 2 == 0 else 1.0
			var sy := -1.0 if corner < 2 else 1.0
			var cc := Vector2(cx + sx * 27.0, cy + sy * 16.0)
			var dir := Vector2(sx * sy, 1.0).normalized().orthogonal()     # 막대가 늘어선 방향에 수직
			var along := Vector2(sx, sy).normalized()
			for k in 3:
				var o := cc + along.orthogonal() * float(k - 1) * 4.6
				for t in range(-7, 8):
					var p := o + along * float(t) * 0.7 * -1.0
					if (corner == 0 or corner == 3) and k == 1 and abs(t) < 2:      # 가운데 막대는 끊어 음효처럼
						continue
					img.fill_rect(Rect2i(int(p.x), int(p.y), 2, 2), black)
		return img

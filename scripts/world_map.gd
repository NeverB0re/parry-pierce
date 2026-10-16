extends CanvasLayer
## 월드 맵 (스테이지 사이, ESC 메뉴에서도): 은하 9개(스테이지)와 목적지(10번째)를 점선 항로로 잇고, 기체가 고른 스테이지 위에 떠 있다.
## 깬 은하는 다시 골라 재전투할 수 있다. 안 깬 곳(다음 하나만 고를 수 있음)·아직 만들지 않은 곳은 회색.
## 아래에는 얻은 동력 코어를 보여 주고, 눌러서(또는 숫자 키) 장착·교체한다 (장착 칸 수만큼만 작동). FTL 도약 → 고른 스테이지.

const Loc := preload("res://scripts/loc.gd")
signal jump_requested
signal back_requested               # 타이틀에서 열었을 때만 (allow_back)

const Upgrades := preload("res://scripts/upgrades.gd")
const Stages := preload("res://scripts/stages.gd")
const Sprites := preload("res://scripts/sprites.gd")
const C_TAKEN := Color(1.0, 0.85, 0.45)
const C_LOCKED := Color(0.5, 0.52, 0.58)
const C_OWNED := Color(0.78, 0.8, 0.86)       # 얻었지만 장착하지 않은 코어

var profile                          # main.gd 가 연결 (profile.gd)
var ui_scale := 1.0
var font: SystemFont
var sub: Label
var map: MapView
var core_labels := {}                # 코어 id → Label
var jump_button: Button
var back_button: Button
var title_l: Label
var core_head: Label
var allow_back := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(28 * ui_scale))
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(10 * ui_scale))
	margin.add_child(root)

	title_l = _label(Loc.t("항로도 — 퇴각 항로"), 32, Color(1.0, 0.95, 0.88))
	root.add_child(title_l)
	sub = _label("", 18, Color(0.75, 0.8, 0.88))
	root.add_child(sub)

	map = MapView.new()
	map.world = self
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(0, 280) * ui_scale
	root.add_child(map)

	core_head = _label("", 17, Color(1.0, 0.8, 0.55))
	root.add_child(core_head)
	for id in Upgrades.CORES:
		var l := _label("", 16, C_TAKEN)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_STOP              # 눌러서 장착·교체
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				equip(id))
		root.add_child(l)
		core_labels[id] = l

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	back_button = Button.new()
	back_button.text = Loc.t("뒤로")
	back_button.custom_minimum_size = Vector2(160, 60) * ui_scale
	back_button.add_theme_font_override("font", font)
	back_button.add_theme_font_size_override("font_size", int(18 * ui_scale))
	back_button.pressed.connect(back)
	bottom.add_child(back_button)
	jump_button = Button.new()
	jump_button.text = Loc.t("FTL 도약 ▶")
	jump_button.custom_minimum_size = Vector2(300, 60) * ui_scale
	jump_button.add_theme_font_override("font", font)
	jump_button.add_theme_font_size_override("font_size", int(18 * ui_scale))
	jump_button.pressed.connect(jump)
	bottom.add_child(jump_button)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(size * ui_scale))
	l.add_theme_color_override("font_color", col)
	return l


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	map.ship_at = float(profile.stage)
	refresh()


func close() -> void:
	visible = false


## 타이틀로 돌아간다 (타이틀에서 연 경우만)
func back() -> void:
	if not visible or not allow_back:
		return
	close()
	back_requested.emit()


func jump() -> void:
	if not visible:
		return
	close()
	jump_requested.emit()


## 코어 장착·교체 (얻은 코어만)
func equip(id: String) -> bool:
	if not profile.toggle_equip(id):
		return false
	refresh()
	return true


## 월드 맵에서 스테이지를 고른다 (고를 수 없는 곳이면 false)
func select(i: int) -> bool:
	if not profile.select_stage(i):
		return false
	refresh()
	return true


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			jump()
		KEY_ESCAPE, KEY_BACKSPACE:
			back()
		KEY_LEFT:
			select(profile.stage - 1)
		KEY_RIGHT:
			select(profile.stage + 1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:   # 숫자 키: 그 번째 코어 장착·교체
			var ids := Upgrades.CORES.keys()
			var k: int = e.keycode - KEY_1
			if k < ids.size():
				equip(ids[k])
	get_viewport().set_input_as_handled()            # 맵을 연 동안엔 다른 키(ESC 메뉴 등)를 막는다. 나가는 길은 FTL 도약


func refresh() -> void:
	title_l.text = Loc.t("항로도 — 퇴각 항로")                 # 언어가 바뀌었을 수 있으니 열 때마다 다시
	core_head.text = Loc.t("동력 코어 — 장착한 코어만 작동합니다 (장착 칸 %d개). 눌러서 장착·교체") % profile.slots()
	jump_button.text = Loc.t("FTL 도약 ▶")
	back_button.text = Loc.t("뒤로")
	back_button.visible = allow_back
	var st: Dictionary = Stages.LIST[profile.stage]
	sub.text = Loc.t("도약지: %d. %s — 콜로서스 「%s」%s   ·   은하를 눌러 고르기 (깬 곳은 다시 싸울 수 있음)") % [
		profile.stage + 1, Loc.t(st["coord"]), Loc.t(st["name"]), Loc.t(" (재전투)") if profile.is_cleared(profile.stage) else ""]
	var n := 0
	for id in core_labels:
		n += 1
		var l: Label = core_labels[id]
		var c: Dictionary = Upgrades.CORES[id]
		if profile.equipped.has(id):
			l.text = "%d ◆ %s — %s   [%s]" % [n, Loc.t(c["name"]), Loc.t(c["desc"]), Loc.t("장착")]
			l.add_theme_color_override("font_color", C_TAKEN)
		elif profile.cores.has(id):
			l.text = "%d ◇ %s — %s" % [n, Loc.t(c["name"]), Loc.t(c["desc"])]
			l.add_theme_color_override("font_color", C_OWNED)
		else:
			l.text = Loc.t("??? — 콜로서스 「%s」를 처리하면 얻습니다") % _stage_name(c["from"])
			l.add_theme_color_override("font_color", C_LOCKED)
	map.queue_redraw()


static func _stage_name(id: String) -> String:
	for st in Stages.LIST:
		if st["id"] == id:
			return Loc.t(st["name"])
	return id


# ═══ 항로도 그림 ════════════════════════════════════════
class MapView extends Control:
	var world                                    # 바깥 world_map
	var ship_at := 0.0                           # 기체가 떠 있는 위치 (스테이지 번호, 고르면 미끄러져 간다)
	var hover := -1
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		t += dt
		ship_at = lerpf(ship_at, float(world.profile.stage), 1.0 - exp(-6.0 * dt))
		queue_redraw()

	## i 번째 지점(0~8 은하, 9 목적지) 화면 위치: 좌우로 지그재그하며 오른쪽으로 나아간다
	func node_pos(i: int) -> Vector2:
		var n := Stages.MAP_STAGES + 1
		var x := lerpf(70.0, size.x - 80.0, float(i) / (n - 1))
		var y := size.y * (0.5 + (0.24 if i % 2 == 0 else -0.24) * (1.0 if i < n - 1 else 0.0))
		return Vector2(x, y)

	## 이름표·기체 자리: 아래쪽 은하는 이름표가 아래, 기체가 위. 위쪽 은하는 항로가 아래로 지나가므로 이름표도 위, 기체는 그 위
	func label_off(i: int) -> Vector2:
		return Vector2(0, 62) if i % 2 == 0 else Vector2(0, -50)

	func ship_off(i: int) -> float:
		return -52.0 if i % 2 == 0 else -106.0

	func _pick(p: Vector2) -> int:
		for i in Stages.MAP_STAGES:
			if node_pos(i).distance_to(p) < 42.0:
				return i
		return -1

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = _pick(e.position)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var i := _pick(e.position)
			if i >= 0:
				world.select(i)

	func _draw() -> void:
		var pr = world.profile
		var font: Font = world.font
		var n := Stages.MAP_STAGES
		# 배경 별
		for k in 90:
			var sp := Vector2(fmod(k * 137.5, size.x), fmod(k * 71.3 + k * k * 0.7, size.y))
			draw_circle(sp, 1.0 + float(k % 3) * 0.5, Color(0.7, 0.8, 1.0, 0.15 + 0.25 * float((k * 7) % 5) / 5.0))
		# 점선 항로: 깬 구간은 밝게
		for i in n:
			var a := node_pos(i)
			var b := node_pos(i + 1)
			var lit: bool = pr.is_cleared(i)
			var col := Color(0.6, 0.9, 1.0, 0.85) if lit else Color(0.45, 0.47, 0.52, 0.55)
			var d := b - a
			var steps := int(d.length() / 14.0)
			for s in steps:
				if s % 2 == 0:
					draw_line(a + d * (float(s) / steps), a + d * (float(s + 1) / steps), col, 3.0)
		# 은하
		for i in n:
			_galaxy(node_pos(i), i, pr)
		# 목적지
		var dp := node_pos(n)
		var dpulse := 0.5 + 0.5 * sin(t * 2.0)
		draw_circle(dp, 30.0 + 4.0 * dpulse, Color(0.5, 0.52, 0.58, 0.18))
		draw_circle(dp, 20.0, Color(0.32, 0.34, 0.38))
		draw_arc(dp, 30.0, 0.0, TAU, 32, Color(0.6, 0.62, 0.68, 0.7), 2.0)
		for k in 4:
			var ra := k * PI * 0.5 + PI * 0.25
			draw_line(dp + Vector2.from_angle(ra) * 34.0, dp + Vector2.from_angle(ra) * 46.0, Color(0.6, 0.62, 0.68, 0.7), 2.0)
		_text(font, "%d. %s" % [n + 1, Loc.t(Stages.DESTINATION)], dp + Vector2(0, 62), Color(0.62, 0.64, 0.7))
		# 기체: 고른 은하 위에 떠 있다
		var i0 := clampi(int(floor(ship_at)), 0, n - 1)
		var i1 := clampi(i0 + 1, 0, n - 1)
		var f := ship_at - i0
		var sp2 := node_pos(i0).lerp(node_pos(i1), f) + Vector2(0, lerpf(ship_off(i0), ship_off(i1), f) + 4.0 * sin(t * 3.0))
		var tex := Sprites.ship("b", 0.0)
		draw_texture_rect(tex, Rect2(sp2 - Vector2(24, 24), Vector2(48, 48)), false)
		draw_colored_polygon(PackedVector2Array([sp2 + Vector2(-5, 26), sp2 + Vector2(5, 26), sp2 + Vector2(0, 26 + 8.0 + 3.0 * sin(t * 20.0))]), Color(1.0, 0.6, 0.2))

	## 은하 하나: 깬 곳은 푸른 소용돌이, 고를 수 있는 다음 곳은 깜빡이는 금빛 테두리, 그 밖은 회색
	func _galaxy(p: Vector2, i: int, pr) -> void:
		var cleared: bool = pr.is_cleared(i)
		var open: bool = pr.can_play(i)
		var core := Color(0.75, 0.9, 1.0) if cleared else (Color(0.85, 0.8, 0.7) if open else Color(0.45, 0.47, 0.52))
		var arm := Color(0.45, 0.6, 1.0) if cleared else (Color(0.6, 0.58, 0.55) if open else Color(0.35, 0.37, 0.42))
		var spin := t * (0.4 if cleared or open else 0.1) + i * 1.3
		draw_circle(p, 34.0, Color(arm, 0.12))
		for k in 2:                                  # 나선 팔 두 개
			var pts := PackedVector2Array()
			for j in 16:
				var u := float(j) / 15.0
				pts.append(p + Vector2.from_angle(spin + k * PI + u * 3.2) * (6.0 + 28.0 * u) * Vector2(1.0, 0.62))
			draw_polyline(pts, Color(arm, 0.85), 3.0)
		draw_circle(p, 8.0, core)
		draw_circle(p, 4.0, Color(1, 1, 1, 0.9 if cleared or open else 0.4))
		if open and not cleared:
			draw_arc(p, 40.0, 0.0, TAU, 36, Color(1.0, 0.85, 0.45, 0.5 + 0.4 * sin(t * 5.0)), 2.5)
		if i == pr.stage:
			draw_arc(p, 46.0, 0.0, TAU, 40, Color(0.75, 0.95, 1.0, 0.9), 2.0)
		elif i == hover and open:
			draw_arc(p, 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		var name := "???"
		if i < Stages.LIST.size() and (open or cleared):
			name = Loc.t(Stages.LIST[i]["name"])
		var tag := " ✓" if cleared else ""
		_text(world.font, "%d. %s%s" % [i + 1, name, tag], p + label_off(i), core if cleared or open else Color(0.5, 0.52, 0.58))

	func _text(font: Font, s: String, p: Vector2, c: Color) -> void:
		var fs := 15
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p - Vector2(w * 0.5, 0) + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		draw_string(font, p - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

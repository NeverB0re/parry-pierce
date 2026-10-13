extends CanvasLayer
## 튜토리얼 팝업: 새 메커니즘이 처음 나올 때 게임을 멈추고 반복 재생 애니메이션 + 설명을 보여 준다.
## 애니메이션은 코드로 그린 짧은 루프(움짤)다. 한 번 본 장은 다시 자동으로 뜨지 않고(user://tutorial.cfg),
## ESC 메뉴의 '조작법'에서 언제든 다시 볼 수 있다.

const Sprites := preload("res://scripts/sprites.gd")

const ORDER := ["dodge", "parry", "charge", "unparry", "barrage", "press"]
const SAVE_PATH := "user://tutorial.cfg"

var enabled := true                  # false: 자동 팝업·저장 없음 (테스트·헤드리스)
var touch := false
var seen := {}
var queue: Array = []
var current := ""
var was_paused := false
var was_mouse := Input.MOUSE_MODE_VISIBLE

var font: SystemFont
var dim: ColorRect
var title_l: Label
var stage: Control
var desc_l: Label
var page_l: Label
var btn: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])
	_load_seen()
	_build_ui()


# ── 내용 ───────────────────────────────────────────────
func _pages() -> Dictionary:
	var dash := "화면의 큰 버튼 탭" if touch else "좌클릭"
	var hold := "큰 버튼 꾹" if touch else "좌클릭 꾹"
	var par := "작은 금색 버튼 꾹" if touch else "우클릭(또는 Space) 꾹"
	return {
		"dodge": {
			"title": "회피 — 돌진",
			"lines": [
				"%s(짧게)으로 돌진합니다. 돌진하는 동안은 무적이라 탄과 레이저를 그대로 통과할 수 있습니다. 무적인 동안은 언제나 푸른 벌집 실드가 둘러쌉니다. 단, 근접공격(팔 휘두르기·프레스)은 회피 불가 — 돌진으로 통과할 수 없습니다." % dash,
				"돌진은 쿨다운(1.15초)만 있고 횟수 제한이 없습니다. 표적에 닿으면 피해 1을 주고 위로 솟구칩니다. 솟구치는 동안만 보호막이 있고, 기체 통제를 되찾으면 사라집니다.",
				"돌진을 시작한 직후(0.12초 안)에 공격이 스치면 '퍼펙트 회피'! 다음 차지 강습의 피해가 2배가 되고(동조), 차지가 두 배 빨라지며, 돌진 쿨다운이 즉시 초기화되고, 실드가 0.8초 더 남습니다.",
			],
		},
		"parry": {
			"title": "패리 — 막고 리버스 드라이브",
			"lines": [
				"금색 탄은 %s 으로 막을 수 있습니다. 누르는 순간 짧은 패리 판정이 열리니 탄이 닿기 직전에 누르세요." % par,
				"성공하면 시간이 느려집니다. 마우스(스틱)로 방향을 정하고 버튼을 떼면 리버스 드라이브! 받아낸 에너지를 추진기로 방출해 충돌합니다. 피해 12 (PERFECT 패리는 16). 적중하면 돌진 쿨다운이 바로 돌아와 튕겨나는 중에도 돌진할 수 있습니다.",
				"금색 = 패리할 수 있는 공격입니다. 팔 휘두르기를 그냥 패리하면 피해만 막고 튕겨나기만 합니다.",
				"무엇이든 막아 내면(잔탄 흡수·근접공격 패리 포함) 패리 쿨다운이 없어져 바로 다시 패리할 수 있습니다. 헛치면 잠깐 쿨다운이 생깁니다.",
			],
		},
		"charge": {
			"title": "차지 강습 — 강한 일격과 요격",
			"lines": [
				"%s 으로 0.6초 모으고 떼면 차지 강습: 피해 3으로 일반 돌진(1)보다 훨씬 강합니다. 모으는 동안 기체가 떨리고 완료되면 빛납니다. 한 번 쓰면 1.5초 동안은 다시 모을 수 없습니다(주황 링). 적중(요격 포함)하면 돌진 쿨다운이 바로 돌아옵니다." % hold,
				"적이 팔을 들어 위치를 잡고 붉게 점멸하며 멈춰 있을 때(또는 휘두르는 중) 차지 강습으로 부딪히면 요격! 공격을 끊고 구동부에 피해 8! 리버스 드라이브로 부딪혀도 요격됩니다(피해 12).",
				"팔을 들어 올리는 중에는 요격할 수 없습니다. 근접공격(팔 휘두르기·프레스)은 일반 돌진으로 통과할 수 없습니다 — 요격하거나, 패리로 튕겨나거나, 범위 밖으로 피하세요.",
			],
		},
		"barrage": {
			"title": "탄막 — 주탄과 잔탄",
			"lines": [
				"작은 주황 별(잔탄)에 맞아도 실드 셀이 바로 깨지지 않고 왼쪽 위 '과열' 게이지가 한 칸 오릅니다(제어 불능 없음). 3칸이 차면 셀 1개가 깨지고, 5초 동안 안 맞으면 한 칸 식습니다.",
				"잔탄은 패리해도 흡수될 뿐 리버스 드라이브는 열리지 않습니다. 흡수해도 패리 쿨다운이 없어 겹쳐 오는 잔탄을 연달아 막을 수 있습니다. 일반 돌진이 끝난 직후 0.25초는 잔탄을 맞지 않습니다(옅은 실드).",
				"크고 둥근 금색 탄(주탄)과 붉은 불길을 두른 유도탄을 패리해야 리버스 드라이브가 열립니다. 유도탄은 쫓아오지만 크고 느려서 패리하기 좋습니다.",
				"바닥 가까이 머물면 융해 지대에 기뢰가 내려앉아 위로 터집니다.",
			],
		},
		"press": {
			"title": "프레스 — 천장이 내려온다 (근접, 회피 불가)",
			"lines": [
				"천장 전체가 내려와 경기장을 깔아뭉갭니다. 붉게 깜빡이는 정지선 아래로 내려가세요. 내려오는 판에 닿으면 피해를 입고 판 아래로 밀려납니다. 다 내려온 뒤(멈춤·올라감)에는 막히기만 하고 피해는 없습니다.",
				"근접공격이라 돌진의 무적으로 통과할 수 없습니다. 팔처럼 차지 강습이나 리버스 드라이브로 판을 요격하면 프레스가 걸려 도로 올라갑니다 (조준 보조가 판을 잡습니다).",
				"패리하면 막기는 하지만 거대한 힘에 아래로 내리꽂혀 융해 지대로 빠집니다. 패리하지 말고 피하세요.",
			],
		},
		"unparry": {
			"title": "패리 불가 — 보라색 공격",
			"lines": [
				"검붉은 보라색 공격(눈 레이저·심장부에서 퍼지는 동심원 파동)은 패리할 수 없습니다. 돌진의 무적으로 통과하세요. 지나갈 부채꼴과 경로가 미리 표시됩니다.",
				"돌진을 시작한 직후(0.12초 안)에 스치게 피하면 '강한 퍼펙트 회피'! 다음 차지 강습의 피해가 4배(완전 동조), 무적 1.2초, 기체 뒤로 금빛 꼬리가 길게 늘어집니다(리버스 드라이브 중에도 나옵니다).",
				"그 일격은 퍼펙트 패리에 준하는 큰 임팩트로 들어갑니다.",
			],
		},
	}


# ── 저장 ───────────────────────────────────────────────
func _load_seen() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for id in ORDER:
			seen[id] = bool(cf.get_value("seen", id, false))


func _save_seen() -> void:
	if not enabled:
		return
	var cf := ConfigFile.new()
	for id in ORDER:
		cf.set_value("seen", id, bool(seen.get(id, false)))
	cf.save(SAVE_PATH)


# ── 표시 ───────────────────────────────────────────────
func is_open() -> bool:
	return visible


## 처음 보는 장만 골라 연속으로 띄운다 (자동 트리거용). 이미 열려 있으면 뒤에 붙인다
func request(ids: Array) -> void:
	if not enabled:
		return
	var fresh: Array = []
	for id in ids:
		if not seen.get(id, false) and not fresh.has(id) and not queue.has(id) and current != id:
			fresh.append(id)
	if fresh.is_empty():
		return
	for id in fresh:
		seen[id] = true
	_save_seen()
	queue.append_array(fresh)
	if not visible:
		_open_next(true)


## 다시 보기 (ESC 메뉴): 본 적 있어도 띄우고, 저장은 건드리지 않는다
func replay(id: String) -> void:
	queue.clear()
	queue.append(id)
	_open_next(true)


func _open_next(first: bool) -> void:
	if queue.is_empty():
		_close()
		return
	if first and not visible:
		was_paused = get_tree().paused
		was_mouse = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current = queue.pop_front()
	var pg: Dictionary = _pages()[current]
	title_l.text = pg["title"]
	var lines: PackedStringArray = PackedStringArray()
	for l in pg["lines"]:
		lines.append("• " + String(l))
	desc_l.text = "\n".join(lines)
	page_l.text = "" if queue.is_empty() else "다음 장 %d개 남음" % queue.size()
	btn.text = "다음 (Enter)" if not queue.is_empty() else "계속하기 (Enter)"
	stage.set("kind", current)
	stage.set("t", 0.0)
	stage.set_process(true)
	visible = true
	btn.grab_focus()


func _close() -> void:
	visible = false
	stage.set_process(false)                  # 닫혀 있는 동안은 애니메이션을 돌리지 않는다
	current = ""
	queue.clear()
	get_tree().paused = was_paused
	Input.mouse_mode = was_mouse


func _input(e: InputEvent) -> void:
	if not visible:
		return
	var accept := false
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE or e.keycode == KEY_ESCAPE:
			accept = true
		get_viewport().set_input_as_handled()
	if accept:
		_open_next(false)


func _build_ui() -> void:
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	sb.border_color = Color(0.55, 0.62, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	title_l = Label.new()
	title_l.add_theme_font_override("font", font)
	title_l.add_theme_font_size_override("font_size", 28)
	title_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	box.add_child(title_l)

	stage = Stage.new()
	stage.font = font
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.custom_minimum_size = Vector2(700, 260)
	stage.clip_contents = true
	stage.set_process(false)
	box.add_child(stage)

	desc_l = Label.new()
	desc_l.add_theme_font_override("font", font)
	desc_l.add_theme_font_size_override("font_size", 17)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.custom_minimum_size = Vector2(700, 130)
	box.add_child(desc_l)

	var foot := HBoxContainer.new()
	box.add_child(foot)
	page_l = Label.new()
	page_l.add_theme_font_override("font", font)
	page_l.add_theme_font_size_override("font_size", 14)
	page_l.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	page_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(page_l)
	btn = Button.new()
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(190, 44)
	btn.pressed.connect(func() -> void: _open_next(false))
	foot.add_child(btn)


# ═══ 애니메이션 무대 ═══════════════════════════════════
class Stage extends Control:
	const Sprites := preload("res://scripts/sprites.gd")
	const GOLD := Color(1.0, 0.86, 0.3)
	const MINT := Color(0.45, 1.0, 0.85)
	const UNP := Color(0.6, 0.08, 0.36)
	const UNP_C := Color(1.0, 0.62, 0.86)
	const SMALL_C := Color(1.0, 0.58, 0.12)
	const HexShield := preload("res://scripts/hex_shield.gd")
	var kind := ""
	var t := 0.0
	var font: SystemFont

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	# ── 그리기 도우미 ──
	func _txt(s: String, p: Vector2, size: int, c: Color) -> void:
		draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, c.a * 0.8))
		draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

	func _ship(p: Vector2, heading := -PI * 0.5, alpha := 1.0, col := "b", size := 54.0) -> void:
		draw_set_transform(p, heading + PI * 0.5)
		draw_texture_rect(Sprites.ship(col, 0.0), Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), false, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0)

	func _flame(p: Vector2, heading: float, len := 18.0) -> void:
		var back := Vector2.from_angle(heading + PI)
		var side := back.orthogonal()
		var b := p + back * 14.0
		draw_colored_polygon(PackedVector2Array([b + side * 5.0, b - side * 5.0, b + back * len]), Color(0.95, 0.15, 0.05))
		draw_colored_polygon(PackedVector2Array([b + side * 2.5, b - side * 2.5, b + back * len * 0.6]), Color(1.0, 0.8, 0.3))

	func _bolt(p: Vector2, v := Vector2.LEFT) -> void:
		draw_line(p, p - v.normalized() * 34.0, Color(GOLD, 0.35), 8.0)
		draw_circle(p, 12.0, Color(GOLD, 0.25))
		draw_circle(p, 8.0, GOLD)
		draw_circle(p, 4.0, Color(1, 1, 0.9))

	func _ring(p: Vector2, r: float, c: Color, w := 2.0) -> void:
		draw_arc(p, r, 0.0, TAU, 40, c, w)

	func _spark(p: Vector2, k: float, c: Color, n := 10, rad := 40.0) -> void:
		if k < 0.0 or k > 1.0:
			return
		for i in n:
			var a := TAU * i / n + 0.3
			var d := Vector2.from_angle(a)
			draw_line(p + d * rad * (0.3 + 0.5 * k), p + d * rad * (0.5 + 0.9 * k), Color(c, 1.0 - k), 3.0)
		_ring(p, rad * (0.4 + k), Color(c, 1.0 - k), 3.0)

	func _target(p: Vector2, hit_k := 0.0, cracks := 0) -> void:
		draw_circle(p, 30.0, Color(0.1, 0.11, 0.14))
		_ring(p, 30.0, Color(0.62, 0.3, 0.14), 3.0)
		draw_circle(p, 12.0, Color(1.0, 0.42, 0.22).lerp(Color.WHITE, hit_k))
		for i in cracks:
			var a := 0.8 + i * 2.1
			draw_line(p + Vector2.from_angle(a) * 6.0, p + Vector2.from_angle(a + 0.3) * 26.0, Color(1.0, 0.7, 0.3), 2.0)

	func _mouse(p: Vector2, left: bool, right: bool) -> void:
		var r := Rect2(p - Vector2(15, 22), Vector2(30, 44))
		draw_rect(r, Color(0.2, 0.22, 0.28))
		draw_rect(r, Color(0.7, 0.75, 0.85), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(12, 16)), GOLD if left else Color(0.35, 0.38, 0.46))
		draw_rect(Rect2(r.position + Vector2(16, 2), Vector2(12, 16)), GOLD if right else Color(0.35, 0.38, 0.46))

	func _caption(s: String, c := Color(0.85, 0.9, 1.0)) -> void:
		_txt(s, Vector2(16, 28), 17, c)

	func _smooth(a: float, b: float, x: float) -> float:
		return clampf((x - a) / (b - a), 0.0, 1.0)

	# ── 장면 ──
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.07, 0.1))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.35, 0.45), false, 2.0)
		draw_rect(Rect2(0, s.y - 22, s.x, 22), Color(0.45, 0.14, 0.05))      # 용암
		draw_rect(Rect2(0, s.y - 22, s.x, 3), Color(1.0, 0.5, 0.15))
		match kind:
			"dodge":
				_dodge()
			"parry":
				_parry()
			"charge":
				_charge()
			"unparry":
				_unparry()
			"barrage":
				_barrage()
			"press":
				_press()

	func _dodge() -> void:
		var T := 6.0
		var tt := fmod(t, T)
		if tt < 3.0:
			_caption("① 돌진으로 통과 — 돌진 중엔 무적")
			var y := 150.0
			var bx := lerpf(680.0, 20.0, _smooth(0.2, 2.6, tt))
			var d0 := 1.0
			var sx := 220.0
			var dashing := tt >= d0 and tt < d0 + 0.28
			if tt >= d0:
				sx = 220.0 + 260.0 * _smooth(d0, d0 + 0.28, tt)
			if dashing:
				for k in 3:
					_ship(Vector2(sx - 26.0 * (k + 1), y), 0.0, 0.18, "b")
			_ship(Vector2(sx, y), 0.0)
			if dashing:
				HexShield.draw(self, Vector2(sx, y), 34.0, 1.0, t)
			if tt < d0:
				_flame(Vector2(sx, y), 0.0)
			_bolt(Vector2(bx, y), Vector2.LEFT)
			if tt < d0 + 0.05 and tt > d0 - 0.4:
				_txt("좌클릭!", Vector2(sx - 30.0, y + 52.0), 16, GOLD)
				_mouse(Vector2(sx + 40.0, y + 60.0), tt >= d0, false)
		else:
			_caption("② 돌진 직후 0.12초 안에 스치면 PERFECT", MINT)
			var u := tt - 3.0
			var y := 150.0
			var bx := lerpf(680.0, 20.0, _smooth(0.0, 2.4, u))
			var x0 := 200.0                              # ①과 같은 방향(오른쪽)으로 돌진한다
			var d0 := (680.0 - (x0 + 58.0)) / 660.0 * 2.4   # 탄이 바로 코앞까지 왔을 때 돌진을 시작
			var dashing := u >= d0 and u < d0 + 0.28
			var sx := x0
			if u >= d0:
				sx = x0 + 190.0 * _smooth(d0, d0 + 0.28, u)
			if dashing:
				for k in 3:
					_ship(Vector2(sx - 26.0 * (k + 1), y), 0.0, 0.18, "b")
			_ship(Vector2(sx, y), 0.0)
			if dashing:
				HexShield.draw(self, Vector2(sx, y), 34.0, 1.0, t)
			if u < d0:
				_flame(Vector2(sx, y), 0.0)
			_bolt(Vector2(bx, y), Vector2.LEFT)
			if u >= d0 - 0.4 and u < d0 + 0.05:
				_txt("좌클릭!", Vector2(x0 - 30.0, y + 52.0), 16, GOLD)
				_mouse(Vector2(x0 + 40.0, y + 60.0), u >= d0, false)
			if u >= d0 + 0.05:
				var k := _smooth(d0 + 0.05, d0 + 0.55, u)
				_ring(Vector2(sx, y), 60.0 - 40.0 * k, Color(MINT, 1.0 - k * 0.5), 2.0)
				_txt("PERFECT", Vector2(sx - 40.0, y - 50.0 - 8.0 * k), 20, MINT)
			if u >= d0 + 0.5:
				_ring(Vector2(sx, y), 34.0, Color(0.8, 0.97, 1.0, 0.8), 2.5)
				_txt("다음 차지 ×2", Vector2(sx - 52.0, y + 56.0), 16, Color(0.85, 1.0, 1.0))

	func _parry() -> void:
		var T := 6.4
		var tt := fmod(t, T)
		_caption("우클릭 꾹 → 막으면 슬로우 → 방향 정하고 떼면 리버스 드라이브", GOLD)
		var sp := Vector2(150, 175)
		var tgt := Vector2(540, 90)
		var shift := _smooth(0.0, 1.0, tt)
		var bolt_k := _smooth(0.3, 1.9, tt)
		var parried := tt >= 1.9
		var holding := tt >= 1.3 and tt < 4.0
		var ship_pos := sp
		var heading := -PI * 0.5
		var dashing := tt >= 4.0 and tt < 4.25
		if tt >= 4.0:
			ship_pos = sp.lerp(tgt - Vector2(34, -12), _smooth(4.0, 4.25, tt))
		if parried and tt < 4.0:                       # 방향 지정: 조준선이 표적 쪽으로 돌아간다
			var ta := (tgt - sp).angle()
			heading = lerp_angle(-PI * 0.5, ta, _smooth(2.1, 3.0, tt))
		elif tt >= 4.0:
			heading = (tgt - sp).angle()
		if parried and tt < 4.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 0.95, 0.1))
		_target(tgt, _smooth(4.25, 4.5, tt) * (1.0 - _smooth(4.5, 4.9, tt)), 3 if tt >= 4.25 else 0)
		if dashing:
			for k in 3:
				_ship(ship_pos - Vector2.from_angle(heading) * 24.0 * (k + 1), heading, 0.2, "r")
		_ship(ship_pos, heading, 1.0, "r" if dashing else "b")
		if tt < 4.0:
			_flame(ship_pos, heading, 14.0)
		if not parried:
			var bp := Vector2(680, 150).lerp(sp + Vector2(18, -4), bolt_k)
			_bolt(bp, Vector2(-1, 0.2))
		if holding:
			var pr := 40.0 + (4.0 if int(t * 10.0) % 2 == 0 else 0.0)
			_ring(sp, pr, Color(1.0, 0.95, 0.75, 0.9), 2.5)
		if parried and tt < 2.3:
			var k := (tt - 1.9) / 0.4
			_spark(sp + Vector2(20, -4), k, Color(1, 1, 1), 12, 56.0)
			_txt("막았다!", Vector2(sp.x - 24.0, sp.y - 62.0), 18, GOLD)
		if parried and tt >= 2.3 and tt < 4.0:
			var ta := (tgt - sp).normalized()
			var aim := Vector2.from_angle(heading)
			draw_line(ship_pos + aim * 30.0, ship_pos + aim * 360.0, Color(0.75, 0.92, 1.0, 0.8), 2.0)
			_txt("방향 지정 (슬로우)", Vector2(sp.x + 40.0, sp.y + 54.0), 16, Color(0.8, 0.92, 1.0))
		if tt >= 4.2 and tt < 5.8:
			_txt("피해 12", Vector2(tgt.x - 30.0, tgt.y - 50.0), 20, GOLD)
			_spark(tgt, _smooth(4.25, 4.8, tt), Color(1.0, 0.85, 0.5), 12, 60.0)
		_mouse(Vector2(size.x - 40.0, 60.0), false, holding)
		if holding:
			_txt("꾹", Vector2(size.x - 52.0, 100.0), 15, GOLD)
		if tt >= 4.0 and tt < 4.3:
			_txt("뗀다", Vector2(size.x - 60.0, 100.0), 15, Color(0.8, 0.9, 1.0))

	func _charge() -> void:
		var T := 8.0
		var tt := fmod(t, T)
		if tt < 3.6:
			_caption("모으면 피해 3 — 일반 돌진은 1")
			var sp := Vector2(120, 170)
			var tgt := Vector2(560, 170)
			var pos := sp
			var col := "b"
			var held := false
			# 일반 돌진
			if tt < 1.4:
				if tt >= 0.4 and tt < 0.65:
					pos = sp.lerp(tgt - Vector2(40, 0), _smooth(0.4, 0.65, tt))
				elif tt >= 0.65:
					pos = (tgt - Vector2(40, 0)).lerp(sp, _smooth(0.9, 1.4, tt))
					pos.y -= 40.0 * sin(_smooth(0.65, 1.4, tt) * PI)
				_target(tgt, _smooth(0.65, 0.8, tt) * (1.0 - _smooth(0.8, 1.2, tt)), 0)
				if tt >= 0.65 and tt < 1.3:
					_spark(tgt - Vector2(34, 0), _smooth(0.65, 1.0, tt), Color(0.85, 0.93, 1.0), 6, 28.0)
					_txt("피해 1", Vector2(tgt.x - 30.0, tgt.y - 50.0), 17, Color(0.85, 0.93, 1.0))
				_mouse(Vector2(size.x - 40.0, 60.0), tt >= 0.4 and tt < 0.65, false)
			else:
				# 차지
				var u := tt - 1.4
				var shake := Vector2.ZERO
				if u < 1.1:
					held = true
					var f := u / 1.1
					shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (0.6 + 1.6 * f)
					pos = sp + shake
					draw_arc(sp, 44.0, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1.0, 0.6, 0.2), 4.0)
					if f >= 1.0 - 0.001:
						col = "r"
				elif u < 1.4:
					pos = sp.lerp(tgt - Vector2(40, 0), _smooth(1.1, 1.4, u))
					col = "r"
				else:
					pos = tgt - Vector2(40, 0)
					col = "r"
				if u >= 1.0 and u < 1.1:
					col = "r"
				_target(tgt, _smooth(1.4, 1.55, u) * (1.0 - _smooth(1.55, 1.9, u)), 3 if u >= 1.4 else 0)
				if u >= 1.4 and u < 2.2:
					_spark(tgt - Vector2(34, 0), _smooth(1.4, 1.9, u), Color(1.0, 0.7, 0.3), 14, 56.0)
					_txt("피해 3", Vector2(tgt.x - 30.0, tgt.y - 54.0), 22, Color(1.0, 0.75, 0.35))
				_mouse(Vector2(size.x - 40.0, 60.0), held, false)
				if held:
					_txt("꾹", Vector2(size.x - 52.0, 100.0), 15, GOLD)
			_ship(pos, 0.0, 1.0, col)
		else:
			_caption("팔이 멈춰 있을 때 차지 강습으로 부딪히면 요격!", Color(1.0, 0.8, 0.6))
			var u := tt - 3.6
			var sh := Vector2(110, 60)
			var arm_len := 380.0
			var ang := 0.2
			var phase := ""
			if u < 1.2:
				phase = "prep"
				ang = lerpf(-0.5, 0.55, _smooth(0.0, 1.2, u))
			elif u < 2.4:
				phase = "set"
				ang = 0.55
			else:
				phase = "hit"
				ang = 0.55 - 0.5 * _smooth(2.7, 3.3, u)
			var fist := sh + Vector2.from_angle(ang) * arm_len
			var blink := 0.5 + 0.5 * sin(t * 24.0)
			if phase == "set":
				draw_colored_polygon(PackedVector2Array([sh, sh + Vector2.from_angle(0.55) * 420.0, sh + Vector2.from_angle(1.35) * 420.0]), Color(1.0, 0.3, 0.25, 0.1 + 0.25 * blink))
			var arm_c := Color(0.35, 0.37, 0.45)
			draw_line(sh, fist, arm_c, 22.0)
			draw_circle(fist, 24.0, Color(0.22, 0.23, 0.3))
			draw_circle(sh, 26.0, Color(0.18, 0.19, 0.25))
			var el := sh.lerp(fist, 0.55)
			draw_circle(el, 13.0, Color(1.0, 0.42, 0.22).lerp(Color.WHITE, _smooth(2.35, 2.5, u) * (1.0 - _smooth(2.5, 2.9, u))))
			if phase == "prep":
				_txt("들어 올리는 중 — 아직 요격 불가", Vector2(240, 230), 16, Color(0.75, 0.78, 0.85))
			elif phase == "set":
				_txt("위치 고정 · 붉게 점멸 = 지금!", Vector2(240, 230), 16, Color(1.0, 0.6, 0.5))
			var spx := Vector2(520, 205)
			var pos := spx
			var dashing := false
			if u >= 1.9 and u < 2.4:
				pos = spx.lerp(el + Vector2(26, 20), _smooth(1.9, 2.4, u) * 0.999)
				dashing = true
			elif u >= 2.4:
				pos = el + Vector2(26, 20) + Vector2(60.0, -60.0) * _smooth(2.4, 3.2, u)
			if u >= 1.6 and u < 1.9:
				pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0
				draw_arc(pos, 44.0, -PI * 0.5, -PI * 0.5 + TAU * _smooth(1.6, 1.9, u), 32, Color(1.0, 0.6, 0.2), 3.0)
			_ship(pos, (el - spx).angle() if u < 2.4 else -PI * 0.5, 1.0, "r" if u >= 1.6 else "b")
			if dashing:
				_ring(pos, 40.0, Color(1.0, 0.6, 0.2, 0.6), 2.0)
			if u >= 2.4 and u < 3.6:
				_spark(el, _smooth(2.4, 3.0, u), Color(1.0, 0.85, 0.5), 14, 60.0)
				_txt("요격! 구동부 피해 8", Vector2(el.x + 10.0, el.y - 36.0), 20, GOLD)
			if u >= 1.5 and u < 2.4:
				_mouse(Vector2(size.x - 40.0, 60.0), true, false)

	func _unparry() -> void:
		var T := 7.0
		var tt := fmod(t, T)
		_caption("보라색 = 패리 불가 → 돌진으로 통과", UNP_C)
		var eye := Vector2(330, 34)
		draw_circle(eye, 24.0, Color(0.1, 0.1, 0.14))
		draw_circle(eye, 8.0 + 4.0 * _smooth(0.0, 1.4, tt), UNP_C)
		var ship := Vector2(450, 148)
		var th_from := PI + 0.2
		var th_to := -0.2
		var fan_a := _smooth(0.2, 1.6, tt)
		var sweep := tt >= 1.6 and tt < 3.4
		var th := th_from
		if sweep:
			var k := (tt - 1.6) / 1.8
			th = lerpf(th_from, th_to, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
		elif tt >= 3.4:
			th = th_to
		if tt < 3.4:
			var blink := 0.65 + 0.35 * sin(t * 20.0)
			var pts := PackedVector2Array([eye])
			var a0 := th if sweep else th_from
			for j in 17:
				var a := lerpf(a0, th_to, j / 16.0)
				pts.append(eye + Vector2.from_angle(a) * 460.0)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(UNP, (0.12 + 0.22 * fan_a) * (blink if not sweep else 1.0)))
		if sweep:
			var e := eye + Vector2.from_angle(th) * 470.0
			draw_line(eye, e, Color(UNP, 0.5), 18.0)
			draw_line(eye, e, Color(UNP, 0.9), 8.0)
			draw_line(eye, e, UNP_C, 3.0)
		# 플레이어: 레이저가 지나가기 직전에 돌진
		var hit_a := (ship - eye).angle()
		var kh := (th_from - hit_a) / (th_from - th_to)             # 레이저가 기체 각도를 지나는 진행도
		var dash_t0 := 1.6 + 1.8 * 0.5                              # 근사: 아래 보정식으로 시각 계산
		dash_t0 = _beam_time(kh) - 0.09
		var dashing := tt >= dash_t0 and tt < dash_t0 + 0.28
		var pos := ship
		if tt >= dash_t0:
			pos = ship + Vector2(70.0, 0.0) * _smooth(dash_t0, dash_t0 + 0.28, tt)
		if dashing:
			for k in 3:
				_ship(pos - Vector2(22.0 * (k + 1), 0), 0.0, 0.18, "b")
		var strong := tt >= dash_t0 + 0.15
		_ship(pos, 0.0)
		if dashing:
			HexShield.draw(self, pos, 34.0, 1.0, t)
		if tt >= dash_t0 - 0.5 and tt < dash_t0:
			_txt("돌진!", Vector2(pos.x - 20.0, pos.y + 54.0), 17, GOLD)
			_mouse(Vector2(size.x - 40.0, 70.0), tt >= dash_t0 - 0.1, false)
		if strong and tt < 6.6:
			var f := _smooth(dash_t0 + 0.15, dash_t0 + 0.6, tt)
			var tl := 90.0 + 6.0 * sin(t * 30.0)          # 금빛 꼬리 (기체 뒤)
			var b0 := pos + Vector2(-16, 0)
			for L in [[16.0, 1.0, Color(1.0, 0.72, 0.2)], [10.0, 0.75, Color(1.0, 0.86, 0.38)], [5.0, 0.5, Color(1.0, 0.97, 0.78)]]:
				var w: float = L[0]
				var c0: Color = L[2]
				draw_polygon(PackedVector2Array([b0 + Vector2(0, w), b0 + Vector2(0, -w), b0 + Vector2(-tl * float(L[1]), 0)]),
					PackedColorArray([Color(c0, 0.85), Color(c0, 0.85), Color(c0, 0.0)]))
			_txt("완전 동조!", Vector2(pos.x - 70.0, pos.y - 70.0 - 6.0 * f), 20, GOLD)
			_txt("다음 차지 ×4 · 무적 1.2초", Vector2(pos.x - 100.0, pos.y + 78.0), 16, Color(1.0, 0.95, 0.75))

	## 잔탄: 작고 뾰족한 주황 별 (게임과 같은 모양)
	func _small(p: Vector2, v := Vector2.LEFT) -> void:
		draw_line(p, p - v.normalized() * 14.0, Color(SMALL_C, 0.4), 4.0)
		var r := 11.0
		var pts := PackedVector2Array()
		for j in 8:
			pts.append(p + Vector2.from_angle(j * TAU / 8.0) * (r if j % 2 == 0 else r * 0.35))
		draw_colored_polygon(pts, SMALL_C if int(t * 14.0) % 2 == 0 else Color(SMALL_C, 0.75))
		draw_circle(p, 2.5, Color(1.0, 0.93, 0.6))

	func _barrage() -> void:
		var T := 7.6
		var tt := fmod(t, T)
		var sp := Vector2(170, 165)
		if tt < 3.4:
			_caption("① 작은 주황 별(잔탄): 패리하면 흡수만 된다", Color(1.0, 0.75, 0.45))
			var holding := tt >= 0.6 and tt < 3.0
			_ship(sp, 0.0)
			_flame(sp, 0.0, 14.0)
			for k in 6:
				var bx := 700.0 - (tt - 0.2 - k * 0.32) * 420.0
				if bx > sp.x + 42.0 and bx < 700.0:
					_small(Vector2(bx, sp.y + sin(k * 1.7) * 14.0))
				elif bx <= sp.x + 42.0 and bx > sp.x - 10.0:
					_spark(sp + Vector2(40, 0), (sp.x + 42.0 - bx) / 52.0, SMALL_C, 6, 22.0)
					_txt("흡수 (쿨다운 없음)", Vector2(sp.x - 10.0, sp.y - 46.0), 16, Color(1.0, 0.75, 0.45))
			if holding:
				_ring(sp, 40.0 + (4.0 if int(t * 10.0) % 2 == 0 else 0.0), Color(1.0, 0.95, 0.75, 0.9), 2.5)
			_mouse(Vector2(size.x - 40.0, 60.0), false, holding)
		else:
			var u := tt - 3.4
			_caption("② 큰 탄·유도탄(주탄): 패리하면 리버스 드라이브", GOLD)
			var tgt := Vector2(560, 80)
			var parried := u >= 1.6
			var holding := u >= 1.2 and u < 2.8
			var heading := 0.0
			var ship_pos := sp
			if parried and u < 2.8:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 0.95, 0.1))
				heading = lerp_angle(0.0, (tgt - sp).angle(), _smooth(1.8, 2.5, u))
				var aim := Vector2.from_angle(heading)
				draw_line(sp + aim * 30.0, sp + aim * 330.0, Color(0.75, 0.92, 1.0, 0.8), 2.0)
			elif u >= 2.8:
				heading = (tgt - sp).angle()
				ship_pos = sp.lerp(tgt - Vector2(30, -14), _smooth(2.8, 3.05, u))
			_target(tgt, _smooth(3.05, 3.3, u) * (1.0 - _smooth(3.3, 3.7, u)), 3 if u >= 3.05 else 0)
			_ship(ship_pos, heading, 1.0, "r" if u >= 2.8 and u < 3.05 else "b")
			if not parried:                              # 유도탄: 휘어 들어온다 + 도는 고리
				var k := _smooth(0.0, 1.6, u)
				var a := Vector2(660, 40)
				var c := Vector2(560, 260)
				var b := sp + Vector2(22, 0)
				var hp := a.lerp(c, k).lerp(c.lerp(b, k), k)
				draw_circle(hp, 22.0, Color(1.0, 0.25, 0.1, 0.3))
				draw_circle(hp, 17.0, Color(1.0, 0.45, 0.1, 0.4))
				draw_circle(hp, 12.0, Color(1.0, 0.7, 0.15))
				draw_circle(hp, 6.0, Color(1, 1, 0.9))
				for j in 4:
					var a0 := t * 9.0 + j * TAU / 4.0
					draw_arc(hp, 26.0, a0, a0 + 1.0, 8, Color(1.0, 0.45, 0.2, 0.95), 4.0)
			if holding:
				_ring(sp, 40.0, Color(1.0, 0.95, 0.75, 0.9), 2.5)
			if parried and u < 2.0:
				_spark(sp + Vector2(20, 0), (u - 1.6) / 0.4, Color(1, 1, 1), 12, 56.0)
				_txt("막았다!", Vector2(sp.x - 24.0, sp.y - 62.0), 18, GOLD)
			if u >= 3.05 and u < 4.0:
				_txt("피해 12", Vector2(tgt.x - 30.0, tgt.y - 50.0), 20, GOLD)
			_mouse(Vector2(size.x - 40.0, 60.0), false, holding)

	## 프레스: 천장이 내려오고, 정지선 아래로 내려간 기체만 산다. 패리하면 아래로 내리꽂힌다
	func _press() -> void:
		var T := 7.0
		var tt := fmod(t, T)
		var s := size
		var stop := s.y - 90.0
		var top := 0.0
		var bottom := top
		if tt < 1.4:
			bottom = top + 14.0 * tt
		elif tt < 2.0:
			var k := (tt - 1.4) / 0.6
			bottom = lerpf(20.0, stop, k * k)
		elif tt < 2.8:
			bottom = stop
		else:
			bottom = lerpf(stop, top, _smooth(2.8, 3.6, tt))
		if tt < 3.6:
			_caption("① 붉은 정지선 아래로 피한다 — 돌진으로는 통과 못 함", Color(1.0, 0.6, 0.5))
			var y := lerpf(80.0, stop + 40.0, _smooth(0.3, 1.5, tt))
			_ship(Vector2(260, y), PI * 0.5 if tt < 1.5 else -PI * 0.5)
		else:
			_caption("② 패리하면 막기는 하지만 아래로 내리꽂힌다", Color(1.0, 0.6, 0.5))
			var u := tt - 3.6
			var b2 := 0.0
			if u < 0.8:
				b2 = lerpf(0.0, 120.0, u / 0.8)
			else:
				b2 = lerpf(120.0, stop, _smooth(0.8, 1.3, u))
			bottom = b2
			var py := 150.0
			if u >= 0.8:
				py = maxf(150.0, b2 + 20.0)
			if u >= 1.3:
				py = lerpf(stop + 20.0, s.y + 10.0, _smooth(1.3, 1.6, u))
			_ship(Vector2(420, py), -PI * 0.5)
			if u >= 0.6 and u < 0.95:
				_ring(Vector2(420, py), 40.0, Color(1.0, 0.95, 0.75, 0.9), 2.5)
				_mouse(Vector2(s.x - 40.0, 60.0), false, true)
			if u >= 1.5 and u < 2.6:
				_spark(Vector2(420, s.y - 22.0), _smooth(1.5, 2.2, u), Color(1.0, 0.45, 0.15), 12, 50.0)
				_txt("융해 지대로!", Vector2(370, s.y - 60.0), 18, Color(1.0, 0.55, 0.3))
		if tt < 2.0:
			var blink := 0.5 + 0.5 * sin(t * 20.0)
			draw_rect(Rect2(0, stop, s.x, 4), Color(1.0, 0.3, 0.25, 0.4 + 0.5 * blink))
		draw_rect(Rect2(0, top, s.x, bottom - top), Color(0.16, 0.16, 0.18))
		for k in 14:
			var x := k * 50.0
			draw_line(Vector2(x, bottom - 14.0), Vector2(x + 24.0, bottom), Color(1.0, 0.35, 0.18, 0.8), 6.0)
		draw_line(Vector2(0, bottom), Vector2(s.x, bottom), Color(1.0, 0.35, 0.18), 3.0)

	## 레이저 진행도 k(0~1)가 되는 시각 (sweep 가속 곡선을 이분법으로 역산)
	func _beam_time(target_k: float) -> float:
		var lo := 0.0
		var hi := 1.0
		for i in 20:
			var m := (lo + hi) * 0.5
			var f := m * m * (3.0 - 2.0 * m) * 0.3 + m * 0.7
			if f < target_k:
				lo = m
			else:
				hi = m
		return 1.6 + 1.8 * lo

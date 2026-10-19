extends CanvasLayer
## 튜토리얼 팝업: 새 메커니즘이 처음 나올 때 게임을 멈추고 반복 재생 애니메이션 + 설명을 보여 준다.
## 애니메이션은 코드로 그린 짧은 루프(움짤)다. 한 번 본 장은 다시 자동으로 뜨지 않고(user://tutorial.cfg),
## ESC 메뉴의 '조작법'에서 언제든 다시 볼 수 있다.
const UiFont := preload("res://scripts/ui_font.gd")

const Loc := preload("res://scripts/loc.gd")
const Sprites := preload("res://scripts/sprites.gd")

const ORDER := ["dodge", "charge", "parry", "unparry", "intercept", "barrage", "dashparry", "tentacle"]   # 처음 보여 주는 순서 (조작법 목록도 이 순서): ① 도착 시 돌진·차지, 관측자의 유도탄·동심원·대검에서 패리·패리 불가·요격 ② 도착 시 잔탄, 주포 탄에서 돌진패리 ③ 첫 연속 내려치기에서 연속 요격 (결계 위성은 스스로 알아낸다)
const SAVE_PATH := "user://tutorial.cfg"

var enabled := true                  # false: 자동 팝업·저장 없음 (테스트·헤드리스)
var touch := false
var seen := {}
var queue: Array = []
var current := ""
var was_paused := false
var was_mouse := Input.MOUSE_MODE_VISIBLE

var font: Font
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
	font = UiFont.make(PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"]))
	_load_seen()
	_build_ui()


# ── 내용 ───────────────────────────────────────────────
func _pages() -> Dictionary:
	var dash := Loc.t("화면의 큰 버튼 탭") if touch else Loc.t("좌클릭")
	var hold := Loc.t("큰 버튼 꾹") if touch else Loc.t("좌클릭 꾹")
	var par := Loc.t("작은 금색 버튼 꾹") if touch else Loc.t("우클릭 꾹")
	return {
		"dodge": {
			"title": Loc.t("회피 — 돌진"),
			"lines": [
				Loc.t("%s(짧게)으로 돌진합니다. 돌진하는 동안은 무적이라 탄을 통과할 수 있습니다.") % dash,
				Loc.t("돌진으로 표적에 부딪히면 피해를 주고 튕겨 오릅니다."),
			],
		},
		"parry": {
			"title": Loc.t("패리 — 막고 리버스 드라이브"),
			"lines": [
				Loc.t("금색 탄은 %s(으)로 막을 수 있습니다. 탄이 닿기 직전에 누르세요.") % par,
				Loc.t("막으면 시간이 느려집니다. 방향을 정하고 버튼을 떼면 리버스 드라이브 — 받아낸 힘으로 돌진하는 강력한 일격입니다."),
			],
		},
		"dashparry": {
			"title": Loc.t("돌진패리 — 돌진하며 패리"),
			"lines": [
				Loc.t("탄을 향해 돌진하면서 패리하면 돌진패리 — 이어지는 리버스 드라이브가 더 강한 피해를 줍니다."),
				Loc.t("돌진 중엔 무적이라 주탄을 둘러싼 잔탄 고리도 뚫고 들어갈 수 있습니다."),
			],
		},
		"charge": {
			"title": Loc.t("차지 강습 — 모아서 강한 일격"),
			"lines": [
				Loc.t("%s(으)로 모았다 떼면 차지 강습 — 일반 돌진보다 훨씬 강한 일격입니다.") % hold,
			],
		},
		"intercept": {
			"title": Loc.t("요격 — 멈춘 근접공격을 차지 강습으로"),
			"lines": [
				Loc.t("근접공격이 자세를 잡고 붉게 점멸할 때 차지 강습으로 부딪히면 요격! 공격을 끊고 큰 피해를 줍니다."),
				Loc.t("근접공격은 돌진으로 통과할 수 없습니다. 요격하거나 범위 밖으로 피하세요."),
			],
		},
		"barrage": {
			"title": Loc.t("잔탄 — 작은 주황 별"),
			"lines": [
				Loc.t("잔탄은 패리하면 흡수만 됩니다. 리버스 드라이브는 나가지 않습니다."),
				Loc.t("잔탄에 맞으면 과열이 한 칸 쌓이고, 세 칸이 차면 실드 셀 하나가 깨집니다. 리버스 드라이브나 동조 드라이브로 적을 맞히면 과열이 한 칸 내려갑니다."),
			],
		},
		"tentacle": {
			"title": Loc.t("연속 요격 — 이어지는 근접공격을 차례로"),
			"lines": [
				Loc.t("근접공격이 여러 번 이어지면 한 타씩 차례로 요격하세요. 요격에 성공하면 차지가 바로 다시 모여 다음 타도 요격할 수 있습니다."),
				Loc.t("끝까지 모두 요격하면 마지막 일격에 촉수가 끊어지고 방어막이 약해집니다."),
			],
		},
		"unparry": {
			"title": Loc.t("패리 불가 — 보라색 공격"),
			"lines": [
				Loc.t("보라색 공격은 패리할 수 없습니다. 돌진의 무적으로 통과하세요."),
				Loc.t("돌진을 시작한 직후 스치듯 피하면 완전 동조 — 다음 차지 강습이 매우 강해집니다."),
			],
		},
	}


## 장 제목 (ESC 메뉴·타이틀의 조작법 목록용)
func page_title(id: String) -> String:
	return String(_pages()[id]["title"])


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
	_fit_desc()
	page_l.text = "" if queue.is_empty() else Loc.t("다음 장 %d개 남음") % queue.size()
	btn.text = Loc.t("다음 (Enter)") if not queue.is_empty() else Loc.t("계속하기 (Enter)")
	stage.set("kind", current)
	stage.set("t", 0.0)
	stage.set_process(true)
	visible = true
	btn.grab_focus()


## 글이 길면(영어) 글자 크기와 그림 높이를 줄여 대화창이 화면 안에 들어오게 한다
func _fit_desc() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := minf(860.0, vp.x - 120.0)
	var text := desc_l.text
	var chosen := [160.0, 13]
	for opt in [[260.0, 17], [260.0, 16], [240.0, 15], [220.0, 15], [200.0, 14], [180.0, 14], [160.0, 13]]:
		var avail: float = vp.y - 36.0 - float(opt[0]) - 54.0 - 36.0 - 40.0
		var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, int(opt[1])).y
		if h <= avail:
			chosen = opt
			break
	stage.custom_minimum_size = Vector2(w, chosen[0])
	desc_l.add_theme_font_size_override("font_size", int(chosen[1]))
	desc_l.custom_minimum_size = Vector2(w, 0)


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
	const Loc := preload("res://scripts/loc.gd")
	const GOLD := Color(1.0, 0.86, 0.3)
	const MINT := Color(0.45, 1.0, 0.85)
	const UNP := Color(0.6, 0.08, 0.36)
	const UNP_C := Color(1.0, 0.62, 0.86)
	const SMALL_C := Color(1.0, 0.58, 0.12)
	const HexShield := preload("res://scripts/hex_shield.gd")
	var kind := ""
	var t := 0.0
	var font: Font

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

	## 돌진패리 그림의 주탄: 탄막 요새 주포 탄처럼 큰 금색 주탄 + 둘레를 도는 호위탄 고리 (게임과 같은 모양)
	func _shell(p: Vector2, v := Vector2.LEFT) -> void:
		draw_line(p, p - v.normalized() * 44.0, Color(GOLD, 0.35), 14.0)
		draw_circle(p, 20.0, Color(GOLD, 0.25))
		draw_circle(p, 14.0, GOLD)
		draw_circle(p, 7.0, Color(1, 1, 0.9))
		for j in 10:
			_small(p + Vector2.from_angle(t * 1.3 + j * TAU / 10.0) * 46.0, Vector2.from_angle(t * 1.3 + j * TAU / 10.0 + PI * 0.5))

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
			"dashparry":
				_dashparry()
			"charge":
				_charge()
			"intercept":
				_charge(true)
			"unparry":
				_unparry()
			"barrage":
				_barrage()
			"tentacle":
				_tentacle()

	func _dodge() -> void:
		var T := 6.0
		var tt := fmod(t, T)
		if tt < 3.0:
			_caption(Loc.t("① 돌진으로 통과 — 돌진 중엔 무적"))
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
				_txt(Loc.t("좌클릭!"), Vector2(sx - 30.0, y + 52.0), 16, GOLD)
				_mouse(Vector2(sx + 40.0, y + 60.0), tt >= d0, false)
		else:
			_caption(Loc.t("② 돌진으로 표적에 부딪히면 피해 + 튕겨 오른다"), GOLD)
			var u := tt - 3.0
			var sp := Vector2(200, 170)
			var tgt := Vector2(470, 150)
			var d0 := 0.6
			var hit := d0 + 0.25
			var pos := sp
			if u >= d0 and u < hit:
				pos = sp.lerp(tgt - Vector2(40, -8), _smooth(d0, hit, u))
			elif u >= hit:
				var k := _smooth(hit, hit + 0.8, u)
				pos = tgt - Vector2(40, -8) + Vector2(-60.0 * k, -110.0 * sin(k * PI * 0.5))
			var dashing := u >= d0 and u < hit
			if dashing:
				for k in 3:
					_ship(pos - Vector2(26.0 * (k + 1), -2.0 * (k + 1)), (tgt - sp).angle(), 0.18, "b")
			_target(tgt, _smooth(hit, hit + 0.1, u) * (1.0 - _smooth(hit + 0.1, hit + 0.5, u)), 1 if u >= hit else 0)
			_ship(pos, (tgt - sp).angle() if u < hit else -PI * 0.5)
			if u < d0:
				_flame(pos, (tgt - sp).angle())
			if u >= d0 - 0.4 and u < d0 + 0.05:
				_txt(Loc.t("좌클릭!"), Vector2(sp.x - 30.0, sp.y + 52.0), 16, GOLD)
				_mouse(Vector2(sp.x + 40.0, sp.y + 60.0), u >= d0, false)
			if u >= hit and u < hit + 0.9:
				_spark(tgt, _smooth(hit, hit + 0.5, u), Color(0.85, 0.93, 1.0), 8, 34.0)
				_txt(Loc.t("적중!"), Vector2(tgt.x - 30.0, tgt.y - 50.0), 18, GOLD)

	func _parry() -> void:
		var T := 6.4
		var tt := fmod(t, T)
		_caption(Loc.t("우클릭 꾹 → 막으면 슬로우 → 방향 정하고 떼면 리버스 드라이브"), GOLD)
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
			_txt(Loc.t("막았다!"), Vector2(sp.x - 24.0, sp.y - 62.0), 18, GOLD)
		if parried and tt >= 2.3 and tt < 4.0:
			var ta := (tgt - sp).normalized()
			var aim := Vector2.from_angle(heading)
			draw_line(ship_pos + aim * 30.0, ship_pos + aim * 360.0, Color(0.75, 0.92, 1.0, 0.8), 2.0)
			_txt(Loc.t("방향 지정 (슬로우)"), Vector2(sp.x + 40.0, sp.y + 54.0), 16, Color(0.8, 0.92, 1.0))
		if tt >= 4.2 and tt < 5.8:
			_txt(Loc.t("적중!"), Vector2(tgt.x - 30.0, tgt.y - 50.0), 20, GOLD)
			_spark(tgt, _smooth(4.25, 4.8, tt), Color(1.0, 0.85, 0.5), 12, 60.0)
		_mouse(Vector2(size.x - 40.0, 60.0), false, holding)
		if holding:
			_txt(Loc.t("꾹"), Vector2(size.x - 52.0, 100.0), 15, GOLD)
		if tt >= 4.0 and tt < 4.3:
			_txt(Loc.t("뗀다"), Vector2(size.x - 60.0, 100.0), 15, Color(0.8, 0.9, 1.0))

	## 돌진패리: 주탄(+호위탄 고리)을 향해 돌진하며 패리하면 이어지는 리버스 드라이브가 더 강하다
	func _dashparry() -> void:
		var T := 6.0
		var tt := fmod(t, T)
		var y := 150.0
		var x0 := 170.0
		var d0 := 1.5                                   # 돌진 시작
		var tm := d0 + 0.17                              # 돌진 중간에 탄과 만난다
		var te := minf(tt, tm)
		var sx := x0 + 300.0 * _smooth(d0, d0 + 0.28, te)
		var dashing := tt >= d0 and tt < tm
		var parried := tt >= tm
		if tt < d0:
			_caption(Loc.t("① 다가오는 탄막을 보고 스스로 돌진하며 패리를 누른다"), MINT)
		else:
			_caption(Loc.t("② 돌진하며 패리 → 더 강한 리버스 드라이브"), GOLD)
		if not parried:
			_shell(Vector2(394.0 + 180.0 * (tm - tt), y), Vector2.LEFT)
		if dashing:
			for k in 3:
				_ship(Vector2(sx - 26.0 * (k + 1), y), 0.0, 0.18, "b")
			HexShield.draw(self, Vector2(sx, y), 34.0, 1.0, t)
		_ship(Vector2(sx, y), 0.0)
		if tt < d0:
			_flame(Vector2(sx, y), 0.0)
		if tt >= d0 - 0.5 and tt < tm + 0.3:
			_mouse(Vector2(size.x - 40.0, 60.0), tt >= d0 and tt < d0 + 0.15, tt >= d0 + 0.02)
		if tt >= d0 - 0.5 and tt < d0:
			_txt(Loc.t("돌진 + 패리!"), Vector2(x0 - 40.0, y + 52.0), 16, GOLD)
		if dashing:
			_ring(Vector2(sx, y), 46.0, Color(0.5, 1.0, 0.88, 0.9), 3.0)
		if parried and tt < 4.6:
			_spark(Vector2(sx + 30.0, y), _smooth(tm, tm + 0.5, tt), Color(1, 1, 1), 12, 56.0)
			_txt(Loc.t("돌진패리!"), Vector2(sx - 70.0, y - 62.0), 20, GOLD)
			if tt >= tm + 0.5:
				_txt(Loc.t("더 강한 피해"), Vector2(sx - 100.0, y + 64.0), 16, MINT)

	func _charge(intercept := false) -> void:   # 앞 3.6초 = 차지 강습, 뒤 4.4초 = 요격 (따로 반복)
		var tt := 3.6 + fmod(t, 4.4) if intercept else fmod(t, 3.6)
		if tt < 3.6:
			_caption(Loc.t("모으면 더 강하다 — 일반 돌진보다"))
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
					_txt(Loc.t("약한 일격"), Vector2(tgt.x - 30.0, tgt.y - 50.0), 17, Color(0.85, 0.93, 1.0))
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
					_txt(Loc.t("강한 일격"), Vector2(tgt.x - 30.0, tgt.y - 54.0), 22, Color(1.0, 0.75, 0.35))
				_mouse(Vector2(size.x - 40.0, 60.0), held, false)
				if held:
					_txt(Loc.t("꾹"), Vector2(size.x - 52.0, 100.0), 15, GOLD)
			_ship(pos, 0.0, 1.0, col)
		else:
			_caption(Loc.t("멈춘 근접 공격에 차지 강습으로 부딪히면 요격!"), Color(1.0, 0.8, 0.6))
			# 근접공격(그림은 대검): 떠오름(요격 불가) → 자세 고정·붉게 점멸(지금!) → 차지 강습으로 부딪힘 → 공격이 튕겨 나간다
			var u := tt - 3.6
			var piv := Vector2(250, 30)
			var ang := 0.45
			var phase := ""
			if u < 1.2:
				phase = "rise"
				var k := _smooth(0.0, 1.2, u)
				piv = Vector2(200, 230).lerp(Vector2(250, 30), k)
				ang = lerpf(1.5, 0.45, k)
			elif u < 2.4:
				phase = "set"
			else:
				phase = "hit"
				var k := _smooth(2.4, 3.3, u)
				piv = Vector2(250, 30) + Vector2(-70.0, 20.0) * k
				ang = 0.45 - 0.45 * k
			var blink := 0.5 + 0.5 * sin(t * 24.0)
			if phase == "set":                                          # 예고: 쓸고 지나갈 띠 (붉게 점멸)
				var band := PackedVector2Array()
				for q in 13:
					band.append(piv + Vector2.from_angle(lerpf(0.45, 1.65, q / 12.0)) * 215.0)
				for q in range(12, -1, -1):
					band.append(piv + Vector2.from_angle(lerpf(0.45, 1.65, q / 12.0)) * 30.0)
				draw_colored_polygon(band, Color(1.0, 0.16, 0.12, 0.08 + 0.2 * blink))
			_draw_blade(piv, ang, (0.4 + 0.6 * blink) if phase == "set" else 0.0)
			if phase == "set":
				_txt(Loc.t("자세 고정 · 붉게 점멸 = 지금!"), Vector2(250, 250), 16, Color(1.0, 0.6, 0.5))
			var mid := Vector2(250, 30) + Vector2.from_angle(0.45) * 120.0
			var spx := Vector2(250, 30) + Vector2.from_angle(1.05) * 175.0   # 기체는 대검이 쓸고 지나갈 띠 한가운데 (검이 기체를 노린다)
			var pos := spx
			var dashing := false
			if u >= 1.9 and u < 2.2:
				pos = spx.lerp(mid + Vector2(14, 22), _smooth(1.9, 2.2, u) * 0.999)
				dashing = true
			elif u >= 2.2:
				pos = mid + Vector2(14, 22) + Vector2(60.0, 30.0) * _smooth(2.4, 3.2, u)
			if u >= 1.6 and u < 1.9:
				pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0
			_ship(pos, (mid - spx).angle() if u < 2.4 else (mid - spx).angle(), 1.0, "r" if u >= 1.6 else "b")
			if dashing:
				_ring(pos, 40.0, Color(1.0, 0.6, 0.2, 0.6), 2.0)
			if u >= 2.4 and u < 3.6:
				_spark(mid, _smooth(2.4, 3.0, u), Color(1.0, 0.85, 0.5), 14, 60.0)
				_txt(Loc.t("요격!"), Vector2(mid.x + 10.0, mid.y + 40.0), 22, GOLD)
			if u >= 1.5 and u < 2.4:
				_mouse(Vector2(size.x - 40.0, 60.0), true, false)

	## 근접공격 그림 (대검): 회전축 piv 에서 ang 방향으로 날밑·날. hot = 진홍 테두리
	func _draw_blade(piv: Vector2, ang: float, hot: float) -> void:
		var d := Vector2.from_angle(ang)
		var n := d.orthogonal()
		var g := piv + d * 25.0
		var tip := piv + d * 205.0
		var blade := PackedVector2Array([g + n * 11.0, tip - d * 30.0 + n * 9.0, tip, tip - d * 30.0 - n * 9.0, g - n * 11.0])
		draw_line(piv - d * 10.0, g, Color(0.12, 0.13, 0.16), 10.0)
		draw_colored_polygon(blade, Color(0.42, 0.45, 0.52).lerp(Color(1.0, 0.16, 0.12), 0.3 * hot))
		if hot > 0.0:
			var ol := blade.duplicate()
			ol.append(blade[0])
			draw_polyline(ol, Color(1.0, 0.16, 0.12, hot), 3.0)
		draw_line(g + n * 28.0, g - n * 28.0, Color(0.12, 0.13, 0.16), 8.0)

	## 촉수 요격: 겨누고 멈춘 촉수에 차지 강습 → 움츠러들고 전류가 방어막 속 외눈으로 → 끊어진 촉수는 떨어져 나간다
	func _tentacle() -> void:
		var T := 7.4
		var tt := fmod(t, T)
		var root := Vector2(560, -20)
		var sp := Vector2(330, 195)                     # 기체 (아래)
		var hit_y := 105.0                              # 촉수 끝이 내려와 멈추는 높이 (요격 지점)
		var n := 3
		var t0 := 0.5
		var gap := 1.7
		var cut := tt >= t0 + 2.0 * gap + 1.0           # 세 번째를 받아친 뒤 끊어진다
		var idx := clampi(int((tt - t0) / gap), 0, n - 1)
		var u := tt - (t0 + idx * gap)                   # 이번 타 안의 시각: 0~0.5 들어 올림, 0.5~1.0 멈춰 점멸, 1.0 요격, 이후 튕겨 오름
		var tip := Vector2(sp.x, hit_y)
		if tt < t0:
			tip = Vector2(sp.x + 40.0, 40.0)
		elif u < 0.5:
			tip = Vector2(sp.x, lerpf(40.0, hit_y, _smooth(0.0, 0.5, u)))
		elif u >= 1.0:
			tip = Vector2(sp.x, hit_y - 90.0 * _smooth(1.0, 1.3, u) * (1.0 - _smooth(1.3, gap, u)))
		if cut:
			tip = Vector2(sp.x + 80.0, 215.0) - Vector2(0, 30.0 * (1.0 - _smooth(t0 + 2.0 * gap + 1.0, t0 + 2.0 * gap + 1.5, tt)))
		var mid := root.lerp(tip, 0.45) + Vector2(60.0, 0)
		var pts := PackedVector2Array()
		for q in 13:
			pts.append(root.bezier_interpolate(mid + Vector2(0, -60), mid + Vector2(0, 30), tip, q / 12.0))
		var col := Color(0.2, 0.26, 0.28)
		if cut:                                          # 끊어진 촉수: 끝 토막이 떨어지고 뿌리 쪽만 남는다
			for q in 6:
				draw_line(pts[q], pts[q + 1], Color(0.12, 0.13, 0.14), lerpf(26.0, 17.0, q / 5.0))
			draw_line(tip + Vector2(-50, -60), tip, Color(0.12, 0.13, 0.14), 12.0)
		else:
			for q in 12:
				draw_line(pts[q], pts[q + 1], col, lerpf(26.0, 10.0, q / 11.0))
		var aiming := not cut and tt >= t0 and u >= 0.5 and u < 1.0
		if aiming:                                       # 멈춰 붉게 점멸 (요격할 때)
			var blink := 0.5 + 0.5 * sin(t * 24.0)
			draw_rect(Rect2(sp.x - 18.0, hit_y, 36.0, sp.y - hit_y + 24.0), Color(1.0, 0.16, 0.12, 0.08 + 0.15 * blink))
		var pos := sp
		var charging := not cut and tt >= t0 and u >= 0.55 and u < 0.85
		if charging:
			pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0
		elif not cut and tt >= t0 and u >= 0.85 and u < 1.0:
			pos = sp.lerp(tip + Vector2(0, 26), _smooth(0.85, 1.0, u))
		elif not cut and tt >= t0 and u >= 1.0 and u < 1.4:
			pos = (tip + Vector2(0, 26)).lerp(sp, _smooth(1.0, 1.4, u))
		_ship(pos, -PI * 0.5, 1.0, "r" if charging or (u >= 0.85 and u < 1.0) else "b")
		var done := mini(n, int((tt - t0 - 1.0) / gap) + 1) if tt >= t0 + 1.0 else 0
		for q in n:                                      # 이번 연속 공격의 타 (요격한 타는 금빛)
			var c := Vector2(40.0 + q * 30.0, 195.0)
			draw_circle(c, 9.0, GOLD if q < done else Color(0.3, 0.32, 0.38))
		if not cut and tt >= t0 and u >= 1.0 and u < 1.5:
			_spark(tip + Vector2(0, 10), _smooth(1.0, 1.4, u), Color(1.0, 0.85, 0.5), 12, 46.0)
			_txt(Loc.t("요격! 차지 즉시 회복"), Vector2(sp.x + 34.0, sp.y - 40.0), 16, GOLD)
		if cut:
			_caption(Loc.t("② 끝까지 요격 → 촉수가 끊어지고 방어막이 약해진다"), GOLD)
		else:
			_caption(Loc.t("① 이어지는 내려치기를 한 타씩 차지 강습으로 요격"), Color(1.0, 0.8, 0.6))
		if charging:
			_mouse(Vector2(size.x - 40.0, 60.0), true, false)

	func _unparry() -> void:
		var T := 7.0
		var tt := fmod(t, T)
		_caption(Loc.t("보라색 = 패리 불가 → 돌진으로 통과"), UNP_C)
		var gem := Vector2(80, 150)                                  # 보라 수정: 모았다가(0~1.2초) 동심원을 쏜다
		var charge := _smooth(0.0, 1.2, tt) * (1.0 - _smooth(1.2, 1.5, tt))
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -34), gem + Vector2(22, 0), gem + Vector2(0, 34), gem + Vector2(-22, 0)]), UNP.lerp(UNP_C, charge))
		if charge > 0.0:
			draw_circle(gem, 30.0 + 40.0 * charge, Color(UNP, 0.25 * charge))
		var ship := Vector2(450, 150)
		var SPEED := 260.0
		var reach := 1.2 + (ship.x - gem.x) / SPEED                  # 고리가 기체에 닿는 시각
		var r := (tt - 1.2) * SPEED
		if tt >= 1.2 and r < 620.0:
			draw_arc(gem, r, -1.1, 1.1, 48, Color(UNP, 0.45), 22.0)
			draw_arc(gem, r, -1.1, 1.1, 48, Color(UNP, 0.95), 9.0)
			draw_arc(gem, r, -1.1, 1.1, 48, UNP_C, 3.0)
		var dash_t0 := reach - 0.14                                   # 닿기 직전, 고리가 오는 쪽(왼쪽)으로 달려든다
		var dashing := tt >= dash_t0 and tt < dash_t0 + 0.28
		var pos := ship
		if tt >= dash_t0:
			pos = ship + Vector2(-90.0, 0.0) * _smooth(dash_t0, dash_t0 + 0.28, tt)
		if dashing:
			for k in 3:
				_ship(pos + Vector2(22.0 * (k + 1), 0), PI, 0.18, "b")
		var strong := tt >= dash_t0 + 0.15
		_ship(pos, PI)
		if dashing:
			HexShield.draw(self, pos, 34.0, 1.0, t)
		if tt >= dash_t0 - 0.6 and tt < dash_t0:
			_txt(Loc.t("돌진!"), Vector2(pos.x - 20.0, pos.y + 54.0), 17, GOLD)
			_mouse(Vector2(size.x - 40.0, 70.0), tt >= dash_t0 - 0.1, false)
		if strong and tt < 6.6:
			var f := _smooth(dash_t0 + 0.15, dash_t0 + 0.6, tt)
			var tl := 90.0 + 6.0 * sin(t * 30.0)          # 금빛 꼬리 (기체 뒤 = 오른쪽)
			var b0 := pos + Vector2(16, 0)
			for L in [[16.0, 1.0, Color(1.0, 0.72, 0.2)], [10.0, 0.75, Color(1.0, 0.86, 0.38)], [5.0, 0.5, Color(1.0, 0.97, 0.78)]]:
				var w: float = L[0]
				var c0: Color = L[2]
				draw_polygon(PackedVector2Array([b0 + Vector2(0, w), b0 + Vector2(0, -w), b0 + Vector2(tl * float(L[1]), 0)]),
					PackedColorArray([Color(c0, 0.85), Color(c0, 0.85), Color(c0, 0.0)]))
			_txt(Loc.t("완전 동조!"), Vector2(pos.x - 50.0, pos.y - 70.0 - 6.0 * f), 20, GOLD)
			_txt(Loc.t("다음 차지 크게 강화 · 무적"), Vector2(pos.x - 90.0, pos.y + 78.0), 16, Color(1.0, 0.95, 0.75))

	## 잔탄: 작고 뾰족한 주황 별 (게임과 같은 모양)
	func _small(p: Vector2, v := Vector2.LEFT) -> void:
		draw_line(p, p - v.normalized() * 14.0, Color(SMALL_C, 0.4), 4.0)
		var r := 11.0
		var pts := PackedVector2Array()
		for j in 8:
			pts.append(p + Vector2.from_angle(j * TAU / 8.0) * (r if j % 2 == 0 else r * 0.35))
		draw_colored_polygon(pts, SMALL_C if int(t * 14.0) % 2 == 0 else Color(SMALL_C, 0.75))
		draw_circle(p, 2.5, Color(1.0, 0.93, 0.6))

	## 게임의 과열 링 (player._draw_heat_ring 과 같은 모양): 기체 둘레 세 칸, 맞을 때마다 한 칸씩 차오른다. brk = 셀이 깨진 순간 붉게 깜빡임
	func _heat_ring(p: Vector2, filled: int, flash_k := -1, flash := 0.0, brk := 0.0) -> void:
		var seg := TAU / 3.0
		for k in 3:
			var a0 := -PI * 0.5 + k * seg + 0.14
			var a1 := -PI * 0.5 + (k + 1) * seg - 0.14
			if brk > 0.0:
				draw_arc(p, 46.0, a0, a1, 12, Color(1.0, 0.2, 0.12, 0.9 if fmod(brk * 8.0, 1.0) > 0.4 else 0.3), 4.0)
			elif k < filled:
				draw_arc(p, 46.0, a0, a1, 12, Color(1.0, 0.62, 0.18).lerp(Color.WHITE, flash if k == flash_k else 0.0), 4.0)
			else:
				draw_arc(p, 46.0, a0, a1, 12, Color(0.3, 0.16, 0.1, 0.55), 2.5)

	## 게임의 좌상단 실드 셀 (hud._draw_life 처럼): 기체 아이콘 셋. 깨진 셀은 어둡게 + 금, 다음에 깨질 셀은 과열만큼 달아오른다
	func _lives(alive: int, heat := 0.0) -> void:
		for i in 3:
			var o := Vector2(30.0 + i * 34.0, 62.0)
			if i < alive:
				if i == alive - 1 and heat > 0.0:
					draw_circle(o, 19.0, Color(1.0, 0.4, 0.1, 0.12 + 0.3 * heat))
				_ship(o, -PI * 0.5, 1.0, "b", 34.0)
			else:
				_ship(o, -PI * 0.5, 0.3, "b", 34.0)
				draw_line(o + Vector2(-5, -12), o + Vector2(2, -2), Color(0.05, 0.05, 0.07), 2.0)
				draw_line(o + Vector2(2, -2), o + Vector2(-3, 10), Color(0.05, 0.05, 0.07), 2.0)

	func _barrage() -> void:
		var T := 9.0
		var tt := fmod(t, T)
		var sp := Vector2(330, 170)
		if tt < 2.8:
			_caption(Loc.t("① 잔탄은 패리하면 흡수만 — 리버스 드라이브는 없다"), Color(1.0, 0.75, 0.45))
			_lives(3)
			var holding := tt >= 0.5 and tt < 2.5
			_ship(sp, 0.0)
			_flame(sp, 0.0, 14.0)
			for k in 4:
				var bx := 760.0 - (tt - 0.2 - k * 0.32) * 420.0
				if bx > sp.x + 42.0 and bx < 760.0:
					_small(Vector2(bx, sp.y + sin(k * 1.7) * 14.0))
				elif bx <= sp.x + 42.0 and bx > sp.x - 10.0:
					_spark(sp + Vector2(40, 0), (sp.x + 42.0 - bx) / 52.0, SMALL_C, 6, 22.0)
					_txt(Loc.t("흡수"), Vector2(sp.x - 10.0, sp.y - 60.0), 16, Color(1.0, 0.75, 0.45))
			if holding:
				_ring(sp, 40.0 + (4.0 if int(t * 10.0) % 2 == 0 else 0.0), Color(1.0, 0.95, 0.75, 0.9), 2.5)
			_mouse(Vector2(size.x - 40.0, 60.0), false, holding)
		elif tt < 6.2:
			var u := tt - 2.8
			_caption(Loc.t("② 맞을 때마다 과열이 한 칸씩 차오르고, 가득 차면 실드 셀 하나가 깨진다"), Color(1.0, 0.55, 0.35))
			var hits := [0.6, 1.4, 2.2]
			var n := 0
			for h in hits:
				if u >= h:
					n += 1
			var broke := n >= 3
			var last_h: float = hits[maxi(0, n - 1)]
			var fl := 1.0 - _smooth(last_h, last_h + 0.35, u) if n > 0 else 0.0
			_lives(2 if broke else 3, float(n) / 3.0 if not broke else 0.0)
			_ship(sp, 0.0)
			_heat_ring(sp, 0 if broke and u >= 2.2 + 0.7 else n, n - 1, fl, (2.2 + 0.7 - u) if broke and u < 2.2 + 0.7 else 0.0)
			for k in 3:                                     # 잔탄이 하나씩 날아와 맞는다
				var hk: float = hits[k]
				var bx := lerpf(760.0, sp.x + 20.0, _smooth(hk - 0.6, hk, u))
				if u >= hk - 0.6 and u < hk:
					_small(Vector2(bx, sp.y - 4.0 + k * 4.0))
				if u >= hk and u < hk + 0.4:
					_spark(sp + Vector2(16, 0), _smooth(hk, hk + 0.4, u), Color(1.0, 0.4, 0.1), 8, 30.0)
			if broke and u >= 2.2 and u < 3.2:
				_spark(Vector2(98, 62), _smooth(2.2, 2.8, u), Color(1.0, 0.4, 0.2), 10, 26.0)
				_txt(Loc.t("실드 셀 깨짐"), Vector2(130, 56), 16, Color(1.0, 0.5, 0.35))
		else:
			var u := tt - 6.2
			_caption(Loc.t("③ 리버스 드라이브·동조 드라이브로 적을 맞히면 과열이 한 칸 빠진다"), GOLD)
			var tgt := Vector2(660, 80)
			var go := _smooth(0.6, 0.9, u)
			var heading := (tgt - sp).angle()
			var pos := sp.lerp(tgt - Vector2(34, -12), go)
			var n := 2 if u < 0.9 else 1
			_lives(3, float(n) / 3.0)
			_target(tgt, _smooth(0.9, 1.1, u) * (1.0 - _smooth(1.1, 1.6, u)), 3 if u >= 0.9 else 0)
			if u >= 0.6 and u < 0.9:
				for k in 3:
					_ship(pos - Vector2.from_angle(heading) * 24.0 * (k + 1), heading, 0.2, "r")
			_ship(pos, heading, 1.0, "r" if u >= 0.6 and u < 0.9 else "b")
			_heat_ring(pos, n, 1, 1.0 - _smooth(0.9, 1.3, u) if u >= 0.9 else 0.0)
			if u >= 0.9:
				_spark(tgt, _smooth(0.9, 1.4, u), Color(1.0, 0.85, 0.5), 12, 60.0)
				_txt(Loc.t("과열 -1"), Vector2(pos.x - 30.0, pos.y + 56.0), 18, Color(0.75, 0.95, 1.0))

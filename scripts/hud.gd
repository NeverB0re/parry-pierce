extends Control
## HUD: 체력 가면, 추진 게이지, 배너, 비네트, 화면 플래시.

const Player := preload("res://scripts/player.gd")

var main: Node
var font: SystemFont
var banner_title := ""
var banner_sub := ""
var flash_a := 0.0
var flash_c := Color.WHITE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])


func banner(title: String, sub := "") -> void:
	banner_title = title
	banner_sub = sub


func clear_banner() -> void:
	banner_title = ""
	banner_sub = ""


func flash(a: float, c := Color.WHITE) -> void:
	flash_a = maxf(flash_a, a)
	flash_c = c


func step(dt: float) -> void:
	flash_a = maxf(0.0, flash_a - dt * 3.0)
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos + Vector2(2, 2), s, align, width, size, Color(0, 0, 0, c.a * 0.7))
	draw_string(font, pos, s, align, width, size, c)


func _draw() -> void:
	var s := get_viewport_rect().size
	_draw_vignette(s)
	var pl = main.player
	var boss = main.boss

	# 용암 경고: 낮을수록 화면 아래가 붉게 물든다
	var heat := clampf(1.0 + pl.position.y / 500.0, 0.0, 1.0)
	if heat > 0.0:
		var hc := Color(1.0, 0.25, 0.05, 0.45 * heat)
		var hz := Color(1.0, 0.25, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.45), Vector2(s.x, s.y * 0.45), s, Vector2(0, s.y)]), PackedColorArray([hz, hz, hc, hc]))

	# 목숨 (가면)
	for i in main.LIVES:
		var o := Vector2(46 + i * 46, 46)
		var mask := PackedVector2Array([o + Vector2(-14, -10), o + Vector2(-18, -26), o + Vector2(-6, -16), o + Vector2(0, -18),
			o + Vector2(6, -16), o + Vector2(18, -26), o + Vector2(14, -10), o + Vector2(14, 8), o + Vector2(6, 18),
			o + Vector2(-6, 18), o + Vector2(-14, 8)])
		if i < main.lives:
			draw_colored_polygon(mask, Color(0.93, 0.92, 0.88))
			draw_circle(o + Vector2(-6, 0), 4.0, Color(0.05, 0.05, 0.08))
			draw_circle(o + Vector2(6, 0), 4.0, Color(0.05, 0.05, 0.08))
		else:
			var closed := mask.duplicate()
			closed.append(mask[0])
			draw_polyline(closed, Color(0.6, 0.6, 0.65, 0.5), 2.0)

	# 추진 게이지
	_text(Vector2(28, 100), "추진", 16, Color(0.8, 0.82, 0.86, 0.8))
	for i in Player.GAUGE_MAX:
		var c := Vector2(86 + i * 24, 94)
		if i < pl.gauge:
			draw_circle(c, 8.0, Color(1.0, 0.75, 0.45))
			draw_circle(c, 4.0, Color(1.0, 0.95, 0.85))

		else:
			draw_arc(c, 8.0, 0.0, TAU, 20, Color(0.7, 0.7, 0.75, 0.5), 2.0)
			if i == 0 and pl.gauge == 0 and pl.regen_t > 0.0:   # 재생 진행 (1칸까지)
				draw_arc(c, 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(pl.regen_t / Player.GAUGE_REGEN_TIME, 0.0, 1.0), 20, Color(1.0, 0.75, 0.45, 0.95), 3.0)

	_draw_target_marker(s, boss)
	if not boss.dead and boss.atk.get("kind", "") == "beam" and s.x >= 300.0:   # 레이저 중 머리가 화면 밖이면 방향 표시
		_edge_arrow(s, main.get_viewport().get_canvas_transform() * boss.HEAD_POS, Color(0.85, 0.2, 0.55))

	# 상태 정보
	var left: String = ("부위 %d" % boss.parts_left()) if boss.phase == 1 else ("갑옷 %d" % boss.plates_left())
	_text(Vector2(28, 140), "%s   %.1fs" % [left, main.run_time], 15, Color(0.75, 0.77, 0.82, 0.7))

	# 배너
	if banner_title != "":
		draw_rect(Rect2(0, s.y * 0.5 - 70, s.x, 140), Color(0, 0, 0, 0.45))
		_text(Vector2(0, s.y * 0.5 + 6), banner_title, 56, Color(1, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		_text(Vector2(0, s.y * 0.5 + 46), banner_sub, 20, Color(0.8, 0.82, 0.86), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	# 패리 성공 후 방향 지정(슬로우)
	if pl.aim_phase:
		var total: float = Player.AIM_TIME_PERFECT if pl.aim_perfect else Player.AIM_TIME
		var frac := clampf(pl.aim_left / total, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.5, 0.95, 0.14))
		var bw := 320.0
		var bx := (s.x - bw) * 0.5
		draw_rect(Rect2(bx, s.y * 0.7, bw, 8), Color(1, 1, 1, 0.2))
		draw_rect(Rect2(bx, s.y * 0.7, bw * frac, 8), Color(0.8, 0.92, 1.0, 0.95))

	# 조작
	_text(Vector2(28, s.y - 24), "마우스: 방향(위=활공)   좌클릭: 회피 돌진 / 꾹: 차지 공격   우클릭·Space 꾹: 패리 → 슬로우 조준 → 패리 돌진   R: 재시작   Esc: 메뉴", 15, Color(0.75, 0.77, 0.82, 0.55))

	if flash_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(flash_c, flash_a))


## 다음 표적(부위 또는 심장)이 화면 밖이면 가장자리에 방향 표시
func _draw_target_marker(s: Vector2, boss) -> void:
	if boss.dead or s.x < 300.0 or s.y < 300.0:
		return
	var sp: Vector2 = main.get_viewport().get_canvas_transform() * boss.target_pos(main.player.position)
	_edge_arrow(s, sp, Color(1.0, 0.5, 0.25))


## 화면 밖의 지점 sp 를 가리키는 가장자리 화살표
func _edge_arrow(s: Vector2, sp: Vector2, col: Color) -> void:
	var m := 36.0
	if Rect2(Vector2.ZERO, s).has_point(sp):
		return
	var center := s * 0.5
	var d := sp - center
	var k := minf((s.x * 0.5 - m) / maxf(absf(d.x), 0.001), (s.y * 0.5 - m) / maxf(absf(d.y), 0.001))
	var p := center + d * k
	var dir := d.normalized()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var a := dir * 14.0
	var o := dir.orthogonal() * (9.0 + 1.0 * pulse)
	draw_colored_polygon(PackedVector2Array([p + a, p - a * 0.6 + o, p - a * 0.2, p - a * 0.6 - o]), Color(col, 0.75 + 0.25 * pulse))


func _draw_vignette(s: Vector2) -> void:
	var inset := 260.0
	var dark := Color(0, 0, 0, 0.55)
	var clear := Color(0, 0, 0, 0)
	var o := [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]
	var i := [Vector2(inset, inset * 0.6), Vector2(s.x - inset, inset * 0.6), Vector2(s.x - inset, s.y - inset * 0.6), Vector2(inset, s.y - inset * 0.6)]
	for k in 4:
		var n := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([dark, dark, clear, clear]))

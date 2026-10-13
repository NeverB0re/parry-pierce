extends Control
## HUD: 체력 가면, 추진 게이지, 배너, 비네트, 화면 플래시.

const Player := preload("res://scripts/player.gd")
const Sprites := preload("res://scripts/sprites.gd")

var main: Node
var font: SystemFont
var banner_title := ""
var banner_sub := ""
var flash_a := 0.0
var flash_c := Color.WHITE
var warp_t := 0.0                    # 퍼펙트 회피 '시간 정지' 틴트 남은 시간
var warp_max := 0.45


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


func warp(t: float) -> void:
	warp_t = t
	warp_max = t


func step(dt: float) -> void:
	flash_a = maxf(0.0, flash_a - dt * 3.0)
	warp_t = maxf(0.0, warp_t - dt)
	queue_redraw()


var _tl_cache := {}                  # 문자열 조형(셰이핑)은 비싸므로 TextLine 을 재사용한다


func _line(s: String, size: int) -> TextLine:
	var key := "%d|%s" % [size, s]
	var tl: TextLine = _tl_cache.get(key)
	if tl == null:
		if _tl_cache.size() > 48:
			_tl_cache.clear()
		tl = TextLine.new()
		tl.add_string(s, font, size)
		_tl_cache[key] = tl
	return tl


func _text(pos: Vector2, s: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var tl := _line(s, size)
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER and width > 0.0:
		x += (width - tl.get_size().x) * 0.5
	var top := Vector2(x, pos.y - tl.get_line_ascent())
	tl.draw(get_canvas_item(), top + Vector2(2, 2), Color(0, 0, 0, c.a * 0.7))
	tl.draw(get_canvas_item(), top, c)


const UI_SCALE_TOUCH := 1.7           # 작은 폰 화면에서 좌상단 UI가 PC와 비슷한 크기로 보이도록
var ui_k := 1.0                       # 현재 UI 배율 (그리기 좌표는 논리 좌표)


func _draw() -> void:
	var real := get_viewport_rect().size
	_draw_vignette(real)
	ui_k = UI_SCALE_TOUCH if main.touch_ui != null else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ui_k, ui_k))
	var s := real / ui_k
	var pl = main.player
	var boss = main.boss

	# 용암 경고: 낮을수록 화면 아래가 붉게 물든다
	var heat := clampf(1.0 + pl.position.y / 500.0, 0.0, 1.0)
	if heat > 0.0:
		var hc := Color(1.0, 0.25, 0.05, 0.45 * heat)
		var hz := Color(1.0, 0.25, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.45), Vector2(s.x, s.y * 0.45), s, Vector2(0, s.y)]), PackedColorArray([hz, hz, hc, hc]))

	# 목숨: 플레이어와 같은 로켓. 잃은 목숨은 박살난 회색 잔해
	for i in pl.stats.shield_cells:
		_draw_life(Vector2(46 + i * 46, 50), i < main.lives)

	_draw_target_marker(s, boss)
	if not boss.dead and boss.attack_kind() == "beam" and s.x >= 300.0:   # 레이저 중 머리가 화면 밖이면 방향 표시
		_edge_arrow(s, (main.get_viewport().get_canvas_transform() * boss.HEAD_POS) / ui_k, Color(0.85, 0.2, 0.55))

	# 상태 정보
	var left: String = ("외부 시스템 %d" % boss.parts_left()) if boss.phase == 1 else "동력 코어"
	_text(Vector2(28, 100), "%s   %.1fs" % [left, main.run_time], 15, Color(0.75, 0.77, 0.82, 0.7))

	# 배너
	if banner_title != "":
		draw_rect(Rect2(0, s.y * 0.5 - 70, s.x, 140), Color(0, 0, 0, 0.45))
		_text(Vector2(0, s.y * 0.5 + 6), banner_title, 56, Color(1, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		_text(Vector2(0, s.y * 0.5 + 46), banner_sub, 20, Color(0.8, 0.82, 0.86), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	# 패리 성공 후 방향 지정(슬로우)
	if pl.aim_phase:
		var total: float = pl.stats.aim_time_perfect if pl.aim_perfect else pl.stats.aim_time
		var frac := clampf(pl.aim_left / total, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.5, 0.95, 0.14))
		var bw := 320.0
		var bx := (s.x - bw) * 0.5
		draw_rect(Rect2(bx, s.y * 0.7, bw, 8), Color(1, 1, 1, 0.2))
		draw_rect(Rect2(bx, s.y * 0.7, bw * frac, 8), Color(0.8, 0.92, 1.0, 0.95))

	# 조작
	if main.touch_ui == null:
		_text(Vector2(28, s.y - 24), "마우스: 방향(위=활공)   좌클릭: 돌진 / 꾹: 차지 강습 (팔이 멈춰 있거나 휘두를 때 부딪히면 요격)   우클릭·Space 꾹: 패리 → 슬로우 조준 → 리버스 드라이브   R: 재시작   Esc: 메뉴", 15, Color(0.75, 0.77, 0.82, 0.55))

	if warp_t > 0.0:                          # 퍼펙트 회피: 청록 틴트 + 가장자리에서 모여드는 선
		var wk := clampf(warp_t / warp_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.85, 0.75, 0.05 * wk))
		var c := s * 0.5
		for i in 12:
			var a := TAU * i / 12.0 + 0.11
			var d := Vector2.from_angle(a)
			var edge := minf((s.x * 0.5) / maxf(absf(d.x), 0.001), (s.y * 0.5) / maxf(absf(d.y), 0.001))
			var p1 := c + d * edge * (0.98 - 0.35 * (1.0 - wk))
			var p0 := c + d * edge * (1.0 - 0.18 * wk - 0.0)
			draw_line(p0, p1, Color(0.5, 1.0, 0.9, 0.22 * wk), 1.0)

	if flash_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(flash_c, flash_a))


## 다음 표적(부위 또는 심장)이 화면 밖이면 가장자리에 방향 표시
func _draw_target_marker(s: Vector2, boss) -> void:
	if boss.dead or s.x < 300.0 or s.y < 300.0:
		return
	var sp: Vector2 = (main.get_viewport().get_canvas_transform() * boss.target_pos(main.player.position)) / ui_k
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


## 목숨 아이콘: 플레이어 기체 스프라이트. 잃은 목숨은 어둡게 식은 회색 + 금 간 모양
func _draw_life(o: Vector2, alive: bool) -> void:
	var sz := Vector2(46, 46)
	var r := Rect2(o - sz * 0.5, sz)
	var tex := Sprites.ship("b", 0.0)
	if alive:
		draw_texture_rect(tex, r, false)
		return
	draw_texture_rect(tex, r, false, Color(0.28, 0.29, 0.33, 0.8))
	var ed := Color(0.05, 0.05, 0.07, 0.9)
	draw_line(o + Vector2(-6, -18), o + Vector2(2, -4), ed, 2.0)
	draw_line(o + Vector2(2, -4), o + Vector2(-4, 4), ed, 2.0)
	draw_line(o + Vector2(-4, 4), o + Vector2(6, 16), ed, 2.0)
	draw_line(o + Vector2(2, -4), o + Vector2(12, 0), ed, 2.0)


func _draw_vignette(s: Vector2) -> void:
	var inset := 260.0
	var dark := Color(0, 0, 0, 0.55)
	var clear := Color(0, 0, 0, 0)
	var o := [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]
	var i := [Vector2(inset, inset * 0.6), Vector2(s.x - inset, inset * 0.6), Vector2(s.x - inset, s.y - inset * 0.6), Vector2(inset, s.y - inset * 0.6)]
	for k in 4:
		var n := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[n], i[n], i[k]]), PackedColorArray([dark, dark, clear, clear]))

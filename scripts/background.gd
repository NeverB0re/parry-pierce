extends Node2D
## 실크송풍 원경: 화면 좌표에서 직접 그린다. 카메라 중심(cam)에 패럴랙스 계수를 곱해 이동.

var cam := Vector2.ZERO
var t := 0.0
var spires: Array[Vector3] = []     # x, 폭, 높이
var chains: Array[Vector2] = []     # x, 길이
var arches: Array[Vector2] = []     # x, 폭
var motes: Array[Vector3] = []      # x, y, 속도


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var x := -2200.0
	while x < 2200.0:
		spires.append(Vector3(x, rng.randf_range(60, 160), rng.randf_range(500, 1500)))
		x += rng.randf_range(90, 260)
	for i in 18:
		chains.append(Vector2(rng.randf_range(-1800, 1800), rng.randf_range(300, 1100)))
	x = -2400.0
	while x < 2400.0:
		arches.append(Vector2(x, rng.randf_range(260, 420)))
		x += rng.randf_range(500, 800)
	for i in 70:
		motes.append(Vector3(rng.randf_range(0, 1), rng.randf_range(0, 1), rng.randf_range(0.2, 1.0)))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _layer(p: Vector2, f: float, s: Vector2) -> Vector2:
	return p - cam * f + s * 0.5


func _draw() -> void:
	var s := get_viewport_rect().size
	# 하늘 그라데이션 (위로 갈수록 약간 밝은 푸른 안개)
	var hk := clampf(-cam.y / 2800.0, 0.0, 1.0)
	var top := Color(0.17, 0.21, 0.27).lerp(Color(0.24, 0.29, 0.35), hk)
	var bot := Color(0.08, 0.10, 0.13).lerp(Color(0.14, 0.17, 0.22), hk)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bot, bot]))

	# 빛줄기
	for i in 5:
		var bx := fmod(i * 410.0 - cam.x * 0.05 + 4000.0, s.x + 600.0) - 300.0
		var w := 60.0 + 40.0 * sin(i * 1.7)
		var a := 0.035 + 0.02 * sin(t * 0.4 + i)
		draw_polygon(PackedVector2Array([Vector2(bx, 0), Vector2(bx + w, 0), Vector2(bx + w + 380, s.y), Vector2(bx + 380, s.y)]),
			PackedColorArray([Color(0.8, 0.85, 0.9, a), Color(0.8, 0.85, 0.9, a), Color(0.8, 0.85, 0.9, 0), Color(0.8, 0.85, 0.9, 0)]))

	# 먼 첨탑 (패럴랙스 0.15)
	var far_c := Color(0.2, 0.24, 0.3)
	for sp in spires:
		var base := _layer(Vector2(sp.x, 350), 0.15, s)
		if base.x < -200 or base.x > s.x + 200:
			continue
		var w := sp.y * 0.5
		var h := sp.z * 0.6
		var pts := PackedVector2Array([
			base + Vector2(-w, 400), base + Vector2(-w, -h), base + Vector2(-w * 0.4, -h - 40),
			base + Vector2(0, -h - 110 - w), base + Vector2(w * 0.4, -h - 40), base + Vector2(w, -h), base + Vector2(w, 400)])
		draw_colored_polygon(pts, far_c)
		for j in 3:
			var wy := base.y - h * (0.3 + j * 0.2)
			draw_rect(Rect2(base.x - 3, wy, 6, 16), Color(0.55, 0.6, 0.62, 0.12))

	# 중간 아치/기둥 (0.35)
	var mid_c := Color(0.13, 0.16, 0.2)
	for ar in arches:
		var base := _layer(Vector2(ar.x, 500), 0.35, s)
		if base.x < -600 or base.x > s.x + 600:
			continue
		var w := ar.y
		draw_rect(Rect2(base.x - w * 0.5, base.y - 1400, 70, 1900), mid_c)
		draw_rect(Rect2(base.x + w * 0.5 - 70, base.y - 1400, 70, 1900), mid_c)
		var arc := PackedVector2Array()
		for j in 17:
			var a := PI + PI * j / 16.0
			arc.append(Vector2(base.x + cos(a) * w * 0.5, base.y - 1400 + sin(a) * w * 0.45))
		arc.append(Vector2(base.x + w * 0.5, base.y - 1400 - w * 0.6))
		arc.append(Vector2(base.x - w * 0.5, base.y - 1400 - w * 0.6))
		draw_colored_polygon(arc, mid_c)

	# 매달린 사슬 (0.5)
	for ch in chains:
		var top_p := _layer(Vector2(ch.x, -1900), 0.5, s)
		if top_p.x < -50 or top_p.x > s.x + 50:
			continue
		var sw := sin(t * 0.6 + ch.x) * 8.0
		var end_p := top_p + Vector2(sw, ch.y)
		draw_line(top_p, end_p, Color(0.1, 0.12, 0.15), 3.0)
		draw_circle(end_p, 10.0, Color(0.1, 0.12, 0.15))

	# 떠다니는 먼지 (0.7, 화면 순환)
	for m in motes:
		var px := fposmod(m.x * (s.x + 100) - cam.x * 0.7 * m.z + sin(t * 0.5 + m.y * 9.0) * 20.0, s.x + 100) - 50
		var py := fposmod(m.y * (s.y + 100) - cam.y * 0.7 * m.z - t * 14.0 * m.z, s.y + 100) - 50
		draw_circle(Vector2(px, py), 1.0 + m.z * 1.6, Color(0.85, 0.9, 0.95, 0.12 + 0.25 * m.z))

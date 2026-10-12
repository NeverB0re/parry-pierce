extends Node2D
## 실크송풍 원경. 패럴랙스 층마다 한 번만 그려 두고, 매 프레임에는 위치만 옮긴다 (모바일 성능).
## 카메라 중심(cam)에 패럴랙스 계수를 곱해 이동. 떠다니는 먼지만 매 프레임 그린다.

var cam := Vector2.ZERO
var t := 0.0
var spires: Array[Vector3] = []     # x, 폭, 높이
var chains: Array[Vector2] = []     # x, 길이
var arches: Array[Vector2] = []     # x, 폭
var motes: Array[Vector3] = []      # x, y, 속도

var sky_low: Node2D
var sky_high: Node2D
var far: Node2D                     # 첨탑 (0.15)
var mid: Node2D                     # 아치 (0.35)
var near: Node2D                    # 사슬 (0.5)
var dust: Node2D                    # 먼지 (0.7, 매 프레임)


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
	for i in 36:
		motes.append(Vector3(rng.randf_range(0, 1), rng.randf_range(0, 1), rng.randf_range(0.2, 1.0)))

	sky_low = _layer_node()
	sky_high = _layer_node()
	far = _layer_node()
	mid = _layer_node()
	near = _layer_node()
	dust = _layer_node()
	sky_low.draw.connect(_draw_sky.bind(sky_low, false))
	sky_high.draw.connect(_draw_sky.bind(sky_high, true))
	far.draw.connect(_draw_far.bind(far))
	mid.draw.connect(_draw_mid.bind(mid))
	near.draw.connect(_draw_near.bind(near))
	dust.draw.connect(_draw_dust.bind(dust))
	get_viewport().size_changed.connect(_on_resized)


func _layer_node() -> Node2D:
	var n := Node2D.new()
	add_child(n)
	return n


func _on_resized() -> void:
	sky_low.queue_redraw()
	sky_high.queue_redraw()


func _process(delta: float) -> void:
	t += delta
	var s := get_viewport_rect().size
	sky_high.modulate.a = clampf(-cam.y / 2800.0, 0.0, 1.0)   # 높이 올라갈수록 밝은 푸른 안개
	far.position = -cam * 0.15 + s * 0.5
	mid.position = -cam * 0.35 + s * 0.5
	near.position = -cam * 0.5 + s * 0.5
	dust.queue_redraw()


## 하늘 그라데이션(낮은 팔레트 위에 높은 팔레트를 알파로 겹침) + 빛줄기
func _draw_sky(n: Node2D, high: bool) -> void:
	var s := get_viewport_rect().size
	var top := Color(0.24, 0.29, 0.35) if high else Color(0.17, 0.21, 0.27)
	var bot := Color(0.14, 0.17, 0.22) if high else Color(0.08, 0.10, 0.13)
	n.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bot, bot]))
	if high:
		return
	for i in 5:
		var bx := fmod(i * 410.0 + 4000.0, s.x + 600.0) - 300.0
		var w := 60.0 + 40.0 * sin(i * 1.7)
		var a := 0.04
		n.draw_polygon(PackedVector2Array([Vector2(bx, 0), Vector2(bx + w, 0), Vector2(bx + w + 380, s.y), Vector2(bx + 380, s.y)]),
			PackedColorArray([Color(0.8, 0.85, 0.9, a), Color(0.8, 0.85, 0.9, a), Color(0.8, 0.85, 0.9, 0), Color(0.8, 0.85, 0.9, 0)]))


func _draw_far(n: Node2D) -> void:
	var far_c := Color(0.2, 0.24, 0.3)
	for sp in spires:
		var base := Vector2(sp.x, 350)
		var w := sp.y * 0.5
		var h := sp.z * 0.6
		var pts := PackedVector2Array([
			base + Vector2(-w, 400), base + Vector2(-w, -h), base + Vector2(-w * 0.4, -h - 40),
			base + Vector2(0, -h - 110 - w), base + Vector2(w * 0.4, -h - 40), base + Vector2(w, -h), base + Vector2(w, 400)])
		n.draw_colored_polygon(pts, far_c)
		for j in 3:
			var wy := base.y - h * (0.3 + j * 0.2)
			n.draw_rect(Rect2(base.x - 3, wy, 6, 16), Color(0.55, 0.6, 0.62, 0.12))


func _draw_mid(n: Node2D) -> void:
	var mid_c := Color(0.13, 0.16, 0.2)
	for ar in arches:
		var base := Vector2(ar.x, 500)
		var w := ar.y
		n.draw_rect(Rect2(base.x - w * 0.5, base.y - 1400, 70, 1900), mid_c)
		n.draw_rect(Rect2(base.x + w * 0.5 - 70, base.y - 1400, 70, 1900), mid_c)
		var arc := PackedVector2Array()
		for j in 17:
			var a := PI + PI * j / 16.0
			arc.append(Vector2(base.x + cos(a) * w * 0.5, base.y - 1400 + sin(a) * w * 0.45))
		arc.append(Vector2(base.x + w * 0.5, base.y - 1400 - w * 0.6))
		arc.append(Vector2(base.x - w * 0.5, base.y - 1400 - w * 0.6))
		n.draw_colored_polygon(arc, mid_c)


func _draw_near(n: Node2D) -> void:
	for ch in chains:
		var top_p := Vector2(ch.x, -1900)
		var end_p := top_p + Vector2(0, ch.y)
		n.draw_line(top_p, end_p, Color(0.1, 0.12, 0.15), 3.0)
		n.draw_circle(end_p, 10.0, Color(0.1, 0.12, 0.15))


## 떠다니는 먼지 (화면 순환): 작은 사각형으로 그려 호출 비용을 줄인다
func _draw_dust(n: Node2D) -> void:
	var s := get_viewport_rect().size
	for m in motes:
		var px := fposmod(m.x * (s.x + 100) - cam.x * 0.7 * m.z + sin(t * 0.5 + m.y * 9.0) * 20.0, s.x + 100) - 50
		var py := fposmod(m.y * (s.y + 100) - cam.y * 0.7 * m.z - t * 14.0 * m.z, s.y + 100) - 50
		var d := 2.0 + m.z * 2.6
		n.draw_rect(Rect2(px - d * 0.5, py - d * 0.5, d, d), Color(0.85, 0.9, 0.95, 0.12 + 0.25 * m.z))

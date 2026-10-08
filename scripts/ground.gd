extends Node2D
## 바닥/벽(뒤) 또는 앞쪽 풀 실루엣(front = true). 월드 좌표.

var front := false
var t := 0.0
var blades: Array[Vector3] = []   # x, 높이, 위상


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -1300.0
	while x < 1600.0:
		blades.append(Vector3(x, rng.randf_range(18, 70), rng.randf() * TAU))
		x += rng.randf_range(6, 26)
	if front:
		z_index = 5


func _process(delta: float) -> void:
	if front:
		t += delta
		queue_redraw()


func _draw() -> void:
	if front:
		for b in blades:
			var sway := sin(t * 1.3 + b.z) * 6.0
			var pts := PackedVector2Array([Vector2(b.x - 4, 2), Vector2(b.x + sway, -b.y), Vector2(b.x + 4, 2)])
			draw_colored_polygon(pts, Color(0.02, 0.02, 0.03))
		return
	# 안개 띠
	var fog := PackedVector2Array([Vector2(-1400, -320), Vector2(1700, -320), Vector2(1700, 0), Vector2(-1400, 0)])
	var fc := PackedColorArray([Color(0.6, 0.7, 0.8, 0.0), Color(0.6, 0.7, 0.8, 0.0), Color(0.6, 0.7, 0.8, 0.10), Color(0.6, 0.7, 0.8, 0.10)])
	draw_polygon(fog, fc)
	# 바닥
	draw_rect(Rect2(-1400, 0, 3100, 900), Color(0.045, 0.05, 0.065))
	draw_line(Vector2(-1400, 1), Vector2(1700, 1), Color(0.32, 0.34, 0.38), 3.0)
	for i in 40:
		var x := -1300.0 + i * 75.0
		draw_line(Vector2(x, 14), Vector2(x + 40, 14 + (i % 3) * 6), Color(0.1, 0.11, 0.13), 3.0)
	# 양쪽 벽(폐허 기둥)
	for side in [-1.0, 1.0]:
		var edge := -1150.0 if side < 0 else 1150.0
		var r := Rect2(edge - 500, -4000, 500, 4000) if side < 0 else Rect2(edge, -4000, 500, 4000)
		draw_rect(r, Color(0.035, 0.04, 0.05))
		draw_line(Vector2(edge, -4000), Vector2(edge, 0), Color(0.2, 0.22, 0.26), 3.0)
		var y := -200.0
		while y > -4000.0:
			draw_line(Vector2(edge, y), Vector2(edge - side * 40.0, y), Color(0.12, 0.13, 0.16), 4.0)
			y -= 260.0

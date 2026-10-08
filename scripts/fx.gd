extends Node2D
## 불꽃/파편/충격파 링. 월드 좌표.

var parts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rays: Array[Dictionary] = []


func clear() -> void:
	parts.clear()
	rings.clear()
	rays.clear()


## 중심에서 사방으로 뻗는 빛줄기
func rays_burst(pos: Vector2, n: int, color: Color, length: float, life := 0.4, width := 6.0) -> void:
	var off := randf() * TAU
	for i in n:
		var a := off + TAU * i / n + randf_range(-0.12, 0.12)
		rays.append({"pos": pos, "dir": Vector2.from_angle(a), "len": length * randf_range(0.7, 1.2), "life": life, "max": life, "color": color, "width": width})


func burst(pos: Vector2, n: int, color: Color, speed: float, life := 0.45, size := 3.0, grav := 0.0, dir := Vector2.ZERO, spread := PI) -> void:
	for i in n:
		var a := randf_range(-spread, spread) + (dir.angle() if dir != Vector2.ZERO else 0.0)
		var v := Vector2.from_angle(a) * speed * randf_range(0.35, 1.0)
		var l := life * randf_range(0.6, 1.0)
		parts.append({"pos": pos, "vel": v, "life": l, "max": l, "color": color, "size": size * randf_range(0.6, 1.2), "grav": grav})


func ring(pos: Vector2, color: Color, max_r: float, life := 0.35, width := 4.0) -> void:
	rings.append({"pos": pos, "color": color, "max_r": max_r, "life": life, "max": life, "width": width})


func step(dt: float) -> void:
	for p in parts.duplicate():
		p["life"] = float(p["life"]) - dt
		if p["life"] <= 0.0:
			parts.erase(p)
			continue
		var v: Vector2 = p["vel"]
		v.y += float(p["grav"]) * dt
		v *= 1.0 - 2.5 * dt
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * dt
	for r in rings.duplicate():
		r["life"] = float(r["life"]) - dt
		if r["life"] <= 0.0:
			rings.erase(r)
	for r in rays.duplicate():
		r["life"] = float(r["life"]) - dt
		if r["life"] <= 0.0:
			rays.erase(r)
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var k := float(p["life"]) / float(p["max"])
		var c: Color = p["color"]
		c.a *= k
		var pos: Vector2 = p["pos"]
		var v: Vector2 = p["vel"]
		draw_line(pos, pos - v * 0.035, c, float(p["size"]) * (0.5 + 0.5 * k))
	for r in rays:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var d: Vector2 = r["dir"]
		var p0: Vector2 = r["pos"]
		var l := float(r["len"])
		var rc: Color = r["color"]
		rc.a *= 1.0 - k
		draw_line(p0 + d * l * (0.1 + 0.5 * k), p0 + d * l * (0.3 + 0.7 * k), rc, float(r["width"]) * (1.0 - k) + 1.0)
	for r in rings:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var c: Color = r["color"]
		c.a *= 1.0 - k
		draw_arc(r["pos"], float(r["max_r"]) * ease(k, 0.35), 0.0, TAU, 48, c, float(r["width"]) * (1.0 - k) + 1.0)

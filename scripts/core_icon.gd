extends RefCounted
## 동력 코어 아이콘: 관측자 심장의 하트 컷 보석(observer.gd HEART_SHAPE)을 작게. 코어마다 색만 다르다 (upgrades.gd color).
## 강철 테 → 어두운 바깥 면(빛 받는 모서리) → 빛나는 안쪽 심 → 면 분할선 → 하이라이트.

const Observer := preload("res://scripts/colossi/observer.gd")


## ci 위 c 에 크기 s(반지름 정도)로 그린다. lit = false 면 꺼진 회색 실루엣 (아직 얻지 못함)
static func draw(ci: CanvasItem, c: Vector2, s: float, col: Color, lit := true, pulse := 0.0) -> void:
	if not lit:
		col = Color(0.32, 0.34, 0.4)
	var bezel := _shape(c, s * 1.2)
	ci.draw_colored_polygon(bezel, Color(0.1, 0.11, 0.14))
	ci.draw_polyline(_closed(bezel), Color(0.55, 0.6, 0.7) if lit else Color(0.3, 0.32, 0.38), maxf(1.0, s * 0.08))
	var o := _shape(c, s)
	var inner := _shape(c, s * Observer.HEART_IN)
	var n := o.size()
	for k in n:                                        # 바깥 면
		var fc := PackedVector2Array([o[k], o[(k + 1) % n], inner[(k + 1) % n], inner[k]])
		var shade := 0.5 + 0.5 * cos(float(k) * 1.3)
		ci.draw_colored_polygon(fc, col.darkened(0.72 - 0.25 * shade))
		ci.draw_line(o[k], o[(k + 1) % n], Color(col.lightened(0.5), 0.5 if lit else 0.2), 1.0)
	ci.draw_colored_polygon(inner, col.darkened(0.15 - 0.15 * pulse) if lit else col.darkened(0.3))
	if lit:
		var top := c + Vector2(0, -s * 0.12)
		for q in inner:                                # 면 분할선
			ci.draw_line(top, q, Color(1, 1, 1, 0.25 + 0.2 * pulse), 1.0)
		ci.draw_colored_polygon(_shape(c + Vector2(0, -s * 0.12), s * 0.22), Color(1, 1, 1, 0.7 + 0.3 * pulse))


static func _shape(c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in Observer.HEART_SHAPE:
		out.append(c + q * k)
	return out


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q

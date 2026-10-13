extends RefCounted
## 무적 실드: 푸른 벌집(육각 격자) 방어막. 무적 상태는 모두 이 실드 하나로 보여 준다 (돌진·피격 후·적중 후 튕김 등).
## 평평한 육각 격자를 구에 감싼 모양으로 눌러(가장자리일수록 촘촘) 둥근 막처럼 보이게 하고,
## 가장자리일수록 밝게(프레넬) 그린다. 격자 선분은 처음 한 번만 만들고, 색만 매 프레임 바꾼다.

const C := Color(0.4, 0.8, 1.0)
const C_RIM := Color(0.75, 0.95, 1.0)
const CELL := 9.0                    # 육각 칸 크기 (펼친 격자 기준, 반지름 1 = 46px 기준으로 맞춤)

static var _segs := PackedVector2Array()   # 반지름 1 기준 선분 끝점 (2개씩)
static var _rad := PackedFloat32Array()    # 선분 중점의 중심 거리 (0~1)


static func _build() -> void:
	var R := 46.0
	var reach := R * PI * 0.5            # 구 표면에서 정면 → 가장자리까지의 호 길이
	var w := CELL * sqrt(3.0)
	var seen := {}
	var n := int(reach / CELL) + 2
	for q in range(-n, n + 1):
		for r in range(-n, n + 1):
			var cx := w * (q + r * 0.5)
			var cy := CELL * 1.5 * r
			if Vector2(cx, cy).length() > reach + CELL:
				continue
			for k in 6:
				var a0 := PI / 6.0 + k * PI / 3.0
				var a1 := a0 + PI / 3.0
				var p0 := Vector2(cx, cy) + Vector2.from_angle(a0) * CELL
				var p1 := Vector2(cx, cy) + Vector2.from_angle(a1) * CELL
				if p0.length() > reach or p1.length() > reach:
					continue
				var key := "%d,%d|%d,%d" % [roundi(minf(p0.x, p1.x) * 10), roundi(minf(p0.y, p1.y) * 10), roundi(maxf(p0.x, p1.x) * 10), roundi(maxf(p0.y, p1.y) * 10)]
				if seen.has(key):
					continue
				seen[key] = true
				var m0 := _wrap(p0, R)
				var m1 := _wrap(p1, R)
				_segs.append(m0)
				_segs.append(m1)
				_rad.append(((m0 + m1) * 0.5).length())


## 펼친 격자 위의 점 → 구에 감싼 뒤 정면에서 본 위치 (반지름 1 기준)
static func _wrap(p: Vector2, R: float) -> Vector2:
	var s := p.length()
	if s < 0.001:
		return Vector2.ZERO
	return p / s * sin(s / R)


## ci 에 center 중심, 반지름 r 의 실드를 그린다. a = 진하기(0~1), now = 시간(초, 반짝임 물결)
static func draw(ci: CanvasItem, center: Vector2, r: float, a: float, now: float) -> void:
	if _segs.is_empty():
		_build()
	ci.draw_circle(center, r, Color(C, 0.08 * a))
	var pts := PackedVector2Array()
	pts.resize(_segs.size())
	var cols := PackedColorArray()
	cols.resize(_rad.size())
	for i in _segs.size():
		pts[i] = center + _segs[i] * r
	for i in _rad.size():
		var d: float = _rad[i]
		var wave := 0.5 + 0.5 * sin(now * 7.0 - d * 9.0)    # 가운데서 바깥으로 번지는 반짝임
		cols[i] = Color(C, a * (0.12 + 0.55 * d * d + 0.25 * wave * d))
	ci.draw_multiline_colors(pts, cols, 1.5)
	ci.draw_arc(center, r, 0.0, TAU, 40, Color(C_RIM, 0.75 * a), 2.5)
	ci.draw_arc(center, r + 3.0, 0.0, TAU, 40, Color(C, 0.25 * a), 4.0)

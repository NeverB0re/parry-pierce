extends RefCounted
## 근접공격 예고 표시. 모든 근접공격(팔 휘두르기·프레스 …)이 같은 모양을 쓴다:
##   진홍색 빗금 위험구간 + 점멸하는 테두리 + ⚠ 표지. 글자는 쓰지 않는다 (설명은 튜토리얼). 화면 위 ⚠ 는 hud.gd 가 boss.melee_warning() 으로 따로 그린다.
## 색 규칙: 금 = 패리 가능, 검붉은 보라 = 패리 불가, 진홍 빗금 = 근접(돌진 무적으로 못 피함).
## 단계(level): 0 준비 중(윤곽만) → 1 위치 고정(빗금, 일정) → 2 곧 닿음(빗금·테두리가 빠르게 점멸)

const C := Color(1.0, 0.16, 0.12)         # 근접 = 진홍
const C_HOT := Color(1.0, 0.82, 0.7)      # 테두리 안쪽 밝은 선

## 위험구간 poly (월드 좌표) 를 ci 에 그린다. 반드시 ci 의 _draw 안에서 부른다
static func zone(ci: CanvasItem, poly: PackedVector2Array, level: int, now: float) -> void:
	if poly.size() < 3:
		return
	var blink := 0.5 + 0.5 * sin(now * 26.0)
	var outline := poly.duplicate()
	outline.append(poly[0])
	match level:
		0:
			ci.draw_polyline(outline, Color(C, 0.45), 3.0)
		1:
			ci.draw_colored_polygon(poly, Color(C, 0.05))
			_hatch(ci, poly, Color(C, 0.17), now, 0.0)
			ci.draw_polyline(outline, Color(C_HOT, 0.6), 3.0)
		_:
			ci.draw_colored_polygon(poly, Color(C, 0.08 + 0.12 * blink))
			_hatch(ci, poly, Color(C, 0.2 + 0.25 * blink), now, 1.0)
			ci.draw_polyline(outline, Color(1.0, 0.5, 0.4, 0.4 + 0.3 * blink), 5.0)
			ci.draw_polyline(outline, Color(C_HOT, 0.5 + 0.3 * blink), 2.5)


## ⚠ 표지 (pos = 삼각형 중심). 글자 없음. order >= 0 (연타 순번)이면 아래에 점을 order + 1 개 찍는다
static func tag(ci: CanvasItem, pos: Vector2, level: int, now: float, order := -1) -> void:
	var a := 1.0 if level < 2 else 0.55 + 0.45 * sin(now * 24.0)
	var s := 44.0 if level >= 1 else 30.0
	var tri := PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(-s * 0.95, s * 0.62), pos + Vector2(s * 0.95, s * 0.62)])
	ci.draw_colored_polygon(tri, Color(C, 0.7 * a))
	var ol := tri.duplicate()
	ol.append(tri[0])
	ci.draw_polyline(ol, Color(1, 1, 1, 0.75 * a), 3.0)
	ci.draw_rect(Rect2(pos.x - 4.0, pos.y - s * 0.42, 8.0, s * 0.62), Color(1, 1, 1, a))
	ci.draw_circle(pos + Vector2(0, s * 0.4), 5.0, Color(1, 1, 1, a))
	for k in order + 1:
		var q := pos + Vector2((k - order * 0.5) * 26.0, s * 0.62 + 24.0)
		ci.draw_circle(q, 10.0, Color(C, 0.8 * a))
		ci.draw_circle(q, 6.0, Color(1, 1, 1, a))


## 휘두르는 방향: 흐릿한 점선이 시작점(속이 빈 작은 원)에서 끝까지 TRACE_TIME 동안 한 번 그어진다 (prog = 0~1).
## 다 그어지면 끝에 작은 꺾쇠. 화면 밖으로 일부가 잘려도 시작점과 그어지는 방향으로 읽힌다
const TRACE_TIME := 0.6
const C_TRACE := Color(1.0, 0.93, 0.82)

static func arc_trace(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, prog: float) -> void:
	var n := 28
	var pr := clampf(prog, 0.0, 1.0)
	var at := func(f: float) -> Vector2: return center + Vector2.from_angle(lerpf(a0, a1, f)) * r
	for q in n:
		var f0 := q / float(n)
		if f0 >= pr:
			break
		if q % 2 == 0:
			ci.draw_line(at.call(f0), at.call(minf((q + 1) / float(n), pr)), Color(C_TRACE, 0.4), 4.0)
	ci.draw_arc(at.call(0.0), 10.0, 0.0, TAU, 14, Color(C_TRACE, 0.55), 2.5)
	if pr < 1.0:
		ci.draw_circle(at.call(pr), 6.0, Color(C_TRACE, 0.85))
	else:
		var e: Vector2 = at.call(1.0)
		var d: Vector2 = (e - at.call(0.96)).normalized()
		var sd := d.orthogonal()
		ci.draw_polyline(PackedVector2Array([e - d * 22.0 + sd * 14.0, e, e - d * 22.0 - sd * 14.0]), Color(C_TRACE, 0.5), 3.5)


## 공격하는 촉수·팔 강조: 척추를 따라 진홍 테두리 (어느 몸통이 치는지 보인다)
static func limb(ci: CanvasItem, spine: PackedVector2Array, level: int, now: float) -> void:
	var blink := 1.0 if level < 2 else 0.6 + 0.4 * sin(now * 24.0)
	ci.draw_polyline(spine, Color(C, 0.55 * blink), 14.0)
	ci.draw_polyline(spine, Color(C_HOT, 0.5 * blink), 3.0)


## 위험 줄무늬: 45도 빗금이 다각형 안쪽만 천천히 흘러간다 (speed: 0 보통, 1 빠르게)
static func _hatch(ci: CanvasItem, poly: PackedVector2Array, color: Color, now: float, speed: float) -> void:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var h := hi.y - lo.y
	var step := 44.0
	var x := lo.x - h - fposmod(now * 36.0 * (1.0 + speed), step)
	while x < hi.x:
		var seg := PackedVector2Array([Vector2(x, hi.y), Vector2(x + h, lo.y)])
		for part in Geometry2D.intersect_polyline_with_polygon(seg, poly):
			ci.draw_polyline(part, color, 7.0)
		x += step

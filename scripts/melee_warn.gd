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


## 휘두르는 방향 화살표: center 를 축으로 반지름 r 의 호를 a0 → a1 로 따라가는 굵은 화살 (끝에 화살촉).
## 빛이 a0 에서 a1 쪽으로 흘러 방향이 한눈에 보인다
static func arc_arrow(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, level: int, now: float) -> void:
	var n := 20
	var pts := PackedVector2Array()
	for q in n + 1:
		pts.append(center + Vector2.from_angle(lerpf(a0, a1, q / float(n))) * r)
	var a := 0.55 if level == 0 else 0.9
	ci.draw_polyline(pts, Color(0.05, 0.02, 0.02, 0.5 * a), 22.0)
	ci.draw_polyline(pts, Color(C, 0.75 * a), 13.0)
	var flow := fposmod(now * 1.6, 1.0)                     # 흐르는 빛
	for k in 3:
		var f := fposmod(flow + k / 3.0, 1.0)
		var p := center + Vector2.from_angle(lerpf(a0, a1, f)) * r
		ci.draw_circle(p, 9.0, Color(C_HOT, a * (1.0 - f * 0.5)))
	var tip := pts[n]
	var dir := (pts[n] - pts[n - 1]).normalized()
	var side := dir.orthogonal()
	var head := PackedVector2Array([tip + dir * 62.0, tip + side * 40.0, tip - side * 40.0])
	ci.draw_colored_polygon(head, Color(C, 0.9 * a))
	var ol := head.duplicate()
	ol.append(head[0])
	ci.draw_polyline(ol, Color(1, 1, 1, 0.8 * a), 3.0)


## 공격하는 촉수·팔 강조: 척추를 따라 진홍 테두리 (어느 몸통이 치는지 보인다)
static func limb(ci: CanvasItem, spine: PackedVector2Array, level: int, now: float) -> void:
	var blink := 1.0 if level < 2 else 0.6 + 0.4 * sin(now * 24.0)
	ci.draw_polyline(spine, Color(C, 0.55 * blink), 14.0)
	ci.draw_polyline(spine, Color(C_HOT, 0.5 * blink), 3.0)


# ── 잔상식 예고 (크라켄 촉수에 시험 적용): 면을 칠하지 않고, 몸이 끝날 자세의 잔상 + 얇은 궤적 + 몸이 달아오르는 색으로만.
#    밝은 것 = 다음에 칠 공격, 회색 = 기다리는 공격. 점멸 없음. k = 0~1 (타격이 다가올수록 진해진다)
const C_GHOST_NEXT := Color(1.0, 0.72, 0.45)
const C_GHOST_WAIT := Color(0.62, 0.64, 0.7)
const C_HEAT := Color(1.0, 0.45, 0.15)


## 예고 단계(0 준비, 1 고정, 2 곧) → 진하기
static func level_k(level: int) -> float:
	return [0.3, 0.65, 1.0][clampi(level, 0, 2)]


## 잔상: 몸이 공격을 마칠 자세를 반투명 실루엣으로 (width = 몸 굵기)
static func ghost(ci: CanvasItem, spine: PackedVector2Array, width: float, next: bool, k: float) -> void:
	if spine.size() < 2:
		return
	var c := C_GHOST_NEXT if next else C_GHOST_WAIT
	var a := (0.1 + 0.2 * k) if next else 0.1
	ci.draw_polyline(spine, Color(c, a), width)
	ci.draw_polyline(spine, Color(c, a * 2.2), 2.5)
	ci.draw_circle(spine[spine.size() - 1], width * 0.5, Color(c, a))


## 궤적(직선): 얇은 점선 + 작은 화살촉 (다음 공격만)
static func trail_line(ci: CanvasItem, from: Vector2, to: Vector2, k: float) -> void:
	var d := to - from
	var n := maxi(2, int(d.length() / 36.0))
	for q in n:
		if q % 2 == 0:
			ci.draw_line(from + d * (q / float(n)), from + d * ((q + 1) / float(n)), Color(C_GHOST_NEXT, 0.25 + 0.35 * k), 3.0)
	_head(ci, to, d.normalized(), k)


## 궤적(호): center 를 축으로 반지름 r, a0 → a1 (다음 공격만)
static func trail_arc(ci: CanvasItem, center: Vector2, r: float, a0: float, a1: float, k: float) -> void:
	var n := 24
	for q in n:
		if q % 2 == 0:
			ci.draw_line(center + Vector2.from_angle(lerpf(a0, a1, q / float(n))) * r, center + Vector2.from_angle(lerpf(a0, a1, (q + 1) / float(n))) * r, Color(C_GHOST_NEXT, 0.25 + 0.35 * k), 3.0)
	var e := center + Vector2.from_angle(a1) * r
	var before := center + Vector2.from_angle(lerpf(a0, a1, 0.97)) * r
	_head(ci, e, (e - before).normalized(), k)


static func _head(ci: CanvasItem, tip: Vector2, dir: Vector2, k: float) -> void:
	var side := dir.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip + dir * 30.0, tip + side * 17.0, tip - side * 17.0]), Color(C_GHOST_NEXT, 0.35 + 0.45 * k))


## 다음에 칠 몸이 달아오른다: 주황 → 흰빛 (점멸 없음). 판정이 있는 마디(from~)만
static func heat(ci: CanvasItem, spine: PackedVector2Array, from: int, k: float) -> void:
	if spine.size() - from < 2:
		return
	var pts := spine.slice(from)
	ci.draw_polyline(pts, Color(C_HEAT, 0.25 + 0.3 * k), 16.0)
	ci.draw_polyline(pts, Color(C_HEAT.lerp(Color.WHITE, k), 0.45 + 0.4 * k), 4.0)


## 연타 순번 점 (order + 1 개). 다음 공격이면 밝게
static func pips(ci: CanvasItem, pos: Vector2, order: int, next: bool) -> void:
	for q in order + 1:
		var p := pos + Vector2((q - order * 0.5) * 26.0, 0)
		ci.draw_circle(p, 10.0, Color(0.05, 0.05, 0.06, 0.7))
		ci.draw_circle(p, 6.0, C_GHOST_NEXT if next else C_GHOST_WAIT)


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

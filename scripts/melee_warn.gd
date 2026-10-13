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


## ⚠ 표지 (pos = 삼각형 중심). 글자 없음
static func tag(ci: CanvasItem, pos: Vector2, level: int, now: float) -> void:
	var a := 1.0 if level < 2 else 0.55 + 0.45 * sin(now * 24.0)
	var s := 44.0 if level >= 1 else 30.0
	var tri := PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(-s * 0.95, s * 0.62), pos + Vector2(s * 0.95, s * 0.62)])
	ci.draw_colored_polygon(tri, Color(C, 0.7 * a))
	var ol := tri.duplicate()
	ol.append(tri[0])
	ci.draw_polyline(ol, Color(1, 1, 1, 0.75 * a), 3.0)
	ci.draw_rect(Rect2(pos.x - 4.0, pos.y - s * 0.42, 8.0, s * 0.62), Color(1, 1, 1, a))
	ci.draw_circle(pos + Vector2(0, s * 0.4), 5.0, Color(1, 1, 1, a))


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

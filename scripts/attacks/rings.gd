extends "res://scripts/attacks/attack.gd"
## 동심원 파동 (패리 불가 = 검붉은 보라): 심장부(반응로)에서 보라색 고리가 COUNT 개 차례로 퍼져 나간다 (지금은 한 줄기).
## 돌진 무적으로 통과한다. 돌진 직후 스치면 강한 퍼펙트 회피(완전 동조).
## 고리를 다 내보내면 다음 공격에 자리를 내주고(boss.detach_attack) 고리는 경기장을 다 덮을 때까지 퍼진다.
## boss 에 필요한 것: set_glow(-4, v) (반응로 발광)

const WIND := 1.2
const COUNT := 1
const GAP := 0.85                    # 고리 사이 간격 (초)
const SPEED := 430.0
const HALF := 20.0                   # 판정 반폭
const MAX_R := 3400.0                # 경기장을 다 덮으면 끝
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var dodged_rings: Array[int] = []      # 퍼펙트 회피로 빨아들인 고리 번호 (사라진다)
var origin := Vector2.ZERO
var started := 0
var count := COUNT
var wind := WIND


func _init(o: Vector2) -> void:
	kind = "rings"
	origin = o


func _radius(k: int) -> float:
	return (t - wind - k * GAP) * SPEED


func step(_dt: float, _ppos: Vector2) -> void:
	if started < count:
		boss.set_glow(-4, minf(1.0, t / wind))
	while started < count and _radius(started) >= 0.0:
		boss.emit(Ev.RING, origin)
		started += 1
		if started == count:
			boss.detach_attack()
	if _radius(count - 1) > MAX_R:
		boss.finish_attack()


## 플레이어 쪽으로 퍼져 오는 고리의 가장 가까운 지점 (퍼지기 전엔 심장부)
func unparry_point(ppos: Vector2) -> Vector2:
	var d := ppos - origin
	var best := -1.0
	for k in count:
		var r := _radius(k)
		if r < d.length():
			best = maxf(best, maxf(r, 0.0))
	if best < 0.0:
		return Vector2.INF                        # 고리가 모두 플레이어를 지나갔다
	return origin + d.normalized() * best


## 고리에 닿으면 바깥쪽으로 밀려난다
func beam_hit(p: Vector2, r: float) -> Vector2:
	var k := _ring_at(p, r)
	if k < 0:
		return Vector2.ZERO
	var rel := p - origin
	return rel / rel.length() if rel.length() > 1.0 else Vector2.UP


## p 에 닿은 고리 번호 (회피로 통과한 고리는 빼고, 없으면 -1)
func _ring_at(p: Vector2, r: float) -> int:
	var dist := (p - origin).length()
	for k in count:
		var rr := _radius(k)
		if rr >= 0.0 and absf(dist - rr) < HALF + r and not dodged_rings.has(k):
			return k
	return -1


## 회피로 통과한 고리만 더는 맞지 않는다 (다음 고리는 그대로)
func mark_dodged(p: Vector2, r: float) -> void:
	var k := _ring_at(p, r)
	if k >= 0:
		dodged_rings.append(k)


func draw() -> void:
	var c: CanvasItem = boss
	var bt: float = boss.t
	if t < wind:                                  # 예고: 심장부에서 보라 고리가 맥동하며 모인다
		var k := t / wind
		var blink := 0.6 + 0.4 * sin(bt * 22.0)
		c.draw_circle(origin, 60.0 + 80.0 * k, Color(C_UNPARRY, 0.2 * k))
		c.draw_arc(origin, 300.0 * (1.0 - k) + 70.0, 0.0, TAU, 64, Color(C_UNPARRY_CORE, (0.3 + 0.5 * k) * blink), 4.0)
	for k in count:
		var rr := _radius(k)
		if rr < 0.0 or rr > MAX_R or dodged_rings.has(k):   # 빨아들인 고리는 사라진다
			continue
		c.draw_arc(origin, rr, 0.0, TAU, 160, Color(C_UNPARRY, 0.07), 140.0)        # 넓은 빛무리 (판정 없음)
		c.draw_arc(origin, rr, 0.0, TAU, 160, Color(C_UNPARRY, 0.7), HALF * 2.0)
		c.draw_arc(origin, rr, 0.0, TAU, 160, Color(C_UNPARRY_CORE, 0.9), 6.0)
		c.draw_arc(origin, rr + SPEED * 0.25, 0.0, TAU, 160, Color(C_UNPARRY, 0.15), 3.0)   # 앞쪽 희미한 예고선

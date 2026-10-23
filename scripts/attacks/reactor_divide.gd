extends "res://scripts/attacks/attack.gd"
## 양분 + 줄넘기 (반응로): 방벽 한가운데에서 **아주 굵은 보라 광선**이 바닥까지 내리꽂혀 경기장을 둘로 가른다 (패리 불가).
## 너무 굵어 돌진 한 번의 무적으로 건널 수 없고, 퍼펙트 회피(완전 동조)도 안 된다 (v0.129 규칙). 갈라진 동안 한쪽 칸에 갇힌다.
## 그동안 배출구에서 **빈틈 없는 잔탄 줄**이 차례로 내려온다 — 줄넘기: 돌진 무적으로 한 줄씩 넘는다 (엔터 더 건전 '벽치광이' 참고).
## 단계: warn(광선 자리가 옅게 예고, 점점 짙어짐) → on(광선 + 줄넘기) → fade
## boss 에 필요한 것: SPAWN_Y, FLOOR_Y, shots, bolt_mult(), emit

const Projectiles := preload("res://scripts/projectiles.gd")
const WARN := 1.2
const ON := 8.5
const FADE := 0.4
const HALF := 170.0                  # 판정 반폭 (폭 340: 돌진 한 번의 무적 거리보다 굵다)
const ROPES := 5
const ROPE_FIRST := 0.9              # 광선이 켜지고 첫 줄까지
const ROPE_T := 1.45                 # 줄 간격
const ROPE_SPEED := 300.0
const DOT := 40.0                    # 빈틈 없이 (기체가 사이로 못 빠진다)
const X0 := -1130.0
const X1 := 1130.0
const LIFE := 10.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var ropes := 0


func _init() -> void:
	kind = "divide"
	phase = "warn"


func step(_dt: float, _ppos: Vector2) -> void:
	match phase:
		"warn":
			if t >= WARN:
				set_phase("on")
				boss.emit(Ev.BEAM, Vector2(0, boss.SPAWN_Y))
		"on":
			while ropes < ROPES and t >= ROPE_FIRST + ropes * ROPE_T:
				_rope()
				ropes += 1
			if t >= ON:
				set_phase("fade")
		"fade":
			if t >= FADE:
				boss.finish_attack()


## 빈틈 없는 잔탄 줄 하나 (광선이 덮은 가운데는 빼고)
func _rope() -> void:
	var v := Vector2(0, ROPE_SPEED * boss.bolt_mult())
	var x := X0
	while x <= X1:
		if absf(x) > HALF + 10.0:
			boss.shots.spawn(Vector2(x, boss.SPAWN_Y), v, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
		x += DOT
	boss.emit(Ev.BOLT, Vector2(0, boss.SPAWN_Y))


func strand_width() -> float:
	return HALF * 2.0


func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "on" or p.y < boss.SPAWN_Y:
		return Vector2.ZERO
	if absf(p.x) >= HALF + r:
		return Vector2.ZERO
	return Vector2(1.0 if p.x >= 0.0 else -1.0, 0.0)


func unparry_point(ppos: Vector2) -> Vector2:
	if phase == "fade":
		return Vector2.INF
	return Vector2(0.0, clampf(ppos.y, boss.SPAWN_Y, boss.FLOOR_Y))


func draw() -> void:
	var c: CanvasItem = boss
	var top: float = boss.SPAWN_Y
	var bot: float = boss.FLOOR_Y + 60.0
	var bt: float = boss.t
	match phase:
		"warn":                                          # 광선 자리: 양쪽 테두리 점선이 점점 짙어진다
			var k := clampf(t / WARN, 0.0, 1.0)
			var blink := 0.6 + 0.4 * sin(bt * 18.0)
			c.draw_rect(Rect2(-HALF, top, HALF * 2.0, bot - top), Color(C_UNPARRY, 0.06 + 0.12 * k))
			var y := top
			while y < bot:
				c.draw_line(Vector2(-HALF, y), Vector2(-HALF, y + 40.0), Color(C_UNPARRY_CORE, (0.3 + 0.5 * k) * blink), 4.0)
				c.draw_line(Vector2(HALF, y), Vector2(HALF, y + 40.0), Color(C_UNPARRY_CORE, (0.3 + 0.5 * k) * blink), 4.0)
				y += 80.0
		"on", "fade":
			var a := 1.0 if phase == "on" else 1.0 - clampf(t / FADE, 0.0, 1.0)
			var fl := 0.92 + 0.08 * sin(bt * 40.0)
			c.draw_rect(Rect2(-HALF * 1.6 * fl, top, HALF * 3.2 * fl, bot - top), Color(C_UNPARRY, 0.12 * a))
			c.draw_rect(Rect2(-HALF, top, HALF * 2.0, bot - top), Color(C_UNPARRY, 0.8 * a))
			c.draw_rect(Rect2(-HALF * 0.5, top, HALF, bot - top), Color(C_UNPARRY_CORE, 0.9 * a))
			c.draw_rect(Rect2(-HALF * 0.15, top, HALF * 0.3, bot - top), Color(1, 1, 1, 0.8 * a))
			for q in 6:                                  # 광선을 타고 흐르는 빛 덩어리
				var yy := top + fposmod(bt * 900.0 + q * 420.0, bot - top)
				c.draw_circle(Vector2(0, yy), HALF * 0.7, Color(C_UNPARRY_CORE, 0.25 * a))

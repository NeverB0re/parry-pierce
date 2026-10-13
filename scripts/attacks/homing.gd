extends "res://scripts/attacks/attack.gd"
## 유도탄: 사일로(또는 코어 페이즈의 배기구) 해치가 달아오른 뒤 크고 느린 유도탄을 하나씩 쏜다.
## 피하기 어렵게 쫓아오지만 크고 느려서 패리하기 좋다 (주탄 → 리버스 드라이브).
## boss 에 필요한 것: homing_origins() → [[번호, 위치], ...], set_glow(c, v)

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.9
const SPEED := 270.0
const LIFE := 7.0
const AFTER := 0.6                   # 쏜 뒤 다음 공격까지

var origins: Array = []              # [[번호, 위치], ...] (쏘는 순간 다시 확인: 부서진 사일로는 빠진다)
var fired := false


func _init() -> void:
	kind = "homing"


func step(_dt: float, _ppos: Vector2) -> void:
	if origins.is_empty():
		origins = boss.homing_origins()
	if not fired:
		for o in origins:
			boss.set_glow(int(o[0]), t / WIND)
		if t < WIND:
			return
		fired = true
		for o in boss.homing_origins():
			var p: Vector2 = o[1]
			var side := signf(p.x) if absf(p.x) > 1.0 else 0.0
			boss.shots.spawn(p, Vector2(side * 0.5, -1.0).normalized() * SPEED, LIFE, 0.0, 0.0, Projectiles.Kind.HOMING)
			boss.set_glow(int(o[0]), 1.0)
		boss.emit(Ev.BOLT, origins[0][1])
		return
	if t >= WIND + AFTER:
		boss.finish_attack()


## 예고: 해치 위로 깜빡이는 고리
func draw() -> void:
	if fired:
		return
	var c: CanvasItem = boss
	var k := clampf(t / WIND, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(boss.t * 22.0)
	for o in origins:
		var p: Vector2 = o[1]
		c.draw_arc(p, 60.0 - 24.0 * k, 0.0, TAU, 28, Color(1.0, 0.95, 0.7, (0.3 + 0.6 * k) * blink), 3.0)

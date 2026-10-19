extends "res://scripts/attacks/attack.gd"
## 주포 (모함 본체, 패리 불가 = 보라): 뱃머리 아래 거대한 주포가 플레이어를 겨눈다 — 가는 조준선이 플레이어를 따라오다(aim) 멈추고 깜빡인 뒤(lock),
## 아주 굵은 광선 한 줄기를 한 번 쏘고 지나간다(fire). 굵어서 회피 무적으로 뚫기 어렵다 — 멈춘 줄 밖으로 빠져나가야 한다 (퍼펙트 회피면 빨아들인다).
## boss 에 필요한 것: cannon_world(), set_cannon_aim(a), set_cannon_glow(v), cannon_kick(), emit

const AIM := 1.8
const TRACK := 3.0                   # 조준점이 플레이어를 따라가는 빠르기
const LOCK := 0.5
const FIRE := 0.5
const FADE := 0.35
const HALF := 110.0                  # 판정 반폭 (굵다)
const LEN := 4200.0
const C_UNPARRY := Color(0.6, 0.08, 0.36)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var origin := Vector2.ZERO
var aim_pt := Vector2.INF
var dir := Vector2.DOWN


func _init() -> void:
	kind = "cannon"
	phase = "aim"


func step(dt: float, ppos: Vector2) -> void:
	if t < 0.0:                                      # 편대 패턴과 함께 나올 때: 조금 늦게 시작 (그동안 아무것도 안 한다)
		return
	match phase:
		"aim":
			origin = boss.cannon_world()
			if aim_pt == Vector2.INF:
				aim_pt = ppos
			aim_pt = aim_pt.lerp(ppos, 1.0 - exp(-TRACK * dt))
			dir = (aim_pt - origin).normalized()
			boss.set_cannon_aim(dir.angle())
			boss.set_cannon_glow(t / AIM * 0.6)
			if t >= AIM:
				set_phase("lock")
		"lock":
			boss.set_cannon_aim(dir.angle())
			boss.set_cannon_glow(0.6 + 0.4 * t / LOCK)
			if t >= LOCK:
				set_phase("fire")
				boss.emit(Ev.BEAM, origin)
				boss.cannon_kick()
		"fire":
			boss.set_cannon_aim(dir.angle())
			boss.set_cannon_glow(1.0)
			if t >= FIRE:
				set_phase("fade")
		"fade":
			if t >= FADE:
				boss.finish_attack()


func _end() -> Vector2:
	return origin + dir * LEN


func beam_hit(p: Vector2, r: float) -> Vector2:
	if phase != "fire":
		return Vector2.ZERO
	var q: Vector2 = boss.seg_closest(p, origin, _end())
	if q.distance_to(p) >= HALF + r:
		return Vector2.ZERO
	var n := dir.orthogonal()
	return n if n.dot(p - q) >= 0.0 else -n


func unparry_point(_ppos: Vector2) -> Vector2:
	return origin if phase != "fade" and t >= 0.0 else Vector2.INF


func draw() -> void:
	if t < 0.0 or aim_pt == Vector2.INF:            # 아직 첫 진행 전
		return
	var c: CanvasItem = boss
	var e := _end()
	var blink := 0.6 + 0.4 * sin(boss.t * 24.0)
	match phase:
		"aim":                                           # 가는 조준선 + 플레이어 쪽 조준 고리
			c.draw_line(origin, e, Color(C_UNPARRY_CORE, 0.35 * blink), 2.0)
			c.draw_line(origin, e, Color(C_UNPARRY, 0.06), 40.0)
			c.draw_arc(aim_pt, 70.0, 0.0, TAU, 32, Color(C_UNPARRY_CORE, 0.6 * blink), 3.0)
			c.draw_line(aim_pt + Vector2(-95, 0), aim_pt + Vector2(-50, 0), Color(C_UNPARRY_CORE, 0.6), 3.0)
			c.draw_line(aim_pt + Vector2(95, 0), aim_pt + Vector2(50, 0), Color(C_UNPARRY_CORE, 0.6), 3.0)
		"lock":                                          # 멈춤: 쏠 굵기만큼의 테두리가 빠르게 깜빡인다
			var n := dir.orthogonal() * HALF
			c.draw_colored_polygon(PackedVector2Array([origin + n, e + n, e - n, origin - n]), Color(C_UNPARRY, 0.1 + 0.12 * blink))
			c.draw_line(origin + n, e + n, Color(C_UNPARRY_CORE, 0.8 * blink), 3.0)
			c.draw_line(origin - n, e - n, Color(C_UNPARRY_CORE, 0.8 * blink), 3.0)
			c.draw_circle(origin, 60.0 + 30.0 * t / LOCK, Color(C_UNPARRY_CORE, 0.5))
		"fire", "fade":
			if dodged:                                   # 퍼펙트 회피로 빨아들였다
				return
			var a := 1.0 if phase == "fire" else 1.0 - clampf(t / FADE, 0.0, 1.0)
			var fl := 0.92 + 0.16 * sin(boss.t * 40.0)
			c.draw_line(origin, e, Color(C_UNPARRY, 0.1 * a), HALF * 5.0 * fl)       # 넓은 빛무리
			c.draw_line(origin, e, Color(C_UNPARRY, 0.25 * a), HALF * 3.0 * fl)
			c.draw_line(origin, e, Color(C_UNPARRY, 0.85 * a), HALF * 2.0)
			c.draw_line(origin, e, Color(C_UNPARRY_CORE, 0.95 * a), HALF * 0.9)
			c.draw_line(origin, e, Color(1, 1, 1, 0.8 * a), HALF * 0.3)
			c.draw_circle(origin, HALF * 1.6 * fl, Color(C_UNPARRY_CORE, 0.6 * a))

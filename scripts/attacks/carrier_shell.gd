extends "res://scripts/attacks/attack.gd"
## 함포 대형 포탄 (모함 본체, 배경에서): 뱃머리 포대가 플레이어를 겨눠 커다란 포탄 한 발을 쏜다. 포탄은 원근으로 커지며 날아와,
## 쏠 때의 플레이어 자리(금빛 표적 고리)에서 터져 잔탄 고리 두 겹 + 금색 주탄 몇 발을 사방으로 뿌린다.
## 떨어질 자리가 미리 보이므로 터지기 전에 비켜서고, 뿌려지는 금색 주탄은 패리 → 리버스 드라이브로 편대를 친다.
## boss 에 필요한 것: cannon_world(), aim_cannon(p), set_cannon_glow(v), cannon_kick(), shots, bolt_mult(), emit

const Projectiles := preload("res://scripts/projectiles.gd")
const AIM := 0.9                     # 포대가 플레이어를 겨눈다 (표적 고리가 따라온다)
const FLY := 1.25                    # 쏜 뒤 터지기까지
const AFTER := 0.3
const RING_A := 24                   # 바깥 고리 잔탄
const RING_B := 16                   # 안쪽 고리 잔탄 (느리게, 반 칸 어긋나게)
const MAINS := 4                     # 금색 주탄
const SPEED_A := 250.0
const SPEED_B := 170.0
const MAIN_SPEED := 300.0
const LIFE := 7.0
const BLAST_R := 110.0

var target := Vector2.INF
var origin := Vector2.ZERO


func _init() -> void:
	kind = "big_shell"
	phase = "aim"


func step(_dt: float, ppos: Vector2) -> void:
	if t < 0.0:                                      # 편대 패턴과 함께 나올 때: 조금 늦게 시작 (그동안 아무것도 안 한다)
		return
	match phase:
		"aim":
			target = ppos
			boss.aim_cannon(target)
			origin = boss.cannon_world()
			boss.set_cannon_glow(t / AIM)
			if t >= AIM:
				set_phase("fly")
				boss.emit(Ev.BOLT, origin)
				boss.cannon_kick()
		"fly":
			origin = boss.cannon_world()
			boss.set_cannon_glow(maxf(0.0, 1.0 - t * 2.0))
			if t >= FLY:
				_boom()
				set_phase("after")
		"after":
			if t >= AFTER:
				boss.finish_attack()


func _boom() -> void:
	var m: float = boss.bolt_mult()
	var ro := randf() * TAU
	for k in RING_A:
		var d := Vector2.from_angle(ro + k * TAU / RING_A)
		boss.shots.spawn(target + d * 30.0, d * SPEED_A * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
	for k in RING_B:
		var d := Vector2.from_angle(ro + (k + 0.5) * TAU / RING_B)
		boss.shots.spawn(target + d * 30.0, d * SPEED_B * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
	for k in MAINS:
		var d := Vector2.from_angle(ro + (k + 0.25) * TAU / MAINS)
		boss.shots.spawn(target + d * 40.0, d * MAIN_SPEED * m, LIFE)
	boss.emit(Ev.MINE, target)
	boss.emit(Ev.STOMP, target)


func draw() -> void:
	if t < 0.0:
		return
	if target == Vector2.INF or phase == "after":
		return
	var c: CanvasItem = boss
	var blink := 0.6 + 0.4 * sin(boss.t * 20.0)
	var k := clampf(t / FLY, 0.0, 1.0) if phase == "fly" else 0.0
	var r := BLAST_R * (1.8 - 0.8 * k)
	c.draw_circle(target, r, Color(1.0, 0.6, 0.25, 0.05 + 0.12 * k))                 # 떨어질 자리 (금빛 표적 고리, 좁혀 든다)
	c.draw_arc(target, r, 0.0, TAU, 40, Color(1.0, 0.8, 0.45, (0.4 + 0.5 * k) * blink), 4.0)
	c.draw_line(target + Vector2(-26, 0), target + Vector2(26, 0), Color(1.0, 0.85, 0.5, 0.7), 3.0)
	c.draw_line(target + Vector2(0, -26), target + Vector2(0, 26), Color(1.0, 0.85, 0.5, 0.7), 3.0)
	if phase != "fly":
		return
	var q := origin.lerp(target, k * k)                                                # 원근으로 다가오는 포탄: 점점 커진다
	var sz := lerpf(18.0, 70.0, k * k)
	c.draw_line(origin.lerp(target, maxf(0.0, k * k - 0.1)), q, Color(1.0, 0.65, 0.3, 0.35), sz * 0.8)
	c.draw_circle(q, sz * 1.5, Color(1.0, 0.6, 0.25, 0.25))
	c.draw_circle(q, sz, Color(1.0, 0.75, 0.4, 0.95))
	c.draw_circle(q, sz * 0.55, Color(1, 0.95, 0.8))

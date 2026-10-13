extends "res://scripts/attacks/attack.gd"
## 조준 연사: 포구가 달아오르는 동안 조준선이 플레이어를 따라가고, 5갈래 부채꼴을 SHOTS 번 쏜다. 가운데 3갈래는 주탄,
## 바깥 2갈래는 잔탄 (잔탄을 일찍 접하게 한다). 탄은 패리할 수 있다.
## boss 에 필요한 것: set_glow(cannon, v), glow_of(cannon), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const CHARGE := 1.0
const INTERVAL := 0.42
const SHOTS := 3
const SPREAD := 0.28                 # 갈래 사이 각도
const SPEED := 480.0
const C_WARN := Color(1.0, 0.3, 0.25)

var cannon := -1                     # 발사점 번호 (-1 = 머리). 부서지면 공격이 끊긴다
var origin := Vector2.ZERO
var aim := 0.0
var shots := 0


func _init(c: int, o: Vector2, ppos: Vector2) -> void:
	kind = "volley"
	cannon = c
	part = c
	origin = o
	aim = (ppos - o).angle()


func step(_dt: float, ppos: Vector2) -> void:
	if t < CHARGE:
		boss.set_glow(cannon, t / CHARGE)
		aim = (ppos - origin).angle()          # 조준선이 플레이어를 따라간다
		return
	if t >= CHARGE + shots * INTERVAL:
		var base := (ppos - origin).angle()
		aim = base
		for k in range(-2, 3):
			var kd := Projectiles.Kind.SMALL if absi(k) == 2 else Projectiles.Kind.BOLT
			boss.shots.spawn(origin, Vector2.from_angle(base + k * SPREAD) * SPEED * boss.bolt_mult(), 8.0, 0.0, 0.0, kd)
		boss.emit(Ev.BOLT, origin)
		boss.set_glow(cannon, 1.0)
		shots += 1
		if shots >= SHOTS:
			boss.finish_attack()


## 곧 날아올 5갈래 조준선
func draw() -> void:
	if t >= CHARGE + 0.5:
		return
	var gl: float = boss.glow_of(cannon)
	for k in range(-2, 3):
		var d := Vector2.from_angle(aim + k * SPREAD)
		boss.draw_line(origin, origin + d * 900.0, Color(C_WARN, 0.05 + 0.22 * gl), 2.0)

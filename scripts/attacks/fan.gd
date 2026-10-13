extends "res://scripts/attacks/attack.gd"
## 부채 탄막: 조준선이 플레이어를 따라가다가, 넓은 부채꼴로 잔탄을 WAVES 번 쏜다. 각 부채의 한가운데 한 발은 주탄.
## boss 에 필요한 것: set_glow(c, v), glow_of(c), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 1.0
const WAVES := 3
const INTERVAL := 0.5
const COUNT := 13                    # 부채 하나의 탄 수 (가운데 = 주탄)
const SPREAD := 1.5                  # 부채 전체 각도 (라디안)
const SMALL_SPEED := 300.0
const MAIN_SPEED := 360.0
const C_WARN := Color(1.0, 0.3, 0.25)

var cannon := -1
var origin := Vector2.ZERO
var aim := 0.0
var waves := 0


func _init(c: int, o: Vector2, ppos: Vector2) -> void:
	kind = "fan"
	cannon = c
	part = c
	origin = o
	aim = (ppos - o).angle()


func step(_dt: float, ppos: Vector2) -> void:
	if t < WIND:
		boss.set_glow(cannon, t / WIND)
		aim = (ppos - origin).angle()
		return
	if t >= WIND + waves * INTERVAL:
		aim = (ppos - origin).angle()
		var m: float = boss.bolt_mult()
		var half := (COUNT - 1) / 2
		for k in COUNT:
			var a := aim + (k - half) * SPREAD / (COUNT - 1)
			if k == half:
				boss.shots.spawn(origin, Vector2.from_angle(a) * MAIN_SPEED * m, 9.0)
			else:
				boss.shots.spawn(origin, Vector2.from_angle(a) * SMALL_SPEED * m, 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		boss.emit(Ev.BOLT, origin)
		boss.set_glow(cannon, 1.0)
		waves += 1
		if waves >= WAVES:
			boss.finish_attack()


## 예고: 부채꼴 양끝과 가운데(주탄) 조준선
func draw() -> void:
	if t >= WIND + 0.3:
		return
	var c: CanvasItem = boss
	var gl: float = boss.glow_of(cannon)
	for e in [-0.5, 0.5]:
		c.draw_line(origin, origin + Vector2.from_angle(aim + e * SPREAD) * 800.0, Color(C_WARN, 0.06 + 0.2 * gl), 2.0)
	c.draw_line(origin, origin + Vector2.from_angle(aim) * 1000.0, Color(1.0, 0.88, 0.35, 0.15 + 0.4 * gl), 3.0)

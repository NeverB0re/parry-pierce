extends "res://scripts/attacks/attack.gd"
## 흩뿌리기: 포구가 달아오른 뒤 사방으로 탄을 COUNT 발 흩뿌린다. 세 발에 한 발은 잔탄. 탄은 패리할 수 있다.
## boss 에 필요한 것: set_glow(cannon, v), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const CHARGE := 1.3
const COUNT := 18
const SPEED := Vector2(264.0, 408.0)

var cannon := -1                     # 발사점 번호 (-1 = 머리). 부서지면 공격이 끊긴다
var origin := Vector2.ZERO


func _init(c: int, o: Vector2) -> void:
	kind = "burst"
	cannon = c
	part = c
	origin = o


func step(_dt: float, _ppos: Vector2) -> void:
	if t < CHARGE:
		boss.set_glow(cannon, t / CHARGE)
		return
	for i in COUNT:
		var ang := TAU * i / float(COUNT) + randf_range(-0.15, 0.15)
		var kd := Projectiles.Kind.SMALL if i % 3 == 2 else Projectiles.Kind.BOLT
		boss.shots.spawn(origin, Vector2.from_angle(ang) * randf_range(SPEED.x, SPEED.y) * boss.bolt_mult(), 9.0, 0.0, 0.0, kd)
	boss.emit(Ev.BOLT, origin)
	boss.set_glow(cannon, 1.0)
	boss.finish_attack()

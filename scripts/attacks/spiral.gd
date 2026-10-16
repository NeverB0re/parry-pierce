extends "res://scripts/attacks/attack.gd"
## 회전 탄막: 포대가 달아오르는 동안(예고: 휘두를 부채꼴이 표시되고 플레이어 쪽을 겨눈다) 잔탄 줄기를 그 부채꼴 안에서
## 한쪽 끝에서 반대쪽 끝까지 휘둘렀다 돌아오며 뿌리고, 그 사이 주탄을 플레이어에게 쏜다. 부채꼴 밖(특히 반대쪽)은 비어 있어
## 거기로 빠져나갈 수 있다. 잔탄은 피하거나 패리로 흡수하고, 주탄을 패리해 리버스 드라이브를 연다.
## hard(코어 페이즈): 줄기 2개(서로 반대로 휘두름, 같은 부채꼴 안), 조금 더 촘촘하고 오래, 주탄도 더 자주.
## 다른 패턴이 쉬는 동안에만 혼자 쓴다 (고르기는 fortress.gd).
## boss 에 필요한 것: set_glow(c, v), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.9
const DURATION := 2.8
const RATE := 0.11                   # 잔탄 간격 (줄기마다 한 발)
const RATE_HARD := 0.09
const SWEEP := 0.8                   # 부채꼴 반각 (라디안, 전체 약 92도)
const MAIN_EVERY := 0.7              # 주탄 간격
const MAIN_EVERY_HARD := 0.5
const SMALL_SPEED := 270.0
const MAIN_SPEED := 340.0
const C_WARN := Color(1.0, 0.3, 0.25)

var cannon := -1                     # 발사점 번호 (-1 = 첨탑). 부서지면 끊긴다
var origin := Vector2.ZERO
var center := 0.0                    # 부채꼴 가운데 방향 (예고 동안 플레이어를 따라가다 쏘기 시작할 때 고정)
var spin := 1.0                      # +1 / -1: 어느 끝에서 시작하는가
var smalls := 0
var mains := 0
var arms := 1
var rate := RATE
var duration := DURATION
var main_every := MAIN_EVERY
var fixed := false                   # 고정: 부채꼴 방향을 처음 정한 대로 두고, 주탄도 부채꼴 가운데로 쏜다


func _init(c: int, o: Vector2, ppos := Vector2(0.0, -1500.0), hard := false) -> void:
	kind = "spiral"
	cannon = c
	part = c
	origin = o
	center = (ppos - o).angle()
	spin = 1.0 if randf() < 0.5 else -1.0
	if hard:
		arms = 2
		rate = RATE_HARD
		duration = 3.4
		main_every = MAIN_EVERY_HARD


func step(_dt: float, ppos: Vector2) -> void:
	if t < WIND:
		boss.set_glow(cannon, t / WIND)
		if not fixed:
			center = (ppos - origin).angle()        # 부채꼴이 플레이어를 따라가다가 쏘기 직전에 고정된다
		return
	var ft := t - WIND
	var m: float = boss.bolt_mult()
	while smalls * rate <= ft and smalls * rate < duration:
		var ph := cos(TAU * smalls * rate / duration)       # 한쪽 끝에서 시작해 반대쪽 끝까지 갔다 돌아온다
		for k in arms:
			var sgn := 1.0 if k == 0 else -1.0
			var a := center - spin * sgn * SWEEP * ph
			boss.shots.spawn(origin, Vector2.from_angle(a) * SMALL_SPEED * m, 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		smalls += 1
	while mains * main_every <= ft and mains * main_every < duration:
		var md := Vector2.from_angle(center) if fixed else (ppos - origin).normalized()
		boss.shots.spawn(origin, md * MAIN_SPEED * m, 9.0)
		boss.emit(Ev.BOLT, origin)
		mains += 1
	boss.set_glow(cannon, 1.0)
	if ft >= duration:
		boss.finish_attack()


## 예고: 휘두를 부채꼴(옅은 붉은 면 + 양 끝 선)과 시작 끝에서 휘두르는 방향 화살표
func draw() -> void:
	if t >= WIND + 0.4:
		return
	var c: CanvasItem = boss
	var k := clampf(t / WIND, 0.0, 1.0)
	var a0 := center - SWEEP
	var a1 := center + SWEEP
	var pts := PackedVector2Array([origin])
	for j in 13:
		pts.append(origin + Vector2.from_angle(lerpf(a0, a1, j / 12.0)) * 1100.0)
	c.draw_colored_polygon(pts, Color(C_WARN, 0.04 + 0.08 * k))
	for a in [a0, a1]:
		c.draw_line(origin, origin + Vector2.from_angle(a) * 1100.0, Color(C_WARN, 0.2 + 0.35 * k), 2.0)
	var start := center - spin * SWEEP
	var p := origin + Vector2.from_angle(start) * 140.0
	var tg := Vector2.from_angle(start + PI * 0.5 * spin)
	var n := Vector2.from_angle(start)
	c.draw_colored_polygon(PackedVector2Array([p + tg * 26.0, p - tg * 8.0 + n * 14.0, p - tg * 8.0 - n * 14.0]), Color(1.0, 0.85, 0.6, 0.4 + 0.5 * k))

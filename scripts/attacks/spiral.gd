extends "res://scripts/attacks/attack.gd"
## 나선 탄막: 포대가 달아오르며(회전 방향 예고) 잔탄을 양쪽으로 돌려 뿌리고, 그 사이 주탄을 플레이어에게 쏜다.
## 잔탄은 피하거나 패리로 흡수하고, 주탄을 패리해 리버스 드라이브를 연다.
## hard(코어 페이즈): 갈래 3개, 더 오래, 주탄도 더 자주.
## boss 에 필요한 것: set_glow(c, v), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.8
const DURATION := 2.4
const RATE := 0.075                  # 잔탄 간격 (한 번에 반대 방향 둘)
const TURN := 0.33                   # 잔탄마다 도는 각도
const MAIN_EVERY := 0.6              # 주탄 간격
const SMALL_SPEED := 270.0
const MAIN_SPEED := 340.0
const C_WARN := Color(1.0, 0.3, 0.25)

var cannon := -1                     # 발사점 번호 (-1 = 첨탑). 부서지면 끊긴다
var origin := Vector2.ZERO
var ang := 0.0
var spin := 1.0
var smalls := 0
var mains := 0
var arms := 2                        # 한 번에 뿌리는 갈래 수 (반대 방향으로 고르게)
var duration := DURATION
var main_every := MAIN_EVERY


func _init(c: int, o: Vector2, hard := false) -> void:
	kind = "spiral"
	cannon = c
	part = c
	origin = o
	ang = randf() * TAU
	spin = 1.0 if randf() < 0.5 else -1.0
	if hard:
		arms = 3
		duration = 3.2
		main_every = 0.45


func step(_dt: float, ppos: Vector2) -> void:
	if t < WIND:
		boss.set_glow(cannon, t / WIND)
		return
	var ft := t - WIND
	var m: float = boss.bolt_mult()
	while smalls * RATE <= ft and smalls * RATE < duration:
		for k in arms:
			boss.shots.spawn(origin, Vector2.from_angle(ang + k * TAU / arms) * SMALL_SPEED * m, 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		ang += TURN * spin
		smalls += 1
	while mains * main_every <= ft and mains * main_every < duration:
		boss.shots.spawn(origin, (ppos - origin).normalized() * MAIN_SPEED * m, 9.0)
		boss.emit(Ev.BOLT, origin)
		mains += 1
	boss.set_glow(cannon, 1.0)
	if ft >= duration:
		boss.finish_attack()


## 예고: 포구 둘레를 도는 화살표 (회전 방향)
func draw() -> void:
	if t >= WIND:
		return
	var c: CanvasItem = boss
	var k := t / WIND
	var r := 90.0 + 30.0 * (1.0 - k)
	var base: float = boss.t * 4.0 * spin
	c.draw_arc(origin, r, 0.0, TAU, 40, Color(C_WARN, 0.25 + 0.35 * k), 3.0)
	for j in 4:
		var a := base + j * TAU / 4.0
		var p := origin + Vector2.from_angle(a) * r
		var tg := Vector2.from_angle(a + PI * 0.5 * spin)
		var n := Vector2.from_angle(a)
		c.draw_colored_polygon(PackedVector2Array([p + tg * 22.0, p - tg * 8.0 + n * 12.0, p - tg * 8.0 - n * 12.0]), Color(1.0, 0.85, 0.6, 0.4 + 0.5 * k))

extends "res://scripts/attacks/attack.gd"
## 반응로 폭주 (코어 페이즈 전용, 고난도 탄막): 반응로가 달아오르며 맥동한 뒤 잔탄 고리를 RINGS 번 뿜는다.
## 고리마다 조금씩 돌려 쏘아 겹친 고리가 소용돌이 격자를 이루고, 그 틈으로 빠져나가야 한다.
## 두 고리마다 주탄 한 발이 플레이어를 노린다 (패리 → 리버스 드라이브로 반응로에 꽂을 기회).
## boss 에 필요한 것: bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 1.0
const RINGS := 8
const INTERVAL := 0.4
const COUNT := 20                    # 고리 하나의 잔탄 수
const TWIST := 0.35                  # 고리마다 도는 양 (탄 사이 간격의 비율)
const START_R := 150.0               # 반응로 장갑 바깥에서 나온다
const SMALL_SPEED := 210.0
const MAIN_SPEED := 300.0
const AFTER := 0.4
const C_WARN := Color(1.0, 0.3, 0.25)
const C_HOT := Color(1.0, 0.72, 0.3)

var origin := Vector2.ZERO
var rings := 0
var base_ang := 0.0
var turn := 1.0


func _init(o: Vector2) -> void:
	kind = "overload"
	origin = o
	base_ang = randf() * TAU
	turn = 1.0 if randf() < 0.5 else -1.0


func step(_dt: float, ppos: Vector2) -> void:
	if t < WIND:
		return
	var ft := t - WIND
	var m: float = boss.bolt_mult()
	while rings < RINGS and rings * INTERVAL <= ft:
		var off := base_ang + turn * rings * TWIST * TAU / COUNT
		for j in COUNT:
			var d := Vector2.from_angle(off + j * TAU / COUNT)
			boss.shots.spawn(origin + d * START_R, d * SMALL_SPEED * m, 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		if rings % 2 == 1:
			var aim := (ppos - origin).normalized()
			boss.shots.spawn(origin + aim * START_R, aim * MAIN_SPEED * m, 9.0)
		boss.emit(Ev.BOLT, origin)
		rings += 1
	if rings >= RINGS and ft >= (RINGS - 1) * INTERVAL + AFTER:
		boss.finish_attack()


## 예고: 반응로 둘레로 붉은 고리가 조여 들고, 쏘는 동안엔 반응로 둘레가 달아오른다
func draw() -> void:
	var c: CanvasItem = boss
	var bt: float = boss.t
	if t < WIND:
		var k := t / WIND
		var blink := 0.6 + 0.4 * sin(bt * 24.0)
		c.draw_arc(origin, START_R + 220.0 * (1.0 - k), 0.0, TAU, 64, Color(C_WARN, (0.25 + 0.55 * k) * blink), 5.0)
		c.draw_circle(origin, START_R, Color(C_HOT, 0.12 * k))
		for j in 8:
			var a := base_ang + j * TAU / 8.0 + bt * turn
			c.draw_line(origin + Vector2.from_angle(a) * START_R, origin + Vector2.from_angle(a) * (START_R + 60.0 * k), Color(C_HOT, 0.6 * k), 4.0)
		return
	if rings < RINGS:
		c.draw_arc(origin, START_R, 0.0, TAU, 48, Color(C_HOT, 0.5 + 0.3 * sin(bt * 30.0)), 6.0)

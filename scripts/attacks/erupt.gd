extends "res://scripts/attacks/attack.gd"
## 융해 지대 분출: 발을 들었다(경고) 구르면 바닥 여러 곳(하나는 플레이어 바로 아래)에서 용융물 덩어리가 솟구친다.
## 바닥을 쓰는 패턴 (낮은 곳에 머물면 위험). 덩어리는 탄과 같아서 패리할 수 있다.
## boss 에 필요한 것: feet (발 위치 배열), FOOT_REST

const Projectiles := preload("res://scripts/projectiles.gd")
const LIFT_TIME := 0.7               # 발을 들어 경고
const LIFT_H := 420.0
const SLAM_TIME := 0.14
const SPOTS := 4                     # 분출 지점 수 (하나는 플레이어 바로 아래)
const GLOBS := 4                     # 지점마다 솟는 덩어리 수
const GAP := 0.1                     # 덩어리 사이 간격
const GLOB_G := 600.0                # 덩어리 중력
const OVERSHOOT := 150.0             # 플레이어 높이보다 이만큼 위까지 솟는다
const SPOT_X := 1080.0               # 분출 지점 x 범위
const C_LAVA := Color(1.0, 0.35, 0.12)
const C_WARN := Color(1.0, 0.3, 0.25)

var foot := 0
var spots: Array[float] = []
var h := 0.0
var speed := 0.0
var fired := 0
var slammed := false


func _init(ppos: Vector2) -> void:
	kind = "erupt"
	foot = 1 if ppos.x >= 0.0 else 0
	spots = [clampf(ppos.x, -SPOT_X, SPOT_X)]
	while spots.size() < SPOTS:
		var x := randf_range(-SPOT_X, SPOT_X)
		var ok := true
		for sx in spots:
			if absf(sx - x) < 220.0:
				ok = false
		if ok:
			spots.append(x)
	h = clampf(-ppos.y, 300.0, 2800.0) + OVERSHOOT
	speed = sqrt(2.0 * GLOB_G * h)


func step(_dt: float, _ppos: Vector2) -> void:
	var rest: Vector2 = boss.FOOT_REST[foot]
	var slam_at := LIFT_TIME + SLAM_TIME
	if t < LIFT_TIME:
		boss.feet[foot] = rest.lerp(rest + Vector2(0, -LIFT_H), smoothstep(0.0, 1.0, t / LIFT_TIME))
		return
	if t < slam_at:
		var k := (t - LIFT_TIME) / SLAM_TIME
		var f: Vector2 = boss.feet[foot]
		f.y = lerpf(-LIFT_H, 0.0, k * k)
		boss.feet[foot] = f
		return
	boss.feet[foot] = rest
	if not slammed:
		slammed = true
		boss.emit(Ev.STOMP, rest)
	if fired < GLOBS and t >= slam_at + fired * GAP:
		for x in spots:
			var v := Vector2(randf_range(-40.0, 40.0), -speed * randf_range(0.92, 1.0))
			boss.shots.spawn(Vector2(x, -12.0), v, 9.0, Projectiles.WARMUP, GLOB_G, Projectiles.Kind.LAVA)
		boss.emit(Ev.ERUPT, Vector2(spots[0], 0.0))
		fired += 1
	elif fired >= GLOBS and t >= slam_at + GLOBS * GAP + 0.3:
		boss.finish_attack()


## 경고: 분출 지점의 바닥이 부글거리고, 솟을 높이까지 희미한 기둥
func draw() -> void:
	if fired >= GLOBS:
		return
	var c: CanvasItem = boss
	var bt: float = boss.t
	var k := clampf(t / (LIFT_TIME + SLAM_TIME), 0.0, 1.0)
	for sx in spots:
		var bub := PackedVector2Array()
		for j in 20:
			var a := TAU * j / 20.0
			bub.append(Vector2(sx + cos(a) * (40.0 + 50.0 * k), -6.0 + sin(a) * (8.0 + 6.0 * k)))
		c.draw_colored_polygon(bub, Color(C_LAVA, 0.35 + 0.4 * k))
		c.draw_line(Vector2(sx, -10.0), Vector2(sx, -h), Color(C_WARN, 0.05 + 0.15 * k), 26.0)
		for j in 3:
			var bx := sx + sin(bt * 9.0 + j * 2.1) * 35.0
			c.draw_circle(Vector2(bx, -10.0 - fmod(bt * 120.0 + j * 30.0, 50.0)), 6.0, Color(1.0, 0.6, 0.25, 0.7 * k))

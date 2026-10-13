extends "res://scripts/attacks/attack.gd"
## 프레스 (근접공격 = 회피 불가): 천장 전체가 내려와 경기장을 깔아뭉갠다. 정지선(STOP_Y) 아래로 내려가 있어야 산다.
## 일반 돌진의 무적으로는 통과할 수 없고, 패리하면 막기는 하지만 거대한 힘에 아래로 내리꽂혀 융해 지대로 빠진다.
## 단계: warn(정지선 점멸, 천장이 조금씩 내려옴) → drop(가속하며 내려옴) → hold → rise
## 내려오는 판에 닿으면 판 아래로 밀려난다 (피해는 main.gd 가 판정)

const WARN := 1.6
const DROP := 0.9
const HOLD := 0.7
const RISE := 1.2
const TOP := -3100.0                 # 판 윗변 (천장 너머)
const START := -3020.0               # 경고 시작 때 판 아랫변
const STOP_Y := -650.0               # 판이 멈추는 높이 (이 아래가 안전)
const HALF_W := 1260.0
const C_STEEL := Color(0.16, 0.16, 0.18)
const C_HAZARD := Color(1.0, 0.35, 0.18)
const C_WARN := Color(1.0, 0.3, 0.25)

var bottom := START                  # 판 아랫변 y
var speed := 0.0                     # 이번 프레임에 판이 내려오는 속도 (px/s)


func _init() -> void:
	kind = "press"
	phase = "warn"


func step(dt: float, _ppos: Vector2) -> void:
	var prev := bottom
	match phase:
		"warn":
			bottom = START + 70.0 * smoothstep(0.0, 1.0, t / WARN)
			if t >= WARN:
				set_phase("drop")
		"drop":
			var k := minf(1.0, t / DROP)
			bottom = lerpf(START + 70.0, STOP_Y, k * k)
			if k >= 1.0:
				set_phase("hold")
				boss.emit(Ev.PRESS, Vector2(0, STOP_Y))
		"hold":
			if t >= HOLD:
				set_phase("rise")
		"rise":
			bottom = lerpf(STOP_Y, START, smoothstep(0.0, 1.0, minf(1.0, t / RISE)))
			if t >= RISE:
				boss.finish_attack()
	speed = (bottom - prev) / dt if dt > 0.0 else 0.0


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	if phase != "drop" and phase != "hold":
		return
	out.append({"id": "press", "rect": Rect2(-HALF_W, TOP, HALF_W * 2.0, bottom - TOP), "pos": Vector2(ppos.x, bottom),
		"push": Vector2.DOWN, "melee": true, "speed": maxf(speed, 0.0)})


func draw() -> void:
	var c: CanvasItem = boss
	var bt: float = boss.t
	if phase == "warn" or phase == "drop":       # 정지선: 이 아래로!
		var blink := 0.5 + 0.5 * sin(bt * 20.0)
		c.draw_rect(Rect2(-HALF_W, STOP_Y, HALF_W * 2.0, 10.0), Color(C_WARN, 0.35 + 0.5 * blink))
		for k in 9:
			var x := -1000.0 + k * 250.0
			var y := STOP_Y + 30.0 + 18.0 * blink
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 28, y), Vector2(x + 28, y), Vector2(x, y + 34)]), Color(C_WARN, 0.5 + 0.4 * blink))
		var kw := clampf(t / WARN, 0.0, 1.0) if phase == "warn" else 1.0
		c.draw_rect(Rect2(-HALF_W, bottom, HALF_W * 2.0, STOP_Y - bottom), Color(C_WARN, 0.04 + 0.08 * kw))
	# 판: 강철 + 유압 기둥 + 아랫변 위험 줄무늬와 이빨
	c.draw_rect(Rect2(-HALF_W, TOP - 200.0, HALF_W * 2.0, bottom - TOP + 200.0), C_STEEL)
	for k in 6:
		var x := -1050.0 + k * 420.0
		c.draw_rect(Rect2(x - 30.0, TOP - 200.0, 60.0, bottom - TOP + 120.0), Color(0.1, 0.1, 0.11))
		c.draw_line(Vector2(x - 30.0, TOP), Vector2(x - 30.0, bottom - 80.0), Color(0.5, 0.48, 0.44, 0.5), 3.0)
	c.draw_rect(Rect2(-HALF_W, bottom - 60.0, HALF_W * 2.0, 60.0), Color(0.22, 0.2, 0.18))
	for k in 26:
		var x := -HALF_W + k * 100.0
		c.draw_line(Vector2(x, bottom - 58.0), Vector2(x + 50.0, bottom - 4.0), Color(C_HAZARD, 0.8), 14.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, bottom), Vector2(x + 100.0, bottom), Vector2(x + 50.0, bottom + 34.0)]), Color(0.3, 0.28, 0.26))
	c.draw_line(Vector2(-HALF_W, bottom), Vector2(HALF_W, bottom), C_HAZARD, 4.0)

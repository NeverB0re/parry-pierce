extends "res://scripts/attacks/attack.gd"
## 융해 기뢰 (바닥을 쓰는 패턴): 박격포가 기뢰를 융해 지대 위로 쏘아 올린다. 내려앉은 기뢰는 깜빡이다가
## 위쪽 부채꼴로 잔탄을 터뜨린다 (가운데 한 발은 주탄). 낮은 곳에 머물수록 위험하다.
## boss 에 필요한 것: MORTARS (박격포 위치 2개), set_glow(c, v)

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.5
const FLIGHT := 0.9                  # 날아가는 시간
const ARM := 1.1                     # 내려앉은 뒤 터질 때까지 (깜빡임 = 경고)
const COUNT := 3
const OFFSETS := [-380.0, 0.0, 380.0]
const BURST := 9                     # 터질 때 잔탄 수 (가운데 = 주탄)
const BURST_SPREAD := 1.7
const BURST_SPEED := 420.0
const ARC_H := 520.0                 # 포물선 높이
const C_WARN := Color(1.0, 0.3, 0.25)

var mines: Array[Dictionary] = []    # {from, to, t0, done}


func _init(ppos: Vector2) -> void:
	kind = "mines"
	for k in COUNT:
		var x := clampf(ppos.x + OFFSETS[k] + randf_range(-60.0, 60.0), -1080.0, 1080.0)
		mines.append({"to": Vector2(x, -16.0), "t0": WIND + k * 0.15, "done": false})


func step(_dt: float, _ppos: Vector2) -> void:
	boss.set_glow(-3, minf(1.0, t / WIND))
	var left := 0
	for mn in mines:
		if mn["done"]:
			continue
		if not mn.has("from"):
			var to: Vector2 = mn["to"]
			mn["from"] = boss.MORTARS[0 if to.x < 0.0 else 1]
		if t >= float(mn["t0"]) + FLIGHT + ARM:
			mn["done"] = true
			var p: Vector2 = mn["to"]
			for k in BURST:
				var a := -PI * 0.5 + (k - (BURST - 1) / 2) * BURST_SPREAD / (BURST - 1)
				var kd := Projectiles.Kind.BOLT if k == (BURST - 1) / 2 else Projectiles.Kind.SMALL
				boss.shots.spawn(p + Vector2(0, -20), Vector2.from_angle(a) * BURST_SPEED, 7.0, 0.0, 0.0, kd)
			boss.emit(Ev.MINE, p)
		else:
			left += 1
	if left == 0:
		boss.finish_attack()


func _mine_pos(mn: Dictionary) -> Vector2:
	var k := clampf((t - float(mn["t0"])) / FLIGHT, 0.0, 1.0)
	var a: Vector2 = mn["from"]
	var b: Vector2 = mn["to"]
	var p := a.lerp(b, k)
	p.y -= ARC_H * 4.0 * k * (1.0 - k)
	return p


func draw() -> void:
	var c: CanvasItem = boss
	for mn in mines:
		if mn["done"] or not mn.has("from") or t < float(mn["t0"]):
			continue
		var p := _mine_pos(mn)
		var landed := t >= float(mn["t0"]) + FLIGHT
		var to: Vector2 = mn["to"]
		# 떨어질 자리 표시
		c.draw_arc(to, 46.0, PI, TAU, 16, Color(C_WARN, 0.5), 3.0)
		c.draw_circle(p, 22.0, Color(0.14, 0.15, 0.18))
		c.draw_arc(p, 22.0, 0.0, TAU, 20, Color(0.55, 0.6, 0.68), 3.0)
		if landed:
			var ak := clampf((t - float(mn["t0"]) - FLIGHT) / ARM, 0.0, 1.0)
			var on := int(t * (6.0 + 14.0 * ak)) % 2 == 0
			c.draw_circle(p, 8.0, Color(1.0, 0.3, 0.2) if on else Color(0.4, 0.1, 0.08))
			# 터질 방향 (위쪽 부채꼴) 경고
			for e in [-0.5, 0.0, 0.5]:
				var d := Vector2.from_angle(-PI * 0.5 + e * BURST_SPREAD)
				c.draw_line(p, p + d * (160.0 + 260.0 * ak), Color(C_WARN, 0.12 + 0.3 * ak), 2.0 if e != 0.0 else 3.0)
		else:
			c.draw_circle(p, 6.0, Color(1.0, 0.6, 0.3))

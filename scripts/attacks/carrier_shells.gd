extends "res://scripts/attacks/attack.gd"
## 함포 포격 (모함 본체, 배경에서): 멀리 정박한 모함의 포대가 일제히 불을 뿜으면, 포탄이 원근으로 다가와(점점 커지며) 플레이어 둘레 여러 곳에 떨어진다.
## 떨어질 자리는 먼저 금빛 표적 고리로 보인다 (겨누지 않는다: 플레이어 둘레 고리 위 무작위 자리, 몇 곳은 비워 둔다).
## 떨어지는 순간 그 자리에서 잔탄이 사방으로 터지고, 한 발씩 금색 주탄이 섞인다 (패리 → 리버스 드라이브로 편대를 친다).
## 화면 가득 표적 고리와 폭발 — 실제 위협은 터지는 탄뿐 (압도적으로 보이게).
## boss 에 필요한 것: battery_pos(k), BATTERIES, set_battery_glow(k, v), shots, bolt_mult(), emit

const Projectiles := preload("res://scripts/projectiles.gd")
const WAVES := 3
const WAVE_GAP := 0.75
const PER_WAVE := 7
const FALL := 1.0                    # 표적 고리가 뜨고 포탄이 떨어지기까지
const RING_IN := 260.0               # 떨어질 자리: 플레이어에서 이 거리 ~
const RING_OUT := 900.0
const BURST_N := 10
const SPEED := 230.0
const MAIN_SPEED := 280.0
const LIFE := 6.0
const BLAST_R := 70.0                # 표적 고리 반지름 (그림)

var marks: Array = []                # [{pos, t0, from, done}]
var waves := 0


func _init() -> void:
	kind = "shells"


func step(_dt: float, ppos: Vector2) -> void:
	while waves < WAVES and t >= waves * WAVE_GAP:
		_wave(ppos)
		waves += 1
	var all_done := waves >= WAVES
	for m in marks:
		if m["done"]:
			continue
		all_done = false
		if t >= float(m["t0"]) + FALL:
			m["done"] = true
			_burst(m["pos"], int(m["n"]))
	if all_done and t >= (WAVES - 1) * WAVE_GAP + FALL + 0.3:
		boss.finish_attack()


func _wave(ppos: Vector2) -> void:
	var a0 := randf() * TAU
	var skip := randi() % PER_WAVE                    # 한 자리는 비워 둔다 (빠져나갈 길)
	for k in PER_WAVE:
		if k == skip:
			continue
		var a := a0 + k * TAU / PER_WAVE + randf_range(-0.2, 0.2)
		var d := randf_range(RING_IN, RING_OUT)
		var p := ppos + Vector2.from_angle(a) * d
		p.x = clampf(p.x, -1150.0, 1150.0)
		p.y = clampf(p.y, -3000.0, -150.0)
		var b: int = randi() % boss.BATTERIES
		marks.append({"pos": p, "t0": t, "from": b, "done": false, "n": k})
		boss.set_battery_glow(b, 1.0)
	boss.emit(Ev.BOLT, boss.battery_pos(0))


func _burst(p: Vector2, n: int) -> void:
	var m: float = boss.bolt_mult()
	var ro := randf() * TAU
	for k in BURST_N:
		var d := Vector2.from_angle(ro + k * TAU / BURST_N)
		if k == 0 and n % 2 == 0:                      # 두 자리에 하나꼴로 금색 주탄 한 발
			boss.shots.spawn(p + d * 20.0, d * MAIN_SPEED * m, LIFE)
		else:
			boss.shots.spawn(p + d * 20.0, d * SPEED * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
	boss.emit(Ev.MINE, p)


func draw() -> void:
	var c: CanvasItem = boss
	for m in marks:
		if m["done"]:
			continue
		var k := clampf((t - float(m["t0"])) / FALL, 0.0, 1.0)
		var p: Vector2 = m["pos"]
		var blink := 0.6 + 0.4 * sin(boss.t * 20.0)
		c.draw_circle(p, BLAST_R * (1.6 - 0.6 * k), Color(1.0, 0.6, 0.25, 0.06 + 0.1 * k))      # 떨어질 자리 (금빛 표적 고리, 좁혀 든다)
		c.draw_arc(p, BLAST_R * (1.6 - 0.6 * k), 0.0, TAU, 32, Color(1.0, 0.8, 0.45, (0.35 + 0.45 * k) * blink), 3.0)
		c.draw_line(p + Vector2(-16, 0), p + Vector2(16, 0), Color(1.0, 0.85, 0.5, 0.5 * k), 2.0)
		c.draw_line(p + Vector2(0, -16), p + Vector2(0, 16), Color(1.0, 0.85, 0.5, 0.5 * k), 2.0)
		var src: Vector2 = boss.battery_pos(int(m["from"]))           # 원근으로 다가오는 포탄: 모함 쪽에서 점점 커지며 내려온다
		var q := src.lerp(p, k * k)
		var sz := lerpf(4.0, 26.0, k * k)
		c.draw_line(src.lerp(p, maxf(0.0, k * k - 0.08)), q, Color(1.0, 0.7, 0.35, 0.35), sz * 0.6)
		c.draw_circle(q, sz, Color(1.0, 0.75, 0.4, 0.9))
		c.draw_circle(q, sz * 0.5, Color(1, 0.95, 0.8))

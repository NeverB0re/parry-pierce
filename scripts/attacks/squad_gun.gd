extends "res://scripts/attacks/attack.gd"
## 탄막 편대 (모함, 금): 플레이어를 노려 쏜다. 차례가 오면 편대가 포위 고리에서 플레이어 쪽으로 다가서고(STAND), 지금 플레이어 자리를 겨눈다.
## 모드 — 편대 패턴 둘 + 편대장 패턴 하나
##   fan      : 셋이 동시에 플레이어 쪽으로 잔탄 부채 (가운데 한 발은 금색 주탄 → 패리 → 리버스 드라이브) × 3
##   stream   : 한 기씩 차례로 플레이어를 따라가며 연사 (세 발마다 금색 주탄)
##   missiles : 편대장만 나서서 금색 유도탄을 두 발씩 두 번 (편대원은 고리를 지킨다)
## boss 에 필요한 것: squad_alive(s), leader_of(s), want_drone(i, pos), drone_pos(i), is_leader(i), set_drone_glow(i, v), aim_drone(i, a), shots, bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.6
const STAND := 540.0                 # 쏘는 동안 플레이어에서 이만큼 (고리보다 가깝게)
const FAN_ROUNDS := 3
const FAN_GAP := 0.65
const FAN_N := 5
const FAN_SPREAD := 0.55
const STREAM_SHOTS := 6
const STREAM_EVERY := 0.11
const STREAM_SLOT := 0.95            # 한 기가 연사하는 차례 길이
const MISSILE_SPEED := 330.0
const MISSILE_STEER := 2.4
const SPEED := 270.0
const MAIN_SPEED := 320.0
const LIFE := 6.0

var squad := 0
var mode := "fan"
var fired := 0                       # 지금까지 쏜 차례 수 (모드마다 뜻이 다르다)


func _init(s: int, m := "fan") -> void:
	kind = "squad_gun"
	phase = "wind"
	squad = s
	mode = m


func _shooters() -> Array:
	if mode == "missiles":
		var l: int = boss.leader_of(squad)
		return [l] if boss.part_alive(l) else []
	return boss.squad_alive(squad)


func step(_dt: float, ppos: Vector2) -> void:
	var ids := _shooters()
	if ids.is_empty():
		boss.finish_attack()
		return
	for i in ids:                                       # 플레이어 쪽으로 다가서서 플레이어를 겨눈다
		var d: Vector2 = (boss.drone_pos(i) - ppos).normalized()
		boss.want_drone(i, ppos + d * STAND)
		boss.aim_drone(i, (ppos - boss.drone_pos(i)).angle())
	match phase:
		"wind":
			for i in ids:
				boss.set_drone_glow(i, minf(1.0, t / WIND))
			if t >= WIND:
				set_phase("fire")
		"fire":
			match mode:
				"fan":
					while fired < FAN_ROUNDS and t >= fired * FAN_GAP:
						for i in ids:
							_fan(i, ppos)
						fired += 1
						boss.emit(Ev.BOLT, ppos)
					if fired >= FAN_ROUNDS and t >= FAN_ROUNDS * FAN_GAP:
						boss.finish_attack()
				"stream":
					var order := ids.duplicate()
					order.reverse()                                   # 편대원 먼저, 편대장 마지막
					var total := order.size() * STREAM_SHOTS
					while fired < total and t >= _stream_time(fired):
						var k := fired / STREAM_SHOTS
						var i: int = order[k]
						_shot(i, ppos, fired % 3 == 2)
						boss.set_drone_glow(i, 1.0)
						fired += 1
					if fired >= total and t >= _stream_time(total - 1) + 0.5:
						boss.finish_attack()
				"missiles":
					while fired < 2 and t >= fired * 0.9:
						var i: int = ids[0]
						var o: Vector2 = boss.drone_pos(i)
						var base := (ppos - o).angle()
						for sd in [-1.0, 1.0]:
							var d := Vector2.from_angle(base + sd * 0.55)
							boss.shots.spawn(o + d * 50.0, d * MISSILE_SPEED * boss.bolt_mult(), LIFE, 0.0, 0.0, Projectiles.Kind.HOMING, 0, 0.0, 0.0, MISSILE_STEER)
						boss.set_drone_glow(i, 1.0)
						boss.emit(Ev.BOLT, o)
						fired += 1
					if fired >= 2 and t >= 1.6:
						boss.finish_attack()


func _stream_time(n: int) -> float:
	return (n / STREAM_SHOTS) * STREAM_SLOT + (n % STREAM_SHOTS) * STREAM_EVERY


## 부채: 지금 플레이어 자리를 가운데로 (편대장은 가운데 한 발이 늘 금색, 편대원은 번갈아)
func _fan(i: int, ppos: Vector2) -> void:
	var o: Vector2 = boss.drone_pos(i)
	var base := (ppos - o).angle()
	var m: float = boss.bolt_mult()
	for k in FAN_N:
		var d := Vector2.from_angle(base - FAN_SPREAD * 0.5 + FAN_SPREAD * k / (FAN_N - 1))
		if k == FAN_N / 2 and (boss.is_leader(i) or fired % 2 == 0):
			boss.shots.spawn(o + d * 50.0, d * MAIN_SPEED * m, LIFE)
		else:
			boss.shots.spawn(o + d * 50.0, d * SPEED * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
	boss.set_drone_glow(i, 1.0)


func _shot(i: int, ppos: Vector2, gold: bool) -> void:
	var o: Vector2 = boss.drone_pos(i)
	var d := (ppos - o).normalized()
	var m: float = boss.bolt_mult()
	if gold:
		boss.shots.spawn(o + d * 50.0, d * MAIN_SPEED * m, LIFE)
	else:
		boss.shots.spawn(o + d * 50.0, d * SPEED * 1.25 * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
	boss.emit(Ev.BOLT, o)

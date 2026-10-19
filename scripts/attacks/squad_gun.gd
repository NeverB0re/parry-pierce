extends "res://scripts/attacks/attack.gd"
## 탄막 편대 (모함, 금 = 패리): 차례가 오면 편대가 플레이어를 가운데 두고 삼각 대형으로 벌려 서서, 셋이 한꺼번에 가운데 쪽으로 잔탄 부채를 몇 차례 쏜다.
## 부채마다 가운데 한 발은 금색 주탄 (패리 → 리버스 드라이브로 드론을 친다). 겨누지 않는다: 대형을 잡을 때의 플레이어 자리(c)로 쏘고, 부채 사이 틈이 빠져나갈 길.
## 차례마다 반 칸씩 어긋나 틈의 자리가 바뀐다. 대형은 천천히 돈다 (멈춰 서 있지 않게).
## boss 에 필요한 것: squad_alive(s), want_drone(i, pos), drone_pos(i), bolt_mult(), shots, set_drone_glow(i, v)

const Projectiles := preload("res://scripts/projectiles.gd")
const FORM := 0.9                    # 대형을 잡는다 (모으며 빛난다)
const ROUNDS := 4
const GAP := 0.75
const FAN_N := 7
const SPREAD := 0.95                 # 부채 폭 (라디안)
const SPEED := 250.0
const MAIN_SPEED := 300.0
const LIFE := 7.0
const R := 600.0                     # 대형 반지름
const SPIN := 0.28                   # 대형 회전 (rad/s)
const OUT := 0.4                     # 다 쏜 뒤 물러나기 전 잠깐

var squad := 0
var c := Vector2.ZERO
var a0 := 0.0
var done := 0


func _init(s: int) -> void:
	kind = "squad_gun"
	phase = "form"
	squad = s


func step(_dt: float, ppos: Vector2) -> void:
	var ids: Array = boss.squad_alive(squad)
	if ids.is_empty():
		boss.finish_attack()
		return
	if phase == "form" and t < FORM * 0.5:            # 대형을 잡는 동안 앞쪽 절반만 플레이어를 따라간다
		c = ppos
		a0 = (boss.squad_center(squad) - ppos).angle()
	var spin := a0 + (SPIN * t if phase == "fire" else 0.0)
	for k in ids.size():
		var a := spin + k * TAU / ids.size()
		boss.want_drone(ids[k], c + Vector2.from_angle(a) * R)
	match phase:
		"form":
			for i in ids:
				boss.set_drone_glow(i, minf(1.0, t / FORM))
			if t >= FORM:
				set_phase("fire")
		"fire":
			while done < ROUNDS and t >= done * GAP:
				_volley(ids)
				done += 1
			if done >= ROUNDS and t >= (ROUNDS - 1) * GAP + OUT:
				boss.finish_attack()


func _volley(ids: Array) -> void:
	var m: float = boss.bolt_mult()
	var off := (0.5 if done % 2 == 1 else 0.0) * SPREAD / (FAN_N - 1)
	for i in ids:
		var o: Vector2 = boss.drone_pos(i)
		var base := (c - o).angle()
		for k in FAN_N:
			var a := base - SPREAD * 0.5 + SPREAD * k / (FAN_N - 1) + off
			var d := Vector2.from_angle(a)
			if k == FAN_N / 2 and (boss.is_leader(i) or done % 2 == 0):   # 가운데 한 발은 금색 주탄 (편대장은 매번, 편대원은 번갈아)
				boss.shots.spawn(o + d * 40.0, d * MAIN_SPEED * m, LIFE)
			else:
				boss.shots.spawn(o + d * 40.0, d * SPEED * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
		boss.set_drone_glow(i, 1.0)
	boss.emit(Ev.BOLT, c)

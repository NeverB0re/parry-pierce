extends "res://scripts/attacks/attack.gd"
## 노드 분사 (결계 위성, 잔탄): 아래쪽에 있는 노드들이 바깥 방향으로 잔탄 부채를 몇 차례 뿌린다 (겨누지 않는다, 차례마다 반 칸 어긋남).
## 잔탄 = 패리하면 흡수만 (리버스 드라이브 없음). 닫힌 동안의 기본 압박
## boss 에 필요한 것: NODES, CORE_POS, node_pos(i), set_glow(i, v), bolt_mult(), shots

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.6
const ROUNDS := 3
const GAP := 0.55
const FAN_N := 5
const SPREAD := 0.9
const SPEED := 250.0

var done := 0


func _init() -> void:
	kind = "spray"


func step(_dt: float, _ppos: Vector2) -> void:
	var ids := _lower_nodes()
	if done == 0:
		for i in ids:
			boss.set_glow(i, minf(1.0, t / WIND))
	while done < ROUNDS and t >= WIND + done * GAP:
		var m: float = boss.bolt_mult()
		var off := (0.5 if done % 2 == 1 else 0.0) * SPREAD / (FAN_N - 1)
		for i in ids:
			var o: Vector2 = boss.node_pos(i)
			var base: float = (o - boss.CORE_POS).angle() - SPREAD * 0.5 + off
			for k in FAN_N:
				var a: float = base + k * SPREAD / (FAN_N - 1)
				boss.shots.spawn(o, Vector2.from_angle(a) * SPEED * m, 8.0, 0.0, 0.0, Projectiles.Kind.SMALL)
			boss.set_glow(i, 1.0)
		boss.emit(Ev.BOLT, boss.CORE_POS)
		done += 1
	if done >= ROUNDS:
		boss.finish_attack()


## 코어보다 아래에 있는 노드들 (위로 쏘면 천장에 닿을 뿐이다)
func _lower_nodes() -> Array[int]:
	var out: Array[int] = []
	for i in boss.NODES:
		if boss.node_pos(i).y > boss.CORE_POS.y + 40.0:
			out.append(i)
	return out

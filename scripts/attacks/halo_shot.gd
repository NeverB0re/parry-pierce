extends "res://scripts/attacks/attack.gd"
## 헤일로 사격 (관측자, 용암 분출 대체): 머리 뒤 헤일로의 렌즈 몇 개가 차례로 금빛으로 달아올라
## 각각 느린 주탄을 한 발씩 플레이어에게 쏜다 (패리 → 리버스 드라이브). 1스테이지라 느리고 띄엄띄엄.
## 렌즈는 부서지지 않는다 (어깨포를 다 부숴도 이 사격은 남는다).
## boss 에 필요한 것: lens_pos(k), LENSES, halo_glow (렌즈별 발광 배열), bolt_mult(), shots

const Projectiles := preload("res://scripts/projectiles.gd")
const SHOTS := 4                     # 쏘는 렌즈 수
const WIND := 0.7                    # 렌즈 하나가 달아오르는 시간
const INTERVAL := 0.45               # 렌즈 사이 간격
const SPEED := 360.0                 # 느린 주탄
const LIFE := 9.0

var lenses: Array[int] = []          # 쏠 렌즈 번호 (헤일로 양옆에서 고른다)
var fired := 0


func _init() -> void:
	kind = "halo"


## 쏠 수 있는 렌즈 = 몸에 가리지 않고(양옆) 경기장 천장 아래에 있는 것. 그중 SHOTS 개를 골라 플레이어 쪽에서 먼 렌즈부터 쏜다
func pick(ppos: Vector2) -> void:
	var up: Array[int] = []
	for k in boss.LENSES:
		var lp: Vector2 = boss.lens_pos(k)
		if absf(lp.x) > 560.0 and lp.y > Projectiles.KILL_TOP + 250.0:
			up.append(k)
	up.shuffle()
	lenses.clear()
	for k in mini(SHOTS, up.size()):
		lenses.append(up[k])
	lenses.sort_custom(func(a, b): return boss.lens_pos(a).distance_to(ppos) > boss.lens_pos(b).distance_to(ppos))


func step(_dt: float, ppos: Vector2) -> void:
	if lenses.is_empty():
		pick(ppos)
	for i in lenses.size():
		var t0 := i * INTERVAL
		var k: int = lenses[i]
		if t >= t0 and i >= fired:
			boss.halo_glow[k] = minf(1.0, (t - t0) / WIND)
		if i == fired and t >= t0 + WIND:
			var o: Vector2 = boss.lens_pos(k)
			boss.shots.spawn(o, (ppos - o).normalized() * SPEED * boss.bolt_mult(), LIFE, Projectiles.WARMUP)
			boss.emit(Ev.BOLT, o)
			boss.halo_glow[k] = 0.0
			fired += 1
	if fired >= lenses.size():
		boss.finish_attack()

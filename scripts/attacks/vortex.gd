extends "res://scripts/attacks/attack.gd"
## 소용돌이 (코어 페이즈 전용): 다시 자라난 촉수 둘이 번갈아 COUNT 번 몸통 내려치기를 한다. 하나하나가 그때의 플레이어 위치를 겨눈다.
## 박자가 빠른 내려치기(hammer.gd, fast)를 INTERVAL 마다 보조 공격으로 띄운다 → 동시에 예고하는 촉수는 최대 2개.
## 모두 끝나면 이 공격도 끝난다.
## boss 에 필요한 것: busy, Hammer

const COUNT := 3
const INTERVAL := 1.1

var pair: Array[int] = []
var fired := 0
var kids: Array = []


func _init(tents: Array) -> void:
	kind = "vortex"
	pair.assign(tents)


func step(_dt: float, _ppos: Vector2) -> void:
	if fired < COUNT and t >= fired * INTERVAL:
		var i: int = pair[fired % pair.size()]
		if boss.busy[i] == null:
			var s = boss.Hammer.new(i, true)
			boss.start_side(s)
			s.claim()
			kids.append(s)
		fired += 1
	if fired >= COUNT:
		for s in kids:
			if boss.lingering.has(s):
				return
		boss.finish_attack()


func melee_warning() -> bool:
	return fired < COUNT

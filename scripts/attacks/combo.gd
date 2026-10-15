extends "res://scripts/attacks/attack.gd"
## 연타 (크라켄): 촉수 공격 여러 개를 차례로 보조 공격으로 띄운다. 소용돌이(내려치기 연타) · 행진(정해진 자리를 차례로 내려침) · 난타(좌우 번갈아 휩쓸기).
## 첫 타만 예고가 느리다(tentacle.gd lead). 첫 타가 내려치거나 요격당한 순간부터 나머지가 INTERVAL 간격으로 이어진다
## → 첫 타를 요격하면 차지 쿨다운 초기화 + 빠른 차지로 나머지도 이어서 요격할 수 있다. 놓치면 피해야 한다.
## makers: 순서대로 부를 Callable (그때 쓸 수 있는 촉수로 공격 모듈을 만들어 돌려준다, 없으면 null). 모두 끝나면 이 공격도 끝난다.

var makers: Array = []
var interval := 1.0
var fired := 0
var first = null                     # 첫 타 모듈
var go_t := -1.0                     # 첫 타가 풀린(내려침·요격) 시각. 그 전에는 다음 타를 띄우지 않는다
var kids: Array = []


func _init(name: String, list: Array, gap: float) -> void:
	kind = name
	makers = list
	interval = gap


func step(_dt: float, _ppos: Vector2) -> void:
	if fired == 0:
		first = _launch(0)
		fired = 1
		if first == null:
			go_t = t
	if go_t < 0.0 and (not first.lead or not boss.lingering.has(first)):
		go_t = t
	while go_t >= 0.0 and fired < makers.size() and t >= go_t + (fired - 1) * interval:
		var a = _launch(fired)
		if a != null:
			a.lead = false
		fired += 1
	if fired >= makers.size():
		for s in kids:
			if boss.lingering.has(s):
				return
		boss.finish_attack()


func _launch(k: int):
	var a = makers[k].call()
	if a == null:
		return null
	boss.start_side(a)
	a.claim()
	kids.append(a)
	return a


func melee_warning() -> bool:
	return fired < makers.size()

extends "res://scripts/attacks/attack.gd"
## 연타 (크라켄): 촉수 여러 개가 처음부터 한꺼번에 올라와 예고하고, 정해진 순서대로 하나씩 내려친다.
## 소용돌이(내려치기, 대기 중에도 플레이어를 겨눔) · 행진(정해진 자리를 먼 쪽부터) · 난타(좌우 번갈아 휩쓸기).
## 다음에 올 타만 또렷하게(빗금) 예고하고, 기다리는 타는 윤곽 + 순번 점만 보인다 (겹쳐도 무엇이 먼저인지 보인다).
## 각 타는 앞 타가 내려치거나 요격·끊긴 뒤 INTERVAL 만큼 더 기다렸다가 마지막 예고(set → warn)를 이어 간다.
## 첫 타만 예고가 느리다(tentacle.gd lead). 대기 중인 타도 요격할 수 있다.
## makers: 순서대로 부를 Callable (각자 다른 촉수로 공격 모듈을 만들어 돌려준다, 없으면 null). 모두 끝나면 이 공격도 끝난다.

var makers: Array = []
var interval := 0.15
var started := false
var kids: Array = []


func _init(name: String, list: Array, gap: float) -> void:
	kind = name
	makers = list
	interval = gap


func step(_dt: float, _ppos: Vector2) -> void:
	if not started:
		started = true
		var prev = null
		for mk in makers:
			var a = mk.call()
			if a == null:
				continue
			a.order = kids.size()
			if prev != null:
				a.after = prev
				a.after_gap = interval
				a.lead = false
			boss.start_side(a)
			a.claim()
			kids.append(a)
			prev = a
	for s in kids:
		if boss.lingering.has(s):
			return
	boss.finish_attack()


func melee_warning() -> bool:
	for s in kids:
		if boss.lingering.has(s) and s.melee_warning():
			return true
	return not started

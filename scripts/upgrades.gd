extends RefCounted
## 동력 코어 (docs/PLAN_upgrade.md): 콜로서스를 처음 처리할 때마다 그 동력 코어를 얻고, 얻은 코어는 모두 영구히 켜진다 (장착·교체 없음).
## 효과 = {수치 이름(player_stats.gd): ["set", 값] 또는 ["mul", 배율]}. 기본 수치에 얻은 순서대로 적용한다.

const CORES := {
	"counter": {"name": "반격 코어", "from": "observer",
		"desc": "패리한 탄(잔탄 흡수 포함)이 사라지지 않고 표적으로 되돌아가 피해를 준다",
		"mods": {"counter": ["set", true]}},
	"reflect": {"name": "반사 코어", "from": "fortress",
		"desc": "리버스 드라이브로 돌진하는 동안, 몸 둘레의 탄을 표적으로 되돌린다",
		"mods": {"reflect": ["set", true]}},
	"assault": {"name": "강습 코어", "from": "kraken",
		"desc": "요격을 연달아 성공할수록 요격 피해가 커진다. 맞으면 끊긴다 (기체 둘레의 주황 불씨 = 연쇄 단계)",
		"mods": {"assault": ["set", true]}},
}


## 기본 수치(base)에 얻은 코어를 모두 적용한 새 수치
static func build(base: Resource, cores: Array) -> Resource:
	var st: Resource = base.duplicate()
	for id in cores:
		if CORES.has(id):
			_apply(st, CORES[id]["mods"])
	return st


static func _apply(st: Resource, mods: Dictionary) -> void:
	for key in mods:
		var op: Array = mods[key]
		match op[0]:
			"set":
				st.set(key, op[1])
			"mul":
				st.set(key, st.get(key) * op[1])

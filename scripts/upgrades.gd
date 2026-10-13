extends RefCounted
## 동력 코어 (docs/PLAN_upgrade.md): 콜로서스를 처음 처리할 때마다 그 동력 코어를 얻고, 얻은 코어는 모두 영구히 켜진다 (장착·교체 없음).
## 효과 = {수치 이름(player_stats.gd): ["set", 값] 또는 ["mul", 배율]}. 기본 수치에 얻은 순서대로 적용한다.

const CORES := {
	"counter": {"name": "반격 코어", "from": "observer",
		"desc": "패리한 탄(잔탄 흡수 포함)이 사라지지 않고 지금 표적으로 빠르게 되돌아간다. 탄 하나당 피해 1, 유도탄은 3",
		"mods": {"counter": ["set", true]}},
	"reflect": {"name": "반사 코어", "from": "fortress",
		"desc": "리버스 드라이브로 돌진하는 동안만 기체 둘레 70px 안에 닿은 탄을 표적으로 되돌린다 (적중해 튕겨나면 끝). 탄 하나당 피해 1, 유도탄은 3",
		"mods": {"reflect": ["set", true]}},
	"assault": {"name": "강습 코어", "from": "kraken",
		"desc": "요격(차지 강습·리버스 드라이브로 근접공격에 부딪힘)에 성공하면 차지 쿨다운이 사라지고, 다음 차지가 모으는 시간 없이 바로 완료된다 (기체 둘레의 주황 불씨)",
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

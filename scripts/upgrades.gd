extends RefCounted
## 동력 코어 (docs/PLAN_upgrade.md): 콜로서스를 처음 처리할 때마다 그 동력 코어를 얻는다. 작동하는 것은 장착한 코어뿐 (장착 칸 1개, 5스테이지를 깨면 2개, profile.gd).
## color = 장착 화면의 코어 아이콘 색 (모양은 모두 관측자의 하트 컷 보석, core_icon.gd).
## 효과 = {수치 이름(player_stats.gd): ["set", 값] 또는 ["mul", 배율]}. 기본 수치에 얻은 순서대로 적용한다.

const CORES := {
	"counter": {"name": "반격 코어", "from": "observer", "color": Color(0.95, 0.22, 0.3),
		"desc": "패리한 탄(잔탄 흡수 포함)이 사라지지 않고 표적으로 되돌아가 피해를 준다",
		"mods": {"counter": ["set", true]}},
	"reflect": {"name": "반사 코어", "from": "fortress", "color": Color(1.0, 0.62, 0.18),
		"desc": "리버스 드라이브로 돌진하는 동안, 몸 둘레의 탄을 표적으로 되돌린다",
		"mods": {"reflect": ["set", true]}},
	"assault": {"name": "강습 코어", "from": "kraken", "color": Color(0.25, 0.9, 0.55),
		"desc": "요격을 연달아 성공할수록 요격 피해가 커진다. 맞으면 끊긴다 (기체 둘레의 주황 불씨 = 연쇄 단계)",
		"mods": {"assault": ["set", true]}},
	"sync": {"name": "동조 코어", "from": "satellite", "color": Color(0.35, 0.7, 1.0),
		"desc": "퍼펙트 회피에 성공하면 기체 둘레의 적 탄이 사라진다",
		"mods": {"sync_clear": ["set", true]}},
}


## 기본 수치(base)에 장착한 코어를 적용한 새 수치
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

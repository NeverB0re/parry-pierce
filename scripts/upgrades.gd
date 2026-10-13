extends RefCounted
## 업그레이드 정의 (docs/PLAN_upgrade.md):
##  - 부산물 노드 트리 3개 × 5노드. 보스를 처음 처리할 때마다 1포인트, 선행 노드만 충족하면 자유롭게 찍는다. 영구.
##  - 코어 아이템: 보스마다 하나, 한 번에 하나만 장착. 버프만 있다.
## 효과 = {수치 이름(player_stats.gd): ["set", 값] 또는 ["mul", 배율]}. 기본 수치에 노드 → 코어 순서로 적용한다.

const TREES := [
	{"id": "judge", "name": "판정 완화", "nodes": ["A1", "A2", "A3", "A4", "A5"]},
	{"id": "power", "name": "스텟 증가", "nodes": ["P1", "P2", "P3", "P4", "P5"]},
	{"id": "util", "name": "유틸리티", "nodes": ["U1", "U2", "U3", "U4", "U5"]},
]

const NODES := {
	"A1": {"name": "패리 유지", "desc": "패리 판정 유지 0.2초 → 0.25초", "req": [],
		"mods": {"parry_hold_max": ["set", 0.25]}},
	"A2": {"name": "조준 유예", "desc": "리버스 드라이브 조준 유예 1.4초 → 1.8초 (PERFECT 1.9 → 2.3)", "req": [],
		"mods": {"aim_time": ["set", 1.8], "aim_time_perfect": ["set", 2.3]}},
	"A3": {"name": "회피 판정", "desc": "퍼펙트 회피 판정 0.12초 → 0.16초", "req": ["A1"],
		"mods": {"perfect_evade_window": ["set", 0.16]}},
	"A4": {"name": "조준 보조", "desc": "조준 보조 범위 +30%", "req": ["A2"],
		"mods": {"assist_cone": ["mul", 1.3], "assist_cone_touch": ["mul", 1.3]}},
	"A5": {"name": "반응 회로", "desc": "입력 기억 시간 증가 (돌진 0.2 → 0.3초, 패리 0.15 → 0.25초), 제어 불능 0.9 → 0.7초", "req": ["A3", "A4"],
		"mods": {"dash_buffer": ["set", 0.3], "parry_buffer": ["set", 0.25], "stun_time": ["set", 0.7]}},
	"P1": {"name": "실드 증설", "desc": "실드 셀 +1 (3 → 4)", "req": [],
		"mods": {"shield_cells": ["set", 4]}},
	"P2": {"name": "강습 탄두", "desc": "차지 강습 피해 3 → 4", "req": [],
		"mods": {"charge_damage": ["set", 4]}},
	"P3": {"name": "요격 장갑", "desc": "요격 피해 8 → 11", "req": ["P2"],
		"mods": {"clash_damage": ["set", 11]}},
	"P4": {"name": "역추진 증폭", "desc": "리버스 드라이브 피해 12 → 14 (PERFECT 16 → 19)", "req": ["P1"],
		"mods": {"power_damage": ["set", 14], "power_damage_perfect": ["set", 19]}},
	"P5": {"name": "동조 증폭", "desc": "동조 배율 ×2 → ×3 (완전 동조 ×4 → ×5)", "req": ["P3", "P4"],
		"mods": {"evade_buff_mult": ["set", 3], "evade_buff_mult_strong": ["set", 5]}},
	"U1": {"name": "냉각 계통", "desc": "돌진 쿨다운 0.7초 → 0.6초", "req": [],
		"mods": {"dash_cooldown": ["set", 0.6]}},
	"U2": {"name": "축전 회로", "desc": "차지 시간 0.6초 → 0.5초", "req": [],
		"mods": {"charge_time": ["set", 0.5]}},
	"U3": {"name": "반동 추진", "desc": "적중 후 솟구침 높이 +15%", "req": ["U1"],
		"mods": {"bounce_up": ["mul", 1.15]}},
	"U4": {"name": "실드 재충전", "desc": "퍼펙트 회피 성공 시 실드 셀 1 회복 (출격당 1회)", "req": ["U2"],
		"mods": {"evade_heal": ["set", true]}},
	"U5": {"name": "역추진 순환", "desc": "리버스 드라이브 직후 무적 0.7초 → 1.1초, 끝나면 돌진 쿨다운 즉시 초기화", "req": ["U3", "U4"],
		"mods": {"power_grace": ["set", 1.1], "power_cd_reset": ["set", true]}},
}

const CORES := {
	"mobility": {"name": "기동 코어", "from": "observer", "style": "기동·돌진",
		"desc": "돌진 거리 +25%, 활공 중 낙하 속도 감소 (140 → 90)",
		"mods": {"dash_time": ["mul", 1.25], "glide_fall": ["set", 90.0]}},
}


## 기본 수치(base)에 찍은 노드와 장착 코어를 적용한 새 수치
static func build(base: Resource, nodes: Array, core: String) -> Resource:
	var st: Resource = base.duplicate()
	for id in nodes:
		if NODES.has(id):
			_apply(st, NODES[id]["mods"])
	if CORES.has(core):
		_apply(st, CORES[core]["mods"])
	return st


static func _apply(st: Resource, mods: Dictionary) -> void:
	for key in mods:
		var op: Array = mods[key]
		match op[0]:
			"set":
				st.set(key, op[1])
			"mul":
				st.set(key, st.get(key) * op[1])


## 노드를 찍을 수 있는가: 아직 안 찍었고, 선행 노드를 모두 찍었고, 포인트가 남았다
static func can_take(id: String, nodes: Array, points_left: int) -> bool:
	if not NODES.has(id) or nodes.has(id) or points_left <= 0:
		return false
	return requirements_met(id, nodes)


static func requirements_met(id: String, nodes: Array) -> bool:
	for r in NODES[id]["req"]:
		if not nodes.has(r):
			return false
	return true

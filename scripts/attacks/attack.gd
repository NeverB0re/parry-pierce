extends RefCounted
## 공격 모듈 하나 = 예고 → 판정 → 회복 상태 머신. 콜로서스는 한 번에 하나를 들고(atk) 매 프레임 진행한다.
## 콜로서스는 t 를 올린 뒤 step 을 부른다. 단계(phase)가 바뀌면 모듈이 t 를 0 으로 되돌린다.
## 끝나면 boss.finish_attack() 을 부른다.

const Ev := preload("res://scripts/ev.gd")

var boss                     # 이 공격을 쓰는 콜로서스 (start_attack 이 채운다)
var kind := ""               # 공격 이름 (튜토리얼·디버그·HUD 가 읽는다)
var phase := ""              # 현재 단계 (모듈마다 다름. 단계가 하나뿐이면 "")
var t := 0.0                 # 현재 단계에서 흐른 시간
var dodged := false          # 회피한 공격: 그 뒤로는 맞지 않는다. 탄·근접 = 회피 무적(일반 돌진·퍼펙트 회피)으로 통과, 보라(패리 불가) = 퍼펙트 회피로 에너지를 빨아들임 → 사라진다
var part := -2               # 이 공격이 쓰는 외부 시스템 번호. 그 부위가 부서지면 공격이 끊긴다 (-2 = 없음)


var cut_done := false                 # (크라켄) 이 패턴에서 이미 촉수 하나가 끊겼다 — 한 패턴에 하나까지
var hit_mods: Array = []              # (크라켄) 이 패턴에서 요격당한 모듈들 (연타를 다 요격했는지)

func step(_dt: float, _ppos: Vector2) -> void:
	pass


## 예고·이펙트 그리기 (boss 의 그리기 함수로)
func draw() -> void:
	pass


## 지금 활성인 공격 판정을 out 에 넣는다
func hitboxes(_ppos: Vector2, _out: Array[Dictionary]) -> void:
	pass


## 차지 강습으로 요격할 수 있는 판정 ({} = 없음)
func clash_box(_ppos: Vector2) -> Dictionary:
	return {}


## 에임 어시스트 임시 표적 ({pos, r, intercept}) — 요격할 수 있는 공격이 쓴다 (from = 플레이어 위치).
## intercept = true 인 표적은 차지·조준 중 어시스트가 다른 표적보다 먼저 잡는다
func assist_targets(_from: Vector2, _out: Array[Dictionary]) -> void:
	pass


## 패리 불가 공격이 플레이어에게 다가오는 지점 (화면 밖이면 HUD 가 보라 ⚠ + 화살표). 없으면 Vector2.INF
func unparry_point(_ppos: Vector2) -> Vector2:
	return Vector2.INF


## 근접공격을 예고하는 중인가 (HUD 경고 띠). 근접공격 모듈은 true 를 돌려 주고, 예고 그림은 melee_warn.gd 로 그린다
func melee_warning() -> bool:
	return false


## 패리 불가 판정 → 밀려날 방향 (안 맞으면 ZERO)
func beam_hit(_p: Vector2, _r: float) -> Vector2:
	return Vector2.ZERO


## 이 보라 줄기의 두께 (판정 폭, px). 0 = 가는 심줄
func strand_width() -> float:
	return 0.0


## 퍼펙트 회피로 흡수(완전 동조)할 수 있는 줄기인가: 돌진 한 번의 무적으로 건널 수 없는 두께(EVADE_CROSS_MAX 초과)는 안 된다 (v0.129 규칙)
const EVADE_CROSS_MAX := 200.0


func absorbable() -> bool:
	return strand_width() <= EVADE_CROSS_MAX


## 회피했다 (p 에 닿은 판정). 기본 = 공격 전체가 더는 맞지 않는다. 여러 줄기 공격은 닿은 줄기만 (rings·radial_burst·lattice)
func mark_dodged(_p: Vector2, _r: float) -> void:
	dodged = true


func on_parried(_hb: Dictionary) -> void:
	pass


func release_stagger() -> void:
	pass


func set_phase(p: String) -> void:
	phase = p
	t = 0.0

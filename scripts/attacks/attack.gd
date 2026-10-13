extends RefCounted
## 공격 모듈 하나 = 예고 → 판정 → 회복 상태 머신. 콜로서스는 한 번에 하나를 들고(atk) 매 프레임 진행한다.
## 콜로서스는 t 를 올린 뒤 step 을 부른다. 단계(phase)가 바뀌면 모듈이 t 를 0 으로 되돌린다.
## 끝나면 boss.finish_attack() 을 부른다.

const Ev := preload("res://scripts/ev.gd")

var boss                     # 이 공격을 쓰는 콜로서스 (start_attack 이 채운다)
var kind := ""               # 공격 이름 (튜토리얼·디버그·HUD 가 읽는다)
var phase := ""              # 현재 단계 (모듈마다 다름. 단계가 하나뿐이면 "")
var t := 0.0                 # 현재 단계에서 흐른 시간
var part := -2               # 이 공격이 쓰는 외부 시스템 번호. 그 부위가 부서지면 공격이 끊긴다 (-2 = 없음)


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


## 에임 어시스트 임시 표적 ({pos, r}) — 요격할 수 있는 공격이 쓴다 (from = 플레이어 위치)
func assist_targets(_from: Vector2, _out: Array[Dictionary]) -> void:
	pass


## 근접공격을 예고하는 중인가 (HUD 경고 띠). 근접공격 모듈은 true 를 돌려 주고, 예고 그림은 melee_warn.gd 로 그린다
func melee_warning() -> bool:
	return false


## 패리 불가 판정 → 밀려날 방향 (안 맞으면 ZERO)
func beam_hit(_p: Vector2, _r: float) -> Vector2:
	return Vector2.ZERO


func on_parried(_hb: Dictionary) -> void:
	pass


func release_stagger() -> void:
	pass


func set_phase(p: String) -> void:
	phase = p
	t = 0.0

extends Node2D
## 플레이어: 작은 로켓. 머리는 평소 마우스 방향, 노즐 화염 길이가 추진 상태(활공/낙하)를 보여준다.
## 시뮬레이션은 main.gd 가 step() 으로 직접 호출한다(히트스톱/슬로모션 제어 때문).

const Sprites := preload("res://scripts/sprites.gd")
const HexShield := preload("res://scripts/hex_shield.gd")
const PlayerStats := preload("res://scripts/player_stats.gd")
const BASE_STATS := preload("res://data/player_stats.tres")

# ── 튜닝값 ─────────────────────────────────────────────
const RADIUS := 12.0
const GRAVITY := 900.0
const BASE_FALL := 480.0         # 마우스가 수평일 때 낙하 속도 상한
const DIVE_FALL := 1000.0        # 마우스를 아래로: 빨리 떨어진다
const THRUST := 560.0            # 약한 무한 추진(좌우/하강)
const AIR_DRAG := 0.9
const PLATFORM_SPEED := 260.0
const DASH_SPEED := 2000.0       # 돌진: 무적 + 표적에 닿으면 피해 1. 사거리 약 560px. 자원 없이 쿨다운만
const DASH_KEEP := 0.5           # 돌진이 끝난 뒤 남기는 속도 비율 (위쪽 관성은 남기지 않는다)
const DASH_DAMAGE := 1
const CHARGE_HOVER := 0.15       # 이 시간 이상 누르면 차지 자세(공중 정지)로 들어간다
const CHARGE_AUTO := 0.9         # 차지 완료 후 이 시간이 지나면 자동 발사 (v0.44: 1.3 → 0.9)
const CHARGE_SPEED := 3600.0     # 차지 돌진: 빠르게 꽂힌다. 사거리 약 790px
const CHARGE_DASH_TIME := 0.22
const CHARGE_GRACE := 0.5        # 차지 돌진이 빗나가 끝난 직후 무적
const PERFECT_EVADE_GRAZE := 16.0   # 퍼펙트 회피로 인정하는 근접 여유 (몸 반지름에 더함)
const PERFECT_EVADE_INVULN := 0.8   # 퍼펙트 회피 성공 시 추가 무적 (회피 직후 다른 곳에 맞는 일 방지)
const PARRY_PUSH := 1100.0          # 휩쓰는 팔을 그냥 패리하면: 피해 없이 반대쪽으로 튕겨나기만 한다
const PARRY_PUSH_SHIELD := 0.5
const PERFECT_WINDOW := 0.07     # 패리 누른 뒤 이 시간 안에 막으면 PERFECT
const PARRY_MIN := 0.12          # 짧게 눌러도 이 시간만큼은 패리 유지
const PARRY_COOLDOWN := 0.55     # 끝까지 버틴 뒤 재입력 대기 (남발 방지)
const PARRY_RELEASE_CD := 0.25   # 중간에 뗐을 때 재입력 대기
const PARRY_DASH_SPEED := 3600.0 # 패리 돌진: 주력 공격. 월드가 느려져도 플레이어는 실시간
const PARRY_DASH_SPEED_PERFECT := 4000.0
const PARRY_DASH_TIME := 0.22
const DASH_PARRY_RANGE := 1.35  # 돌진패리 뒤 리버스 드라이브의 사거리 배율
const REFLECT_RADIUS := 70.0     # 반사 범위 (기체보다 넓게)
const POWER_RADIUS := 8.0        # 패리 돌진은 타격 범위도 넓다
# 직격 후: v0.6 방식 — 위로 솟구치고, 들어온 반대쪽으로 약간 밀리며, 마우스 좌우로 조종한다
const BOUNCE_SIDE := 250.0       # 들어온 방향의 반대쪽으로 밀리는 가로 속도
const BOUNCE_STEER := 750.0      # 튕길 때 마우스 좌우 방향으로 더하는 가로 속도 (좌우 조종)
const ASSIST_SLACK := 60.0           # 사거리 여유
const BOUNCE_THRUST := 2.0       # 튕겨나는 동안 좌우 추진 배율
const STRIKE_SHIELD := 0.9       # 직격 후 튕겨나는 동안 무적 (최대). 튕김이 끝나 기체 통제를 되찾으면 바로 끝난다
const BOUNCE_END := 0.25         # 솟구치는 속도가 처음의 이 비율 아래로 떨어지면 튕김 끝 = 통제 회복 (v0.37: 0.4 → 0.25, 무적이 조금 더 길다)
const PRESS_PIN_SPEED := 2300.0  # 프레스(천장 근접공격)를 패리하면 이 속도로 아래로 내리꽂힌다
const PRESS_PIN_TIME := 1.0
const STUN_INVULN := 0.4         # 스턴이 끝난 뒤 추가 무적
const DASH_PARRY_GRACE := 0.12   # 돌진패리: 일반 돌진이 끝난 직후에도 이만큼은 돌진 중으로 친다
const CORE_REBOUND := 0.45       # 코어 안쪽으로 튕길 뻔한 속도를 바깥으로 이 비율만큼 되튕긴다
const CORE_REBOUND_SHIELD := 0.5 # 그때의 튕김 무적
const STRIKE_PASS := 0.25         # 적중 직후 이 시간 안에 시작한 일반 돌진은, 방금 맞힌 표적의 원 안쪽에서만 충돌하지 않는다 (적 안에서 빠져나오는 돌진이 멈추지 않게)
const SMALL_GUARD := 0.25        # 일반 돌진이 끝난 직후 이 시간 동안 잔탄에 맞지 않는다 (옅은 실드)
const HEAT_RING_R := 64.0        # 잔탄 체력 링 (초기 빌드의 외부 시스템 원형 체력바 모양): 돌진 쿨다운 링 바깥
const HEAT_RING_HOLD := 1.0      # 다 회복된 뒤 이만큼 보였다가
const HEAT_RING_FADE := 0.4      # 이만큼에 걸쳐 사라진다
const HEAT_RING_BREAK := 0.7     # 셋째 피격으로 셀이 깨질 때 빈 링이 붉게 깜빡이는 시간
const HURT_PUSH := 500.0
const HURT_POP := 380.0          # 맞으면 살짝 솟구친다
const LAUNCH_SPEED := 1850.0     # 발판에서의 첫 돌진 = 발사. 정점 약 y -2400 (어깨 높이)
const LAUNCH_FLOAT := 0.25       # 발사 직후 중력 없음
const LAUNCH_STEER := 0.25       # 발사 방향에 마우스 좌우가 반영되는 정도
const ROT_SPEED := 12.0          # 머리가 마우스를 따라 도는 빠르기
const AIM_DEADZONE := 40.0       # 마우스가 기체에 이만큼 가까우면 방향 유지 (떨림 방지)
const WALL_L := -1150.0
const WALL_R := 1150.0
const CEILING := -3080.0         # 보이는 천장 아랫면 (뿔 끝 -3030 바로 위)
const PLAT_CENTER := Vector2(650, -40)   # 시작 발판 윗면 중앙
const PLAT_HALF := 90.0

const C_BODY := Color(0.93, 0.94, 0.96)
const C_TRIM := Color(0.45, 0.8, 1.0)
const C_EVADE := Color(0.6, 0.85, 1.0)
const C_ATTACK := Color(1.0, 0.55, 0.2)

var main: Node
var boss: Node
var stats: PlayerStats = BASE_STATS.duplicate()   # 업그레이드가 바꿀 수 있는 수치 (scripts/player_stats.gd). 기본값의 복사본

var vel := Vector2.ZERO
var on_platform := false
var dash_t := 0.0
var dash_kind := ""              # "dash" | "charge" | "power"
var dash_total := 0.28
var perfect_dash := false        # PERFECT 패리 돌진
var evade_window := 0.0          # 퍼펙트 회피 판정이 남은 시간
var evade_rewarded := false      # 이번 돌진에서 이미 퍼펙트 회피 보상을 받음
var evade_invuln := 0.0          # 이번 퍼펙트 회피로 얻은 추가 무적 길이 (돌진 중 다른 공격에 닿을 때마다 이 길이로 되돌린다)
var assist_lock := false          # 에임 어시스트가 표적에 붙어 있음
var assist_pos := Vector2.ZERO   # 붙은 표적 위치
var assist_r := 0.0
var dash_held := false           # 좌클릭을 누르고 있는 중 (스턴 중 선입력 판단용)
var buffed := false              # 퍼펙트 회피 버프: 다음 차지 공격 피해 2배, 차지 시간 절반
var buff_strong := false         # 패리 불가 공격을 퍼펙트 회피해 얻은 강한 버프 (4배)
var buff_t := 0.0                # 동조 남은 시간
var last_hit_strong := false     # 방금 일격이 강한 버프를 소모했는가 (main.gd 가 이펙트에 사용)
var queued_press := false        # 스턴 중 누른 좌클릭: 회복하면 차지 시작
var pending_kind := ""           # 쿨다운 중에 뗀 돌진: 쿨다운이 끝나는 즉시 나간다
var parry_queue := 0.0           # 패리 쿨다운 중 누른 입력 기억
var charging := false            # 좌클릭 누르는 중 (짧게 떼면 돌진, 다 모으면 차지 돌진)
var charge_t := 0.0
var charged_notified := false
var dash_cd := 0.0
var charge_cd := 0.0             # 차지 강습 후 다음 차지가 완료될 수 있을 때까지
var quick_charge := false        # 강습 코어: 요격에 성공했다 → 다음 차지는 모으는 시간 없이 바로 완료
var heat_vis := 0.0              # 잔탄 체력 링이 보이는 남은 시간 (과열 중엔 계속 가득)
var heat_cells := 3              # 링에 그리는 남은 칸 (바뀌는 순간을 알아 번쩍임을 준다)
var heat_flash := 0.0            # 칸이 깎이거나 돌아온 순간의 번쩍임
var heat_flash_k := 0            # 번쩍이는 칸
var heat_break := 0.0            # 셀이 깨진 직후: 빈 링이 붉게 깜빡인다
var parry_active := false
var parry_held := false
var parry_t := 0.0
var parry_cd := 0.0
var aim_phase := false           # 패리 성공 → 슬로우 → 방향 지정
var aim_left := 0.0
var aim_perfect := false
var aim_boost := false           # 돌진패리 성공 → 이어지는 리버스 드라이브의 사거리가 늘어난다
var power_boost := false         # 지금 리버스 드라이브가 사거리 증가 상태
var invuln := 0.0                # 피격 후 무적
var bouncing := false            # 직격 후 튕겨나는 중
var bounce_rise := 0.0           # 직격 튕김의 처음 솟구치는 속도 (0 = 직격 튕김 아님). 통제 회복 판정용
var parry_hit := false           # 이번 패리 판정에서 무언가를 막았다 → 판정이 끝나도 패리 쿨다운 없음
var shield_t := 0.0              # 돌진/직격 후 무적
var small_guard := 0.0           # 일반 돌진이 끝난 직후: 잔탄만 맞지 않는 시간
var strike_pass_t := 0.0         # 적중 직후 남은 시간: 이때 시작한 일반 돌진은 맞힌 표적의 원 안쪽을 통과한다
var pass_target := {}            # 방금 맞힌 표적 {kind, idx}
var dash_pass := false           # 지금 돌진이 그 표적의 원 안쪽을 빠져나오는 중 (원을 벗어나면 꺼진다)
var dash_parry_t := 0.0          # 일반 돌진이 끝난 뒤 돌진패리가 아직 인정되는 시간
var shield_max := 1.0
var stun := 0.0
var launch_t := 0.0
var aim := Vector2.UP
var facing := -PI * 0.5
var trail: Array[Vector2] = []
var parry_flash := 0.0
var frozen := false              # 승리/용암 연출 중 정지
var bank := 0.0                  # 기체 좌우 기울임 (회전 중 -1..1)
var _ship_col := "b"             # 그릴 기체 색: 청(평소) / 적(차지·패리 돌진 중)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # 도트가 번지지 않게


func reset(pos: Vector2, platform := false) -> void:
	position = pos
	vel = Vector2.ZERO
	on_platform = platform
	dash_t = 0.0
	dash_kind = ""
	perfect_dash = false
	charging = false
	charge_t = 0.0
	bouncing = false
	dash_cd = 0.0
	bounce_rise = 0.0
	parry_hit = false
	charge_cd = 0.0
	quick_charge = false
	heat_vis = 0.0
	heat_cells = 3
	heat_flash = 0.0
	heat_break = 0.0
	small_guard = 0.0
	strike_pass_t = 0.0
	pass_target = {}
	dash_pass = false
	dash_parry_t = 0.0
	evade_window = 0.0
	evade_rewarded = false
	dash_held = false
	buffed = false
	buff_strong = false
	buff_t = 0.0
	queued_press = false
	pending_kind = ""
	parry_queue = 0.0
	parry_active = false
	parry_held = false
	parry_cd = 0.0
	aim_phase = false
	aim_boost = false
	power_boost = false
	invuln = 0.0
	shield_t = 0.0
	stun = 0.0
	launch_t = 0.0
	aim = Vector2.UP
	facing = -PI * 0.5
	frozen = false
	visible = true
	bank = 0.0
	trail.clear()
	queue_redraw()


## 근접공격(팔·프레스)은 회피 불가: 일반 돌진의 무적으로는 통과할 수 없다 (리버스 드라이브·차지 강습·피격 후 무적 등은 그대로)
func is_immune_melee() -> bool:
	return frozen or aim_phase or shield_t > 0.0 or invuln > 0.0 or launch_t > 0.0 or (dash_t > 0.0 and dash_kind != "dash")


func is_immune() -> bool:
	return frozen or aim_phase or dash_t > 0.0 or shield_t > 0.0 or invuln > 0.0 or launch_t > 0.0


## 모든 돌진은 표적에 닿으면 타격한다 (일반 돌진도 피해 1)
func is_attacking() -> bool:
	return dash_t > 0.0 and dash_kind != ""


## 반사 코어가 지금 탄을 되돌리는 중인가
func is_reflecting() -> bool:
	return stats.reflect and dash_kind == "power" and dash_t > 0.0


## 카메라용: 차지가 절반 넘게 모였을 때부터 0 → 1 (짧게 누르는 연속 돌진에는 카메라가 움직이지 않게)
func charge_view() -> float:
	if not charging:
		return 0.0
	var need := charge_need()
	return clampf((charge_t - need * 0.5) / (need * 0.5), 0.0, 1.0)


## 차지 완료에 필요한 시간 (퍼펙트 회피 버프가 있으면 절반)
func charge_need() -> float:
	return stats.charge_time * (0.5 if buffed else 1.0)


func is_charged() -> bool:
	return charging and charge_t >= charge_need()


func is_hovering_charge() -> bool:
	return charging and charge_t >= CHARGE_HOVER


func can_dash() -> bool:
	return not (frozen or aim_phase or stun > 0.0 or dash_cd > 0.0 or dash_t > 0.0)


## 좌클릭 누름: 발판 위면 발사, 아니면 모으기 시작 (짧게 떼면 돌진, 다 모아 떼면 차지 돌진)
func press_dash() -> void:
	dash_held = true
	if frozen or aim_phase:
		return
	if on_platform and stun <= 0.0:
		_launch()
		return
	if stun > 0.0:
		queued_press = true             # 추락(스턴) 중 선입력: 회복하자마자 모으기 시작
		return
	pending_kind = ""
	charging = true
	charge_t = charge_need() if quick_charge else 0.0
	charged_notified = false


## 좌클릭 뗌: 다 모았으면 차지 돌진, 아니면 일반 돌진 (모은 시간이 버려지지 않는다)
func release_dash() -> void:
	dash_held = false
	queued_press = false
	if not charging:
		return
	var kind := "charge" if is_charged() else "dash"
	charging = false
	_fire(kind)


## 쿨다운 중이면 기억했다가 끝나는 즉시 (짧은 돌진은 거의 끝났을 때만 기억)
func _fire(kind: String) -> void:
	if can_dash():
		_dash(kind)
	elif kind == "charge" or (dash_cd <= stats.dash_buffer and dash_t <= 0.0):
		pending_kind = kind


## 차지 취소(피격/패리 전환)
func cancel_charge() -> void:
	charging = false
	pending_kind = ""


func _dash(kind: String) -> void:
	dash_kind = kind
	pending_kind = ""
	dash_pass = kind == "dash" and strike_pass_t > 0.0 and not pass_target.is_empty()
	var spd := DASH_SPEED
	dash_total = stats.dash_time
	if kind == "charge":
		spd = CHARGE_SPEED
		dash_total = CHARGE_DASH_TIME
	dash_t = dash_total
	dash_cd = stats.dash_cooldown
	if kind == "charge":
		charge_cd = stats.charge_cooldown
		quick_charge = false
	evade_window = stats.perfect_evade_window if kind == "dash" else 0.0
	evade_rewarded = false
	vel = aim * spd
	bouncing = false
	if bounce_rise > 0.0:                    # 직격 튕김 중 돌진: 튕김 무적은 여기서 끝 (돌진 자체가 무적)
		bounce_rise = 0.0
		shield_t = 0.0
	main.on_dash(position, aim, kind)


func _launch() -> void:
	on_platform = false
	launch_t = LAUNCH_FLOAT
	vel = Vector2(aim.x * LAUNCH_STEER, -1.0).normalized() * LAUNCH_SPEED
	main.on_launch(position)


## 우클릭/Space 누름: 패리 판정 (모으던 차지는 취소)
func parry_press() -> void:
	parry_held = true
	queued_press = false
	if frozen or aim_phase or parry_active or stun > 0.0:
		return
	if parry_cd > 0.0:
		parry_queue = stats.parry_buffer            # 쿨다운이 곧 끝나면 그때 발동
		return
	parry_active = true
	parry_hit = false
	parry_t = 0.0


func parry_release() -> void:
	parry_held = false


func parry_reach() -> float:
	return RADIUS + (stats.parry_reach if parry_active else 0.0)


## 탄 패리 성공: 시간이 느려지고 방향을 정한다 → 패리 돌진
## 돌진패리: 스스로 돌진해(일반 돌진·차지 강습, 끝난 직후 잠깐 포함) 탄막으로 다가가며 하는 패리. 성공하면 타이밍과 상관없이 PERFECT 패리.
## (리버스 드라이브 중에는 해당 없음)
func is_dash_parry() -> bool:
	return (dash_t > 0.0 and (dash_kind == "dash" or dash_kind == "charge")) or dash_parry_t > 0.0


func on_parry_success(perfect: bool, boosted := false) -> void:
	dash_parry_t = 0.0
	parry_active = false
	parry_cd = 0.0
	cancel_charge()                              # 패리에 성공하면 차지는 끊긴다 (리버스 드라이브가 대신 나간다)
	queued_press = false
	dash_t = 0.0
	_end_dash()
	on_platform = false
	launch_t = 0.0
	vel = Vector2.ZERO
	aim_phase = true
	aim_perfect = perfect
	aim_boost = boosted
	aim_left = stats.aim_time_perfect if perfect else stats.aim_time
	parry_flash = 1.0


## 잔탄 흡수: 패리 판정은 그대로 열려 있고, 판정이 끝나도 쿨다운이 없다
func on_absorb() -> void:
	parry_hit = true


## 프레스(천장 근접공격)를 패리: 막기는 했지만 거대한 힘에 아래로 내리꽂힌다 (제어 불능, 융해 지대로)
func on_press_pin() -> void:
	parry_active = false
	parry_cd = 0.0
	cancel_charge()
	queued_press = false
	dash_t = 0.0
	_end_dash()
	bouncing = false
	bounce_rise = 0.0
	on_platform = false
	launch_t = 0.0
	vel = Vector2(0.0, PRESS_PIN_SPEED)
	stun = PRESS_PIN_TIME
	shield_t = PRESS_PIN_TIME                    # 막기는 했으니 피해는 없다 (대신 내리꽂힘)
	shield_max = PRESS_PIN_TIME
	parry_flash = 0.6


## 휩쓰는 팔을 그냥 패리: 피해는 없지만 패리 돌진도 없다. 팔 반대쪽으로 튕겨나기만 한다
func on_parry_push(away: Vector2) -> void:
	parry_active = false
	parry_cd = 0.0
	cancel_charge()
	dash_t = 0.0
	_end_dash()
	on_platform = false
	launch_t = 0.0
	vel = away.normalized() * PARRY_PUSH
	bouncing = true
	shield_t = PARRY_PUSH_SHIELD
	shield_max = PARRY_PUSH_SHIELD
	parry_flash = 0.6


## 지금 조준 중인 리버스 드라이브의 사거리 (돌진패리면 DASH_PARRY_RANGE 배)
func parry_dash_reach() -> float:
	var spd := PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED
	return spd * PARRY_DASH_TIME * (DASH_PARRY_RANGE if aim_boost else 1.0)


## 방향 지정 종료 → 마우스 방향으로 패리 돌진(공격 판정, 강한 데미지)
func launch_parry_dash() -> void:
	if not aim_phase:
		return
	aim_phase = false
	dash_kind = "power"
	perfect_dash = aim_perfect
	power_boost = aim_boost
	aim_boost = false
	dash_total = PARRY_DASH_TIME * (DASH_PARRY_RANGE if power_boost else 1.0)
	dash_t = dash_total
	dash_cd = stats.dash_cooldown
	vel = aim * (PARRY_DASH_SPEED_PERFECT if aim_perfect else PARRY_DASH_SPEED)
	parry_cd = PARRY_RELEASE_CD
	main.on_parry_launch(position, aim)


## 일반 돌진 중 공격이 스치는지 검사할 상태인가 (main.gd 가 공격 판정과 겹치는지 검사)
func can_evade_reward() -> bool:
	return dash_kind == "dash" and dash_t > 0.0 and evade_window > 0.0 and not evade_rewarded


## 퍼펙트 회피 (돌진 시작 직후 공격이 스침): 다음 차지 강화 + 무적 연장 + 돌진 쿨다운 즉시 초기화.
## 그냥 무적으로 통과한 것은 보상·연출이 없다
func try_evade_reward(strong := false) -> void:
	if evade_window <= 0.0:
		return
	evade_rewarded = true
	buffed = true
	buff_strong = buff_strong or strong            # 이미 강한 버프가 있으면 약한 회피로 내려가지 않는다
	buff_t = stats.sync_time                       # 다시 얻으면 지속 시간 갱신
	evade_invuln = PERFECT_EVADE_INVULN * (1.5 if strong else 1.0)
	invuln = maxf(invuln, evade_invuln)            # 성공 직후 다른 공격에 맞지 않도록 무적 연장
	dash_cd = dash_t                               # 이 돌진이 끝나는 즉시 다시 돌진할 수 있다
	main.on_perfect_evade(position, strong)


## 퍼펙트 회피에 성공한 돌진이 진행되는 동안(기본 회피 무적 시간) 다른 공격과 닿을 때마다 추가 무적을 처음 길이로 되돌린다
## (도착한 자리에서도 무사할 확률을 높인다)
func can_refresh_evade() -> bool:
	return evade_rewarded and dash_kind == "dash" and dash_t > 0.0


func refresh_evade_invuln() -> void:
	invuln = maxf(invuln, evade_invuln)


## 피격: 잠시 조작 불가(스턴), 살짝 솟구친 뒤 추락
func on_hurt(push: Vector2) -> void:
	dash_parry_t = 0.0
	cancel_charge()
	_clear_buff()
	queued_press = dash_held                       # 누르고 있었다면 스턴이 끝나자마자 모으기 시작
	evade_window = 0.0
	var sx := signf(push.x) if absf(push.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	vel = Vector2(sx * HURT_PUSH, -HURT_POP)
	stun = stats.stun_time
	invuln = stats.stun_time + STUN_INVULN
	dash_t = 0.0
	dash_kind = ""
	perfect_dash = false
	parry_active = false
	bouncing = false
	on_platform = false
	launch_t = 0.0


func step(dt: float) -> void:
	if frozen:
		queue_redraw()
		return
	if buffed:                                    # 동조 지속 시간: 월드 시간으로 줄어든다 (슬로우 중엔 느리게)
		buff_t -= dt * main.world_scale()
		if buff_t <= 0.0 and not (dash_t > 0.0 and dash_kind == "charge"):   # 끝날 무렵 시전한 차지 강습은 끝날 때까지 유지
			_clear_buff()
	var m: Vector2 = main.aim_offset(position)
	assist_lock = false
	if m.length() > AIM_DEADZONE:
		aim = m.normalized()
		if aim_phase:                                 # 에임 어시스트: 사거리 안 표적이 조준선 가까이 있으면 살짝 끌어당긴다
			aim = _assisted(aim, parry_dash_reach(), POWER_RADIUS)
		elif is_charged() or pending_kind == "charge":
			aim = _assisted(aim, CHARGE_SPEED * CHARGE_DASH_TIME, 0.0)
	if aim_phase:
		facing = lerp_angle(facing, aim.angle(), 1.0 - exp(-ROT_SPEED * 2.0 * dt))
		queue_redraw()
		return

	dash_cd = maxf(0.0, dash_cd - dt)
	charge_cd = maxf(0.0, charge_cd - dt)
	small_guard = maxf(0.0, small_guard - dt)
	strike_pass_t = maxf(0.0, strike_pass_t - dt)
	evade_window = maxf(0.0, evade_window - dt)
	parry_cd = maxf(0.0, parry_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	dash_parry_t = maxf(0.0, dash_parry_t - dt)
	shield_t = maxf(0.0, shield_t - dt)
	if bounce_rise > 0.0 and vel.y > -bounce_rise * BOUNCE_END:   # 직격 튕김이 끝나 통제를 되찾음 → 무적도 끝
		bounce_rise = 0.0
		shield_t = 0.0
	if shield_t <= 0.0:
		bouncing = false
	launch_t = maxf(0.0, launch_t - dt)
	parry_flash = maxf(0.0, parry_flash - dt * 4.0)
	_step_heat_ring(dt)
	if stun > 0.0:
		stun -= dt
		if stun <= 0.0:
			stun = 0.0
			main.on_stun_recover(position)
			if queued_press and dash_held:
				queued_press = false
				press_dash()
	if pending_kind != "" and can_dash() and not on_platform:
		_dash(pending_kind)
	if charging:
		charge_t += dt
		if charge_cd > 0.0:                   # 차지 쿨다운 중: 모이지 않는다 (감속·떨림도 없음). 끝나면 0부터 모인다. 그 전에 떼면 일반 돌진
			charge_t = 0.0
		if charge_t >= charge_need() and not charged_notified:
			charged_notified = true
			main.on_charged(position)
		if is_charged() and charge_t >= charge_need() + CHARGE_AUTO:   # 차지 완료 후 잠시 지나면 자동 발사
			charging = false
			_fire("charge")
	if parry_queue > 0.0:
		parry_queue -= dt
		if parry_cd <= 0.0 and parry_held and not parry_active and stun <= 0.0:
			parry_queue = 0.0
			parry_active = true
			parry_hit = false
			parry_t = 0.0
	if parry_active:
		parry_t += dt
		if parry_t > stats.parry_hold_max:
			parry_active = false
			parry_cd = 0.0 if parry_hit else PARRY_COOLDOWN     # 막은 게 있으면 쿨다운 없이 바로 다시
		elif not parry_held and parry_t >= PARRY_MIN:
			parry_active = false
			parry_cd = 0.0 if parry_hit else PARRY_RELEASE_CD

	if on_platform:
		vel.y = 0.0
		var want := 0.0
		if absf(m.x) > 30.0:
			want = signf(m.x) * PLATFORM_SPEED
		vel.x = move_toward(vel.x, want, 2000.0 * dt)
	elif dash_t > 0.0:
		dash_t -= dt
		if dash_t <= 0.0:
			vel *= DASH_KEEP
			if dash_kind == "dash":
				small_guard = SMALL_GUARD
			if dash_kind == "dash" or dash_kind == "charge":
				dash_parry_t = DASH_PARRY_GRACE
			var grace := stats.power_grace if dash_kind == "power" else (CHARGE_GRACE if dash_kind == "charge" else 0.0)
			if grace > 0.0:                   # 무적 여유는 패리 돌진/차지 돌진만
				shield_max = grace
				shield_t = grace
			_end_dash()
	elif launch_t > 0.0:
		pass                                  # 발사 직후: 중력 없이 곧게 솟는다
	else:
		var fall_cap := BASE_FALL
		if stun > 0.0:
			fall_cap = DIVE_FALL
		elif m.length() > AIM_DEADZONE:
			vel.x += aim.x * THRUST * (BOUNCE_THRUST if bouncing else 1.0) * dt
			if aim.y > 0.0:
				vel.y += aim.y * THRUST * dt
				fall_cap = lerpf(BASE_FALL, DIVE_FALL, aim.y)
			else:
				fall_cap = lerpf(BASE_FALL, stats.glide_fall, -aim.y)
		if is_hovering_charge():              # 차지 중엔 공중에서 거의 멈춰 조준한다
			vel.y += GRAVITY * 0.2 * dt
			vel.y = move_toward(vel.y, 0.0, 1500.0 * dt)
			vel.x -= vel.x * 4.0 * dt
		else:
			vel.y += GRAVITY * dt
			vel.x -= vel.x * AIR_DRAG * dt
		if vel.y > fall_cap:
			vel.y = move_toward(vel.y, fall_cap, 2500.0 * dt)

	_move(dt)
	if frozen:
		return

	# 머리 방향: 평소엔 마우스, 돌진·발사·튕김 중엔 진행 방향, 스턴 중엔 빙글빙글
	if stun > 0.0:
		facing += 14.0 * dt
	else:
		var tdir := aim
		if (dash_t > 0.0 or launch_t > 0.0 or bouncing) and vel.length() > 60.0:
			tdir = vel.normalized()
		var turn := wrapf(tdir.angle() - facing, -PI, PI)
		bank = lerpf(bank, clampf(turn / 0.9, -1.0, 1.0), 1.0 - exp(-14.0 * dt))
		facing = lerp_angle(facing, tdir.angle(), 1.0 - exp(-ROT_SPEED * dt))

	trail.push_front(position)
	if trail.size() > 16:
		trail.pop_back()
	queue_redraw()


func _move(dt: float) -> void:
	var steps := clampi(int(ceil(vel.length() * dt / 6.0)), 1, 12)
	var sdt := dt / steps
	for s in steps:
		var prev_y := position.y
		position += vel * sdt
		if on_platform:
			position.x = clampf(position.x, PLAT_CENTER.x - PLAT_HALF + RADIUS, PLAT_CENTER.x + PLAT_HALF - RADIUS)
			position.y = PLAT_CENTER.y - RADIUS
			continue
		# 차지 강습·리버스 드라이브가 근접공격(팔·프레스)에 부딪히면 요격 (부위 타격보다 먼저)
		if (dash_kind == "charge" or dash_kind == "power") and dash_t > 0.0 and main.try_clash(position):
			return
		# 표적(부위·코어)은 돌진 중에만 충돌한다. 그 밖에는 통과하며 접촉 피해도 없다 (피해는 적의 공격으로만)
		if is_attacking():
			var hit: Dictionary = boss.strike_hit(position, RADIUS + (POWER_RADIUS if dash_kind == "power" else 0.0))
			if dash_pass and (hit.is_empty() or str(hit.get("kind", "")) != str(pass_target.get("kind", "")) or int(hit.get("idx", -1)) != int(pass_target.get("idx", -1))):
				dash_pass = false                  # 방금 맞힌 표적의 원을 벗어났다 (또는 다른 표적): 이제부터 정상 충돌 (뒤돌아 다시 때릴 수 있다)
			if not hit.is_empty() and not dash_pass:
				_on_strike(hit)
				if frozen:
					return
		# 벽/천장
		if position.x < WALL_L + RADIUS:
			position.x = WALL_L + RADIUS
			vel.x = absf(vel.x) * 0.5
		elif position.x > WALL_R - RADIUS:
			position.x = WALL_R - RADIUS
			vel.x = -absf(vel.x) * 0.5
		if position.y < CEILING + RADIUS:
			position.y = CEILING + RADIUS
			vel.y = absf(vel.y) * 0.3
		# 발판 (재출격 직후 등 발판이 떠 있을 때만)
		var top := PLAT_CENTER.y - RADIUS
		if main.plat_on and vel.y >= 0.0 and prev_y <= top + 0.5 and position.y >= top \
				and absf(position.x - PLAT_CENTER.x) <= PLAT_HALF:
			position.y = top
			on_platform = true
			vel = Vector2.ZERO
			dash_t = 0.0
			_end_dash()
			return
		# 용암
		if position.y > -RADIUS * 0.3:
			main.on_lava(position)
			return


## 공격 돌진 종료(적중·빗나감 모두). 패리 돌진이 끝나면 슬로우가 풀리고 밀려난 팔이 돌아간다
func _end_dash() -> void:
	var was_power := dash_kind == "power"
	dash_kind = ""
	perfect_dash = false
	power_boost = false
	dash_pass = false
	if was_power:
		main.on_power_dash_end()


## 이번 돌진의 피해량과 버프 소모
func _strike_damage() -> int:
	match dash_kind:
		"power":
			return stats.power_damage_perfect if perfect_dash else stats.power_damage
		"charge":
			return stats.charge_damage * _buff_mult()
	return DASH_DAMAGE


func _buff_mult() -> int:
	if buffed:
		return stats.evade_buff_mult_strong if buff_strong else stats.evade_buff_mult
	return 1


func _on_strike(hit: Dictionary) -> void:
	pass_target = {"kind": hit.get("kind", ""), "idx": hit.get("idx", -1)}
	var dir := vel.normalized()
	var kind := dash_kind
	var dmg := _strike_damage()
	var was_buffed := buffed and kind == "charge"
	last_hit_strong = was_buffed and buff_strong
	if was_buffed:                               # 퍼펙트 회피 버프는 차지 공격 한 번에 소모된다
		_clear_buff()
	main.on_strike(hit, dmg, position, dir, kind, was_buffed, last_hit_strong)
	if frozen:
		return
	bounce_off(dir, kind)
	if hit.get("kind", "") == "core":            # 큰 코어: 튕김이 껍질 안쪽(예: 아래에서 맞혀 위로)을 향하면 바깥으로 되튄다 (코어 안에 박히지 않게)
		var n: Vector2 = hit["n"]
		var vn := vel.dot(n)
		if vn < 0.0:
			vel -= n * vn * (1.0 + CORE_REBOUND)
			bounce_rise = 0.0                      # 솟구치지 않으므로 튕김 무적은 짧게 고정
			shield_t = CORE_REBOUND_SHIELD
			shield_max = CORE_REBOUND_SHIELD


## 요격 피해: 리버스 드라이브로 요격하면 리버스 드라이브 피해(12, PERFECT 16) 그대로, 차지 강습이면 clash_damage
func intercept_damage() -> int:
	if dash_kind == "power":
		last_hit_strong = false
		return _strike_damage()
	return clash_damage()


## 받아치기: 휩쓰는 팔에 차지 돌진이 부딪힘 → 피해량 반환 (버프가 있으면 2배, 소모)
## 요격에는 강한 버프(4배)가 걸리지 않는다. 동조가 있으면 일반 배율(2배)만 적용하고 소모한다
func clash_damage() -> int:
	var dmg := stats.clash_damage * (stats.evade_buff_mult if buffed else 1)
	last_hit_strong = false
	_clear_buff()
	return dmg


## 잔탄 체력 링: 과열(main.heat)이 있으면 보이고, 다 식으면 잠시 뒤 사라진다. 칸이 바뀌면 그 칸이 번쩍인다
func _step_heat_ring(dt: float) -> void:
	var hmax: int = main.HEAT_MAX
	var cells: int = hmax - int(main.heat)
	heat_flash = maxf(0.0, heat_flash - dt * 3.0)
	heat_break = maxf(0.0, heat_break - dt)
	if cells != heat_cells:
		heat_flash_k = mini(cells, heat_cells)          # 깎이면 사라진 칸, 돌아오면 새로 찬 칸
		heat_flash = 1.0
		heat_cells = cells
	if int(main.heat) > 0 or heat_break > 0.0:
		heat_vis = HEAT_RING_HOLD + HEAT_RING_FADE
	else:
		heat_vis = maxf(0.0, heat_vis - dt)


## 셋째 잔탄으로 셀이 깨짐 (main.gd): 빈 링을 잠깐 붉게 보인 뒤 가득 찬 링으로
func on_heat_break() -> void:
	heat_break = HEAT_RING_BREAK
	heat_vis = HEAT_RING_HOLD + HEAT_RING_FADE


## 요격 성공 (main.gd). 강습 코어가 있으면 차지 쿨다운을 없애고 다음 차지를 바로 완료시킨다 (이미 누르고 있으면 그 자리에서 완료)
func on_intercept() -> void:
	if not stats.assault:
		return
	charge_cd = 0.0
	quick_charge = true
	if charging:
		charge_t = maxf(charge_t, charge_need())


func _clear_buff() -> void:
	buffed = false
	buff_strong = false
	buff_t = 0.0


## 직격 후 위로 솟구친다 (차지·패리 돌진일수록 조금 더 높이). 좌우는 마우스(스틱)로 조종.
## 차지 강습(요격 포함)·리버스 드라이브가 적중하면 돌진 쿨다운을 돌려준다 (튕겨나는 중에도 바로 돌진). 일반 돌진은 그대로
func bounce_off(dir: Vector2, kind := "dash") -> void:
	dash_t = 0.0
	_end_dash()
	bouncing = true
	shield_t = STRIKE_SHIELD                     # 튕겨나는 동안 무적 (통제를 되찾으면 끝)
	shield_max = STRIKE_SHIELD
	strike_pass_t = STRIKE_PASS
	parry_cd = 0.0                               # 튕겨나오는 즉시 패리 가능
	if kind != "dash":
		dash_cd = 0.0
		pending_kind = ""
	parry_queue = 0.0
	var k := 1.25 if kind == "power" else (1.1 if kind == "charge" else 1.0)
	var m: Vector2 = main.aim_offset(position)    # 조준 보조가 아니라 실제 마우스(스틱) 방향으로 좌우 조종
	var steer := 0.0
	if m.length() > AIM_DEADZONE:
		steer = m.normalized().x
	vel = Vector2(-dir.x * BOUNCE_SIDE + steer * BOUNCE_STEER, -stats.bounce_up * k)
	bounce_rise = stats.bounce_up * k


## 에임 어시스트: 사거리 안에서 조준선이 표적 가장자리 일정 각도(PC 24도, 터치 40도) 이내면 표적 중심으로 달라붙는다.
## 가장자리에서 멀수록 천천히 풀려(연속) 튀지 않는다. 가장 가까운 표적 하나만 대상.
func _assisted(a: Vector2, reach: float, extra_r: float) -> Vector2:
	var cone := stats.assist_cone_touch if main.touch_ui != null else stats.assist_cone
	var ang := a.angle()
	var best_score := INF
	var best_da := 0.0
	var best_err := 0.0
	var best_t := {}
	for t in boss.assist_targets(position):
		var d: Vector2 = t["pos"] - position
		var dist := d.length()
		var r: float = float(t["r"]) + RADIUS + extra_r
		if dist < 1.0 or dist - r > reach + ASSIST_SLACK:
			continue
		var da := wrapf(d.angle() - ang, -PI, PI)
		var err := absf(da) - asin(minf(1.0, r / dist))
		if err > cone:
			continue
		var score := maxf(err, 0.0) * 10.0 + absf(da)
		if score < best_score:
			best_score = score
			best_da = da
			best_err = err
			best_t = t
	if best_t.is_empty():
		return a
	var s := 1.0 - smoothstep(cone * 0.5, cone, maxf(best_err, 0.0))     # 가까우면 완전히 붙고, 멀면 풀린다
	if s > 0.5:
		assist_lock = true
		assist_pos = best_t["pos"]
		assist_r = float(best_t["r"])
	return a.rotated(best_da * s)


# ── 그리기 ─────────────────────────────────────────────
## 레이저 같은 실선 사거리 표시 (끝으로 갈수록 옅어짐)
func _laser(dir: Vector2, reach: float, c: Color) -> void:
	var n := 14
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var fade := lerpf(1.0, 0.35, t0)
		var p0 := dir * lerpf(40.0, reach, t0)
		var p1 := dir * lerpf(40.0, reach, t1)
		draw_line(p0, p1, Color(c, 0.16 * fade), 8.0)
		draw_line(p0, p1, Color(c, 0.5 * fade), 3.2)
		draw_line(p0, p1, Color(1, 1, 1, 0.9 * fade), 1.3)
	var tip := dir * reach
	draw_circle(tip, 5.0, Color(c, 0.9))
	draw_circle(tip, 3.0, Color(1, 1, 1))
	draw_arc(tip, 12.0, 0.0, TAU, 16, Color(c, 0.7), 2.0)


## 기체 스프라이트 (64×64, 기수가 위쪽이라 +x 기준 각도에서 90도 더 돌린다)
const SHIP_SIZE := 72.0           # 원본 64px 을 약 1.1배


func _draw_rocket(off: Vector2, ang: float, tint: Color) -> void:
	var tex := Sprites.ship(_ship_col, bank)
	draw_set_transform(off, ang + PI * 0.5)
	draw_texture_rect(tex, Rect2(Vector2(-SHIP_SIZE, -SHIP_SIZE) * 0.5, Vector2(SHIP_SIZE, SHIP_SIZE)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0)


## 노즐 화염: 기체 뒤쪽 중심선(기수 반대 방향)에서 나온다. 붉은 바깥불꽃 → 주황 → 노란 심.
## 마우스를 위로(활공·역추진) 두고 떨어지는 중이면 낙하를 상쇄하느라 불꽃이 크게 솟고 불똥이 튄다.
func _draw_flame(off: Vector2) -> void:
	if stun > 0.0 or frozen:
		return
	var power := 0.35
	var retro := 0.0                    # 역추진 강도 0~1: 위를 향해 낙하 속도를 줄이는 중
	if dash_t > 0.0 or launch_t > 0.0:
		power = 1.5
	elif on_platform:
		power = 0.3
	elif is_hovering_charge():
		power = 0.8
	elif aim.y < 0.0:
		power = 0.35 + 0.65 * -aim.y
		retro = clampf(vel.y / 500.0, 0.0, 1.0) * -aim.y
		power += 0.9 * retro
	else:
		power = 0.35 - 0.2 * aim.y
	if dash_cd > 0.0 and dash_t <= 0.0:   # 돌진 쿨다운 중엔 화염이 약하다
		power *= 0.6
	var back := Vector2.from_angle(facing + PI)      # 기체 뒤쪽 (기수 반대)
	var side := back.orthogonal()
	var base := off + back * SHIP_SIZE * 0.27        # 노즐
	var t := Time.get_ticks_msec() * 0.001
	var flick := 0.85 + 0.15 * sin(t * 60.0) + 0.08 * sin(t * 37.0)
	var len := (14.0 + 52.0 * power) * flick
	var w := (5.0 + 5.0 * minf(power, 1.3)) * 0.5 * SHIP_SIZE / 64.0
	var wob := side * sin(t * 45.0) * 2.0
	# 바깥 붉은 불꽃 / 주황 / 노랑·흰 심 (겹쳐서 선명하게)
	draw_colored_polygon(PackedVector2Array([base + side * w * 1.5, base - side * w * 1.5, base + back * len * 1.15 + wob]), Color(0.95, 0.1, 0.05, 0.95))
	draw_colored_polygon(PackedVector2Array([base + side * w * 1.1, base - side * w * 1.1, base + back * len * 0.8 - wob]), Color(1.0, 0.4, 0.05, 1.0))
	draw_colored_polygon(PackedVector2Array([base + side * w * 0.6, base - side * w * 0.6, base + back * len * 0.5 + wob * 0.5]), Color(1.0, 0.88, 0.35, 1.0))
	draw_circle(base, w * 1.1, Color(1.0, 0.95, 0.7, 0.9))
	if retro > 0.15:                     # 역추진: 불똥이 뒤로 튄다
		for k in 6:
			var ph := fmod(t * (3.0 + k * 0.7) + k * 0.37, 1.0)
			var sp := base + back * (len * (0.4 + ph * 0.9)) + side * sin(k * 2.3 + t * 8.0) * w * (1.0 + ph * 2.5)
			draw_circle(sp, 2.0 * (1.0 - ph) + 0.8, Color(1.0, 0.55 + 0.35 * (1.0 - ph), 0.15, 0.9 * (1.0 - ph)))
	# 아래로 향해 낙하 중: 몸 주변 속도선
	if aim.y > 0.3 and dash_t <= 0.0 and vel.y > 200.0:
		var a := clampf((aim.y - 0.3) * 1.4, 0.0, 0.7)
		var vd := vel.normalized()
		for k in [-1.0, 0.0, 1.0]:
			var st: Vector2 = off + vd.orthogonal() * k * 14.0 - vd * 18.0
			draw_line(st, st - vd * (26.0 + 14.0 * absf(float(k))), Color(0.85, 0.92, 1.0, a), 2.0)


## 금빛 꼬리: 기체 뒤쪽(기수 반대)으로 길게 늘어지는 금빛 불꽃 (완전 동조 · 리버스 드라이브 중). k = 크기 배율
func _draw_gold_tail(k: float) -> void:
	var back := Vector2.from_angle(facing + PI)
	var side := back.orthogonal()
	var t := Time.get_ticks_msec() * 0.001
	var flick := 0.9 + 0.1 * sin(t * 52.0) + 0.05 * sin(t * 29.0)
	var base := back * SHIP_SIZE * 0.22
	var layers := [[1.0, 1.0, Color(1.0, 0.72, 0.2)], [0.62, 0.8, Color(1.0, 0.86, 0.38)], [0.3, 0.55, Color(1.0, 0.97, 0.78)]]
	for L in layers:
		var w := 17.0 * k * float(L[0])
		var ln := 105.0 * k * float(L[1]) * flick
		var tip := base + back * ln + side * sin(t * 38.0 + float(L[0]) * 5.0) * 4.0 * k
		var c: Color = L[2]
		draw_polygon(PackedVector2Array([base + side * w, base - side * w, tip]),
			PackedColorArray([Color(c, 0.85), Color(c, 0.85), Color(c, 0.0)]))
	for j in 5:                                     # 뒤로 흩날리는 불똥
		var ph := fmod(t * (1.6 + j * 0.37) + j * 0.31, 1.0)
		var sp := base + back * (30.0 + 120.0 * k * ph) + side * sin(j * 2.1 + t * 9.0) * 12.0 * k * (0.4 + ph)
		draw_circle(sp, 2.6 * (1.0 - ph) + 0.8, Color(1.0, 0.9, 0.5, 0.9 * (1.0 - ph)))


## 무적이 남은 시간 (실드가 끝나기 직전 깜빡임용). 돌진·조준·발사 중엔 넉넉하게 본다
func _draw_heat_ring() -> void:
	var a := clampf(heat_vis / HEAT_RING_FADE, 0.0, 1.0)
	var hmax: int = main.HEAT_MAX
	var seg := TAU / hmax
	var full := Color(1.0, 0.62, 0.18)
	if heat_break > 0.0:                       # 셀이 깨졌다: 빈 칸들이 붉게 깜빡인다
		var on := fmod(heat_break * 8.0, 1.0) > 0.4
		for k in hmax:
			draw_arc(Vector2.ZERO, HEAT_RING_R, -PI * 0.5 + k * seg + 0.14, -PI * 0.5 + (k + 1) * seg - 0.14, 12,
				Color(1.0, 0.2, 0.12, (0.9 if on else 0.3) * a), 5.0)
		return
	for k in hmax:
		var a0 := -PI * 0.5 + k * seg + 0.14
		var a1 := -PI * 0.5 + (k + 1) * seg - 0.14
		if k < heat_cells:
			var c := full.lerp(Color.WHITE, heat_flash if k == heat_flash_k else 0.0)
			draw_arc(Vector2.ZERO, HEAT_RING_R, a0, a1, 12, Color(c, 0.9 * a), 5.0)
		else:                                  # 깎인 칸: 어두운 자리만 (방금 깎였으면 하얗게 사라진다)
			draw_arc(Vector2.ZERO, HEAT_RING_R, a0, a1, 12, Color(0.3, 0.16, 0.1, 0.55 * a), 3.0)
			if k == heat_flash_k and heat_flash > 0.0:
				draw_arc(Vector2.ZERO, HEAT_RING_R + 6.0 * (1.0 - heat_flash), a0, a1, 12, Color(1, 1, 1, heat_flash * a), 5.0)


func _immune_left() -> float:
	var left := maxf(shield_t, invuln)
	if dash_t > 0.0 or aim_phase or launch_t > 0.0:
		left = maxf(left, 1.0)
	return left


func _draw() -> void:
	var jitter := Vector2.ZERO
	if is_hovering_charge():           # 차지 중엔 몸이 떨린다 (완료되면 더)
		var amp := 0.8 if is_charged() else 0.6 + 1.6 * clampf(charge_t / charge_need(), 0.0, 1.0)
		jitter = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	var evade := dash_t > 0.0 and dash_kind == "dash"
	var attack := dash_t > 0.0 and (dash_kind == "charge" or dash_kind == "power")

	# 꼬리: 일반 돌진은 청백(무적·잔상), 차지·패리 돌진은 주황
	var tc := (Color(0.5, 1.0, 0.88) if power_boost else C_ATTACK) if attack else C_EVADE   # 돌진패리 리버스 드라이브는 청록 꼬리
	for i in range(trail.size() - 1):
		var a := 1.0 - float(i) / trail.size()
		draw_line(trail[i] - position, trail[i + 1] - position, Color(tc, a * (0.3 if evade else 0.6)), 6.0 * a + 1.0)
	# 일반 돌진: 잔상
	if evade:
		for k in [3, 6, 9, 12]:
			if k < trail.size():
				_draw_rocket(trail[k] - position, facing, Color(C_EVADE, 0.28 - k * 0.018))

	# 퍼펙트 회피 버프(동조): 다음 공격이 강화됐음을 알리는 청백 오라. 패리 불가 공격을 피해 얻은 강한 버프(완전 동조, 4배)와
	# 리버스 드라이브 중에는 기체 뒤로 금빛 꼬리가 길게 늘어진다
	var fade_ok := buff_t > 1.0 or dash_t > 0.0 or int(Time.get_ticks_msec() / 90) % 2 == 0   # 마지막 1초는 깜빡인다
	if buffed and not buff_strong and fade_ok:
		var bp := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		draw_circle(Vector2.ZERO, 26.0, Color(0.7, 0.95, 1.0, 0.12 + 0.1 * bp))
		draw_arc(Vector2.ZERO, 30.0 + 3.0 * bp, 0.0, TAU, 32, Color(0.8, 0.97, 1.0, 0.55 + 0.35 * bp), 2.5)
		for k in 3:
			var ba := Time.get_ticks_msec() * 0.006 + k * TAU / 3.0
			draw_circle(Vector2(cos(ba), sin(ba)) * 34.0, 2.6, Color(1, 1, 1, 0.9))
	if dash_t > 0.0 and dash_kind == "power":
		_draw_gold_tail((1.9 if perfect_dash else 1.6) * (1.4 if power_boost else 1.0))
	elif buffed and buff_strong and fade_ok:
		_draw_gold_tail(1.0)

	_ship_col = "r" if attack else "b"
	_draw_flame(jitter)
	# 잔탄 긁힘: 기체가 주황빛으로 달아오르고 불똥이 튄다 (쌓일수록 더, 식으면 서서히 사라진다)
	var hl: float = main.heat_level()
	if hl > 0.0:
		var ht := Time.get_ticks_msec() * 0.001
		var hp := 0.5 + 0.5 * sin(ht * (7.0 + 12.0 * hl))
		draw_circle(Vector2.ZERO, 30.0 + 4.0 * hp, Color(1.0, 0.4, 0.1, (0.07 + 0.2 * hl) * (0.7 + 0.3 * hp)))
		for j in 1 + int(5.0 * hl):
			var ph := fmod(ht * (1.6 + j * 0.6) + j * 0.37, 1.0)
			var sp := Vector2(sin(j * 2.3 + ht * 3.0) * 14.0, -8.0 - 46.0 * ph)
			draw_circle(sp, 2.2 * (1.0 - ph) + 0.8, Color(1.0, 0.55 + 0.35 * (1.0 - ph), 0.2, 0.9 * (1.0 - ph)))
	_draw_rocket(jitter, facing, Color(1.0, 1.0 - 0.12 * hl, 1.0 - 0.3 * hl))
	if hl > 0.3:                                 # 달아오른 선체의 금 (HUD 셀의 금과 같은 모양)
		var hq := 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.006 + 0.012 * hl))
		var cr := [[Vector2(-6, -26), Vector2(2, -9)], [Vector2(2, -9), Vector2(-5, 4)], [Vector2(-5, 4), Vector2(5, 20)], [Vector2(2, -9), Vector2(11, -5)]]
		var rot := facing + PI * 0.5
		for k in (2 if hl < 0.75 else 4):
			var ca: Vector2 = jitter + (cr[k][0] as Vector2).rotated(rot)
			var cb: Vector2 = jitter + (cr[k][1] as Vector2).rotated(rot)
			draw_line(ca, cb, Color(0.1, 0.04, 0.02, 0.8), 3.0)
			draw_line(ca, cb, Color(1.0, 0.62, 0.22, 0.6 + 0.4 * hq), 1.6)

	# 무적 실드: 무적인 동안은 언제나 푸른 벌집 실드 하나로 보여 준다 (돌진·공격 돌진·발사·적중 후 튕김·피격 후·퍼펙트 회피 후).
	# 끝나기 직전엔 깜빡인다. 기체 위에 그려 가려지지 않게, 기체보다 넓게
	if is_immune() and not frozen:
		var left := _immune_left()
		var sa := 1.0 if left > 0.3 or int(Time.get_ticks_msec() / 60) % 2 == 0 else 0.35
		HexShield.draw(self, Vector2.ZERO, 44.0, sa, Time.get_ticks_msec() * 0.001)
	elif small_guard > 0.0 and not frozen:          # 돌진 직후: 잔탄만 막아 주는 옅은 실드
		HexShield.draw(self, Vector2.ZERO, 40.0, 0.4, Time.get_ticks_msec() * 0.001)
	if attack:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(C_ATTACK, 0.8), 2.0)

	# 스턴: 연기
	if stun > 0.0:
		var tt := Time.get_ticks_msec() * 0.006
		for k in 3:
			var a := tt + k * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a)) * 18.0 + Vector2(0, -6), 7.0 + 2.0 * sin(tt * 2.0 + k), Color(0.55, 0.57, 0.62, 0.55))

	# 조준
	if aim_phase:
		var total := stats.aim_time_perfect if aim_perfect else stats.aim_time
		var c := Color(0.5, 1.0, 0.88, 0.95) if aim_boost else Color(0.75, 0.92, 1.0, 0.95)   # 돌진패리: 청록 + 더 길게
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color(c, 0.5), 2.0)
		draw_arc(Vector2.ZERO, 46.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(aim_left / total, 0.0, 1.0), 40, c, 4.0)
		_laser(aim, parry_dash_reach(), c)
	elif is_hovering_charge():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		if is_charged():               # 차지 완료: 몸이 살짝 빛나고 공격 사거리 레이저. (차지 중엔 떨림만)
			draw_circle(Vector2.ZERO, 30.0, Color(C_ATTACK, 0.12 + 0.1 * pulse))
			draw_circle(Vector2.ZERO, 19.0, Color(1.0, 0.85, 0.6, 0.12 + 0.12 * pulse))
			_laser(aim, CHARGE_SPEED * CHARGE_DASH_TIME, C_ATTACK)

	# 에임 어시스트: 붙은 표적을 고리로 표시
	if assist_lock and (aim_phase or is_charged()):
		var lp := assist_pos - position
		var ap := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		var lc := Color(0.75, 0.92, 1.0) if aim_phase else C_ATTACK
		draw_arc(lp, assist_r + 8.0 + 3.0 * ap, 0.0, TAU, 36, Color(lc, 0.85), 3.0)
		draw_arc(lp, assist_r + 20.0, 0.0, TAU, 36, Color(lc, 0.3), 2.0)

	# 돌진 쿨다운: 플레이어 주변 얇은 링이 차오른다 (다 차면 다시 돌진)
	if dash_cd > 0.0 and dash_t <= 0.0:
		var ca := 1.0 if charging or pending_kind != "" else 0.7   # 누르고 기다리는 중이면 또렷하게
		draw_arc(Vector2.ZERO, 54.0, 0.0, TAU, 48, Color(C_EVADE, 0.15), 3.0)      # 실드·패리 자세 바깥 (차지 쿨다운 막대와 겹치지 않게)
		draw_arc(Vector2.ZERO, 54.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - dash_cd / stats.dash_cooldown), 48, Color(C_EVADE, ca), 3.0)

	# 잔탄 체력 링: 3칸. 잔탄에 맞으면 깎인 모습이 보이고, 식어서 다 차면 잠시 뒤 사라진다
	if heat_vis > 0.0:
		_draw_heat_ring()

	# 강습 코어: 다음 차지가 바로 완료된다 → 기체 둘레를 도는 주황 불씨 셋
	if quick_charge and not charging and not aim_phase:
		var qa := Time.get_ticks_msec() * 0.008
		for k in 3:
			var qp := Vector2.from_angle(qa + k * TAU / 3.0) * 30.0
			draw_circle(qp, 4.5, Color(C_ATTACK, 0.9))
			draw_circle(qp, 9.0, Color(C_ATTACK, 0.25))

	# 차지 쿨다운: 기체 아래의 주황 막대가 차오른다 (다 차야 다음 차지가 완료된다). 돌진 쿨다운 링과 겹치지 않게 따로 둔다
	if charge_cd > 0.0:
		var fr := 1.0 - charge_cd / stats.charge_cooldown
		var ba := 0.9 if charging else 0.55
		var br := Rect2(-28.0, 68.0, 56.0, 6.0)
		draw_rect(br, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(br.position, Vector2(br.size.x * fr, br.size.y)), Color(C_ATTACK, ba))
		draw_rect(br, Color(C_ATTACK, 0.5 * ba), false, 1.5)

	# 돌진패리: 돌진하는 동안 패리 자세를 잡으면 청록 고리가 겹쳐 뜬다 (이때 막으면 타이밍과 상관없이 PERFECT)
	if parry_active and is_dash_parry():
		var dpp := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_arc(Vector2.ZERO, RADIUS + stats.parry_reach + 8.0, 0.0, TAU, 40, Color(0.5, 1.0, 0.88, 0.7 + 0.3 * dpp), 3.0)

	# 반사 코어: 리버스 드라이브 중 반사 범위
	if is_reflecting():
		draw_arc(Vector2.ZERO, REFLECT_RADIUS, 0.0, TAU, 40, Color(0.75, 1.0, 1.0, 0.55), 2.5)

	# 패리 자세
	if parry_active:
		var perfect_phase := parry_t <= PERFECT_WINDOW
		var c2 := Color(1.0, 0.95, 0.75, 0.9) if perfect_phase else Color(0.8, 0.85, 1.0, 0.55)
		draw_arc(Vector2.ZERO, RADIUS + stats.parry_reach, 0.0, TAU, 40, c2, 2.5 if perfect_phase else 1.5)
	if parry_flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0 + (1.0 - parry_flash) * 44.0, Color(1, 1, 1, parry_flash * 0.5))

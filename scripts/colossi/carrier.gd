extends "res://scripts/colossus_base.gd"
## 콜로서스 ⑤ 모함 (소환형). 기획: docs/BOSS_carrier.md
## 거대한 항공모함이 경기장 위쪽에 정박해 있다 — 배경이라 닿지 않지만 화면 위쪽을 가득 채우고 화면을 따라 천천히 움직인다 (ship_to_world, 원근).
## 플레이어가 실제로 싸우는 상대는 모함이 내보낸 드론 편대 셋(3기씩, 모두 9기)이다.
## 아홉 기는 늘 플레이어를 가운데 둔 둥근 포위망을 유지한다 (플레이어를 따라오고, 천천히 돌고, 숨 쉬듯 좁혀졌다 넓어진다).
## 차례가 온 편대만 나서서 플레이어를 노린다. 편대마다 패턴 셋 = 편대 패턴 둘 + 편대장 패턴 하나 (squad_*.gd):
##   탄막 편대(금): 조준 부채 / 조준 연사 / 편대장 유도탄
##   돌격 편대(진홍, 근접 → 요격): 나란히 돌진 / 연속 돌진 / 편대장 창 돌격
##   결계 편대(보라, 패리 불가 → 퍼펙트 회피): 조여 드는 그물 / 꿰뚫는 창 / 편대장 고리 파동
## 모함 본체도 쏜다: 대형 포탄 한 발(터지며 잔탄) ↔ 주포(겨누는 아주 굵은 패리 불가 광선 한 줄기). 겹쳐도 되는 편대 패턴과는 함께 나오고
## (대형 포탄 = 탄막·결계 편대와, 주포 = 탄막 편대와), 아니면 따로 차례를 받는다. 돌격(근접)과는 절대 겹치지 않는다.
## 견제 사격: 대기 중인 드론이 가끔 플레이어를 겨눠 금색 탄 한 발 (다른 패턴 중에도. 근접 예고·돌진 중에는 쉬고, 금색이라 패리 연료다).
## 편대를 하나 전멸시킬 때마다 남은 편대가 사나워진다 (패턴 +15%, 탄 +8%, 견제 사격이 잦아짐).
## 편대 차례는 섞이되 같은 편대가 연달아 오지 않는다 (편대 안의 패턴도 직전과 다르게). 돌격(근접)은 날아오는 탄이 걷힌 뒤에만.
## 드론 = 외부 시스템 (편대장 체력 높게, 편대원 낮게). 약한 일격(돌진·차지)은 흠집(1)만 — 패턴을 파훼한 일격(리버스 드라이브·요격·동조)으로 부순다.
## 부서진 드론은 맞은 쪽으로 튕겼다가 원근으로 작아지며 모함으로 날아가 선체에 꽂혀 불탄다 (꽂힌 자리 = 체력 표시).
## 아홉 기를 다 잡으면 갑판이 갈라지며 코어가 떨어져 나와 경기장으로 내려오고(CORE_POS), 최후의 발악(금빛 탄막의 바다)이 시작된다.
## 이때 코어는 리버스 드라이브 한 방이면 터지고, 돌진·차지는 튕겨 나온다 (반사탄도 안 들어간다).
## 바닥 y=0 (궤도 무대: 대기권 경계), 위쪽이 음수.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const SquadGun := preload("res://scripts/attacks/squad_gun.gd")
const SquadRush := preload("res://scripts/attacks/squad_rush.gd")
const SquadVeil := preload("res://scripts/attacks/squad_veil.gd")
const CarrierShell := preload("res://scripts/attacks/carrier_shell.gd")
const CarrierCannon := preload("res://scripts/attacks/carrier_cannon.gd")
const OpenBarrage := preload("res://scripts/attacks/open_barrage.gd")

# ── 편대 ───────────────────────────────────────────────
const SQUADS := 3
const PER := 3                               # 편대당 기체 수 (0번 = 편대장)
const SQUAD_KIND := ["gun", "rush", "veil"]
const SQUAD_MODES := {"gun": ["fan", "stream", "missiles"], "rush": ["line", "chain", "lance"], "veil": ["net", "cross", "pulse"]}   # 마지막 = 편대장 패턴
const SQUAD_COL := [Color(1.0, 0.8, 0.35), Color(1.0, 0.24, 0.18), Color(0.85, 0.3, 0.75)]   # 금 / 진홍 / 보라 (색 규칙)
const LEADER_HP := 55                        # 편대장: PERFECT 리버스 드라이브 네 방쯤 (v0.108: 40 → 55, 첫 클리어 1:06 → 1:30 목표)
const WING_HP := 35                          # 편대원: 세 방쯤 (v0.108: 25 → 35)
const ARMOR_HP := 375                        # = 아홉 기 체력 합 (게이지·플레이 기록용)
const CHIP := 1                              # 약한 일격(돌진·차지)은 이만큼만
const WING_SIZE := 62.0                      # 편대원 그림 크기
const LEADER_SIZE := 96.0                    # 편대장 그림 크기 (육중한 지휘기)
const WING_R := 50.0                         # 판정 반지름
const LEADER_R := 74.0

# ── 포위망 ─────────────────────────────────────────────
const RING_R := 690.0
const RING_BREATHE := 70.0                   # 숨 쉬듯 좁혀졌다 넓어진다
const RING_SPIN := 0.25                      # 포위망 회전 (rad/s)
const SHIELD_FRONT := 40.0                   # 편대원은 포위망보다 이만큼 안쪽(플레이어 쪽)에 나란히 서서
const SHIELD_GAP := 62.0                     # 편대장을 가린다 (두 기 사이 간격의 절반: 리버스 드라이브가 빠져나갈 틈이 없게)
const LEADER_BACK := 170.0                   # 편대장은 편대원 뒤 (플레이어에서 멀리)
const MOVE_K := 4.0                          # 드론이 원하는 자리로 미끄러지는 빠르기
const ARENA := Rect2(-1150, -3000, 2300, 2780)

# ── 모함 (배경) ────────────────────────────────────────
const SHIP_ANCHOR := Vector2(0, -2600)      # 모함이 정박한 곳 (월드). 실제로 그리는 자리는 화면 쪽으로 당겨진다 (원근)
const SHIP_PAR := 0.35                       # 화면 가운데에서 SHIP_ANCHOR 쪽으로 이만큼 (작을수록 멀리 있어 화면에 붙어 있다)
const SHIP_SCALE := 0.8                      # 멀리 있지만 화면을 가득 채울 만큼 거대하다
const DECK_CORE := Vector2(0, 40)            # 갑판 속 코어 자리 (선체 기준)
const CORE_POS := Vector2(0, -2050)          # 떨어져 나온 코어가 내려와 머무는 곳 (월드, 최후의 발악)
const CORE_R := 60.0
const HANGARS := [Vector2(-760, 70), Vector2(0, 100), Vector2(760, 70)]   # 편대마다 격납고 (선체 기준)
const CANNON_BASE := Vector2(1240, 250)      # 뱃머리 아래 주포 포탑 (선체 기준)
const CANNON_LEN := 486.0                    # 포가 중심 → 포구 제동기 끝 (GUN_LEN + 제동기)
const GUN_LEN := 430.0                       # 포신 길이 (탄막 요새 v0.72 의 거대 포와 같은 생김새: 각진 포가 + 네모 포신 셋 + 슬롯 제동기)
const C_GUN_FACE := Color(0.13, 0.125, 0.13)
const C_GUN_SIDE := Color(0.07, 0.068, 0.075)
const BARRIER_R := 120.0                     # (open_barrage) 코어 둘레에서 탄이 나오는 반지름의 두 배

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.1, 0.2)               # 차례 사이 (짧게: 화면이 비지 않게, v0.106)
const OVERLAP := {"big_shell": ["gun", "veil"], "cannon": ["gun"]}   # 모함 패턴이 함께 나와도 되는 편대 (위협 두 종류 이하, 보라 둘·근접과 겹침 없음)
const OVERLAP_DELAY := 0.8                   # 함께 나올 때 모함 패턴은 편대 패턴보다 조금 늦게
const FURY_TEMPO := 0.15                     # 전멸한 편대 하나마다 남은 편대의 패턴 속도
const FURY_BOLT := 0.08                      # 〃 탄 속도
const HARASS_EVERY := Vector2(2.2, 3.2)      # 견제 사격 간격 (전멸한 편대마다 짧아진다)
const HARASS_WIND := 0.45                    # 쏘기 전 그 드론이 빛난다
const HARASS_SPEED := 290.0
const RUSH_WAIT := 2.5                       # 돌격 차례에 탄이 걷히길 기다리는 최대 시간 (넘으면 다른 편대)

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.17, 0.19, 0.24)
const C_HULL_DARK := Color(0.09, 0.1, 0.13)
const C_HULL_LIT := Color(0.26, 0.29, 0.35)
const C_RIM := Color(0.5, 0.56, 0.66)
const C_HAZE := Color(0.03, 0.04, 0.08)
const C_LIGHT := Color(1.0, 0.75, 0.4)
const C_WINDOW := Color(0.6, 0.8, 1.0)
const C_CORE := Color(1.0, 0.5, 0.25)
const C_DRONE := Color(0.22, 0.24, 0.3)
const C_DRONE_DARK := Color(0.1, 0.11, 0.15)

var deployed := false                        # 편대가 격납고에서 출격했는가 (스테이지 시작: 플레이어가 날아오르면 출격. 부활 땐 이미 나와 있다)
var deploy_t := 0.0
const DEPLOY_TIME := 0.9
var dpos: Array[Vector2] = []                # 드론 위치
var dwant: Array[Vector2] = []               # 드론이 가려는 자리
var dcmd: Array[bool] = []                   # 이번 프레임에 공격이 자리를 정해 주었나 (아니면 포위망)
var daim: Array[float] = []                  # 드론이 바라보는 방향
var daim_want: Array[float] = []
var dglow: Array[float] = []                 # 곧 쏜다 (빛)
var ring_c := Vector2(0, -1500)
var ring_a := 0.0
var active := -1                             # 지금 차례인 편대 (-1 = 모함 차례·쉬는 중)
var last_squad := -1
var last_mode: Array[String] = ["", "", ""]
var squad_turn := true                       # 다음이 편대 차례인가 (모함 차례와 번갈아)
var last_ship := ""
var rush_wait := 0.0
var harass_t := 2.5                          # 다음 견제 사격까지
var harass_i := -1                           # 견제 사격을 준비 중인 드론 (-1 = 없음)
var harass_wind := 0.0
var flung: Array[Dictionary] = []            # 부서져 모함으로 날아가는 드론 {from, dir, t, to(선체 기준), i}
var burns: Array[Dictionary] = []            # 선체에 꽂혀 타는 자리 {pos(선체 기준), t}
var cannon_aim := PI * 0.5                   # 주포 포신 방향
var cannon_glow := 0.0
var cannon_recoil := 0.0                     # 쏜 순간 포신이 뒤로 밀린다
var hull_shake := 0.0
var shield_flash := 0.0                      # 코어에 약한 일격이 튕김 (main 이 채운다)
var shield_hit_n := Vector2.UP


func _init() -> void:
	open_time = 2.8                              # 금이 번지고 → 선체가 갈라지고 → 코어가 나온다
	attack_gap = GAP
	core_assist_r = 150.0
	bolt_speedup_core = 0.0


func _ready() -> void:
	var outline := []
	for k in 16:
		outline.append(Vector2.from_angle(k * TAU / 16.0) * CORE_R * 1.5)
	core = ArmoredCore.new(self, CORE_POS, outline, ARMOR_HP, Rect2(), 0, 53)
	reset()


func reset() -> void:
	super()
	dpos.clear()
	dwant.clear()
	dcmd.clear()
	daim.clear()
	daim_want.clear()
	dglow.clear()
	for i in part_count():
		var h: Vector2 = ship_to_world(HANGARS[squad_of(i)]) + Vector2((i % PER - 1) * 50.0, 0)
		dpos.append(h)                           # 격납고에서 쏟아져 나와 포위망으로 간다
		dwant.append(h)
		dcmd.append(false)
		daim.append(PI * 0.5)
		daim_want.append(PI * 0.5)
		dglow.append(0.0)
	ring_c = look_at
	ring_a = 0.0
	deployed = false
	deploy_t = 0.0
	active = -1
	last_squad = -1
	last_mode = ["", "", ""]
	squad_turn = true
	last_ship = ""
	rush_wait = 0.0
	harass_t = 2.5
	harass_i = -1
	harass_wind = 0.0
	flung.clear()
	burns.clear()
	cannon_aim = PI * 0.5
	cannon_glow = 0.0
	cannon_recoil = 0.0
	hull_shake = 0.0
	shield_flash = 0.0


# ── 드론 (외부 시스템) ─────────────────────────────────
func part_count() -> int:
	return SQUADS * PER


func squad_of(i: int) -> int:
	return i / PER


func is_leader(i: int) -> bool:
	return i % PER == 0


func leader_of(s: int) -> int:
	return s * PER


## 출격 전(격납고에 숨어 있음)에는 보이지도, 노려지지도, 맞지도 않는다
func part_targetable(i: int) -> bool:
	return deployed and part_alive(i)


func part_max_hp(i: int) -> int:
	return LEADER_HP if is_leader(i) else WING_HP


func part_pos(i: int) -> Vector2:
	return dpos[i] if i < dpos.size() else Vector2.ZERO


func part_radius(i: int) -> float:
	return LEADER_R if is_leader(i) else WING_R


func drone_pos(i: int) -> Vector2:
	return dpos[i]


## 편대 s 의 살아 있는 기체 (편대장 먼저)
func squad_alive(s: int) -> Array:
	var out := []
	if s < 0:
		return out
	for k in PER:
		var i := s * PER + k
		if part_alive(i):
			out.append(i)
	return out


func squad_center(s: int) -> Vector2:
	var ids := squad_alive(s)
	if ids.is_empty():
		return ring_c
	var c := Vector2.ZERO
	for i in ids:
		c += dpos[i]
	return c / ids.size()


## 공격이 드론을 그 자리로 보낸다 (미끄러져 간다)
func want_drone(i: int, p: Vector2) -> void:
	dwant[i] = _in_arena(p)
	dcmd[i] = true


## 공격이 드론을 그 자리에 바로 둔다 (겨누고 멈춤·들이받기·결계 대형)
func hold_drone(i: int, p: Vector2) -> void:
	dpos[i] = _in_arena(p)
	dwant[i] = dpos[i]
	dcmd[i] = true


func aim_drone(i: int, a: float) -> void:
	daim_want[i] = a


func set_drone_glow(i: int, v: float) -> void:
	dglow[i] = maxf(dglow[i], v)


func _in_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, ARENA.position.x, ARENA.end.x), clampf(p.y, ARENA.position.y, ARENA.end.y))


## 포위망 위 드론 i 의 자리: 플레이어를 가운데 두고 편대마다 120°씩. 편대원 둘이 플레이어 쪽에 나란히 서서 뒤의 편대장을 가린다
## (리버스 드라이브 사선이 편대원에 막힌다 — 편대장부터 노리기 어렵게. 편대원이 부서지면 편대장이 드러난다). 돌고 숨 쉬고, 조금씩 흔들린다
func ring_slot(i: int) -> Vector2:
	var s := squad_of(i)
	var k := i % PER
	var d := Vector2.from_angle(ring_a + s * TAU / SQUADS)
	var r := RING_R + RING_BREATHE * sin(t * 0.7)
	var p: Vector2
	if k == 0:
		p = ring_c + d * (r + LEADER_BACK)
	else:
		p = ring_c + d * (r - SHIELD_FRONT) + d.orthogonal() * SHIELD_GAP * (1.0 if k == 1 else -1.0)
	return p + Vector2(sin(t * 2.1 + i), cos(t * 1.8 + i * 0.7)) * 10.0


## 편대장 패턴 동안 편대원 i 의 자리: 앞으로 나선 편대장의 좌우 조금 뒤 (자리를 내주고 붙어 따라간다)
const ESCORT_SIDE := 170.0
const ESCORT_BACK := 70.0


func escort_slot(i: int) -> Vector2:
	var l := dpos[leader_of(squad_of(i))]
	var d := (look_at - l).normalized()
	if d.length() < 0.1:
		d = Vector2.DOWN
	var sd := 1.0 if i % PER == 1 else -1.0
	return l - d * ESCORT_BACK + d.orthogonal() * ESCORT_SIDE * sd


## 약한 일격은 흠집만. 드론이 부서질 때마다 게이지·기록용 코어 값을 맞춘다
func damage_part(i: int, dmg: int) -> bool:
	if dmg > 0 and dmg < FLINCH_DMG:
		dmg = CHIP
	var broke := super(i, dmg)
	_sync_core()
	return broke


func _sync_core() -> void:
	var hp := 0
	for v in part_hp:
		hp += maxi(0, v)
	core.armor_hp = hp


## 부서진 드론: 맞은 쪽으로 튕겼다가 모함 선체의 한 자리로 날아가 꽂힌다
func _on_part_broken(i: int) -> void:
	var dir := (dpos[i] - look_at).normalized()
	if dir.length() < 0.1:
		dir = Vector2.UP
	var slot := float(i) / (part_count() - 1)
	var to := Vector2(lerpf(-1300.0, 1300.0, slot) + sin(i * 2.3) * 80.0, 20.0 + cos(i * 1.7) * 90.0)   # 선체 기준
	flung.append({"from": dpos[i], "dir": dir, "t": 0.0, "to": to, "i": i})
	dglow[i] = 0.0
	if parts_left() == 1:                        # 마지막 기체: 모함에 크게 금이 가며 선체 파편이 튄다
		hull_shake = 1.0
		for k in 10:
			var a := -PI * 0.5 + (k - 4.5) * 0.3
			_spawn_shard(ship_to_world(DECK_CORE + Vector2((k - 4.5) * 60.0, -60.0)), randf_range(18.0, 34.0), Vector2.from_angle(a) * randf_range(500.0, 900.0))


## 전멸한 편대 수 (남은 편대가 그만큼 사나워진다)
func squads_lost() -> int:
	var n := 0
	for s in SQUADS:
		n += 1 if squad_alive(s).is_empty() else 0
	return n


## 탄 속도: 드론이 줄수록, 편대가 전멸할수록 빨라진다
func bolt_mult() -> float:
	return (1.0 + 0.04 * (part_count() - parts_left()) + FURY_BOLT * squads_lost()) * (1.0 + LEVEL_SPEEDUP * level)


## 패턴 속도: 편대가 전멸할수록 남은 편대가 빨라진다 (움찔하면 잠깐 느려지는 것은 그대로)
func pattern_scale() -> float:
	return super() * (1.0 + FURY_TEMPO * squads_lost())


func target_pos(from: Vector2) -> Vector2:
	if phase >= 2:
		return CORE_POS
	var best := CORE_POS
	var bd := INF
	for i in part_count():
		if part_alive(i) and dpos[i].distance_to(from) < bd:
			bd = dpos[i].distance_to(from)
			best = dpos[i]
	return best


## 드러난 코어: 리버스 드라이브만 들어간다 (돌진·차지는 튕긴다)
func blocks_strike(hit: Dictionary, kind: String, _perfect: bool, _strong: bool) -> bool:
	return hit.get("kind", "") == "core" and kind != "power"


func gauge_values() -> Vector3:
	var hp := 0.0
	for v in part_hp:
		hp += maxf(0.0, float(v))
	return Vector3(hp, ARMOR_HP, 0)


func gauge_radius() -> float:
	return CORE_R * 2.4


# ── 모함 (배경): 원근 좌표 · 주포 ───────────────────────
## 선체 기준 좌표 → 지금 화면에서 모함이 보이는 월드 자리 (멀리 있어 화면을 따라 천천히 움직인다)
func ship_to_world(local: Vector2) -> Vector2:
	var c := view_c + (SHIP_ANCHOR - view_c) * SHIP_PAR
	return c + local * SHIP_SCALE


## 주포 포구 (월드)
func cannon_world() -> Vector2:
	return ship_to_world(CANNON_BASE + Vector2.from_angle(cannon_aim) * CANNON_LEN)


func set_cannon_aim(a: float) -> void:
	cannon_aim = a


## 주포를 at 쪽으로 돌린다: 포가(회전축)에서 잰 방향 — 포구에서 재면 포신이 돌 때마다 포구가 옮겨 가
## 가까운 표적에서 각도가 프레임마다 두 값 사이를 오간다 (포신이 둘로 갈라져 X 자로 보이던 원인, v0.118)
func aim_cannon(at: Vector2) -> void:
	cannon_aim = (at - ship_to_world(CANNON_BASE)).angle()


func set_cannon_glow(v: float) -> void:
	cannon_glow = maxf(cannon_glow, clampf(v, 0.0, 1.0))


## 주포가 쐈다: 포신이 뒤로 밀렸다 돌아온다
func cannon_kick() -> void:
	cannon_recoil = 1.0


## (open_barrage 가 부른다) 발광할 곳이 따로 없다
func set_glow(_i: int, _v: float) -> void:
	pass


## 갈라짐 연출의 단계 (페이즈 2: open_t / open_time). 금 → 갈라짐 → 코어가 나옴
const SPLIT_CRACK := 0.45                    # 이때까지 금이 선체 끝까지 번진다
const SPLIT_OPEN := 0.3                      # 이때부터 가운데가 벌어진다
const SPLIT_EMERGE := 0.55                   # 이때부터 코어가 갈라진 틈에서 나와 내려온다


func split_k() -> float:
	if phase < 2:
		return 0.0
	if phase >= 3 or dead:
		return 1.0
	return clampf(open_t / maxf(open_time, 0.1), 0.0, 1.0)


## 떨어져 나온 코어의 그림 위치: 갈라진 틈에서 나와 CORE_POS 로 내려온다 (원근으로 커지며)
func core_draw_pos() -> Vector2:
	var k := clampf((split_k() - SPLIT_EMERGE) / (1.0 - SPLIT_EMERGE), 0.0, 1.0)
	return ship_to_world(DECK_CORE).lerp(CORE_POS, k * k * (3.0 - 2.0 * k))


# ── 진행 ───────────────────────────────────────────────
const FLING_KNOCK := 0.28                    # 맞은 쪽으로 튕기는 시간
const FLING_FLY := 1.1                       # 모함까지 날아가는 시간 (원근으로 작아진다. 불꽃 꼬리가 보이게 조금 느리게)
const FLING_KNOCK_D := 240.0


## 날아가는 드론의 지금 위치와 크기 배율
func fling_state(f: Dictionary, at := -1.0) -> Array:
	var tt := float(f["t"]) if at < 0.0 else at
	var from: Vector2 = f["from"]
	var dir: Vector2 = f["dir"]
	var knock := from + dir * FLING_KNOCK_D
	if tt < FLING_KNOCK:
		var k := tt / FLING_KNOCK
		return [from.lerp(knock, 1.0 - (1.0 - k) * (1.0 - k)), 1.0]
	var u := clampf((tt - FLING_KNOCK) / FLING_FLY, 0.0, 1.0)
	var to := ship_to_world(f["to"])
	var mid := knock.lerp(to, 0.5) + Vector2(0, -260.0)
	var p := knock.lerp(mid, u).lerp(mid.lerp(to, u), u)
	return [p, lerpf(1.0, SHIP_SCALE * 0.45, u)]


func _step_effects(dt: float) -> void:
	hull_shake = maxf(0.0, hull_shake - dt * 2.5)
	shield_flash = maxf(0.0, shield_flash - dt * 3.0)
	cannon_glow = maxf(0.0, cannon_glow - dt * 1.5)
	cannon_recoil = maxf(0.0, cannon_recoil - dt * 2.5)
	if phase == 2:                                # 선체가 갈라지는 동안 계속 흔들린다
		hull_shake = maxf(hull_shake, 0.7)
	for i in dglow.size():
		dglow[i] = move_toward(dglow[i], 0.0, dt * 2.0)
	for b in burns:
		b["t"] = float(b["t"]) + dt
	for f in flung.duplicate():
		f["t"] = float(f["t"]) + dt
		if float(f["t"]) >= FLING_KNOCK + FLING_FLY:   # 선체에 꽂혔다: 불이 붙고 모함이 휘청
			flung.erase(f)
			burns.append({"pos": f["to"], "t": 0.0})
			hull_shake = 1.0
			emit(Ev.CORE_STAGE, ship_to_world(f["to"]), {"stage": burns.size(), "fell": 1})


func _step_phase(dt: float) -> void:
	if phase == 3 and not core.broken:           # 코어가 드러났다: 껍질 없이 한 방이면 터진다
		core.armor_hp = 0
		core.broken = true
		core.guard = 0.0
	if not deployed:                             # 출격 전: 격납고에 숨어 있다가 플레이어가 날아오르면 쏟아져 나온다
		if hold_attacks:
			for i in part_count():
				dpos[i] = ship_to_world(HANGARS[squad_of(i)]) + Vector2((i % PER - 1) * 50.0, 0)
				dwant[i] = dpos[i]
			return
		deployed = true
	deploy_t = minf(DEPLOY_TIME, deploy_t + dt)
	ring_a += RING_SPIN * dt
	ring_c = look_at                             # 포위망은 늘 플레이어를 가운데 둔다 (look_at = 부드럽게 따라가는 플레이어 위치)
	var lead_cmd: Array[bool] = []               # 편대장이 공격에 불려 나갔는가 (편대장 패턴): 편대원이 좌우로 비켜 따라붙는다
	for s in SQUADS:
		var l := leader_of(s)
		lead_cmd.append(part_alive(l) and dcmd[l])
	for i in part_count():
		if not part_alive(i):
			continue
		if not dcmd[i]:
			if not is_leader(i) and lead_cmd[squad_of(i)]:
				dwant[i] = _in_arena(escort_slot(i))
			else:
				dwant[i] = _in_arena(ring_slot(i))
			daim_want[i] = (look_at - dpos[i]).angle()
		dpos[i] = dpos[i].lerp(dwant[i], 1.0 - exp(-MOVE_K * dt))
		daim[i] = lerp_angle(daim[i], daim_want[i], 1.0 - exp(-8.0 * dt))
		dcmd[i] = false
	if phase == 1 and not hold_attacks:
		_harass(dt)


## 견제 사격: 차례가 아닌 드론 하나가 잠깐 빛난 뒤 플레이어를 겨눠 금색 탄 한 발. 근접 예고·돌진 중에는 쉰다 (탄막과 근접은 겹치지 않는다)
func _harass(dt: float) -> void:
	var melee := melee_warning() or attack_kind() == "squad_rush"
	if harass_i >= 0:
		if not part_alive(harass_i) or melee:
			harass_i = -1
			return
		harass_wind += dt
		set_drone_glow(harass_i, harass_wind / HARASS_WIND)
		daim_want[harass_i] = (look_at - dpos[harass_i]).angle()
		if harass_wind >= HARASS_WIND:
			var o := dpos[harass_i]
			var d := (look_at - o).normalized()
			shots.spawn(o + d * 50.0, d * HARASS_SPEED * bolt_mult(), 6.0, 0.0, 0.0, Projectiles.Kind.BOLT, Projectiles.STRAY)
			emit(Ev.BOLT, o)
			harass_i = -1
		return
	harass_t -= dt * (1.0 + 0.3 * squads_lost())
	if harass_t > 0.0 or melee:
		return
	harass_t = randf_range(HARASS_EVERY.x, HARASS_EVERY.y)
	var idle: Array[int] = []
	for i in part_count():
		if part_alive(i) and squad_of(i) != active:
			idle.append(i)
	if idle.is_empty():
		return
	harass_i = idle[randi() % idle.size()]
	harass_wind = 0.0


func _on_attack_finished() -> void:
	active = -1
	attack_gap = GAP


func _choose(ppos: Vector2) -> void:
	if phase == 2:
		return
	if phase == 3:                               # 최후의 발악: 코어에서 금빛 탄막의 바다 (끝나면 다시)
		start_attack(OpenBarrage.new(CORE_POS, true))
		return
	if squad_turn:
		var s := _pick_squad(ppos)
		if s < 0:                                # 돌격만 남았는데 탄이 아직 날아온다: 잠깐 기다린다
			next_t = 0.15
			return
		squad_turn = false
		active = s
		last_squad = s
		rush_wait = 0.0
		var mode := _pick_mode(s)
		last_mode[s] = mode
		match SQUAD_KIND[s]:
			"gun":
				start_attack(SquadGun.new(s, mode))
			"rush":
				start_attack(SquadRush.new(s, mode))
			"veil":
				start_attack(SquadVeil.new(s, mode))
		var ship := _next_ship()                 # 겹쳐도 되는 조합이면 모함 패턴이 함께 (조금 늦게), 아니면 다음 차례에 따로
		if OVERLAP[ship].has(SQUAD_KIND[s]) and not _ship_lingering():
			last_ship = ship
			var a = _ship_attack(ship)
			a.t = -OVERLAP_DELAY
			start_side(a)
			squad_turn = true
		return
	if not lingering.is_empty():                 # 모함 패턴이 아직 도는 중이면 겹쳐 쏘지 않고 기다린다
		next_t = 0.15
		return
	squad_turn = true                            # 모함 차례: 대형 포탄 ↔ 주포 번갈아
	last_ship = _next_ship()
	start_attack(_ship_attack(last_ship))


func _next_ship() -> String:
	return "cannon" if last_ship == "big_shell" else "big_shell"


func _ship_attack(kind_: String):
	return CarrierShell.new() if kind_ == "big_shell" else CarrierCannon.new()


## 다음 편대: 살아 있는 편대 중 직전과 다른 것 (하나만 남으면 그 편대). 돌격은 탄이 걷히고 함께 도는 모함 패턴이 없을 때만 (RUSH_WAIT 를 넘기면 다른 편대로)
func _pick_squad(ppos: Vector2) -> int:
	var cands: Array[int] = []
	for s in SQUADS:
		if not squad_alive(s).is_empty() and s != last_squad:
			cands.append(s)
	if cands.is_empty() and not squad_alive(last_squad).is_empty():
		cands.append(last_squad)
	cands.shuffle()
	if not cands.is_empty() and SQUAD_KIND[cands[0]] == "rush":   # 돌격 차례: 탄이 걷히고 함께 도는 패턴이 없어질 때까지 조금 기다린다
		if shots_clear(ppos) and lingering.is_empty():
			return cands[0]
		rush_wait += 0.15
		if rush_wait < RUSH_WAIT:
			return -1
	if rush_wait >= RUSH_WAIT and not squad_alive(last_squad).is_empty() and not cands.has(last_squad):   # 돌격만 남아 탄을 기다리다 지쳤으면 직전 편대가 다시 나선다 (멈춰 서지 않게)
		cands.append(last_squad)
	for s in cands:                              # 아직 도는 모함 패턴과 겹쳐도 되는 편대만 (패리 불가 + 근접, 보라 둘은 겹치지 않는다)
		if SQUAD_KIND[s] == "rush":
			if shots_clear(ppos) and lingering.is_empty():
				return s
			continue
		if _fits_lingering(SQUAD_KIND[s]):
			return s
	return -1


## 모함 패턴(대형 포탄·주포)이 아직 도는가 — 같은 모함 패턴이 둘 겹쳐 나오지 않게
func _ship_lingering() -> bool:
	return is_lingering("cannon") or is_lingering("big_shell")


## 지금 도는 모함 패턴들이 이 편대 종류와 함께 나와도 되는가
func _fits_lingering(squad_kind: String) -> bool:
	for la in lingering:
		if not OVERLAP.get(la.kind, []).has(squad_kind):
			return false
	return true


## 편대 s 가 지금 쓸 수 있는 패턴: 편대 패턴 둘은 편대원이 남아 있을 때만 (그물은 두 기 이상), 편대장 패턴은 편대장이 살아 있을 때만.
## 편대장 혼자 남으면 편대장 패턴만 — 대신 강화된다 (공격 모듈이 squad_solo 로 안다)
func squad_modes(s: int) -> Array:
	var all: Array = SQUAD_MODES[SQUAD_KIND[s]]
	var n := squad_alive(s).size()
	var lead := part_alive(leader_of(s))
	var out := []
	if n - (1 if lead else 0) > 0:
		for m in all.slice(0, 2):
			if m == "net" and n < 2:                 # 그물은 두 기 이상이 줄을 이어야 한다
				continue
			out.append(m)
	if lead:
		out.append(all[2])
	return out


## 편대장 혼자 남았는가 (편대장 패턴 강화)
func squad_solo(s: int) -> bool:
	return part_alive(leader_of(s)) and squad_alive(s).size() == 1


## 편대 s 의 패턴: squad_modes 중 직전 패턴은 피한다
func _pick_mode(s: int) -> String:
	var modes := squad_modes(s)
	if modes.size() > 1:
		modes.erase(last_mode[s])
	return modes[randi() % modes.size()]


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_ship()
	for f in flung:
		_draw_fling_trail(f)
		var st := fling_state(f)
		_draw_drone(st[0], int(f["i"]), float(st[1]), 1.0, float(f["t"]) * 14.0)
		_draw_burning(st[0], float(st[1]))
	_draw_drones()
	_draw_part_marks()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


## 부서져 날아가는 드론의 불꽃 꼬리: 지나온 길을 따라 불덩이 → 검은 연기로 (모함에 꽂히는 길이 눈에 보이게)
func _draw_fling_trail(f: Dictionary) -> void:
	var tt := float(f["t"])
	var n := 44
	var pts: Array[Vector2] = []
	var scs: Array[float] = []
	for k in n + 1:                                                 # 0 = 드론 바로 뒤 … n = 꼬리 끝
		var back := k * 0.018
		if tt - back < 0.0:
			break
		var st := fling_state(f, tt - back)
		var u := float(k) / n
		pts.append(Vector2(st[0]) + Vector2(sin(t * 23.0 + k * 0.9), cos(t * 19.0 + k * 1.3)) * 9.0 * u * float(st[1]))
		scs.append(st[1])
	for k in range(pts.size() - 2, -1, -1):                         # 꼬리 끝(연기)부터 그려서 불길이 위에 오게
		var u := float(k) / n
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var sc: float = scs[k]
		if u < 0.5:                                                 # 불길: 굵고 밝게 → 가늘고 붉게
			var w := lerpf(46.0, 18.0, u / 0.5) * sc
			draw_line(a, b, Color(1.0, 0.4, 0.08, 0.3 * (1.0 - u)), w * 1.8)
			draw_line(a, b, Color(1.0, 0.62 - 0.3 * u, 0.18, 0.9 * (1.0 - u * 1.4)), w)
			draw_line(a, b, Color(1.0, 0.95, 0.7, 0.9 * maxf(0.0, 1.0 - u * 3.0)), w * 0.4)
		else:                                                       # 연기: 넓어지며 옅어진다
			draw_line(a, b, Color(0.17, 0.16, 0.17, 0.5 * (1.0 - u)), lerpf(24.0, 60.0, u) * sc)


## 날아가는 드론 몸에 붙은 불길
func _draw_burning(p: Vector2, sc: float) -> void:
	var fl := 0.7 + 0.3 * sin(t * 31.0)
	draw_circle(p, 46.0 * sc * fl, Color(1.0, 0.5, 0.12, 0.35))
	for k in 3:
		var q := p + Vector2.from_angle(t * 9.0 + k * TAU / 3.0) * 22.0 * sc
		draw_circle(q, 16.0 * sc * fl, Color(1.0, 0.75, 0.3, 0.8))


## 배경의 항공모함 (선체 기준 좌표로 그린 뒤 ship_to_world 로 옮긴다): 장갑 선체 + 비행갑판 + 함교 + 갑판 포탑 + 격납고 + 하부 포대 + 주포 + 엔진.
## 먼 거리의 옅은 안개를 덮는다
func _draw_ship() -> void:
	var sh := Vector2(sin(t * 47.0), cos(t * 39.0)) * 10.0 * hull_shake * hull_shake
	draw_set_transform(ship_to_world(Vector2.ZERO) + sh, 0.0, Vector2(SHIP_SCALE, SHIP_SCALE))
	# 선체
	var hull := PackedVector2Array([Vector2(-1820, -190), Vector2(1600, -190), Vector2(1860, -150), Vector2(1700, 40), Vector2(1450, 230),
		Vector2(-1350, 260), Vector2(-1640, 140), Vector2(-1820, -20)])
	draw_colored_polygon(hull, C_HULL)
	draw_colored_polygon(PackedVector2Array([Vector2(-1640, 140), Vector2(1580, 140), Vector2(1450, 230), Vector2(-1350, 260)]), C_HULL_DARK)   # 아래쪽 그늘
	for row in [-80.0, 30.0]:                                          # 장갑판 줄 + 리벳
		draw_line(Vector2(-1800, row), Vector2(1780, row), Color(C_HULL_DARK, 0.9), 5.0)
		for k in 36:
			draw_circle(Vector2(-1760 + k * 100.0, row - 14.0), 3.0, Color(C_RIM, 0.35))
	for k in 12:                                                       # 세로 이음매
		var x := -1650.0 + k * 280.0
		draw_line(Vector2(x, -180), Vector2(x - 30, 250), Color(C_HULL_DARK, 0.8), 4.0)
	for k in 8:                                                        # 선체 창 줄
		for j in 6:
			var on := 0.5 + 0.5 * sin(t * 0.7 + k * 1.3 + j * 2.1)
			draw_rect(Rect2(-1500 + k * 360.0 + j * 34.0, -50, 20, 10), Color(C_WINDOW, 0.15 + 0.35 * on))
	for k in 5:                                                        # 뱃머리 경고 줄무늬
		var x := 1500.0 + k * 60.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -150), Vector2(x + 30, -150), Vector2(x - 10, -60), Vector2(x - 40, -60)]), Color(1.0, 0.7, 0.2, 0.35))
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, Color(C_RIM, 0.55), 5.0)
	# 비행갑판
	draw_rect(Rect2(-1900, -232, 3800, 46), C_HULL_DARK)
	draw_line(Vector2(-1900, -232), Vector2(1880, -232), Color(C_RIM, 0.6), 4.0)
	for k in 30:                                                       # 활주로 표시 + 유도등
		draw_line(Vector2(-1800 + k * 120.0, -209), Vector2(-1750 + k * 120.0, -209), Color(1, 1, 1, 0.25), 3.0)
		var on := 0.5 + 0.5 * sin(t * 3.0 - k * 0.5)
		draw_circle(Vector2(-1800 + k * 120.0, -226), 5.0, Color(C_LIGHT, 0.25 + 0.55 * on))
	for k in 5:                                                        # 갑판 포탑 (쌍열 포신이 천천히 돈다)
		var b := Vector2(-1500 + k * 520.0, -240)
		var a := -PI * 0.5 + sin(t * 0.6 + k) * 0.7
		draw_circle(b, 46.0, C_HULL)
		draw_arc(b, 46.0, PI, TAU, 16, Color(C_RIM, 0.5), 3.0)
		for sd in [-12.0, 12.0]:
			var o: Vector2 = b + Vector2.from_angle(a).orthogonal() * sd
			draw_line(o, o + Vector2.from_angle(a) * 110.0, C_HULL_DARK, 12.0)
	# 함교
	var isl := PackedVector2Array([Vector2(700, -232), Vector2(1120, -232), Vector2(1060, -560), Vector2(780, -560)])
	draw_colored_polygon(isl, C_HULL)
	draw_colored_polygon(PackedVector2Array([Vector2(820, -560), Vector2(1020, -560), Vector2(990, -700), Vector2(850, -700)]), C_HULL_LIT)
	draw_polyline(PackedVector2Array([isl[0], isl[3], isl[2], isl[1]]), Color(C_RIM, 0.5), 4.0)
	for k in 4:
		for j in 5:
			var on := 0.5 + 0.5 * sin(t * 1.1 + k + j * 1.7)
			draw_rect(Rect2(800 + j * 48.0, -520 + k * 62.0, 30, 16), Color(C_WINDOW, 0.25 + 0.4 * on))
	draw_rect(Rect2(870, -680, 100, 22), Color(C_WINDOW, 0.6))       # 함교 창
	draw_line(Vector2(920, -700), Vector2(920, -900), C_HULL_DARK, 14.0)   # 마스트
	draw_line(Vector2(860, -820), Vector2(980, -820), C_HULL_DARK, 8.0)
	var ra := t * 1.6
	draw_line(Vector2(920, -880) - Vector2.from_angle(ra) * Vector2(110, 18), Vector2(920, -880) + Vector2.from_angle(ra) * Vector2(110, 18), C_RIM, 8.0)
	draw_circle(Vector2(920, -910), 10.0, Color(1.0, 0.3, 0.25, 0.4 + 0.5 * float(int(t * 2.0) % 2)))
	draw_rect(Rect2(1070, -400, 60, 168), C_HULL_DARK)              # 굴뚝
	for k in 3:
		var life := fmod(t * 0.4 + k * 0.33, 1.0)
		draw_circle(Vector2(1100 + life * 60.0, -420 - life * 220.0), 26.0 + life * 50.0, Color(0.3, 0.32, 0.36, 0.3 * (1.0 - life)))
	# 격납고: 남은 편대가 있으면 안쪽이 그 편대 색으로 밝다
	for s in HANGARS.size():
		var h: Vector2 = HANGARS[s]
		var alive := not squad_alive(s).is_empty()
		draw_rect(Rect2(h + Vector2(-190, -80), Vector2(380, 160)), C_HULL_DARK)
		draw_rect(Rect2(h + Vector2(-170, -62), Vector2(340, 124)), Color(SQUAD_COL[s], 0.4 if alive else 0.04))
		for g in 5:
			draw_line(h + Vector2(-170, -62 + g * 31.0), h + Vector2(170, -62 + g * 31.0), Color(C_HULL_DARK, 0.85), 4.0)
		draw_rect(Rect2(h + Vector2(-190, -80), Vector2(380, 160)), Color(C_RIM, 0.5), false, 4.0)
		for sd in [-1.0, 1.0]:                                          # 유도등
			var on := 0.5 + 0.5 * sin(t * 6.0 + s + sd)
			draw_circle(h + Vector2(sd * 210.0, -60), 9.0, Color(SQUAD_COL[s], (0.3 + 0.6 * on) if alive else 0.1))
	# 하부 포대
	for k in 9:
		var b := Vector2(-1250 + k * 300.0, 245)
		draw_circle(b, 40.0, C_HULL_DARK)
		draw_line(b, b + Vector2(sin(t * 0.8 + k) * 30.0, 90), C_HULL, 16.0)
	# 주포 (뱃머리 아래): 포신이 겨누는 쪽을 향하고, 모을수록 포구가 달아오른다
	_draw_main_gun(sh)
	_draw_traffic()
	# 고물 엔진
	for k in 4:
		var e := Vector2(-1830, -130 + k * 80.0)
		draw_rect(Rect2(e + Vector2(-60, -30), Vector2(70, 60)), C_HULL_DARK)
		draw_circle(e + Vector2(-70, 0), 40.0 + 8.0 * sin(t * 9.0 + k), Color(0.45, 0.7, 1.0, 0.3))
		draw_circle(e + Vector2(-70, 0), 20.0, Color(0.85, 0.95, 1.0, 0.75))
	for sd in [-1.0, 1.0]:                                             # 항해등 (양 끝)
		var on := float(int(t * 1.5 + (0.5 if sd > 0 else 0.0)) % 2)
		draw_circle(Vector2(sd * 1820.0, -250), 12.0, Color(1.0, 0.25, 0.2, 0.3 + 0.6 * on) if sd < 0 else Color(0.3, 1.0, 0.45, 0.3 + 0.6 * on))
	# 꽂힌 드론이 타는 자리
	for b in burns:
		var p: Vector2 = b["pos"]
		var fl := 0.6 + 0.4 * sin(t * 13.0 + p.x)
		draw_circle(p, 60.0, Color(0.05, 0.03, 0.02, 0.9))
		draw_circle(p, 34.0 * fl, Color(1.0, 0.5, 0.15, 0.85))
		draw_circle(p, 15.0 * fl, Color(1.0, 0.9, 0.5))
		for k in 3:
			var life := fmod(t * 0.5 + k * 0.33 + p.x * 0.001, 1.0)
			draw_circle(p + Vector2(sin(t + k) * 24.0, -50.0 - life * 260.0), 24.0 + life * 50.0, Color(0.2, 0.2, 0.24, 0.4 * (1.0 - life)))
	draw_colored_polygon(PackedVector2Array([Vector2(-2000, -950), Vector2(2000, -950), Vector2(2000, 300), Vector2(-2000, 300)]), Color(C_HAZE, 0.38))   # 거리의 안개 (배경으로 물러나 보이게)
	if split_k() > 0.0:                                                # 마지막 편대가 부서졌다: 금이 번지고 선체가 갈라진다 (안개 위에 또렷하게)
		_draw_hull_split(split_k())
	draw_set_transform(Vector2.ZERO, 0.0)
	if phase >= 2 and not dead:
		var cp := core_draw_pos()
		var deck := ship_to_world(DECK_CORE)
		if split_k() > SPLIT_EMERGE:
			draw_line(deck, cp, Color(C_CORE, 0.25), 10.0)             # 모함과 이어진 동력선
			draw_line(deck, cp, Color(1.0, 0.85, 0.6, 0.5), 3.0)
		if phase == 3:
			_draw_exposed_core(CORE_POS, CORE_R, C_CORE)
		elif split_k() > SPLIT_EMERGE:                                 # 갈라진 틈에서 나와 내려오는 코어
			var k := clampf((split_k() - SPLIT_EMERGE) / (1.0 - SPLIT_EMERGE), 0.0, 1.0)
			_soft_glow(cp, CORE_R * 3.0, C_CORE, 0.4)
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE * 0.6, 1.0, k), Color(C_CORE, 0.9))
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE * 0.6, 1.0, k) * 0.5, Color(1, 0.95, 0.8))
		if shield_flash > 0.0:                                          # 약한 일격이 튕김
			draw_arc(CORE_POS, CORE_R * 1.8, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * shield_flash), 6.0)
	if dead:
		var kk := minf(1.0, death_t / 1.4)
		draw_circle(CORE_POS, CORE_R + kk * 500.0, Color(C_CORE, 0.5 * (1.0 - kk)))
		draw_arc(CORE_POS, CORE_R + kk * 900.0, 0.0, TAU, 48, Color(1, 0.95, 0.8, 1.0 - kk), 8.0)


## 드론은 기체 외곽을 따라 윤곽선을 그린다 (_draw_drone)
func _rim_part(_i: int) -> bool:
	return true


## 모함 둘레의 작은 기체들 (그림만, 선체 기준): 멀리서 점처럼 보이는 함재기 편대가 선체를 따라 순찰하고, 몇 대는 격납고를 드나든다.
## 작은 삼각형 몸체 + 깜빡이는 항법등 + 엔진 불빛 (거대한 모함의 크기와 살아 있는 기지라는 설정을 보탠다)
func _draw_traffic() -> void:
	for f in 4:                                                        # 순찰 편대 넷: 선체 위아래를 천천히 가로지른다
		var dir := 1.0 if f % 2 == 0 else -1.0
		var y: float = [-420.0, -300.0, -560.0, -370.0][f]          # 모두 갑판 위 (경기장으로 내려와 적처럼 보이지 않게)
		var x := fposmod(t * 140.0 * (1.0 + f * 0.15) * dir + f * 900.0, 4400.0) - 2200.0
		for k in 3:                                                    # 세 대씩 V 자
			var p := Vector2(x - dir * k * 46.0, y + (k - 1) * 30.0 * float(k != 0) * (1.0 if k == 1 else -1.0) + sin(t * 1.3 + f) * 20.0)
			_draw_tiny_craft(p, Vector2(dir, 0.0), f * 3 + k)
	for h in HANGARS.size():                                           # 격납고를 드나드는 몇 대 (나왔다가 위로 돌아 나간다)
		var u := fmod(t * 0.18 + h * 0.37, 1.0)
		var base: Vector2 = HANGARS[h]
		var p := base + Vector2(sin(u * TAU) * 260.0, -u * 760.0)
		var d := Vector2(cos(u * TAU) * 260.0 * TAU, -760.0).normalized()
		if u < 0.85:
			_draw_tiny_craft(p, d, 20 + h)


func _draw_tiny_craft(p: Vector2, d: Vector2, seed_i: int) -> void:
	var n := d.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + d * 22.0, p - d * 14.0 + n * 14.0, p - d * 8.0, p - d * 14.0 - n * 14.0]), Color(0.3, 0.33, 0.4))
	draw_circle(p - d * 14.0, 5.0, Color(0.6, 0.85, 1.0, 0.8))         # 엔진 불빛
	if int(t * 2.0 + seed_i * 0.7) % 2 == 0:                           # 항법등
		draw_circle(p + n * 13.0, 3.0, Color(1.0, 0.3, 0.25, 0.9))
		draw_circle(p - n * 13.0, 3.0, Color(0.3, 1.0, 0.45, 0.9))


## 주포 (뱃머리 아래, 선체 기준 좌표계 안에서): 선체에 박힌 장갑 포탑 + 겨누는 쪽으로 도는 각진 포가 + 네모난 포신 셋 + 슬롯 달린 포구 제동기.
## 탄막 요새 v0.72 의 거대 포 생김새를 다시 쓴다. 모을수록 포구가 달아오르고, 쏘면 포신이 뒤로 밀린다
func _draw_main_gun(sh: Vector2) -> void:
	var cb := CANNON_BASE
	draw_rect(Rect2(cb + Vector2(-190, -150), Vector2(380, 150)), C_HULL_DARK)          # 선체에 박힌 포탑 받침
	draw_rect(Rect2(cb + Vector2(-190, -150), Vector2(380, 150)), Color(C_RIM, 0.5), false, 4.0)
	for k in 4:
		draw_line(cb + Vector2(-170 + k * 110.0, -140), cb + Vector2(-170 + k * 110.0, -10), C_HULL, 8.0)
	var ship_x := Transform2D(0.0, Vector2(SHIP_SCALE, SHIP_SCALE), 0.0, ship_to_world(Vector2.ZERO) + sh)
	draw_set_transform_matrix(ship_x * Transform2D(cannon_aim, cb))
	var L := GUN_LEN - 70.0 * cannon_recoil
	var mantlet := PackedVector2Array([Vector2(-150, -150), Vector2(10, -150), Vector2(70, -100), Vector2(70, 100), Vector2(10, 150), Vector2(-150, 150)])
	draw_colored_polygon(mantlet, C_GUN_SIDE)
	draw_colored_polygon(PackedVector2Array([Vector2(-130, -128), Vector2(0, -128), Vector2(48, -88), Vector2(48, 88), Vector2(0, 128), Vector2(-130, 128)]), C_GUN_FACE)
	for q in 3:                                                        # 포가 장갑 띠
		draw_line(Vector2(-110 + q * 45, -120), Vector2(-110 + q * 45, 120), C_HULL_DARK, 6.0)
	for y in [-64.0, 0.0, 64.0]:                                       # 네모난 포신 셋
		draw_rect(Rect2(60.0, y - 24.0, L - 60.0, 48.0), C_GUN_SIDE)
		draw_rect(Rect2(60.0, y - 16.0, L - 60.0, 32.0), C_GUN_FACE)
		draw_line(Vector2(60.0, y - 16.0), Vector2(L, y - 16.0), Color(C_RIM, 0.4), 3.0)
		for q in 2:                                                    # 포신 고정 띠
			var x := 60.0 + (L - 60.0) * (0.3 + q * 0.35)
			draw_rect(Rect2(x - 10.0, y - 30.0, 20.0, 60.0), C_HULL_DARK)
		draw_rect(Rect2(L, y - 32.0, 56.0, 64.0), C_HULL_DARK)           # 포구 제동기 (네모, 옆으로 슬롯)
		for q in 2:
			draw_rect(Rect2(L + 10.0 + q * 22.0, y - 32.0, 10.0, 14.0), Color(0.02, 0.02, 0.02))
			draw_rect(Rect2(L + 10.0 + q * 22.0, y + 18.0, 10.0, 14.0), Color(0.02, 0.02, 0.02))
		if cannon_glow > 0.0:                                          # 모을수록 포구가 달아오른다
			draw_rect(Rect2(L + 46.0, y - 14.0, 14.0, 28.0), Color(1.0, 0.75, 0.85, 0.4 + 0.6 * cannon_glow))
	if cannon_glow > 0.0:
		_soft_glow(Vector2(L + 70.0, 0.0), 140.0 * cannon_glow + 30.0, Color(1.0, 0.62, 0.86), 0.5 * cannon_glow)
	draw_set_transform_matrix(ship_x)


## 선체가 갈라진다 (선체 기준 좌표계 안에서, k = 0~1): 가운데에서 금이 번개처럼 선체 끝까지 번지고(빛나는 균열),
## 가운데가 들쭉날쭉하게 벌어지며 안에서 붉은 빛이 새고, 그 틈에서 코어가 나온다 (core_draw_pos)
func _draw_hull_split(k: float) -> void:
	var crack := clampf(k / SPLIT_CRACK, 0.0, 1.0)
	var open := clampf((k - SPLIT_OPEN) / (1.0 - SPLIT_OPEN), 0.0, 1.0)
	var o := DECK_CORE
	var dirs := [0.05, -0.28, 0.32, PI - 0.05, PI + 0.3, PI - 0.33, -PI * 0.5, PI * 0.5, -0.9, PI + 0.95]
	var lens := [1750.0, 1500.0, 1450.0, 1750.0, 1450.0, 1400.0, 300.0, 260.0, 600.0, 650.0]
	for c in dirs.size():                                              # 번지는 금
		var d := Vector2.from_angle(float(dirs[c]))
		var n := d.orthogonal()
		var pts := PackedVector2Array([o])
		var segs := 14
		var reach: float = float(lens[c]) * crack
		for q in range(1, segs + 1):
			var u := float(q) / segs
			var p := o + d * reach * u + n * sin(q * 2.7 + c * 1.9) * 38.0 * u
			p.y = clampf(p.y, -225.0, 255.0)
			pts.append(p)
		draw_polyline(pts, Color(1.0, 0.45, 0.12, 0.35), 26.0)
		draw_polyline(pts, Color(1.0, 0.75, 0.4, 0.9), 9.0)
		draw_polyline(pts, Color(1.0, 0.97, 0.85), 3.0)
	if open <= 0.0:
		return
	var w := 30.0 + 320.0 * open                                       # 벌어진 틈 (들쭉날쭉)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for q in 9:
		var y := lerpf(-240.0, 270.0, q / 8.0)
		var jag := sin(q * 3.1) * 40.0 * open
		left.append(Vector2(o.x - w + jag, y))
		right.append(Vector2(o.x + w + jag * 0.6, y))
	var gap := left.duplicate()
	for q in range(right.size() - 1, -1, -1):
		gap.append(right[q])
	draw_colored_polygon(gap, Color(0.05, 0.015, 0.01))
	_soft_glow(o, 260.0 + 260.0 * open, C_CORE, 0.45 * open)          # 안에서 새는 빛
	draw_polyline(left, Color(1.0, 0.6, 0.25, 0.9), 10.0)              # 찢어진 가장자리가 달아오른다
	draw_polyline(right, Color(1.0, 0.6, 0.25, 0.9), 10.0)
	draw_polyline(left, Color(1.0, 0.95, 0.75), 3.0)
	draw_polyline(right, Color(1.0, 0.95, 0.75), 3.0)


## 드론들: 차례인 편대는 밝게, 나머지는 조금 어둡게 포위망을 지킨다
func _draw_drones() -> void:
	for i in part_count():
		if not part_alive(i):
			continue
		var on := squad_of(i) == active
		if not deployed:
			continue
		var emerge := smoothstep(0.0, 1.0, deploy_t / DEPLOY_TIME)
		_draw_drone(dpos[i], i, lerpf(0.35, 1.0, emerge), 1.0 if on or active < 0 else 0.7, 0.0, true)


## target = 살아 있는 드론: 차지·조준 중이거나 막 맞았으면 기체 외곽이 붉게 빛난다 (평소엔 강철색 테두리).
## 편대 색은 조종석 창(편대장은 감지 눈)과 추진기 불꽃에만 — 윤곽선으로 편대를 칠하지 않는다 (v0.113)
func _draw_drone(p: Vector2, i: int, scale_k: float, lit: float, spin: float, target := false) -> void:
	var col: Color = SQUAD_COL[squad_of(i)]
	var rim := Color(C_RIM, 0.35 + 0.3 * lit)                      # 강철색 테두리
	var hot := false
	if target:
		var rc := rim_color(i)
		rim = rim.lerp(Color(rc, 1.0), rc.a)
		hot = rc.a > 0.3
	var g: float = dglow[i] if i < dglow.size() else 0.0
	var a: float = (daim[i] if i < daim.size() else 0.0) + spin
	if is_leader(i):
		draw_set_transform(p, a, Vector2.ONE * LEADER_SIZE * scale_k)
		_leader_body(col, lit, g, rim, hot)
	else:
		draw_set_transform(p, a, Vector2.ONE * WING_SIZE * scale_k)
		_wing_body(col, lit, g, rim, hot)
	draw_set_transform(Vector2.ZERO, 0.0)


static func _mirror(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(Vector2(q.x, -q.y))
	return out


func _poly(pts: Array, fill: Color, edge: Color, w: float, glow := false) -> void:
	var pa := PackedVector2Array(pts)
	draw_colored_polygon(pa, fill)
	var ol := pa.duplicate()
	ol.append(pa[0])
	if glow:                                                           # 표적 윤곽선: 바깥으로 번진다
		draw_polyline(ol, Color(edge, edge.a * 0.3), w * 3.5)
	draw_polyline(ol, edge, w)


## 편대원: 날렵한 요격기 (단위 크기, 앞 = +x). 앞으로 젖힌 날개 + 쌍 꼬리날개 + 날개 끝 기관포 + 편대 색 조종석 + 편대 색 불꽃의 쌍 엔진
func _wing_body(col: Color, lit: float, g: float, rim: Color, hot: bool) -> void:
	var body := C_DRONE.lightened(0.12 * lit)
	var dark := C_DRONE_DARK
	var edge := rim
	var wing := [Vector2(0.2, 0.14), Vector2(-0.05, 0.92), Vector2(-0.38, 0.95), Vector2(-0.42, 0.16)]
	for side in [wing, _mirror(wing)]:
		_poly(side, dark, edge, 0.04, hot)
	for sd in [1.0, -1.0]:                                             # 날개 판 이음 + 날개 끝 기관포 (쏠 때만 포구가 달아오른다)
		draw_line(Vector2(0.05, 0.55 * sd), Vector2(-0.28, 0.6 * sd), Color(C_RIM, 0.25), 0.03)
		draw_line(Vector2(-0.2, 0.93 * sd), Vector2(0.28, 0.93 * sd), dark, 0.07)
		if g > 0.0:
			draw_circle(Vector2(0.3, 0.93 * sd), 0.035, Color(col, g))
	var fin := [Vector2(-0.55, 0.12), Vector2(-0.95, 0.45), Vector2(-0.9, 0.12)]
	for side in [fin, _mirror(fin)]:
		_poly(side, dark, edge, 0.035, hot)
	var hull := [Vector2(1.05, 0.0), Vector2(0.6, 0.12), Vector2(-0.2, 0.19), Vector2(-0.8, 0.15), Vector2(-0.9, 0.0),
		Vector2(-0.8, -0.15), Vector2(-0.2, -0.19), Vector2(0.6, -0.12)]
	_poly(hull, body, edge, 0.035, hot)
	draw_line(Vector2(0.55, 0), Vector2(-0.75, 0), Color(dark, 0.9), 0.025)   # 등줄기
	draw_line(Vector2(-0.1, 0.12), Vector2(-0.1, -0.12), Color(dark, 0.9), 0.02)
	_poly([Vector2(0.62, 0.0), Vector2(0.42, 0.08), Vector2(0.18, 0.07), Vector2(0.18, -0.07), Vector2(0.42, -0.08)],
		Color(col.lightened(0.2), 0.55 + 0.35 * g), Color(1, 1, 1, 0.4), 0.015)   # 조종석
	for sd in [0.08, -0.08]:                                           # 쌍 엔진 (편대 색 불꽃)
		draw_circle(Vector2(-0.9, sd), 0.07, dark)
		var fl := 0.12 + 0.05 * sin(t * 30.0 + sd * 40.0)
		draw_circle(Vector2(-1.02 - fl, sd), 0.09, Color(col, 0.35 * lit))
		draw_circle(Vector2(-0.98 - fl, sd), 0.07, Color(col.lightened(0.2), 0.7 * lit))
		draw_circle(Vector2(-0.95, sd), 0.04, Color(1, 0.97, 0.9, 0.85 * lit))


## 편대장: 육중한 지휘 포격기 (단위 크기, 앞 = +x). 두꺼운 장갑 몸통 + 넓은 날개 끝 엔진 포드(편대 색 불꽃) + 쌍 주포 + 편대 색 감지 눈 + 계급 갈매기 문장
func _leader_body(col: Color, lit: float, g: float, rim: Color, hot: bool) -> void:
	var body := C_DRONE.lightened(0.14 * lit)
	var dark := C_DRONE_DARK
	var edge := rim
	var wing := [Vector2(0.3, 0.28), Vector2(-0.15, 1.02), Vector2(-0.62, 1.0), Vector2(-0.55, 0.32)]
	for side in [wing, _mirror(wing)]:
		_poly(side, dark, edge, 0.03, hot)
	for sd in [1.0, -1.0]:                                             # 날개 끝 엔진 포드
		_poly([Vector2(-0.05, 0.9 * sd), Vector2(-0.75, 0.9 * sd), Vector2(-0.8, 1.12 * sd), Vector2(-0.05, 1.12 * sd)], body, edge, 0.03, hot)
		var fl := 0.1 + 0.04 * sin(t * 26.0 + sd * 3.0)
		draw_circle(Vector2(-0.9 - fl, 1.01 * sd), 0.1, Color(col, 0.35 * lit))
		draw_circle(Vector2(-0.85 - fl, 1.01 * sd), 0.08, Color(col.lightened(0.2), 0.7 * lit))
		draw_circle(Vector2(-0.82, 1.01 * sd), 0.05, Color(1, 0.97, 0.9, 0.85 * lit))
		draw_line(Vector2(-0.1, 0.62 * sd), Vector2(-0.45, 0.66 * sd), Color(C_RIM, 0.25), 0.03)   # 날개 판 이음
	for sd in [0.15, -0.15]:                                           # 쌍 주포
		draw_line(Vector2(0.35, sd), Vector2(1.2, sd), dark, 0.11)
		draw_line(Vector2(0.4, sd), Vector2(1.18, sd), Color(C_RIM, 0.5), 0.03)
		if g > 0.0:                                                    # 쏠 때만 포구가 달아오른다
			draw_circle(Vector2(1.2, sd), 0.06, Color(col, g))
	var hull := [Vector2(0.85, 0.0), Vector2(0.55, 0.34), Vector2(-0.45, 0.4), Vector2(-0.82, 0.22), Vector2(-0.82, -0.22),
		Vector2(-0.45, -0.4), Vector2(0.55, -0.34)]
	_poly(hull, body, edge, 0.035, hot)
	_poly([Vector2(0.45, 0.0), Vector2(0.2, 0.24), Vector2(-0.35, 0.26), Vector2(-0.35, -0.26), Vector2(0.2, -0.24)],
		C_HULL_LIT.darkened(0.2 * (1.0 - lit)), Color(dark, 0.9), 0.025)   # 등 장갑판
	for k in 3:                                                        # 계급 갈매기 문장 (도장, 강철색)
		var x := -0.15 - k * 0.14
		draw_polyline(PackedVector2Array([Vector2(x - 0.08, 0.16), Vector2(x, 0.0), Vector2(x - 0.08, -0.16)]), Color(C_RIM, 0.45 + 0.2 * lit), 0.04)
	draw_circle(Vector2(0.28, 0.0), 0.12, dark)                         # 감지 눈 (곧 쏘면 커진다)
	draw_circle(Vector2(0.28, 0.0), 0.08 + 0.04 * g, Color(col.lightened(0.3), 0.7 + 0.3 * g))
	draw_circle(Vector2(0.3, -0.03), 0.025, Color(1, 1, 1, 0.8))
	for sd in [0.2, 0.0, -0.2]:                                        # 꼬리 엔진 셋
		draw_circle(Vector2(-0.86, sd), 0.06, dark)
		draw_circle(Vector2(-0.94, sd), 0.045, Color(col.lightened(0.3), 0.75 * lit))

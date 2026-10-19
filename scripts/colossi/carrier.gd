extends "res://scripts/colossus_base.gd"
## 콜로서스 ⑤ 모함 (소환형). 기획: docs/BOSS_carrier.md
## 거대한 항공모함이 경기장 위쪽에 정박해 있다 — 배경이라 닿지 않지만 화면 위쪽을 가득 채우고 화면을 따라 천천히 움직인다 (ship_to_world, 원근).
## 플레이어가 실제로 싸우는 상대는 모함이 내보낸 드론 편대 셋(3기씩, 모두 9기)이다.
## 아홉 기는 늘 플레이어를 가운데 둔 둥근 포위망을 유지한다 (플레이어를 따라오고, 천천히 돌고, 숨 쉬듯 좁혀졌다 넓어진다).
## 차례가 온 편대만 나서서 플레이어를 노린다. 편대마다 패턴 셋 = 편대 패턴 둘 + 편대장 패턴 하나 (squad_*.gd):
##   탄막 편대(금): 조준 부채 / 조준 연사 / 편대장 유도탄
##   돌격 편대(진홍, 근접 → 요격): 나란히 돌진 / 연속 돌진 / 편대장 창 돌격
##   결계 편대(보라, 패리 불가 → 퍼펙트 회피): 조여 드는 그물 / 꿰뚫는 창 / 편대장 고리 파동
## 편대 차례 사이에는 모함 본체가 쏜다: 대형 포탄 한 발(터지며 잔탄) ↔ 주포(겨누는 아주 굵은 패리 불가 광선 한 줄기).
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
const LEADER_HP := 40                        # 편대장: PERFECT 리버스 드라이브 세 방쯤
const WING_HP := 25                          # 편대원: 두 방쯤
const ARMOR_HP := 270                        # = 아홉 기 체력 합 (게이지·플레이 기록용)
const CHIP := 1                              # 약한 일격(돌진·차지)은 이만큼만
const WING_SIZE := 62.0                      # 편대원 그림 크기
const LEADER_SIZE := 96.0                    # 편대장 그림 크기 (육중한 지휘기)
const WING_R := 50.0                         # 판정 반지름
const LEADER_R := 74.0

# ── 포위망 ─────────────────────────────────────────────
const RING_R := 690.0
const RING_BREATHE := 70.0                   # 숨 쉬듯 좁혀졌다 넓어진다
const RING_SPIN := 0.25                      # 포위망 회전 (rad/s)
const WING_SPREAD := 0.28                    # 편대장 양옆 편대원 간격 (라디안)
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
const CANNON_LEN := 330.0
const BARRIER_R := 120.0                     # (open_barrage) 코어 둘레에서 탄이 나오는 반지름의 두 배

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.25, 0.5)
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
var flung: Array[Dictionary] = []            # 부서져 모함으로 날아가는 드론 {from, dir, t, to(선체 기준), i}
var burns: Array[Dictionary] = []            # 선체에 꽂혀 타는 자리 {pos(선체 기준), t}
var cannon_aim := PI * 0.5                   # 주포 포신 방향
var cannon_glow := 0.0
var hull_shake := 0.0
var deck_k := 0.0                            # 갑판이 갈라진 정도 (0~1)
var shield_flash := 0.0                      # 코어에 약한 일격이 튕김 (main 이 채운다)
var shield_hit_n := Vector2.UP


func _init() -> void:
	open_time = 2.0
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
	active = -1
	last_squad = -1
	last_mode = ["", "", ""]
	squad_turn = true
	last_ship = ""
	rush_wait = 0.0
	flung.clear()
	burns.clear()
	cannon_aim = PI * 0.5
	cannon_glow = 0.0
	hull_shake = 0.0
	deck_k = 0.0
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


## 포위망 위 드론 i 의 자리: 플레이어를 가운데 두고 편대마다 120°씩, 편대장이 가운데·편대원이 양옆. 돌고 숨 쉬고, 기체마다 조금씩 흔들린다
func ring_slot(i: int) -> Vector2:
	var s := squad_of(i)
	var k := i % PER
	var a := ring_a + s * TAU / SQUADS + (0.0 if k == 0 else (WING_SPREAD if k == 1 else -WING_SPREAD))
	var r := RING_R + RING_BREATHE * sin(t * 0.7) + 25.0 * sin(t * 1.7 + i * 1.3)
	return ring_c + Vector2.from_angle(a) * r + Vector2(sin(t * 2.1 + i), cos(t * 1.8 + i * 0.7)) * 16.0


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


## 탄 속도: 드론이 줄수록 조금씩 빨라진다
func bolt_mult() -> float:
	return (1.0 + 0.04 * (part_count() - parts_left())) * (1.0 + LEVEL_SPEEDUP * level)


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


func set_cannon_glow(v: float) -> void:
	cannon_glow = maxf(cannon_glow, clampf(v, 0.0, 1.0))


## (open_barrage 가 부른다) 발광할 곳이 따로 없다
func set_glow(_i: int, _v: float) -> void:
	pass


## 떨어져 나온 코어의 그림 위치: 페이즈 2 동안 갑판에서 CORE_POS 로 내려온다 (원근으로 커지며)
func core_draw_pos() -> Vector2:
	if phase < 2:
		return ship_to_world(DECK_CORE)
	if phase == 3 or dead:
		return CORE_POS
	var k := clampf(open_t / maxf(open_time, 0.1), 0.0, 1.0)
	return ship_to_world(DECK_CORE).lerp(CORE_POS, k * k * (3.0 - 2.0 * k))


# ── 진행 ───────────────────────────────────────────────
const FLING_KNOCK := 0.28                    # 맞은 쪽으로 튕기는 시간
const FLING_FLY := 0.85                      # 모함까지 날아가는 시간 (원근으로 작아진다)
const FLING_KNOCK_D := 240.0


## 날아가는 드론의 지금 위치와 크기 배율
func fling_state(f: Dictionary) -> Array:
	var tt := float(f["t"])
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
	deck_k = move_toward(deck_k, 1.0 if phase >= 2 else 0.0, dt / maxf(open_time, 0.1))
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
	ring_a += RING_SPIN * dt
	ring_c = look_at                             # 포위망은 늘 플레이어를 가운데 둔다 (look_at = 부드럽게 따라가는 플레이어 위치)
	for i in part_count():
		if not part_alive(i):
			continue
		if not dcmd[i]:
			dwant[i] = _in_arena(ring_slot(i))
			daim_want[i] = (look_at - dpos[i]).angle()
		dpos[i] = dpos[i].lerp(dwant[i], 1.0 - exp(-MOVE_K * dt))
		daim[i] = lerp_angle(daim[i], daim_want[i], 1.0 - exp(-8.0 * dt))
		dcmd[i] = false


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
		return
	squad_turn = true                            # 모함 차례: 대형 포탄 ↔ 주포 번갈아
	last_ship = "cannon" if last_ship == "big_shell" else "big_shell"
	if last_ship == "big_shell":
		start_attack(CarrierShell.new())
	else:
		start_attack(CarrierCannon.new())


## 다음 편대: 살아 있는 편대 중 직전과 다른 것 (하나만 남으면 그 편대). 돌격은 탄이 걷혔을 때만 (RUSH_WAIT 를 넘기면 다른 편대로)
func _pick_squad(ppos: Vector2) -> int:
	var cands: Array[int] = []
	for s in SQUADS:
		if not squad_alive(s).is_empty() and s != last_squad:
			cands.append(s)
	if cands.is_empty() and not squad_alive(last_squad).is_empty():
		cands.append(last_squad)
	cands.shuffle()
	for s in cands:
		if SQUAD_KIND[s] != "rush" or shots_clear(ppos):
			return s
	rush_wait += 0.15
	if rush_wait < RUSH_WAIT:
		return -1
	for s in cands:                              # 오래 기다렸다: 돌격이 아닌 다른 편대
		if SQUAD_KIND[s] != "rush":
			return s
	return -1


## 편대 s 의 패턴: 편대 패턴 둘 + 편대장 패턴 (편대장이 살아 있을 때만). 직전 패턴은 피한다
func _pick_mode(s: int) -> String:
	var modes: Array = SQUAD_MODES[SQUAD_KIND[s]].duplicate()
	if not part_alive(leader_of(s)):
		modes.pop_back()
	if modes.size() > 1:
		modes.erase(last_mode[s])
	return modes[randi() % modes.size()]


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_ship()
	for f in flung:
		var st := fling_state(f)
		_draw_drone(st[0], int(f["i"]), float(st[1]), 1.0, float(f["t"]) * 14.0)
	_draw_drones()
	_draw_part_marks()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


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
	var cb := CANNON_BASE
	var cd := Vector2.from_angle(cannon_aim)
	draw_circle(cb, 110.0, C_HULL_DARK)
	draw_arc(cb, 110.0, 0.0, TAU, 32, Color(C_RIM, 0.5), 5.0)
	draw_line(cb, cb + cd * CANNON_LEN, C_HULL_DARK, 70.0)
	draw_line(cb, cb + cd * CANNON_LEN, C_HULL, 46.0)
	for k in 3:
		draw_line(cb + cd * (120.0 + k * 70.0) + cd.orthogonal() * 36.0, cb + cd * (120.0 + k * 70.0) - cd.orthogonal() * 36.0, C_HULL_DARK, 8.0)
	var mz := cb + cd * CANNON_LEN
	draw_circle(mz, 40.0, C_HULL_DARK)
	if cannon_glow > 0.0:
		draw_circle(mz, 30.0 + 50.0 * cannon_glow, Color(1.0, 0.62, 0.86, 0.25 * cannon_glow))
		draw_circle(mz, 24.0 * cannon_glow, Color(1.0, 0.85, 0.95, 0.9))
	# 고물 엔진
	for k in 4:
		var e := Vector2(-1830, -130 + k * 80.0)
		draw_rect(Rect2(e + Vector2(-60, -30), Vector2(70, 60)), C_HULL_DARK)
		draw_circle(e + Vector2(-70, 0), 40.0 + 8.0 * sin(t * 9.0 + k), Color(0.45, 0.7, 1.0, 0.3))
		draw_circle(e + Vector2(-70, 0), 20.0, Color(0.85, 0.95, 1.0, 0.75))
	for sd in [-1.0, 1.0]:                                             # 항해등 (양 끝)
		var on := float(int(t * 1.5 + (0.5 if sd > 0 else 0.0)) % 2)
		draw_circle(Vector2(sd * 1820.0, -250), 12.0, Color(1.0, 0.25, 0.2, 0.3 + 0.6 * on) if sd < 0 else Color(0.3, 1.0, 0.45, 0.3 + 0.6 * on))
	# 갑판이 갈라진다: 가운데가 벌어지고 코어가 드러난다
	if deck_k > 0.0:
		var w := 40.0 + 300.0 * deck_k
		draw_rect(Rect2(DECK_CORE.x - w, -240, w * 2.0, 480), Color(0.02, 0.01, 0.02))
		_soft_glow(DECK_CORE, 420.0 * deck_k, C_CORE, 0.35 * deck_k)
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
	draw_set_transform(Vector2.ZERO, 0.0)
	if phase >= 2 and not dead:
		var cp := core_draw_pos()
		var deck := ship_to_world(DECK_CORE)
		draw_line(deck, cp, Color(C_CORE, 0.25), 10.0)                 # 모함과 이어진 동력선
		draw_line(deck, cp, Color(1.0, 0.85, 0.6, 0.5), 3.0)
		if phase == 3:
			_draw_exposed_core(CORE_POS, CORE_R, C_CORE)
		else:
			var k := clampf(open_t / maxf(open_time, 0.1), 0.0, 1.0)
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE * 0.6, 1.0, k), Color(C_CORE, 0.85))
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE * 0.6, 1.0, k) * 0.5, Color(1, 0.95, 0.8))
		if shield_flash > 0.0:                                          # 약한 일격이 튕김
			draw_arc(CORE_POS, CORE_R * 1.8, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * shield_flash), 6.0)
	if dead:
		var kk := minf(1.0, death_t / 1.4)
		draw_circle(CORE_POS, CORE_R + kk * 500.0, Color(C_CORE, 0.5 * (1.0 - kk)))
		draw_arc(CORE_POS, CORE_R + kk * 900.0, 0.0, TAU, 48, Color(1, 0.95, 0.8, 1.0 - kk), 8.0)


## 드론들: 차례인 편대는 밝게, 나머지는 조금 어둡게 포위망을 지킨다
func _draw_drones() -> void:
	for i in part_count():
		if not part_alive(i):
			continue
		var on := squad_of(i) == active
		_draw_drone(dpos[i], i, 1.0, 1.0 if on or active < 0 else 0.7, 0.0)


func _draw_drone(p: Vector2, i: int, scale_k: float, lit: float, spin: float) -> void:
	var col: Color = SQUAD_COL[squad_of(i)]
	var g: float = dglow[i] if i < dglow.size() else 0.0
	var a: float = (daim[i] if i < daim.size() else 0.0) + spin
	if lit >= 1.0 and active == squad_of(i):                      # 차례인 편대: 편대 색 빛무리
		draw_circle(p, (LEADER_SIZE if is_leader(i) else WING_SIZE) * 1.3 * scale_k, Color(col, 0.08 + 0.14 * g))
	if is_leader(i):
		draw_set_transform(p, a, Vector2.ONE * LEADER_SIZE * scale_k)
		_leader_body(col, lit, g)
	else:
		draw_set_transform(p, a, Vector2.ONE * WING_SIZE * scale_k)
		_wing_body(col, lit, g)
	draw_set_transform(Vector2.ZERO, 0.0)


static func _mirror(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(Vector2(q.x, -q.y))
	return out


func _poly(pts: Array, fill: Color, edge: Color, w: float) -> void:
	var pa := PackedVector2Array(pts)
	draw_colored_polygon(pa, fill)
	var ol := pa.duplicate()
	ol.append(pa[0])
	draw_polyline(ol, edge, w)


## 편대원: 날렵한 요격기 (단위 크기, 앞 = +x). 앞으로 젖힌 날개 + 쌍 꼬리날개 + 날개 끝 기관포 + 편대 색 조종석·날개 띠 + 쌍 엔진
func _wing_body(col: Color, lit: float, g: float) -> void:
	var body := C_DRONE.lightened(0.12 * lit)
	var dark := C_DRONE_DARK
	var edge := Color(col, 0.35 + 0.45 * lit)
	var wing := [Vector2(0.2, 0.14), Vector2(-0.05, 0.92), Vector2(-0.38, 0.95), Vector2(-0.42, 0.16)]
	for side in [wing, _mirror(wing)]:
		_poly(side, dark, edge, 0.035)
	for sd in [1.0, -1.0]:                                             # 날개 띠 + 날개 끝 기관포
		draw_line(Vector2(0.05, 0.55 * sd), Vector2(-0.28, 0.6 * sd), Color(col, 0.55 * lit + 0.3 * g), 0.08)
		draw_line(Vector2(-0.2, 0.93 * sd), Vector2(0.28, 0.93 * sd), dark, 0.07)
		draw_circle(Vector2(0.3, 0.93 * sd), 0.035, Color(col, 0.4 + 0.6 * g))
	var fin := [Vector2(-0.55, 0.12), Vector2(-0.95, 0.45), Vector2(-0.9, 0.12)]
	for side in [fin, _mirror(fin)]:
		_poly(side, dark, edge, 0.03)
	var hull := [Vector2(1.05, 0.0), Vector2(0.6, 0.12), Vector2(-0.2, 0.19), Vector2(-0.8, 0.15), Vector2(-0.9, 0.0),
		Vector2(-0.8, -0.15), Vector2(-0.2, -0.19), Vector2(0.6, -0.12)]
	_poly(hull, body, Color(C_RIM, 0.6), 0.03)
	draw_line(Vector2(0.55, 0), Vector2(-0.75, 0), Color(dark, 0.9), 0.025)   # 등줄기
	draw_line(Vector2(-0.1, 0.12), Vector2(-0.1, -0.12), Color(dark, 0.9), 0.02)
	_poly([Vector2(0.62, 0.0), Vector2(0.42, 0.08), Vector2(0.18, 0.07), Vector2(0.18, -0.07), Vector2(0.42, -0.08)],
		Color(col.lightened(0.2), 0.55 + 0.35 * g), Color(1, 1, 1, 0.4), 0.015)   # 조종석
	for sd in [0.08, -0.08]:                                           # 쌍 엔진
		draw_circle(Vector2(-0.9, sd), 0.07, dark)
		var fl := 0.12 + 0.05 * sin(t * 30.0 + sd * 40.0)
		draw_circle(Vector2(-0.98 - fl, sd), 0.07, Color(0.55, 0.8, 1.0, 0.6 * lit))
		draw_circle(Vector2(-0.95, sd), 0.04, Color(0.9, 0.97, 1.0, 0.8 * lit))


## 편대장: 육중한 지휘 포격기 (단위 크기, 앞 = +x). 두꺼운 장갑 몸통 + 넓은 날개 끝 엔진 포드 + 쌍 주포 + 편대 색 감지 눈 + 계급 갈매기 문장
func _leader_body(col: Color, lit: float, g: float) -> void:
	var body := C_DRONE.lightened(0.14 * lit)
	var dark := C_DRONE_DARK
	var edge := Color(col, 0.45 + 0.45 * lit)
	var wing := [Vector2(0.3, 0.28), Vector2(-0.15, 1.02), Vector2(-0.62, 1.0), Vector2(-0.55, 0.32)]
	for side in [wing, _mirror(wing)]:
		_poly(side, dark, edge, 0.03)
	for sd in [1.0, -1.0]:                                             # 날개 끝 엔진 포드
		_poly([Vector2(-0.05, 0.9 * sd), Vector2(-0.75, 0.9 * sd), Vector2(-0.8, 1.12 * sd), Vector2(-0.05, 1.12 * sd)], body, Color(C_RIM, 0.6), 0.025)
		var fl := 0.1 + 0.04 * sin(t * 26.0 + sd * 3.0)
		draw_circle(Vector2(-0.85 - fl, 1.01 * sd), 0.08, Color(0.55, 0.8, 1.0, 0.6 * lit))
		draw_circle(Vector2(-0.82, 1.01 * sd), 0.05, Color(0.9, 0.97, 1.0, 0.85 * lit))
		draw_line(Vector2(-0.1, 0.62 * sd), Vector2(-0.45, 0.66 * sd), Color(col, 0.6 * lit + 0.3 * g), 0.07)   # 날개 띠
	for sd in [0.15, -0.15]:                                           # 쌍 주포
		draw_line(Vector2(0.35, sd), Vector2(1.2, sd), dark, 0.11)
		draw_line(Vector2(0.4, sd), Vector2(1.18, sd), Color(C_RIM, 0.5), 0.03)
		draw_circle(Vector2(1.2, sd), 0.06, Color(col, 0.35 + 0.65 * g))
	var hull := [Vector2(0.85, 0.0), Vector2(0.55, 0.34), Vector2(-0.45, 0.4), Vector2(-0.82, 0.22), Vector2(-0.82, -0.22),
		Vector2(-0.45, -0.4), Vector2(0.55, -0.34)]
	_poly(hull, body, Color(C_RIM, 0.7), 0.035)
	_poly([Vector2(0.45, 0.0), Vector2(0.2, 0.24), Vector2(-0.35, 0.26), Vector2(-0.35, -0.26), Vector2(0.2, -0.24)],
		C_HULL_LIT.darkened(0.2 * (1.0 - lit)), Color(dark, 0.9), 0.025)   # 등 장갑판
	for k in 3:                                                        # 계급 갈매기 문장 (편대 색)
		var x := -0.15 - k * 0.14
		draw_polyline(PackedVector2Array([Vector2(x - 0.08, 0.16), Vector2(x, 0.0), Vector2(x - 0.08, -0.16)]), Color(col, 0.7 * lit + 0.3 * g), 0.04)
	draw_circle(Vector2(0.28, 0.0), 0.12, dark)                         # 감지 눈 (곧 쏘면 커진다)
	draw_circle(Vector2(0.28, 0.0), 0.08 + 0.04 * g, Color(col.lightened(0.3), 0.7 + 0.3 * g))
	draw_circle(Vector2(0.3, -0.03), 0.025, Color(1, 1, 1, 0.8))
	for sd in [0.2, 0.0, -0.2]:                                        # 꼬리 엔진 셋
		draw_circle(Vector2(-0.86, sd), 0.06, dark)
		draw_circle(Vector2(-0.94, sd), 0.045, Color(0.7, 0.88, 1.0, 0.7 * lit))

extends "res://scripts/colossus_base.gd"
## 콜로서스 ⑤ 모함 (소환형). 기획: docs/BOSS_carrier.md
## 거대한 항공모함이 멀리(배경, 옅은 안개 너머) 정박해 있다 — 화면 위쪽에 원근으로 작게 보이고 화면을 따라 천천히 움직인다 (ship_to_world).
## 플레이어가 실제로 싸우는 상대는 모함이 내보낸 드론 편대 셋(3기씩, 모두 9기)이다.
## 아홉 기는 플레이어를 가운데 두고 둥글게 포위한 채 늘 움직인다 (고리가 천천히 돌고, 숨 쉬듯 좁혀졌다 넓어지고, 플레이어를 늦게 따라온다).
## 차례가 온 편대만 앞으로 나서 공격한다: 탄막 편대(금, 패리 → 리버스 드라이브) / 돌격 편대(진홍, 요격) / 결계 편대(보라, 퍼펙트 회피 → 동조 일격).
## 편대 차례 사이에는 모함 본체가 배경에서 압도적인 패턴을 쏜다: 함포 포격(표적 고리 + 터지는 탄) / 탐조 광선(패리 불가, 화면을 가르는 광선 다발).
## 편대 차례는 섞이되 같은 편대가 연달아 오지 않는다. 돌격(근접)은 날아오는 탄이 걷힌 뒤에만.
## 드론 = 외부 시스템 (편대장 체력 높게, 편대원 낮게). 일반 돌진·차지 강습은 흠집(1)만 — 패턴을 파훼한 일격(리버스 드라이브·요격·동조)으로 부순다.
## 부서진 드론은 맞은 쪽으로 튕겼다가 원근으로 작아지며 모함으로 날아가 선체에 꽂혀 불탄다 (꽂힌 자리 = 체력 표시).
## 아홉 기를 다 잡으면 갑판이 갈라지며 코어가 떨어져 나와 경기장으로 내려오고(CORE_POS), 최후의 발악(금빛 탄막의 바다)이 시작된다.
## 이때 코어는 리버스 드라이브 한 방이면 터지고, 돌진·차지는 튕겨 나온다 (반사탄도 안 들어간다).
## 바닥 y=0 (궤도 무대: 대기권 경계), 위쪽이 음수.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const SquadGun := preload("res://scripts/attacks/squad_gun.gd")
const SquadRush := preload("res://scripts/attacks/squad_rush.gd")
const SquadVeil := preload("res://scripts/attacks/squad_veil.gd")
const CarrierShells := preload("res://scripts/attacks/carrier_shells.gd")
const RadialBurst := preload("res://scripts/attacks/radial_burst.gd")
const OpenBarrage := preload("res://scripts/attacks/open_barrage.gd")

# ── 편대 ───────────────────────────────────────────────
const SQUADS := 3
const PER := 3                               # 편대당 기체 수 (0번 = 편대장)
const SQUAD_KIND := ["gun", "rush", "veil"]
const SQUAD_COL := [Color(1.0, 0.8, 0.35), Color(1.0, 0.24, 0.18), Color(0.85, 0.3, 0.75)]   # 금 / 진홍 / 보라 (색 규칙)
const LEADER_HP := 40                        # 편대장: PERFECT 리버스 드라이브 세 방쯤
const WING_HP := 25                          # 편대원: 두 방쯤
const ARMOR_HP := 270                        # = 아홉 기 체력 합 (게이지·플레이 기록용. 코어 껍질은 드론이 다 부서지면 사라진다)
const CHIP := 1                              # 약한 일격(돌진·차지)은 이만큼만 (작은 표적을 마구 들이받는 쪽이 쉬워지지 않게)
const DRONE_R := 40.0                        # 편대원 판정 반지름 (편대장은 1.2배)

# ── 포위 고리 ──────────────────────────────────────────
const RING_R := 820.0
const RING_BREATHE := 110.0                  # 숨 쉬듯 좁혀졌다 넓어진다
const RING_SPIN := 0.22                      # 고리 회전 (rad/s)
const RING_FOLLOW := 0.8                     # 고리 중심이 플레이어를 따라가는 빠르기 (늦게)
const WING_SPREAD := 0.3                     # 편대장 양옆 편대원 간격 (라디안)
const MOVE_K := 3.2                          # 드론이 원하는 자리로 미끄러지는 빠르기
const ARENA := Rect2(-1120, -2950, 2240, 2720)

# ── 모함 (배경) ────────────────────────────────────────
const SHIP_ANCHOR := Vector2(0, -2900)      # 모함이 정박한 곳 (월드). 실제로 그리는 자리는 화면 쪽으로 당겨진다 (원근)
const SHIP_PAR := 0.3                        # 화면 가운데에서 SHIP_ANCHOR 쪽으로 이만큼만 (작을수록 멀리 있어 화면에 붙어 있다)
const SHIP_SCALE := 0.42                     # 멀리 있어 작게
const SHIP_Y := 0.0                          # 선체 그림 좌표의 가운데 높이 (아래 모함 좌표는 모두 선체 기준, ship_to_world 로 월드로)
const DECK_CORE := Vector2(0, 40)            # 갑판 속 코어 자리 (선체 기준)
const CORE_POS := Vector2(0, -2050)          # 떨어져 나온 코어가 내려와 머무는 곳 (월드, 최후의 발악)
const CORE_R := 60.0
const HANGARS := [Vector2(-760, 80), Vector2(0, 120), Vector2(760, 80)]   # 편대마다 격납고 (선체 기준. 시작할 때 여기서 나온다)
const BATTERIES := 10                         # 선체 아래 포대 수 (함포 포격·탐조 광선의 발사점)
const BARRIER_R := 120.0                     # 탐조 광선이 시작되는 반지름 (발사점 둘레)
const SEARCH_BEAMS := 10                     # 탐조 광선 줄기 수 (아래로 퍼지는 부채로 보인다)

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.25, 0.5)
const RUSH_WAIT := 2.5                       # 돌격 차례에 탄이 걷히길 기다리는 최대 시간 (넘으면 다른 편대)

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.16, 0.18, 0.23)
const C_HULL_DARK := Color(0.09, 0.1, 0.13)
const C_RIM := Color(0.45, 0.5, 0.6)
const C_HAZE := Color(0.03, 0.04, 0.08)
const C_LIGHT := Color(1.0, 0.75, 0.4)
const C_CORE := Color(1.0, 0.5, 0.25)

var dpos: Array[Vector2] = []                # 드론 위치
var dwant: Array[Vector2] = []               # 드론이 가려는 자리
var dcmd: Array[bool] = []                   # 이번 프레임에 공격이 자리를 정해 주었나 (아니면 포위 고리)
var dglow: Array[float] = []                 # 곧 쏜다 (빛)
var ring_c := Vector2(0, -1500)
var ring_a := 0.0
var active := -1                             # 지금 차례인 편대 (-1 = 모함 차례·쉬는 중)
var last_squad := -1
var squad_turn := true                       # 다음이 편대 차례인가 (모함 차례와 번갈아)
var last_ship := ""
var rush_wait := 0.0
var flung: Array[Dictionary] = []            # 부서져 모함으로 날아가는 드론 {from, dir, t, to, i}
var burns: Array[Dictionary] = []            # 선체에 꽂혀 타는 자리 {pos, t}
var batt_glow: Array[float] = []
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
	dglow.clear()
	for i in part_count():
		var h: Vector2 = ship_to_world(HANGARS[squad_of(i)]) + Vector2((i % PER - 1) * 40.0, 0)
		dpos.append(h)                           # 격납고에서 쏟아져 나와 고리로 간다
		dwant.append(h)
		dcmd.append(false)
		dglow.append(0.0)
	ring_c = Vector2(0, -1500)
	ring_a = 0.0
	active = -1
	last_squad = -1
	squad_turn = true
	last_ship = ""
	rush_wait = 0.0
	flung.clear()
	burns.clear()
	batt_glow.clear()
	for k in BATTERIES:
		batt_glow.append(0.0)
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


func part_max_hp(i: int) -> int:
	return LEADER_HP if is_leader(i) else WING_HP


func part_pos(i: int) -> Vector2:
	return dpos[i] if i < dpos.size() else Vector2.ZERO


func part_radius(i: int) -> float:
	return DRONE_R * (1.2 if is_leader(i) else 1.0)


func drone_pos(i: int) -> Vector2:
	return dpos[i]


## 편대 s 의 살아 있는 기체 (편대장 먼저)
func squad_alive(s: int) -> Array:
	var out := []
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


func set_drone_glow(i: int, v: float) -> void:
	dglow[i] = maxf(dglow[i], v)


func _in_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, ARENA.position.x, ARENA.end.x), clampf(p.y, ARENA.position.y, ARENA.end.y))


## 포위 고리 위 드론 i 의 자리: 편대마다 120°씩, 편대장이 가운데·편대원이 양옆. 고리가 돌고 숨 쉬고, 기체마다 조금씩 흔들린다
func ring_slot(i: int) -> Vector2:
	var s := squad_of(i)
	var k := i % PER
	var a := ring_a + s * TAU / SQUADS + (0.0 if k == 0 else (WING_SPREAD if k == 1 else -WING_SPREAD))
	var r := RING_R + RING_BREATHE * sin(t * 0.6) + 30.0 * sin(t * 1.7 + i * 1.3)
	return ring_c + Vector2.from_angle(a) * r + Vector2(sin(t * 2.1 + i), cos(t * 1.8 + i * 0.7)) * 18.0


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
	var to := Vector2(lerpf(-1150.0, 1150.0, slot) + sin(i * 2.3) * 80.0, 60.0 + cos(i * 1.7) * 70.0)   # 선체 기준
	flung.append({"from": dpos[i], "dir": dir, "t": 0.0, "to": to, "i": i})
	dglow[i] = 0.0


## 탄 속도: 드론이 줄수록 조금씩 빨라진다 (기본처럼 부위마다 +10% 는 아홉 기에 너무 크다)
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


# ── 모함 포대 (함포 포격·탐조 광선의 발사점) ─────────────
## 포대 k (선체 기준)
func battery_local(k: int) -> Vector2:
	return Vector2(lerpf(-1150.0, 1150.0, float(k) / (BATTERIES - 1)), 200.0)


func battery_pos(k: int) -> Vector2:
	return ship_to_world(battery_local(k))


## 선체 기준 좌표 → 지금 화면에서 모함이 보이는 월드 자리 (멀리 있어 작고, 화면을 따라 천천히 움직인다)
func ship_to_world(local: Vector2) -> Vector2:
	var c := view_c + (SHIP_ANCHOR - view_c) * SHIP_PAR
	return c + local * SHIP_SCALE


func set_battery_glow(k: int, v: float) -> void:
	if k >= 0 and k < BATTERIES:
		batt_glow[k] = maxf(batt_glow[k], v)


## 탐조 광선(radial_burst)이 쓰는 이름: 광선 방향 a 에 가장 가까운 포대
func node_toward(a: float) -> int:
	var o := _search_origin()
	var best := 0
	var bd := INF
	for k in BATTERIES:
		var d: float = absf(angle_difference((battery_pos(k) - o).angle(), a))
		if d < bd:
			bd = d
			best = k
	return best


func set_glow(i: int, v: float) -> void:
	set_battery_glow(i, v)


func _search_origin() -> Vector2:
	return ship_to_world(Vector2(0, 230.0))


## 떨어져 나온 코어의 그림 위치: 페이즈 2 동안 갑판에서 CORE_POS 로 내려온다 (원근으로 커지며)
func core_draw_pos() -> Vector2:
	if phase < 2:
		return ship_to_world(DECK_CORE)
	if phase == 3 or dead:
		return CORE_POS
	var k := clampf(open_t / maxf(open_time, 0.1), 0.0, 1.0)
	return ship_to_world(DECK_CORE).lerp(CORE_POS, k * k * (3.0 - 2.0 * k))


# ── 진행 ───────────────────────────────────────────────
func _step_effects(dt: float) -> void:
	hull_shake = maxf(0.0, hull_shake - dt * 2.5)
	shield_flash = maxf(0.0, shield_flash - dt * 3.0)
	deck_k = move_toward(deck_k, 1.0 if phase >= 2 else 0.0, dt / maxf(open_time, 0.1))
	for k in batt_glow.size():
		batt_glow[k] = move_toward(batt_glow[k], 0.0, dt * 2.0)
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
	return [p, lerpf(1.0, SHIP_SCALE * 0.7, u)]


func _step_phase(dt: float) -> void:
	if phase == 3 and not core.broken:           # 코어가 드러났다: 껍질 없이 한 방이면 터진다
		core.armor_hp = 0
		core.broken = true
		core.guard = 0.0
	ring_a += RING_SPIN * dt
	var want := Vector2(clampf(look_at.x, -350.0, 350.0), clampf(look_at.y, -2200.0, -1000.0))
	ring_c = ring_c.lerp(want, 1.0 - exp(-RING_FOLLOW * dt))
	for i in part_count():
		if not part_alive(i):
			continue
		if not dcmd[i]:
			dwant[i] = _in_arena(ring_slot(i))
		dpos[i] = dpos[i].lerp(dwant[i], 1.0 - exp(-MOVE_K * dt))
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
		match SQUAD_KIND[s]:
			"gun":
				start_attack(SquadGun.new(s))
			"rush":
				start_attack(SquadRush.new(s))
			"veil":
				start_attack(SquadVeil.new(s))
		return
	squad_turn = true                            # 모함 차례: 함포 포격 ↔ 탐조 광선 번갈아
	last_ship = "search" if last_ship == "shells" else "shells"
	if last_ship == "shells":
		start_attack(CarrierShells.new())
	else:
		start_attack(RadialBurst.new(_search_origin(), SEARCH_BEAMS))


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
	for s in SQUADS:                             # 오래 기다렸다: 돌격이 아닌 다른 살아 있는 편대
		if SQUAD_KIND[s] != "rush" and not squad_alive(s).is_empty():
			return s
	return -1


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


## 배경의 항공모함: 길쭉한 선체 + 비행갑판 + 함교 + 격납고 불빛 + 아래쪽 포대. 옅은 안개를 덮어 멀리 있는 느낌
func _draw_ship() -> void:
	var sh := Vector2(sin(t * 47.0), cos(t * 39.0)) * 10.0 * hull_shake * hull_shake
	draw_set_transform(ship_to_world(Vector2.ZERO) + sh, 0.0, Vector2(SHIP_SCALE, SHIP_SCALE))
	var y := SHIP_Y
	var hull := PackedVector2Array([Vector2(-1700, y - 170), Vector2(1560, y - 170), Vector2(1760, y - 120), Vector2(1450, y + 150),
		Vector2(1250, y + 240), Vector2(-1350, y + 240), Vector2(-1560, y + 120), Vector2(-1700, y + 20)])
	draw_colored_polygon(hull, C_HULL)
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, Color(C_RIM, 0.45), 4.0)
	draw_rect(Rect2(-1760, y - 205, 3480, 38), C_HULL_DARK)            # 비행갑판 (가장자리)
	draw_line(Vector2(-1760, y - 205), Vector2(1720, y - 205), Color(C_RIM, 0.5), 3.0)
	for k in 22:                                                       # 갑판 유도등
		var on := 0.5 + 0.5 * sin(t * 3.0 - k * 0.5)
		draw_circle(Vector2(-1650 + k * 150.0, y - 186), 5.0, Color(C_LIGHT, 0.25 + 0.5 * on))
	var isl := PackedVector2Array([Vector2(820, y - 205), Vector2(1080, y - 205), Vector2(1040, y - 460), Vector2(860, y - 460)])   # 함교
	draw_colored_polygon(isl, C_HULL)
	draw_polyline(PackedVector2Array([isl[0], isl[3], isl[2], isl[1]]), Color(C_RIM, 0.45), 3.0)
	for k in 3:
		draw_rect(Rect2(880, y - 430 + k * 60.0, 140, 18), Color(0.55, 0.75, 1.0, 0.18 + 0.1 * k))
	draw_line(Vector2(950, y - 460), Vector2(950, y - 640), C_HULL_DARK, 12.0)      # 레이더 마스트
	var ra := t * 1.6
	draw_line(Vector2(950, y - 600) - Vector2.from_angle(ra) * Vector2(90, 14), Vector2(950, y - 600) + Vector2.from_angle(ra) * Vector2(90, 14), Color(C_RIM, 0.7), 6.0)
	draw_circle(Vector2(950, y - 650), 8.0, Color(1.0, 0.3, 0.25, 0.4 + 0.5 * float(int(t * 2.0) % 2)))
	for k in 6:                                                        # 선체 판 이음매
		var x := -1300.0 + k * 480.0
		draw_line(Vector2(x, y - 160), Vector2(x - 40, y + 230), Color(C_HULL_DARK, 0.9), 4.0)
	for s in HANGARS.size():                                           # 격납고: 남은 편대가 있으면 안쪽이 밝다
		var h: Vector2 = HANGARS[s]
		var alive := not squad_alive(s).is_empty()
		draw_rect(Rect2(h + Vector2(-150, -60), Vector2(300, 120)), C_HULL_DARK)
		draw_rect(Rect2(h + Vector2(-130, -44), Vector2(260, 88)), Color(SQUAD_COL[s], 0.35 if alive else 0.05))
		for g in 4:
			draw_line(h + Vector2(-130, -44 + g * 29.0), h + Vector2(130, -44 + g * 29.0), Color(C_HULL_DARK, 0.8), 3.0)
	for k in BATTERIES:                                                # 아래쪽 포대
		var b := battery_local(k)
		var g: float = batt_glow[k]
		draw_circle(b + Vector2(0, -30), 38.0, C_HULL_DARK)
		draw_line(b + Vector2(0, -30), b + Vector2(0, 30), C_HULL, 18.0)
		draw_circle(b + Vector2(0, 30), 9.0 + 9.0 * g, Color(C_LIGHT, 0.3 + 0.7 * g))
		if g > 0.05:
			draw_circle(b + Vector2(0, 30), 70.0 * g, Color(C_LIGHT, 0.2 * g))
	for k in 3:                                                        # 고물 쪽 엔진 불빛
		var e := Vector2(-1680, y - 80 + k * 90.0)
		draw_circle(e, 30.0 + 6.0 * sin(t * 9.0 + k), Color(0.5, 0.75, 1.0, 0.35))
		draw_circle(e, 14.0, Color(0.85, 0.95, 1.0, 0.7))
	if deck_k > 0.0:                                                   # 갑판이 갈라진다: 가운데가 벌어지고 코어가 드러난다
		var w := 40.0 + 260.0 * deck_k
		draw_rect(Rect2(DECK_CORE.x - w, y - 210, w * 2.0, 450), Color(0.02, 0.01, 0.02))
		_soft_glow(DECK_CORE, 360.0 * deck_k, C_CORE, 0.35 * deck_k)
	for b in burns:                                                    # 꽂힌 드론이 타는 자리
		var p: Vector2 = b["pos"]
		var fl := 0.6 + 0.4 * sin(t * 13.0 + p.x)
		draw_circle(p, 46.0, Color(0.05, 0.03, 0.02, 0.9))
		draw_circle(p, 26.0 * fl, Color(1.0, 0.5, 0.15, 0.8))
		draw_circle(p, 12.0 * fl, Color(1.0, 0.9, 0.5))
		for k in 3:
			var life := fmod(t * 0.5 + k * 0.33 + p.x * 0.001, 1.0)
			draw_circle(p + Vector2(sin(t + k) * 20.0, -40.0 - life * 220.0), 20.0 + life * 40.0, Color(0.2, 0.2, 0.24, 0.4 * (1.0 - life)))
	draw_colored_polygon(PackedVector2Array([Vector2(-1800, y - 700), Vector2(1800, y - 700), Vector2(1800, y + 280), Vector2(-1800, y + 280)]), Color(C_HAZE, 0.35))   # 먼 거리의 안개
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
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE, 1.0, k), Color(C_CORE, 0.85))
			draw_circle(cp, CORE_R * lerpf(SHIP_SCALE, 1.0, k) * 0.5, Color(1, 0.95, 0.8))
		if shield_flash > 0.0:                                          # 약한 일격이 튕김
			draw_arc(CORE_POS, CORE_R * 1.8, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * shield_flash), 6.0)
	if dead:
		var kk := minf(1.0, death_t / 1.4)
		draw_circle(CORE_POS, CORE_R + kk * 500.0, Color(C_CORE, 0.5 * (1.0 - kk)))
		draw_arc(CORE_POS, CORE_R + kk * 900.0, 0.0, TAU, 48, Color(1, 0.95, 0.8, 1.0 - kk), 8.0)


## 드론들: 차례인 편대는 밝고 크게, 나머지는 어둡게 고리를 지킨다
func _draw_drones() -> void:
	for i in part_count():
		if not part_alive(i):
			continue
		var on := squad_of(i) == active
		_draw_drone(dpos[i], i, 1.0, 1.0 if on or active < 0 else 0.6, 0.0)


## 드론 하나: 끝이 플레이어를 향한 화살촉 몸통 + 편대 색 줄무늬 + 엔진 불꽃. 편대장은 크고 볏이 있다
func _draw_drone(p: Vector2, i: int, scale_k: float, lit: float, spin: float) -> void:
	var s := squad_of(i)
	var col: Color = SQUAD_COL[s]
	var sz := (1.25 if is_leader(i) else 1.0) * 38.0 * scale_k
	var a := (look_at - p).angle() + spin
	var f := Vector2.from_angle(a)
	var n := f.orthogonal()
	var g: float = dglow[i] if i < dglow.size() else 0.0
	if lit >= 1.0 and active == s:
		draw_circle(p, sz * 1.9, Color(col, 0.1 + 0.15 * g))
	var body := PackedVector2Array([p + f * sz, p - f * sz * 0.7 + n * sz * 0.85, p - f * sz * 0.35, p - f * sz * 0.7 - n * sz * 0.85])
	draw_colored_polygon(body, Color(C_HULL, 1.0).lightened(0.15 * lit))
	var ol := body.duplicate()
	ol.append(body[0])
	draw_polyline(ol, Color(col, 0.5 + 0.4 * lit), 3.0 * scale_k)
	draw_line(p + f * sz * 0.6, p - f * sz * 0.3, Color(col, 0.6 * lit + 0.3 * g), 6.0 * scale_k)   # 편대 색 줄무늬
	if is_leader(i):                                                   # 편대장 볏
		draw_line(p - f * sz * 0.2 + n * sz * 0.3, p - f * sz * 0.75 + n * sz * 0.6, Color(col, 0.8 * lit), 4.0 * scale_k)
		draw_line(p - f * sz * 0.2 - n * sz * 0.3, p - f * sz * 0.75 - n * sz * 0.6, Color(col, 0.8 * lit), 4.0 * scale_k)
	var flame := p - f * sz * (0.45 + 0.15 * sin(t * 30.0 + i))        # 엔진 불꽃
	draw_circle(flame, sz * 0.22, Color(0.6, 0.85, 1.0, 0.7 * lit))
	draw_circle(p + f * sz * 0.2, sz * 0.16 + sz * 0.12 * g, Color(col.lightened(0.3), 0.6 + 0.4 * g))   # 눈 (곧 쏘면 커진다)

extends "res://scripts/colossus_base.gd"
## 콜로서스 ② 탄막 요새 (패리 중심형). 포신으로 뒤덮인 계단식 포격 성채 — 무한궤도 위에 층층이 쌓인 포대가 화면 위 끝 너머까지 솟는다.
## 외형 리워크 (v0.69, docs/BOSS_fortress.md 3장): 그림만 바꿨고 판정·발사점은 아직 예전 자리 (다음 단계에서 대구경 포대·보조 시스템으로 옮긴다).
## 핵심: 잔탄(작은 탄)은 피하거나 패리로 흡수, 주탄(큰 탄·유도탄)을 패리해 리버스 드라이브로 꽂는다.
## 페이즈: 1) 포격전 — 주 목표는 몸통 가운데(2층)의 코어 포대. 포방패가 닫혀 있으면 피해가 크게 준다. 쏠 차례에 포방패가 열리면
##            장갑에 싸인 에너지 코어가 드러나 힘을 모았다가 대구경 포탄을 만들어 쏜다 — 받아친 탄으로 때리면 코어 장갑이 떨어져 나간다 (체력제 BIG_HP).
##            보조 시스템(양옆 작은 포탑 둘·유도탄 포드 둘)은 몸 바깥쪽 가장자리에 작게 붙어 있다 — 부수면 그쪽에서 탄이 안 나올 뿐, 차례는 다른 발사점이 잇는다
##         2) 대구경 포가 부서지고 그 뒤에서 동력 코어가 드러난다
##         3) 코어 — 장갑 없이 드러나 있다 (한 대면 터진다). 반응로 폭주로 마지막 저항
## 플레이어는 경기장 가운데 위쪽에 머물며 보조 시스템과 닫힌 코어 포대를 때리다가, 대구경 포탄이 나오면 받아친다 (v0.74)
## 공격: 나선 탄막 · 부채 탄막(가운데 주탄) · 유도탄 · 프레스(근접, 회피 불가, 드물게) · 동심원 파동(패리 불가, 드물게)
##       · 반응로 폭주(코어 페이즈 전용). 코어 페이즈에선 기존 탄막도 강해진다(hard).
## 탄막형이라 화면이 비지 않게: 쉬는 시간이 짧고, 유도탄은 다른 공격과 겹쳐 쏘며(보조 공격),
## 동심원 파동·올라가는 프레스는 판정을 남긴 채 다음 공격에 자리를 내준다. 같은 탄막을 연달아 쓰지 않는다.
## 회전형(spiral)은 반대로 다른 패턴이 쉴 때만 혼자 쓰고, 부채꼴 안에서만 뿌려 반대쪽이 비어 있다.
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Spiral := preload("res://scripts/attacks/spiral.gd")
const Fan := preload("res://scripts/attacks/fan.gd")
const Homing := preload("res://scripts/attacks/homing.gd")
const Press := preload("res://scripts/attacks/press.gd")
const Rings := preload("res://scripts/attacks/rings.gd")
const Overload := preload("res://scripts/attacks/overload.gd")
const BigGun := preload("res://scripts/attacks/big_gun.gd")

# ── 구조 ───────────────────────────────────────────────
const REACTOR_POS := Vector2(0, -1550)      # 동력 코어 = 코어 포대 (포방패 안, 2층 가운데)
const ARMOR_HP := 110                       # = BIG_HP: 코어 포대의 체력이 곧 코어 장갑 (깎일수록 장갑판이 떨어져 나간다)
const CORE_R := 58.0
# 반응로 외곽선 (REACTOR_POS 기준): 모서리를 깎은 팔각형 + 위아래 냉각 돌기
const REACTOR_OUTLINE := [
	Vector2(-60, -160), Vector2(60, -160), Vector2(150, -100), Vector2(175, 0), Vector2(150, 100),
	Vector2(60, 160), Vector2(-60, 160), Vector2(-150, 100), Vector2(-175, 0), Vector2(-150, -100),
]
const BATTERIES := [Vector2(-690, -2230), Vector2(690, -2230)]      # 보조 포탑 (외부 시스템 0, 1): 3층 양옆 가장자리, 작게
const BARREL_TIPS := [Vector2(-790, -2350), Vector2(790, -2350)]   # 쉴 때의 포구 (포신은 플레이어를 따라 돈다: battery_tip)
const BARREL_LEN := 156.0
const SILOS := [Vector2(-880, -1380), Vector2(880, -1380)]           # 유도탄 포드 (외부 시스템 2, 3): 2층 바깥 가장자리, 작게
const SPIRE_TOP := Vector2(0, -2800)                                # 지붕 회전 포탑 (부서지지 않는 발사점)
const BG_GUNS := [Vector2(-930, -2610), Vector2(930, -2610)]        # 배경 포탑 포구 (부서지지 않는 발사점)
const GUN_PORT := Vector2(0, -1310)                                 # 닫힌 코어 포대 아래 작은 포문 (닫혀 있어도 간단한 탄막)
const VENTS := [Vector2(-340, -1550), Vector2(340, -1550)]          # 코어 페이즈 유도탄 배기구 (코어 양옆)

# ── 외부 시스템 ────────────────────────────────────────
const PART_HP := 30
const PART_R := [46.0, 46.0, 50.0, 50.0, 190.0]
const BIG := 4                       # 대구경 포대 (외부 시스템 4): 체력제. 포방패가 닫힌 동안은 피해가 크게 줄고, 드러났을 때는 그대로 들어간다
const BIG_HP := 110                  # 주 공략 대상이라 튼튼하게 (리버스 드라이브 8 / PERFECT 16, 반사탄은 0.5~3)
const BIG_CLOSED_K := 0.15           # 포방패 너머로 들어가는 피해 비율
const BIG_EVERY := 5                 # 공격 이만큼마다 대구경 포 (단독 패턴, 너무 자주 열리면 금방 끝난다)
const GUN_HOLD := 1.5                # 대구경 포 차례에 필드가 비길 기다리는 최대 시간 (남은 탄·자리를 내준 공격)
const SHELL_OUT := 200.0             # 포탄이 만들어지는 자리 (코어 앞, 플레이어 쪽으로)
const SEGS := 8                      # 코어 장갑 조각 수 (조리개처럼 둘러싼 사다리꼴, 체력이 깎일수록 하나씩 떨어진다)
const SEG_ORDER := [0, 4, 2, 6, 1, 5, 3, 7]   # 떨어지는 순서 (남은 수가 n 이면 앞에서 n 개를 뺀 나머지가 남는다)
const SEG_IN := 56.0
const SEG_OUT := 150.0
const SEG_GAP := 0.05
const OPEN_TIME := 1.6

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.2, 0.45)      # 공격 사이 쉬는 시간 (짧게: 한 번에 적게 쏘는 대신 끊기지 않게)
const GAP_CORE := Vector2(0.2, 0.45) # 코어 페이즈는 더 몰아친다
const GAP_SPIRAL := Vector2(0.5, 0.8) # 회전형 탄막 뒤: 남은 탄이 지나갈 시간을 준다 (겹치지 않게)
const CALM_SHOTS := 8                # 회전형 탄막은 필드의 탄이 이 이하이고 겹쳐 도는 공격이 없을 때만
const SPECIAL_EVERY := 5             # 특수기(프레스·동심원)는 이만큼 공격한 뒤에야 다시 (드물게, 연달아 쓰지 않음)

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.085, 0.085, 0.095)
const C_HULL_DARK := Color(0.05, 0.05, 0.06)
const C_RIM := Color(0.5, 0.48, 0.44)
const C_RUST := Color(0.36, 0.2, 0.12)
const C_TREAD := Color(0.06, 0.06, 0.065)
const C_GLOW := Color(1.0, 0.78, 0.42)

var glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 발사 전 달아오름: 부위 0~3, 4 회전 포탑, 5 박격포, 6 반응로(보라), 7·8 배경 포탑, 9 포문
var gun_open := 0.0                  # 포방패가 열리고 포가 나온 정도 (0~1)
var gun_aim := PI * 0.5              # 포탄을 쏠 방향 (아래 = PI/2)
var gun_heat := 0.0                  # 쏘기 직전 포구가 달아오름
var gun_recoil := 0.0
var gun_exposed := false             # 포가 드러나 있다 = 제대로 피해가 들어간다
var gun_shake := 0.0                 # 맞고 휘청임
var since_gun := 0
var battery_aim: Array[float] = [0.0, 0.0]   # 보조 포탑 포신 방향 (플레이어를 천천히 따라간다)
var gun_hold := 0.0
var debris: Array[Dictionary] = []
var last := ""                       # 직전에 고른 주 공격 (같은 탄막 반복 방지)
var since_special := 0


func _init() -> void:
	open_time = OPEN_TIME
	attack_gap = GAP
	core_assist_r = 220.0


func _ready() -> void:
	core = ArmoredCore.new(self, REACTOR_POS, REACTOR_OUTLINE, ARMOR_HP, Rect2(), 0, 23)   # 불규칙 장갑판 없음 (장갑 = 코어 포대의 조각 SEGS)
	reset()


func reset() -> void:
	super()
	debris.clear()
	last = ""
	since_special = 0
	for i in glow.size():
		glow[i] = 0.0
	gun_open = 0.0
	gun_aim = PI * 0.5
	gun_heat = 0.0
	gun_recoil = 0.0
	gun_exposed = false
	gun_shake = 0.0
	since_gun = 0
	gun_hold = 0.0
	for i in 2:
		battery_aim[i] = (BARREL_TIPS[i] - BATTERIES[i]).angle()


# ── 외부 시스템 ────────────────────────────────────────
func part_count() -> int:
	return 5


func part_max_hp(i: int) -> int:
	return BIG_HP if i == BIG else PART_HP


func part_radius(i: int) -> float:
	return PART_R[i]


## 보조 포탑 포구: 포신이 플레이어 쪽을 겨눈다
func battery_tip(i: int) -> Vector2:
	return BATTERIES[i] + Vector2.from_angle(battery_aim[i]) * BARREL_LEN


func part_pos(i: int) -> Vector2:
	if i == BIG:
		return gun_center()
	return BATTERIES[i] if i < 2 else SILOS[i - 2]


## 대구경 포대 중심 (포방패 가운데)과 포구 끝
func gun_center() -> Vector2:
	return CASEMATE.get_center()


func gun_muzzle() -> Vector2:
	return gun_center() + Vector2.from_angle(gun_aim) * SHELL_OUT


## 대구경 포대: 포방패가 닫혀 있으면 피해가 크게 준다 (둔탁하게 튕긴다). 드러났을 때 맞으면 한 번에 1/3 + 휘청이며 들어간다
func damage_part(i: int, dmg: int) -> bool:
	if i != BIG:
		return super(i, dmg)
	if not part_alive(i):
		return false
	if gun_exposed:
		if dmg >= 4:                                    # 큰 일격(리버스 드라이브 등)이면 휘청이며 들어간다. 반사탄 같은 작은 피해는 피해만
			gun_shake = 1.0
			for m in active_attacks():
				if m.kind == "big_gun":
					m.hit()
		return _hit_core_armor(dmg)
	part_flash[i] = 0.4
	return _hit_core_armor(int(floor(dmg * BIG_CLOSED_K)))


## 코어 포대 체력 = 코어 장갑: 깎인 만큼 장갑 조각(SEGS 장)이 하나씩 떨어져 나간다 (조각이 튀고 흔들림)
func _hit_core_armor(d: int) -> bool:
	var before := segs_left()
	var broke := super.damage_part(BIG, d)
	core.armor_hp = maxi(0, part_hp[BIG])
	if d > 0:
		core.flash = 1.0
	var after := segs_left()
	for n in range(after, before):                      # 떨어져 나간 조각: 그 모양 그대로 튀어 나간다
		var k: int = SEG_ORDER[n]
		var a := k * TAU / SEGS
		var poly := _seg_poly(a)
		var cen := Vector2.ZERO
		for q in poly:
			cen += q
		cen /= poly.size()
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(q - cen)
		shards.append({"pos": gun_center() + cen, "vel": Vector2.from_angle(a) * randf_range(420.0, 650.0) + Vector2(0, -320), "rot": 0.0, "rotv": randf_range(-5.0, 5.0), "pts": pts})
		emit(Ev.CORE_STAGE, gun_center() + cen, {"stage": SEGS - n, "fell": 1})
	return broke


## 코어 포대의 손상은 장갑 조각(SEGS)이 보여 주므로, 공통 손상 단계(튀는 파편·끊긴 테두리·균열)는 쓰지 않는다
func _part_stage_of(i: int) -> int:
	return 0 if i == BIG else super(i)


## 남은 장갑 조각 수 (체력 비례)
func segs_left() -> int:
	if not part_alive(BIG):
		return 0
	return int(ceil(float(part_hp[BIG]) / BIG_HP * SEGS - 0.001))


## 장갑 조각 하나 (가운데 기준): a 방향의 사다리꼴 — 안쪽 SEG_IN, 바깥 SEG_OUT, 옆 틈 SEG_GAP
func _seg_poly(a: float) -> PackedVector2Array:
	var h := PI / SEGS - SEG_GAP
	return PackedVector2Array([Vector2.from_angle(a - h) * SEG_IN, Vector2.from_angle(a - h) * SEG_OUT, Vector2.from_angle(a + h) * SEG_OUT, Vector2.from_angle(a + h) * SEG_IN])


## 대구경 포대가 부서지면 코어가 열린다 (나머지 외부 시스템은 조건이 아니다)
func _should_open() -> bool:
	return not part_alive(BIG)


## 체력 게이지 (v0.75): 코어 포대 체력만, 코어를 바짝 두른 작은 링 (빨강). 보조 시스템·보호 몫(청록)은 따로 그리지 않는다 — 장갑 조각이 떨어지는 게 보이니까
const GAUGE_R := 176.0               # 장갑 조각 바깥(SEG_OUT)과 하우징 사이

func gauge_values() -> Vector3:
	return Vector3(maxf(0.0, part_hp[BIG]), BIG_HP, BIG_HP)


func gauge_radius() -> float:
	return GAUGE_R


func _draw_gauge() -> void:
	if dead or gauge_vis <= 0.0:
		return
	var vis := minf(1.0, gauge_vis / GAUGE_FADE)
	var hc := gun_center()
	var top := -PI * 0.5
	var w := GAUGE_W * 0.7 * (1.0 + 0.5 * gauge_hit)
	var hp := gauge_values().x
	draw_arc(hc, GAUGE_R, 0.0, TAU, 96, Color(0.03, 0.04, 0.05, 0.75 * vis), w + 6.0)
	if gauge_lag > hp:
		draw_arc(hc, GAUGE_R, top + TAU * hp / BIG_HP, top + TAU * gauge_lag / BIG_HP, 48, Color(1, 1, 1, 0.85 * vis), w)
	if hp > 0.0:
		var red := Color(C_HEART, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
		red.a *= vis
		draw_arc(hc, GAUGE_R, top, top + TAU * hp / BIG_HP, 64, red, w)


## 겨냥 표적 (반사탄·반격 코어): 닫힌 코어 포대는 피해가 거의 안 들어가므로, 드러났을 때만 노린다
func target_pos(from: Vector2) -> Vector2:
	if phase >= 2 or gun_exposed:
		return core.center if phase >= 2 else gun_center()
	var best := Vector2.INF
	for i in 4:
		if part_alive(i) and (best == Vector2.INF or part_pos(i).distance_to(from) < best.distance_to(from)):
			best = part_pos(i)
	return gun_center() if best == Vector2.INF else best


func part_emphasis(i: int) -> float:
	if i != BIG:
		return 1.0
	return 2.2 if gun_exposed else 0.35


## 표적 테두리: 사일로 = 사일로 상자 (보조 포탑은 원, 코어 포대는 _draw_part_outline)
func part_outline(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if i < 2:
		return out                                     # 작은 포탑: 원 테두리
	var p: Vector2 = SILOS[i - 2]
	return PackedVector2Array([p + Vector2(-58, -68), p + Vector2(58, -68), p + Vector2(58, 68), p + Vector2(-58, 68)])


## 코어 포대 표적: 코어 둘레의 붉은 원 하나 (다른 표적 테두리와 같은 굵기). 드러나면 굵고 밝게 맥동한다
func _draw_part_outline(i: int, p: Vector2, r: float, flick: float) -> void:
	if i != BIG:
		super(i, p, r, flick)
		return
	var breathe := 0.5 + 0.5 * sin(t * 2.2)
	var col := Color(C_TARGET, (0.5 + 0.25 * breathe) * flick).lerp(Color.WHITE, part_flash[i])
	var w := 4.0
	if gun_exposed:
		col.a = 1.0
		w = 7.0
		var u := fmod(t * 1.5, 1.0)
		draw_arc(p, (r + 16.0) * (1.0 + 0.25 * u), 0.0, TAU, 48, Color(C_TARGET, 0.6 * (1.0 - u)), 4.0)
	draw_arc(p, r + 16.0, 0.0, TAU, 64, Color(C_TARGET, 0.15 * flick), w * 4.0)   # 바깥 번짐
	draw_arc(p, r + 16.0, 0.0, TAU, 64, col, w)


## 부서진 포대는 포신이, 사일로는 해치가 떨어져 나간다
func _on_part_broken(i: int) -> void:
	var s := 1.0 if i % 2 == 1 else -1.0
	if i == BIG:                                        # 코어 장갑이 다 떨어졌다: 맨 코어가 바로 드러난다 (다음 페이즈)
		gun_exposed = false
		_bare_core()
		return
	if i < 2:
		var b: Vector2 = BATTERIES[i]
		var tip: Vector2 = battery_tip(i)
		debris.append({"pos": (b + tip) * 0.5, "half": (tip - b) * 0.5, "w": 26.0, "vel": Vector2(s * 280.0, -360.0), "rot": 0.0, "rotv": s * 3.2, "rest": false})
	else:
		var p: Vector2 = SILOS[i - 2]
		debris.append({"pos": p + Vector2(0, -36), "half": Vector2(44, 0), "w": 24.0, "vel": Vector2(s * 320.0, -300.0), "rot": 0.0, "rotv": s * 4.0, "rest": false})


# ── 진행 ───────────────────────────────────────────────
func _step_effects(dt: float) -> void:
	for d in debris:
		if d["rest"]:
			continue
		var v: Vector2 = d["vel"]
		v.y += 1500.0 * dt
		d["vel"] = v
		var p: Vector2 = d["pos"] + v * dt
		var rot: float = float(d["rot"]) + float(d["rotv"]) * dt
		var half: Vector2 = d["half"]
		var reach := absf(half.rotated(rot).y) + float(d["w"]) * 0.5
		if p.y + reach >= 0.0:
			p.y = -reach
			d["rest"] = true
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))
		d["pos"] = p
		d["rot"] = rot


func _step_phase(dt: float) -> void:
	attack_gap = GAP_CORE if phase == 3 else GAP
	if last == "spiral":
		attack_gap = GAP_SPIRAL
	for i in glow.size():
		glow[i] = move_toward(glow[i], 0.0, dt * 2.0)
	gun_recoil = move_toward(gun_recoil, 0.0, dt * 3.0)
	for i in 2:                                         # 보조 포탑 포신이 플레이어를 따라 돈다
		battery_aim[i] = lerp_angle(battery_aim[i], (look_at - BATTERIES[i]).angle(), 1.0 - exp(-3.0 * dt))
	gun_shake = move_toward(gun_shake, 0.0, dt * 1.2)
	if not part_alive(BIG):
		gun_open = 0.0
	elif not is_lingering("big_gun") and (atk == null or atk.kind != "big_gun"):   # 포가 들어가며 포방패가 닫힌다
		gun_open = move_toward(gun_open, 0.0, dt / 0.6)
	if phase >= 2 and not core.broken:                 # 디버그 건너뛰기 등
		_bare_core()


## 코어 포대가 부서지면 장갑 없이 드러난 코어만 남는다 (한 대면 터진다)
func _bare_core() -> void:
	core.armor_hp = 0
	core.broken = true
	core.guard = 0.0


## 공격 고르기: 한 번에 큰 패턴 하나 (+ 가끔 작은 곁가지). 대구경 포 차례(BIG_EVERY)에는 포 혼자 쏜다 — 필드가 빌 때까지 잠깐(GUN_HOLD) 기다렸다가.
## 탄막 발사점은 살아 있는 후보(보조 포탑·회전 포탑·배경 포탑·닫힌 포문) 중 플레이어에게서 먼 쪽 — 보조 시스템을 부숴도 차례는 그대로, 방향만 바뀐다
func _choose(ppos: Vector2) -> void:
	var hard := phase == 3
	var calm: bool = lingering.is_empty() and shots.size() <= CALM_SHOTS
	if phase == 1 and part_alive(BIG) and since_gun + 1 >= BIG_EVERY:   # 대구경 포 차례: 단독 (겹치는 탄막 없이)
		if not calm and gun_hold < GUN_HOLD:
			gun_hold += 0.1
			next_t = 0.1
			return
		since_gun = 0
		gun_hold = 0.0
		since_special += 1
		_pick("big_gun", BigGun.new())
		return
	since_special += 1
	since_gun += 1
	var main_kind := ""
	var high := ppos.y < -1900.0
	if since_special >= SPECIAL_EVERY and randf() < (0.75 if high else 0.35):   # 드물게: 천장 프레스(근접) / 반응로 동심원 파동(패리 불가)
		since_special = 0
		var press_ok := shots_clear(ppos)
		main_kind = "press" if press_ok and (high or randf() < 0.4) else "rings"
	else:
		var pool: Array[String] = ["spiral", "fan", "fan"]
		if hard:
			pool.append("overload")
			pool.append("overload")
		while pool.has(last):
			pool.erase(last)
		if not calm:
			while pool.has("spiral"):
				pool.erase("spiral")
		if pool.is_empty():
			pool.append("fan")
		main_kind = pool[randi() % pool.size()]
	var em := _emitter(ppos)
	var c: int = em[0]
	var org: Vector2 = em[1]
	match main_kind:
		"press":
			_pick("press", Press.new())
		"rings":                                            # 패리 불가 동심원 + 가벼운 부채 (모으는 동안 비지 않게)
			_pick("rings", Rings.new(REACTOR_POS))
			var lf2 = Fan.new(c, org, ppos, false)
			lf2.wave_n = 2
			lf2.count = 9
			lf2.wind = 0.5
			start_side(lf2)
		"spiral":
			var sp := Spiral.new(c, org, ppos, hard)
			sp.fixed = true
			sp.center = nearest_dir(org, ppos, DIRS_DOWN)
			_pick("spiral", sp)
		"fan":
			var f := Fan.new(c, org, ppos, hard)
			f.fixed = true
			f.aim = nearest_dir(org, ppos, DIRS_DOWN)
			if not hard:                                    # 한꺼번에 너무 많지 않게
				f.wave_n = 2
				f.count = 11
				f.wind = 0.6
			_pick("fan", f)
			if randf() < 0.45 and not is_lingering("homing"):   # 가끔: 유도탄이 곁들여진다 (포드 → 없으면 배경 포탑)
				start_side(Homing.new())
		_:
			_pick("overload", Overload.new(REACTOR_POS))


func _pick(kind: String, a) -> void:
	last = kind
	start_attack(a)


## 탄막 발사점 [발광 번호, 위치]: 살아 있는 후보 중 무작위 둘을 골라 플레이어에게서 더 먼 쪽 (탄이 날아올 시간).
## 후보 = 보조 포탑(살아 있으면) · 회전 포탑 · 배경 포탑 둘 · 닫힌 대구경 포대의 포문 (코어 페이즈는 회전 포탑·배경 포탑)
## 보조 포탑이 살아 있으면 절반은 그 포탑이 쏜다 (부술 이유가 보이게: 부수면 그쪽 탄이 멎는다)
func _emitter(ppos: Vector2) -> Array:
	var cands := [[-1, SPIRE_TOP], [-5, BG_GUNS[0]], [-6, BG_GUNS[1]]]
	if phase == 1:
		var bats := []
		for i in 2:
			if part_alive(i):
				bats.append([i, battery_tip(i)])
		if not bats.is_empty() and randf() < 0.5:
			var fb: Array = bats[0]
			for bt in bats:
				if ppos.distance_to(bt[1]) > ppos.distance_to(fb[1]):
					fb = bt
			return fb
		cands.append_array(bats)
		if part_alive(BIG) and gun_open <= 0.0:
			cands.append([-7, GUN_PORT])
	var a: Array = cands[randi() % cands.size()]
	var b: Array = cands[randi() % cands.size()]
	return a if ppos.distance_to(a[1]) >= ppos.distance_to(b[1]) else b


## 유도탄 발사점 [[번호, 위치]]: 페이즈 1은 살아 있는 사일로, 코어 페이즈는 배기구 둘
func homing_origins() -> Array:
	var out := []
	if phase == 3:
		out.append([-1, VENTS[0]])
		out.append([-1, VENTS[1]])
		return out
	for k in 2:
		if part_alive(2 + k):
			out.append([2 + k, SILOS[k] + Vector2(0, -60)])
	if out.is_empty():                                  # 포드를 다 부숴도 차례는 쉬지 않는다: 배경 포탑이 잇는다
		out.append([-5, BG_GUNS[0]])
		out.append([-6, BG_GUNS[1]])
	return out


## 발사 전 발광: 0~3 부위, -1 회전 포탑(코어 페이즈 배기구 포함), -4 반응로(동심원 파동), -5·-6 배경 포탑, -7 포문
func set_glow(c: int, v: float) -> void:
	glow[_glow_idx(c)] = v


func glow_of(c: int) -> float:
	return glow[_glow_idx(c)]


static func _glow_idx(c: int) -> int:
	if c >= 0:
		return c
	match c:
		-4:
			return 6
		-1:
			return 4
		-5:
			return 7
		-6:
			return 8
		-7:
			return 9
	return 5


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_heat_aura()
	_draw_backdrop()
	_draw_searchlight()
	_draw_stacks()
	_draw_smoke()
	_draw_tiers()
	_draw_spine()
	_draw_sponsons()
	_draw_roof()
	_draw_casemate()
	if phase >= 2:
		_draw_reactor()
	_draw_ciws()
	_draw_bg_guns()
	_draw_batteries()
	_draw_silos()
	_draw_treads()
	_draw_part_marks()
	_draw_gauge()
	_draw_debris()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


## ── 대기 모션 (그림만, 판정·발사점은 그대로) ──
## 첨탑 탐조등: 옅은 빛줄기가 경기장을 천천히 훑다가 플레이어 쪽으로 조금 끌린다
func _draw_searchlight() -> void:
	if dead:
		return
	var o := Vector2(0, -2960)                                     # 함교 위 탐조등
	var to_p := (look_at - o).angle()
	var a := lerp_angle(PI * 0.5 + sin(t * 0.35) * 1.1, to_p, 0.35)
	var pts := PackedVector2Array([o, o + Vector2.from_angle(a - 0.09) * 2600.0, o + Vector2.from_angle(a + 0.09) * 2600.0])
	draw_colored_polygon(pts, Color(1.0, 0.92, 0.7, 0.035))
	draw_line(o, o + Vector2.from_angle(a) * 2600.0, Color(1.0, 0.92, 0.7, 0.05), 6.0)


## 뒤쪽 열기 후광: 용광로처럼 달아오른 붉은 빛 (크기를 느끼게)
func _draw_heat_aura() -> void:
	var dim := 1.0 if not dead else maxf(0.0, 1.0 - death_t * 0.6)
	var flick := 0.85 + 0.15 * sin(t * 3.1) * sin(t * 1.7)
	_soft_glow(Vector2(0, -1400), 1500.0, Color(1.0, 0.38, 0.12), 0.13 * dim * flick)
	_soft_glow(Vector2(0, -200), 950.0, Color(1.0, 0.4, 0.1), 0.12 * dim)       # 차대 아래 바닥 열기










## ── 포격 성채 (그림만) ─────────────────────────────────
# 층: [아래 반폭, 위 반폭, 아래 y, 위 y]. 위층일수록 좁아져 층마다 턱(난간)이 생긴다
const TIERS := [[1150.0, 1100.0, -420.0, -1150.0], [960.0, 900.0, -1150.0, -1950.0], [790.0, 710.0, -1950.0, -2700.0]]
const ROOF := [430.0, 360.0, -2700.0, -3000.0]
const CASEMATE := Rect2(-250, -1750, 500, 400)       # 코어 포대의 포방패 (2층 가운데)
const C_BACK := Color(0.055, 0.06, 0.075)            # 배경 포탑 (멀리, 푸른 기)
const DEPTH := Vector2(110.0, -70.0)                  # 비스듬히 본 깊이 (오른쪽 옆면·층 윗면이 보인다)
const C_FACE := Color(0.13, 0.125, 0.13)              # 정면 장갑
const C_SIDE := Color(0.07, 0.068, 0.075)             # 옆면 (그늘)
const C_TOP := Color(0.2, 0.19, 0.18)                 # 층 윗면 (빛을 받는 난간)


func _tier_poly(tr: Array) -> PackedVector2Array:
	var bw: float = tr[0]
	var tw: float = tr[1]
	var by: float = tr[2]
	var ty: float = tr[3]
	var ch := 40.0                                    # 모서리를 깎는다
	return PackedVector2Array([Vector2(-bw, by), Vector2(bw, by), Vector2(tw, ty + ch), Vector2(tw - ch, ty), Vector2(-tw + ch, ty), Vector2(-tw, ty + ch)])


## 성채 뒤편의 배경 포탑들 (멀리, 어둡게): 양옆으로 높이 솟은 탑과 포신 — 화면을 끝까지 채운다. 판정 없음
func _draw_backdrop() -> void:
	for sd in [-1.0, 1.0]:
		for k in 2:
			var x: float = sd * (930.0 - k * 330.0)
			var top := -2650.0 - k * 520.0
			var w := 150.0 - k * 20.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - w, -1100), Vector2(x + w, -1100), Vector2(x + w * 0.8, top), Vector2(x - w * 0.8, top)]), C_BACK)
			draw_line(Vector2(x - w * 0.8, top), Vector2(x + w * 0.8, top), Color(C_RIM, 0.15), 3.0)
			var a: float = -PI * 0.5 + sd * (0.5 + 0.12 * sin(t * 0.4 + k * 2.0))   # 천천히 겨누는 배경 포신
			var base := Vector2(x, top + 40.0)
			_cap(base, base + Vector2.from_angle(a) * 260.0, 30.0, C_BACK)
			draw_circle(base, 48.0, C_BACK)
			for q in 4:                                               # 창 불빛
				var on := 0.5 + 0.5 * sin(t * 1.3 + q * 1.7 + k + sd)
				draw_rect(Rect2(x - 12, top + 140 + q * 220, 24, 34), Color(1.0, 0.6, 0.25, 0.12 + 0.15 * on))


## 층층이 쌓인 성채 몸통: 층마다 장갑판·리벳·녹 줄무늬, 층 사이 턱에서 용광로 빛이 새어 나오고, 왼쪽 위에서 테두리 빛
func _draw_tiers() -> void:
	var lit := 1.0 if not dead else 0.25
	for ti in range(TIERS.size() - 1, -1, -1):                       # 위층부터 (아래층의 윗면이 위층 밑동을 가린다)
		var tr: Array = TIERS[ti]
		var poly := _tier_poly(tr)
		var bw0: float = tr[0]
		var tw0: float = tr[1]
		var by0: float = tr[2]
		var ty0: float = tr[3]
		draw_colored_polygon(PackedVector2Array([Vector2(bw0, by0), Vector2(bw0, by0) + DEPTH, Vector2(tw0, ty0 + 40.0) + DEPTH, Vector2(tw0, ty0 + 40.0)]), C_SIDE)   # 오른쪽 옆면
		draw_colored_polygon(PackedVector2Array([Vector2(-tw0 + 40.0, ty0), Vector2(tw0 - 40.0, ty0), Vector2(tw0 - 40.0, ty0) + DEPTH, Vector2(-tw0 + 40.0, ty0) + DEPTH]), C_TOP)     # 층 윗면
		draw_line(Vector2(-tw0 + 40.0, ty0) + DEPTH, Vector2(tw0 - 40.0, ty0) + DEPTH, Color(C_RIM, 0.6), 3.0)
		draw_colored_polygon(poly, C_FACE)
		var ol := poly.duplicate()
		ol.append(poly[0])
		draw_polyline(ol, Color(C_RIM, 0.5), 4.0)
		var by: float = tr[2]
		var ty: float = tr[3]
		var tw: float = tr[1]
		draw_rect(Rect2(-tw + 10.0, ty + 10.0, tw * 2.0 - 20.0, 70.0), Color(0.0, 0.0, 0.0, 0.35))   # 난간 아래 그늘 (층이 앞으로 튀어나온 느낌)
		for sd in [-1.0, 1.0]:                                         # 모서리 버팀벽 (아래로 넓어지는 경사 장갑)
			var bw2: float = tr[0]
			draw_colored_polygon(PackedVector2Array([Vector2(sd * bw2, by), Vector2(sd * (bw2 - 150.0), by), Vector2(sd * (tw - 40.0), ty + 120.0), Vector2(sd * tw, ty + 60.0)]), C_HULL_DARK)
			draw_line(Vector2(sd * bw2, by), Vector2(sd * tw, ty + 60.0), Color(C_RIM, 0.35), 3.0)
		draw_line(Vector2(-tw, ty + 6.0), Vector2(tw, ty + 6.0), Color(C_RIM, 0.75), 6.0)          # 난간 윗면
		var fl := 0.6 + 0.4 * sin(t * 2.3 + ti)
		draw_line(Vector2(-tw + 20.0, ty + 22.0), Vector2(tw - 20.0, ty + 22.0), Color(0.75, 0.18, 0.05, 0.3 * fl * lit), 8.0)   # 층 사이 열기 (붉고 어둡게)
		var h := by - ty
		for q in 3:                                                    # 가로 장갑 띠
			var y := ty + h * (0.3 + q * 0.25)
			var w: float = lerpf(tr[1], tr[0], (y - ty) / h)
			draw_line(Vector2(-w + 30.0, y), Vector2(w - 30.0, y), C_HULL_DARK, 10.0)
			draw_line(Vector2(-w + 30.0, y - 8.0), Vector2(w - 30.0, y - 8.0), Color(C_RIM, 0.18), 2.0)
		for q in 7:                                                    # 세로 이음매 + 리벳
			var u := -0.75 + q * 0.25
			draw_line(Vector2(u * tr[1], ty + 30.0), Vector2(u * tr[0], by - 10.0), Color(C_HULL_DARK, 0.9), 5.0)
			draw_circle(Vector2(u * lerpf(tr[1], tr[0], 0.5), (ty + by) * 0.5), 6.0, Color(C_RIM, 0.45))
		draw_polyline(PackedVector2Array([Vector2(-tr[0] + 10.0, by - 20.0), Vector2(-tr[1] + 10.0, ty + 50.0)]), Color(0.6, 0.75, 1.0, 0.28), 6.0)   # 테두리 빛 (왼쪽)
		draw_polyline(PackedVector2Array([Vector2(tr[0] - 10.0, by - 20.0), Vector2(tr[1] - 10.0, ty + 50.0)]), Color(1.0, 0.5, 0.2, 0.25 * lit), 5.0)  # 열기 반사 (오른쪽)
	for row in 2:                                                      # 1층 용광로 화구 (일렁임)
		var y := -820.0 - row * 150.0
		for k in 11:
			var x := -800.0 + k * 160.0
			var f2 := 0.55 + 0.45 * sin(t * (3.0 + k * 0.3) + row * 1.7 + k)
			draw_rect(Rect2(x - 40, y - 11, 80, 22), Color(0.05, 0.02, 0.01))
			draw_rect(Rect2(x - 33, y - 6, 66, 12), Color(0.8, 0.2 + 0.1 * f2, 0.05, (0.35 + 0.3 * f2) * lit))   # 장식 빛은 붉고 어둡게 (표적의 금빛 테두리와 구분)
	for k in 8:                                                        # 경고 줄무늬 (1층 아래)
		var x := -560.0 + k * 160.0
		draw_line(Vector2(x, -520), Vector2(x + 60, -450), Color(C_RUST, 0.9), 16.0)


## 가운데 동력 척추 (v0.75): 코어 포대에서 지붕 회전 포탑까지 곧게 뻗은 도관 둘 + 그 사이 3층 가운데의 큰 방열판.
## 코어가 힘을 모으면(gun_heat) 빛 덩어리가 도관을 타고 빠르게 오르고 방열판 틈이 달아오른다. 코어 페이즈엔 불안정하게 깜빡인다 (그림만)
func _draw_spine() -> void:
	var lit := 0.25 if dead else 1.0
	var heat: float = gun_heat
	if phase >= 2 and not dead:
		heat = 0.45 + 0.35 * float(int(t * 9.0) % 3 != 0)
	var gr := Rect2(-230, -2560, 460, 500)                           # 방열판
	draw_rect(gr.grow(26.0), C_HULL_DARK)
	draw_rect(gr.grow(26.0), Color(C_RIM, 0.5), false, 4.0)
	draw_rect(gr, Color(0.03, 0.025, 0.025))
	for q in 10:                                                       # 루버: 틈 사이로 열기가 아래에서 위로 번진다
		var y := gr.position.y + 25.0 + q * 50.0
		var f := 0.5 + 0.5 * sin(t * 2.2 + q * 0.6)
		draw_rect(Rect2(gr.position.x + 18.0, y - 5.0, gr.size.x - 36.0, 10.0), Color(0.8, 0.2, 0.05, (0.1 + 0.15 * f + 0.55 * heat) * lit))
		draw_line(Vector2(gr.position.x + 8.0, y - 16.0), Vector2(gr.end.x - 8.0, y - 16.0), C_FACE, 14.0)
		draw_line(Vector2(gr.position.x + 8.0, y - 22.0), Vector2(gr.end.x - 8.0, y - 22.0), Color(C_RIM, 0.3), 2.0)
	draw_rect(Rect2(-16, gr.position.y, 32, gr.size.y), C_HULL)            # 가운데 기둥
	for sd in [-1.0, 1.0]:                                             # 위쪽 경고 V자 (코어 쪽을 가리킨다)
		draw_line(Vector2(0, gr.position.y - 70.0), Vector2(sd * 120.0, gr.position.y - 130.0), Color(C_RUST, 0.9), 14.0)
	for sd in [-1.0, 1.0]:                                             # 도관 둘 (코어 포대 → 지붕)
		var x: float = sd * 310.0
		var y0 := CASEMATE.position.y - 30.0
		var y1: float = ROOF[2]
		draw_line(Vector2(x, y0), Vector2(x, y1), C_SIDE, 48.0)
		draw_line(Vector2(x, y0), Vector2(x, y1), C_FACE, 30.0)
		draw_line(Vector2(x - 8.0, y0), Vector2(x - 8.0, y1), Color(C_RIM, 0.4), 2.0)
		var y := y0 - 60.0
		while y > y1 + 30.0:                                           # 고정 띠
			draw_rect(Rect2(x - 34.0, y - 10.0, 68.0, 20.0), C_HULL_DARK)
			y -= 150.0
		draw_line(Vector2(x, gr.position.y + 60.0), Vector2(sd * (gr.size.x * 0.5 + 26.0), gr.position.y + 60.0), C_SIDE, 22.0)   # 방열판으로 가는 지관
		draw_line(Vector2(x, gr.end.y - 60.0), Vector2(sd * (gr.size.x * 0.5 + 26.0), gr.end.y - 60.0), C_SIDE, 22.0)
		for k in 3:                                                    # 위로 흐르는 에너지
			var u := fmod(t * (0.25 + 1.4 * heat) + k / 3.0 + (0.5 if sd > 0.0 else 0.0), 1.0)
			var py := lerpf(y0, y1, u)
			draw_rect(Rect2(x - 7.0, py - 34.0, 14.0, 68.0), Color(1.0, 0.55, 0.2, (0.2 + 0.7 * heat) * (1.0 - u * 0.5) * lit))


## 현측 포대: 층마다 양옆 벽에 반원 포좌가 붙고, 긴 포신이 바깥 위로 뻗어 플레이어 쪽으로 천천히 돈다. 가끔 반동하며 포구가 번쩍 (그림만)
func _draw_sponsons() -> void:
	for ti in TIERS.size():
		var tr: Array = TIERS[ti]
		for sd in [-1.0, 1.0]:
			for k in 2:
				if k == 1 and ti >= 1:                             # 보조 시스템(2층 유도탄 포드 · 3층 보조 포탑)이 이 자리를 쓴다
					continue
				var f := 0.3 + 0.4 * k
				var y: float = lerpf(tr[3], tr[2], f)
				var x: float = sd * lerpf(tr[1], tr[0], f)
				var p := Vector2(x - sd * 30.0, y)
				var base_a: float = -PI * 0.5 + sd * (0.75 + 0.2 * k)
				var to_p := (look_at - p).angle()
				var a: float = lerp_angle(base_a, to_p, 0.35)
				var ph: float = fmod(t * 0.45 + ti * 0.31 + k * 0.53 + (0.5 if sd > 0.0 else 0.0), 1.0)
				var recoil := 26.0 * maxf(0.0, 1.0 - ph * 8.0)
				var len := 240.0 - ti * 30.0
				var b0 := p - Vector2.from_angle(a) * recoil
				_cap(b0, b0 + Vector2.from_angle(a) * len, 40.0 - ti * 4.0, C_SIDE)
				_cap(b0, b0 + Vector2.from_angle(a) * len, 26.0 - ti * 3.0, C_FACE)
				draw_line(b0, b0 + Vector2.from_angle(a) * len, Color(C_RIM, 0.45), 3.0)
				draw_circle(b0 + Vector2.from_angle(a) * len, 12.0, Color(0.03, 0.03, 0.03))
				draw_circle(p, 62.0 - ti * 6.0, C_TOP)
				draw_arc(p, 62.0 - ti * 6.0, 0.0, TAU, 20, Color(C_RIM, 0.55), 4.0)
				draw_circle(p, 18.0, C_HULL_DARK)
				if not dead and ph < 0.06:
					draw_circle(b0 + Vector2.from_angle(a) * (len + 20.0), 34.0, Color(1.0, 0.82, 0.45, 0.8))


## 지붕: 함교(불 켜진 창) + 회전 포탑(나선 포화 = SPIRE_TOP) + 레이더 + 안테나 돛대 (천장 너머로)
func _draw_roof() -> void:
	var poly := _tier_poly(ROOF)
	draw_colored_polygon(PackedVector2Array([Vector2(ROOF[0], ROOF[2]), Vector2(ROOF[0], ROOF[2]) + DEPTH, Vector2(ROOF[1], ROOF[3] + 40.0) + DEPTH, Vector2(ROOF[1], ROOF[3] + 40.0)]), C_SIDE)
	for sd in [-1.0, 1.0]:                                             # 안테나 돛대 (뒤)
		draw_line(Vector2(sd * 180.0, -3000), Vector2(sd * 210.0, -3400), C_HULL_DARK, 12.0)
		draw_circle(Vector2(sd * 210.0, -3090), 8.0, Color(1.0, 0.3, 0.2, 0.5 + 0.5 * float(int(t * 2.0 + sd) % 2)))
	draw_colored_polygon(poly, C_FACE)
	var ol := poly.duplicate()
	ol.append(poly[0])
	draw_polyline(ol, Color(C_RIM, 0.55), 4.0)
	var wy := -2960.0
	draw_rect(Rect2(-330, wy - 20, 660, 40), C_HULL_DARK)
	for k in 9:
		var x := -290.0 + k * 72.5
		var on := 0.0 if dead else (0.35 if int(t * 0.7 + k * 3.1) % 7 == 0 else 1.0)
		draw_rect(Rect2(x - 22, wy - 12, 44, 24), Color(1.0, 0.82, 0.5, 0.75 * on))
	var o := Vector2(-260, -3020)                                       # 레이더
	var w := 90.0 * cos(t * 1.4)
	draw_line(o + Vector2(0, 40), o, C_HULL_DARK, 14.0)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-w, -10), o + Vector2(w, -10), o + Vector2(w * 0.7, 26), o + Vector2(-w * 0.7, 26)]), C_HULL)
	draw_line(o + Vector2(-w, -10), o + Vector2(w, -10), Color(C_RIM, 0.6), 3.0)



## 코어 포대: 두꺼운 포방패(셔터 두 짝)가 닫혀 있다가, 쏠 차례에 양옆으로 열리면 안쪽의 에너지 코어가 드러난다.
## 코어 = 가둠 고리 둘이 도는 빛나는 구체 + 네 귀퉁이에서 붙든 집게 팔 + 그 위를 덮은 장갑판(깎일수록 떨어져 나간다).
## 쏘기 전에 둘레에서 에너지가 빨려 들어 코어가 달아오르고(gun_heat), 쏘면 앞쪽에서 대구경 포탄이 만들어져 나간다.
## 맞으면 흔들린다(gun_shake). 장갑이 다 떨어지면 셔터가 찢어진 채 맨 코어가 남는다 (_draw_reactor)
func _draw_casemate() -> void:
	var rc := CASEMATE
	var c := rc.get_center()
	var alive := part_alive(BIG)
	draw_rect(rc.grow(30.0), C_HULL_DARK)
	draw_rect(rc.grow(30.0), Color(C_RIM, 0.55), false, 5.0)
	var op := gun_open if alive else 0.85
	if op > 0.0:                                                       # 열린 포좌 안: 어둡고, 코어 빛이 번진다
		draw_rect(rc, Color(0.04, 0.025, 0.02))
		for q in 3:                                                    # 안쪽 벽의 전력 배관
			var y := rc.position.y + 70.0 + q * 130.0
			draw_line(Vector2(rc.position.x + 20.0, y), Vector2(rc.end.x - 20.0, y), Color(0.12, 0.09, 0.07), 14.0)
			draw_line(Vector2(rc.position.x + 20.0, y), Vector2(rc.end.x - 20.0, y), Color(1.0, 0.5, 0.2, 0.15 * op), 3.0)
	if alive and op > 0.0:
		_draw_core_unit(c + Vector2(sin(t * 53.0), cos(t * 47.0)) * 12.0 * gun_shake, op)
	var half_w := rc.size.x * 0.5
	for sd in [-1.0, 1.0]:                                             # 셔터: 양옆으로 밀려 열린다 (부서지면 한 짝은 찢어져 기운다)
		var slide: float = sd * half_w * 0.92 * op
		var x0: float = (rc.position.x if sd < 0.0 else c.x + 6.0) + slide
		var hr := Rect2(x0, rc.position.y, half_w - 6.0, rc.size.y)
		var torn: bool = not alive and sd > 0.0
		if torn:
			draw_set_transform(Vector2(hr.position.x, hr.end.y), 0.35)
			hr.position = Vector2(0, -hr.size.y)
		draw_rect(hr, C_HULL)
		for q in 4:
			var y := hr.position.y + 50.0 + q * 95.0
			draw_line(Vector2(hr.position.x + 14.0, y), Vector2(hr.end.x - 14.0, y), C_HULL_DARK, 8.0)
			draw_circle(Vector2(hr.position.x + 30.0, y + 20.0), 6.0, Color(C_RIM, 0.5))
			draw_circle(Vector2(hr.end.x - 30.0, y + 20.0), 6.0, Color(C_RIM, 0.5))
		for q in 3:
			var x := hr.position.x + 40.0 + q * 80.0
			draw_line(Vector2(x, hr.end.y - 60.0), Vector2(x + 40.0, hr.end.y - 20.0), Color(C_RUST, 0.8), 12.0)
		if torn:
			draw_set_transform(Vector2.ZERO, 0.0)
	if alive and op <= 0.01:                                           # 닫혀 있을 때: 틈으로 새는 코어 빛
		var heat := 0.5 + 0.5 * sin(t * 1.7)
		draw_line(Vector2(c.x, rc.position.y + 10.0), Vector2(c.x, rc.end.y - 10.0), Color(1.0, 0.55, 0.2, 0.3 + 0.3 * heat), 6.0)
	if not alive and not dead:                                         # 부서진 포좌: 연기
		for k in 5:
			var life := fmod(t * 0.5 + k * 0.2, 1.0)
			draw_circle(c + Vector2(sin(t + k * 1.7) * 60.0, -life * 300.0), 30.0 + life * 60.0, Color(0.25, 0.24, 0.25, 0.4 * (1.0 - life)))
	for sd in [-1.0, 1.0]:                                             # 포방패를 여닫는 유압 실린더 (열리면 늘어난다)
		var a2: Vector2 = Vector2(c.x + sd * (half_w + 30.0), rc.position.y + 40.0)
		var b2 := a2 + Vector2(sd * (90.0 + 80.0 * op), 120.0)
		draw_line(a2, b2, C_HULL_DARK, 22.0)
		draw_line(a2, a2.lerp(b2, 0.55 + 0.3 * op), Color(0.62, 0.66, 0.68, 0.6), 7.0)


## 에너지 코어 (포방패 안): 직선으로만 — 팔각 하우징 + 붉게 타는 팔각 에너지실 + 가운데 마름모 결정(하얗게 달아오름) +
## 조리개처럼 둘러싼 사다리꼴 장갑 조각 8장(체력이 깎일수록 하나씩 떨어져 그 자리로 에너지실이 드러난다) + 네 귀퉁이 고정 버팀대.
## 힘을 모을 때(gun_heat) 여덟 방향의 직선 빛줄기가 결정으로 빨려 들고 결정이 커진다. 쏘면 앞쪽으로 빛이 터진다(gun_recoil)
func _draw_core_unit(c: Vector2, op: float) -> void:
	var heat := gun_heat
	var beat := 0.5 + 0.5 * sin(t * (5.0 + heat * 10.0))
	var red := Color(C_HEART).lerp(Color.WHITE, core.flash * 0.5)
	for k in 4:                                                        # 고정 버팀대 (틀 귀퉁이 → 하우징, 직선)
		var a := PI * 0.25 + k * PI * 0.5
		var p0 := c + Vector2.from_angle(a) * 285.0
		var p1 := c + Vector2.from_angle(a) * 190.0
		draw_line(p0, p1, C_SIDE, 34.0)
		draw_line(p0, p1, C_FACE, 20.0)
		draw_rect(Rect2(p0 - Vector2(16, 16), Vector2(32, 32)), C_HULL_DARK)
	var oct := func(rr: float, rot := PI / 8.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for q in 8:
			pts.append(c + Vector2.from_angle(rot + q * TAU / 8.0) * rr)
		return pts
	var housing: PackedVector2Array = oct.call(200.0)
	draw_colored_polygon(housing, C_SIDE)
	var hl := housing.duplicate()
	hl.append(housing[0])
	draw_polyline(hl, Color(C_RIM, 0.8), 4.0)
	for q in housing:                                                  # 하우징 볼트
		draw_rect(Rect2(q.lerp(c, 0.08) - Vector2(6, 6), Vector2(12, 12)), C_TOP)
	var chamber: PackedVector2Array = oct.call(162.0)
	draw_colored_polygon(chamber, Color(0.25, 0.04, 0.03).lerp(red, 0.35 + 0.35 * heat + 0.1 * beat))   # 에너지실 (조각이 떨어진 자리로 보인다)
	for k in SEGS:                                                     # 에너지실 안쪽 방사선 (직선)
		var a := k * TAU / SEGS
		draw_line(c + Vector2.from_angle(a) * 40.0, c + Vector2.from_angle(a) * 160.0, Color(1.0, 0.75, 0.5, 0.25 + 0.4 * heat), 3.0)
	var left := segs_left()
	for n in range(SEGS - left, SEGS):                                 # 남은 장갑 조각: 어두운 강철 + 바깥 모서리 빛 + 안쪽 모서리 붉은 열
		var k: int = SEG_ORDER[n]
		var a := k * TAU / SEGS
		var poly := _seg_poly(a)
		var wp := PackedVector2Array()
		for q in poly:
			wp.append(c + q)
		draw_colored_polygon(wp, Color(0.15, 0.15, 0.17).lerp(Color.WHITE, core.flash * 0.25))
		draw_line(wp[1], wp[2], Color(0.75, 0.78, 0.82, 0.8), 3.0)
		draw_line(wp[0], wp[3], Color(red, 0.6 + 0.4 * heat), 3.0)
		var mid := c + Vector2.from_angle(a) * (SEG_IN + SEG_OUT) * 0.5
		draw_line(mid - Vector2.from_angle(a + PI * 0.5) * 18.0, mid + Vector2.from_angle(a + PI * 0.5) * 18.0, C_HULL_DARK, 6.0)   # 조각 위 홈
	var cs := (40.0 + 16.0 * heat + 3.0 * beat) * op                  # 가운데 마름모 결정 (천천히 돈다)
	var ca := t * 0.4
	var dia := PackedVector2Array([c + Vector2.from_angle(ca) * cs, c + Vector2.from_angle(ca + PI * 0.5) * cs * 0.7, c + Vector2.from_angle(ca + PI) * cs, c + Vector2.from_angle(ca + PI * 1.5) * cs * 0.7])
	draw_colored_polygon(dia, red.lerp(Color(1.0, 0.95, 0.85), 0.35 + 0.5 * heat))
	var inner := PackedVector2Array()
	for q in dia:
		inner.append(c + (q - c) * 0.5)
	draw_colored_polygon(inner, Color(1.0, 1.0, 0.95))
	var dl := dia.duplicate()
	dl.append(dia[0])
	draw_polyline(dl, Color(1.0, 0.85, 0.7), 2.0)
	if heat > 0.0:                                                     # 빨려 드는 직선 빛줄기 (여덟 방향)
		for k in SEGS:
			var a := k * TAU / SEGS + PI / SEGS
			var u := fmod(t * 1.8 + k * 0.29, 1.0)
			var p0 := c + Vector2.from_angle(a) * lerpf(380.0, 60.0, u)
			draw_line(p0, p0 - Vector2.from_angle(a) * 70.0, Color(1.0, 0.85, 0.6, heat * (0.3 + 0.7 * u)), 4.0)
	if gun_recoil > 0.5:                                               # 쏜 순간: 앞쪽으로 빛이 터진다
		_soft_glow(c + Vector2.from_angle(gun_aim) * SHELL_OUT, 150.0 * gun_recoil, Color(1.0, 0.85, 0.5), 0.8 * gun_recoil)


## 부서지지 않는 발사점: 지붕 회전 포탑 · 배경 포탑 포구 둘 · 닫힌 대구경 포대 아래 포문 (판정 없음, 쏘기 전에 달아오른다)
func _draw_bg_guns() -> void:
	var g := glow[4]
	var spin := t * (0.6 + 2.5 * g)
	draw_circle(SPIRE_TOP, 66.0, C_HULL_DARK)
	draw_arc(SPIRE_TOP, 66.0, 0.0, TAU, 24, Color(C_RIM, 0.6), 4.0)
	for k in 4:
		var a := spin + k * TAU / 4.0
		_cap(SPIRE_TOP + Vector2.from_angle(a) * 36.0, SPIRE_TOP + Vector2.from_angle(a) * 104.0, 18.0, C_HULL)
	draw_circle(SPIRE_TOP, 20.0 + 16.0 * g, Color(C_GLOW, 0.3 + 0.55 * g))
	for k in 2:
		var p: Vector2 = BG_GUNS[k]
		var gk := glow[7 + k]
		draw_circle(p, 46.0, C_BACK.lightened(0.15))
		draw_arc(p, 46.0, 0.0, TAU, 18, Color(C_RIM, 0.35), 3.0)
		draw_circle(p, 16.0 + 14.0 * gk, Color(C_GLOW, 0.25 + 0.6 * gk))
	if part_alive(BIG) and phase == 1:
		var gp := glow[9]
		draw_rect(Rect2(GUN_PORT.x - 60, GUN_PORT.y - 18, 120, 36), C_HULL_DARK)
		draw_circle(GUN_PORT, 12.0 + 12.0 * gp, Color(C_GLOW, 0.3 + 0.6 * gp))


## 근접 방공포 (잔탄의 출처): 층 난간마다 작은 포탑이 줄지어 플레이어를 따라 돌고, 가끔 짧게 번쩍인다
func _draw_ciws() -> void:
	for ti in TIERS.size():
		var tr: Array = TIERS[ti]
		var ty: float = tr[3]
		var tw: float = tr[1]
		var n := 6 - ti
		for k in n:
			var u := -0.85 + 1.7 * k / maxf(1.0, n - 1.0)
			var p := Vector2(u * (tw - 60.0), ty - 6.0)
			if ti == 2 and absf(p.x) < 320.0:
				continue
			if ti == 1 and absf(absf(p.x) - 310.0) < 70.0:          # 가운데 동력 도관 자리
				continue
			var a := (look_at - p).angle()
			_cap(p, p + Vector2.from_angle(a) * 46.0, 12.0, C_HULL_DARK)
			draw_circle(p, 24.0, C_HULL)
			draw_arc(p, 24.0, PI, TAU, 12, Color(C_RIM, 0.6), 3.0)
			if not dead and int(t * 9.0 + k * 3.0 + ti * 5.0) % 23 == 0:
				draw_circle(p + Vector2.from_angle(a) * 52.0, 12.0, Color(1.0, 0.85, 0.45, 0.8))


## 굴뚝 둘: 3층 지붕 양옆으로 높이 솟고, 끝에서 불꽃이 일렁인다 (연기는 _draw_smoke)
func _draw_stacks() -> void:
	for s2 in [-1.0, 1.0]:
		var b := Vector2(s2 * 560.0, -2700.0)
		var top := Vector2(s2 * 590.0, -3150.0)
		draw_colored_polygon(PackedVector2Array([b + Vector2(-56, 0), b + Vector2(56, 0), top + Vector2(46, 0), top + Vector2(-46, 0)]), C_HULL_DARK)
		draw_line(b + Vector2(-s2 * 56, 0), top + Vector2(-s2 * 46, 0), Color(C_RIM, 0.4), 3.0)
		for k in 3:
			var y := lerpf(b.y, top.y, 0.25 + k * 0.25)
			draw_line(Vector2(top.x - 52, y), Vector2(top.x + 52, y), C_HULL, 10.0)
		if dead:
			continue
		for k in 4:
			var ph := fmod(t * 2.4 + k * 0.27 + (0.5 if s2 > 0.0 else 0.0), 1.0)
			draw_circle(top + Vector2(sin(t * 7.0 + k * 2.0) * 10.0, -30.0 - ph * 90.0), 28.0 * (1.0 - ph) + 6.0, Color(1.0, 0.55 + 0.35 * (1.0 - ph), 0.15, 0.55 * (1.0 - ph)))


## 무한궤도: 성채 전체를 받치는 거대한 궤도 둘. 바퀴가 돌고, 궤도판이 흐르고, 용암을 긁어 불똥이 튄다 (그림만)
func _draw_treads() -> void:
	for sd in [-1.0, 1.0]:
		var x0: float = sd * 80.0
		var x1: float = sd * 1150.0
		var rc := Rect2(minf(x0, x1), -420.0, absf(x1 - x0), 400.0)
		draw_rect(rc, C_TREAD)
		draw_rect(rc, Color(C_RIM, 0.45), false, 4.0)
		var roll := fmod(t * 60.0, 70.0)
		for k in 16:                                                   # 궤도판 (흐른다)
			var x := rc.position.x + fmod(k * 70.0 + roll * sd + 1120.0, rc.size.x)
			draw_line(Vector2(x, -420.0), Vector2(x, -396.0), Color(C_RIM, 0.45), 6.0)
			draw_line(Vector2(x, -44.0), Vector2(x, -20.0), Color(C_RIM, 0.45), 6.0)
		for k in 6:                                                    # 바퀴 (돈다)
			var c := Vector2(rc.position.x + 90.0 + k * (rc.size.x - 180.0) / 5.0, -220.0)
			draw_circle(c, 78.0, C_HULL)
			draw_arc(c, 78.0, 0.0, TAU, 24, Color(C_RIM, 0.55), 4.0)
			for q in 4:
				var a: float = t * 1.5 * sd + q * TAU / 4.0
				draw_line(c + Vector2.from_angle(a) * 18.0, c + Vector2.from_angle(a) * 66.0, C_HULL_DARK, 10.0)
			draw_circle(c, 20.0, C_RUST)
		if not dead:                                                   # 용암을 긁는 불똥
			for k in 3:
				var ph := fmod(t * 1.8 + k * 0.33 + (0.5 if sd > 0.0 else 0.0), 1.0)
				var sp := Vector2(rc.position.x + rc.size.x * (0.2 + 0.3 * k), -20.0) + Vector2(-sd * ph * 160.0, -ph * 120.0 + ph * ph * 140.0)
				draw_circle(sp, 6.0 * (1.0 - ph) + 2.0, Color(1.0, 0.7, 0.3, 0.9 * (1.0 - ph)))


## 배기 연기: 상부 장갑 양쪽 굴뚝에서 피어오른다
func _draw_smoke() -> void:
	if dead:
		return
	for s in [-1.0, 1.0]:
		var o := Vector2(s * 590.0, -3200.0)                            # 굴뚝 끝에서
		for k in 6:
			var life := fmod(t * 0.3 + k / 6.0 + (0.33 if s > 0.0 else 0.0), 1.0)
			var p := o + Vector2(s * life * 120.0 + sin(t * 1.5 + k * 1.7) * 18.0, -life * 380.0)
			draw_circle(p, 22.0 + life * 60.0, Color(0.22, 0.2, 0.2, 0.3 * (1.0 - life)))










## 보조 포탑 (외부 시스템 0·1): 3층 양옆 가장자리의 작은 쌍열 포탑. 부서지면 포신이 떨어지고 그루터기에서 불씨
func _draw_batteries() -> void:
	for i in 2:
		var b: Vector2 = BATTERIES[i]
		var tip: Vector2 = battery_tip(i)
		var d := (tip - b).normalized()
		var n := d.orthogonal()
		if part_alive(i):
			for k in [-1.0, 1.0]:
				_cap(b + n * 14.0 * k, tip + n * 14.0 * k, 18.0, C_HULL_DARK)
			var g := glow[i]
			draw_circle(tip, 16.0 + 14.0 * g, Color(C_GLOW, 0.12 + 0.55 * g))
		else:
			_cap(b, b + d * 40.0, 26.0, C_HULL_DARK)
			draw_circle(b + d * 40.0, 10.0, Color(C_HEART, 0.25 + 0.15 * sin(t * 4.0)))
		draw_circle(b, 48.0, C_TOP)
		draw_arc(b, 48.0, PI, TAU, 20, C_RIM, 4.0)
		draw_rect(Rect2(b.x - 56.0, b.y + 20.0, 112.0, 28.0), C_HULL_DARK)


## 유도탄 포드 (외부 시스템 2·3): 2층 바깥 가장자리의 작은 상자. 쏠 때 해치가 열린다. 부서지면 빈 구멍
func _draw_silos() -> void:
	for k in 2:
		var p: Vector2 = SILOS[k]
		var rc := Rect2(p.x - 52.0, p.y - 62.0, 104.0, 124.0)
		draw_rect(rc, C_HULL_DARK)
		draw_rect(rc, Color(C_RIM, 0.6), false, 3.0)
		draw_line(Vector2(rc.position.x, p.y + 10.0), Vector2(rc.end.x, p.y + 10.0), Color(C_RIM, 0.25), 3.0)
		var hatch := p + Vector2(0, -36)
		if part_alive(2 + k):
			var g := glow[2 + k]
			var open := g * 26.0
			draw_rect(Rect2(hatch.x - 44.0 - open, hatch.y - 12.0, 44.0, 24.0), C_TOP)
			draw_rect(Rect2(hatch.x + open, hatch.y - 12.0, 44.0, 24.0), C_TOP)
			if g > 0.0:
				draw_rect(Rect2(hatch.x - open, hatch.y - 12.0, open * 2.0, 24.0), Color(C_GLOW, 0.3 + 0.6 * g))
		else:
			draw_circle(hatch, 22.0, C_CAVITY)
			draw_circle(hatch, 10.0, Color(C_HEART, 0.3 + 0.15 * sin(t * 4.0 + k)))




## 코어 페이즈: 부서진 코어 포대 자리에 장갑 없이 드러난 코어 (한 대면 터진다) + 양옆 유도탄 배기구
func _draw_reactor() -> void:
	var hc := REACTOR_POS
	if dead:
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	_draw_exposed_core(hc, CORE_R, C_HEART)
	for v in VENTS:                                   # 코어 페이즈 유도탄 배기구
		var g := glow[4]
		draw_circle(v, 40.0, C_HULL_DARK)
		draw_arc(v, 40.0, 0.0, TAU, 20, C_RIM, 4.0)
		draw_circle(v, 14.0 + 12.0 * g, Color(C_GLOW, 0.3 + 0.6 * g))
	if focus_glow > 0.0:
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, 290.0, 0.0, TAU, 48, Color(C_TARGET, focus_glow * (0.6 if in_reach else 0.25)), 4.0)


func _draw_debris() -> void:
	for d in debris:
		var p: Vector2 = d["pos"]
		var half: Vector2 = d["half"]
		draw_set_transform(p, float(d["rot"]))
		_cap(-half, half, float(d["w"]), C_HULL_DARK)
		draw_circle(-half, float(d["w"]) * 0.35, Color(C_HEART, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0)

extends "res://scripts/colossus_base.gd"
## 콜로서스 ③ 크라켄 (차지 강습 + 요격 중심형). 천장에 매달린 거대한 기계 문어형 채굴함. 기계 촉수 8개 중 6개가 싸우고, 바깥 2개는 배경이다.
## 표적은 외투막 한가운데의 외눈(동력 코어) 하나뿐. 촉수에는 노릴 곳이 없다 (돌진은 쉬는 촉수를 그냥 통과한다).
## 핵심: 촉수 공격(근접, 회피 불가)이 위치를 잡고 멈춘 순간을 차지 강습으로 요격하면, 그 촉수(구동부, 2번 요격이면 끊어짐)와 코어에 함께 피해가 들어간다.
## 페이즈: 1) 방어막 — 코어가 방어막에 싸여 있다. 돌진·차지 강습은 튕겨 나오고(피해 없음), 리버스 드라이브·반사탄·요격은 뚫고 코어에 피해.
##            방어막이 남아 있을수록 뚫고 들어가는 피해가 적다 (SHIELD_PASS_MIN ~ 100%). 플레이어의 일격은 방어막을 깎지 못한다 — 방어막은 집게로만 깎인다.
##            방어막이 다 깎이거나, 코어가 CORE_FLOOR 까지 깎이면(피해 누적) 산산조각 난다
##         2) 방어막이 깨지는 연출
##         3) 동력 코어 — 직접 노릴 수 있다
## 촉수 = 부가 목표: 근접공격을 요격하면 촉수에 상처가 쌓이고(요격 2번, 강한 요격은 1번) 끊어지면 그 촉수의 패턴·발사점이 사라진다.
##   REGROW_DELAY 뒤 천천히 다시 자란다 (다른 패턴이 한두 번 지나갈 무렵)
## 잘린 집게 = 보너스: 끊긴 촉수 끝의 집게가 공중에서 천천히 떨어진다. 용암에 닿기 전에 차지 강습·리버스 드라이브로 치면
##   눈알로 날아가 꽂힌다 — 방어막이 있으면 방어막을 크게 깎고(CLAW_SHIELD), 방어막이 없으면 코어가 그대로 터진다
## v0.50+: 탄막이 중심 (탄막 7 : 근접 3, 쉬는 시간 짧게). 촉수 끝·배경 다리·분사구가 모두 발사점 (barrage.gd).
##   탄막마다 저격 유도탄(시그니처)이 한 발씩 섞여 날아온다 (따로 쏘지 않는다).
## 몸은 DROP 만큼 낮게 걸려 있다 (코어 작게, 튕겨 올라가도 천장에 붙지 않게).
## 공격: 몸통 내려치기 · 압착(촉수 둘) · 추적 감아치기 · 휩쓸기 · 조이기(촉수 2개 이상 잃은 뒤) · 먹물 포(부채 탄막, 가운데 주탄)
##       · 방전 그물(패리 불가, 드물게) · 연속 내려치기(combo.gd). 패턴 통합: 내려치기·소용돌이·행진 → 연속 내려치기, 휩쓸기·난타 → 휩쓸기,
##       압착·조이기 → 조이기, 먹물 부채·회전 → 먹물, 촉수 끝·양쪽 줄기 → 촉수 끝 물결
## 근접 패턴의 첫 타는 예고가 느리다 (tentacle.gd LEAD_K).
## 촉수 모양은 척추(마디 N 개)로 그린다: 강철 마디판 + 관절 링 + 유압 피스톤 + 집게 끝. 쉬는 촉수는 크라켄이, 공격 중인 촉수는 그 공격 모듈(attacks/tentacle.gd)이 움직인다.
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Hammer := preload("res://scripts/attacks/hammer.gd")
const Chase := preload("res://scripts/attacks/chase.gd")
const Lash := preload("res://scripts/attacks/lash.gd")
const Constrict := preload("res://scripts/attacks/constrict.gd")
const Combo := preload("res://scripts/attacks/combo.gd")
const Net := preload("res://scripts/attacks/net.gd")
const Fan := preload("res://scripts/attacks/fan.gd")
const Barrage := preload("res://scripts/attacks/barrage.gd")
const Rings := preload("res://scripts/attacks/rings.gd")

# ── 구조 ───────────────────────────────────────────────
const DROP := 640.0                          # 몸을 천장에서 이만큼 내려 걸었다 (튕겨 올라가도 천장에 붙지 않게)
const CORE_POS := Vector2(0, -2520.0 + DROP)          # 외눈 = 동력 코어 중심 (외투막 한가운데)
const ARMOR_HP := 320                        # 코어 체력 (장갑판 없이 균열로 보인다). 다 깎이면 한 발 더 맞아야 부서진다 (armored_core.gd)
const SHIELD_HP := 100.0                     # 방어막 내구도 (코어 체력과 따로)
const SHIELD_PASS_MIN := 0.5                 # 방어막이 온전할 때 코어까지 뚫고 들어가는 피해 비율 (집게로 깎일수록 1.0 으로)
const CORE_FLOOR := 100                      # 방어막이 남은 채 코어가 여기까지 깎이면 방어막이 깨진다 (집게 없이 피해 누적으로 여는 길)
const SHIELD_R := 205.0                      # 방어막 반지름
const SHIELD_SHATTER := 1.6                  # 방어막이 깨지는 연출 시간 (페이즈 2)
const CORE_R := 46.0
const EYE_RX := 150.0                        # 눈알(코어 껍질) 반지름 (가로·세로)
const EYE_RY := 112.0
const SIPHON := Vector2(0, -2120.0 + DROP)            # 먹물 포 (외투막 아래 분사구)

# ── 촉수 ───────────────────────────────────────────────
const N := 12                                # 척추 마디 수
# 촉수 0~5 (짝수 = 왼쪽, 홀수 = 오른쪽): 뿌리와 쉬는 자세의 끝
const ROOTS := [Vector2(-430, -2210.0 + DROP), Vector2(430, -2210.0 + DROP), Vector2(-260, -2170.0 + DROP), Vector2(260, -2170.0 + DROP), Vector2(-90, -2150.0 + DROP), Vector2(90, -2150.0 + DROP)]
# 쉬는 자세: 0·1 = 머리 옆으로 치켜들고 위협 (끝이 플레이어 쪽으로 꺾임), 2·3 = 중간 높이로 옆으로 펼침, 4·5 = 아래로 늘어뜨림
const IDLE_TIPS := [Vector2(-780, -2250), Vector2(780, -2250), Vector2(-1060, -1200), Vector2(1060, -1200), Vector2(-330, -620), Vector2(330, -620)]
const IDLE_C1 := [Vector2(-330, 120), Vector2(330, 120), Vector2(-320, 60), Vector2(320, 60), Vector2(-60, 300), Vector2(60, 300)]     # 뿌리 기준 첫 조절점
const IDLE_C2 := [Vector2(-260, 380), Vector2(260, 380), Vector2(150, -180), Vector2(-150, -180), Vector2(120, -260), Vector2(-120, -260)]  # 끝 기준 둘째 조절점
const IDLE_SWAY := [Vector2(70, 60), Vector2(70, 60), Vector2(50, 90), Vector2(50, 90), Vector2(70, 40), Vector2(70, 40)]          # 끝이 흔들리는 폭
const BG_ROOTS := [Vector2(-560, -2300.0 + DROP), Vector2(560, -2300.0 + DROP)]     # 배경 다리 (표적·판정 없음, 방전 그물만 건다)
const BG_TIPS := [Vector2(-1080, -520), Vector2(1080, -520)]
const REGROW_DELAY := 8.0                    # 끊긴 촉수가 다시 자라기 시작할 때까지
const REGROW := 1.6                          # 다시 자라나는 시간
const CLAW_R := 70.0                         # 잘린 집게 판정 반지름 (차지 강습·리버스 드라이브로 친다)
const CLAW_FALL := 380.0                     # 집게가 떨어지는 최고 속도
const CLAW_POP := 1150.0                     # 끊기는 순간 솟구치는 속도 (높이 날아올랐다 떨어지며 칠 틈을 준다)
const CLAW_G := 900.0
const CLAW_SPEED := 2800.0                   # 쳐 낸 집게가 눈알로 날아가는 속도
const CLAW_SHIELD := 34.0                    # 집게 하나가 깎는 방어막 (셋이면 거의 깨진다)
const W_ROOT := 100.0                        # 촉수 굵기 (뿌리 → 끝)
const W_TIP := 40.0
const PART_AT := 3                           # 구동부가 달린 척추 마디
const PART_HP := 16                          # 요격 피해(8)가 두 번 쌓이면 끊어진다. 강한 요격(동조 2배·PERFECT 리버스 드라이브)은 한 번에
const PART_R := 52.0
const GAUGE_R := 262.0                       # 체력 게이지 링 반지름 (방어막 바깥)
const ZAP_TIME := 0.4                        # 요격 피해가 촉수 뿌리에서 코어로 흐르는 전류 줄기

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.45, 0.8)               # 근접 뒤 쉬는 시간
const GAP_CORE := Vector2(0.3, 0.55)
const GAP_FIRE := Vector2(0.25, 0.5)         # 탄막 뒤 (멍때릴 틈을 주지 않는다)
const RANGED_KINDS := ["ink", "fan", "tips", "ring"]
const ROTATION := 2                          # 탄막 → 근접 을 되풀이한다 (근접 차례에 쓸 촉수가 없으면 다음 차례로 미룬다)
const CLEAR_WAIT := 2.5                      # 그래도 이 시간이 지나면 시작한다 (탄이 오래 남아 있을 때)
const CROWD_R := 1300.0                      # 플레이어 둘레 이 안에
const CROWD_CAP := 30                        # 적 탄이 이보다 많으면 다음 공격을 미룬다 (화면을 꽉 채우지 않는다)
const SPECIAL_EVERY := 4                    # 방전 그물(패리 불가)은 공격 이만큼마다 (드물게)
const COMBO_HITS := 3                        # 연타 타수
const SWEEPERS := [4, 5]                     # 휩쓸기·난타는 아래로 늘어진 두 촉수만, 항상 바깥 → 안쪽으로 (방향을 가늠하기 쉽게)

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.06, 0.08, 0.09)
const C_BODY_DARK := Color(0.035, 0.05, 0.06)
const C_RIM := Color(0.4, 0.53, 0.55)
const C_STEEL := Color(0.14, 0.17, 0.19)     # 촉수 마디판
const C_PISTON := Color(0.62, 0.66, 0.68)
const C_PARRY := Color(1.0, 0.88, 0.35)
const C_GLOW := Color(1.0, 0.78, 0.42)

var spines: Array[PackedVector2Array] = []
var bg_spines: Array[PackedVector2Array] = []
var busy: Array = [null, null, null, null, null, null]   # 촉수를 붙잡은 공격 모듈
var grown: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]   # 촉수가 자란 정도 (0 = 떨어져 나가 뿌리만, 1 = 다 자람)
var regrow_t: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 다시 자라기 시작할 때까지 남은 시간
var bg_hold: Array = []                      # 방전 그물이 배경 다리 끝을 붙잡은 위치 [왼, 오] (빈 배열 = 쉼)
var hit_dir := Vector2.ZERO                  # 마지막으로 요격당한 방향 (부서진 촉수가 그쪽으로 날아간다)
var hit_dir_t := -99.0
var siphon_glow := 0.0
var debris: Array[Dictionary] = []           # 떨어져 나간 촉수 조각
var last := ""
var want := ""                               # 탄이 걷히길 기다리는 근접 패턴
var want_t := 0.0
var eye_charge := 0.0                         # 코어 단계: 눈알이 패리 불가 동심원을 모으는 정도 (보라)
var emit_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 발사점 발광 (0~5 촉수 끝, 6·7 배경 다리)
var _ppos := Vector2(0, -400)
var since_special := 0
var zaps: Array[Dictionary] = []             # 코어로 흐르는 전류 줄기 {from, t}
var shield_flash := 0.0                      # 방어막에 무언가 부딪힘 (번쩍)
var shield_hit_n := Vector2.UP               # 부딪힌 쪽
var cracks: Array[PackedVector2Array] = []   # 코어 균열선 (피해가 쌓일수록 앞에서부터 더 많이 그린다)
var shield_hp := SHIELD_HP
var shield_cracks: Array[PackedVector2Array] = []   # 방어막 금 (닳을수록 더 많이)
var pierce := 0.0                            # 방금 방어막을 뚫은 일격 연출 (1 → 0)
var pierce_k := 0.0                          # 그 일격이 뚫고 들어간 비율 (얼마나 깊이 들어갔나)
var pierce_n := Vector2.DOWN
var claws: Array[Dictionary] = []            # 잘린 집게 {pos, vel, rot, rotv, fly}
var rot_k := 0                               # 탄막·탄막·근접 순서


func _init() -> void:
	open_time = SHIELD_SHATTER
	attack_gap = GAP
	core_assist_r = 170.0


func _ready() -> void:
	var outline := []
	for k in 20:
		var a := k * TAU / 20.0
		outline.append(Vector2(cos(a) * EYE_RX, sin(a) * EYE_RY))
	core = ArmoredCore.new(self, CORE_POS, outline, ARMOR_HP, Rect2(), 0, 37)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for k in 10:                                         # 균열: 동공 가장자리에서 바깥으로 갈라지는 번개 모양
		var a := k * TAU / 10.0 + rng.randf_range(-0.25, 0.25)
		var p := Vector2.from_angle(a) * CORE_R * 0.8
		var line := PackedVector2Array([p])
		var d := Vector2.from_angle(a)
		for s in 4:
			d = d.rotated(rng.randf_range(-0.6, 0.6))
			p += d * rng.randf_range(24.0, 38.0)
			p = Vector2(clampf(p.x, -EYE_RX * 0.9, EYE_RX * 0.9), clampf(p.y, -EYE_RY * 0.88, EYE_RY * 0.88))
			line.append(p)
		cracks.append(line)
	for k in 9:                                          # 방어막 금: 가장자리에서 안쪽으로
		var a := k * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var p := Vector2.from_angle(a) * SHIELD_R
		var line := PackedVector2Array([p])
		var d := -Vector2.from_angle(a)
		for s in 3:
			d = d.rotated(rng.randf_range(-0.7, 0.7))
			p += d * rng.randf_range(30.0, 50.0)
			line.append(p)
		shield_cracks.append(line)
	reset()


func reset() -> void:
	spines.clear()
	bg_spines.clear()
	for i in 6:
		spines.append(PackedVector2Array())
		busy[i] = null
		grown[i] = 1.0
		regrow_t[i] = 0.0
	for k in 2:
		bg_spines.append(PackedVector2Array())
	super()
	for i in 6:
		spines[i] = _idle_spine(i)
	for k in 2:
		bg_spines[k] = _bg_spine(k, BG_TIPS[k])
	bg_hold = []
	hit_dir_t = -99.0
	siphon_glow = 0.0
	debris.clear()
	last = ""
	want = ""
	for k in 8:
		emit_glow[k] = 0.0
	since_special = 0
	zaps.clear()
	shield_flash = 0.0
	shield_hp = SHIELD_HP
	pierce = 0.0
	claws.clear()
	rot_k = 0


# ── 방어막 · 외눈 코어 ─────────────────────────────────
## 표적은 코어 하나. 페이즈 1은 방어막 원({kind:"shield"}), 그 뒤는 눈알 껍질(core.hit). 촉수에는 표적이 없다
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead:
		return {}
	if phase == 1:
		var d := p - CORE_POS
		if d.length() < r + SHIELD_R:
			return {"kind": "shield", "n": d.normalized() if d.length() > 0.1 else Vector2.DOWN}
		return {}
	return core.hit(p, r)


func assist_targets(from := Vector2.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	out.append({"pos": CORE_POS, "r": SHIELD_R if phase == 1 else core_assist_r})
	for c in claws:
		if not c["fly"]:
			out.append({"pos": c["pos"], "r": CLAW_R})
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


func target_pos(_from: Vector2) -> Vector2:
	return CORE_POS


## 방어막을 뚫은 피해 (리버스 드라이브·반사탄·완전 동조 차지). 돌진·차지 강습은 main.gd 가 먼저 막는다
func damage(hit: Dictionary, dmg: int) -> bool:
	if hit["kind"] == "shield":
		shield_flash = 1.0
		shield_hit_n = hit["n"]
		_feed_core(dmg)
		return false
	return super(hit, dmg)


## 방어막이 남은 비율 (1 = 온전)
func shield_frac() -> float:
	return clampf(shield_hp / SHIELD_HP, 0.0, 1.0)


## 지금 방어막을 뚫고 코어까지 들어가는 피해 비율: 방어막이 닳을수록 커진다
func shield_pass() -> float:
	return lerpf(1.0, SHIELD_PASS_MIN, shield_frac())


## 방어막 너머 코어에 피해를 준다 (페이즈 1): 뚫는 비율만큼 코어에만 (방어막은 그대로).
## 코어가 CORE_FLOOR 까지 깎이면 방어막이 깨진다. 페이즈 3이면 그대로 코어에
func _feed_core(dmg: int) -> void:
	if phase != 1:
		core.damage(dmg)
		return
	var k := shield_pass()
	pierce = 1.0
	pierce_k = k
	pierce_n = shield_hit_n
	var d := mini(maxi(1, int(round(dmg * k))), core.armor_hp - CORE_FLOOR)
	if d > 0:
		core.damage(d)
	else:
		core.flash = 1.0
	if core.armor_hp <= CORE_FLOOR:
		_shatter()


func _wear_shield(v: float) -> void:
	shield_hp = maxf(0.0, shield_hp - v)
	gauge_vis = GAUGE_SHOW                                # 방어막만 깎여도 게이지가 뜬다
	gauge_hit = 1.0
	if phase == 1 and shield_hp <= 0.0:
		_shatter()


## 방어막이 산산조각 난다 → 페이즈 2(연출) → 3(코어 노출)
func _shatter() -> void:
	phase = 2
	open_t = 0.0
	atk = null
	lingering.clear()
	next_t = open_time + 1.0
	emit(Ev.CORE_OPEN, core.center)
	shield_flash = 1.0
	for k in 14:
		var a := k * TAU / 14.0 + randf_range(-0.1, 0.1)
		var at := CORE_POS + Vector2.from_angle(a) * SHIELD_R
		_spawn_shard(at, randf_range(18.0, 30.0), Vector2.from_angle(a) * randf_range(500.0, 900.0) + Vector2(0, -300))


## 촉수 요격 (main.gd _clash, 방어막 단계): 촉수에 상처가 쌓이고(PART_HP) 다 차면 끊어진다. 요격 피해는 방어막 너머 코어에도 (전류 줄기)
func damage_part(i: int, dmg: int) -> bool:
	if not part_alive(i):
		return false
	zaps.append({"from": i, "t": 0.0})
	_feed_core(dmg)
	return _wound(i, dmg)


## 코어 단계: 촉수를 요격 → 상처가 쌓이고 코어에 바로 피해. 부서지면 true (승리)
func intercept_core(i: int, dmg: int) -> bool:
	if part_alive(i):
		_wound(i, dmg)
	zaps.append({"from": i, "t": 0.0})
	return damage_core(dmg)


## 촉수에 상처: 다 차면 끊어 true. 아니면 금이 가고 불꽃이 튄다
func _wound(i: int, dmg: int) -> bool:
	var pos := part_pos(i)
	part_hp[i] -= dmg
	part_flash[i] = 1.0
	if part_hp[i] > 0:
		part_stage[i] = 2
		emit(Ev.PART_STAGE, pos)
		return false
	_cut(i)
	emit(Ev.PART_BREAK, pos)
	return true


## 촉수를 끊는다: 조각이 날아가고, 끝의 집게가 떨어지기 시작하고, 그 촉수를 쓰던 공격은 끊기고, REGROW_DELAY 뒤 다시 자란다
func _cut(i: int) -> void:
	part_flash[i] = 1.0
	var sp := spines[i]
	var tip := sp[N - 1]
	var tdir := (tip - sp[N - 2]).normalized() if tip.distance_to(sp[N - 2]) > 1.0 else Vector2.DOWN
	var side := hit_dir.x * 420.0 if t - hit_dir_t < 0.6 else signf(tip.x) * 260.0   # 맞은 방향으로 튕겨 나가며 높이 솟는다
	claws.append({"pos": tip, "vel": Vector2(side, -CLAW_POP), "rot": tdir.angle(), "rotv": randf_range(9.0, 12.0) * (1.0 if randf() < 0.5 else -1.0), "fly": false})
	_on_part_broken(i)
	part_hp[i] = 0
	regrow_t[i] = REGROW_DELAY
	if atk != null and atk.part == i:
		finish_attack()


# ── 외부 시스템 ────────────────────────────────────────
func part_count() -> int:
	return 6


func part_max_hp(_i: int) -> int:
	return PART_HP


func part_radius(_i: int) -> float:
	return PART_R


func part_pos(i: int) -> Vector2:
	if spines.size() <= i or spines[i].is_empty():
		return ROOTS[i]
	return spines[i][PART_AT]


## 구동부가 부서지면 촉수가 뿌리째 떨어져 나가 세 토막으로 빠르게 멀리 날아간다 (방금 요격당했다면 부딪힌 방향으로).
## 그 촉수를 쓰던 공격(보조 공격 포함)은 끊긴다
func _on_part_broken(i: int) -> void:
	var sp := spines[i]
	var dir := hit_dir if t - hit_dir_t < 0.6 else Vector2(signf(ROOTS[i].x), -0.7).normalized()   # 요격이 아니면 바깥 위로
	for c in 3:
		var a := c * 4
		var b := mini(a + 4, N - 1)
		var cen := (sp[a] + sp[b]) * 0.5
		var pts := PackedVector2Array()
		var ws := PackedFloat32Array()
		for q in range(a, b + 1):
			pts.append(sp[q] - cen)
			ws.append(width_at(q))
		var v := dir.rotated(randf_range(-0.45, 0.45)) * randf_range(1000.0, 1300.0) * (1.0 + 0.3 * c) + Vector2(0, -520.0)
		debris.append({"pos": cen, "pts": pts, "ws": ws, "vel": v, "rot": 0.0, "rotv": randf_range(6.0, 11.0) * (1.0 if randf() < 0.5 else -1.0), "splash": false})
	grown[i] = 0.0
	spines[i] = _idle_spine(i)
	for m in lingering.duplicate():
		if m.has_method("uses") and m.uses(i):
			lingering.erase(m)
	if atk != null and atk.has_method("uses") and atk.uses(i) and atk.part != i:
		finish_attack()


func _part_highlight(i: int) -> bool:
	var m = busy[i]
	return m != null and m.has_method("is_staggered") and m.is_staggered(i)


## 이 촉수로 지금 공격할 수 있는가
func tent_ready(i: int) -> bool:
	return busy[i] == null and phase != 2 and part_alive(i) and grown[i] >= 1.0


## 코어가 상할수록 예고가 짧아진다 (공격 모듈이 곱한다). 촉수를 끊는 건 손해가 아니다
func tempo() -> float:
	return 1.0 - 0.22 * core.frac()


## 탄 속도: 코어가 상할수록 빨라진다 (촉수 수와는 무관) × 스테이지 난이도
func bolt_mult() -> float:
	return (1.0 + 0.3 * core.frac()) * (1.0 + LEVEL_SPEEDUP * level)


# ── 척추 ───────────────────────────────────────────────
func width_at(k: int) -> float:
	return lerpf(W_ROOT, W_TIP, float(k) / (N - 1))


## 판정 선분들 [[a, b, 반폭]] (k0 번째 마디부터 끝까지). half >= 0 이면 반폭을 그 값으로 고정
func tent_segs(i: int, k0: int, half := -1.0) -> Array:
	var sp := spines[i]
	var out := []
	for k in range(k0, N - 1):
		out.append([sp[k], sp[k + 1], half if half >= 0.0 else (width_at(k) + width_at(k + 1)) * 0.25])
	return out


static func _bezier_spine(root: Vector2, tip: Vector2, bend: float, n: int) -> PackedVector2Array:
	var d := tip - root
	var perp := d.orthogonal().normalized()
	var c1 := root + d * 0.33 + perp * bend
	var c2 := root + d * 0.66 - perp * bend * 0.8
	var sp := PackedVector2Array()
	for q in n:
		sp.append(root.bezier_interpolate(c1, c2, tip, float(q) / (n - 1)))
	return sp


## 쉬는 자세 (IDLE_*): 끝이 천천히 원을 그리며 흔들리고, 조절점이 시차를 두고 따라가 몸통에 물결이 흐른다.
## 치켜든 촉수(0·1)는 가끔 움찔하며 뒤로 젖혔다 돌아온다 (위협). 자란 정도(grown)만큼만 뿌리에서 뻗는다 (떨어져 나간 촉수는 뿌리에 모인다)
func _idle_spine(i: int) -> PackedVector2Array:
	var root: Vector2 = ROOTS[i]
	var ph := t + i * 1.7
	var sw: Vector2 = IDLE_SWAY[i]
	var tip: Vector2 = IDLE_TIPS[i] + Vector2(sin(ph * 0.9) * sw.x, cos(ph * 0.7) * sw.y)
	if i < 2:                                            # 위협: 주기적으로 뒤로 젖혔다가 앞으로 튕기듯 돌아온다
		var cyc := fmod(ph * 0.35, 1.0)
		var rear := smoothstep(0.0, 0.25, cyc) * (1.0 - smoothstep(0.25, 0.4, cyc))
		tip += Vector2(signf(root.x) * 90.0, -70.0) * rear
	var c1: Vector2 = root + IDLE_C1[i] + Vector2(sin(ph * 0.9 - 1.2), cos(ph * 0.7 - 1.2)) * sw * 0.5
	var c2: Vector2 = tip + IDLE_C2[i] + Vector2(sin(ph * 0.9 - 0.6), cos(ph * 0.7 - 0.6)) * sw * 0.8
	var sp := PackedVector2Array()
	for q in N:
		sp.append(root.bezier_interpolate(c1, c2, tip, float(q) / (N - 1)))
	var g := grown[i]
	if g < 1.0:
		var e := g * g * (3.0 - 2.0 * g)
		for q in N:
			sp[q] = root + (sp[q] - root) * e
	return sp


func _bg_spine(k: int, tip: Vector2) -> PackedVector2Array:
	var s := 1.0 if k == 1 else -1.0
	return _bezier_spine(BG_ROOTS[k], tip, s * (140.0 + 50.0 * sin(t * 0.5 + k * 2.0)), N)


# ── 진행 ───────────────────────────────────────────────
## 매 프레임: 쉬는 촉수는 제자리 자세로 천천히 돌아간다 (끝난 공격이 붙잡던 촉수도 여기서 놓인다)
func _step_effects(dt: float) -> void:
	var live := active_attacks()
	var ease_k := 1.0 - exp(-5.0 * dt)
	for i in 6:
		if busy[i] != null and not live.has(busy[i]):
			busy[i] = null
		if busy[i] == null:
			var to := _idle_spine(i)
			if grown[i] < 1.0:                      # 떨어져 나갔거나 자라는 중: 자람에 맞춰 바로
				spines[i] = to
				continue
			var sp := spines[i]
			for q in N:
				sp[q] = sp[q].lerp(to[q], ease_k)
			spines[i] = sp
	for k in 2:
		var tip: Vector2 = BG_TIPS[k] + Vector2(0, sin(t * 0.6 + k) * 40.0)
		var fast := false
		if not bg_hold.is_empty() and not dead:
			tip = bg_hold[k]
			fast = true
		var to := _bg_spine(k, tip)
		var sp := bg_spines[k]
		var kk := 1.0 - exp(-(14.0 if fast else 3.0) * dt)
		for q in N:
			sp[q] = sp[q].lerp(to[q], kk)
		bg_spines[k] = sp
	_step_debris(dt)


func step(dt: float, ppos: Vector2) -> void:
	_ppos = ppos
	super(dt, ppos)


func _on_attack_finished() -> void:
	if RANGED_KINDS.has(last):
		attack_gap = GAP_FIRE
	else:
		attack_gap = GAP_CORE if phase == 3 else GAP


func _step_phase(dt: float) -> void:
	for k in 8:
		emit_glow[k] = move_toward(emit_glow[k], 0.0, dt * 2.5)
	eye_charge = move_toward(eye_charge, 0.0, dt * 1.5)
	shield_flash = maxf(0.0, shield_flash - dt * 3.0)
	for z in zaps.duplicate():
		z["t"] = float(z["t"]) + dt
		if z["t"] >= ZAP_TIME:
			zaps.erase(z)
	siphon_glow = move_toward(siphon_glow, 0.0, dt * 2.0)
	pierce = maxf(0.0, pierce - dt * 2.5)
	_step_claws(dt)
	for i in 6:                                  # 끊긴 촉수: 잠시 뒤 뿌리에서 천천히 다시 자란다
		if part_alive(i) or dead:
			continue
		if regrow_t[i] > 0.0:
			regrow_t[i] -= dt
			continue
		grown[i] = minf(1.0, grown[i] + dt / REGROW)
		if grown[i] >= 1.0:
			part_hp[i] = PART_HP
			part_stage[i] = 0


## 잘린 집게: 살짝 튀어 올랐다가 천천히 떨어지며 돈다 → 용암에 닿으면 가라앉는다. 쳐 낸 집게는 눈알로 곧장 날아가 꽂힌다
func _step_claws(dt: float) -> void:
	for c in claws.duplicate():
		var p: Vector2 = c["pos"]
		if c["fly"]:
			var to := CORE_POS - p
			var stepd := CLAW_SPEED * dt
			c["rot"] = to.angle()
			if to.length() <= stepd + 40.0:
				claws.erase(c)
				_claw_impact(CORE_POS - to.normalized() * (SHIELD_R if phase == 1 else 40.0), to.normalized())
				continue
			c["pos"] = p + to.normalized() * stepd
			continue
		var v: Vector2 = c["vel"]
		v.y = minf(CLAW_FALL, v.y + CLAW_G * dt)
		v.x = move_toward(v.x, 0.0, 160.0 * dt)
		p += v * dt
		if absf(p.x) > 1100.0:                                 # 벽에 튕긴다
			p.x = signf(p.x) * 1100.0
			v.x = -v.x * 0.5
		p.y = maxf(p.y, -3000.0)
		c["vel"] = v
		c["pos"] = p
		c["rotv"] = move_toward(float(c["rotv"]), signf(float(c["rotv"])) * 2.5, 6.0 * dt)   # 빠르게 돌다가 천천히
		c["rot"] = float(c["rot"]) + float(c["rotv"]) * dt
		if p.y > -30.0:
			claws.erase(c)
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))


## 이 위치에 떨어지는 집게가 있으면 그 번호 (없으면 -1). main.try_clash 가 차지 강습·리버스 드라이브로 부른다
func claw_at(p: Vector2, r: float) -> int:
	for k in claws.size():
		if not claws[k]["fly"] and p.distance_to(claws[k]["pos"]) < r + CLAW_R:
			return k
	return -1


func launch_claw(k: int) -> void:
	claws[k]["fly"] = true


## 집게가 눈알에 꽂힌다: 방어막이 있으면 방어막을 크게 깎고, 없으면 코어가 터진다 (main 이 CLAW_HIT 의 kill 을 보고 승리 처리)
func _claw_impact(at: Vector2, dir: Vector2) -> void:
	if dead:
		return
	if phase == 1:
		shield_flash = 1.0
		shield_hit_n = -dir
		pierce = 1.0
		pierce_k = shield_pass()
		pierce_n = -dir
		for k in 6:
			_spawn_shard(at, randf_range(14.0, 24.0), (-dir).rotated(randf_range(-0.8, 0.8)) * randf_range(400.0, 700.0) + Vector2(0, -200))
		emit(Ev.CLAW_HIT, at, {"kill": false})
		_wear_shield(CLAW_SHIELD)
		return
	emit(Ev.CLAW_HIT, at, {"kill": true})


## 탄을 쏠 수 있는 발사점 [[번호, 위치], ...]: 분사구(-1) · 놀고 있는 촉수 끝(0~5) · 배경 다리 끝(6·7)
func emitters() -> Array:
	var out := [[-1, SIPHON]]
	for i in 6:
		if tent_ready(i) and grown[i] >= 1.0 and not spines[i].is_empty():
			out.append([i, spines[i][N - 1]])
	for k in 2:
		out.append([6 + k, bg_spines[k][N - 1]])
	return out


## 발사점 위치 (지금 쓸 수 없으면 Vector2.INF)
func emitter_pos(id: int) -> Vector2:
	if id < 0:
		return SIPHON
	if id >= 6:
		return bg_spines[id - 6][N - 1]
	if tent_ready(id) and grown[id] >= 1.0 and not spines[id].is_empty():
		return spines[id][N - 1]
	return Vector2.INF


func emit_glow_set(id: int, v: float) -> void:
	if id == -4:
		eye_charge = v
	elif id < 0:
		siphon_glow = v
	else:
		emit_glow[id] = v


func die() -> void:
	super()
	bg_hold = []


func _choose(ppos: Vector2) -> void:
	var hard := phase == 3
	var ready: Array[int] = []
	for i in 6:
		if tent_ready(i):
			ready.append(i)
	if want != "":                                           # 근접 패턴이 탄이 걷히길 기다리는 중
		want_t += 0.2
		if not _shots_clear(ppos) and want_t < CLEAR_WAIT:
			next_t = 0.2
			return
		var w := want
		want = ""
		if w == "net" or _melee_ok(w, ready):
			_start(w, ready, ppos, hard)
			return
	if shots_near(ppos, CROWD_R) > CROWD_CAP:                 # 앞 탄막이 아직 화면에 많으면 걷힐 때까지 다음 탄막을 미룬다 (쉴 공간)
		next_t = 0.2
		return
	since_special += 1
	var kind := ""
	if since_special >= SPECIAL_EVERY and randf() < 0.55 and rot_k % ROTATION != ROTATION - 1:    # 드물게: 방전 그물 (패리 불가, 탄막 차례 하나를 대신)
		since_special = 0
		rot_k += 1
		kind = "net"
	else:
		var fire: Array[String] = ["ink", "tips", "ring"]     # 탄막마다 저격 유도탄이 함께 날아온다 (_start)
		if hard:
			fire.append("eye")                               # 코어 단계: 눈알 동심원 (패리 불가, 탄막 자리를 다 차지하지 않게 가끔)
		var melee: Array[String] = []
		for m in ["pound", "pound", "chase", "sweep", "constrict", "constrict"]:   # 시그니처: 연속 내려치기 · 조이기
			if _melee_ok(m, ready):
				melee.append(m)
		var pool: Array[String] = fire
		var melee_turn := rot_k % ROTATION == ROTATION - 1
		if melee_turn and not melee.is_empty():
			pool = melee
		if not (melee_turn and melee.is_empty()):           # 근접 차례인데 쓸 촉수가 없으면 다음에도 근접 차례
			rot_k += 1
		var w := {}                                          # 같은 패턴이 여러 번 들어 있으면 그만큼 자주 + 구역 가중치
		for k in pool:
			w[k] = float(w.get(k, 0.0)) + _zone_w(k, ppos)
		kind = weighted_pick(w, last)
	if not RANGED_KINDS.has(kind) and kind != "eye" and not _shots_clear(ppos):   # 근접·그물: 날아오는 탄이 걷힐 때까지 기다린다 (요격하려면 멈춰야 하므로)
		want = kind
		want_t = 0.0
		next_t = 0.2
		return
	_start(kind, ready, ppos, hard)


## 이 근접 패턴을 지금 쓸 수 있는가
func _melee_ok(m: String, ready: Array[int]) -> bool:
	match m:
		"sweep":
			return ready.has(SWEEPERS[0]) or ready.has(SWEEPERS[1])
		"pound", "chase":
			return not ready.is_empty()
		"constrict":
			return ready.size() >= 2 and (phase == 3 or core.frac() > 0.15)
	return ready.size() >= 2


## 플레이어 가까이(CLEAR_R) 날아오는 적 탄이 없고, 유도탄도 더 쏠 게 없는가
func _shots_clear(ppos: Vector2) -> bool:
	return shots_clear(ppos) and not is_lingering("snipe")


## 구역 가중치: 플레이어가 그 패턴이 덮는 곳에 있으면 자주, 아니면 드물게 (y 아래 = +)
func _zone_w(kind: String, p: Vector2) -> float:
	var below_body := p.y > SIPHON.y - 100.0
	var low := p.y > ROOTS[4].y + 150.0                      # 늘어진 촉수 뿌리보다 아래 = 하단
	match kind:
		"ink":
			return 1.0 if below_body else 0.15
		"tips":
			return 1.0 if absf(p.x) < 750.0 and p.y > -1900.0 else 0.4
		"sweep":
			return 1.4 if low else 0.05
		"ring":
			return 0.8
		"eye":
			return 0.5
	return 1.0


func _start(kind: String, ready: Array[int], ppos: Vector2, hard: bool) -> void:
	match kind:
		"net":
			_pick("net", Net.new(randf() < 0.5))
		"pound":
			_pick("pound", _pound(ready, ppos))
		"chase":
			_grab_start("chase", Chase.new(_nearest(ready, ppos.x)))
		"sweep":                                             # 아래 두 촉수가 함께 바깥에서 안으로 하단을 쓴다 (고정)
			var sw: Array[int] = []
			for i in SWEEPERS:
				if ready.has(i):
					sw.append(i)
			if sw.size() == 2:
				_pick("sweep", Combo.new("sweep", [func(): return Lash.new(sw[0], true), func(): return Lash.new(sw[1], true)], 0.0, true))
			else:
				_grab_start("sweep", Lash.new(sw[0], true))
		"eye":                                               # 눈알이 보라 고리를 모았다가 동심원 셋을 내보낸다
			var r = Rings.new(CORE_POS)
			r.count = 3
			r.wind = 1.5
			_pick("eye", r)
		"constrict":
			var lr := _outer_pair(ready)
			_grab_start("constrict", Constrict.new(lr[0], lr[1]))
		_:                                                   # 고정 탄막 + 그 사이로 저격 유도탄 (탄막을 피하는 동안 압박)
			_pick(kind, _fire(kind, ppos, hard))
			if not is_lingering("snipe"):
				start_side(Barrage.new("snipe", emitters(), ppos, hard))


## 탄막 모듈
func _fire(kind: String, ppos: Vector2, hard: bool):
	match kind:
		"ink":                                               # 고정 방향(플레이어 쪽 선택지)으로 부채, 부채마다 반 칸 어긋난다
			var f = Fan.new(-1, SIPHON, SIPHON + Vector2(0, 1000), hard)
			f.fixed = true
			f.aim = nearest_dir(SIPHON, ppos, DIRS_DOWN)
			return f
	return Barrage.new(kind, emitters(), ppos, hard)


## 연속 내려치기 (관측자 때의 행진·소용돌이·단발 내려치기를 하나로): 서로 다른 촉수가 처음부터 함께 올라와 차례로 내려친다.
## 첫 타는 플레이어를 따라가 겨누고, 다음 타들은 그 첫 타 자리 위에 겹겹이 들려 있다가 같은 자리에 차례로 떨어진다. 다음에 칠 타만 예고가 보인다.
## 촉수가 하나뿐이면 단발 (플레이어를 따라감)
func _pound(ready: Array[int], ppos: Vector2) -> Combo:
	var ls: Array[int] = []
	var rs: Array[int] = []
	for i in ready:
		(ls if ROOTS[i].x < 0.0 else rs).append(i)
	var order: Array[int] = []
	var side := 0 if ppos.x >= 0.0 else 1                    # 플레이어 반대쪽 촉수부터
	while order.size() < COMBO_HITS and not (ls.is_empty() and rs.is_empty()):
		var src := ls if side == 0 else rs
		if src.is_empty():
			src = rs if side == 0 else ls
		order.append(src.pop_front())
		side = 1 - side
	var makers := []
	var first := []
	for k in order.size():
		var i: int = order[k]
		if k == 0:
			makers.append(func():
				var h = Hammer.new(i, true)
				first.append(h)
				return h)
		else:
			makers.append(func():
				var h = Hammer.new(i, true)
				h.follow = first[0] if not first.is_empty() else null
				h.stack = k
				return h)
	return Combo.new("pound", makers, 0.1)


func _pick(kind: String, a) -> void:
	last = kind
	start_attack(a)


func _grab_start(kind: String, a) -> void:
	_pick(kind, a)
	a.claim()


## 가장 왼쪽 촉수(왼쪽 몫)와 가장 오른쪽 촉수(오른쪽 몫)
static func _outer_pair(ts: Array[int]) -> Array[int]:
	var l := ts[0]
	var r := ts[ts.size() - 1]
	for i in ts:
		if ROOTS[i].x < ROOTS[l].x:
			l = i
		if ROOTS[i].x > ROOTS[r].x:
			r = i
	return [l, r]


## 플레이어 x 에 가장 가까운 촉수 (쉬는 자세의 끝 기준)
static func _nearest(ts: Array[int], x: float) -> int:
	var best := ts[0]
	for i in ts:
		if absf(IDLE_TIPS[i].x - x) < absf(IDLE_TIPS[best].x - x):
			best = i
	return best


## 휩쓸 촉수: 플레이어 쪽에 달린 것 중 닿는 것, 없으면 가장 가까운 것
## 휩쓸 촉수: 아래 두 촉수(SWEEPERS) 중 플레이어 쪽에 달린 것, 쓸 수 없으면 다른 하나
func _sweeper(ts: Array[int], ppos: Vector2) -> int:
	var near: int = SWEEPERS[1] if ppos.x >= 0.0 else SWEEPERS[0]
	var far: int = SWEEPERS[0] if near == SWEEPERS[1] else SWEEPERS[1]
	return near if ts.has(near) else far


## 먹물 포 발광 (Fan 이 부른다. 발사점은 분사구 하나뿐)
func set_glow(c: int, v: float) -> void:
	emit_glow_set(c, v)


func glow_of(c: int) -> float:
	return siphon_glow if c < 0 else emit_glow[c]


## 떨어져 나간 촉수 토막: 빠르게 돌며 날아가다 벽에 튕기고, 융해 지대에 빠지면 물보라와 함께 사라진다
func _step_debris(dt: float) -> void:
	for d in debris.duplicate():
		var v: Vector2 = d["vel"]
		v.y += 1500.0 * dt
		var p: Vector2 = d["pos"] + v * dt
		if absf(p.x) > 1150.0:
			p.x = signf(p.x) * 1150.0
			v.x = -v.x * 0.45
		d["vel"] = v
		d["pos"] = p
		d["rot"] = float(d["rot"]) + float(d["rotv"]) * dt
		if p.y > -20.0 and not d["splash"]:
			d["splash"] = true
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))
		if p.y > 400.0:
			debris.erase(d)


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	for k in 2:
		_draw_mech(bg_spines[k], 0.85, C_BODY_DARK, false)
	_draw_mantle()
	_draw_core()
	for i in 6:
		_draw_arm(i)
	_draw_emit_glow()
	_draw_shield()
	_draw_gauge()
	_draw_claws()
	_draw_zaps()
	_draw_debris()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


## 탄을 쏘기 전 촉수 끝·배경 다리 끝이 달아오른다
func _draw_emit_glow() -> void:
	for id in 8:
		var g := emit_glow[id]
		if g <= 0.02:
			continue
		var p := emitter_pos(id) if id < 6 else bg_spines[id - 6][N - 1]
		if p == Vector2.INF:
			continue
		draw_circle(p, 20.0 + 26.0 * g, Color(C_GLOW, 0.2 + 0.45 * g))
		draw_circle(p, 9.0 + 6.0 * g, Color(1.0, 0.95, 0.8, 0.5 + 0.5 * g))


func _draw_arm(i: int) -> void:
	var root: Vector2 = ROOTS[i]
	if grown[i] <= 0.02:                                  # 떨어져 나간 자리: 뜯긴 소켓 + 끊긴 케이블 + 튀는 불꽃
		draw_circle(root, 44.0, C_BODY_DARK)
		draw_arc(root, 44.0, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
		for c in 3:
			var a := PI * 0.5 + (c - 1) * 0.5
			draw_line(root, root + Vector2.from_angle(a + 0.2 * sin(t * 3.0 + c)) * 70.0, Color(0.1, 0.1, 0.1), 5.0)
		draw_circle(root, 16.0, Color(C_HEART, 0.3 + 0.25 * float(int(t * 11.0 + i) % 3 == 0)))
		return
	var m = busy[i]
	var striking: bool = m != null and m.delay <= 0.0 and m._harmful()
	var lit: bool = m != null and focus_glow > 0.0 and m.delay <= 0.0 and m._clashable()
	var revived := phase >= 2 and not dead
	if phase == 1 and part_stage[i] >= 2:                 # 한 번 요격당한 촉수: 뿌리 관절에서 불꽃이 튄다 (다음 요격이면 끊어진다)
		if int(t * 8.0 + i) % 3 == 0:
			draw_circle(spines[i][PART_AT] + Vector2(sin(t * 23.0 + i) * 18.0, cos(t * 19.0) * 18.0), 3.0, Color(1.0, 0.85, 0.5))
	_draw_mech(spines[i], 1.0, C_STEEL, revived)
	if striking or lit:                                  # 판정이 있는 공격 중 = 금색(패리할 수 있음) / 차지·조준 중 요격할 수 있으면 밝게
		var c := Color(C_PARRY, 0.75) if striking else Color(1.0, 0.92, 0.6, 0.45 + 0.35 * sin(t * 12.0))
		for k in range(m.hit_from, N - 1):
			draw_line(spines[i][k], spines[i][k + 1], c, 5.0)
	if grown[i] < 1.0:                                   # 자라는 중: 뿌리에서 불꽃
		for c in 4:
			draw_circle(root + Vector2.from_angle(t * 9.0 + c * 1.6) * 30.0, 4.0, Color(1.0, 0.8, 0.45, 0.9))


## 기계 촉수: 강철 마디판(사다리꼴) + 등줄기 + 유압 피스톤 + 관절 링·볼트 + 끝의 집게.
## revived = 코어 페이즈에 다시 자라난 촉수 → 관절이 붉게 달아오른다
func _draw_mech(sp: PackedVector2Array, ws: float, col: Color, revived: bool) -> void:
	var rim := Color(C_RIM, 0.5)
	for k in N - 1:
		var a := sp[k]
		var b := sp[k + 1]
		if a.distance_to(b) < 1.0:
			continue
		var d := (b - a).normalized()
		var o := d.orthogonal()
		var wa := width_at(k) * ws * 0.5
		var wb := width_at(k + 1) * ws * 0.5 * 0.9
		var plate := PackedVector2Array([a + o * wa, b + o * wb, b - o * wb, a - o * wa])
		draw_colored_polygon(plate, col)
		draw_line(a + o * wa, b + o * wb, rim, 2.5)
		draw_line(a - o * wa, b - o * wb, Color(C_RIM, 0.25), 2.0)
		draw_line(a.lerp(b, 0.15) - o * wa * 0.15, a.lerp(b, 0.85) - o * wb * 0.15, Color(C_BODY_DARK, 0.9), 5.0)   # 등줄기 홈
		var pa := a + o * wa * 0.62                       # 유압 피스톤: 실린더 + 반짝이는 막대
		var pm := a.lerp(b, 0.55) + o * (wa + wb) * 0.31
		var pb := b + o * wb * 0.62
		draw_line(pa, pm, Color(C_BODY_DARK, 1.0), 7.0)
		draw_line(pm, pb, Color(C_PISTON, 0.55), 2.5)
	for k in range(1, N):                                 # 관절 링 + 볼트
		var r := width_at(k) * ws * 0.36
		draw_circle(sp[k], r, C_BODY_DARK)
		draw_arc(sp[k], r, 0.0, TAU, 14, Color(C_RIM, 0.55), 2.5)
		var bc := Color(C_HEART, 0.55 + 0.3 * sin(t * 6.0 + k)) if revived else Color(C_RIM, 0.7)
		draw_circle(sp[k], r * 0.3, bc)
	draw_circle(sp[0], width_at(0) * ws * 0.55, C_BODY_DARK)
	draw_arc(sp[0], width_at(0) * ws * 0.55, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
	var tip := sp[N - 1]                                  # 집게: 바깥으로 벌어진 두 갈래
	var td := (tip - sp[N - 2]).normalized() if tip.distance_to(sp[N - 2]) > 1.0 else Vector2.DOWN
	var to := td.orthogonal()
	var wt := width_at(N - 1) * ws * 0.5
	for s in [-1.0, 1.0]:
		var base: Vector2 = tip + to * wt * 0.5 * s
		var prong := PackedVector2Array([base - to * 9.0 * s, base + to * 9.0 * s, tip + td * 62.0 * ws + to * (wt + 10.0) * s])
		draw_colored_polygon(prong, col)
		draw_polyline(PackedVector2Array([prong[1], prong[2], prong[0]]), rim, 2.0)


## 머리 (기계 문어): 천장에서 내려온 줄기에 매달린 둥근 강철 돔. 위가 둥글고 아래로 좁아져 촉수가 모이는 목깃에서 끝난다 (지느러미 없음).
## 장갑판 이음매(위도·경도선) + 리벳 + 줄지어 깜빡이는 표시등 + 양옆 유압 배관 + 정수리 배기구의 증기. 좌표는 DROP 전 기준
func _draw_mantle() -> void:
	draw_set_transform(Vector2(0, DROP))
	draw_colored_polygon(PackedVector2Array([Vector2(-150, -3150), Vector2(150, -3150), Vector2(190, -3700), Vector2(-190, -3700)]), C_BODY_DARK)   # 천장에서 늘어진 줄기
	for s2 in [-1.0, 1.0]:
		draw_line(Vector2(s2 * 150, -3150), Vector2(s2 * 190, -3700), Color(C_RIM, 0.4), 3.0)
	var cy := -2720.0                                    # 돔 중심
	var rx := 540.0
	var ry := 470.0
	var dome := PackedVector2Array()
	for k in 25:
		var a := PI + k * PI / 24.0
		dome.append(Vector2(cos(a) * rx, cy + sin(a) * ry))
	dome.append_array(PackedVector2Array([Vector2(560, -2560), Vector2(530, -2380), Vector2(450, -2245), Vector2(300, -2160), Vector2(0, -2130),
		Vector2(-300, -2160), Vector2(-450, -2245), Vector2(-530, -2380), Vector2(-560, -2560)]))
	for s2 in [-1.0, 1.0]:                                # 양옆 유압 배관 (돔 뒤)
		var pipe := PackedVector2Array([Vector2(s2 * 300, -3120), Vector2(s2 * 560, -3010), Vector2(s2 * 650, -2700), Vector2(s2 * 610, -2380), Vector2(s2 * 480, -2200)])
		draw_polyline(pipe, C_BODY_DARK, 34.0)
		draw_polyline(pipe, Color(C_RIM, 0.35), 3.0)
		for q in range(1, pipe.size() - 1):
			draw_circle(pipe[q], 24.0, C_BODY_DARK)
			draw_arc(pipe[q], 24.0, 0.0, TAU, 12, Color(C_RIM, 0.5), 3.0)
	draw_colored_polygon(dome, C_BODY)
	var ol := dome.duplicate()
	ol.append(dome[0])
	draw_polyline(ol, Color(C_RIM, 0.55), 4.0)
	for y in [-3060.0, -2900.0]:                          # 위도 이음매 (둥글게 휜다) + 리벳
		var w := rx * sqrt(maxf(0.0, 1.0 - pow((y - cy) / ry, 2.0)))
		var seam := PackedVector2Array()
		for q in 17:
			var x := lerpf(-w, w, q / 16.0)
			seam.append(Vector2(x, y + 30.0 * (1.0 - pow(x / w, 2.0))))
		draw_polyline(seam, C_BODY_DARK, 6.0)
		draw_polyline(seam, Color(C_RIM, 0.25), 2.0)
		for q in range(1, 16, 2):
			draw_circle(seam[q] + Vector2(0, 12), 4.0, Color(C_RIM, 0.55))
	for mx in [-0.62, -0.3, 0.3, 0.62]:                   # 경도 이음매 (정수리 → 목깃)
		var mer := PackedVector2Array()
		for q in 11:
			var y := lerpf(cy - ry * 0.92, -2300.0, q / 10.0)
			var w := rx * sqrt(maxf(0.0, 1.0 - pow(clampf((y - cy) / ry, -1.0, 1.0), 2.0))) if y < cy else lerpf(rx, 470.0, (y - cy) / (-2300.0 - cy))
			mer.append(Vector2(mx * w, y))
		draw_polyline(mer, C_BODY_DARK, 5.0)
	for q in 7:                                           # 정수리 표시등: 한쪽에서 차례로 깜빡인다
		var a := PI * 1.25 + q * PI * 0.5 / 6.0
		var p := Vector2(cos(a) * rx * 0.78, cy + sin(a) * ry * 0.78)
		var on := 0.5 + 0.5 * sin(t * 3.0 - q * 0.9)
		draw_circle(p, 9.0, C_BODY_DARK)
		draw_circle(p, 5.0, Color(C_GLOW, 0.25 + 0.65 * on))
	for s2 in [-1.0, 1.0]:                                # 정수리 배기구 + 증기
		var v := Vector2(s2 * 200, -3150)
		draw_rect(Rect2(v.x - 34, v.y - 10, 68, 26), C_BODY_DARK)
		for k in 4:
			var life := fmod(t * 0.5 + k * 0.25 + (0.5 if s2 > 0.0 else 0.0), 1.0)
			draw_circle(v + Vector2(s2 * life * 60.0 + sin(t * 2.0 + k) * 10.0, -life * 220.0), 16.0 + life * 36.0, Color(0.55, 0.58, 0.62, 0.2 * (1.0 - life)))
	var collar := PackedVector2Array([Vector2(-450, -2245), Vector2(-300, -2160), Vector2(0, -2130), Vector2(300, -2160), Vector2(450, -2245)])   # 목깃: 촉수가 모이는 띠 + 볼트
	draw_polyline(collar, C_BODY_DARK, 40.0)
	draw_polyline(collar, Color(C_RIM, 0.45), 3.0)
	for q in 9:
		var p := collar[0].lerp(collar[4], q / 8.0)
		p.y = -2130.0 - 115.0 * pow(absf(p.x) / 450.0, 2.0)
		draw_circle(p, 6.0, Color(C_RIM, 0.6))
	draw_set_transform(Vector2.ZERO)
	# 분사구 (먹물 포)
	draw_circle(SIPHON, 46.0, C_BODY_DARK)
	draw_arc(SIPHON, 46.0, 0.0, PI, 18, C_RIM, 4.0)
	draw_circle(SIPHON + Vector2(0, 14), 18.0 + 14.0 * siphon_glow, Color(C_GLOW, 0.2 + 0.6 * siphon_glow))


## 외눈 = 동력 코어: 눈구멍 + 붉은 홍채 + 가로로 찢어진 동공(빛나는 코어). 체력바 대신 쌓인 피해가 그대로 보인다:
## 균열이 늘어나 빛이 새고(피해 비율만큼 cracks 를 앞에서부터), 동공이 흐려지며 깜빡이고, 연기가 오른다
func _draw_core() -> void:
	var hc := CORE_POS
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (4.2 + f * 5.0))
	var shell: PackedVector2Array = core.shell_poly
	if dead:
		draw_colored_polygon(shell, Color(0.1, 0.05, 0.05))
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	var socket := PackedVector2Array()                       # 눈구멍 (외투막 판의 테두리)
	for q in shell:
		socket.append(hc + (q - hc) * 1.14)
	draw_colored_polygon(socket, C_BODY_DARK)
	var so := socket.duplicate()
	so.append(socket[0])
	draw_polyline(so, Color(C_RIM, 0.6), 5.0)
	var flick := 1.0
	if f > 0.55:                                             # 많이 상함: 동공 빛이 깜빡인다
		flick = 0.55 + 0.45 * float(int(t * (8.0 + f * 10.0)) % 4 != 0)
	if core.broken:
		flick = 0.55 + 0.45 * float(int(t * 14.0) % 3 != 0)
	_draw_iris(hc, f, beat, flick)
	var n := int(ceil(f * cracks.size()))                     # 균열: 쌓인 피해만큼
	for k in n:
		var cr: PackedVector2Array = cracks[k]
		var pts := PackedVector2Array()
		for q in cr:
			pts.append(hc + q)
		draw_polyline(pts, Color(0.05, 0.02, 0.02), 7.0)
		draw_polyline(pts, Color(1.0, 0.55, 0.22, 0.55 + 0.4 * beat), 3.0)
	_draw_lids(hc)
	var smoke := int(f * 6.0)
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -110.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if f > 0.3 and fmod(t * 2.0, 1.0) < 0.3:                   # 균열에서 튀는 불꽃
		for k in 3:
			var cr: PackedVector2Array = cracks[(int(t * 2.0) + k * 3) % maxi(1, n)]
			draw_circle(hc + cr[cr.size() - 1] + Vector2(sin(t * 31.0 + k) * 10.0, -fmod(t * 300.0, 40.0)), 3.0, Color(1.0, 0.85, 0.5))
	if core.broken:
		draw_arc(hc, CORE_R + 22.0 + 6.0 * beat, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.55 + 0.4 * beat), 3.0)
	if eye_charge > 0.0:                                     # 동심원을 모은다: 보라 빛이 눈알로 빨려 든다
		var uc := Color(0.6, 0.08, 0.36)
		draw_circle(hc, EYE_RX * (0.6 + 0.5 * eye_charge), Color(uc, 0.25 * eye_charge))
		draw_arc(hc, EYE_RX * 1.6 * (1.0 - eye_charge) + EYE_RX * 0.7, 0.0, TAU, 48, Color(1.0, 0.62, 0.86, 0.7 * eye_charge), 5.0)
	if focus_glow > 0.0 and phase == 3:
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, EYE_RX + 40.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.55, focus_glow * (0.6 if in_reach else 0.25)), 3.0)


## 타원 위의 점 (rx, ry 반지름, 각도 a)
static func _ell(c: Vector2, rx: float, ry: float, a: float) -> Vector2:
	return c + Vector2(cos(a) * rx, sin(a) * ry)


## 뱀눈 (그림만, 판정은 core.shell_poly 그대로): 핏빛 테두리 → 호박빛 안쪽의 홍채, 그 위를 덮은 기계 조리개 날,
## 렌즈 고리와 눈금, 세로로 찢어진 동공이 플레이어를 따라간다 (동심원을 모을 때·맞을 때 벌어진다). 동공 깊은 곳에 코어 불씨
func _draw_iris(hc: Vector2, f: float, beat: float, flick: float) -> void:
	var rx := EYE_RX
	var ry := EYE_RY
	var hot := Color(1.0, 0.72, 0.16).lerp(Color(0.85, 0.35, 0.1), f)
	for k in 6:                                                   # 홍채: 바깥 핏빛 → 안쪽 호박빛
		var s := 1.0 - k * 0.15
		var ring := PackedVector2Array()
		for q in 24:
			ring.append(_ell(hc, rx * s, ry * s, q * TAU / 24.0))
		draw_colored_polygon(ring, Color(0.32, 0.03, 0.02).lerp(hot, k / 5.0).lerp(Color.WHITE, core.flash * 0.3))
	var look := _ppos - hc                                        # 동공이 플레이어를 따라간다
	var pc := hc + Vector2(clampf(look.x * 0.03, -46.0, 46.0), clampf(look.y * 0.02, -18.0, 18.0))
	for k in 18:                                                  # 기계 조리개 날 (천천히 돈다)
		var a := k * TAU / 18.0 + t * 0.08
		draw_line(pc + Vector2.from_angle(a) * 26.0, _ell(hc, rx * 0.95, ry * 0.95, a + 0.32), Color(0.28, 0.04, 0.02, 0.6), 3.0)
	var lens := PackedVector2Array()                              # 렌즈 고리 + 눈금 (초점을 맞추듯 돈다)
	for q in 41:
		lens.append(_ell(pc, rx * 0.5, ry * 0.62, q * TAU / 40.0))
	draw_polyline(lens, Color(1.0, 0.85, 0.5, 0.35 * flick), 2.0)
	for k in 4:
		var a := k * TAU / 4.0 - t * 0.6
		draw_line(_ell(pc, rx * 0.5, ry * 0.62, a), _ell(pc, rx * 0.6, ry * 0.74, a), Color(1.0, 0.9, 0.6, 0.6 * flick), 3.0)
	var w: float = 10.0 + 22.0 * eye_charge + 8.0 * core.flash          # 세로 슬릿 동공 (벌어진다)
	var h := ry * 0.95
	var slit := PackedVector2Array()
	for q in 13:
		var y := lerpf(-h, h, q / 12.0)
		slit.append(pc + Vector2(w * (1.0 - pow(y / h, 2.0)), y))
	for q in range(11, 0, -1):
		var y := lerpf(-h, h, q / 12.0)
		slit.append(pc + Vector2(-w * (1.0 - pow(y / h, 2.0)), y))
	draw_colored_polygon(slit, Color(0.02, 0.0, 0.0))
	var so := slit.duplicate()
	so.append(slit[0])
	draw_polyline(so, Color(1.0, 0.45, 0.1, (0.55 + 0.3 * beat) * flick), 2.5)
	draw_circle(pc, 5.0 + 3.0 * beat, Color(C_HEART, flick).lerp(Color.WHITE, core.flash * 0.7))   # 동공 깊은 곳의 코어 불씨
	draw_circle(hc + Vector2(-rx * 0.42, -ry * 0.2), 9.0, Color(1.0, 0.95, 0.85, 0.75 * flick))      # 번들거림


## 강철 눈꺼풀: 위는 무겁게 내리깔고(사나운 눈매) 아래는 살짝 올라와 눈을 아몬드 모양으로 가른다.
## 판 이음매·리벳 + 눈꺼풀 끝에 달아오른 테두리. 동심원을 모을 때는 크게 뜬다
func _draw_lids(hc: Vector2) -> void:
	var rx := EYE_RX * 1.16
	var ry := EYE_RY * 1.16
	var up_open := 0.5 + 0.42 * eye_charge                        # 가운데에서 위로 열린 정도 (ry 비율)
	var lo_open := 0.62 + 0.3 * eye_charge
	for side in [-1.0, 1.0]:                                      # -1 = 위, 1 = 아래
		var open: float = up_open if side < 0.0 else lo_open
		var edge := PackedVector2Array()
		for q in 17:
			var x := lerpf(-rx, rx, q / 16.0)
			var u := x / rx
			var sag := 0.22 * (1.0 - absf(u)) if side < 0.0 else 0.0  # 위 눈꺼풀은 가운데가 살짝 처져 노려본다
			edge.append(hc + Vector2(x, side * ry * (open * (1.0 - u * u) - sag)))
		var lid := edge.duplicate()
		for q in 17:                                              # 눈구멍 테두리를 따라 되돌아간다
			lid.append(_ell(hc, rx, ry, side * q * PI / 16.0))
		draw_colored_polygon(lid, C_BODY)
		for k in [-0.5, 0.0, 0.5]:                                # 판 이음매
			var e: Vector2 = edge[int(round((k + 1.0) * 8.0))]
			draw_line(e, Vector2(e.x, hc.y + side * ry * 0.98), C_BODY_DARK, 4.0)
			draw_circle(e + Vector2(0, side * 16.0), 4.0, Color(C_RIM, 0.7))
		draw_polyline(edge, C_BODY_DARK, 9.0)
		draw_polyline(edge, Color(1.0, 0.4, 0.12, 0.65), 3.0)       # 눈꺼풀 끝의 달아오른 테두리
		var shine := PackedVector2Array()
		for e in edge:
			shine.append(e + Vector2(0, side * 9.0))
		draw_polyline(shine, Color(C_RIM, 0.45), 2.0)


## 방어막: 페이즈 1 = 육각 무늬가 흐르는 청록 막 (부딪힌 쪽이 번쩍), 페이즈 2 = 금이 가며 사라진다 (파편은 damage_part 가 뿌린다)
func _draw_shield() -> void:
	if dead or phase == 3:
		return
	var k := 1.0 if phase == 1 else 1.0 - clampf(open_t / SHIELD_SHATTER * 3.0, 0.0, 1.0)
	if k <= 0.0:
		return
	var c := Color(0.45, 0.95, 1.0)
	var hc := CORE_POS
	var sf := shield_frac() if phase == 1 else 0.0           # 닳을수록 옅고 얇아지고 금이 는다 = 뚫고 들어가기 쉽다
	draw_circle(hc, SHIELD_R, Color(c, (0.04 + 0.16 * sf + 0.12 * shield_flash) * k))
	draw_arc(hc, SHIELD_R, 0.0, TAU, 64, Color(c, (0.3 + 0.35 * sf + 0.4 * shield_flash) * k), 2.0 + 6.0 * sf)
	draw_arc(hc, SHIELD_R - 10.0, 0.0, TAU, 64, Color(c, 0.18 * sf * k), 2.0)
	var nc := int(round((1.0 - sf) * shield_cracks.size()))
	for j in nc:
		var pts := PackedVector2Array()
		for q in shield_cracks[j]:
			pts.append(hc + q)
		draw_polyline(pts, Color(1, 1, 1, (0.5 + 0.3 * shield_flash) * k), 2.5)
	if pierce > 0.0 and phase == 1:                           # 방금 뚫은 일격: 방어막이 약할수록 창이 코어 깊이까지 들어간다
		var from := hc + pierce_n * (SHIELD_R + 30.0)
		var depth := lerpf(0.25, 1.0, (pierce_k - SHIELD_PASS_MIN) / (1.0 - SHIELD_PASS_MIN))
		var to := from.lerp(hc, depth)
		draw_line(from, to, Color(1.0, 0.85, 0.5, 0.5 * pierce), 10.0 + 22.0 * pierce_k)
		draw_line(from, to, Color(1, 1, 1, pierce), 3.0 + 6.0 * pierce_k)
		draw_circle(to, (18.0 + 60.0 * pierce_k) * pierce, Color(1.0, 0.8, 0.45, 0.6 * pierce))
	for j in 6:                                               # 막 위를 흐르는 호
		var a0 := t * 0.4 + j * TAU / 6.0
		draw_arc(hc, SHIELD_R - 4.0, a0, a0 + 0.35, 8, Color(1, 1, 1, 0.35 * k), 3.0)
	if shield_flash > 0.0:                                    # 부딪힌 쪽 물결
		var a := shield_hit_n.angle()
		draw_arc(hc, SHIELD_R + 8.0, a - 0.6, a + 0.6, 16, Color(1, 1, 1, 0.8 * shield_flash * k), 6.0)
		draw_arc(hc, SHIELD_R + 22.0 * (1.0 - shield_flash), a - 0.4, a + 0.4, 12, Color(c, 0.6 * shield_flash * k), 3.0)
	if phase == 2:                                            # 깨지는 중: 금
		for j in 8:
			var a := j * TAU / 8.0 + 0.2
			var p0 := hc + Vector2.from_angle(a) * SHIELD_R
			draw_polyline(PackedVector2Array([p0, p0 + Vector2.from_angle(a + 2.6) * 60.0, p0 + Vector2.from_angle(a + 2.2) * 110.0]), Color(1, 1, 1, 0.8 * k), 3.0)


## 체력 게이지 (colossus_base.gd): 안쪽 = 코어 체력(빨강), 페이즈 1 에는 바깥에 방어막 내구도(청록)를 한 겹 더 두른다
func gauge_values() -> Vector3:
	return Vector3(core.armor_hp, ARMOR_HP, ARMOR_HP)


func _draw_gauge() -> void:
	if dead or gauge_vis <= 0.0:
		return
	var vis := minf(1.0, gauge_vis / GAUGE_FADE)
	var hc := CORE_POS
	var top := -PI * 0.5
	var w := GAUGE_W * (1.0 + 0.5 * gauge_hit)
	var hp := float(core.armor_hp)
	draw_arc(hc, GAUGE_R, 0.0, TAU, 96, Color(0.03, 0.04, 0.05, 0.75 * vis), w + 6.0)
	if gauge_lag > hp:
		draw_arc(hc, GAUGE_R, top + TAU * hp / ARMOR_HP, top + TAU * gauge_lag / ARMOR_HP, 48, Color(1, 1, 1, 0.85 * vis), w)
	if hp > 0.0:
		var red := Color(C_HEART, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
		red.a *= vis
		draw_arc(hc, GAUGE_R, top, top + TAU * hp / ARMOR_HP, 64, red, w)
	else:
		draw_arc(hc, GAUGE_R, 0.0, TAU, 64, Color(1.0, 0.95, 0.7, (0.3 + 0.4 * float(int(t * 8.0) % 2)) * vis), 3.0)
	if phase == 1 and shield_hp > 0.0:
		var R := GAUGE_R + w + 8.0
		draw_arc(hc, R, 0.0, TAU, 96, Color(0.03, 0.04, 0.05, 0.6 * vis), w * 0.6 + 4.0)
		var cyan := Color(0.45, 0.95, 1.0, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
		cyan.a *= vis
		draw_arc(hc, R, top, top + TAU * shield_frac(), 64, cyan, w * 0.6)


## 잘린 집게: 두 갈래 집게 + 끊긴 단면의 불씨 + 눈에 띄는 금빛 테두리 (쳐 보고 싶게). 날아가는 중엔 금빛 꼬리
func _draw_claws() -> void:
	for c in claws:
		var p: Vector2 = c["pos"]
		var rot: float = c["rot"]
		var pulse := 0.5 + 0.5 * sin(t * 8.0)
		if c["fly"]:
			var back := Vector2.from_angle(rot) * -1.0
			draw_line(p, p + back * 260.0, Color(1.0, 0.8, 0.4, 0.35), 26.0)
			draw_line(p, p + back * 180.0, Color(1, 1, 1, 0.8), 6.0)
		else:
			draw_circle(p, CLAW_R + 40.0 + 14.0 * pulse, Color(C_PARRY, 0.08 + 0.06 * pulse))
			draw_circle(p, CLAW_R + 10.0, Color(C_PARRY, 0.12 + 0.08 * pulse))
			draw_arc(p, CLAW_R + 10.0, 0.0, TAU, 32, Color(C_PARRY, 0.6 + 0.4 * pulse), 5.0)
		draw_set_transform(p, rot, Vector2(1.6, 1.6))
		var wt := W_TIP * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(-50, -wt), Vector2(10, -wt * 0.9), Vector2(10, wt * 0.9), Vector2(-50, wt)]), C_STEEL)
		for s in [-1.0, 1.0]:
			var prong := PackedVector2Array([Vector2(4, wt * 0.5 * s - 9.0 * s), Vector2(4, wt * 0.5 * s + 9.0 * s), Vector2(70, (wt + 12.0) * s)])
			draw_colored_polygon(prong, C_STEEL)
			draw_polyline(PackedVector2Array([prong[1], prong[2], prong[0]]), Color(C_PARRY, 0.8), 3.0)
		draw_circle(Vector2(-50, 0), wt * 0.8, Color(C_HEART, 0.6))
		draw_circle(Vector2(-50, 0), wt * 0.4, Color(1.0, 0.9, 0.6, 0.6 + 0.4 * pulse))
		draw_set_transform(Vector2.ZERO, 0.0)


func gauge_radius() -> float:
	return GAUGE_R


## 요격 피해가 촉수 뿌리에서 코어로 흐르는 전류 줄기 (지그재그, 금빛 → 사라짐)
func _draw_zaps() -> void:
	for z in zaps:
		var u := float(z["t"]) / ZAP_TIME
		var from: Vector2 = ROOTS[int(z["from"])]
		var to := CORE_POS
		var pts := PackedVector2Array()
		var dd := (to - from).orthogonal().normalized()
		for q in 9:
			var f := q / 8.0
			var j := 0.0 if q == 0 or q == 8 else sin(q * 7.3 + t * 40.0) * 26.0
			pts.append(from.lerp(to, f) + dd * j)
		var head := mini(8, int(u * 3.0 * 8.0) + 1)             # 앞쪽으로 뻗어 나가다 닿으면 전체가 빛나고 사라진다
		var a := 1.0 - maxf(0.0, u - 0.35) / 0.65
		draw_polyline(pts.slice(0, head + 1), Color(1.0, 0.75, 0.35, 0.5 * a), 12.0)
		draw_polyline(pts.slice(0, head + 1), Color(1.0, 0.95, 0.8, a), 4.0)


## 떨어져 나간 촉수 토막: 마디판 + 관절 + 끊긴 단면의 불씨
func _draw_debris() -> void:
	for d in debris:
		draw_set_transform(d["pos"], float(d["rot"]))
		var pts: PackedVector2Array = d["pts"]
		var ws: PackedFloat32Array = d["ws"]
		for q in pts.size() - 1:
			var dd := (pts[q + 1] - pts[q]).normalized()
			var o := dd.orthogonal()
			draw_colored_polygon(PackedVector2Array([pts[q] + o * ws[q] * 0.5, pts[q + 1] + o * ws[q + 1] * 0.45, pts[q + 1] - o * ws[q + 1] * 0.45, pts[q] - o * ws[q] * 0.5]), C_STEEL)
			draw_circle(pts[q + 1], ws[q + 1] * 0.36, C_BODY_DARK)
		draw_circle(pts[0], ws[0] * 0.4, Color(C_HEART, 0.5))
		draw_circle(pts[0], ws[0] * 0.2, Color(1.0, 0.85, 0.5, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0)

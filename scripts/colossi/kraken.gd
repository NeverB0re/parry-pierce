extends "res://scripts/colossus_base.gd"
## 콜로서스 ③ 크라켄 (차지 강습 + 요격 중심형). 천장에 매달린 거대한 기계 문어형 채굴함. 기계 촉수 8개 중 6개가 싸우고, 바깥 2개는 배경이다.
## 표적은 외투막 한가운데의 외눈(동력 코어) 하나뿐. 촉수에는 노릴 곳이 없다 (돌진은 쉬는 촉수를 그냥 통과한다).
## 핵심: 촉수 공격(근접, 회피 불가)이 위치를 잡고 멈춘 순간을 차지 강습으로 요격하면, 그 촉수(구동부, 2번 요격이면 끊어짐)와 코어에 함께 피해가 들어간다.
## 페이즈: 1) 방어막 — 코어가 방어막에 싸여 있다. 돌진·차지 강습은 튕겨 나오고(피해 없음), 리버스 드라이브와 반사탄은 뚫고 코어에 피해.
##            코어에 쌓인 피해는 균열·깜빡임·연기로 보인다(체력바 없음). 방어막 동안 코어는 SHIELD_FLOOR 아래로는 깎이지 않는다
##         2) 촉수 6개가 모두 떨어져 나가면 방어막이 저절로 산산조각 난다
##         3) 동력 코어 — 직접 노릴 수 있다. 떨어져 나간 촉수 둘(REVIVED)이 다시 자라나고, 요격하면 코어에 바로 피해
## v0.50+: 탄막이 중심 (탄막 6 : 근접 4, 쉬는 시간 짧게). 촉수 끝·배경 다리·분사구가 모두 발사점 (barrage.gd). 근접 중에도 가끔 한 발씩 날아온다.
## 몸은 DROP 만큼 낮게 걸려 있다 (코어 작게, 튕겨 올라가도 천장에 붙지 않게).
## 공격: 몸통 내려치기 · 압착(촉수 둘) · 추적 감아치기 · 휩쓸기 · 조이기(촉수 2개 이상 잃은 뒤) · 먹물 포(부채 탄막, 가운데 주탄)
##       · 방전 그물(패리 불가, 드물게) · 연타 3종(소용돌이·행진·난타, combo.gd). 동시에 예고하는 촉수는 최대 2개.
## 근접 패턴의 첫 타는 예고가 느리다 (tentacle.gd LEAD_K).
## 촉수 모양은 척추(마디 N 개)로 그린다: 강철 마디판 + 관절 링 + 유압 피스톤 + 집게 끝. 쉬는 촉수는 크라켄이, 공격 중인 촉수는 그 공격 모듈(attacks/tentacle.gd)이 움직인다.
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Hammer := preload("res://scripts/attacks/hammer.gd")
const Clap := preload("res://scripts/attacks/clap.gd")
const Chase := preload("res://scripts/attacks/chase.gd")
const Lash := preload("res://scripts/attacks/lash.gd")
const Constrict := preload("res://scripts/attacks/constrict.gd")
const Combo := preload("res://scripts/attacks/combo.gd")
const Net := preload("res://scripts/attacks/net.gd")
const Fan := preload("res://scripts/attacks/fan.gd")
const Spiral := preload("res://scripts/attacks/spiral.gd")
const Barrage := preload("res://scripts/attacks/barrage.gd")

# ── 구조 ───────────────────────────────────────────────
const DROP := 640.0                          # 몸을 천장에서 이만큼 내려 걸었다 (튕겨 올라가도 천장에 붙지 않게)
const CORE_POS := Vector2(0, -2520.0 + DROP)          # 외눈 = 동력 코어 중심 (외투막 한가운데)
const ARMOR_HP := 180                        # 코어 체력 (장갑판 없이 균열로 보인다). 다 깎이면 한 발 더 맞아야 부서진다 (armored_core.gd)
const SHIELD_FLOOR := 60                     # 방어막 동안 코어는 이 아래로 깎이지 않는다 (마지막 페이즈에 할 일을 남긴다)
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
const IDLE_TIPS := [Vector2(-900, -620), Vector2(900, -620), Vector2(-560, -400), Vector2(560, -400), Vector2(-210, -560), Vector2(210, -560)]
const BG_ROOTS := [Vector2(-560, -2300.0 + DROP), Vector2(560, -2300.0 + DROP)]     # 배경 다리 (표적·판정 없음, 방전 그물만 건다)
const BG_TIPS := [Vector2(-1080, -520), Vector2(1080, -520)]
const REVIVED := [2, 3]                      # 코어 페이즈에 다시 자라나는 촉수
const REGROW := 1.6                          # 다시 자라나는 시간
const W_ROOT := 100.0                        # 촉수 굵기 (뿌리 → 끝)
const W_TIP := 40.0
const PART_AT := 3                           # 구동부가 달린 척추 마디
const PART_HP := 16                         # 요격 2번이면 끊어진다
const PART_R := 52.0
const ZAP_TIME := 0.4                        # 요격 피해가 촉수 뿌리에서 코어로 흐르는 전류 줄기

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.45, 0.8)               # 근접 뒤 쉬는 시간
const GAP_CORE := Vector2(0.3, 0.55)
const GAP_FIRE := Vector2(0.25, 0.5)         # 탄막 뒤 (멍때릴 틈을 주지 않는다)
const RANGED_KINDS := ["ink", "spray", "fan", "spiral", "tips", "ring", "cross"]
const RANGED_SHARE := 0.62                   # 탄막 : 근접 = 6 : 4 (근접은 시그니처 패턴 위주)
const AMBIENT_EVERY := 1.15                  # 근접 중·쉬는 중에도 가끔 한 발씩 날아온다
const SPECIAL_EVERY := 4                     # 방전 그물(패리 불가)은 공격 이만큼마다 (드물게)
const COMBO_HITS := 3                        # 연타 타수
const MARCH_X := [-640.0, 0.0, 640.0]        # 행진: 이 자리를 한쪽 끝부터 차례로 내려친다

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
var bg_hold: Array = []                      # 방전 그물이 배경 다리 끝을 붙잡은 위치 [왼, 오] (빈 배열 = 쉼)
var hit_dir := Vector2.ZERO                  # 마지막으로 요격당한 방향 (부서진 촉수가 그쪽으로 날아간다)
var hit_dir_t := -99.0
var siphon_glow := 0.0
var debris: Array[Dictionary] = []           # 떨어져 나간 촉수 조각
var last := ""
var ambient_t := 1.5
var emit_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 발사점 발광 (0~5 촉수 끝, 6·7 배경 다리)
var _ppos := Vector2(0, -400)
var since_special := 0
var zaps: Array[Dictionary] = []             # 코어로 흐르는 전류 줄기 {from, t}
var shield_flash := 0.0                      # 방어막에 무언가 부딪힘 (번쩍)
var shield_hit_n := Vector2.UP               # 부딪힌 쪽
var cracks: Array[PackedVector2Array] = []   # 코어 균열선 (피해가 쌓일수록 앞에서부터 더 많이 그린다)


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
	reset()


func reset() -> void:
	spines.clear()
	bg_spines.clear()
	for i in 6:
		spines.append(PackedVector2Array())
		busy[i] = null
		grown[i] = 1.0
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
	ambient_t = 1.5
	for k in 8:
		emit_glow[k] = 0.0
	since_special = 0
	zaps.clear()
	shield_flash = 0.0


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
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


func target_pos(_from: Vector2) -> Vector2:
	return CORE_POS


## 방어막을 뚫은 피해 (리버스 드라이브·반사탄). 돌진·차지 강습은 main.gd 가 먼저 막는다
func damage(hit: Dictionary, dmg: int) -> bool:
	if hit["kind"] == "shield":
		shield_flash = 1.0
		shield_hit_n = hit["n"]
		_feed_core(dmg)
		return false
	return super(hit, dmg)


## 방어막 너머 코어에 피해를 쌓는다 (SHIELD_FLOOR 아래로는 안 깎인다). 균열 단계가 오르면 CORE_STAGE 이벤트(흔들림·파편)
func _feed_core(dmg: int) -> void:
	var d := mini(dmg, core.armor_hp - SHIELD_FLOOR)
	if d > 0:
		core.damage(d)
	else:
		core.flash = 1.0


## 촉수 요격 피해 (main.gd _clash): 촉수 구동부 + 코어. 뿌리에서 코어로 전류 줄기가 흐른다
func damage_part(i: int, dmg: int) -> bool:
	if phase == 1 and part_alive(i):
		_feed_core(dmg)
		zaps.append({"from": i, "t": 0.0})
	var broke := super(i, dmg)
	if broke and phase == 2:                         # 마지막 촉수 → 방어막이 산산조각
		shield_flash = 1.0
		for k in 14:
			var a := k * TAU / 14.0 + randf_range(-0.1, 0.1)
			var at := CORE_POS + Vector2.from_angle(a) * SHIELD_R
			_spawn_shard(at, randf_range(18.0, 30.0), Vector2.from_angle(a) * randf_range(500.0, 900.0) + Vector2(0, -300))
	return broke


## 코어 페이즈: 다시 자란 촉수를 요격 → 코어에 바로 피해. 부서지면 true (승리)
func intercept_core(i: int, dmg: int) -> bool:
	zaps.append({"from": i, "t": 0.0})
	return damage_core(dmg)


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
	if busy[i] != null:
		return false
	if phase == 1:
		return part_alive(i)
	return phase == 3 and REVIVED.has(i) and grown[i] >= 1.0


## 촉수를 잃을수록(페이즈 1), 코어 페이즈일수록 예고가 짧아진다 (공격 모듈이 곱한다)
func tempo() -> float:
	if phase == 3:
		return 0.78
	return maxf(0.7, 1.0 - 0.06 * (6 - parts_left()))


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


## 쉬는 자세: 천천히 흔들리며 늘어져 있다. 자란 정도(grown)만큼만 뿌리에서 뻗는다 (떨어져 나간 촉수는 뿌리에 모인다)
func _idle_spine(i: int) -> PackedVector2Array:
	var root: Vector2 = ROOTS[i]
	var s := 1.0 if i % 2 == 1 else -1.0
	var tip: Vector2 = IDLE_TIPS[i] + Vector2(sin(t * 0.9 + i * 1.3) * 45.0, cos(t * 0.7 + i) * 30.0)
	var sp := _bezier_spine(root, tip, s * (90.0 + 70.0 * sin(t * 0.8 + i * 0.9)), N)
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
	_ambient(dt)
	shield_flash = maxf(0.0, shield_flash - dt * 3.0)
	for z in zaps.duplicate():
		z["t"] = float(z["t"]) + dt
		if z["t"] >= ZAP_TIME:
			zaps.erase(z)
	siphon_glow = move_toward(siphon_glow, 0.0, dt * 2.0)
	if phase == 3:                               # 코어 페이즈: 촉수 둘이 뿌리에서 다시 자라난다
		for i in REVIVED:
			grown[i] = minf(1.0, grown[i] + dt / REGROW)


## 근접 공격 중·쉬는 중에도 가끔 한 발씩 (플레이어가 가만히 있지 못하게). 탄막 중에는 쏘지 않는다
func _ambient(dt: float) -> void:
	if dead or hold_attacks or phase == 2:
		return
	if atk != null and (RANGED_KINDS.has(atk.kind) or atk.kind == "net"):
		return
	ambient_t -= dt
	if ambient_t > 0.0:
		return
	ambient_t = AMBIENT_EVERY * randf_range(0.8, 1.2)
	var em := emitters()
	var e: Array = em[randi() % em.size()]
	var o: Vector2 = e[1]
	var d := (_ppos - o).normalized().rotated(randf_range(-0.12, 0.12))
	shots.spawn(o, d * 270.0 * bolt_mult(), 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
	emit_glow_set(int(e[0]), 1.0)
	emit(Ev.BOLT, o)


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
	if id < 0:
		siphon_glow = v
	else:
		emit_glow[id] = v


func die() -> void:
	super()
	bg_hold = []


func _choose(ppos: Vector2) -> void:
	since_special += 1
	var hard := phase == 3
	var ready: Array[int] = []
	for i in 6:
		if tent_ready(i):
			ready.append(i)
	if since_special >= SPECIAL_EVERY and randf() < 0.55:    # 드물게: 방전 그물 (패리 불가)
		since_special = 0
		_pick("net", Net.new(randf() < 0.5))
		return
	var fire: Array[String] = ["ink", "spray", "tips", "ring", "cross"]
	var melee: Array[String] = []
	if not ready.is_empty():
		melee.append_array(["hammer", "chase", "sweep"])
		if ready.size() >= 2:
			melee.append_array(["clap", "vortex", "march", "flurry", "vortex", "flurry"])
			if hard:
				melee.append_array(["vortex", "flurry"])
			if hard or parts_left() <= 4:
				melee.append_array(["constrict", "constrict", "constrict"])
	var pool: Array[String] = fire
	if not melee.is_empty() and randf() > RANGED_SHARE:
		pool = melee
	pool = pool.duplicate()
	while pool.size() > 1 and pool.has(last):
		pool.erase(last)
	var kind: String = pool[randi() % pool.size()]
	match kind:
		"hammer":
			_grab_start("hammer", Hammer.new(_nearest(ready, ppos.x)))
		"chase":
			_grab_start("chase", Chase.new(_nearest(ready, ppos.x)))
		"sweep":
			_grab_start("sweep", Lash.new(_sweeper(ready, ppos)))
		"clap":
			var lr := _outer_pair(ready)
			_grab_start("clap", Clap.new(lr[0], lr[1]))
		"constrict":
			var lr := _outer_pair(ready)
			_grab_start("constrict", Constrict.new(lr[0], lr[1]))
		"vortex", "march", "flurry":
			_pick(kind, _combo(kind, ready, ppos))
		"spray":
			_pick("spray", Spiral.new(-1, SIPHON, ppos, hard))
		"tips", "ring", "cross":
			_pick(kind, Barrage.new(kind, emitters(), ppos, hard))
		_:
			_pick("ink", Fan.new(-1, SIPHON, ppos, hard))


## 연타: 촉수를 번갈아 COMBO_HITS 번. 그때 쓸 수 없는 촉수면 같은 무리의 다른 촉수, 그것도 없으면 그 타는 건너뛴다
##  vortex 소용돌이 = 빠른 내려치기가 매번 플레이어를 겨눈다 / march 행진 = 정해진 자리를 플레이어에게서 먼 쪽부터 차례로 내려친다
##  flurry 난타 = 좌우 촉수가 번갈아 휩쓴다
func _combo(kind: String, ready: Array[int], ppos: Vector2) -> Combo:
	var lr := _outer_pair(ready)
	var xs: Array = MARCH_X.duplicate()
	if ppos.x < 0.0:                                         # 먼 쪽부터 다가온다
		xs.reverse()
	var makers := []
	for k in COMBO_HITS:
		var want: int = lr[k % 2]
		var x: float = xs[k]
		makers.append(func():
			var i := _free_tent(want, lr)
			if i < 0:
				return null
			match kind:
				"march":
					return Hammer.new(i, true, 0.0, x)
				"flurry":
					var a = Lash.new(i)
					a.pace = 0.7
					return a
			return Hammer.new(i, true))
	return Combo.new(kind, makers, 0.95 if kind == "flurry" else 0.8)


func _free_tent(want: int, alts: Array[int]) -> int:
	if tent_ready(want):
		return want
	for i in alts:
		if tent_ready(i):
			return i
	return -1


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
func _sweeper(ts: Array[int], ppos: Vector2) -> int:
	var best := -1
	for i in ts:
		var same_side: bool = signf(ROOTS[i].x) == signf(ppos.x)
		if same_side and ppos.distance_to(ROOTS[i]) < Lash.REACH + 80.0:
			if best < 0 or ppos.distance_to(ROOTS[i]) < ppos.distance_to(ROOTS[best]):
				best = i
	return best if best >= 0 else _nearest(ts, ppos.x)


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
	var revived := phase >= 2 and REVIVED.has(i) and not dead
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


## 외투막 (몸통): 천장 너머까지 이어진 둥근 머리 + 양쪽 지느러미 + 눈 + 아래 분사구
func _draw_mantle() -> void:
	draw_set_transform(Vector2(0, DROP))
	var sway := sin(t * 0.7) * 14.0
	draw_colored_polygon(PackedVector2Array([Vector2(-150, -3150), Vector2(150, -3150), Vector2(190, -3700), Vector2(-190, -3700)]), C_BODY_DARK)   # 천장에서 늘어진 줄기
	for s2 in [-1.0, 1.0]:
		draw_line(Vector2(s2 * 150, -3150), Vector2(s2 * 190, -3700), Color(C_RIM, 0.4), 3.0)
	for s in [-1.0, 1.0]:                                 # 지느러미
		var fin := PackedVector2Array([Vector2(s * 380, -2950), Vector2(s * (720 + sway), -3150), Vector2(s * (680 + sway), -2860), Vector2(s * 520, -2700)])
		draw_colored_polygon(fin, C_BODY_DARK)
		draw_polyline(PackedVector2Array([fin[0], fin[1], fin[2]]), Color(C_RIM, 0.4), 3.0)
	var body := PackedVector2Array([
		Vector2(-560, -2350), Vector2(-540, -2650), Vector2(-420, -2960), Vector2(-200, -3180), Vector2(200, -3180),
		Vector2(420, -2960), Vector2(540, -2650), Vector2(560, -2350), Vector2(470, -2200), Vector2(300, -2135),
		Vector2(0, -2105), Vector2(-300, -2135), Vector2(-470, -2200)])
	draw_colored_polygon(body, C_BODY)
	var ol := body.duplicate()
	ol.append(body[0])
	draw_polyline(ol, Color(C_RIM, 0.55), 4.0)
	for k in 5:                                          # 외투막 주름 (기계 판 이음매)
		var y := -2300.0 - k * 150.0
		var w := 520.0 - k * 40.0
		draw_line(Vector2(-w, y), Vector2(-260, y - 30), Color(C_BODY_DARK, 1.0), 6.0)
		draw_line(Vector2(260, y - 30), Vector2(w, y), Color(C_BODY_DARK, 1.0), 6.0)
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
	draw_colored_polygon(shell, Color(0.2, 0.06, 0.05).lerp(Color(0.08, 0.04, 0.04), f))
	draw_colored_polygon(core.shell_inner, Color(0.45, 0.12, 0.07).lerp(Color(0.22, 0.07, 0.05), f))
	var flick := 1.0
	if f > 0.55:                                             # 많이 상함: 동공 빛이 깜빡인다
		flick = 0.55 + 0.45 * float(int(t * (8.0 + f * 10.0)) % 4 != 0)
	if core.broken:
		flick = 0.55 + 0.45 * float(int(t * 14.0) % 3 != 0)
	var glow := Color(C_HEART, flick).lerp(Color.WHITE, core.flash * 0.7)
	var pr := CORE_R * (1.0 + 0.06 * beat)
	draw_circle(hc, pr * 2.2, Color(C_HEART, (0.1 + 0.1 * beat) * flick))
	var pupil := PackedVector2Array()                         # 가로로 찢어진 동공
	for k in 16:
		var a := k * TAU / 16.0
		pupil.append(hc + Vector2(cos(a) * pr * 1.5, sin(a) * pr * 0.5))
	draw_colored_polygon(pupil, glow)
	draw_circle(hc + Vector2(-pr * 0.5, -pr * 0.15), pr * 0.18, Color(1.0, 0.9, 0.7, 0.9 * flick))
	var n := int(ceil(f * cracks.size()))                     # 균열: 쌓인 피해만큼
	for k in n:
		var cr: PackedVector2Array = cracks[k]
		var pts := PackedVector2Array()
		for q in cr:
			pts.append(hc + q)
		draw_polyline(pts, Color(0.05, 0.02, 0.02), 7.0)
		draw_polyline(pts, Color(1.0, 0.55, 0.22, 0.55 + 0.4 * beat), 3.0)
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
	if focus_glow > 0.0 and phase == 3:
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, EYE_RX + 40.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.55, focus_glow * (0.6 if in_reach else 0.25)), 3.0)


## 방어막: 페이즈 1 = 육각 무늬가 흐르는 청록 막 (부딪힌 쪽이 번쩍), 페이즈 2 = 금이 가며 사라진다 (파편은 damage_part 가 뿌린다)
func _draw_shield() -> void:
	if dead or phase == 3:
		return
	var k := 1.0 if phase == 1 else 1.0 - clampf(open_t / SHIELD_SHATTER * 3.0, 0.0, 1.0)
	if k <= 0.0:
		return
	var c := Color(0.45, 0.95, 1.0)
	var hc := CORE_POS
	draw_circle(hc, SHIELD_R, Color(c, (0.07 + 0.12 * shield_flash) * k))
	draw_arc(hc, SHIELD_R, 0.0, TAU, 64, Color(c, (0.55 + 0.4 * shield_flash) * k), 4.0)
	draw_arc(hc, SHIELD_R - 10.0, 0.0, TAU, 64, Color(c, 0.18 * k), 2.0)
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

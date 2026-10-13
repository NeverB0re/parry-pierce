extends "res://scripts/colossus_base.gd"
## 콜로서스 ③ 크라켄 (차지 강습 + 요격 중심형). 천장에 매달린 거대한 기계 문어형 채굴함. 기계 촉수 8개 중 6개가 싸우고, 바깥 2개는 배경이다.
## 핵심: 촉수 공격(근접, 회피 불가)이 위치를 잡고 멈춘 순간을 차지 강습으로 요격하면, 그 촉수의 구동부에 바로 피해가 들어간다.
## 페이즈: 1) 외부 시스템 = 촉수 6개의 구동부(체력 20). 구동부가 부서진 촉수는 뿌리째 떨어져 나간다. 촉수를 잃을수록 남은 촉수가 빨라진다
##         2) 개방 — 외투막 한가운데가 좌우로 열린다
##         3) 동력 코어 — 장갑에 싸인 코어. 떨어져 나간 촉수 둘(REVIVED)이 뿌리에서 다시 자라난다 (표적은 아님, 요격하면 공격만 끊김)
## 공격: 몸통 내려치기 · 압착(촉수 둘) · 추적 감아치기 · 휩쓸기 · 조이기(촉수 2개 이상 잃은 뒤) · 먹물 포(부채 탄막, 가운데 주탄)
##       · 방전 그물(패리 불가, 드물게) · 소용돌이(코어 페이즈 전용, 연속 내려치기). 동시에 예고하는 촉수는 최대 2개.
## 촉수 모양은 척추(마디 N 개)로 그린다: 강철 마디판 + 관절 링 + 유압 피스톤 + 집게 끝. 쉬는 촉수는 크라켄이, 공격 중인 촉수는 그 공격 모듈(attacks/tentacle.gd)이 움직인다.
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Hammer := preload("res://scripts/attacks/hammer.gd")
const Clap := preload("res://scripts/attacks/clap.gd")
const Chase := preload("res://scripts/attacks/chase.gd")
const Lash := preload("res://scripts/attacks/lash.gd")
const Constrict := preload("res://scripts/attacks/constrict.gd")
const Vortex := preload("res://scripts/attacks/vortex.gd")
const Net := preload("res://scripts/attacks/net.gd")
const Fan := preload("res://scripts/attacks/fan.gd")

# ── 구조 ───────────────────────────────────────────────
const CORE_POS := Vector2(0, -2520)          # 동력 코어 중심 (외투막 안)
const DOOR_RECT := Rect2(-240, -2790, 480, 540)
const ARMOR_HP := 170
const PLATE_SITES := 10
const CORE_R := 60.0
const CORE_OUTLINE := [
	Vector2(0, -262), Vector2(78, -226), Vector2(145, -173), Vector2(189, -94), Vector2(205, 0), Vector2(189, 94),
	Vector2(145, 173), Vector2(78, 226), Vector2(0, 262), Vector2(-78, 226), Vector2(-145, 173), Vector2(-189, 94),
	Vector2(-205, 0), Vector2(-189, -94), Vector2(-145, -173), Vector2(-78, -226),
]
const PLATE_SITE_BOX := Rect2(-200, -240, 400, 480)
const SIPHON := Vector2(0, -2120)            # 먹물 포 (외투막 아래 분사구)
const EYES := [Vector2(-350, -2420), Vector2(350, -2420)]

# ── 촉수 ───────────────────────────────────────────────
const N := 12                                # 척추 마디 수
# 촉수 0~5 (짝수 = 왼쪽, 홀수 = 오른쪽): 뿌리와 쉬는 자세의 끝
const ROOTS := [Vector2(-430, -2210), Vector2(430, -2210), Vector2(-260, -2170), Vector2(260, -2170), Vector2(-90, -2150), Vector2(90, -2150)]
const IDLE_TIPS := [Vector2(-900, -1000), Vector2(900, -1000), Vector2(-560, -760), Vector2(560, -760), Vector2(-210, -1080), Vector2(210, -1080)]
const BG_ROOTS := [Vector2(-560, -2300), Vector2(560, -2300)]     # 배경 다리 (표적·판정 없음, 방전 그물만 건다)
const BG_TIPS := [Vector2(-1080, -620), Vector2(1080, -620)]
const REVIVED := [2, 3]                      # 코어 페이즈에 다시 자라나는 촉수
const REGROW := 1.6                          # 다시 자라나는 시간
const W_ROOT := 100.0                        # 촉수 굵기 (뿌리 → 끝)
const W_TIP := 40.0
const PART_AT := 3                           # 구동부가 달린 척추 마디
const PART_HP := 20
const PART_R := 52.0
const OPEN_TIME := 1.6

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.7, 1.2)
const GAP_CORE := Vector2(0.45, 0.85)
const SPECIAL_EVERY := 4                     # 방전 그물(패리 불가)은 공격 이만큼마다 (드물게)

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.06, 0.08, 0.09)
const C_BODY_DARK := Color(0.035, 0.05, 0.06)
const C_RIM := Color(0.4, 0.53, 0.55)
const C_STEEL := Color(0.14, 0.17, 0.19)     # 촉수 마디판
const C_PISTON := Color(0.62, 0.66, 0.68)
const C_EYE := Color(1.0, 0.78, 0.42)
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
var since_special := 0


func _init() -> void:
	open_time = OPEN_TIME
	attack_gap = GAP
	core_assist_r = 220.0


func _ready() -> void:
	core = ArmoredCore.new(self, CORE_POS, CORE_OUTLINE, ARMOR_HP, PLATE_SITE_BOX, PLATE_SITES, 37)
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
	since_special = 0


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


func _step_phase(dt: float) -> void:
	attack_gap = GAP_CORE if phase == 3 else GAP
	siphon_glow = move_toward(siphon_glow, 0.0, dt * 2.0)
	if phase == 3:                               # 코어 페이즈: 촉수 둘이 뿌리에서 다시 자라난다
		for i in REVIVED:
			grown[i] = minf(1.0, grown[i] + dt / REGROW)


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
	var pool: Array[String] = ["ink"]
	if not ready.is_empty():
		pool.append_array(["hammer", "hammer", "chase", "sweep"])
		if hard:
			pool.append_array(["vortex", "vortex"])
		if ready.size() >= 2:
			pool.append("clap")
			if hard or parts_left() <= 4:
				pool.append_array(["constrict", "constrict"])
	while pool.size() > 1 and pool.has(last):
		pool.erase(last)
	match pool[randi() % pool.size()]:
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
		"vortex":
			_pick("vortex", Vortex.new(ready))
		_:
			_pick("ink", Fan.new(-1, SIPHON, ppos, hard))


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
func set_glow(_c: int, v: float) -> void:
	siphon_glow = v


func glow_of(_c: int) -> float:
	return siphon_glow


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
	_draw_door()
	for i in 6:
		_draw_arm(i)
	_draw_part_marks()
	_draw_debris()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


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
	var sway := sin(t * 0.7) * 14.0
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
	for e in EYES:                                       # 눈: 가로로 찢어진 동공
		draw_circle(e, 62.0, C_BODY_DARK)
		draw_arc(e, 62.0, 0.0, TAU, 28, Color(C_RIM, 0.6), 4.0)
		var g := 0.55 if not dead else maxf(0.0, 0.55 - death_t * 0.4)
		draw_circle(e, 40.0, Color(C_EYE, 0.14 * g))
		draw_rect(Rect2(e.x - 34.0, e.y - 7.0, 68.0, 14.0), Color(C_EYE, g))
	# 분사구 (먹물 포)
	draw_circle(SIPHON, 46.0, C_BODY_DARK)
	draw_arc(SIPHON, 46.0, 0.0, PI, 18, C_RIM, 4.0)
	draw_circle(SIPHON + Vector2(0, 14), 18.0 + 14.0 * siphon_glow, Color(C_GLOW, 0.2 + 0.6 * siphon_glow))


## 외투막 문: 페이즈 1 닫힘, 2 좌우로 열리는 중, 3 코어
func _draw_door() -> void:
	var open_k := 0.0 if phase == 1 else (1.0 if phase == 3 else clampf(open_t / OPEN_TIME, 0.0, 1.0))
	if open_k > 0.0:
		_draw_core()
	if open_k >= 1.0:
		return
	var rc := DOOR_RECT
	var half_w := rc.size.x * 0.5
	var slide := ease(open_k, 2.2) * (half_w + 20.0)
	var alpha := 1.0 - maxf(0.0, open_k - 0.7) / 0.3
	for s in [-1.0, 1.0]:
		var x0: float = rc.position.x + (0.0 if s < 0.0 else half_w) + s * slide
		var door := Rect2(x0, rc.position.y, half_w, rc.size.y)
		draw_rect(door, Color(C_BODY_DARK, alpha))
		draw_rect(door, Color(C_RIM, 0.55 * alpha), false, 4.0)
		for k in 6:                                      # 비늘 판
			var y := door.position.y + 45.0 + k * 85.0
			draw_arc(Vector2(door.position.x + door.size.x * 0.5, y), 70.0, 0.2, PI - 0.2, 12, Color(C_RIM, 0.3 * alpha), 3.0)
	if open_k > 0.0:
		var gap := slide * 2.0
		draw_rect(Rect2(CORE_POS.x - gap * 0.5, rc.position.y, gap, rc.size.y), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(0, rc.position.y), Vector2(0, rc.end.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)


func _draw_core() -> void:
	var hc := CORE_POS
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (4.2 + f * 5.0))
	var lit := strike_glow or focus_glow > 0.0
	var shell: PackedVector2Array = core.shell_poly
	if dead:
		draw_colored_polygon(shell, Color(0.1, 0.05, 0.05))
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	draw_colored_polygon(shell, Color(0.12, 0.05, 0.05))
	draw_colored_polygon(core.shell_inner, Color(0.24, 0.07, 0.06).lerp(Color(0.45, 0.12, 0.07), f * 0.6))
	for k in 5:                                          # 신경 다발 (맥동)
		var a := k * TAU / 5.0 + 0.3
		var p1 := hc + Vector2.from_angle(a) * 70.0
		var p2 := hc + Vector2.from_angle(a + 0.4 * sin(t * 2.0 + k)) * 180.0
		draw_line(p1, p2, Color(0.55, 0.12, 0.1, 0.7), 6.0)
	var flick := 1.0
	if core.broken:
		flick = 0.55 + 0.45 * float(int(t * 14.0) % 3 != 0)
	var pr := CORE_R * (1.0 + 0.06 * beat)
	var ca := 0.35 + 0.65 * minf(1.0, f * 1.3)
	draw_circle(hc, pr * 2.0, Color(C_HEART, (0.08 + 0.1 * beat) * ca * flick))
	draw_circle(hc, pr * 1.3, Color(C_HEART, 0.35 * ca * flick))
	draw_circle(hc, pr, Color(C_HEART, ca * flick).lerp(Color.WHITE, core.flash * 0.6))
	draw_circle(hc + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.4, Color(1.0, 0.85, 0.6, ca * flick))
	core.draw_plates(self, t, lit, beat)
	var smoke := int(f * 6.0)
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -150.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if core.broken:
		for k in 6:
			var sa := t * 4.0 + k * 1.1
			var sd := CORE_R + 14.0 + fmod(t * 120.0 + k * 41.0, 80.0)
			draw_circle(hc + Vector2.from_angle(sa) * sd, 3.0, Color(1.0, 0.85, 0.5, 0.9))
		draw_arc(hc, CORE_R + 22.0 + 6.0 * beat, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.55 + 0.4 * beat), 3.0)
	if focus_glow > 0.0:
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, 290.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.55, focus_glow * (0.6 if in_reach else 0.25)), 3.0)


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

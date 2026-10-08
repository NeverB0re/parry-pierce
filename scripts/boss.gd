extends Node2D
## 거대한 적 (정면). 배경에 서 있어서 몸 자체는 충돌/피해 판정이 없다.
## 판정은 두 종류:
##  1) 적이 공격할 때 그 공격(주먹/발/충격파/탄환) — 그때만 생긴다
##  2) 표적(부위·갑옷·심장)은 상시 판정: 돌진 중에 닿으면 타격, 아니면 닿은 플레이어가 피해
## 페이즈: 1) 부위 파괴 — 좌/우 포대, 좌/우 팔꿈치 관절을 부순다 (가슴은 닫혀 있음)
##         2) 개방 연출 — 가슴이 열린다
##         3) 코어 — 하트 모양 갑옷에 싸인 심장. 탄은 머리에서 쏜다
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

# ── 구조 ───────────────────────────────────────────────
const CELL := 60.0
const GRID_N := 7
const GRID_ORIGIN := Vector2(-210, -2110)   # 가슴 갑옷 격자 좌상단 (7x7, 중심이 심장)
const HEART_CELL := 3
const HEART_R := 24.0
const RING_HP := [0, 5, 3, 2]               # 심장에서의 거리(칸)별 내구도: 0=심장, 1=가장 안쪽(강철), 2=중간, 3=바깥
const PLATE_COL := [Color(0, 0, 0), Color(0.38, 0.46, 0.56), Color(0.6, 0.47, 0.32), Color(0.64, 0.6, 0.52)]
const HEART_MASK := [                       # 하트 모양 갑옷 (1 = 갑옷 칸)
	"0110110",
	"1111111",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]

const HIPS := [Vector2(-210, -1020), Vector2(210, -1020)]
const FOOT_REST := [Vector2(-230, 0), Vector2(230, 0)]
const LEG_SEG := 470.0
const SHOULDERS := [Vector2(-470, -2260), Vector2(470, -2260)]
const FIST_IDLE := [Vector2(-600, -1100), Vector2(600, -1100)]
const ARM_SEG := 620.0
const MUZZLES := [Vector2(-640, -2470), Vector2(640, -2470)]   # 양어깨 포대의 포구
const HEAD_POS := Vector2(0, -2605)                             # 최종 페이즈 탄 발사점
const EYES := [Vector2(-62, -2605), Vector2(62, -2605)]

# ── 부위 ───────────────────────────────────────────────
const PART_HP := 6                          # 0 왼쪽 포대, 1 오른쪽 포대, 2 왼팔 관절, 3 오른팔 관절
const PART_R := [55.0, 55.0, 70.0, 70.0]
const OPEN_TIME := 1.6                      # 가슴이 열리는 연출 시간

# ── 공격 튜닝 ──────────────────────────────────────────
const LOW_ZONE_Y := -650.0           # 이보다 아래(바닥 근처)면 내려찍기 위주
const STOMP_LIFT_TIME := 0.9
const STOMP_LIFT_H := 420.0
const STOMP_SLAM_TIME := 0.14
const WAVE_SPEED := 850.0
const WAVE_H := 70.0
const WAVE_HALF := 45.0
const SWING_L := 1180.0              # 팔 전체를 곧게 뻗어 휩쓰는 반경
const SWING_WIND := 1.0              # 경고(휩쓸 부채꼴이 표시된다)
const SWING_TIME := 0.65
const SWING_HOLD := 0.25
const SWING_SPAN := 2.6              # 휩쓰는 각도(라디안, 약 150도)
const FIST_R := 105.0
const BOLT_SPEED := 400.0
const BOLT_SPEEDUP := 0.1            # 부위 하나 부술 때마다 탄 속도 +10%
const BOLT_SPEEDUP_CORE := 0.15      # 최종 페이즈 추가 가속
const BOLT_WARMUP := 0.6             # 발사 직후 느리게 출발해 점점 빨라진다(반응 시간)
const VOLLEY_CHARGE := 1.0
const BURST_CHARGE := 1.3
const BOLT_R := 16.0
const ATTACK_GAP := Vector2(1.2, 2.2)   # 공격 사이 쉬는 시간

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.075, 0.08, 0.10)
const C_BODY_DARK := Color(0.045, 0.05, 0.065)
const C_RIM := Color(0.48, 0.52, 0.6)
const C_CLOAK := Color(0.05, 0.045, 0.07)
const C_BONE := Color(0.78, 0.75, 0.68)
const C_PLATE_EDGE := Color(0.62, 0.3, 0.14)     # 상시 위험(닿으면 피해) → 달궈진 가장자리
const C_CAVITY := Color(0.10, 0.03, 0.04)
const C_HEART := Color(1.0, 0.42, 0.22)
const C_EYE := Color(1.0, 0.78, 0.42)
const C_WARN := Color(1.0, 0.3, 0.25)

var phase := 1
var open_t := 0.0
var part_hp: Array[int] = []
var part_flash: Array[float] = []
var plates: Array[int] = []
var plate_flash: Array[float] = []
var feet: Array[Vector2] = []
var fists: Array[Vector2] = []
var arm_prefer: Array[Vector2] = []  # 팔꿈치가 굽는 쪽
var debris: Array[Dictionary] = []   # 부서져 떨어진 부위
var atk: Dictionary = {}
var bolts: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var next_t := 2.5
var eye_glow := 0.0
var cannon_glow: Array[float] = [0.0, 0.0]   # 발사 전 포구가 달아오르는 정도
var strike_glow := false             # 플레이어가 돌진 중 = 타격점이 드러난다
var dead := false
var death_t := 0.0
var t := 0.0
var events: Array[Dictionary] = []   # main.gd 가 매 프레임 꺼내 처리 (흔들림/사운드)


func _ready() -> void:
	reset()


func reset() -> void:
	phase = 1
	open_t = 0.0
	part_hp = [PART_HP, PART_HP, PART_HP, PART_HP]
	part_flash = [0.0, 0.0, 0.0, 0.0]
	plates.clear()
	plate_flash.clear()
	for r in GRID_N:
		for c in GRID_N:
			var ring := maxi(absi(c - HEART_CELL), absi(r - HEART_CELL))
			plates.append(RING_HP[ring] if in_mask(c, r) else 0)
			plate_flash.append(0.0)
	feet.clear()
	feet.append(FOOT_REST[0])
	feet.append(FOOT_REST[1])
	fists.clear()
	fists.append(FIST_IDLE[0])
	fists.append(FIST_IDLE[1])
	arm_prefer.clear()
	arm_prefer.append(Vector2(-1.0, 0.35))
	arm_prefer.append(Vector2(1.0, 0.35))
	debris.clear()
	atk = {}
	bolts.clear()
	waves.clear()
	next_t = 2.5
	eye_glow = 0.0
	cannon_glow = [0.0, 0.0]
	dead = false
	death_t = 0.0
	events.clear()
	queue_redraw()


# ── 부위 ───────────────────────────────────────────────
func part_alive(i: int) -> bool:
	return part_hp[i] > 0


func parts_left() -> int:
	var n := 0
	for hp in part_hp:
		if hp > 0:
			n += 1
	return n


func cannon_base(c: int) -> Vector2:
	var s := 1.0 if c == 1 else -1.0
	return SHOULDERS[c] + Vector2(s * 60.0, -110.0)


func part_pos(i: int) -> Vector2:
	if i < 2:
		return cannon_base(i).lerp(MUZZLES[i], 0.55)
	return elbow_of(i - 2)


## 부위 피해. 부서지면 떨어져 나가고, 넷 다 부서지면 가슴이 열린다
func damage_part(i: int, dmg: int) -> bool:
	if not part_alive(i):
		return false
	part_flash[i] = 1.0
	if part_hp[i] - dmg > 0:
		part_hp[i] -= dmg
		return false
	var pos := part_pos(i)
	var s := 1.0 if i % 2 == 1 else -1.0
	if i < 2:
		var base := cannon_base(i)
		var mz: Vector2 = MUZZLES[i]
		debris.append({"pos": (base + mz) * 0.5, "half": (mz - base) * 0.5, "w": 54.0, "fist": false,
			"vel": Vector2(s * 260.0, -380.0), "rot": 0.0, "rotv": s * 3.5, "rest": false})
		if atk.get("cannon", -2) == i:
			_finish()
	else:
		var a := i - 2
		var el := elbow_of(a)
		debris.append({"pos": (el + fists[a]) * 0.5, "half": (fists[a] - el) * 0.5, "w": 125.0, "fist": true,
			"vel": Vector2(s * 200.0, -250.0), "rot": 0.0, "rotv": s * 2.2, "rest": false})
		if atk.get("kind", "") == "swing" and atk.get("arm", -1) == a:
			_finish()
	part_hp[i] = 0
	events.append({"type": "part_break", "pos": pos})
	if parts_left() == 0:
		phase = 2
		open_t = 0.0
		atk = {}
		next_t = OPEN_TIME + 1.0
		events.append({"type": "core_open", "pos": heart_pos()})
	return true


## 탄 속도 배율: 부위를 부술수록, 최종 페이즈일수록 빨라진다
func bolt_mult() -> float:
	return 1.0 + BOLT_SPEEDUP * (4 - parts_left()) + (BOLT_SPEEDUP_CORE if phase == 3 else 0.0)


## HUD 화살표가 가리킬 다음 표적
func target_pos(from: Vector2) -> Vector2:
	if phase >= 2:
		return heart_pos()
	var best := heart_pos()
	var best_d := INF
	for i in 4:
		if part_alive(i) and part_pos(i).distance_to(from) < best_d:
			best_d = part_pos(i).distance_to(from)
			best = part_pos(i)
	return best


# ── 격자 ───────────────────────────────────────────────
func in_mask(c: int, r: int) -> bool:
	return String(HEART_MASK[r])[c] == "1"


func cell_rect(c: int, r: int) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(c, r) * CELL, Vector2(CELL, CELL))


func heart_pos() -> Vector2:
	return cell_rect(HEART_CELL, HEART_CELL).get_center()


func damage_plate(idx: int, dmg: int) -> bool:
	if plates[idx] <= 0:
		return false
	plates[idx] = maxi(0, plates[idx] - dmg)
	plate_flash[idx] = 1.0
	return plates[idx] == 0


func plates_left() -> int:
	var n := 0
	for hp in plates:
		if hp > 0:
			n += 1
	return n


# ── 플레이어 공격 판정 ─────────────────────────────────
## 원(p, r)이 닿은 표적. 페이즈 1은 부위, 페이즈 3은 갑옷이 먼저, 막힘 없이 닿으면 심장. {kind, idx?}
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead or phase == 2:
		return {}
	if phase == 1:
		var best := {}
		var best_d := INF
		for i in 4:
			if not part_alive(i):
				continue
			var d := p.distance_to(part_pos(i))
			if d < r + float(PART_R[i]) and d < best_d:
				best_d = d
				best = {"kind": "part", "idx": i}
		return best
	var best := {}
	var best_d := 0.0
	for i in plates.size():
		if plates[i] <= 0:
			continue
		var h := _rect_hit(p, r, cell_rect(i % GRID_N, i / GRID_N).grow(-2.0))
		if not h.is_empty() and h["depth"] > best_d:
			best_d = h["depth"]
			best = {"kind": "plate", "idx": i}
	if not best.is_empty():
		return best
	if p.distance_to(heart_pos()) < r + HEART_R:
		return {"kind": "heart"}
	return {}


func hit_center(hit: Dictionary) -> Vector2:
	match hit["kind"]:
		"heart":
			return heart_pos()
		"part":
			return part_pos(int(hit["idx"]))
	var idx: int = hit["idx"]
	return cell_rect(idx % GRID_N, idx / GRID_N).get_center()


static func _rect_hit(p: Vector2, r: float, rc: Rect2) -> Dictionary:
	var q := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
	var d := p - q
	var l := d.length()
	if l > 0.0001:
		if l >= r:
			return {}
		return {"n": d / l, "depth": r - l}
	var m := minf(minf(p.x - rc.position.x, rc.end.x - p.x), minf(p.y - rc.position.y, rc.end.y - p.y))
	return {"n": Vector2.UP, "depth": m + r}


func foot_rect(i: int) -> Rect2:
	var f := feet[i]
	return Rect2(f.x - 130.0, f.y - 110.0, 260.0, 110.0)


func knee_of(i: int) -> Vector2:
	var ankle := feet[i] + Vector2(0, -100)
	return _joint(HIPS[i], ankle, LEG_SEG, Vector2(1.0 if i == 1 else -1.0, 0))


func elbow_of(a: int) -> Vector2:
	if not part_alive(2 + a):              # 부서진 팔: 위팔만 축 늘어져 있다
		return SHOULDERS[a] + Vector2((1.0 if a == 1 else -1.0) * 90.0, 430.0)
	return _joint(SHOULDERS[a], fists[a], ARM_SEG, arm_prefer[a])


## 두 마디 관절 위치. prefer 쪽으로 굽힌다.
static func _joint(a: Vector2, b: Vector2, seg: float, prefer: Vector2) -> Vector2:
	var d := b - a
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, seg * seg - half * half))
	var perp := d.orthogonal().normalized()
	if perp.dot(prefer) < 0.0:
		perp = -perp
	return (a + b) * 0.5 + perp * h


# ── 적 공격 판정 ───────────────────────────────────────
## 현재 활성화된 공격 판정들. push = 플레이어가 밀려나는 방향.
func hitboxes(ppos: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	if atk.get("kind", "") == "stomp" and atk["phase"] == "slam":
		var i: int = atk["foot"]
		out.append({"id": "foot", "rect": foot_rect(i), "pos": feet[i],
			"push": Vector2(signf(ppos.x - feet[i].x) * 0.6, -1.0).normalized()})
	for w in waves:
		var wx: float = w["x"]
		out.append({"id": "wave", "rect": Rect2(wx - WAVE_HALF, -WAVE_H, WAVE_HALF * 2.0, WAVE_H), "pos": Vector2(wx, -WAVE_H * 0.5),
			"push": Vector2(float(w["dir"]) * 0.45, -1.0).normalized(), "wave": w})
	if atk.get("kind", "") == "swing" and atk["phase"] == "swing":
		var a: int = atk["arm"]
		var sh: Vector2 = SHOULDERS[a]
		var el := elbow_of(a)
		var segs := [[sh, el, 75.0], [el, fists[a], 62.0], [fists[a], fists[a], FIST_R]]
		var best := fists[a]
		var best_d := INF
		for sg in segs:
			var q := _seg_closest(ppos, sg[0], sg[1])
			var d := q.distance_to(ppos) - float(sg[2])
			if d < best_d:
				best_d = d
				best = q
		var th: float = atk["th"]
		var s := 1.0 if a == 1 else -1.0
		var tangent := Vector2(-s * sin(th), cos(th))
		out.append({"id": "arm", "segs": segs, "pos": best, "push": (tangent + Vector2(0, -0.5)).normalized()})
	for b in bolts:
		var bv: Vector2 = b["vel"]
		out.append({"id": "bolt", "pos": b["pos"], "r": BOLT_R, "push": bv.normalized(), "bolt": b})
	return out


static func _seg_closest(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


func overlaps(hb: Dictionary, p: Vector2, r: float) -> bool:
	if hb.has("segs"):
		for sg in hb["segs"]:
			if _seg_closest(p, sg[0], sg[1]).distance_to(p) < r + float(sg[2]):
				return true
		return false
	if hb.has("rect"):
		return not _rect_hit(p, r, hb["rect"]).is_empty()
	var hp: Vector2 = hb["pos"]
	return hp.distance_to(p) < r + float(hb["r"])


func on_parried(hb: Dictionary) -> void:
	match hb["id"]:
		"foot":
			atk["phase"] = "recoil"; atk["t"] = 0.0; atk["from"] = feet[int(atk["foot"])]
		"wave":
			waves.erase(hb["wave"])
		"arm":
			atk["phase"] = "recoil"; atk["t"] = 0.0; atk["th_from"] = atk["th"]
		"bolt":
			bolts.erase(hb["bolt"])


func on_hit_player(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		bolts.erase(hb["bolt"])
	elif hb["id"] == "wave":
		waves.erase(hb["wave"])


func die() -> void:
	dead = true
	death_t = 0.0
	atk = {}
	bolts.clear()
	waves.clear()


# ── 진행 ───────────────────────────────────────────────
func step(dt: float, ppos: Vector2) -> void:
	t += dt
	for i in plate_flash.size():
		plate_flash[i] = maxf(0.0, plate_flash[i] - dt * 4.0)
	for i in 4:
		part_flash[i] = maxf(0.0, part_flash[i] - dt * 4.0)
	_step_debris(dt)
	if dead:
		death_t += dt
		queue_redraw()
		return
	if phase == 2:
		open_t += dt
		if open_t >= OPEN_TIME:
			phase = 3
			events.append({"type": "core_ready", "pos": heart_pos()})
	eye_glow = move_toward(eye_glow, 0.0, dt * 2.0)
	for i in 2:
		cannon_glow[i] = move_toward(cannon_glow[i], 0.0, dt * 2.0)
	_step_bolts(dt)
	_step_waves(dt)
	if atk.is_empty():
		next_t -= dt
		if next_t <= 0.0:
			_choose(ppos)
	else:
		atk["t"] = float(atk["t"]) + dt
		match atk["kind"]:
			"stomp": _step_stomp(dt, ppos)
			"swing": _step_swing(dt, ppos)
			"volley": _step_volley(ppos)
			"burst": _step_burst()
	queue_redraw()


func _finish() -> void:
	atk = {}
	arm_prefer[0] = Vector2(-1.0, 0.35)
	arm_prefer[1] = Vector2(1.0, 0.35)
	if part_alive(2) == false:
		fists[0] = FIST_IDLE[0]
	if part_alive(3) == false:
		fists[1] = FIST_IDLE[1]
	next_t = randf_range(ATTACK_GAP.x, ATTACK_GAP.y)


func _choose(ppos: Vector2) -> void:
	var roll := randf()
	var can_shoot := phase == 3 or part_alive(0) or part_alive(1)
	var arm := _swing_arm(ppos)
	if ppos.y > LOW_ZONE_Y:
		if roll < 0.65 or not can_shoot:
			_start_stomp(ppos)
		elif roll < 0.85:
			atk = {"kind": "volley", "t": 0.0, "shots": 0}
		else:
			atk = {"kind": "burst", "t": 0.0}
	elif arm >= 0 and (roll < 0.5 or not can_shoot):
		atk = {"kind": "swing", "phase": "wind", "t": 0.0, "arm": arm}
		_aim_swing(arm, ppos)
	elif can_shoot:
		if roll < 0.75:
			atk = {"kind": "volley", "t": 0.0, "shots": 0}
		else:
			atk = {"kind": "burst", "t": 0.0}
	else:
		next_t = 0.5
		return
	_setup_origin(ppos)


## 휩쓸 수 있는 팔: 플레이어 쪽 팔 우선, 부서졌거나 닿지 않으면 반대 팔
func _swing_arm(ppos: Vector2) -> int:
	var first := 1 if ppos.x >= 0.0 else 0
	for a in [first, 1 - first]:
		if part_alive(2 + a) and ppos.distance_to(SHOULDERS[a]) < SWING_L + 120.0:
			return a
	return -1


## 탄막 발사점: 페이즈 1은 플레이어에게서 더 먼(살아있는) 포대, 최종 페이즈는 머리
func _setup_origin(ppos: Vector2) -> void:
	var kind: String = atk.get("kind", "")
	if kind != "volley" and kind != "burst":
		return
	var c := -1
	if phase != 3:
		if part_alive(0) and part_alive(1):
			c = 0 if ppos.distance_to(MUZZLES[0]) >= ppos.distance_to(MUZZLES[1]) else 1
		else:
			c = 0 if part_alive(0) else 1
	atk["cannon"] = c
	atk["origin"] = HEAD_POS if c < 0 else MUZZLES[c]
	atk["aim"] = (ppos - atk["origin"]).angle()


func _set_glow(c: int, v: float) -> void:
	if c < 0:
		eye_glow = v
	else:
		cannon_glow[c] = v


func _start_stomp(ppos: Vector2) -> void:
	var i := 1 if ppos.x >= 0.0 else 0
	atk = {"kind": "stomp", "phase": "lift", "t": 0.0, "foot": i, "from": feet[i], "tx": _foot_x(i, ppos.x)}


func _foot_x(i: int, x: float) -> float:
	var rx: float = FOOT_REST[i].x
	return clampf(x, rx - 150.0, rx + 150.0)


func _set_prefer(a: int, th: float, s: float) -> void:
	arm_prefer[a] = -Vector2(-s * sin(th), cos(th))   # 팔꿈치는 휘두르는 방향의 뒤쪽으로 굽는다


## 플레이어 방향을 가운데 두고 SWING_SPAN 만큼 휩쓰는 각도 범위를 정한다 (팔 방향 = (s*cos, sin))
func _aim_swing(a: int, ppos: Vector2) -> void:
	var sh: Vector2 = SHOULDERS[a]
	var s := 1.0 if a == 1 else -1.0
	var d := ppos - sh
	var phi := atan2(d.y, d.x * s)
	var th0 := clampf(phi - SWING_SPAN * 0.5, -3.0, 0.4)
	atk["th0"] = th0
	atk["th1"] = th0 + SWING_SPAN
	atk["th"] = th0


func _arm_fist(a: int, th: float) -> Vector2:
	var s := 1.0 if a == 1 else -1.0
	return SHOULDERS[a] + Vector2(s * cos(th), sin(th)) * SWING_L


func _step_stomp(dt: float, ppos: Vector2) -> void:
	var i: int = atk["foot"]
	var rest_x: float = FOOT_REST[i].x
	var tt: float = atk["t"]
	match atk["phase"]:
		"lift":
			if tt < STOMP_LIFT_TIME * 0.7:
				atk["tx"] = _foot_x(i, ppos.x)
			var k := smoothstep(0.0, 1.0, tt / STOMP_LIFT_TIME)
			var from: Vector2 = atk["from"]
			feet[i] = from.lerp(Vector2(float(atk["tx"]), -STOMP_LIFT_H), k)
			if tt >= STOMP_LIFT_TIME:
				atk["phase"] = "hold"; atk["t"] = 0.0
		"hold":
			feet[i].y = -STOMP_LIFT_H + sin(tt * 60.0) * 4.0
			if tt >= 0.12:
				atk["phase"] = "slam"; atk["t"] = 0.0; atk["from"] = feet[i]
		"slam":
			var k := minf(1.0, tt / STOMP_SLAM_TIME)
			var from: Vector2 = atk["from"]
			feet[i].y = lerpf(from.y, 0.0, k * k)
			if k >= 1.0:
				feet[i].y = 0.0
				var x := feet[i].x
				waves.append({"x": x - 120.0, "dir": -1})
				waves.append({"x": x + 120.0, "dir": 1})
				events.append({"type": "stomp", "pos": Vector2(x, 0)})
				atk["phase"] = "land"; atk["t"] = 0.0
		"land":
			feet[i].x = move_toward(feet[i].x, rest_x, 260.0 * dt)
			if tt >= 0.6:
				_finish()
		"recoil":
			var from: Vector2 = atk["from"]
			feet[i].x = move_toward(feet[i].x, rest_x, 200.0 * dt)
			if tt < 0.25:
				feet[i].y = lerpf(from.y, from.y - 240.0, ease(tt / 0.25, 0.4))
			else:
				var k := minf(1.0, (tt - 0.25) / 0.7)
				feet[i].y = lerpf(from.y - 240.0, 0.0, smoothstep(0.0, 1.0, k))
				if k >= 1.0:
					feet[i] = FOOT_REST[i]
					_finish()


## 팔 전체를 곧게 뻗어 부채꼴로 휩쓰는 큰 공격. 팔 어디에 닿아도 피해 → 패리하거나 돌진(무적)으로 뚫는다
func _step_swing(dt: float, ppos: Vector2) -> void:
	var a: int = atk["arm"]
	var s := 1.0 if a == 1 else -1.0
	var tt: float = atk["t"]
	var th0: float = atk["th0"]
	var th1: float = atk["th1"]
	match atk["phase"]:
		"wind":
			if tt < SWING_WIND * 0.6:
				_aim_swing(a, ppos)                # 처음엔 플레이어를 따라 조준, 이후 고정
			var wind_th := th0 - 0.35 * sin(minf(1.0, tt / SWING_WIND) * PI)   # 휘두르기 전 살짝 뒤로 젖힘
			atk["th"] = wind_th
			fists[a] = fists[a].lerp(_arm_fist(a, wind_th), minf(1.0, dt * 6.0))
			_set_prefer(a, wind_th, s)
			if tt >= SWING_WIND:
				atk["phase"] = "swing"; atk["t"] = 0.0
				events.append({"type": "swing", "pos": fists[a]})
		"swing":
			var k := minf(1.0, tt / SWING_TIME)
			var th := lerpf(th0, th1, k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65)   # 거의 등속, 시작만 살짝 느리게
			atk["th"] = th
			fists[a] = _arm_fist(a, th)
			_set_prefer(a, th, s)
			if k >= 1.0:
				atk["phase"] = "hold"; atk["t"] = 0.0
		"hold":
			if tt >= SWING_HOLD:
				atk["phase"] = "return"; atk["t"] = 0.0
		"recoil":
			var k := minf(1.0, tt / 0.4)
			var th := lerpf(float(atk["th_from"]), th0 - 0.6, ease(k, 0.4))
			atk["th"] = th
			fists[a] = _arm_fist(a, th)
			_set_prefer(a, th, s)
			if k >= 1.0:
				atk["phase"] = "return"; atk["t"] = 0.0
		"return":
			fists[a] = fists[a].lerp(FIST_IDLE[a], minf(1.0, dt * 4.0))
			if tt >= 0.9:
				fists[a] = FIST_IDLE[a]
				_finish()


func _step_volley(ppos: Vector2) -> void:
	var tt: float = atk["t"]
	var c: int = atk["cannon"]
	var org: Vector2 = atk["origin"]
	if tt < VOLLEY_CHARGE:
		_set_glow(c, tt / VOLLEY_CHARGE)
		atk["aim"] = (ppos - org).angle()          # 조준선이 플레이어를 따라간다
		return
	var shots: int = atk["shots"]
	if tt >= VOLLEY_CHARGE + shots * 0.5:
		var base := (ppos - org).angle()
		atk["aim"] = base
		for k in range(-2, 3):
			bolts.append({"pos": org, "vel": Vector2.from_angle(base + k * 0.28) * BOLT_SPEED * bolt_mult(), "life": 8.0, "age": 0.0})
		events.append({"type": "bolt", "pos": org})
		_set_glow(c, 1.0)
		atk["shots"] = shots + 1
		if shots + 1 >= 3:
			_finish()


func _step_burst() -> void:
	var tt: float = atk["t"]
	var c: int = atk["cannon"]
	var org: Vector2 = atk["origin"]
	if tt < BURST_CHARGE:
		_set_glow(c, tt / BURST_CHARGE)
		return
	for i in 18:
		var ang := TAU * i / 18.0 + randf_range(-0.15, 0.15)
		bolts.append({"pos": org, "vel": Vector2.from_angle(ang) * randf_range(220.0, 340.0) * bolt_mult(), "life": 9.0, "age": 0.0})
	events.append({"type": "bolt", "pos": org})
	_set_glow(c, 1.0)
	_finish()


func _step_bolts(dt: float) -> void:
	for b in bolts.duplicate():
		var p: Vector2 = b["pos"]
		var v: Vector2 = b["vel"]
		b["age"] = float(b["age"]) + dt
		p += v * lerpf(0.2, 1.0, minf(1.0, float(b["age"]) / BOLT_WARMUP)) * dt
		b["pos"] = p
		b["life"] = float(b["life"]) - dt
		if b["life"] <= 0.0 or p.y > -6.0 or p.x < -1250.0 or p.x > 1250.0 or p.y < -3400.0:
			bolts.erase(b)
			events.append({"type": "bolt_pop", "pos": p})


func _step_waves(dt: float) -> void:
	for w in waves.duplicate():
		w["x"] = float(w["x"]) + float(w["dir"]) * WAVE_SPEED * dt
		if absf(w["x"]) > 1250.0:
			waves.erase(w)


func _step_debris(dt: float) -> void:
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
		if bool(d["fist"]):
			reach = maxf(reach, absf(half.rotated(rot).y) + FIST_R)
		if p.y + reach >= 0.0:                   # 바닥에 닿으면 그대로 눕는다
			p.y = -reach
			d["rest"] = true
			events.append({"type": "debris_land", "pos": Vector2(p.x, 0)})
		d["pos"] = p
		d["rot"] = rot


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_cloak()
	_draw_legs()
	_draw_torso()
	_draw_chest()
	_draw_arms()
	_draw_head()
	_draw_part_marks()
	_draw_debris()
	_draw_telegraphs()
	_draw_waves()
	_draw_bolts()


func _cap(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	draw_line(a, b, c, w)
	draw_circle(a, w * 0.5, c)
	draw_circle(b, w * 0.5, c)


func _draw_cloak() -> void:
	var sw := sin(t * 0.9) * 18.0
	var pts := PackedVector2Array([
		Vector2(-520, -2380), Vector2(520, -2380), Vector2(640, -1700),
		Vector2(700 + sw, -1000), Vector2(640 + sw, -860), Vector2(560 + sw, -1000), Vector2(470, -880),
		Vector2(380, -1010), Vector2(260, -900), Vector2(120, -1030), Vector2(0, -910),
		Vector2(-120, -1030), Vector2(-260, -900), Vector2(-380, -1010), Vector2(-470, -880),
		Vector2(-560 - sw, -1000), Vector2(-640 - sw, -860), Vector2(-700 - sw, -1000), Vector2(-640, -1700),
	])
	draw_colored_polygon(pts, C_CLOAK)


func _draw_legs() -> void:
	for i in 2:
		var s := 1.0 if i == 1 else -1.0
		var hip: Vector2 = HIPS[i]
		var knee := knee_of(i)
		var ankle := feet[i] + Vector2(0, -100)
		_cap(hip, knee, 170.0, C_BODY)
		_cap(knee, ankle, 140.0, C_BODY)
		draw_line(hip + Vector2(-s * 50, 0), knee + Vector2(-s * 50, 0), Color(C_RIM, 0.45), 4.0)
		draw_circle(knee, 80.0, C_BODY_DARK)
		draw_arc(knee, 80.0, PI * 0.75, PI * 2.25, 24, C_RIM, 5.0)
		var r := foot_rect(i)
		var boot := PackedVector2Array([
			Vector2(r.position.x, r.end.y), Vector2(r.position.x + 8, r.position.y + 45),
			Vector2(r.position.x + 60, r.position.y), Vector2(r.end.x - 60, r.position.y),
			Vector2(r.end.x - 8, r.position.y + 45), Vector2(r.end.x, r.end.y)])
		draw_colored_polygon(boot, C_BODY_DARK)
		draw_polyline(PackedVector2Array([boot[1], boot[2], boot[3], boot[4]]), C_RIM, 4.0)
		draw_line(Vector2(r.position.x, r.end.y - 16), Vector2(r.end.x, r.end.y - 16), Color(C_BONE, 0.4), 3.0)


func _draw_torso() -> void:
	var body := PackedVector2Array([
		Vector2(-470, -2350), Vector2(470, -2350), Vector2(500, -2250), Vector2(400, -1700),
		Vector2(310, -1300), Vector2(-310, -1300), Vector2(-400, -1700), Vector2(-500, -2250)])
	draw_colored_polygon(body, C_BODY)
	draw_polyline(PackedVector2Array([Vector2(-500, -2250), Vector2(-470, -2350), Vector2(470, -2350), Vector2(500, -2250)]), C_RIM, 5.0)
	for y in [-1560.0, -1470.0, -1380.0]:
		draw_line(Vector2(-330, y), Vector2(330, y), C_BODY_DARK, 6.0)
		draw_line(Vector2(-330, y + 6), Vector2(330, y + 6), Color(C_RIM, 0.3), 2.0)
	draw_rect(Rect2(-380, -1300, 760, 280), C_BODY_DARK)
	for x in [-250.0, -125.0, 0.0, 125.0, 250.0]:
		draw_line(Vector2(x, -1290), Vector2(x, -1030), C_BODY, 8.0)
	draw_line(Vector2(-380, -1300), Vector2(380, -1300), C_BONE, 5.0)


## 하트 곡선 (gap = 바깥으로 넓힐 여백)
func _heart_outline(gap: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sc := 14.0 + gap / 16.0
	var c := heart_pos() + Vector2(0, -40)
	for j in 48:
		var u := TAU * j / 48.0
		var x := 16.0 * pow(sin(u), 3)
		var y := -(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u))
		pts.append(c + Vector2(x, y) * sc)
	return pts


## 가슴: 페이즈 1은 닫힌 문, 페이즈 2는 열리는 중, 페이즈 3은 하트 모양 갑옷 코어
func _draw_chest() -> void:
	var open_k := 0.0 if phase == 1 else (1.0 if phase == 3 else clampf(open_t / OPEN_TIME, 0.0, 1.0))
	if open_k > 0.0:
		_draw_grid()
	if open_k >= 1.0:
		return
	var rc := Rect2(GRID_ORIGIN, Vector2(GRID_N, GRID_N) * CELL).grow(26.0)
	var half_w := rc.size.x * 0.5
	var slide := ease(open_k, 2.2) * (half_w + 20.0)
	var alpha := 1.0 - maxf(0.0, open_k - 0.7) / 0.3
	for s in [-1.0, 1.0]:
		var x0: float = rc.position.x + (0.0 if s < 0.0 else half_w) + s * slide
		var door := Rect2(x0, rc.position.y, half_w, rc.size.y)
		draw_rect(door, Color(C_BODY_DARK, alpha))
		draw_rect(door, Color(C_RIM, 0.6 * alpha), false, 4.0)
		for k in 4:
			var y := door.position.y + 50.0 + k * (door.size.y - 100.0) / 3.0
			draw_circle(Vector2(door.position.x + door.size.x * 0.5, y), 7.0, Color(C_RIM, 0.5 * alpha))
	if open_k > 0.0:                            # 열리는 틈새로 새어나오는 빛
		var gap := slide * 2.0
		draw_rect(Rect2(heart_pos().x - gap * 0.5, rc.position.y, gap, rc.size.y), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(0, rc.position.y), Vector2(0, rc.end.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)


func _draw_grid() -> void:
	var hc := heart_pos()
	var beat := 0.5 + 0.5 * sin(t * 5.0)
	draw_colored_polygon(_heart_outline(30.0), C_BODY_DARK)
	var rim := _heart_outline(30.0)
	rim.append(rim[0])
	draw_polyline(rim, Color(C_RIM, 0.6), 4.0)
	var edge_col := Color(1.0, 0.85, 0.5) if strike_glow else C_PLATE_EDGE
	var edge_w := 3.0 if strike_glow else 2.0
	for r in GRID_N:
		for c in GRID_N:
			if not in_mask(c, r):
				continue
			var rc := cell_rect(c, r)
			draw_rect(rc, C_CAVITY)
			if c == HEART_CELL and r == HEART_CELL:
				continue
			var i := r * GRID_N + c
			var hp := plates[i]
			if hp <= 0:
				var near := 1.0 - clampf(rc.get_center().distance_to(hc) / 200.0, 0.0, 1.0)
				draw_rect(rc, Color(0.45, 0.08, 0.06, 0.2 + 0.45 * near * (0.7 + 0.3 * beat)))
				continue
			var ring := maxi(absi(c - HEART_CELL), absi(r - HEART_CELL))
			var maxhp: int = RING_HP[ring]
			var col: Color = PLATE_COL[ring]
			col = col.lerp(col * 0.55, 1.0 - float(hp) / maxhp)
			col = col.lerp(Color.WHITE, plate_flash[i])
			if strike_glow:
				col = col.lerp(Color(1.0, 0.85, 0.5), 0.25)
			var inner := rc.grow(-2.0)
			draw_rect(inner, col)
			draw_rect(inner, edge_col, false, edge_w)
			draw_line(inner.position + Vector2(3, 3), Vector2(inner.end.x - 3, inner.position.y + 3), Color(1, 1, 1, 0.18), 2.0)
			if hp < maxhp:
				var cc := rc.get_center()
				var s := float((i * 37) % 11) - 5.0
				draw_polyline(PackedVector2Array([cc + Vector2(-20, -18 + s), cc + Vector2(-4, -2), cc + Vector2(6, 4 - s), cc + Vector2(20, 16)]), Color(0.15, 0.12, 0.1), 2.0)
				if hp < maxhp - 1:
					draw_polyline(PackedVector2Array([cc + Vector2(16, -20), cc + Vector2(2, 0), cc + Vector2(-14, 20)]), Color(0.15, 0.12, 0.1), 2.0)
	if dead:
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, HEART_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, HEART_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	var pr := HEART_R * (1.0 + 0.12 * beat)
	draw_circle(hc, pr * (2.4 if strike_glow else 1.7), Color(C_HEART, 0.1 + 0.08 * beat + (0.12 if strike_glow else 0.0)))
	draw_circle(hc, pr, C_HEART)
	draw_circle(hc + Vector2(-6, -6), pr * 0.45, Color(1.0, 0.85, 0.6))


func _draw_arms() -> void:
	for a in 2:
		var s := 1.0 if a == 1 else -1.0
		var sh: Vector2 = SHOULDERS[a]
		var el := elbow_of(a)
		_cap(sh, el, 150.0, C_BODY)
		if part_alive(2 + a):
			var f := fists[a]
			_cap(el, f, 125.0, C_BODY)
			draw_circle(el, 70.0, C_BODY_DARK)
			draw_arc(el, 70.0, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
			draw_circle(f, FIST_R, C_BODY_DARK)
			draw_arc(f, FIST_R, -PI * 0.9, -PI * 0.1, 18, C_RIM, 6.0)
			for j in 3:
				var y := f.y - 40.0 + j * 40.0
				draw_line(Vector2(f.x - 55, y), Vector2(f.x + 55, y), Color(C_RIM, 0.35), 3.0)
		else:
			_draw_stump(el, (el - sh).normalized(), 60.0)
		draw_circle(sh, 140.0, C_BODY_DARK)
		draw_arc(sh, 140.0, PI, TAU, 24, Color(C_BONE, 0.8), 7.0)
		# 어깨 포대
		var base := cannon_base(a)
		var mz: Vector2 = MUZZLES[a]
		if part_alive(a):
			_cap(base, mz, 54.0, C_BODY_DARK)
			draw_line(base + Vector2(0, -25), mz + Vector2(0, -22), Color(C_RIM, 0.55), 3.0)
			draw_circle(mz, 34.0, C_BODY)
			draw_arc(mz, 34.0, 0.0, TAU, 20, C_RIM, 4.0)
			var g := cannon_glow[a]
			draw_circle(mz, 18.0 + 22.0 * g, Color(C_EYE, 0.12 + 0.5 * g))
			draw_circle(mz, 9.0 + 6.0 * g, Color(C_EYE, 0.55 + 0.45 * g))
		else:
			var tip := base.lerp(mz, 0.25)
			_cap(base, tip, 54.0, C_BODY_DARK)
			_draw_stump(tip, (mz - base).normalized(), 30.0)


## 부서진 단면: 들쭉날쭉한 끝 + 꺼져가는 불씨
func _draw_stump(p: Vector2, dir: Vector2, r: float) -> void:
	var o := dir.orthogonal()
	var pts := PackedVector2Array([p + o * r, p + dir * r * 0.5 + o * r * 0.5, p + dir * r * 0.2, p + dir * r * 0.7 - o * r * 0.3, p - o * r])
	draw_colored_polygon(pts, C_BODY_DARK)
	draw_circle(p + dir * r * 0.2, r * 0.35, Color(C_HEART, 0.25 + 0.15 * sin(t * 4.0)))


## 페이즈 1 표적: 포대·팔꿈치에 맥동하는 약점 표시 + 남은 내구도 조각
func _draw_part_marks() -> void:
	if phase != 1 or dead:
		return
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	for i in 4:
		if not part_alive(i):
			continue
		var p := part_pos(i)
		var r: float = PART_R[i]
		var core := Color(C_HEART, 0.85).lerp(Color.WHITE, part_flash[i])
		draw_circle(p, r * 0.45 + 4.0 * pulse, Color(C_HEART, 0.18 + 0.12 * pulse + (0.15 if strike_glow else 0.0)))
		draw_circle(p, r * 0.28, core)
		var edge := Color(1.0, 0.85, 0.5, 0.9) if strike_glow else Color(C_PLATE_EDGE, 0.9)
		var seg := TAU / PART_HP
		for k in part_hp[i]:
			draw_arc(p, r + 6.0, -PI * 0.5 + k * seg + 0.08, -PI * 0.5 + (k + 1) * seg - 0.08, 8, edge, 5.0)


func _draw_debris() -> void:
	for d in debris:
		var p: Vector2 = d["pos"]
		var half: Vector2 = d["half"]
		draw_set_transform(p, float(d["rot"]))
		_cap(-half, half, float(d["w"]), C_BODY_DARK)
		if bool(d["fist"]):
			draw_circle(half, FIST_R, C_BODY_DARK)
			draw_arc(half, FIST_R, 0.0, TAU, 18, Color(C_RIM, 0.4), 4.0)
		else:
			draw_circle(half, 34.0, C_BODY)
		draw_circle(-half, float(d["w"]) * 0.35, Color(C_HEART, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_head() -> void:
	for s in [-1.0, 1.0]:
		_cap(Vector2(s * 120, -2740), Vector2(s * 230, -2900), 40.0, C_BONE)
		_cap(Vector2(s * 230, -2900), Vector2(s * 380, -3000), 26.0, C_BONE)
		_cap(Vector2(s * 380, -3000), Vector2(s * 500, -3015), 14.0, C_BONE)
	draw_rect(Rect2(-90, -2400, 180, 80), C_BODY_DARK)
	var helm := PackedVector2Array([
		Vector2(-170, -2380), Vector2(-195, -2600), Vector2(-135, -2745), Vector2(0, -2795),
		Vector2(135, -2745), Vector2(195, -2600), Vector2(170, -2380), Vector2(80, -2335), Vector2(-80, -2335)])
	draw_colored_polygon(helm, C_BODY)
	var rim := helm.duplicate()
	rim.append(helm[0])
	draw_polyline(rim, C_RIM, 5.0)
	draw_line(Vector2(0, -2790), Vector2(0, -2650), Color(C_RIM, 0.5), 4.0)
	draw_rect(Rect2(-125, -2640, 250, 70), Color(0.02, 0.02, 0.03))
	var glow := 0.55 + 0.45 * eye_glow
	if dead:
		glow = maxf(0.0, 0.55 - death_t * 0.4)
	for e in EYES:
		draw_circle(e, 32.0 + eye_glow * 32.0, Color(C_EYE, 0.16 * glow))
		draw_circle(e, 10.0 + eye_glow * 6.0, Color(C_EYE, glow))


func _draw_telegraphs() -> void:
	if atk.get("kind", "") == "stomp" and (atk["phase"] == "lift" or atk["phase"] == "hold"):
		var i: int = atk["foot"]
		var cx := feet[i].x
		var k := clampf(-feet[i].y / STOMP_LIFT_H, 0.0, 1.0)
		var pts := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0
			pts.append(Vector2(cx + cos(a) * 180.0, -4.0 + sin(a) * 14.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45 * k))
		draw_line(Vector2(-1150, -2), Vector2(1150, -2), Color(C_WARN, 0.35 * k), 3.0)
	if atk.get("kind", "") == "volley" and float(atk["t"]) < VOLLEY_CHARGE + 0.5:
		var c: int = atk["cannon"]
		var org: Vector2 = atk["origin"]
		var gl := eye_glow if c < 0 else cannon_glow[c]
		for k in range(-2, 3):                       # 곧 날아올 5갈래 조준선
			var d := Vector2.from_angle(float(atk["aim"]) + k * 0.28)
			draw_line(org, org + d * 900.0, Color(C_WARN, 0.05 + 0.22 * gl), 2.0)
	if atk.get("kind", "") == "swing" and atk["phase"] == "wind":
		# 휩쓸 부채꼴 경고: 이 안에 있으면 팔에 맞는다
		var a: int = atk["arm"]
		var s := 1.0 if a == 1 else -1.0
		var sh: Vector2 = SHOULDERS[a]
		var k := clampf(float(atk["t"]) / SWING_WIND, 0.0, 1.0)
		var locked := float(atk["t"]) >= SWING_WIND * 0.6
		var th0: float = atk["th0"]
		var th1: float = atk["th1"]
		var pts := PackedVector2Array([sh])
		for j in 25:
			var th := lerpf(th0, th1, j / 24.0)
			pts.append(sh + Vector2(s * cos(th), sin(th)) * SWING_L)
		# 시작 쪽이 진하고 끝으로 갈수록 옅은 부채꼴 → 어디서부터 쓸어오는지 보인다
		for j in 24:
			var fa := lerpf(0.26, 0.04, j / 23.0) * (0.35 + 0.65 * k)
			draw_colored_polygon(PackedVector2Array([sh, pts[j + 1], pts[j + 2]]), Color(C_WARN, fa))
		var c := Color(1, 1, 1, 0.9) if locked else Color(C_WARN, 0.35 + 0.5 * k)
		draw_line(sh, pts[1], Color(1.0, 0.85, 0.55, 0.25 + 0.3 * k), 16.0)   # 시작선: 굵고 밝게
		draw_line(sh, pts[1], Color(1.0, 0.95, 0.8, 0.95) if locked else Color(1.0, 0.6, 0.35, 0.6 + 0.4 * k), 7.0)
		draw_line(sh, pts[pts.size() - 1], Color(c, 0.45), 2.0)
		draw_polyline(pts.slice(1), Color(c, 0.7), 3.0)
		for f in [0.3, 0.5, 0.7]:                # 휩쓰는 방향을 가리키는 화살표
			var th2: float = lerpf(th0, th1, f)
			var radial := Vector2(s * cos(th2), sin(th2))
			var tangent := Vector2(-s * sin(th2), cos(th2))
			var at := sh + radial * SWING_L * 0.8
			draw_colored_polygon(PackedVector2Array([at + tangent * 40.0, at - tangent * 12.0 + radial * 26.0, at - tangent * 12.0 - radial * 26.0]), Color(1, 0.9, 0.7, 0.3 + 0.45 * k))


func _draw_waves() -> void:
	for w in waves:
		var x: float = w["x"]
		var d := float(w["dir"])
		var crest := PackedVector2Array([Vector2(x - d * 90, 0), Vector2(x - d * 20, -WAVE_H), Vector2(x + d * 30, -WAVE_H * 0.5), Vector2(x + d * 45, 0)])
		draw_colored_polygon(crest, Color(0.85, 0.85, 0.8, 0.75))
		draw_line(Vector2(x - d * 260, -4), Vector2(x - d * 90, -4), Color(C_WARN, 0.5), 5.0)


func _draw_bolts() -> void:
	for b in bolts:
		var p: Vector2 = b["pos"]
		var v: Vector2 = b["vel"]
		draw_line(p, p - v.normalized() * 50.0, Color(C_EYE, 0.35), 10.0)
		draw_circle(p, BOLT_R * 1.8, Color(C_EYE, 0.2))
		draw_circle(p, BOLT_R, C_EYE)
		draw_circle(p, BOLT_R * 0.5, Color(1, 1, 0.9))

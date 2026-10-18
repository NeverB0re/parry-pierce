extends "res://scripts/colossus_base.gd"
## 콜로서스 ① 관측자 (올라운더, 첫 보스). 정면을 보고 서 있는 거대한 인간형.
## 페이즈: 1) 외부 시스템 파괴 — 좌/우 포대, 좌/우 팔꿈치 관절을 부순다 (가슴은 닫혀 있음)
##         2) 개방 연출 — 가슴이 열린다
##         3) 동력 코어 — 심장 모양 장갑에 싸인 코어. 탄은 머리에서 쏜다
## 공격: 융해 지대 분출(바닥) · 검·방패 휘두르기(요격 가능) · 눈 레이저(패리 불가) · 조준 연사 · 흩뿌리기
## 무기 (v0.80, docs/BOSS_observer.md): 오른손 검, 왼손 탑 방패. 휘두를 때 판정은 무기와 손뿐 (팔은 아니다)
## 체력바는 없다: 외부 시스템·장갑 모두 균열·연기·조각 탈락으로 남은 체력을 보여 준다
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const MeleeWarn := preload("res://scripts/melee_warn.gd")
const Erupt := preload("res://scripts/attacks/erupt.gd")
const Swing := preload("res://scripts/attacks/swing.gd")
const Beam := preload("res://scripts/attacks/beam.gd")
const Volley := preload("res://scripts/attacks/volley.gd")
const Burst := preload("res://scripts/attacks/burst.gd")

# ── 구조 ───────────────────────────────────────────────
const HEART_POS := Vector2(0, -1900)        # 동력 코어 중심 (v0.80: 심장 대신 네모난 금고 속 결정)
const CHEST_RECT := Rect2(-244, -2160, 488, 540)   # 가슴 문 (페이즈 1에 닫혀 있음)
const ARMOR_HP := 160                       # 장갑 체력. 다 부서져도 피해가 코어로 넘어가지 않는다
const CORE_R := 62.0                        # 금고 안 결정 반지름
const VAULT := 190.0                        # 코어 금고 반폭 (가슴 안 네모난 틀)
const CORE_OUTLINE := [Vector2(-190, -190), Vector2(190, -190), Vector2(190, 190), Vector2(-190, 190)]
const PLATE_N := 9                          # 3×3 장갑판
const PLATE_ORDER := [0, 8, 2, 6, 1, 7, 3, 5, 4]   # 떨어지는 순서 (귀퉁이 → 변 → 가운데)

const HIPS := [Vector2(-210, -1020), Vector2(210, -1020)]
const FOOT_REST := [Vector2(-230, 0), Vector2(230, 0)]
const LEG_SEG := 470.0
const SHOULDERS := [Vector2(-470, -2260), Vector2(470, -2260)]
const FIST_IDLE := [Vector2(-600, -1100), Vector2(600, -1100)]
const ARM_SEG := 620.0
const FIST_R := 95.0                 # 손 (판정 반지름)
const SWORD_HAND := 1000.0           # 검을 휘두를 때 어깨~손 (팔을 거의 곧게 뻗는다. 검 끝까지 SWORD_HAND + BLADE_AT + BLADE_L)
const SHIELD_HAND := 1000.0          # 방패를 휘두를 때 어깨~손
const BLADE_AT := 70.0               # 손에서 날밑까지
const BLADE_L := 650.0               # 몸 높이에 맞먹는 대검
const BLADE_W := 52.0                # 날 판정 반폭
const SHIELD_OFF := 80.0             # 손에서 방패 가운데까지 (팔 방향)
const SHIELD_HALF := Vector2(150.0, 330.0)  # 방패 반폭(판정 반폭) · 반길이 (그림 = 판정): 몸통 절반을 가리는 탑 방패
const MUZZLES := [Vector2(-640, -2470), Vector2(640, -2470)]   # 양어깨 포대의 포구
const HEAD_POS := Vector2(0, -2605)                             # 최종 페이즈 탄·레이저 발사점
const EYES := [Vector2(-62, -2605), Vector2(62, -2605)]

# ── 외부 시스템 ────────────────────────────────────────
const PART_HP := 30                         # 0 왼쪽 포대, 1 오른쪽 포대, 2 방패(왼손, 가운데 수정), 3 검(오른손, 손목)
const PART_R := [55.0, 55.0, 80.0, 80.0]
const OPEN_TIME := 1.6                      # 가슴이 열리는 연출 시간

# ── 공격 고르기 ────────────────────────────────────────
const LOW_ZONE_Y := -900.0           # 이보다 아래(융해 지대 근처)면 분출 위주

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.075, 0.08, 0.10)
const C_BODY_DARK := Color(0.045, 0.05, 0.065)
const C_RIM := Color(0.48, 0.52, 0.6)
const C_CLOAK := Color(0.05, 0.045, 0.07)
const C_BONE := Color(0.78, 0.75, 0.68)
const C_EYE := Color(1.0, 0.78, 0.42)
const C_PARRY := Color(1.0, 0.88, 0.35)          # 패리할 수 있는 것 = 금색 (탄, 휩쓰는 팔)
const C_UNPARRY := Color(0.6, 0.08, 0.36)       # 패리 불가 = 검붉은 보라 (회피 돌진으로만 피한다)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var feet: Array[Vector2] = []
var fists: Array[Vector2] = []
var debris: Array[Dictionary] = []   # 부서져 떨어진 부위
var eye_glow := 0.0
var last := ""                       # 직전 패턴 (연달아 같은 것을 덜 고른다)
var beam_glow := 0.0                 # 레이저 직전·중 눈이 보랏빛으로 달아오름
var cannon_glow: Array[float] = [0.0, 0.0]   # 발사 전 포구가 달아오르는 정도
var shield_turn := 0.0               # 방패가 돌아선 정도: 0 = 팔을 따라 세로로 듦, 1 = 팔에 수직 (휘두르는 면)


func _init() -> void:
	open_time = OPEN_TIME
	attack_gap = Vector2(0.5, 0.9)               # 멍때릴 틈 없이 (기본 1.0~1.8 은 길었다)


func _ready() -> void:
	core = ArmoredCore.new(self, HEART_POS, CORE_OUTLINE, ARMOR_HP, Rect2(), 0, 11)   # 불규칙 판 없음 (장갑 = 3×3 판, _draw_core)
	reset()


func reset() -> void:
	super()
	feet.clear()
	feet.append(FOOT_REST[0])
	feet.append(FOOT_REST[1])
	fists.clear()
	fists.append(FIST_IDLE[0])
	fists.append(FIST_IDLE[1])
	debris.clear()
	eye_glow = 0.0
	beam_glow = 0.0
	cannon_glow = [0.0, 0.0]
	shield_turn = 0.0


# ── 외부 시스템 ────────────────────────────────────────
func part_count() -> int:
	return 4


func part_max_hp(_i: int) -> int:
	return PART_HP


func part_radius(i: int) -> float:
	return PART_R[i]


func cannon_base(c: int) -> Vector2:
	var s := 1.0 if c == 1 else -1.0
	return SHOULDERS[c] + Vector2(s * 60.0, -110.0)


func part_pos(i: int) -> Vector2:
	if i < 2:
		return cannon_base(i).lerp(MUZZLES[i], 0.55)
	if i == 2:
		return shield_center()
	return fists[1]


## 표적 테두리: 어깨포 = 포좌 + 포신을 감싼 다각형, 방패 = 가운데 수정 둘레 마름모, 검 = 손목 원 (기본)
func part_outline(i: int) -> PackedVector2Array:
	if i < 2:
		var b := cannon_base(i)
		var mz: Vector2 = MUZZLES[i]
		var d := (mz - b).normalized()
		var n := d.orthogonal()
		var p0 := b - d * 70.0
		var p1 := mz + d * 46.0
		return PackedVector2Array([p0 + n * 62.0, p1 + n * 46.0, p1 - n * 46.0, p0 - n * 62.0])
	if i == 2:
		var c := shield_center()
		var ax := shield_axis()
		var nx := ax.orthogonal()
		return PackedVector2Array([c + ax * 140.0, c + nx * 100.0, c - ax * 140.0, c - nx * 100.0])
	return PackedVector2Array()


# ── 무기 ───────────────────────────────────────────────
## 무기 방향 = 어깨에서 손으로 (검은 이 방향으로 뻗고, 방패는 이 방향 앞에 든다)
func weapon_dir(a: int) -> Vector2:
	return (fists[a] - SHOULDERS[a]).normalized()


func hand_reach(a: int) -> float:
	return SWORD_HAND if a == 1 else SHIELD_HAND


## 방패의 긴 축: 쉴 때는 팔을 따라 세로, 휘두를 때는 팔에 수직으로 돌아선다
func shield_axis(turn := -1.0) -> Vector2:
	var k := shield_turn if turn < 0.0 else turn
	return weapon_dir(0).rotated(PI * 0.5 * k)


func shield_center() -> Vector2:
	return fists[0] + weapon_dir(0) * SHIELD_OFF


func sword_tip() -> Vector2:
	return fists[1] + weapon_dir(1) * (BLADE_AT + BLADE_L)


## 무기 판정 조각 [[a, b, 반폭]]: 손 + 검날 / 손 + 방패 (팔은 판정이 아니다). dir·hand 를 주면 그 자세로
func weapon_segs(a: int, dir := Vector2.ZERO, hand := Vector2.INF, turn := -1.0) -> Array:
	var d := weapon_dir(a) if dir == Vector2.ZERO else dir
	var h: Vector2 = fists[a] if hand == Vector2.INF else hand
	if a == 1:
		return [[h, h, FIST_R], [h + d * BLADE_AT, h + d * (BLADE_AT + BLADE_L), BLADE_W]]
	var k := shield_turn if turn < 0.0 else turn
	var ax := d.rotated(PI * 0.5 * k)
	var c := h + d * SHIELD_OFF
	return [[h, h, FIST_R], [c - ax * SHIELD_HALF.y, c + ax * SHIELD_HALF.y, SHIELD_HALF.x]]


## 휘두를 때 닿는 가장 먼 거리 (어깨 기준)
func swing_reach(a: int) -> float:
	var d := Vector2.RIGHT
	var r := 0.0
	for sg in weapon_segs(a, d, SHOULDERS[a] + d * hand_reach(a), 1.0):
		for q in [sg[0], sg[1]]:
			r = maxf(r, (q - SHOULDERS[a]).length() + float(sg[2]))
	return r


# ── 몸 ─────────────────────────────────────────────────
func foot_rect(i: int) -> Rect2:
	var f := feet[i]
	return Rect2(f.x - 130.0, f.y - 110.0, 260.0, 110.0)


func knee_of(i: int) -> Vector2:
	var ankle := feet[i] + Vector2(0, -100)
	return _joint(HIPS[i], ankle, LEG_SEG, Vector2(1.0 if i == 1 else -1.0, 0))


func _swing_of(a: int):
	if atk is Swing and atk.arm == a:
		return atk
	return null


func elbow_of(a: int) -> Vector2:
	var bent := _arm_bent(a)
	var sw = _swing_of(a)
	if sw == null:
		return bent
	var sh: Vector2 = SHOULDERS[a]                       # 휘두르는 동안은 팔을 거의 곧게 편다 (팔꿈치가 꺾여 튀지 않게)
	var d := fists[a] - sh
	var straight: Vector2 = sh + d * 0.5 + d.orthogonal().normalized() * (60.0 if a == 1 else -60.0)
	match sw.phase:
		"prep":
			return bent.lerp(straight, minf(1.0, sw.t / 0.3))
		"return":
			return straight.lerp(bent, minf(1.0, sw.t / 0.4))
	return straight


## 팔꿈치: 항상 팔 진행 방향의 같은 쪽(바깥)으로 굽힌다 → 팔이 돌아도 관절이 반대편으로 튀지 않는다
func _arm_bent(a: int) -> Vector2:
	var sh: Vector2 = SHOULDERS[a]
	var d := fists[a] - sh
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, ARM_SEG * ARM_SEG - half * half))
	var perp := d.orthogonal().normalized() * (1.0 if a == 1 else -1.0)
	return sh + d * 0.5 + perp * h


func is_staggered(a: int) -> bool:
	var sw = _swing_of(a)
	return sw != null and sw.phase == "stagger"


## 두 마디 관절 위치. prefer 쪽으로 굽힌다.
static func _joint(a: Vector2, b: Vector2, seg: float, prefer: Vector2) -> Vector2:
	var d := b - a
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, seg * seg - half * half))
	var perp := d.orthogonal().normalized()
	if perp.dot(prefer) < 0.0:
		perp = -perp
	return (a + b) * 0.5 + perp * h


## 휘두르는 무기 판정 상자 (손 + 검날 / 손 + 방패). pos = ppos 에 가장 가까운 지점
func arm_box(a: int, ppos: Vector2) -> Dictionary:
	var segs := weapon_segs(a)
	var best := fists[a]
	var best_d := INF
	for sg in segs:
		var q := seg_closest(ppos, sg[0], sg[1])
		var d := q.distance_to(ppos) - float(sg[2])
		if d < best_d:
			best_d = d
			best = q
	return {"id": "arm", "segs": segs, "pos": best}


# ── 진행 ───────────────────────────────────────────────
## 부서진 부위가 떨어져 나간다 (포대 / 팔꿈치 아래 팔)
func _on_part_broken(i: int) -> void:
	var s := 1.0 if i % 2 == 1 else -1.0
	if i < 2:
		var base := cannon_base(i)
		var mz: Vector2 = MUZZLES[i]
		debris.append({"pos": (base + mz) * 0.5, "half": (mz - base) * 0.5, "w": 54.0, "fist": false,
			"vel": Vector2(s * 260.0, -380.0), "rot": 0.0, "rotv": s * 3.5, "rest": false})
	elif i == 3:                                    # 검날이 부러져 떨어진다 (손잡이와 짧은 그루터기만 남는다)
		var d := weapon_dir(1)
		var p0 := fists[1] + d * (BLADE_AT + 140.0)
		var p1 := sword_tip()
		debris.append({"pos": (p0 + p1) * 0.5, "half": (p1 - p0) * 0.5, "w": BLADE_W * 2.0, "fist": false,
			"vel": Vector2(s * 200.0, -300.0), "rot": 0.0, "rotv": s * 2.6, "rest": false})
	else:                                           # 방패 아래쪽 절반이 깨져 떨어진다
		var c := shield_center()
		var ax := shield_axis()
		debris.append({"pos": c + ax * SHIELD_HALF.y * 0.5, "half": ax * SHIELD_HALF.y * 0.5, "w": SHIELD_HALF.x * 2.0, "fist": false,
			"vel": Vector2(s * 220.0, -260.0), "rot": 0.0, "rotv": s * 2.0, "rest": false})


func _part_highlight(i: int) -> bool:
	return i >= 2 and is_staggered(i - 2)


func _step_effects(dt: float) -> void:
	_step_debris(dt)


func _step_phase(dt: float) -> void:
	eye_glow = move_toward(eye_glow, 0.0, dt * 2.0)
	beam_glow = move_toward(beam_glow, 0.0, dt * 2.0)
	for i in 2:
		cannon_glow[i] = move_toward(cannon_glow[i], 0.0, dt * 2.0)
	var sw0 = _swing_of(0)                              # 방패는 휘두를 자세를 잡으며 돌아선다
	var turn_to := 1.0 if sw0 != null and sw0.phase != "return" else 0.0
	shield_turn = move_toward(shield_turn, turn_to, dt * 2.5)
	if sw0 != null and (sw0.phase == "set" or sw0.phase == "warn" or sw0.phase == "swing"):
		shield_turn = 1.0                               # 판정이 있는 동안은 예고 범위와 같은 자세


func _on_attack_finished() -> void:
	if part_alive(2) == false:
		fists[0] = FIST_IDLE[0]
	if part_alive(3) == false:
		fists[1] = FIST_IDLE[1]


## 구역 가중치로 고른다: 낮은 곳 = 분출, 팔이 닿는 곳 = 휩쓸기, 그 밖 = 포대 사격. 레이저는 드물게.
## 휩쓸기(근접)는 날아오는 탄이 걷힌 뒤에만 (탄막과 겹치지 않게). 조준 연사가 관측자의 시그니처(겨누는 사격)
func _choose(ppos: Vector2) -> void:
	var can_shoot := phase == 3 or part_alive(0) or part_alive(1)
	var arm := _swing_arm(ppos)
	var low := ppos.y > LOW_ZONE_Y
	var w := {"erupt": 2.5 if low else 0.5, "beam": 0.6}
	if arm >= 0 and shots_clear(ppos):
		w["swing"] = 2.2
	if can_shoot:
		w["volley"] = 1.6 if not low else 0.6
		w["burst"] = 0.8
	var kind := weighted_pick(w, last)
	last = kind
	match kind:
		"erupt":
			start_attack(Erupt.new(ppos))
		"beam":
			start_attack(Beam.new(HEAD_POS))
		"swing":
			var sw := Swing.new(arm, 2 + arm, fists[arm])
			start_attack(sw)
			sw.aim_at(ppos)
		_:
			var c := _shooter(ppos)
			var org: Vector2 = HEAD_POS if c < 0 else MUZZLES[c]
			start_attack(Volley.new(c, org, ppos) if kind == "volley" else Burst.new(c, org))


## 휩쓸 수 있는 팔: 플레이어 쪽 팔 우선, 부서졌거나 닿지 않으면 반대 팔
func _swing_arm(ppos: Vector2) -> int:
	var first := 1 if ppos.x >= 0.0 else 0
	for a in [first, 1 - first]:
		if part_alive(2 + a) and ppos.distance_to(SHOULDERS[a]) < swing_reach(a) + 120.0:
			return a
	return -1


## 탄 발사점: 페이즈 1은 플레이어에게서 더 먼(살아있는) 포대, 최종 페이즈는 머리(-1)
func _shooter(ppos: Vector2) -> int:
	if phase == 3:
		return -1
	if part_alive(0) and part_alive(1):
		return 0 if ppos.distance_to(MUZZLES[0]) >= ppos.distance_to(MUZZLES[1]) else 1
	return 0 if part_alive(0) else 1


## 발사 전 발광: -1 = 눈, 0·1 = 포구
func set_glow(c: int, v: float) -> void:
	if c < 0:
		eye_glow = v
	else:
		cannon_glow[c] = v


func glow_of(c: int) -> float:
	return eye_glow if c < 0 else cannon_glow[c]


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
		if p.y + reach >= 0.0:                   # 바닥에 닿으면 그대로 눕는다
			p.y = -reach
			d["rest"] = true
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))
		d["pos"] = p
		d["rot"] = rot


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_halo()
	_draw_vents()
	_draw_cloak()
	_draw_legs()
	_draw_torso()
	_draw_seams()
	_draw_chest()
	_draw_arms()
	_draw_head()
	_draw_part_marks()
	_draw_gauge()
	_draw_debris()
	_draw_shards()
	if atk != null:
		atk.draw()
	shots.draw(self)


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
	var hem := PackedVector2Array()                                     # 찢어진 끝단: 호박빛으로 달아오른 실밥
	for k in range(3, pts.size() - 1):
		hem.append(pts[k])
	draw_polyline(hem, Color(C_EYE, 0.22 + 0.12 * sin(t * 2.0)), 4.0)
	for k in 6:                                                         # 망토 주름
		var x := -500.0 + k * 200.0
		draw_line(Vector2(x * 0.8, -2300), Vector2(x + sw * 0.5, -1080), Color(0.02, 0.02, 0.04, 0.6), 10.0)


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


## 가슴: 페이즈 1은 닫힌 문, 페이즈 2는 열리는 중, 페이즈 3은 장갑판에 싸인 동력 코어
func _draw_chest() -> void:
	var open_k := 0.0 if phase == 1 else (1.0 if phase == 3 else clampf(open_t / OPEN_TIME, 0.0, 1.0))
	if open_k > 0.0:
		_draw_core()
	if open_k >= 1.0:
		return
	var rc := CHEST_RECT
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
		draw_rect(Rect2(HEART_POS.x - gap * 0.5, rc.position.y, gap, rc.size.y), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(0, rc.position.y), Vector2(0, rc.end.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)


## 동력 코어 (v0.80, 심장 대신): 가슴 속 네모난 금고 — 각진 틀 + 네 귀퉁이 버팀대가 붙든 호박빛 결정(육각, 면 분할) +
## 그 위를 덮은 3×3 장갑판 (체력이 깎일수록 정해진 순서로 한 장씩 떨어져 그 자리로 결정 빛이 샌다). 직선만.
## 장갑이 다 떨어지면 결정만 남아 깜빡인다 (한 대면 터진다)
func _draw_core() -> void:
	var hc := HEART_POS
	if dead:
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (4.5 + f * 5.0))          # 많이 부서질수록 빨리 뛴다
	var vault := Rect2(hc - Vector2(VAULT, VAULT), Vector2(VAULT, VAULT) * 2.0)
	draw_rect(vault.grow(24.0), C_BODY_DARK)
	draw_rect(vault.grow(24.0), Color(C_RIM, 0.7), false, 5.0)
	draw_rect(vault, Color(0.06, 0.04, 0.03).lerp(Color(0.25, 0.13, 0.04), (0.3 + 0.3 * beat) * (0.4 + 0.6 * f)))   # 안쪽: 결정 빛이 번진다
	for k in 4:                                                        # 버팀대 (귀퉁이 → 결정)
		var a := PI * 0.25 + k * PI * 0.5
		draw_line(hc + Vector2.from_angle(a) * VAULT * 1.35, hc + Vector2.from_angle(a) * 70.0, C_BODY, 22.0)
		draw_line(hc + Vector2.from_angle(a) * VAULT * 1.35, hc + Vector2.from_angle(a) * 70.0, Color(C_RIM, 0.35), 3.0)
	if core.broken:                                                    # 장갑이 다 떨어짐: 한 대면 터지는 결정만
		_draw_exposed_core(hc, CORE_R, C_HEART)
	else:
		var gem := PackedVector2Array()                                # 육각 결정 + 면 분할
		for q in 6:
			gem.append(hc + Vector2.from_angle(q * TAU / 6.0 + PI / 6.0) * CORE_R * (1.0 + 0.05 * beat))
		var gc := C_EYE.lerp(Color.WHITE, 0.2 + core.flash * 0.6)
		draw_circle(hc, CORE_R * 1.8, Color(C_EYE, 0.12 + 0.08 * beat))
		draw_colored_polygon(gem, gc)
		for q in 6:
			draw_line(hc, gem[q], Color(0.6, 0.35, 0.1, 0.7), 2.0)
		draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -CORE_R * 0.45), hc + Vector2(CORE_R * 0.4, 0), hc + Vector2(0, CORE_R * 0.45), hc + Vector2(-CORE_R * 0.4, 0)]), Color(1.0, 0.97, 0.88))
	var left := plates_left()
	var cell := VAULT * 2.0 / 3.0
	for n in range(PLATE_N - left, PLATE_N):                           # 남은 장갑판: 어두운 강철 + 위 모서리 빛 + 리벳 + 가운데 홈
		var r := _plate_rect(PLATE_ORDER[n])
		draw_rect(r, C_BODY.lerp(Color(0.2, 0.21, 0.25), 0.6).lerp(Color.WHITE, core.flash * 0.25))
		draw_line(r.position, Vector2(r.end.x, r.position.y), Color(C_RIM, 0.8), 3.0)
		draw_line(Vector2(r.position.x, r.end.y), r.end, C_BODY_DARK, 4.0)
		for q in 4:
			var cp := r.position + Vector2(16.0 if q % 2 == 0 else r.size.x - 16.0, 16.0 if q < 2 else r.size.y - 16.0)
			draw_rect(Rect2(cp - Vector2(5, 5), Vector2(10, 10)), Color(C_RIM, 0.55))
		draw_line(r.get_center() - Vector2(cell * 0.22, 0), r.get_center() + Vector2(cell * 0.22, 0), C_BODY_DARK, 6.0)
	var smoke := int(f * 6.0)                                          # 연기: 손상이 클수록 많이
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -140.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if focus_glow > 0.0:                           # 방향 지정·차지 중: 노릴 수 있는 표적 강조
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, 270.0, 0.0, TAU, 48, Color(C_TARGET, focus_glow * (0.6 if in_reach else 0.25)), 4.0)


## 장갑판 k (0~8, 3×3 격자의 칸 번호)
func _plate_rect(k: int) -> Rect2:
	var cell := VAULT * 2.0 / 3.0
	var org := HEART_POS - Vector2(VAULT, VAULT)
	return Rect2(org + Vector2(k % 3, k / 3) * cell + Vector2(4, 4), Vector2(cell, cell) - Vector2(8, 8))


## 남은 장갑판 수 (장갑 체력 비례)
func plates_left() -> int:
	if core.broken:
		return 0
	return int(ceil(float(core.armor_hp) / ARMOR_HP * PLATE_N - 0.001))


## 코어 피해: 깎인 만큼 장갑판이 그 모양 그대로 튀어 떨어진다
func damage_core(dmg: int) -> bool:
	var before := plates_left()
	var broke := super(dmg)
	var after := plates_left()
	for n in range(PLATE_N - before, PLATE_N - after):
		var r := _plate_rect(PLATE_ORDER[n])
		var c := r.get_center()
		var h := r.size * 0.5
		var out := (c - HEART_POS).normalized() if c.distance_to(HEART_POS) > 1.0 else Vector2.UP
		shards.append({"pos": c, "vel": out * randf_range(300.0, 480.0) + Vector2(0, -300), "rot": 0.0, "rotv": randf_range(-4.0, 4.0),
			"pts": PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])})
	return broke


func _draw_arms() -> void:
	for a in 2:
		var sh: Vector2 = SHOULDERS[a]
		var el := elbow_of(a)
		var f := fists[a]
		var sw = _swing_of(a)
		if sw == null and not dead:                    # 대기 모션: 손이 들썩인다 (그림만, 판정은 그대로)
			f += Vector2(sin(t * 1.3 + a * 2.1) * 16.0, cos(t * 1.1 + a * 1.3) * 22.0)
		var hot := 0.0                                 # 판정이 있는(또는 곧 생길) 무기: 진홍으로 달아오른다 (근접 경고색)
		if sw != null:
			match sw.phase:
				"warn":
					hot = 0.5 + 0.5 * sin(t * 18.0)
				"swing":
					hot = 1.0
				"set":
					hot = 0.35
		_cap(sh, el, 150.0, C_BODY)
		_cap(el, f, 125.0, C_BODY)
		draw_circle(el, 70.0, C_BODY_DARK)
		draw_arc(el, 70.0, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
		if a == 1:
			_draw_sword(f, (f - sh).normalized(), hot)
		_draw_hand(f)
		if a == 0:
			_draw_shield(f, (f - sh).normalized(), hot)
		draw_circle(sh, 140.0, C_BODY_DARK)
		draw_arc(sh, 140.0, PI, TAU, 24, Color(C_BONE, 0.8), 7.0)
		var so := 1.0 if a == 1 else -1.0
		for q in 3:                                                     # 어깨 뼈 가시
			var base_a := PI + 0.5 + q * 0.55 if so < 0.0 else TAU - 0.5 - q * 0.55
			var bp := sh + Vector2.from_angle(base_a) * 130.0
			_cap(bp, bp + Vector2.from_angle(base_a) * (90.0 + 30.0 * (1 - q % 2)) + Vector2(0, -40), 16.0, C_BONE)
		_draw_cannon(a)


## 장갑 손: 팔각 손등 판 + 손가락 마디 줄
func _draw_hand(f: Vector2) -> void:
	var pts := PackedVector2Array()
	for q in 8:
		pts.append(f + Vector2.from_angle(PI / 8.0 + q * TAU / 8.0) * FIST_R)
	draw_colored_polygon(pts, C_BODY_DARK)
	var ol := pts.duplicate()
	ol.append(pts[0])
	draw_polyline(ol, Color(C_RIM, 0.55), 4.0)
	for j in 3:
		var y := f.y - 30.0 + j * 30.0
		draw_line(Vector2(f.x - 45, y), Vector2(f.x + 45, y), Color(C_RIM, 0.3), 3.0)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## 장검 (오른손): 날밑 + 곧은 날(끝만 깎은 직선) + 가운데 홈. 휘두를 때 날 테두리가 진홍으로 달아오른다.
## 부서지면 날밑 위로 짧은 그루터기만 남는다
func _draw_sword(f: Vector2, d: Vector2, hot: float) -> void:
	var n := d.orthogonal()
	var g := f + d * BLADE_AT
	var alive := part_alive(3)
	var tip := g + d * (BLADE_L if alive else 150.0)
	draw_line(f - d * 90.0, g, C_BODY_DARK, 40.0)                                   # 손잡이
	draw_colored_polygon(PackedVector2Array([f - d * 125.0, f - d * 95.0 + n * 30.0, f - d * 65.0, f - d * 95.0 - n * 30.0]), C_BONE)   # 자루 끝
	var blade: PackedVector2Array
	var edge_end: Vector2
	if alive:
		blade = PackedVector2Array([g + n * BLADE_W, tip - d * 120.0 + n * BLADE_W * 0.85, tip, tip - d * 120.0 - n * BLADE_W * 0.85, g - n * BLADE_W])
		edge_end = tip - d * 120.0 + n * BLADE_W * 0.75
	else:
		blade = PackedVector2Array([g + n * BLADE_W, tip + n * BLADE_W * 0.9, tip - d * 30.0 + n * 6.0, tip + d * 10.0 - n * 12.0, tip - n * BLADE_W * 0.9, g - n * BLADE_W])
		edge_end = tip + n * BLADE_W * 0.8
	if hot > 0.0:
		draw_polyline(_closed(blade), Color(MeleeWarn.C, 0.25 * hot), 22.0)
	draw_colored_polygon(blade, Color(0.3, 0.32, 0.38).lerp(MeleeWarn.C, 0.25 * hot))
	draw_line(g + n * BLADE_W * 0.85, edge_end, Color(0.75, 0.8, 0.88, 0.9), 4.0)   # 빛 받는 날
	draw_line(g + d * 30.0, tip - d * (140.0 if alive else 40.0), Color(0.12, 0.13, 0.16), 8.0)   # 가운데 홈
	if hot > 0.0:
		draw_polyline(_closed(blade), Color(MeleeWarn.C, 0.5 + 0.5 * hot), 5.0)
	if not alive:
		draw_circle(tip, 10.0, Color(C_HEART, 0.3 + 0.15 * sin(t * 4.0)))
	var gp := PackedVector2Array([g + n * 150.0 - d * 20.0, g + n * 150.0 + d * 20.0, g - n * 150.0 + d * 20.0, g - n * 150.0 - d * 20.0])   # 날밑
	draw_colored_polygon(gp, C_BODY_DARK)
	draw_polyline(_closed(gp), Color(C_BONE, 0.7), 4.0)


## 탑 방패 (왼손): 모서리를 깎은 직사각 판 + 안쪽 판 + 가로 띠 + 가운데 수정(동심원 발사점).
## 휘두를 때 테두리가 진홍으로 달아오른다. 부서지면 손 쪽 절반만 남는다 (깨진 단면)
func _draw_shield(f: Vector2, d: Vector2, hot: float) -> void:
	var ax := d.rotated(PI * 0.5 * shield_turn)
	var nx := ax.orthogonal()
	var c := f + d * SHIELD_OFF
	var hl := SHIELD_HALF.y
	var hw := SHIELD_HALF.x
	var ch := 60.0
	var alive := part_alive(2)
	if not alive:                                                      # 깨지면 손 쪽 절반이 남는다 (먼 쪽 절반은 떨어졌다)
		ax = -ax
		nx = -nx
	var outer: PackedVector2Array
	if alive:
		outer = PackedVector2Array([
			c + ax * hl + nx * (hw - ch), c + ax * (hl - ch) + nx * hw, c - ax * (hl - ch) + nx * hw, c - ax * hl + nx * (hw - ch),
			c - ax * hl - nx * (hw - ch), c - ax * (hl - ch) - nx * hw, c + ax * (hl - ch) - nx * hw, c + ax * hl - nx * (hw - ch)])
	else:
		outer = PackedVector2Array([
			c + ax * hl + nx * (hw - ch), c + ax * (hl - ch) + nx * hw, c + ax * 20.0 + nx * hw, c - ax * 30.0 + nx * hw * 0.3,
			c + ax * 10.0 - nx * hw * 0.2, c - ax * 25.0 - nx * hw, c + ax * (hl - ch) - nx * hw, c + ax * hl - nx * (hw - ch)])
	if hot > 0.0:
		draw_polyline(_closed(outer), Color(MeleeWarn.C, 0.25 * hot), 24.0)
	draw_colored_polygon(outer, C_BODY_DARK.lerp(MeleeWarn.C, 0.15 * hot))
	var inner := PackedVector2Array()
	for q in outer:
		inner.append(c + (q - c) * 0.8)
	draw_colored_polygon(inner, C_BODY)
	draw_polyline(_closed(outer), Color(MeleeWarn.C, 0.5 + 0.5 * hot) if hot > 0.0 else Color(C_RIM, 0.75), 5.0)
	for k in [-0.55, 0.55]:                                            # 가로 띠
		if not alive and k < 0.0:
			continue
		var y: Vector2 = c + ax * hl * k
		draw_line(y + nx * hw * 0.8, y - nx * hw * 0.8, C_BODY_DARK, 12.0)
		draw_line(y + nx * hw * 0.8 + ax * 7.0, y - nx * hw * 0.8 + ax * 7.0, Color(C_RIM, 0.3), 2.0)
	if alive:                                                          # 가운데 수정
		var cr := PackedVector2Array([c + ax * 100.0, c + nx * 66.0, c - ax * 100.0, c - nx * 66.0])
		draw_colored_polygon(cr, C_UNPARRY.darkened(0.4))
		draw_colored_polygon(PackedVector2Array([c + ax * 48.0, c + nx * 30.0, c - ax * 48.0, c - nx * 30.0]), Color(C_UNPARRY_CORE, 0.35 + 0.15 * sin(t * 1.6)))
		draw_polyline(_closed(cr), Color(C_BONE, 0.6), 3.0)
	else:
		draw_circle(c, 12.0, Color(C_HEART, 0.3 + 0.15 * sin(t * 4.0)))


## 어깨포: 각진 포좌 상자 + 곧은 포신 + 포구 제퇴기 (직선). 부서지면 포좌만 남고 그을린다
func _draw_cannon(a: int) -> void:
	var b := cannon_base(a)
	var mz: Vector2 = MUZZLES[a]
	var d := (mz - b).normalized()
	var n := d.orthogonal()
	var box := PackedVector2Array([b - d * 64.0 + n * 58.0, b + d * 30.0 + n * 58.0, b + d * 30.0 - n * 58.0, b - d * 64.0 - n * 58.0])
	draw_colored_polygon(box, C_BODY_DARK)
	draw_polyline(_closed(box), Color(C_RIM, 0.6), 4.0)
	if part_alive(a):
		var bar := PackedVector2Array([b + d * 30.0 + n * 24.0, mz - d * 18.0 + n * 24.0, mz - d * 18.0 - n * 24.0, b + d * 30.0 - n * 24.0])
		draw_colored_polygon(bar, C_BODY)
		draw_line(b + d * 30.0 + n * 18.0, mz - d * 18.0 + n * 18.0, Color(C_RIM, 0.5), 3.0)
		var brake := PackedVector2Array([mz - d * 22.0 + n * 36.0, mz + d * 20.0 + n * 36.0, mz + d * 20.0 - n * 36.0, mz - d * 22.0 - n * 36.0])
		draw_colored_polygon(brake, C_BODY_DARK)
		draw_polyline(_closed(brake), Color(C_RIM, 0.7), 3.0)
		var g := cannon_glow[a]
		draw_circle(mz + d * 20.0, 18.0 + 22.0 * g, Color(C_EYE, 0.12 + 0.5 * g))
		draw_circle(mz + d * 20.0, 8.0 + 6.0 * g, Color(C_EYE, 0.55 + 0.45 * g))
	else:
		_draw_stump(b + d * 40.0, d, 30.0)


## 부서진 단면: 들쭉날쭉한 끝 + 꺼져가는 불씨
func _draw_stump(p: Vector2, dir: Vector2, r: float) -> void:
	var o := dir.orthogonal()
	var pts := PackedVector2Array([p + o * r, p + dir * r * 0.5 + o * r * 0.5, p + dir * r * 0.2, p + dir * r * 0.7 - o * r * 0.3, p - o * r])
	draw_colored_polygon(pts, C_BODY_DARK)
	draw_circle(p + dir * r * 0.2, r * 0.35, Color(C_HEART, 0.25 + 0.15 * sin(t * 4.0)))


func _draw_debris() -> void:
	for d in debris:
		var p: Vector2 = d["pos"]
		var half: Vector2 = d["half"]
		draw_set_transform(p, float(d["rot"]))
		var hn := half.orthogonal().normalized() * float(d["w"]) * 0.5
		draw_colored_polygon(PackedVector2Array([-half + hn, half + hn, half - hn, -half - hn]), C_BODY_DARK)
		draw_polyline(PackedVector2Array([-half + hn, half + hn, half - hn, -half - hn, -half + hn]), Color(C_RIM, 0.4), 3.0)
		draw_circle(-half, float(d["w"]) * 0.35, Color(C_HEART, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0)


## 감시 후광 (관측자의 상징, 그림만): 머리 뒤에 걸린 거대한 렌즈 고리. 렌즈들이 차례로 깜빡이며 돌고,
## 플레이어 쪽 렌즈가 가장 밝게 빛나 늘 지켜보는 느낌. 뒤로 옅은 호박빛 후광과 가는 주사선
func _draw_halo() -> void:
	var c := HEAD_POS + Vector2(0, 120)
	var dim := 1.0 if not dead else maxf(0.0, 1.0 - death_t * 0.6)
	_soft_glow(c, 1450.0, C_EYE, 0.12 * dim)
	var r := 860.0
	draw_arc(c, r, 0.0, TAU, 96, C_BODY_DARK, 46.0)                    # 고리 몸통
	draw_arc(c, r + 23.0, 0.0, TAU, 96, Color(C_RIM, 0.35), 3.0)
	draw_arc(c, r - 23.0, 0.0, TAU, 96, Color(C_RIM, 0.2), 2.0)
	for k in 6:                                                         # 고리를 받치는 지지대 (몸 뒤로 사라진다)
		var a := k * TAU / 6.0 + PI / 6.0
		draw_line(c + Vector2.from_angle(a) * 380.0, c + Vector2.from_angle(a) * (r - 20.0), Color(C_BODY_DARK, 0.9), 22.0)
	var to_p := (look_at - c).angle()
	for k in 16:                                                        # 렌즈 16개: 천천히 돌며 차례로 깜빡, 플레이어 쪽이 가장 밝다
		var a := k * TAU / 16.0 + t * 0.06
		var p := c + Vector2.from_angle(a) * r
		var seq := 0.5 + 0.5 * sin(t * 2.2 - k * 0.8)
		var watch := maxf(0.0, cos(angle_difference(a, to_p))) ** 6
		var g := (0.25 + 0.45 * seq + 0.6 * watch) * dim
		draw_circle(p, 34.0, C_BODY)
		draw_arc(p, 34.0, 0.0, TAU, 16, Color(C_RIM, 0.55), 3.0)
		draw_circle(p, 14.0 + 8.0 * watch, Color(C_EYE, minf(1.0, g)))
		if watch > 0.3:
			draw_circle(p, 48.0 + 30.0 * watch, Color(C_EYE, 0.12 * watch * dim))
	var sweep := fmod(t * 0.25, 1.0) * TAU                              # 주사선: 고리 안을 천천히 훑는다
	draw_line(c, c + Vector2.from_angle(sweep) * r, Color(C_EYE, 0.06 * dim), 10.0)


## 몸통의 빛나는 이음매와 테두리 빛 (그림만): 가슴 둘레 갈비뼈 판 + 맥동하는 호박빛 선 + 왼쪽 위에서 오는 푸른 테두리 빛
func _draw_seams() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 1.8)
	var lit := 1.0 if not dead else 0.2
	for k in 4:                                                         # 갈비뼈 판 (가슴 문 양옆)
		var y := -2180.0 + k * 150.0
		for s in [-1.0, 1.0]:
			var a := Vector2(s * 190.0, y)
			var b := Vector2(s * (430.0 - k * 22.0), y + 70.0)
			draw_line(a, b, C_BODY_DARK, 26.0)
			draw_line(a + Vector2(0, -10), b + Vector2(0, -10), Color(C_RIM, 0.35), 3.0)
			draw_line(a + Vector2(0, 9), b + Vector2(0, 9), Color(C_EYE, (0.25 + 0.3 * pulse) * lit), 2.5)
	for s in [-1.0, 1.0]:                                               # 옆구리 호박빛 이음매
		draw_polyline(PackedVector2Array([Vector2(s * 470, -2330), Vector2(s * 455, -2000), Vector2(s * 390, -1700), Vector2(s * 300, -1320)]),
			Color(C_EYE, (0.18 + 0.25 * pulse) * lit), 4.0)
	draw_polyline(PackedVector2Array([Vector2(-500, -2250), Vector2(-400, -1700), Vector2(-310, -1300)]), Color(0.6, 0.75, 1.0, 0.35), 5.0)   # 테두리 빛 (왼쪽)
	for i in 2:
		var hip: Vector2 = HIPS[i]
		var knee := knee_of(i)
		draw_line(hip + Vector2(-80, 0), knee + Vector2(-70, 0), Color(0.6, 0.75, 1.0, 0.25), 4.0)


## 어깨 배기구에서 주기적으로 증기가 뿜어져 오른다 (대기 모션)
func _draw_vents() -> void:
	if dead:
		return
	for s in [-1.0, 1.0]:
		var o := Vector2(s * 330.0, -2370.0)
		for k in 5:
			var life := fmod(t * 0.45 + k * 0.2 + (0.5 if s > 0.0 else 0.0), 1.0)
			var p := o + Vector2(s * (20.0 + life * 70.0) + sin(t * 2.0 + k) * 12.0, -life * 260.0)
			draw_circle(p, 18.0 + life * 46.0, Color(0.55, 0.58, 0.62, 0.22 * (1.0 - life)))


## 머리: 플레이어 쪽으로 천천히 고개를 돌리고(살짝 기울임) 숨 쉬듯 까딱인다 (그림만)
func _draw_head() -> void:
	var tilt := 0.0
	if not dead:
		tilt = clampf((look_at.x - 0.0) / 1200.0, -1.0, 1.0) * 0.07 + sin(t * 0.6) * 0.02
	var neck := Vector2(0, -2380)
	draw_set_transform_matrix(Transform2D(tilt, neck + Vector2(0, sin(t * 1.2) * 4.0)) * Transform2D(0.0, -neck))
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
		draw_circle(e + (look_at - e).limit_length(1.0) * 7.0, 10.0 + eye_glow * 6.0, Color(C_EYE, glow))   # 눈동자가 플레이어를 좇는다
		if beam_glow > 0.0:                          # 레이저: 보랏빛으로 달아오른다
			draw_circle(e, 30.0 + beam_glow * 40.0, Color(C_UNPARRY, 0.35 * beam_glow))
			draw_circle(e, 8.0 + beam_glow * 10.0, Color(C_UNPARRY_CORE, beam_glow))
	draw_set_transform(Vector2.ZERO)

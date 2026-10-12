extends Node2D
## 거대한 적 (정면). 배경에 서 있어서 몸 자체는 충돌/피해 판정이 없다.
## 판정은 두 종류:
##  1) 적이 공격할 때 그 공격(주먹/발/충격파/탄환) — 그때만 생긴다
##  2) 표적(부위·코어)은 상시 판정: 돌진 중에 닿으면 타격, 아니면 닿은 플레이어가 피해
## 페이즈: 1) 부위 파괴 — 좌/우 포대, 좌/우 팔꿈치 관절을 부순다 (가슴은 닫혀 있음)
##         2) 개방 연출 — 가슴이 열린다
##         3) 코어 — 하트 모양 강철 껍질에 싸인 코어(체력 하나). 피해가 쌓일수록 껍질이 부서진다. 탄은 머리에서 쏜다
## 체력바는 없다: 부위·코어 모두 균열·연기·조각 탈락으로 남은 체력을 보여 준다
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

# ── 구조 ───────────────────────────────────────────────
const HEART_POS := Vector2(0, -1900)        # 코어(심장) 중심
const CHEST_RECT := Rect2(-244, -2160, 488, 540)   # 가슴 문 (페이즈 1에 닫혀 있음)
const ARMOR_HP := 160                       # 강철 껍질 체력. 다 부서져도 피해가 코어로 넘어가지 않는다
const CORE_HP := 1                          # 껍질이 다 부서진 뒤 코어는 한 발이면 부서진다
const CORE_GUARD := 0.35                    # 껍질이 부서진 직후 이 시간은 코어가 맞아도 부서지지 않는다 (한 번에 둘 다 깨지는 것 방지)
const PLATE_SITES := 11                     # 껍질을 이루는 불규칙한 강철 판 수
const CORE_R := 62.0                        # 심장 안 코어 반지름
# 심장 외곽선 (HEART_POS 기준, 두 심방·대동맥·폐동맥·좌심실 끝으로 이어지는 해부학적 모양). 한 번 부드럽게 다듬어 쓴다
const HEART_OUTLINE := [
	Vector2(-40, 262), Vector2(-95, 225), Vector2(-150, 165), Vector2(-190, 95), Vector2(-212, 15), Vector2(-212, -55),
	Vector2(-190, -105), Vector2(-150, -130), Vector2(-105, -133), Vector2(-75, -118),
	Vector2(-62, -150), Vector2(-58, -195), Vector2(-40, -232), Vector2(-5, -246), Vector2(30, -236), Vector2(48, -205), Vector2(50, -165), Vector2(58, -140),
	Vector2(78, -160), Vector2(100, -170), Vector2(118, -150), Vector2(112, -125),
	Vector2(135, -130), Vector2(175, -118), Vector2(205, -80), Vector2(218, -25), Vector2(212, 40), Vector2(190, 100), Vector2(150, 160), Vector2(100, 210), Vector2(45, 247),
]
const C_STEEL := Color(0.34, 0.38, 0.45)
const C_STEEL_DARK := Color(0.2, 0.22, 0.27)

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
const PART_HP := 24                         # 0 왼쪽 포대, 1 오른쪽 포대, 2 왼팔 관절, 3 오른팔 관절
const PART_R := [55.0, 55.0, 70.0, 70.0]
const OPEN_TIME := 1.6                      # 가슴이 열리는 연출 시간

# ── 공격 튜닝 ──────────────────────────────────────────
const LOW_ZONE_Y := -900.0           # 이보다 아래(용암 근처)면 용암 분출 위주
const STOMP_LIFT_TIME := 0.7         # 용암 분출: 발을 들어(경고) 구르면 용암이 솟는다
const STOMP_LIFT_H := 420.0
const STOMP_SLAM_TIME := 0.14
const ERUPT_SPOTS := 4               # 분출 지점 수 (하나는 플레이어 바로 아래)
const ERUPT_GLOBS := 4               # 지점마다 솟는 용암 덩어리 수
const ERUPT_GAP := 0.1               # 덩어리 사이 간격
const GLOB_G := 600.0                # 용암 덩어리 중력
const GLOB_OVERSHOOT := 150.0        # 플레이어 높이보다 이만큼 위까지 솟는다
const SWING_L := 1180.0              # 팔 전체를 곧게 뻗어 휩쓰는 반경
const SWING_PREP := 0.9              # 준비 모션: 팔이 뒤로 젖혀졌다 목표 위치로 (앞부분에서만 플레이어를 따라간다)
const SWING_PREP_TRACK := 0.6        # 준비 모션의 이 비율까지만 조준. 이후 위치 확정
const SWING_SET := 0.3               # 팔 위치 고정 (예상 범위 윤곽만 표시)
const SWING_WARN := 0.8              # 실제 공격 범위가 붉게 점멸
const UPPER_W := 75.0                # 팔 판정 반폭: 위팔 / 아래팔 / 주먹은 FIST_R
const FORE_W := 62.0
const SWING_TIME := 0.65
const SWING_HOLD := 0.25
const SWING_SPAN := 2.6              # 휩쓰는 각도(라디안, 약 150도)
const ELBOW_AT := 0.55               # 휩쓰는 동안 팔꿈치는 어깨~주먹 선의 이 지점에 고정 (곧은 팔)
const RECOIL_ANGLE := 0.5            # 패리당하면 휩쓸던 반대쪽으로 이만큼(라디안) 밀려난다
const RECOIL_TIME := 0.7
const STAGGER_TIME := 1.0            # 밀려난 뒤 팔이 멈춰 관절이 드러나는 시간
const FIST_R := 105.0
const BEAM_WIND := 1.1               # 눈 레이저(패리 불가): 눈이 달아오르고 시작선이 표시된다
const BEAM_SWEEP := 1.7              # 왼쪽 → 아래 → 오른쪽으로 긋는 시간
const BEAM_FROM := PI + 0.2          # 시작 각도 (왼쪽, 살짝 위)
const BEAM_TO := -0.2                # 끝 각도 (오른쪽, 살짝 위)
const BEAM_HALF := 16.0              # 판정 반폭
const BOLT_SPEED := 480.0
const BOLT_SPEEDUP := 0.1            # 부위 하나 부술 때마다 탄 속도 +10%
const BOLT_SPEEDUP_CORE := 0.15      # 최종 페이즈 추가 가속
const BOLT_WARMUP := 0.3             # 발사 직후 50% 속도에서 출발해 이 시간 동안 100%까지
const BOLT_WARMUP_FLOOR := 0.5
const VOLLEY_CHARGE := 1.0
const VOLLEY_INTERVAL := 0.42
const BURST_CHARGE := 1.3
const BURST_SPEED := Vector2(264.0, 408.0)
const BOLT_R := 16.0
const ATTACK_GAP := Vector2(1.0, 1.8)   # 공격 사이 쉬는 시간

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
const C_PARRY := Color(1.0, 0.88, 0.35)          # 패리할 수 있는 것 = 금색 (탄, 휩쓰는 팔)
const C_LAVA := Color(1.0, 0.35, 0.12)
const C_UNPARRY := Color(0.6, 0.08, 0.36)       # 패리 불가 = 검붉은 보라 (회피 돌진으로만 피한다)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var phase := 1
var open_t := 0.0
var part_hp: Array[int] = []
var part_flash: Array[float] = []
var part_stage: Array[int] = []      # 부위 손상 단계 0~3 (남은 체력 75/50/25%)
var armor_hp := ARMOR_HP
var core_hp := CORE_HP
var core_flash := 0.0
var core_stage := 0                  # 껍질 손상 단계 0~4 (피해 20%마다, 연출용)
var armor_broken := false            # 껍질이 다 부서져 코어가 드러남 (한 발 더 필요)
var core_guard := 0.0
var shell_poly := PackedVector2Array()
var plates: Array[Dictionary] = []   # 불규칙한 강철 판: poly(중심 기준), cen, th(떨어지는 시점), 패임·균열선, gone
var shards: Array[Dictionary] = []   # 떨어져 나가는 장갑 조각
var feet: Array[Vector2] = []
var fists: Array[Vector2] = []
var debris: Array[Dictionary] = []   # 부서져 떨어진 부위
var atk: Dictionary = {}
var bolts: Array[Dictionary] = []
var next_t := 2.5
var hold_attacks := false             # true 인 동안(플레이어가 발판 위) 새 공격을 시작하지 않는다
var eye_glow := 0.0
var beam_glow := 0.0                 # 레이저 직전·중 눈이 보랏빛으로 달아오름
var cannon_glow: Array[float] = [0.0, 0.0]   # 발사 전 포구가 달아오르는 정도
var strike_glow := false             # 플레이어가 공격 돌진 중 = 타격점이 드러난다
var focus_glow := 0.0                # 방향 지정·차지 중: 노릴 수 있는 표적 강조 (0~1)
var focus_from := Vector2.ZERO       # 강조 기준 위치(플레이어)
var focus_reach := 0.0               # 이 거리 안의 표적은 더 밝게
var dead := false
var death_t := 0.0
var t := 0.0
var events: Array[Dictionary] = []   # main.gd 가 매 프레임 꺼내 처리 (흔들림/사운드)


func _ready() -> void:
	_build_shell()
	reset()


## 심장 외곽선과 불규칙한 강철 판(보로노이 조각 + 들쭉날쭉한 변), 패임·균열선을 한 번만 만든다
func _build_shell() -> void:
	var pts := PackedVector2Array()
	for q in HEART_OUTLINE:
		pts.append(HEART_POS + q)
	for it in 2:                                  # 모서리를 둥글려 유기적인 윤곽으로
		var sm := PackedVector2Array()
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			sm.append(a.lerp(b, 0.25))
			sm.append(a.lerp(b, 0.75))
		pts = sm
	shell_poly = pts
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var sites: Array[Vector2] = []
	var tries := 0
	while sites.size() < PLATE_SITES and tries < 4000:
		tries += 1
		var q := HEART_POS + Vector2(rng.randf_range(-215, 215), rng.randf_range(-245, 260))
		if not Geometry2D.is_point_in_polygon(q, shell_poly):
			continue
		var ok := true
		for o in sites:
			if o.distance_to(q) < 105.0:
				ok = false
				break
		if ok:
			sites.append(q)
	plates.clear()
	for i in sites.size():
		var cell := shell_poly
		for j in sites.size():
			if i != j:
				cell = _clip_half(cell, (sites[i] + sites[j]) * 0.5, (sites[j] - sites[i]).normalized())
		if cell.size() < 3:
			continue
		cell = _jag(cell, rng)
		var cen := Vector2.ZERO
		for q in cell:
			cen += q
		cen /= cell.size()
		var local := PackedVector2Array()
		for q in cell:
			local.append(q - cen)
		var crumple: Array[PackedVector2Array] = []
		var cracks: Array[PackedVector2Array] = []
		var bb := Rect2(local[0], Vector2.ZERO)
		for q in local:
			bb = bb.expand(q)
		for k in 3:
			var a := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if Geometry2D.is_point_in_polygon(a, local):
				var d := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(10.0, 24.0)
				crumple.append(PackedVector2Array([a - d, a, a + d.rotated(rng.randf_range(-0.9, 0.9))]))
		var cr := Vector2.ZERO
		var cd := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var line := PackedVector2Array([cr])
		for k in 4:
			cd = cd.rotated(rng.randf_range(-0.7, 0.7))
			cr += cd * rng.randf_range(12.0, 26.0)
			if not Geometry2D.is_point_in_polygon(cr, local):
				break
			line.append(cr)
		if line.size() >= 2:
			cracks.append(line)
		plates.append({"poly": local, "cen": cen, "th": rng.randf_range(0.12, 0.96), "off": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)),
			"rot": rng.randf_range(-1.0, 1.0), "crumple": crumple, "cracks": cracks, "gone": false, "rivet": local[0].lerp(Vector2.ZERO, 0.55)})


## 볼록하지 않은 다각형을 반평면(점 m 에서 n 쪽의 반대편 = 가까운 쪽)으로 자른다
static func _clip_half(poly: PackedVector2Array, m: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		var da := (a - m).dot(n)
		var db := (b - m).dot(n)
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## 변을 쪼개 살짝 들쭉날쭉하게 (깨진 철판 느낌)
static func _jag(poly: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		out.append(a)
		var l := a.distance_to(b)
		if l > 46.0:
			var nrm := (b - a).orthogonal().normalized()
			out.append(a.lerp(b, rng.randf_range(0.35, 0.65)) + nrm * rng.randf_range(-7.0, 7.0))
	return out


func reset() -> void:
	phase = 1
	open_t = 0.0
	part_hp = [PART_HP, PART_HP, PART_HP, PART_HP]
	part_flash = [0.0, 0.0, 0.0, 0.0]
	part_stage = [0, 0, 0, 0]
	armor_hp = ARMOR_HP
	core_hp = CORE_HP
	core_flash = 0.0
	core_stage = 0
	armor_broken = false
	core_guard = 0.0
	for pl in plates:
		pl["gone"] = false
	shards.clear()
	feet.clear()
	feet.append(FOOT_REST[0])
	feet.append(FOOT_REST[1])
	fists.clear()
	fists.append(FIST_IDLE[0])
	fists.append(FIST_IDLE[1])
	debris.clear()
	atk = {}
	bolts.clear()
	next_t = 2.5
	eye_glow = 0.0
	beam_glow = 0.0
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
		var st := _part_stage_of(i)
		if st > part_stage[i]:                 # 손상 단계가 올라가면 조각이 튀고 연기가 짙어진다
			part_stage[i] = st
			events.append({"type": "part_stage", "pos": part_pos(i), "stage": st})
			if st == 3:
				_spawn_shard(part_pos(i), 26.0, Vector2((1.0 if i % 2 == 1 else -1.0) * 240.0, -320.0))
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


func _part_stage_of(i: int) -> int:
	var f := float(part_hp[i]) / PART_HP
	if f <= 0.25:
		return 3
	if f <= 0.5:
		return 2
	if f <= 0.75:
		return 1
	return 0


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


# ── 코어 ───────────────────────────────────────────────
## 껍질 판의 손상 단계: 0 멀쩡 / 1 찌그러짐 / 2 휘고 금 감 / 3 떨어져 나감.
## 판마다 임계값(th)이 달라 불규칙하게 하나씩 망가진다. f = 껍질 손상 비율 0~1
func plate_level(pl: Dictionary, f: float) -> int:
	var th: float = pl["th"]
	if f >= th or armor_broken:
		return 3
	if f >= th * 0.75:
		return 2
	if f >= th * 0.45:
		return 1
	return 0


func armor_frac() -> float:
	return 1.0 - float(armor_hp) / ARMOR_HP


## 코어 쪽 피해. 껍질이 남아 있으면 껍질만 깎는다(남는 피해는 버린다) → 껍질이 다 부서지면 코어가 드러난다.
## 이미 드러난 코어를 맞히면 true (부서짐 = 승리). 껍질이 부서진 그 일격으로는 코어가 부서지지 않는다.
func damage_core(dmg: int) -> bool:
	if core_hp <= 0:
		return false
	if armor_hp > 0:
		armor_hp = maxi(0, armor_hp - dmg)
		core_flash = 1.0
		_update_plates()
		if armor_hp == 0:
			armor_broken = true
			core_guard = CORE_GUARD
			events.append({"type": "armor_break", "pos": HEART_POS})
		return false
	if core_guard > 0.0:
		core_flash = 1.0
		return false
	core_hp = 0
	core_flash = 1.0
	return true


## 껍질 손상 비율에 따라 임계값을 넘은 판이 떨어져 나가고(불규칙한 파편), 단계 이벤트를 낸다
func _update_plates() -> void:
	var f := armor_frac()
	var st := mini(4, int(f * 5.0 + 0.001))
	var fell := 0
	for pl in plates:
		if pl["gone"] or plate_level(pl, f) < 3:
			continue
		pl["gone"] = true
		fell += 1
		var cen: Vector2 = pl["cen"]
		var out := (cen - HEART_POS).normalized()
		var v := out * randf_range(260.0, 420.0) + Vector2(randf_range(-80, 80), randf_range(-380, -180))
		shards.append({"pos": cen, "vel": v, "rot": 0.0, "rotv": randf_range(-4.0, 4.0), "pts": pl["poly"]})
	if fell > 0 or st > core_stage:
		core_stage = maxi(core_stage, st)
		events.append({"type": "core_stage", "pos": HEART_POS, "stage": core_stage, "fell": fell})


func _spawn_shard(pos: Vector2, size: float, v: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(-size, -size * 0.6), Vector2(size * 0.8, -size * 0.8), Vector2(size, size * 0.5), Vector2(-size * 0.5, size)])
	shards.append({"pos": pos, "vel": v, "rot": 0.0, "rotv": randf_range(-5.0, 5.0), "pts": pts})


func heart_pos() -> Vector2:
	return HEART_POS


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
				var n := p - part_pos(i)
				best = {"kind": "part", "idx": i, "n": n.normalized() if n.length() > 0.1 else Vector2.UP}
		return best
	return _core_hit(p, r)


## 하트 껍질과의 충돌: 안쪽이면 중심에서 바깥 방향, 바깥이면 가장 가까운 변에서 바깥 방향이 법선
func _core_hit(p: Vector2, r: float) -> Dictionary:
	if Geometry2D.is_point_in_polygon(p, shell_poly):
		var n := p - HEART_POS
		return {"kind": "core", "n": n.normalized() if n.length() > 0.1 else Vector2.UP}
	var best_d := INF
	var best_q := Vector2.ZERO
	for j in shell_poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, shell_poly[j], shell_poly[(j + 1) % shell_poly.size()])
		var d := q.distance_to(p)
		if d < best_d:
			best_d = d
			best_q = q
	if best_d < r:
		return {"kind": "core", "n": (p - best_q).normalized()}
	return {}


## 에임 어시스트용 표적 목록 (중심, 반지름)
func assist_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead or phase == 2:
		return out
	if phase == 1:
		for i in 4:
			if part_alive(i):
				out.append({"pos": part_pos(i), "r": float(PART_R[i])})
		return out
	out.append({"pos": HEART_POS, "r": 200.0})
	return out


func hit_center(hit: Dictionary) -> Vector2:
	if hit["kind"] == "part":
		return part_pos(int(hit["idx"]))
	return HEART_POS


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
	var bent := _arm_bent(a)
	if atk.get("kind", "") == "swing" and atk.get("arm", -1) == a:
		var straight: Vector2 = SHOULDERS[a].lerp(fists[a], ELBOW_AT)   # 휩쓰는 동안은 곧은 팔 → 관절 위치를 예측 가능
		var tt: float = atk["t"]
		match atk["phase"]:
			"prep":
				return bent.lerp(straight, minf(1.0, tt / 0.3))
			"return":
				return straight.lerp(bent, minf(1.0, tt / 0.4))
		return straight
	return bent


## 팔꿈치: 항상 팔 진행 방향의 같은 쪽(바깥)으로 굽힌다 → 팔이 돌아도 관절이 반대편으로 튀지 않는다
func _arm_bent(a: int) -> Vector2:
	var sh: Vector2 = SHOULDERS[a]
	var d := fists[a] - sh
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, ARM_SEG * ARM_SEG - half * half))
	var perp := d.orthogonal().normalized() * (1.0 if a == 1 else -1.0)
	return sh + d * 0.5 + perp * h


func is_staggered(a: int) -> bool:
	return atk.get("kind", "") == "swing" and atk.get("arm", -1) == a and atk["phase"] == "stagger"


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
	if atk.get("kind", "") == "swing" and atk["phase"] == "swing":
		var a: int = atk["arm"]
		var th: float = atk["th"]
		var s := 1.0 if a == 1 else -1.0
		var tangent := Vector2(-s * sin(th), cos(th))
		var hb := _arm_box(a, ppos)
		hb["push"] = (tangent + Vector2(0, -0.5)).normalized()
		out.append(hb)
	for b in bolts:
		var bv: Vector2 = b["vel"]
		out.append({"id": "bolt", "pos": b["pos"], "r": BOLT_R, "push": bv.normalized(), "bolt": b})
	return out


## 팔 전체(위팔·아래팔·주먹) 판정 상자. pos = ppos 에 가장 가까운 지점
func _arm_box(a: int, ppos: Vector2) -> Dictionary:
	var sh: Vector2 = SHOULDERS[a]
	var el := elbow_of(a)
	var segs := [[sh, el, UPPER_W], [el, fists[a], FORE_W], [fists[a], fists[a], FIST_R]]
	var best := fists[a]
	var best_d := INF
	for sg in segs:
		var q := _seg_closest(ppos, sg[0], sg[1])
		var d := q.distance_to(ppos) - float(sg[2])
		if d < best_d:
			best_d = d
			best = q
	return {"id": "arm", "segs": segs, "pos": best}


## 차지 돌진으로 저지할 수 있는 팔: 위치를 잡고 공격 직전 멈춰 있을 때(set·warn)와 휘두르는 중(swing).
## 들어올리는 중(prep)은 아니다.
func clash_box(ppos: Vector2) -> Dictionary:
	if dead or atk.get("kind", "") != "swing":
		return {}
	var ph: String = atk["phase"]
	if ph != "set" and ph != "warn" and ph != "swing":
		return {}
	return _arm_box(int(atk["arm"]), ppos)


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


## 받아치기 / 탄 패리: 팔은 휩쓸던 반대쪽으로 밀려나 멈추고, 탄은 사라진다
func on_parried(hb: Dictionary) -> void:
	match hb["id"]:
		"arm":
			atk["phase"] = "recoil"; atk["t"] = 0.0; atk["th_from"] = atk["th"]
		"bolt":
			bolts.erase(hb["bolt"])


## 패리로 밀려난 팔: 패리 돌진이 끝나면 경직을 풀고 바로 제자리로
func release_stagger() -> void:
	if atk.get("kind", "") == "swing" and (atk["phase"] == "recoil" or atk["phase"] == "stagger"):
		atk["phase"] = "return"; atk["t"] = 0.0


## 레이저 끝점: 눈에서 쏜 광선이 벽·천장·용암에 닿는 곳
func beam_end(th: float) -> Vector2:
	var d := Vector2.from_angle(th)
	var k := 99999.0
	if d.x < -0.001:
		k = minf(k, (-1150.0 - HEAD_POS.x) / d.x)
	elif d.x > 0.001:
		k = minf(k, (1150.0 - HEAD_POS.x) / d.x)
	if d.y > 0.001:
		k = minf(k, (0.0 - HEAD_POS.y) / d.y)
	elif d.y < -0.001:
		k = minf(k, (-3080.0 - HEAD_POS.y) / d.y)
	return HEAD_POS + d * k


## 레이저 판정(패리 불가). 이번 프레임에 광선이 쓸고 지나간 부채꼴 안이면 맞는다 → 밀려날 방향, 아니면 ZERO
func beam_hit(p: Vector2, r: float) -> Vector2:
	if dead or atk.get("kind", "") != "beam" or atk["phase"] != "sweep":
		return Vector2.ZERO
	var rel := p - HEAD_POS
	var dist := rel.length()
	if dist < 1.0:
		return Vector2.ZERO
	var th: float = atk["th"]
	var th_prev: float = atk["th_prev"]
	var d := wrapf(th_prev - rel.angle(), -PI, PI)      # 광선은 각도가 줄어드는 방향으로 돈다
	var w := (BEAM_HALF + r) / dist
	if d < -w or d > (th_prev - th) + w:
		return Vector2.ZERO
	if dist > HEAD_POS.distance_to(beam_end(rel.angle())) + r:
		return Vector2.ZERO
	return Vector2.from_angle(th - PI * 0.5)           # 쓸고 가는 방향으로 밀려난다


func on_hit_player(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		bolts.erase(hb["bolt"])


func die() -> void:
	dead = true
	death_t = 0.0
	atk = {}
	bolts.clear()


# ── 진행 ───────────────────────────────────────────────
func step(dt: float, ppos: Vector2) -> void:
	t += dt
	core_flash = maxf(0.0, core_flash - dt * 4.0)
	core_guard = maxf(0.0, core_guard - dt)
	_step_shards(dt)
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
	beam_glow = move_toward(beam_glow, 0.0, dt * 2.0)
	for i in 2:
		cannon_glow[i] = move_toward(cannon_glow[i], 0.0, dt * 2.0)
	_step_bolts(dt)
	if atk.is_empty():
		if hold_attacks:
			next_t = maxf(next_t, 1.2)         # 날아오른 뒤 잠시 여유를 준다
		next_t -= dt
		if next_t <= 0.0:
			_choose(ppos)
	else:
		atk["t"] = float(atk["t"]) + dt
		match atk["kind"]:
			"erupt": _step_erupt(ppos)
			"swing": _step_swing(dt, ppos)
			"volley": _step_volley(ppos)
			"burst": _step_burst()
			"beam": _step_beam()
	queue_redraw()


func _finish() -> void:
	atk = {}
	if part_alive(2) == false:
		fists[0] = FIST_IDLE[0]
	if part_alive(3) == false:
		fists[1] = FIST_IDLE[1]
	next_t = randf_range(ATTACK_GAP.x, ATTACK_GAP.y)


func _choose(ppos: Vector2) -> void:
	var roll := randf()
	var can_shoot := phase == 3 or part_alive(0) or part_alive(1)
	var arm := _swing_arm(ppos)
	if ppos.y > LOW_ZONE_Y and roll < 0.6:      # 용암 근처: 아래에서 솟는 탄막 위주
		_start_erupt(ppos)
		return
	if roll < 0.2:
		_start_erupt(ppos)
		return
	if roll < 0.36:                               # 패리 불가 눈 레이저
		atk = {"kind": "beam", "phase": "wind", "t": 0.0, "th": BEAM_FROM, "th_prev": BEAM_FROM}
		return
	if arm >= 0 and (roll < 0.64 or not can_shoot):
		atk = {"kind": "swing", "phase": "prep", "t": 0.0, "arm": arm, "from": fists[arm]}
		_aim_swing(arm, ppos)
	elif can_shoot:
		if roll < 0.86:
			atk = {"kind": "volley", "t": 0.0, "shots": 0}
		else:
			atk = {"kind": "burst", "t": 0.0}
	else:
		_start_erupt(ppos)
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


## 용암 분출: 발을 들었다 구르면 용암 표면 여러 곳(하나는 플레이어 바로 아래)에서 덩어리가 솟구친다
func _start_erupt(ppos: Vector2) -> void:
	var i := 1 if ppos.x >= 0.0 else 0
	var spots: Array[float] = [clampf(ppos.x, -1080.0, 1080.0)]
	while spots.size() < ERUPT_SPOTS:
		var x := randf_range(-1080.0, 1080.0)
		var ok := true
		for sx in spots:
			if absf(sx - x) < 220.0:
				ok = false
		if ok:
			spots.append(x)
	var h := clampf(-ppos.y, 300.0, 2800.0) + GLOB_OVERSHOOT
	atk = {"kind": "erupt", "t": 0.0, "foot": i, "spots": spots, "h": h, "speed": sqrt(2.0 * GLOB_G * h), "fired": 0, "slammed": false}


func _step_erupt(_ppos: Vector2) -> void:
	var i: int = atk["foot"]
	var tt: float = atk["t"]
	var rest: Vector2 = FOOT_REST[i]
	var slam_at := STOMP_LIFT_TIME + STOMP_SLAM_TIME
	if tt < STOMP_LIFT_TIME:
		feet[i] = rest.lerp(rest + Vector2(0, -STOMP_LIFT_H), smoothstep(0.0, 1.0, tt / STOMP_LIFT_TIME))
		return
	if tt < slam_at:
		var k := (tt - STOMP_LIFT_TIME) / STOMP_SLAM_TIME
		feet[i].y = lerpf(-STOMP_LIFT_H, 0.0, k * k)
		return
	feet[i] = rest
	if not atk["slammed"]:
		atk["slammed"] = true
		events.append({"type": "stomp", "pos": rest})
	var fired: int = atk["fired"]
	if fired < ERUPT_GLOBS and tt >= slam_at + fired * ERUPT_GAP:
		for x in atk["spots"]:
			var v := Vector2(randf_range(-40.0, 40.0), -float(atk["speed"]) * randf_range(0.92, 1.0))
			bolts.append({"pos": Vector2(x, -12.0), "vel": v, "life": 9.0, "age": BOLT_WARMUP, "g": GLOB_G, "lava": true})
		events.append({"type": "erupt", "pos": Vector2(float(atk["spots"][0]), 0.0)})
		atk["fired"] = fired + 1
	elif fired >= ERUPT_GLOBS and tt >= slam_at + ERUPT_GLOBS * ERUPT_GAP + 0.3:
		_finish()


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


## 휩쓸기가 실제로 닿는 영역 (판정과 동일: 위팔/아래팔/주먹이 th0~th1 을 쓸고 지나가는 합집합)
func swing_area(a: int, th0: float, th1: float) -> PackedVector2Array:
	var s := 1.0 if a == 1 else -1.0
	var sh: Vector2 = SHOULDERS[a]
	var pieces: Array[PackedVector2Array] = []
	var wedge := PackedVector2Array([sh])
	for j in 25:
		var th := lerpf(th0, th1, j / 24.0)
		wedge.append(sh + Vector2(s * cos(th), sin(th)) * ((SWING_L + FIST_R) / cos(SWING_SPAN / 48.0)))   # 현 근사가 판정 안쪽으로 파고들지 않게 약간 바깥
	pieces.append(wedge)
	for ti in 2:
		var th := th0 if ti == 0 else th1
		var d := Vector2(s * cos(th), sin(th))
		var n := d.orthogonal()
		var el := sh + d * SWING_L * ELBOW_AT
		var fist := sh + d * SWING_L
		pieces.append(PackedVector2Array([sh + n * UPPER_W, el + n * UPPER_W, el - n * UPPER_W, sh - n * UPPER_W]))
		pieces.append(PackedVector2Array([el + n * FORE_W, fist + n * FORE_W, fist - n * FORE_W, el - n * FORE_W]))
		pieces.append(_disc(fist, FIST_R))
		pieces.append(_disc(el, UPPER_W))              # 위팔 끝의 둥근 마감
	pieces.append(_disc(sh, UPPER_W))                  # 어깨 쪽 둥근 마감
	var cur := pieces[0]
	for k in range(1, pieces.size()):
		for r in Geometry2D.merge_polygons(cur, pieces[k]):
			if not Geometry2D.is_polygon_clockwise(r):
				cur = r
				break
	return cur


## 원을 바깥에 접하는 다각형으로 근사 (예고 영역이 판정을 빠뜨리지 않도록)
static func _disc(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in 24:
		out.append(c + Vector2.from_angle(TAU * j / 24.0) * r / cos(PI / 24.0))
	return out


func _arm_fist(a: int, th: float) -> Vector2:
	var s := 1.0 if a == 1 else -1.0
	return SHOULDERS[a] + Vector2(s * cos(th), sin(th)) * SWING_L


## 팔 전체를 곧게 뻗어 부채꼴로 휩쓰는 큰 공격. 팔 어디에 닿아도 피해 → 패리하거나 회피 돌진(무적)으로 빠져나간다
## 패리당하면 휩쓸던 반대쪽으로 천천히 밀려난 뒤 잠시 멈춰 팔꿈치 관절이 드러난다
func _step_swing(dt: float, ppos: Vector2) -> void:
	var a: int = atk["arm"]
	var tt: float = atk["t"]
	var th0: float = atk["th0"]
	var th1: float = atk["th1"]
	match atk["phase"]:
		"prep":                                    # 준비 모션: 뒤로 젖혔다가 목표 위치로. 앞부분에서만 플레이어를 따라간다
			var k := minf(1.0, tt / SWING_PREP)
			if k < SWING_PREP_TRACK:
				_aim_swing(a, ppos)
			th0 = atk["th0"]
			var pre_th := th0 - 0.35 * sin(k * PI)
			atk["th"] = pre_th
			var from: Vector2 = atk.get("from", fists[a])
			fists[a] = from.lerp(_arm_fist(a, pre_th), smoothstep(0.0, 0.4, k))
			if tt >= SWING_PREP:
				atk["phase"] = "set"; atk["t"] = 0.0
		"set":                                     # 팔 고정 (이후 플레이어가 움직여도 경로는 바뀌지 않는다)
			atk["th"] = th0
			fists[a] = _arm_fist(a, th0)
			if tt >= SWING_SET:
				atk["phase"] = "warn"; atk["t"] = 0.0
		"warn":                                    # 실제 공격 범위가 붉게 점멸
			atk["th"] = th0
			fists[a] = _arm_fist(a, th0)
			if tt >= SWING_WARN:
				atk["phase"] = "swing"; atk["t"] = 0.0
				events.append({"type": "swing", "pos": fists[a]})
		"swing":
			var k := minf(1.0, tt / SWING_TIME)
			var th := lerpf(th0, th1, k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65)   # 거의 등속, 시작만 살짝 느리게
			atk["th"] = th
			fists[a] = _arm_fist(a, th)
			if k >= 1.0:
				atk["phase"] = "hold"; atk["t"] = 0.0
		"hold":
			if tt >= SWING_HOLD:
				atk["phase"] = "return"; atk["t"] = 0.0
		"recoil":
			var k := minf(1.0, tt / RECOIL_TIME)
			var th := float(atk["th_from"]) - RECOIL_ANGLE * (1.0 - (1.0 - k) * (1.0 - k))   # 감속하며 반대쪽으로
			atk["th"] = th
			fists[a] = _arm_fist(a, th)
			if k >= 1.0:
				atk["phase"] = "stagger"; atk["t"] = 0.0
		"stagger":
			if tt >= STAGGER_TIME:
				atk["phase"] = "return"; atk["t"] = 0.0
		"return":                                  # 천천히 제자리로 (팔꿈치가 튀지 않게)
			fists[a] = fists[a].lerp(FIST_IDLE[a], minf(1.0, dt * 3.0))
			if tt >= 1.4:
				fists[a] = FIST_IDLE[a]
				_finish()


## 눈 레이저: 왼쪽에서 아래를 지나 오른쪽까지 맵을 긋는다. 패리 불가 → 회피 돌진 무적으로 통과
func _step_beam() -> void:
	var tt: float = atk["t"]
	match atk["phase"]:
		"wind":
			beam_glow = minf(1.0, tt / BEAM_WIND)
			if tt >= BEAM_WIND:
				atk["phase"] = "sweep"; atk["t"] = 0.0
				events.append({"type": "beam", "pos": HEAD_POS})
		"sweep":
			beam_glow = 1.0
			var k := minf(1.0, tt / BEAM_SWEEP)
			atk["th_prev"] = atk["th"]
			atk["th"] = lerpf(BEAM_FROM, BEAM_TO, k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7)
			if k >= 1.0:
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
	if tt >= VOLLEY_CHARGE + shots * VOLLEY_INTERVAL:
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
		bolts.append({"pos": org, "vel": Vector2.from_angle(ang) * randf_range(BURST_SPEED.x, BURST_SPEED.y) * bolt_mult(), "life": 9.0, "age": 0.0})
	events.append({"type": "bolt", "pos": org})
	_set_glow(c, 1.0)
	_finish()


func _step_bolts(dt: float) -> void:
	for b in bolts.duplicate():
		var p: Vector2 = b["pos"]
		var v: Vector2 = b["vel"]
		if b.has("g"):                           # 용암 덩어리: 포물선
			v.y += float(b["g"]) * dt
			b["vel"] = v
		b["age"] = float(b["age"]) + dt
		p += v * lerpf(BOLT_WARMUP_FLOOR, 1.0, minf(1.0, float(b["age"]) / BOLT_WARMUP)) * dt
		b["pos"] = p
		b["life"] = float(b["life"]) - dt
		if b["life"] <= 0.0 or p.y > -6.0 or p.x < -1250.0 or p.x > 1250.0 or p.y < -3100.0:
			bolts.erase(b)
			events.append({"type": "bolt_pop", "pos": p})

func _step_shards(dt: float) -> void:
	for sd in shards.duplicate():
		var v: Vector2 = sd["vel"]
		v.y += 1400.0 * dt
		sd["vel"] = v
		var sp: Vector2 = sd["pos"] + v * dt
		sd["pos"] = sp
		sd["rot"] = float(sd["rot"]) + float(sd["rotv"]) * dt
		if sp.y > 40.0:                        # 용암에 떨어져 사라진다
			shards.erase(sd)


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
	_draw_shards()
	_draw_telegraphs()
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


## 가슴: 페이즈 1은 닫힌 문, 페이즈 2는 열리는 중, 페이즈 3은 강철 껍질에 싸인 심장(코어)
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
		draw_rect(Rect2(heart_pos().x - gap * 0.5, rc.position.y, gap, rc.size.y), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(0, rc.position.y), Vector2(0, rc.end.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)


## 심장: 안쪽은 어두운 붉은 근육 + 맥동하는 코어, 바깥은 불규칙한 강철 판.
## 판은 하나씩 찌그러지고 → 휘고 금이 가고 → 뜯겨 나가며 코어가 드러난다. 껍질이 다 사라지면 코어가 오작동하듯 깜빡이며 약점으로 표시된다.
func _draw_core() -> void:
	var hc := HEART_POS
	var f := armor_frac()
	var beat := 0.5 + 0.5 * sin(t * (4.5 + f * 5.0))          # 많이 부서질수록 빨리 뛴다
	var lit := strike_glow or focus_glow > 0.0               # 공격 돌진 중이거나 방향 지정·차지 중이면 표적이 드러난다
	if dead:
		draw_colored_polygon(shell_poly, Color(0.2, 0.04, 0.05))
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	# 심장 근육 (안쪽): 두 겹 + 중격선 + 혈관
	draw_colored_polygon(shell_poly, Color(0.2, 0.04, 0.06))
	var inner := PackedVector2Array()
	for q in shell_poly:
		inner.append(hc + (q - hc) * 0.86)
	draw_colored_polygon(inner, Color(0.32, 0.06, 0.08).lerp(Color(0.5, 0.1, 0.08), f * 0.6))
	draw_polyline(PackedVector2Array([hc + Vector2(-40, 230), hc + Vector2(-70, 120), hc + Vector2(-60, 10), hc + Vector2(-72, -118)]), Color(0.12, 0.02, 0.03, 0.8), 5.0)
	draw_polyline(PackedVector2Array([hc + Vector2(30, 200), hc + Vector2(80, 110), hc + Vector2(120, 20), hc + Vector2(150, -60)]), Color(0.55, 0.1, 0.12, 0.7), 3.0)
	draw_polyline(PackedVector2Array([hc + Vector2(-30, -240), hc + Vector2(-10, -170), hc + Vector2(30, -110)]), Color(0.55, 0.1, 0.12, 0.7), 4.0)
	# 코어 (맥동). 껍질이 사라질수록 밝고 불안정하게
	var flick := 1.0
	if armor_broken:
		flick = 0.55 + 0.45 * float(int(t * 14.0) % 3 != 0)
	var pr := CORE_R * (1.0 + 0.06 * beat)
	var ca := 0.35 + 0.65 * minf(1.0, f * 1.3)
	draw_circle(hc, pr * 2.0, Color(C_HEART, (0.08 + 0.1 * beat) * ca * flick))
	draw_circle(hc, pr * 1.3, Color(C_HEART, 0.35 * ca * flick))
	draw_circle(hc, pr, Color(C_HEART, ca * flick).lerp(Color.WHITE, core_flash * 0.6))
	draw_circle(hc + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.4, Color(1.0, 0.85, 0.6, ca * flick))
	# 강철 판
	var steel := C_STEEL.lerp(Color.WHITE, core_flash * 0.5)
	if lit:
		steel = steel.lerp(Color(1.0, 0.85, 0.5), 0.15)
	for pl in plates:
		if pl["gone"]:
			continue
		var lv := plate_level(pl, f)
		var cen: Vector2 = pl["cen"]
		var off: Vector2 = pl["off"]
		var rot: float = pl["rot"]
		var col := steel
		var shift := Vector2.ZERO
		var ang := 0.0
		if lv >= 1:
			col = steel.lerp(C_STEEL_DARK, 0.35)
			shift = off * 2.0
			ang = rot * 0.015
		if lv >= 2:
			col = steel.lerp(C_STEEL_DARK, 0.6)
			shift = off * 7.0 + Vector2(0, 2.0 * sin(t * 9.0 + cen.x))   # 헐거워져 덜컹거린다
			ang = rot * 0.12 + 0.02 * sin(t * 7.0 + cen.y)
		draw_set_transform(cen + shift, ang)
		var poly: PackedVector2Array = pl["poly"]
		draw_colored_polygon(poly, col)
		var ol := poly.duplicate()
		ol.append(poly[0])
		draw_polyline(ol, Color(1.0, 0.85, 0.5) if lit else (C_PLATE_EDGE if lv < 2 else Color(1.0, 0.45, 0.15, 0.5 + 0.4 * beat)), 3.0 if lv < 2 else 4.0)
		if lv == 0:
			draw_circle(pl["rivet"], 4.0, C_STEEL_DARK)
			draw_circle(pl["rivet"] + Vector2(-1, -1), 1.6, Color(0.72, 0.76, 0.82))
		if lv >= 1:                                # 찌그러짐: 눌린 자국과 주름
			for c in pl["crumple"]:
				draw_polyline(c, Color(C_STEEL_DARK, 0.9), 3.0)
				draw_polyline(c + PackedVector2Array([Vector2(1, 1), Vector2(1, 1), Vector2(1, 1)]), Color(0.7, 0.74, 0.8, 0.45), 1.5)
		if lv >= 2:                                # 균열 틈으로 코어 빛이 샌다 + 불꽃
			for c in pl["cracks"]:
				draw_polyline(c, Color(1.0, 0.5, 0.2, 0.7 + 0.3 * beat), 3.0)
			if int(t * 6.0 + cen.x * 0.01) % 5 == 0:
				draw_circle(Vector2(sin(t * 20.0 + cen.y) * 14.0, cos(t * 17.0) * 14.0), 2.5, Color(1.0, 0.9, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0)
	# 연기: 손상이 클수록 많이
	var smoke := int(f * 6.0)
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -140.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if armor_broken:                               # 껍질이 사라진 코어: 불안정한 불꽃 + 약점 표시
		for k in 6:
			var sa := t * 4.0 + k * 1.1
			var sd := CORE_R + 14.0 + fmod(t * 120.0 + k * 41.0, 80.0)
			draw_circle(hc + Vector2.from_angle(sa) * sd, 3.0, Color(1.0, 0.85, 0.5, 0.9))
		draw_arc(hc, CORE_R + 22.0 + 6.0 * beat, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.55 + 0.4 * beat), 3.0)
	if focus_glow > 0.0:                           # 방향 지정·차지 중: 노릴 수 있는 표적 강조
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		draw_arc(hc, 270.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.55, focus_glow * (0.6 if in_reach else 0.25)), 3.0)


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
			if atk.get("kind", "") == "swing" and atk.get("arm", -1) == a and atk["phase"] == "swing":
				# 휩쓰는 팔 = 패리할 수 있는 것 → 금색 테두리
				draw_line(sh, el, Color(C_PARRY, 0.7), 5.0)
				draw_line(el, f, Color(C_PARRY, 0.7), 5.0)
				draw_arc(f, FIST_R + 4.0, 0.0, TAU, 24, Color(C_PARRY, 0.8), 5.0)
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


## 페이즈 1 표적: 포대·팔꿈치에 맥동하는 약점 표시 + 손상 단계(체력바 대신)
func _draw_part_marks() -> void:
	if phase != 1 or dead:
		return
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	for i in 4:
		if not part_alive(i):
			continue
		var p := part_pos(i)
		var r: float = PART_R[i]
		if focus_glow > 0.0:                    # 방향 지정·차지 중: 노릴 수 있는 표적 강조 (사거리 안이면 더 밝게)
			var in_reach := p.distance_to(focus_from) <= focus_reach
			draw_circle(p, r * 1.7, Color(C_HEART, focus_glow * (0.3 if in_reach else 0.12) * (0.6 + 0.4 * pulse)))
			if in_reach:
				draw_arc(p, r * 1.7, 0.0, TAU, 32, Color(1.0, 0.85, 0.55, focus_glow * 0.8), 3.0)
		if i >= 2 and is_staggered(i - 2):      # 받아치기로 멈춘 팔: 관절이 크게 빛난다
			draw_circle(p, r * 1.3 + 8.0 * pulse, Color(1.0, 0.75, 0.4, 0.35))
		var flick := 1.0
		if part_stage[i] >= 3:                  # 거의 부서짐: 약점 빛이 깜빡인다
			flick = 0.4 + 0.6 * float(int(t * 9.0 + i) % 3 != 0)
		var core := Color(C_HEART, 0.85 * flick).lerp(Color.WHITE, part_flash[i])
		draw_circle(p, r * 0.45 + 4.0 * pulse, Color(C_HEART, (0.18 + 0.12 * pulse + (0.15 if strike_glow else 0.0)) * flick))
		draw_circle(p, r * 0.28, core)
		var edge := Color(1.0, 0.85, 0.5, 0.9) if strike_glow else Color(C_PLATE_EDGE, 0.9)
		draw_arc(p, r + 6.0, 0.0, TAU, 32, edge, 3.0)
		_draw_part_damage(i, p, r, pulse)


## 부위 손상: 1 긁힘 → 2 빛나는 균열 + 불꽃 → 3 떨어져 나간 자리 + 연기
func _draw_part_damage(i: int, p: Vector2, r: float, pulse: float) -> void:
	var st: int = part_stage[i]
	if st <= 0:
		return
	var base := i * 1.7
	for k in 3:
		var a := base + k * 2.1
		var c0 := p + Vector2.from_angle(a) * r * 0.55
		draw_line(c0, c0 + Vector2.from_angle(a + 1.9) * r * 0.5, Color(0.75, 0.78, 0.84, 0.6), 2.5)
	if st >= 2:
		for k in 3:
			var a := base + 0.6 + k * 2.1
			var q0 := p + Vector2.from_angle(a) * r * 0.3
			var q1 := q0 + Vector2.from_angle(a + 0.4) * r * 0.4
			var q2 := q1 + Vector2.from_angle(a - 0.3) * r * 0.4
			draw_polyline(PackedVector2Array([q0, q1, q2]), Color(1.0, 0.55, 0.25, 0.6 + 0.35 * pulse), 3.0)
		if fmod(t * 3.0 + i * 0.37, 1.0) < 0.25:
			for k in 3:
				var sa := t * 11.0 + k * 2.0 + i
				draw_circle(p + Vector2.from_angle(sa) * r * (0.6 + 0.4 * fmod(t * 4.0 + k, 1.0)), 2.5, Color(1.0, 0.85, 0.5))
	if st >= 3:
		var nc := p + Vector2.from_angle(base + 2.5) * r * 0.85
		draw_circle(nc, r * 0.35, C_CAVITY)
		draw_circle(nc, r * 0.18, Color(C_HEART, 0.35 + 0.3 * pulse))
		for k in 4:
			var life := fmod(t * 0.6 + k * 0.25 + i * 0.13, 1.0)
			var sp := p + Vector2(sin(t + k * 1.7) * 14.0 + (k - 1.5) * 10.0, -r * 0.5 - life * 160.0)
			draw_circle(sp, 12.0 + life * 26.0, Color(0.32, 0.33, 0.36, 0.45 * (1.0 - life)))


func _draw_shards() -> void:
	for sd in shards:
		var pts: PackedVector2Array = sd["pts"]
		draw_set_transform(sd["pos"], float(sd["rot"]))
		draw_colored_polygon(pts, C_STEEL)
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, C_STEEL_DARK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0)


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
		if beam_glow > 0.0:                          # 레이저: 보랏빛으로 달아오른다
			draw_circle(e, 30.0 + beam_glow * 40.0, Color(C_UNPARRY, 0.35 * beam_glow))
			draw_circle(e, 8.0 + beam_glow * 10.0, Color(C_UNPARRY_CORE, beam_glow))


func _draw_telegraphs() -> void:
	if atk.get("kind", "") == "beam":
		_draw_beam()
	if atk.get("kind", "") == "erupt" and int(atk["fired"]) < ERUPT_GLOBS:
		# 용암 분출 경고: 분출 지점의 용암이 부글거리고, 솟을 높이까지 희미한 기둥
		var k := clampf(float(atk["t"]) / (STOMP_LIFT_TIME + STOMP_SLAM_TIME), 0.0, 1.0)
		var h: float = atk["h"]
		for x in atk["spots"]:
			var sx: float = x
			var bub := PackedVector2Array()
			for j in 20:
				var a := TAU * j / 20.0
				bub.append(Vector2(sx + cos(a) * (40.0 + 50.0 * k), -6.0 + sin(a) * (8.0 + 6.0 * k)))
			draw_colored_polygon(bub, Color(C_LAVA, 0.35 + 0.4 * k))
			draw_line(Vector2(sx, -10.0), Vector2(sx, -h), Color(C_WARN, 0.05 + 0.15 * k), 26.0)
			for j in 3:
				var bx := sx + sin(t * 9.0 + j * 2.1) * 35.0
				draw_circle(Vector2(bx, -10.0 - fmod(t * 120.0 + j * 30.0, 50.0)), 6.0, Color(1.0, 0.6, 0.25, 0.7 * k))
	if atk.get("kind", "") == "volley" and float(atk["t"]) < VOLLEY_CHARGE + 0.5:
		var c: int = atk["cannon"]
		var org: Vector2 = atk["origin"]
		var gl := eye_glow if c < 0 else cannon_glow[c]
		for k in range(-2, 3):                       # 곧 날아올 5갈래 조준선
			var d := Vector2.from_angle(float(atk["aim"]) + k * 0.28)
			draw_line(org, org + d * 900.0, Color(C_WARN, 0.05 + 0.22 * gl), 2.0)
	if atk.get("kind", "") == "swing" and ["prep", "set", "warn"].has(atk["phase"]):
		# 실제 판정과 같은 범위: 준비 중엔 옅은 윤곽, 고정되면 또렷한 윤곽, 경고에서는 붉게 점멸
		var a: int = atk["arm"]
		var s := 1.0 if a == 1 else -1.0
		var sh: Vector2 = SHOULDERS[a]
		var ph: String = atk["phase"]
		var th0: float = atk["th0"]
		var th1: float = atk["th1"]
		var area := swing_area(a, th0, th1)
		var outline := area.duplicate()
		outline.append(area[0])
		if ph == "warn":
			var blink := 0.5 + 0.5 * sin(t * 26.0)
			var kw := clampf(float(atk["t"]) / SWING_WARN, 0.0, 1.0)
			draw_colored_polygon(area, Color(C_WARN, (0.14 + 0.3 * blink) * (0.6 + 0.4 * kw)))
			draw_polyline(outline, Color(1.0, 0.5, 0.4, 0.45 + 0.5 * blink), 4.0)
		elif ph == "set":
			draw_colored_polygon(area, Color(C_WARN, 0.06))
			draw_polyline(outline, Color(1.0, 0.85, 0.75, 0.75), 3.0)
		else:
			draw_polyline(outline, Color(C_WARN, 0.2 + 0.2 * float(atk["t"]) / SWING_PREP), 2.0)
		if ph != "prep":
			for f in [0.3, 0.5, 0.7]:                # 휩쓰는 방향을 가리키는 화살표
				var th2: float = lerpf(th0, th1, f)
				var radial := Vector2(s * cos(th2), sin(th2))
				var tangent := Vector2(-s * sin(th2), cos(th2))
				var at := sh + radial * SWING_L * 0.8
				draw_colored_polygon(PackedVector2Array([at + tangent * 40.0, at - tangent * 12.0 + radial * 26.0, at - tangent * 12.0 - radial * 26.0]), Color(1, 0.9, 0.7, 0.6))


## 레이저가 지나갈 부채꼴을 각도 구간별로 칠한다 (a0 → a1 로 옅어짐). 벽·바닥까지 이어져 머리가 안 보여도 보인다
func _beam_fan(from_th: float, to_th: float, a0: float, a1: float, n: int) -> void:
	var prev := beam_end(from_th)
	for j in range(1, n + 1):
		var cur := beam_end(lerpf(from_th, to_th, j / float(n)))
		draw_colored_polygon(PackedVector2Array([HEAD_POS, prev, cur]), Color(C_UNPARRY, lerpf(a0, a1, (j - 0.5) / n)))
		prev = cur


## 눈 레이저 (패리 불가 = 검붉은 보라)
func _draw_beam() -> void:
	var wind: bool = atk["phase"] == "wind"
	var th: float = atk["th"]
	var kk := clampf(float(atk["t"]) / BEAM_WIND, 0.0, 1.0)
	var blink := 0.65 + 0.35 * sin(t * 24.0)
	# 지나갈 부채꼴 (남은 구간). 가까운 쪽이 진하다
	if wind:
		_beam_fan(BEAM_FROM, BEAM_TO, (0.18 + 0.2 * kk) * blink, 0.04, 48)
	else:
		_beam_fan(th, BEAM_TO, 0.3, 0.04, maxi(4, int(48.0 * (th - BEAM_TO) / (BEAM_FROM - BEAM_TO))))
	# 벽·바닥을 따라가는 도착 경로 띠 + 일정 간격의 눈금선
	var path := PackedVector2Array()
	var from_th := BEAM_FROM if wind else th
	for j in 41:
		path.append(beam_end(lerpf(from_th, BEAM_TO, j / 40.0)))
	draw_polyline(path, Color(C_UNPARRY_CORE, (0.18 + 0.3 * kk) if wind else 0.5), 10.0)
	for j in 13:
		var tth := lerpf(BEAM_FROM, BEAM_TO, j / 12.0)
		if wind or tth < th:
			draw_line(HEAD_POS, beam_end(tth), Color(C_UNPARRY, 0.14 + 0.1 * kk), 3.0)
	if wind:
		# 시작선 + 긋는 방향 화살표
		for e in EYES:
			draw_line(e, beam_end(BEAM_FROM), Color(C_UNPARRY_CORE, (0.3 + 0.6 * kk) * blink), 3.0 + 7.0 * kk)
		for f in [0.2, 0.4, 0.6, 0.8]:
			var ath: float = lerpf(BEAM_FROM, BEAM_TO, f)
			var radial := Vector2.from_angle(ath)
			var tangent := Vector2.from_angle(ath - PI * 0.5)
			var at := HEAD_POS + radial * 700.0
			draw_colored_polygon(PackedVector2Array([at + tangent * 46.0, at - tangent * 14.0 + radial * 28.0, at - tangent * 14.0 - radial * 28.0]), Color(C_UNPARRY_CORE, 0.25 + 0.5 * kk))
		return
	var end := beam_end(th)
	var fl := randf_range(0.9, 1.1)
	for e in EYES:
		draw_line(e, end, Color(C_UNPARRY, 0.22), 70.0 * fl)
		draw_line(e, end, Color(C_UNPARRY, 0.75), 30.0 * fl)
		draw_line(e, end, Color(C_UNPARRY_CORE, 0.95), 9.0)
	draw_circle(end, 60.0 * fl, Color(C_UNPARRY, 0.35))
	draw_circle(end, 26.0, Color(C_UNPARRY_CORE, 0.9))


## 탄 = 패리할 수 있는 것 → 금색. 용암 덩어리는 붉은 겉불 + 금색 심
func _draw_bolts() -> void:
	for b in bolts:
		var p: Vector2 = b["pos"]
		var v: Vector2 = b["vel"]
		var outer := C_LAVA if b.has("lava") else C_PARRY
		draw_line(p, p - v.normalized() * 50.0, Color(outer, 0.35), 10.0)
		draw_circle(p, BOLT_R * 1.8, Color(outer, 0.22))
		draw_circle(p, BOLT_R, C_PARRY)
		draw_circle(p, BOLT_R * 0.5, Color(1, 1, 0.9))

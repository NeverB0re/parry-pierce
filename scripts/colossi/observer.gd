extends "res://scripts/colossus_base.gd"
## 콜로서스 ① 관측자 (기본 조작 학습, 첫 보스). 헤일로를 진 기사형 거인 (docs/BOSS_observer.md).
## 코어(가슴 금고)는 처음부터 드러나 있다 — 세 가지 기본 동작이 각각 코어를 친다:
##   금빛 탄 패리 → 리버스 드라이브로 되꽂기 · 떠다니는 대검 요격 → 쳐낸 검이 코어에 꽂힘 · 방패 동심원(패리 불가) 완전 동조 → 강한 일격
## 부위는 어깨포 둘뿐 (부목표: 부수면 그쪽 탄이 멎는다). 코어 장갑(3×3 판)이 다 떨어지면 맨 결정 — 직접 한 대면 터진다.
## 페이즈는 1 그대로 (개방 연출 없음): 부위와 코어를 함께 노린다.
## 공격: 유도탄(어깨포마다 큰 유도탄 한 발, 둘 다 부서지면 방패 보석) · 헤일로 사격 · 대검 긋기(요격) · 방패 동심원(패리 불가)
## 다음 패턴은 필드(적 탄·자리를 내준 공격)가 빌 때까지 기다렸다가 나온다 (초보자가 정신없지 않게, CLEAR_WAIT 까지)
## 고르기는 한 바퀴씩 (PATTERNS 를 섞어 차례로 다 쓴 뒤 다시 섞는다): 고르게, 그러나 순서는 매번 다르게
## 튜토리얼 보스 (docs/BOSS_observer.md 4.1): 처음엔 잠들어 있다 (패턴 없음, 눈·헤일로가 꺼져 있음) — 플레이어가 둘러보며
## 심장을 자유롭게 때린다. 심장에 WAKE_DMG 가 쌓이면 깨어나 INTRO 순서(유도탄 → 헤일로 → 동심원 → 대검)로 한 번씩 보여 준 뒤 바퀴로 돈다
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const MeleeWarn := preload("res://scripts/melee_warn.gd")
const HaloShot := preload("res://scripts/attacks/halo_shot.gd")
const Greatsword := preload("res://scripts/attacks/greatsword.gd")
const Rings := preload("res://scripts/attacks/rings.gd")
const Homing := preload("res://scripts/attacks/homing.gd")

# ── 구조 ───────────────────────────────────────────────
const HEART_POS := Vector2(0, -1790)        # 동력 코어 중심 (가슴 갑옷에 박힌 하트 컷 보석)
const ARMOR_HP := 240                       # 장갑 체력 (v0.84: 160 → 208 배운 걸 익히고 즐길 시간, v0.88: +10%, v0.96: 클리어 1:45 목표 — 늘 드러난 코어, 초당 2.2쯤). 다 부서져도 피해가 코어로 넘어가지 않는다
const CORE_R := 62.0                        # 금고 안 결정 반지름
# 하트 컷 보석 외곽선 (단위, 직선 12각): 가운데 오목한 위 + 두 둥근 어깨 + 아래 뾰족한 끝
const HEART_SHAPE := [
	Vector2(0.0, -0.55), Vector2(0.38, -0.95), Vector2(0.78, -0.88), Vector2(1.0, -0.5), Vector2(0.95, -0.05), Vector2(0.5, 0.5),
	Vector2(0.0, 1.0), Vector2(-0.5, 0.5), Vector2(-0.95, -0.05), Vector2(-1.0, -0.5), Vector2(-0.78, -0.88), Vector2(-0.38, -0.95)]
const HEART_S := 165.0                      # 보석 크기
const HEART_IN := 0.58                      # 안쪽 심 크기 (바깥 면 = 장갑)
const PLATE_N := 12                         # 바깥 면 수 (외곽선 변마다 하나)
const PLATE_ORDER := [0, 6, 3, 9, 1, 7, 4, 10, 2, 8, 5, 11]   # 깨져 떨어지는 순서 (흩어지게)

const HIPS := [Vector2(-210, -1020), Vector2(210, -1020)]
const FOOT_REST := [Vector2(-230, 0), Vector2(230, 0)]
const LEG_SEG := 470.0
const SHOULDERS := [Vector2(-470, -2260), Vector2(470, -2260)]
const FIST_IDLE := [Vector2(-600, -1100), Vector2(600, -1100)]
const ARM_SEG := 620.0
const FIST_R := 95.0                 # 손 (그림)
# 떠다니는 대검: 회전축(sword_piv)에서 HILT_GAP 떨어진 날밑부터 칼끝까지가 날 (판정 반폭 BLADE_W)
const SWORD_REST := Vector2(840, -2050)
const HILT_GAP := 150.0
const HAND_UP := Vector2(760, -2850)         # 대검을 겨눌 때 오른손을 높이 든다
const HAND_DOWN := Vector2(800, -1350)       # 그을 때 내리친다
const BLADE_AT := 70.0               # 그림: 손잡이 끝 ~ 날밑
const BLADE_L := 820.0               # 몸 높이에 맞먹는 대검
const BLADE_W := 58.0
# 방패 (왼손, 휘두르지 않는다): 가운데 수정에서 동심원
const SHIELD_OFF := 60.0             # 손에서 방패 가운데까지 (팔 방향)
const SHIELD_HALF := Vector2(280.0, 600.0)  # 방패 반폭 · 반길이: 몸 옆을 다 가리는 거대한 탑 방패
const MUZZLES := [Vector2(-640, -2470), Vector2(640, -2470)]   # 양어깨 포대의 포구
const EYES := [Vector2(-62, -2605), Vector2(62, -2605)]

# ── 외부 시스템 ────────────────────────────────────────
const PART_HP := 30                         # 0 왼쪽 어깨포, 1 오른쪽 어깨포
const PART_R := [55.0, 55.0]

# 헤일로: 머리 뒤 렌즈 고리 (헤일로 사격 발사점, 부서지지 않음)
const HALO_C := Vector2(0, -2485)
const HALO_R := 860.0
const LENSES := 16

# ── 공격 고르기 ────────────────────────────────────────
const PATTERNS := ["homing", "halo", "sword", "rings"]   # 한 바퀴에 하나씩
const MISSILE_STEER := 2.6           # 유도탄 선회력 (앞쪽 목표만, 지나치면 돌아오지 않는다)
const CLEAR_WAIT := 5.0              # 필드가 비길 기다리는 최대 시간 (오래 남는 탄 때문에 멈추지 않게)
const SWORD_HOLD := 2.5              # 대검 차례에 탄이 걷히길 기다리는 최대 시간
const INTRO := ["homing", "halo", "rings", "sword"]   # 깨어난 뒤 한 번씩 보여 주는 순서 (패리 → 패리 → 패리 불가 → 요격)
const WAKE_DMG := 12                 # 심장에 이만큼 쌓이면 깨어난다 (v0.95: 20 → 12, 차지 강습 네 번쯤)
const WAKE_FALLBACK := 40.0          # 아무것도 안 해도 이만큼 지나면 깨어난다 (막힘 방지)
const WAKE_TIME := 1.4               # 깨어나는 연출 (눈·헤일로가 켜지고 대검이 떠오른다)

# ── 색 ─────────────────────────────────────────────────
const C_BODY := Color(0.075, 0.08, 0.10)
const C_BODY_DARK := Color(0.045, 0.05, 0.065)
const C_RIM := Color(0.48, 0.52, 0.6)
const C_CLOAK := Color(0.05, 0.045, 0.07)
const C_BONE := Color(0.78, 0.75, 0.68)
const C_EYE := Color(1.0, 0.78, 0.42)
const C_UNPARRY := Color(0.6, 0.08, 0.36)       # 패리 불가 = 검붉은 보라 (회피 돌진으로만 피한다)
const C_UNPARRY_CORE := Color(1.0, 0.62, 0.86)

var feet: Array[Vector2] = []
var fists: Array[Vector2] = []
var debris: Array[Dictionary] = []   # 부서져 떨어진 부위
var eye_glow := 0.0
var shield_glow := 0.0               # 동심원을 모으는 방패 수정 (보라)
var last := ""                       # 직전 패턴 (연달아 같은 것을 덜 고른다)
var cannon_glow: Array[float] = [0.0, 0.0]   # 발사 전 포구가 달아오르는 정도
var sword_piv := SWORD_REST          # 대검 회전축 (손잡이 쪽 끝)
var sword_ang := PI * 0.5            # 대검 방향 (회전축 → 칼끝)
var halo_glow: Array[float] = []     # 렌즈별 발사 전 발광
var bag: Array[String] = []          # 이번 바퀴에 남은 패턴
var sword_hold := 0.0
var clear_wait := 0.0
var awake := false
var wake_k := 0.0                    # 깨어난 정도 (그림: 눈·헤일로 밝기, 대검 높이)
var sleep_t := 0.0
var intro: Array[String] = []


func _init() -> void:
	attack_gap = Vector2(0.5, 0.9)               # 멍때릴 틈 없이 (기본 1.0~1.8 은 길었다)


func _ready() -> void:
	var outline := []                                  # 판정 = 보석 테 바깥
	for q in HEART_SHAPE:
		outline.append(q * HEART_S * 1.1)
	core = ArmoredCore.new(self, HEART_POS, outline, ARMOR_HP, Rect2(), 0, 11)   # 장갑 = 보석 바깥 면 (_draw_core)
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
	shield_glow = 0.0
	cannon_glow = [0.0, 0.0]
	sword_piv = SWORD_REST
	sword_ang = sword_rest_ang()
	halo_glow.clear()
	for k in LENSES:
		halo_glow.append(0.0)
	bag.clear()
	sword_hold = 0.0
	clear_wait = 0.0
	awake = false
	wake_k = 0.0
	sleep_t = 0.0
	intro.assign(INTRO)


# ── 외부 시스템 (어깨포 둘) ─────────────────────────────
func part_count() -> int:
	return 2


func part_max_hp(_i: int) -> int:
	return PART_HP


func part_radius(i: int) -> float:
	return PART_R[i]


func cannon_base(c: int) -> Vector2:
	var s := 1.0 if c == 1 else -1.0
	return SHOULDERS[c] + Vector2(s * 60.0, -110.0)


func part_pos(i: int) -> Vector2:
	return cannon_base(i).lerp(MUZZLES[i], 0.55)


## 코어는 처음부터 드러나 있다: 부위를 다 부숴도 개방 연출은 없다
func _should_open() -> bool:
	return false


## 돌진 판정: 어깨포 → 심장 순 (잠든 동안은 어깨포가 꺼져 있어 심장만)
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead:
		return {}
	var best := {}
	var best_d := INF
	for i in part_count():
		if not part_alive(i) or not awake:
			continue
		var d := p.distance_to(part_pos(i))
		if d < r + part_radius(i) and d < best_d:
			best_d = d
			var n := p - part_pos(i)
			best = {"kind": "part", "idx": i, "n": n.normalized() if n.length() > 0.1 else Vector2.UP}
	if not best.is_empty():
		return best
	return core.hit(p, r)


## 반사탄·HUD 화살표가 노리는 곳 = 코어
func target_pos(_from: Vector2) -> Vector2:
	return core.center


func assist_targets(from := Vector2.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	for i in part_count():
		if part_alive(i) and awake:
			out.append({"pos": part_pos(i), "r": part_radius(i)})
	out.append({"pos": core.center, "r": core_assist_r})
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


## 잠든 동안은 어깨포 표적 테두리를 그리지 않는다 (처음엔 심장만 노리게)
func _draw_part_marks() -> void:
	if awake:
		super()


## 체력 게이지: 코어 장갑만 (청록 보호 몫 없음)
func gauge_values() -> Vector3:
	return Vector3(core.armor_hp, ARMOR_HP, ARMOR_HP)


func _draw_gauge() -> void:
	if dead or gauge_vis <= 0.0:
		return
	var vis := minf(1.0, gauge_vis / GAUGE_FADE)
	var hc := HEART_POS
	var R := gauge_radius()
	var top := -PI * 0.5
	var w := GAUGE_W * 0.7 * (1.0 + 0.5 * gauge_hit)
	var hp := float(core.armor_hp)
	draw_arc(hc, R, 0.0, TAU, 96, Color(0.03, 0.04, 0.05, 0.75 * vis), w + 6.0)
	if gauge_lag > hp:
		draw_arc(hc, R, top + TAU * hp / ARMOR_HP, top + TAU * gauge_lag / ARMOR_HP, 48, Color(1, 1, 1, 0.85 * vis), w)
	if hp > 0.0:
		var red := Color(C_HEART, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
		red.a *= vis
		draw_arc(hc, R, top, top + TAU * hp / ARMOR_HP, 64, red, w)
	else:
		draw_arc(hc, R, 0.0, TAU, 64, Color(1.0, 0.95, 0.7, (0.3 + 0.4 * float(int(t * 8.0) % 2)) * vis), 3.0)


func gauge_radius() -> float:
	return HEART_S * 1.36 + 20.0


# ── 무기 ───────────────────────────────────────────────
## 쉬는 대검: 칼끝을 아래로, 플레이어 쪽으로 살짝 기운다 (잠든 동안은 축 늘어져 기울어 있다)
func sword_rest_ang() -> float:
	return PI * 0.5 + clampf((look_at.x - SWORD_REST.x) / 2000.0, -0.25, 0.25) * wake_k + 0.35 * (1.0 - wake_k)


## 깨어난다: 눈·헤일로가 켜지고 대검이 떠오른 뒤 첫 패턴
func wake() -> void:
	if awake:
		return
	awake = true
	next_t = WAKE_TIME
	emit(Ev.WAKE, EYES[0].lerp(EYES[1], 0.5))


## 헤일로 렌즈 k 의 위치 (천천히 돈다, _draw_halo 와 같다)
func lens_pos(k: int) -> Vector2:
	return HALO_C + Vector2.from_angle(k * TAU / LENSES + t * 0.06) * HALO_R


func sword_tip() -> Vector2:
	return sword_piv + Vector2.from_angle(sword_ang) * (HILT_GAP + BLADE_L)


func shield_dir() -> Vector2:
	return (fists[0] - SHOULDERS[0]).normalized()


func shield_center() -> Vector2:
	return fists[0] + shield_dir() * SHIELD_OFF


func _sword_busy() -> bool:
	return atk != null and atk.kind == "sword"


# ── 몸 ─────────────────────────────────────────────────
func foot_rect(i: int) -> Rect2:
	var f := feet[i]
	return Rect2(f.x - 130.0, f.y - 110.0, 260.0, 110.0)


func knee_of(i: int) -> Vector2:
	var ankle := feet[i] + Vector2(0, -100)
	return _joint(HIPS[i], ankle, LEG_SEG, Vector2(1.0 if i == 1 else -1.0, 0))


func elbow_of(a: int) -> Vector2:
	return _arm_bent(a)


## 팔꿈치: 항상 팔 진행 방향의 같은 쪽(바깥)으로 굽힌다 → 팔이 돌아도 관절이 반대편으로 튀지 않는다
func _arm_bent(a: int) -> Vector2:
	var sh: Vector2 = SHOULDERS[a]
	var d := fists[a] - sh
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, ARM_SEG * ARM_SEG - half * half))
	var perp := d.orthogonal().normalized() * (1.0 if a == 1 else -1.0)
	return sh + d * 0.5 + perp * h


## 두 마디 관절 위치. prefer 쪽으로 굽힌다.
static func _joint(a: Vector2, b: Vector2, seg: float, prefer: Vector2) -> Vector2:
	var d := b - a
	var half := d.length() * 0.5
	var h := sqrt(maxf(0.0, seg * seg - half * half))
	var perp := d.orthogonal().normalized()
	if perp.dot(prefer) < 0.0:
		perp = -perp
	return (a + b) * 0.5 + perp * h


# ── 진행 ───────────────────────────────────────────────
## 부서진 어깨포가 떨어져 나간다
func _on_part_broken(i: int) -> void:
	var s := 1.0 if i % 2 == 1 else -1.0
	var base := cannon_base(i)
	var mz: Vector2 = MUZZLES[i]
	debris.append({"pos": (base + mz) * 0.5, "half": (mz - base) * 0.5, "w": 54.0,
		"vel": Vector2(s * 260.0, -380.0), "rot": 0.0, "rotv": s * 3.5, "rest": false})


func _step_effects(dt: float) -> void:
	_step_debris(dt)


func _step_phase(dt: float) -> void:
	eye_glow = move_toward(eye_glow, 0.0, dt * 2.0)
	shield_glow = move_toward(shield_glow, 0.0, dt * 2.0)
	for k in halo_glow.size():
		halo_glow[k] = move_toward(halo_glow[k], 0.0, dt * 1.5)
	for i in 2:
		cannon_glow[i] = move_toward(cannon_glow[i], 0.0, dt * 2.0)
	if not awake:                                        # 잠들어 있다: 심장에 피해가 쌓이면(또는 오래 지나면) 깨어난다
		sleep_t += dt
		if ARMOR_HP - core.armor_hp >= WAKE_DMG or sleep_t >= WAKE_FALLBACK:
			wake()
	wake_k = move_toward(wake_k, 1.0 if awake else 0.0, dt / WAKE_TIME)
	if not _sword_busy():                                # 쉬는 대검: 제자리에서 천천히 오르내린다 (잠든 동안은 낮게 가라앉아 있다)
		sword_piv = SWORD_REST + Vector2(sin(t * 0.7) * 14.0, sin(t * 1.1) * 26.0 * wake_k + 420.0 * (1.0 - wake_k))
		sword_ang = lerp_angle(sword_ang, sword_rest_ang(), 1.0 - exp(-2.0 * dt))
	var reach: Vector2 = FIST_IDLE[1]                    # 오른손: 대검은 원격 조종 — 손은 높이 들었다가(자세) 긋는 순간 내리친다 (그림만)
	var rate := 4.0
	if _sword_busy():
		match atk.phase:
			"rise", "set", "warn":
				reach = HAND_UP
				rate = 5.0
			"swing", "hold":
				reach = HAND_DOWN
				rate = 16.0
	fists[1] = fists[1].lerp(reach, 1.0 - exp(-rate * dt))


## 한 바퀴씩 고른다: 패턴 다섯을 섞어 차례로 쓰고, 다 쓰면 다시 섞는다 (바퀴가 바뀌어도 같은 패턴이 연달아 나오지 않게).
## 대검(근접)은 날아오는 탄이 걷힌 뒤에만 — 제 차례에 잠깐(SWORD_HOLD) 기다리고, 그래도 안 걷히면 다음 패턴을 먼저 쓴다.
## 대검만 남았으면 기다린 뒤 그대로 긋는다 (바퀴 밖의 탄막을 끼우지 않는다: 탄막만 이어지던 v0.81 버그)
## 심장이 깎일수록 사나워진다: 패턴 진행 최대 +20%, 탄 속도 최대 +15% (v0.107 — 모든 보스가 진행할수록 빨라지게)
const FURY_TEMPO := 0.2
const FURY_BOLT := 0.15


func pattern_scale() -> float:
	return super() * (1.0 + FURY_TEMPO * core.frac())


func bolt_mult() -> float:
	return super() * (1.0 + FURY_BOLT * core.frac())


func _choose(ppos: Vector2) -> void:
	if not awake:                                        # 잠든 동안은 공격하지 않는다
		next_t = 0.3
		return
	if _field_busy() and clear_wait < CLEAR_WAIT:       # 앞 패턴의 탄이 다 사라질 때까지 기다린다
		clear_wait += 0.2
		next_t = 0.2
		return
	var list: Array[String] = intro if not intro.is_empty() else bag   # 깨어난 직후엔 INTRO 순서대로
	if list.is_empty():
		bag.assign(PATTERNS)
		bag.shuffle()
		if bag[0] == last and bag.size() > 1:
			bag.push_back(bag.pop_front())
		list = bag
	var kind: String = list[0]
	if kind == "sword" and not shots_clear(ppos):
		if sword_hold < SWORD_HOLD:                     # 제 차례에서 잠깐 기다린다 (순서가 늘 맨 뒤로 밀려 뻔해지지 않게)
			sword_hold += 0.15
			next_t = 0.15
			return
		if list.size() > 1:                             # 그래도 안 걷히면 다음 패턴 먼저 (대검은 이번 바퀴에 남는다)
			kind = list[1]
	sword_hold = 0.0
	clear_wait = 0.0
	list.erase(kind)
	last = kind
	match kind:
		"halo":
			var hs := HaloShot.new()
			start_attack(hs)
			hs.pick(ppos)
		"rings":
			start_attack(Rings.new(shield_center()))
		"sword":
			var gs := Greatsword.new()
			start_attack(gs)
			gs.aim_at(ppos)
		"homing":
			var hm := Homing.new()
			hm.speed = Homing.SPEED * 1.15                  # 플레이어 쪽으로 쏘고, 날아오는 동안 앞의 목표를 쫓는다
			hm.steer = MISSILE_STEER
			start_attack(hm)


## 필드에 적 탄이나 자리를 내준 공격(퍼지는 동심원)이 남아 있는가
func _field_busy() -> bool:
	if not lingering.is_empty():
		return true
	for i in shots.size():
		if shots.mine[i] == 0:
			return true
	return false


## 유도탄 발사점 (homing.gd): 살아 있는 어깨포의 포구마다 한 발, 둘 다 부서지면 방패 보석(-1)
func homing_origins() -> Array:
	var out := []
	for i in 2:
		if part_alive(i):
			out.append([i, MUZZLES[i]])
	if out.is_empty():
		out.append([-1, shield_center()])
	return out


## 발사 전 발광: -1 = 방패 보석 금빛(유도탄, 눈도 같이), -4 = 방패 보석 보라(동심원), 0·1 = 포구
func set_glow(c: int, v: float) -> void:
	if c == -4:
		shield_glow = v
	elif c < 0:
		eye_glow = v
	else:
		cannon_glow[c] = v


func glow_of(c: int) -> float:
	if c == -4:
		return shield_glow
	return eye_glow if c < 0 else cannon_glow[c]


func _step_debris(dt: float) -> void:
	for d in debris:
		if d["rest"]:
			continue
		var v: Vector2 = d["vel"]
		v.y += 1500.0 * dt
		d["vel"] = v
		var pp: Vector2 = d["pos"] + v * dt
		var rot: float = float(d["rot"]) + float(d["rotv"]) * dt
		var half: Vector2 = d["half"]
		var reach := absf(half.rotated(rot).y) + float(d["w"]) * 0.5
		if pp.y + reach >= 0.0:                   # 바닥에 닿으면 그대로 눕는다
			pp.y = -reach
			d["rest"] = true
			emit(Ev.DEBRIS_LAND, Vector2(pp.x, 0))
		d["pos"] = pp
		d["rot"] = rot


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_halo()
	_draw_vents()
	_draw_cloak()
	_draw_legs()
	_draw_torso()
	_draw_seams()
	_draw_core()
	_draw_arms()
	_draw_head()
	_draw_floating_sword()
	_draw_part_marks()
	_draw_gauge()
	_draw_debris()
	_draw_shards()
	for a in active_attacks():
		a.draw()
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


## 동력 코어: 가슴 갑옷 한가운데 박힌 하트 컷 보석 (직선 면만). 두꺼운 강철 테(베젤)와 발톱 여섯 개가 붙들고,
## 위로 굵은 동력관 둘(대동맥처럼)이 몸속으로 이어져 맥박마다 빛이 흘러 들어간다.
## 보석 바깥 고리 면 열 장(FACETS)이 장갑 — 깎일수록 정해진 순서로 한 장씩 깨져 떨어지고, 그 자리로 안쪽의 붉게 뛰는 심이 드러난다.
## 장갑이 다 떨어지면 심만 남아 깜빡인다 (한 대면 터진다)
func _draw_core() -> void:
	var hc := HEART_POS
	if dead:
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	var f: float = core.frac()
	var beat := pow(maxf(0.0, sin(t * (3.2 + f * 3.0))), 6.0)          # 심장 박동 (짧게 쿵)
	for sd in [-1.0, 1.0]:                                             # 동력관 (대동맥): 보석 위에서 몸속으로
		var a := hc + Vector2(sd * 75.0, -150.0)
		var b := hc + Vector2(sd * 150.0, -330.0)
		var c := hc + Vector2(sd * 330.0, -390.0)
		draw_polyline(PackedVector2Array([a, b, c]), C_BODY_DARK, 58.0)
		draw_polyline(PackedVector2Array([a, b, c]), C_BODY, 38.0)
		draw_polyline(PackedVector2Array([a + Vector2(-8, 0), b + Vector2(-8, 0), c + Vector2(0, -10)]), Color(C_RIM, 0.35), 3.0)
		var u := fmod(t * (0.9 + f), 1.0)                              # 흘러가는 빛
		var p := a.lerp(b, u * 2.0) if u < 0.5 else b.lerp(c, u * 2.0 - 1.0)
		draw_circle(p, 12.0, Color(C_HEART, 0.5 + 0.4 * beat))
	var bezel := _heart(1.22)                                          # 강철 테
	draw_colored_polygon(bezel, C_BODY_DARK)
	draw_polyline(_closed(bezel), Color(C_RIM, 0.8), 5.0)
	draw_colored_polygon(_heart(1.05), Color(0.05, 0.02, 0.02))
	for q in [1, 3, 5, 7, 9, 11]:                                       # 발톱: 테에서 보석 가장자리를 물고 있다
		var o: Vector2 = bezel[q]
		var e := hc + (o - hc) * 0.86
		var n := (o - hc).orthogonal().normalized()
		draw_colored_polygon(PackedVector2Array([o + n * 26.0, e + n * 12.0, e - n * 12.0, o - n * 26.0]), C_BONE.darkened(0.35))
	if core.broken:                                                    # 껍질이 다 깨짐: 한 대면 터지는 심만
		_draw_exposed_core(hc, CORE_R, C_HEART)
	else:
		var inner := _heart(HEART_IN)                                  # 안쪽 심: 붉게 뛴다
		var glow := Color(C_HEART).lerp(Color(1.0, 0.25, 0.2), 0.4)
		draw_colored_polygon(inner, glow.darkened(0.45 - 0.35 * beat).lerp(Color.WHITE, core.flash * 0.5))
		for q in inner.size():                                         # 면 분할선
			draw_line(hc + Vector2(0, -20), inner[q], Color(1.0, 0.75, 0.6, 0.35 + 0.3 * beat), 2.0)
		draw_colored_polygon(_heart(0.22, Vector2(0, -20)), Color(1.0, 0.92, 0.85, 0.7 + 0.3 * beat))
		_soft_glow(hc, 260.0 + 60.0 * beat, C_HEART, 0.12 + 0.12 * beat)
	var left := plates_left()
	for n in range(PLATE_N - left, PLATE_N):                           # 남은 바깥 면 (장갑): 어두운 붉은 결정 + 빛 받는 모서리
		var k: int = PLATE_ORDER[n]
		var fc := _facet(k)
		var shade := 0.75 + 0.25 * cos(float(k) * 1.3)
		draw_colored_polygon(fc, Color(0.32, 0.06, 0.08).lerp(Color(0.5, 0.1, 0.12), shade - 0.75).lerp(Color.WHITE, core.flash * 0.3))
		draw_line(fc[0], fc[1], Color(1.0, 0.6, 0.55, 0.55), 3.0)
		draw_polyline(_closed(fc), Color(0.12, 0.02, 0.03), 2.0)
	var smoke := int(f * 6.0)                                          # 연기: 손상이 클수록 많이
	for k in smoke:
		var life := fmod(t * 0.5 + k * 0.17, 1.0)
		var sp := hc + Vector2(sin(k * 2.3 + t * 0.8) * 120.0, -140.0 - life * 190.0)
		draw_circle(sp, 14.0 + life * 30.0, Color(0.3, 0.3, 0.33, 0.35 * (1.0 - life)))
	if focus_glow > 0.0:                           # 방향 지정·차지 중: 노릴 수 있는 심장이 빛난다 (윤곽선 없이)
		var in_reach := hc.distance_to(focus_from) <= focus_reach + 200.0
		_soft_glow(hc, 330.0, C_HEART, focus_glow * (0.35 if in_reach else 0.12))


## 하트 컷 외곽선 (직선 10각, HEART_POS 기준 k 배, off 만큼 옮김)
func _heart(k: float, off := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in HEART_SHAPE:
		out.append(HEART_POS + off + q * HEART_S * k)
	return out


## 바깥 면 k (0~9): 외곽선의 k 번째 변과 안쪽 심 사이의 사다리꼴
func _facet(k: int) -> PackedVector2Array:
	var o := _heart(1.0)
	var i := _heart(HEART_IN)
	var k2 := (k + 1) % o.size()
	return PackedVector2Array([o[k], o[k2], i[k2], i[k]])


## 남은 바깥 면 수 (장갑 체력 비례)
func plates_left() -> int:
	if core.broken:
		return 0
	return int(ceil(float(core.armor_hp) / ARMOR_HP * PLATE_N - 0.001))


## 코어 피해: 깎인 만큼 바깥 면이 그 모양 그대로 튀어 떨어진다
func damage_core(dmg: int) -> bool:
	var before := plates_left()
	var broke := super(dmg)
	var after := plates_left()
	for n in range(PLATE_N - before, PLATE_N - after):
		var fc := _facet(PLATE_ORDER[n])
		var c := (fc[0] + fc[1] + fc[2] + fc[3]) * 0.25
		var pts := PackedVector2Array()
		for q in fc:
			pts.append(q - c)
		var out := (c - HEART_POS).normalized() if c.distance_to(HEART_POS) > 1.0 else Vector2.UP
		shards.append({"pos": c, "vel": out * randf_range(300.0, 480.0) + Vector2(0, -300), "rot": 0.0, "rotv": randf_range(-4.0, 4.0), "pts": pts, "col": Color(0.5, 0.1, 0.12)})
	return broke


func _draw_arms() -> void:
	for a in 2:
		var sh: Vector2 = SHOULDERS[a]
		var el := elbow_of(a)
		var f := fists[a]
		if not dead and not (a == 1 and _sword_busy()):   # 대기 모션: 손이 들썩인다 (그림만)
			f += Vector2(sin(t * 1.3 + a * 2.1) * 16.0, cos(t * 1.1 + a * 1.3) * 22.0)
		_cap(sh, el, 150.0, C_BODY)
		_cap(el, f, 125.0, C_BODY)
		draw_circle(el, 70.0, C_BODY_DARK)
		draw_arc(el, 70.0, 0.0, TAU, 20, Color(C_RIM, 0.6), 4.0)
		_draw_hand(f)
		if a == 0:
			_draw_shield(f, (f - sh).normalized())
		draw_circle(sh, 140.0, C_BODY_DARK)
		draw_arc(sh, 140.0, PI, TAU, 24, Color(C_BONE, 0.8), 7.0)
		var so := 1.0 if a == 1 else -1.0
		for q in 3:                                                     # 어깨 뼈 가시
			var base_a := PI + 0.5 + q * 0.55 if so < 0.0 else TAU - 0.5 - q * 0.55
			var bp := sh + Vector2.from_angle(base_a) * 130.0
			_cap(bp, bp + Vector2.from_angle(base_a) * (90.0 + 30.0 * (1 - q % 2)) + Vector2(0, -40), 16.0, C_BONE)
		_draw_cannon(a)


## 떠다니는 대검: 오른손에서 손잡이로 옅은 빛 줄기(조종). 긋기를 예고·긋는 동안 날이 진홍으로 달아오른다
func _draw_floating_sword() -> void:
	var d := Vector2.from_angle(sword_ang)
	var hot := 0.0
	if atk != null and atk.kind == "sword":
		match atk.phase:
			"warn":
				hot = 0.5 + 0.5 * sin(t * 18.0)
			"swing":
				hot = 1.0
			"set":
				hot = 0.35
	if not dead:
		var grip := sword_piv + d * (HILT_GAP - BLADE_AT - 60.0)
		var flick := 0.6 + 0.4 * sin(t * 7.0)
		draw_line(fists[1], grip, Color(C_EYE, 0.07 * flick), 26.0)
		draw_line(fists[1], grip, Color(C_EYE, 0.25 * flick), 3.0)
	_draw_sword(sword_piv + d * (HILT_GAP - BLADE_AT), d, hot)


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


## 대검: 손잡이 + 날밑 + 곧은 날(끝만 깎은 직선) + 가운데 홈. 그을 때 날 테두리가 진홍으로 달아오른다. f = 손잡이(날밑에서 BLADE_AT 뒤)
func _draw_sword(f: Vector2, d: Vector2, hot: float) -> void:
	var n := d.orthogonal()
	var g := f + d * BLADE_AT
	var tip := g + d * BLADE_L
	draw_line(f - d * 90.0, g, C_BODY_DARK, 40.0)                                   # 손잡이
	draw_colored_polygon(PackedVector2Array([f - d * 125.0, f - d * 95.0 + n * 30.0, f - d * 65.0, f - d * 95.0 - n * 30.0]), C_BONE)   # 자루 끝
	var blade := PackedVector2Array([g + n * BLADE_W, tip - d * 120.0 + n * BLADE_W * 0.85, tip, tip - d * 120.0 - n * BLADE_W * 0.85, g - n * BLADE_W])
	if hot > 0.0:
		draw_polyline(_closed(blade), Color(MeleeWarn.C, 0.25 * hot), 22.0)
	draw_colored_polygon(blade, Color(0.3, 0.32, 0.38).lerp(MeleeWarn.C, 0.25 * hot))
	draw_line(g + n * BLADE_W * 0.85, tip - d * 120.0 + n * BLADE_W * 0.75, Color(0.75, 0.8, 0.88, 0.9), 4.0)   # 빛 받는 날
	draw_line(g + d * 30.0, tip - d * 140.0, Color(0.12, 0.13, 0.16), 8.0)   # 가운데 홈
	if hot > 0.0:
		draw_polyline(_closed(blade), Color(MeleeWarn.C, 0.5 + 0.5 * hot), 5.0)
	var gp := PackedVector2Array([g + n * 150.0 - d * 20.0, g + n * 150.0 + d * 20.0, g - n * 150.0 + d * 20.0, g - n * 150.0 - d * 20.0])   # 날밑
	draw_colored_polygon(gp, C_BODY_DARK)
	draw_polyline(_closed(gp), Color(C_BONE, 0.7), 4.0)


## 탑 방패 (왼손): 모서리를 깎은 직사각 판 + 안쪽 판 + 가로 띠 + 가운데 수정(동심원 발사점).
## 동심원을 모을 때(shield_glow) 수정과 테두리가 보라로 차오른다
func _draw_shield(f: Vector2, d: Vector2) -> void:
	var ax := d
	var nx := ax.orthogonal()
	var c := f + d * SHIELD_OFF
	var hl := SHIELD_HALF.y
	var hw := SHIELD_HALF.x
	var ch := 110.0
	var outer := PackedVector2Array([
		c + ax * hl + nx * (hw - ch), c + ax * (hl - ch) + nx * hw, c - ax * (hl - ch) + nx * hw, c - ax * hl + nx * (hw - ch),
		c - ax * hl - nx * (hw - ch), c - ax * (hl - ch) - nx * hw, c + ax * (hl - ch) - nx * hw, c + ax * hl - nx * (hw - ch)])
	draw_colored_polygon(outer, C_BODY_DARK)
	var inner := PackedVector2Array()
	for q in outer:
		inner.append(c + (q - c) * 0.8)
	draw_colored_polygon(inner, C_BODY)
	draw_polyline(_closed(outer), Color(C_RIM, 0.75), 5.0)
	for k in [-0.55, 0.55]:                                            # 가로 띠
		var y: Vector2 = c + ax * hl * k
		draw_line(y + nx * hw * 0.8, y - nx * hw * 0.8, C_BODY_DARK, 20.0)
		draw_line(y + nx * hw * 0.8 + ax * 7.0, y - nx * hw * 0.8 + ax * 7.0, Color(C_RIM, 0.3), 2.0)
	var cr := PackedVector2Array([c + ax * 190.0, c + nx * 125.0, c - ax * 190.0, c - nx * 125.0])   # 가운데 수정
	var g := shield_glow
	if g > 0.0:                                                        # 모으는 중: 보라 빛이 수정으로 빨려 들고 테두리가 차오른다
		draw_circle(c, 220.0 + 260.0 * g, Color(C_UNPARRY, 0.18 * g))
		draw_polyline(_closed(outer), Color(C_UNPARRY_CORE, 0.6 * g), 6.0)
		for k in 6:
			var a := k * TAU / 6.0 + t * 0.5
			var u := fmod(t * 1.6 + k * 0.17, 1.0)
			draw_line(c + Vector2.from_angle(a) * lerpf(560.0, 170.0, u), c + Vector2.from_angle(a) * lerpf(500.0, 120.0, u), Color(C_UNPARRY_CORE, g * u), 4.0)
	var eg := eye_glow                                                 # 탄막을 쏠 때 (어깨포가 다 부서진 뒤): 금빛으로 달아오른다
	if eg > 0.0:
		draw_circle(c, 160.0 + 140.0 * eg, Color(C_EYE, 0.2 * eg))
	draw_colored_polygon(cr, C_UNPARRY.darkened(0.4).lerp(C_UNPARRY, g).lerp(C_EYE, eg))
	draw_colored_polygon(PackedVector2Array([c + ax * 90.0, c + nx * 56.0, c - ax * 90.0, c - nx * 56.0]), Color(C_UNPARRY_CORE, 0.35 + 0.15 * sin(t * 1.6) + 0.5 * g))
	draw_polyline(_closed(cr), Color(C_BONE, 0.6), 3.0)


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
		var on := 0.1 + 0.9 * wake_k                                   # 잠든 동안은 포구 불이 꺼져 있다
		draw_circle(mz + d * 20.0, 18.0 + 22.0 * g, Color(C_EYE, (0.12 + 0.5 * g) * on))
		draw_circle(mz + d * 20.0, 8.0 + 6.0 * g, Color(C_EYE, (0.55 + 0.45 * g) * on))
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
	var c := HALO_C
	var dim := 1.0 if not dead else maxf(0.0, 1.0 - death_t * 0.6)
	_soft_glow(c, 1450.0, C_EYE, 0.12 * dim)
	var r := HALO_R
	draw_arc(c, r, 0.0, TAU, 96, C_BODY_DARK, 46.0)                    # 고리 몸통
	draw_arc(c, r + 23.0, 0.0, TAU, 96, Color(C_RIM, 0.35), 3.0)
	draw_arc(c, r - 23.0, 0.0, TAU, 96, Color(C_RIM, 0.2), 2.0)
	for k in 6:                                                         # 고리를 받치는 지지대 (몸 뒤로 사라진다)
		var a := k * TAU / 6.0 + PI / 6.0
		draw_line(c + Vector2.from_angle(a) * 380.0, c + Vector2.from_angle(a) * (r - 20.0), Color(C_BODY_DARK, 0.9), 22.0)
	var to_p := (look_at - c).angle()
	for k in LENSES:                                                    # 렌즈 16개: 천천히 돌며 차례로 깜빡, 플레이어 쪽이 가장 밝다
		var a := k * TAU / LENSES + t * 0.06
		var p := lens_pos(k)
		var seq := 0.5 + 0.5 * sin(t * 2.2 - k * 0.8)
		var watch := maxf(0.0, cos(angle_difference(a, to_p))) ** 6
		var g := (0.25 + 0.45 * seq + 0.6 * watch) * dim * (0.12 + 0.88 * wake_k)   # 잠든 동안은 렌즈도 어둡다
		draw_circle(p, 34.0, C_BODY)
		draw_arc(p, 34.0, 0.0, TAU, 16, Color(C_RIM, 0.55), 3.0)
		draw_circle(p, 14.0 + 8.0 * watch, Color(C_EYE, minf(1.0, g)))
		if watch > 0.3:
			draw_circle(p, 48.0 + 30.0 * watch, Color(C_EYE, 0.12 * watch * dim))
		var hg: float = halo_glow[k] if k < halo_glow.size() else 0.0
		if hg > 0.0:                                                    # 헤일로 사격: 쏠 렌즈가 금빛으로 커지며 달아오른다
			draw_circle(p, 50.0 + 70.0 * hg, Color(C_EYE, 0.25 * hg))
			draw_circle(p, 16.0 + 20.0 * hg, Color(1.0, 0.92, 0.7, 0.6 + 0.4 * hg))
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
	var glow := (0.55 + 0.45 * eye_glow) * (0.08 + 0.92 * wake_k)   # 잠든 동안은 눈이 꺼져 있다
	if dead:
		glow = maxf(0.0, 0.55 - death_t * 0.4)
	for e in EYES:
		draw_circle(e, 32.0 + eye_glow * 32.0, Color(C_EYE, 0.16 * glow))
		draw_circle(e + (look_at - e).limit_length(1.0) * 7.0, 10.0 + eye_glow * 6.0, Color(C_EYE, glow))   # 눈동자가 플레이어를 좇는다
	draw_set_transform(Vector2.ZERO)

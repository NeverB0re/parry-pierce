extends "res://scripts/colossus_base.gd"
## 콜로서스 ④ 결계 위성 (회피 중심형, 패리 불가 다수). 기획: docs/BOSS_satellite.md
## 궤도에 떠 있는 거대한 위성: 서로 다른 축으로 도는 고리 3겹(바깥 고리의 노드가 발사점) + 한가운데 코어를 감싼 보라 결계.
## 핵심: 피해서 열고, 패리해서 부순다.
##   닫힘 — 코어는 결계에 싸여 돌진·차지·리버스 드라이브가 모두 튕긴다. 위성은 보라(패리 불가) 공격 + 잔탄을 던진다.
##          보라 공격을 퍼펙트 회피해 얻은 완전 동조(4배) 차지 강습, 또는 PERFECT 리버스 드라이브가 결계에 닿으면 결계에 금이 간다.
##          CRACKS_TO_OPEN 번 금이 가면 열린다 (마지막 일격의 피해는 코어에). 닫힌 동안 금색 주탄은 드물게 한 발씩만 (일부러 찾아가 패리해야 한다)
##          보라 공격은 겉보기엔 화면을 가득 채우지만(넓은 빛무리) 실제 판정은 가는 심줄뿐. 큰 보라 공격 + 작은 보조 공격(잔탄 분사·두 번째 벽)이 겹친다
##   열림 — 위성이 자기 보호 탄막(금색 주탄 나선 + 잔탄)을 쏟아낸다. 연속 패리 → 리버스 드라이브로 코어를 두드린다. OPEN_TIME 뒤 다시 닫히고,
##          닫힌 직후 SEAL_GUARD 동안은 결계가 단단해 무엇으로도 금이 가지 않는다 (남은 금색 탄으로 곧바로 다시 여는 것 방지)
## 표적은 코어 하나 (페이즈는 처음부터 3: 게이지는 코어 체력). 외부 시스템 없음.
## 바닥 y=0 (궤도 무대에서는 대기권 경계), 위쪽이 음수.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const OrbitBeam := preload("res://scripts/attacks/orbit_beam.gd")
const RadialBurst := preload("res://scripts/attacks/radial_burst.gd")
const Lattice := preload("res://scripts/attacks/lattice.gd")
const BarrierWall := preload("res://scripts/attacks/barrier_wall.gd")
const NodeSpray := preload("res://scripts/attacks/node_spray.gd")
const OpenBarrage := preload("res://scripts/attacks/open_barrage.gd")

# ── 구조 ───────────────────────────────────────────────
const CORE_POS := Vector2(0, -1950)
const CORE_R := 58.0
const BARRIER_R := 235.0                     # 결계 구체 반지름 (닫힌 동안의 표적 = 튕김)
const RING_R := [560.0, 800.0, 1060.0]       # 고리 3겹 반지름 (표적인 결계·코어보다 훨씬 크다)
const RING_SPIN := [0.35, -0.22, 0.14]       # 고리 회전 속도 (rad/s, 그림)
const NODES := 10                             # 바깥 고리의 발사 노드 수
const ARMOR_HP := 380                        # 코어 체력 (열림 4~5번)
const GAUGE_R := 300.0

# ── 결계 ───────────────────────────────────────────────
const OPEN_TIME := 7.0                       # 열려 있는 시간
const CLOSE_WARN := 1.0                      # 닫히기 전 깜빡이는 시간
const CLOSE_REST := 0.5                      # 닫힌 직후 첫 공격까지
const CRACKS_TO_OPEN := 3                    # 완전 동조 차지·PERFECT 드라이브를 이만큼 꽂아야 열린다
const SEAL_GUARD := 2.5                      # 닫힌 직후 이 시간 동안은 금이 가지 않는다

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.12, 0.3)              # 보라 공격을 자주 (완전 동조 기회)
const BURST_BEAMS := 8                      # 결계 폭풍 줄기 수 (줄기 사이를 넓게)
const SPRAY_SIDE := 0.6                      # 큰 보라 공격에 잔탄 분사가 겹칠 확률
const SEED_EVERY := 4                        # 닫힌 동안 금색 주탄(한 발)은 공격 이만큼마다
const SEED_SPEED := 170.0
const SEED_LIFE := 9.0
const SEED_TO := [Vector2(-700, -900), Vector2(700, -900), Vector2(-350, -500), Vector2(350, -500), Vector2(0, -1100)]   # 천천히 흘러갈 곳 (겨누지 않는다)

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.09, 0.1, 0.13)
const C_HULL_DARK := Color(0.05, 0.055, 0.075)
const C_RIM := Color(0.5, 0.56, 0.68)
const C_RING := Color(0.32, 0.36, 0.46)
const C_BARRIER := Color(0.6, 0.08, 0.36)          # 패리 불가 보라 (결계도 같은 색 언어)
const C_BARRIER_CORE := Color(1.0, 0.62, 0.86)
const C_CORE := Color(0.55, 0.95, 1.0)

var barrier_open := false
var open_left := 0.0
var barrier_flash := 0.0                     # 결계에 무언가 부딪힘 (번쩍)
var barrier_hit_n := Vector2.UP
var open_k := 0.0                            # 결계가 열린 정도 (그림, 0 = 닫힘 1 = 열림)
var pending_open := false                    # 이번 적중이 결계를 여는 일격인가 (blocks_strike → damage)
var since_seed := 0
var last := ""
var node_glow: Array[float] = []
var opens := 0                               # 연 횟수 (텔레메트리)
var cracks := 0                              # 결계에 간 금 (CRACKS_TO_OPEN 이면 열린다)
var guard_t := 0.0                           # 닫힌 직후 단단한 결계가 남은 시간


func _init() -> void:
	open_time = 0.0
	attack_gap = GAP
	core_assist_r = 160.0
	bolt_speedup_core = 0.0


func _ready() -> void:
	var outline := []
	for k in 20:
		outline.append(Vector2.from_angle(k * TAU / 20.0) * CORE_R * 1.6)
	core = ArmoredCore.new(self, CORE_POS, outline, ARMOR_HP, Rect2(), 0, 41)
	reset()


func reset() -> void:
	super()
	phase = 3                                # 외부 시스템 없음: 처음부터 코어 단계 (게이지 = 코어 체력)
	barrier_open = false
	open_left = 0.0
	barrier_flash = 0.0
	open_k = 0.0
	pending_open = false
	since_seed = 0
	last = ""
	opens = 0
	cracks = 0
	guard_t = 0.0
	node_glow.clear()
	for k in NODES:
		node_glow.append(0.0)


# ── 고리 · 노드 (그림과 발사점) ────────────────────────
## 고리 k 의 기울기 (타원의 세로 납작함, 시간에 따라 천천히 돈다)
func ring_flat(k: int) -> float:
	return 0.3 + 0.22 * sin(t * (0.25 + 0.1 * k) + k * 1.3)


func ring_rot(k: int) -> float:
	return k * 0.5 + sin(t * 0.13 + k) * 0.3


## 고리 k 위 각도 a 의 점
func ring_point(k: int, a: float) -> Vector2:
	var r: float = RING_R[k]
	var q := Vector2(cos(a) * r, sin(a) * r * ring_flat(k))
	return CORE_POS + q.rotated(ring_rot(k))


## 바깥 고리 노드 i 의 위치
func node_pos(i: int) -> Vector2:
	return ring_point(2, t * RING_SPIN[2] + i * TAU / NODES)


## 각도 a 쪽(코어에서 본 방향)에 가장 가까운 노드
func node_toward(a: float) -> int:
	var best := 0
	var bd := INF
	for i in NODES:
		var d: float = absf(angle_difference((node_pos(i) - CORE_POS).angle(), a))
		if d < bd:
			bd = d
			best = i
	return best


func set_glow(i: int, v: float) -> void:
	if i >= 0 and i < NODES:
		node_glow[i] = maxf(node_glow[i], v)


func glow_of(i: int) -> float:
	return node_glow[i] if i >= 0 and i < NODES else 0.0


# ── 표적 ───────────────────────────────────────────────
## 닫힘 = 결계 구체({kind:"shield"}), 열림 = 코어
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead:
		return {}
	if not barrier_open:
		var d := p - CORE_POS
		if d.length() < r + BARRIER_R:
			return {"kind": "shield", "n": d.normalized() if d.length() > 0.1 else Vector2.DOWN}
		return {}
	return core.hit(p, r)


## 결계: 완전 동조(4배) 차지 강습과 PERFECT 리버스 드라이브만 통과해 결계를 연다. 나머지는 튕긴다 (main.gd)
func blocks_strike(hit: Dictionary, kind: String, perfect: bool, strong: bool) -> bool:
	if hit.get("kind", "") != "shield":
		return false
	var opens_it := ((kind == "power" and perfect) or (kind == "charge" and strong)) and guard_t <= 0.0
	pending_open = opens_it
	if not opens_it:
		barrier_flash = 1.0
		barrier_hit_n = hit["n"]
	return not opens_it


func damage(hit: Dictionary, dmg: int) -> bool:
	if hit["kind"] == "shield":
		barrier_flash = 1.0
		barrier_hit_n = hit["n"]
		if not pending_open:                     # 반사탄 등은 결계에 막힌다
			return false
		pending_open = false
		cracks += 1
		if cracks < CRACKS_TO_OPEN:              # 금만 간다 (크게 흔들리고 파편이 튄다)
			emit(Ev.CORE_STAGE, CORE_POS + Vector2(hit["n"]) * BARRIER_R, {"stage": cracks, "fell": 0})
			return false
		_open()
		return damage_core(dmg)
	return super(hit, dmg)


func assist_targets(from := Vector2.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	out.append({"pos": CORE_POS, "r": BARRIER_R if not barrier_open else core_assist_r})
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


func target_pos(_from: Vector2) -> Vector2:
	return CORE_POS


## 체력 게이지: 코어 체력만 (보호 몫 없음 — 결계가 닫혀 있으면 아예 안 깎인다)
func gauge_values() -> Vector3:
	return Vector3(core.armor_hp, ARMOR_HP, 0)


func gauge_radius() -> float:
	return GAUGE_R


# ── 결계 열림 · 닫힘 ───────────────────────────────────
func _open() -> void:
	barrier_open = true
	open_left = OPEN_TIME
	opens += 1
	atk = null                                   # 보라 공격은 그친다 (열린 동안은 패리에 집중)
	lingering.clear()
	start_attack(OpenBarrage.new(CORE_POS, phase_hard()))
	emit(Ev.CORE_OPEN, CORE_POS)


func _close() -> void:
	barrier_open = false
	open_left = 0.0
	cracks = 0
	guard_t = SEAL_GUARD
	atk = null
	lingering.clear()
	next_t = CLOSE_REST
	barrier_flash = 1.0
	emit(Ev.RING, CORE_POS)


## 코어 체력이 절반 아래 (페이즈 2 몫: 더 촘촘하게)
func phase_hard() -> bool:
	return core.frac() > 0.5


func bolt_mult() -> float:
	return (1.0 + 0.2 * core.frac()) * (1.0 + LEVEL_SPEEDUP * level)


# ── 진행 ───────────────────────────────────────────────
func _step_effects(dt: float) -> void:
	barrier_flash = maxf(0.0, barrier_flash - dt * 3.0)
	guard_t = maxf(0.0, guard_t - dt)
	open_k = move_toward(open_k, 1.0 if barrier_open and not dead else 0.0, dt * (4.0 if barrier_open else 2.5))
	for i in NODES:
		node_glow[i] = move_toward(node_glow[i], 0.0, dt * 2.5)


func _step_phase(dt: float) -> void:
	if barrier_open:
		open_left -= dt
		if open_left <= 0.0:
			_close()


func _on_attack_finished() -> void:
	attack_gap = GAP


func _choose(ppos: Vector2) -> void:
	if barrier_open:                             # 열린 동안은 열림 탄막뿐 (끝나면 다시 시작)
		start_attack(OpenBarrage.new(CORE_POS, phase_hard()))
		return
	var w := {"burst": 1.0, "orbit": 0.8, "lattice": 0.8, "wall": 0.7}
	var kind := weighted_pick(w, last)
	last = kind
	match kind:
		"burst":                                 # 결계 폭풍: 사방으로 도는 광선 (겉보기 압도적, 판정은 가는 심줄)
			start_attack(RadialBurst.new(CORE_POS, BURST_BEAMS))
		"orbit":
			start_attack(OrbitBeam.new(self, ppos, level >= 3 and phase_hard()))
		"lattice":
			start_attack(Lattice.new())
		"wall":                                  # 두 겹: 두 번째 벽이 조금 늦게 따라온다
			start_attack(BarrierWall.new(ppos))
			start_side(BarrierWall.new(ppos, 1.4))
	if kind != "wall" and not is_lingering("spray") and randf() < SPRAY_SIDE:   # 작은 보조 공격: 노드 잔탄 분사가 겹친다
		start_side(NodeSpray.new())
	since_seed += 1
	if since_seed >= SEED_EVERY:                 # 드물게: 금색 주탄 한 발이 천천히 흘러간다 (찾아가 PERFECT 패리 → 결계에 금)
		since_seed = 0
		_seed()


func _seed() -> void:
	var to: Vector2 = SEED_TO[randi() % SEED_TO.size()]
	var i := node_toward((to - CORE_POS).angle())
	var o := node_pos(i)
	shots.spawn(o, (to - o).normalized() * SEED_SPEED * bolt_mult(), SEED_LIFE)
	set_glow(i, 1.0)
	emit(Ev.BOLT, o)


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_aura()
	_draw_wings()
	_draw_rings(true)
	_draw_shell()
	_draw_hub()
	_draw_core()
	_draw_barrier()
	_draw_rings(false)
	_draw_nodes()
	_draw_gauge()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


## 고리: 뒤쪽 절반(back) → 몸통 → 앞쪽 절반. 마디판과 이음매가 돈다
func _draw_rings(back: bool) -> void:
	for k in RING_R.size():
		var pts := PackedVector2Array()
		var n := 48
		var a0 := PI if back else 0.0
		for j in n + 1:
			pts.append(ring_point(k, a0 + PI * j / n))
		var w := 40.0 - k * 6.0
		draw_polyline(pts, C_HULL_DARK if back else C_HULL, w + 8.0)
		draw_polyline(pts, Color(C_RING, 0.55 if back else 0.9), w)
		draw_polyline(pts, Color(C_RIM, 0.25 if back else 0.5), 2.0)
		for j in 18:                                 # 도는 마디 + 가시
			var a := a0 + fposmod(t * RING_SPIN[k] + j * TAU / 18.0, PI)
			var p := ring_point(k, a)
			draw_circle(p, w * 0.34, Color(C_RIM, 0.35 if back else 0.7))
			if not back and j % 3 == 0:
				var outv := (p - CORE_POS).normalized()
				draw_line(p, p + outv * (40.0 + 10.0 * k), Color(C_HULL, 0.9), 8.0)


## 뒤쪽 후광: 위성 둘레의 옅은 보라 빛 (크기를 느끼게)
func _draw_aura() -> void:
	draw_circle(CORE_POS, 1500.0, Color(C_BARRIER, 0.035))
	draw_circle(CORE_POS, 1000.0, Color(C_BARRIER, 0.045))
	draw_circle(CORE_POS, 600.0, Color(C_BARRIER, 0.05))


## 양옆 태양 전지판 날개: 경기장 밖까지 뻗는 거대한 트러스 + 패널 격자 (천천히 기운다)
func _draw_wings() -> void:
	for side in [-1.0, 1.0]:
		var tilt: float = sin(t * 0.2) * 0.04 * side
		var base: Vector2 = CORE_POS + Vector2(side * 380.0, -40.0)
		var dirv := Vector2(side, 0).rotated(tilt)
		var up: Vector2 = dirv.orthogonal() * side
		var tip: Vector2 = base + dirv * 1500.0
		draw_line(base, tip, C_HULL_DARK, 46.0)             # 트러스
		draw_line(base, tip, Color(C_RIM, 0.35), 3.0)
		for q in 6:                                       # 패널 6장
			var c0: Vector2 = base + dirv * (180.0 + q * 220.0)
			var poly := PackedVector2Array([c0 + up * 230.0, c0 + up * 230.0 + dirv * 200.0, c0 - up * 230.0 + dirv * 200.0, c0 - up * 230.0])
			draw_colored_polygon(poly, Color(0.07, 0.1, 0.2))
			var ol := poly.duplicate()
			ol.append(poly[0])
			draw_polyline(ol, Color(C_RIM, 0.4), 3.0)
			for g in 4:                                    # 전지 격자
				var f := (g + 1) / 5.0
				draw_line(c0 + up * 230.0 + dirv * 200.0 * f, c0 - up * 230.0 + dirv * 200.0 * f, Color(0.25, 0.35, 0.6, 0.35), 2.0)
				draw_line(c0 + up * (230.0 - 460.0 * f), c0 + up * (230.0 - 460.0 * f) + dirv * 200.0, Color(0.25, 0.35, 0.6, 0.35), 2.0)
			var gl := 0.5 + 0.5 * sin(t * 1.5 + q * 0.7 + side)
			draw_rect(Rect2(c0 + dirv * 90.0 * side - Vector2(6, 6), Vector2(12, 12)), Color(C_BARRIER_CORE, 0.15 + 0.35 * gl))


## 결계를 두른 외피: 큰 장갑 고리 + 방열 핀 + 표시등 (표적은 아니다, 결계 바깥의 몸통)
func _draw_shell() -> void:
	var r := 360.0
	draw_arc(CORE_POS, r, 0.0, TAU, 72, C_HULL_DARK, 70.0)
	draw_arc(CORE_POS, r + 35.0, 0.0, TAU, 72, Color(C_RIM, 0.45), 3.0)
	draw_arc(CORE_POS, r - 35.0, 0.0, TAU, 72, Color(C_RIM, 0.3), 2.0)
	for k in 24:
		var a := k * TAU / 24.0 + t * 0.05
		var d := Vector2.from_angle(a)
		draw_line(CORE_POS + d * (r + 35.0), CORE_POS + d * (r + 80.0 + 20.0 * float(k % 2)), C_HULL, 10.0)
		var on := 0.5 + 0.5 * sin(t * 2.5 - k * 0.6)
		draw_circle(CORE_POS + d * r, 6.0, Color(C_BARRIER_CORE, 0.2 + 0.6 * on))
	draw_line(CORE_POS + Vector2(0, -r - 80.0), CORE_POS + Vector2(0, -r - 700.0), C_HULL_DARK, 30.0)   # 위로 뻗은 안테나 마스트
	draw_line(CORE_POS + Vector2(-90, -r - 520.0), CORE_POS + Vector2(90, -r - 520.0), C_HULL_DARK, 16.0)
	draw_circle(CORE_POS + Vector2(0, -r - 700.0), 18.0, Color(C_BARRIER_CORE, 0.4 + 0.4 * sin(t * 4.0)))


## 몸통: 결계 안쪽의 팔각 허브 + 고리를 잇는 지지대
func _draw_hub() -> void:
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		draw_line(CORE_POS, ring_point(0, a), C_HULL_DARK, 30.0)
	var oct := PackedVector2Array()
	for k in 8:
		oct.append(CORE_POS + Vector2.from_angle(k * TAU / 8.0 + PI / 8.0) * 175.0)
	draw_colored_polygon(oct, C_HULL)
	var ol := oct.duplicate()
	ol.append(oct[0])
	draw_polyline(ol, Color(C_RIM, 0.5), 3.0)
	for k in 8:
		draw_circle(oct[k] * 0.85 + CORE_POS * 0.15, 6.0, Color(C_RIM, 0.5))


func _draw_core() -> void:
	if dead:
		var kk := minf(1.0, death_t / 1.2)
		draw_circle(CORE_POS, CORE_R + kk * 260.0, Color(C_CORE, 0.5 * (1.0 - kk)))
		draw_arc(CORE_POS, CORE_R + kk * 480.0, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - kk), 6.0)
		return
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * f))
	var lit := 0.35 + 0.65 * open_k
	draw_circle(CORE_POS, CORE_R * 2.0, Color(C_CORE, (0.08 + 0.12 * beat) * lit))
	draw_circle(CORE_POS, CORE_R, Color(C_CORE, 0.5 + 0.4 * lit).lerp(Color.WHITE, core.flash * 0.7))
	draw_circle(CORE_POS, CORE_R * 0.45, Color(1, 1, 1, 0.6 + 0.4 * lit))
	if core.broken:
		draw_arc(CORE_POS, CORE_R + 20.0 + 6.0 * beat, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.55 + 0.4 * beat), 3.0)


## 결계 구체: 닫힘 = 보라 막 + 흐르는 육각 무늬 (부딪힌 쪽이 번쩍), 열림 = 갈라진 조각이 바깥으로 벌어져 사라진다. 닫히기 전에는 깜빡인다
func _draw_barrier() -> void:
	if dead:
		return
	var k := 1.0 - open_k
	var warn := barrier_open and open_left < CLOSE_WARN
	if warn:                                         # 곧 닫힌다: 결계 윤곽이 깜빡이며 돌아온다
		var b := 0.5 + 0.5 * sin(t * 20.0)
		draw_arc(CORE_POS, BARRIER_R, 0.0, TAU, 64, Color(C_BARRIER_CORE, 0.25 + 0.5 * b), 3.0)
	if k <= 0.01:
		return
	var spread := (1.0 - k) * 120.0
	for j in 6:                                      # 여섯 조각 (열리면 바깥으로 벌어진다)
		var a0 := j * TAU / 6.0 + t * 0.2
		var dir := Vector2.from_angle(a0 + TAU / 12.0)
		var c := CORE_POS + dir * spread
		var poly := PackedVector2Array([c])
		for q in 9:
			poly.append(c + Vector2.from_angle(a0 + TAU / 6.0 * q / 8.0) * BARRIER_R)
		draw_colored_polygon(poly, Color(C_BARRIER, (0.16 + 0.14 * barrier_flash) * k))
		draw_arc(c, BARRIER_R, a0, a0 + TAU / 6.0, 10, Color(C_BARRIER_CORE, (0.6 + 0.35 * barrier_flash) * k), 4.0)
	for j in 5:                                      # 막 위를 흐르는 호
		var a := t * 0.6 + j * TAU / 5.0
		draw_arc(CORE_POS, BARRIER_R - 12.0, a, a + 0.4, 8, Color(1, 0.85, 0.95, 0.35 * k), 3.0)
	for q in cracks:                                 # 간 금: 결계 표면에 번개처럼 갈라진 흰 선
		var a := q * 2.1 + 0.6
		var p0 := CORE_POS + Vector2.from_angle(a) * BARRIER_R
		var pts := PackedVector2Array([p0])
		var d := -Vector2.from_angle(a)
		for st in 4:
			p0 += d.rotated(sin(q * 3.0 + st) * 0.7) * 55.0
			pts.append(p0)
		draw_polyline(pts, Color(1, 0.95, 1, 0.9 * k), 5.0)
		draw_polyline(pts, Color(C_BARRIER_CORE, 0.6 * k), 12.0)
	if guard_t > 0.0:                                # 다시 닫힌 직후: 단단하게 봉인 (두꺼운 테두리가 빛난다)
		draw_arc(CORE_POS, BARRIER_R + 6.0, 0.0, TAU, 64, Color(1, 0.9, 1, 0.5 + 0.4 * sin(t * 12.0)), 10.0)
	if barrier_flash > 0.0:                          # 부딪힌 쪽 물결
		var a := barrier_hit_n.angle()
		draw_arc(CORE_POS, BARRIER_R + 10.0, a - 0.6, a + 0.6, 16, Color(1, 1, 1, 0.8 * barrier_flash * k), 6.0)


## 바깥 고리의 발사 노드 (발광 = 곧 쏜다)
func _draw_nodes() -> void:
	for i in NODES:
		var p := node_pos(i)
		var g: float = node_glow[i]
		draw_circle(p, 34.0, C_HULL_DARK)
		draw_arc(p, 34.0, 0.0, TAU, 16, Color(C_RIM, 0.7), 4.0)
		draw_circle(p, 12.0 + 12.0 * g, Color(C_BARRIER_CORE, 0.35 + 0.6 * g))
		if g > 0.05:
			draw_circle(p, 60.0 * g, Color(C_BARRIER, 0.25 * g))

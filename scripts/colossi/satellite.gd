extends "res://scripts/colossus_base.gd"
## 콜로서스 ④ 결계 위성 (회피 중심형, 패리 불가 다수). 기획: docs/BOSS_satellite.md
## 궤도에 떠 있는 거대한 위성: 서로 다른 축으로 도는 고리 3겹(바깥 고리의 노드가 발사점) + 한가운데 코어를 감싼 보라 결계.
## 핵심: 피해서 열고, 패리해서 부순다.
##   닫힘 — 코어는 결계에 싸여 돌진·차지·리버스 드라이브가 모두 튕긴다. 위성은 보라(패리 불가) 공격 + 잔탄을 던진다.
##          보라 공격을 퍼펙트 회피해 얻은 완전 동조(4배) 차지 강습, 또는 PERFECT 리버스 드라이브가 결계에 닿으면 결계가 열린다 (그 일격의 피해도 코어에).
##          닫힌 동안 금색 주탄은 드물게 한 발씩만 (일부러 찾아가 패리해야 한다)
##   열림 — 위성이 자기 보호 탄막(금색 주탄 나선 + 잔탄)을 쏟아낸다. 연속 패리 → 리버스 드라이브로 코어를 두드린다. OPEN_TIME 뒤 다시 닫힌다
## 표적은 코어 하나 (페이즈는 처음부터 3: 게이지는 코어 체력). 외부 시스템 없음.
## 바닥 y=0 (궤도 무대에서는 대기권 경계), 위쪽이 음수.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const OrbitBeam := preload("res://scripts/attacks/orbit_beam.gd")
const BarrierWall := preload("res://scripts/attacks/barrier_wall.gd")
const NodeSpray := preload("res://scripts/attacks/node_spray.gd")
const OpenBarrage := preload("res://scripts/attacks/open_barrage.gd")

# ── 구조 ───────────────────────────────────────────────
const CORE_POS := Vector2(0, -1950)
const CORE_R := 58.0
const BARRIER_R := 235.0                     # 결계 구체 반지름 (닫힌 동안의 표적 = 튕김)
const RING_R := [390.0, 520.0, 660.0]        # 고리 3겹 반지름
const RING_SPIN := [0.35, -0.22, 0.14]       # 고리 회전 속도 (rad/s, 그림)
const NODES := 8                             # 바깥 고리의 발사 노드 수
const ARMOR_HP := 380                        # 코어 체력 (열림 4~5번)
const GAUGE_R := 300.0

# ── 결계 ───────────────────────────────────────────────
const OPEN_TIME := 7.0                       # 열려 있는 시간
const CLOSE_WARN := 1.0                      # 닫히기 전 깜빡이는 시간
const CLOSE_REST := 0.6                      # 닫힌 직후 첫 공격까지

# ── 공격 고르기 ────────────────────────────────────────
const GAP := Vector2(0.3, 0.6)
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
	var opens_it := (kind == "power" and perfect) or (kind == "charge" and strong)
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
	var w := {"orbit": 1.0, "wall": 0.75, "spray": 0.6}
	var kind := weighted_pick(w, last)
	last = kind
	match kind:
		"orbit":
			start_attack(OrbitBeam.new(self, ppos, level >= 3 and phase_hard()))
		"wall":
			start_attack(BarrierWall.new(ppos))
		"spray":
			start_attack(NodeSpray.new())
	since_seed += 1
	if since_seed >= SEED_EVERY and kind != "spray":   # 드물게: 금색 주탄 한 발이 천천히 흘러간다 (찾아가 패리 → PERFECT 면 결계가 열린다)
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
	_draw_rings(true)
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
		var w := 26.0 - k * 4.0
		draw_polyline(pts, C_HULL_DARK if back else C_HULL, w + 8.0)
		draw_polyline(pts, Color(C_RING, 0.55 if back else 0.9), w)
		draw_polyline(pts, Color(C_RIM, 0.25 if back else 0.5), 2.0)
		for j in 12:                                 # 도는 마디
			var a := a0 + fposmod(t * RING_SPIN[k] + j * TAU / 12.0, PI)
			var p := ring_point(k, a)
			draw_circle(p, w * 0.32, Color(C_RIM, 0.35 if back else 0.7))


## 몸통: 결계 안쪽의 팔각 허브 + 고리를 잇는 지지대
func _draw_hub() -> void:
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		draw_line(CORE_POS, ring_point(0, a), C_HULL_DARK, 18.0)
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
	if barrier_flash > 0.0:                          # 부딪힌 쪽 물결
		var a := barrier_hit_n.angle()
		draw_arc(CORE_POS, BARRIER_R + 10.0, a - 0.6, a + 0.6, 16, Color(1, 1, 1, 0.8 * barrier_flash * k), 6.0)


## 바깥 고리의 발사 노드 (발광 = 곧 쏜다)
func _draw_nodes() -> void:
	for i in NODES:
		var p := node_pos(i)
		var g: float = node_glow[i]
		draw_circle(p, 20.0, C_HULL_DARK)
		draw_arc(p, 20.0, 0.0, TAU, 14, Color(C_RIM, 0.7), 3.0)
		draw_circle(p, 8.0 + 8.0 * g, Color(C_BARRIER_CORE, 0.35 + 0.6 * g))

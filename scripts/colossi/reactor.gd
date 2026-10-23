extends "res://scripts/colossus_base.gd"
## 콜로서스 ⑥ 반응로 (에너지 충전형). 기획: docs/BOSS_capacitor.md
## 함대 전체에 동력을 대던 거대 반응로가 맵 맨 위에 누워 있고, 앞면을 방열판 HEAT_N 장이 성벽처럼 덮는다. 그 앞을 에너지 방벽이 가로막는다.
##   방벽 — 플레이어가 지나갈 수 없는 진짜 벽 (wall_y_min). 돌진·차지·동조 일격은 튕긴다. 리버스 드라이브만 꿰뚫고 들어가 방열판을 친다.
##   딜 — 미로 끝의 금색 주탄을 패리 → 리버스 드라이브로 방벽을 뚫으면 방열판 하나가 망가져 과열된다. HEAT_N 번이면 노심 융해 대폭발로 끝.
##          꽂히는 순간 반응로가 경직되어 지금 패턴이 끊기고(쏟아지던 탄도 걷힌다), 플레이어는 폭발에 하단으로 크게 밀려난다(무적) → 사이클이 처음부터.
##   패턴 — 냉각 미로(잔탄 지형, 끝에 금색 주탄) · 양분 + 줄넘기(아주 굵은 보라 광선 + 빈틈 없는 잔탄 줄) · 압착(양옆 격벽, 근접)
## 승인된 예외 (docs/RULES.md 9장): 이동을 막는 방벽 / 코어 단계 없이 과열 N 번 / 게이지 링 없음 / 일격에 경직·패턴 끊김.
## 바닥 y=0 (융해 지대), 위쪽이 음수.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Maze := preload("res://scripts/attacks/reactor_maze.gd")
const Divide := preload("res://scripts/attacks/reactor_divide.gd")
const Clamp := preload("res://scripts/attacks/reactor_clamp.gd")

# ── 구조 ───────────────────────────────────────────────
const BARRIER_Y := -2000.0                   # 방벽 아랫면 (이 위로는 못 간다)
const DY := 350.0                            # 그림 기준(-2350)에서 실제 방벽까지 내린 만큼
const SPAWN_Y := -1970.0                     # 배출구 (탄이 나오는 높이)
const FLOOR_Y := 0.0
const ARENA_X := 1150.0                      # 경기장 좌우 벽
const HEAT_N := 5                            # 방열판 수 = 리버스 드라이브를 꽂아야 하는 횟수
const ARMOR_HP := HEAT_N                     # (플레이 기록용: 코어 체력 = 과열 횟수)
const PANEL_X := [-900.0, -450.0, 0.0, 450.0, 900.0]
const PANEL_Y := -2290.0                     # 방열판 가운데
const PANEL_W := 330.0
const PANEL_H := 420.0
const REACTOR_POS := Vector2(0, -2610)
const VENTS := 19                            # 배출구 수 (방벽 아래 한 줄)

# ── 진행 ───────────────────────────────────────────────
const GAP := Vector2(0.05, 0.12)             # 패턴 사이 (미로가 같은 간격으로 이어지게 짧게)
const RECOVER := 2.4                         # 꽂힌 뒤 반응로가 정신을 차리는 시간 (사이클 초기화)
const CLAMP_EVERY := Vector2(16.0, 22.0)     # 압착 간격
const CLAMP_DELAY := 2.5                     # 미로가 시작되고 이만큼 뒤에 압착이 시작된다
const SQUEEZE_HOLD := 13.0                   # 못 쳐낸 격벽이 박혀 있는 시간
const SQUEEZE_BACK := 90.0                   # 박힌 격벽이 물러나는 빠르기 (px/s)
const FURY_TEMPO := 0.1                      # 과열 하나마다 패턴 속도 +10%
const FURY_BOLT := 0.06                      # 과열 하나마다 탄 속도 +6%

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.1, 0.11, 0.13)
const C_HULL_DARK := Color(0.05, 0.055, 0.07)
const C_RIM := Color(0.48, 0.52, 0.58)
const C_COOL := Color(0.45, 0.85, 1.0)       # 냉각수 (식은 방열판)
const C_HOT := Color(1.0, 0.42, 0.12)        # 과열
const C_BARRIER := Color(0.78, 0.86, 0.95)   # 에너지 방벽 (표적이 아닌 막 — 흰 강철빛)
const C_VENT := Color(1.0, 0.6, 0.25)

var heat := 0                                # 꽂힌 리버스 드라이브 수
var hot: Array[bool] = []                    # 방열판마다 과열됐는가
var panel_flash: Array[float] = []
var pending_drive := false                   # 이번 적중이 리버스 드라이브인가 (blocks_strike → damage)
var barrier_flash := 0.0
var barrier_hit_x := 0.0
var last_gap_x := 0.0                        # 미로: 직전 줄의 통로 (다음 패턴이 이어지게)
var row_gap := 0.0                           # 배출구 예고: 다음 줄의 통로 가운데·폭·짙기
var row_w := 0.0
var row_k := 0.0
var squeeze_d: Array[float] = [0.0, 0.0]     # 양옆 격벽이 파고든 깊이 (음수 = 벽 너머에 숨음)
var squeeze_hold_t: Array[float] = [0.0, 0.0]
var clamp_t := 0.0                           # 다음 압착까지
var since_divide := 0
var last_maze := ""
var stagger_t := 0.0                         # 경직 (그림: 떨림·증기)
var shield_flash := 0.0                      # 약한 일격이 방벽에 튕김 (main 이 채운다 → 방벽이 번쩍)
var shield_hit_n := Vector2.DOWN
var last := ""                               # 직전 패턴 (maze / divide)


func _init() -> void:
	open_time = 0.0
	attack_gap = GAP
	core_assist_r = 160.0
	bolt_speedup_core = 0.0
	flinch_on_hit = false                        # 튕기는 일격으로는 움찔하지 않는다 (꽂힐 때만 경직)


func _ready() -> void:
	var outline := []
	for k in 16:
		outline.append(Vector2.from_angle(k * TAU / 16.0) * 200.0)
	core = ArmoredCore.new(self, REACTOR_POS, outline, HEAT_N, Rect2(), 0, 61)
	reset()


func reset() -> void:
	super()
	phase = 3                                    # 외부 시스템·개방 단계 없음 (과열 N 번이 곧 체력)
	heat = 0
	hot.clear()
	panel_flash.clear()
	for i in HEAT_N:
		hot.append(false)
		panel_flash.append(0.0)
	pending_drive = false
	barrier_flash = 0.0
	last_gap_x = randf_range(-500.0, 500.0)
	row_k = 0.0
	squeeze_d = [0.0, 0.0]
	squeeze_hold_t = [0.0, 0.0]
	clamp_t = randf_range(CLAMP_EVERY.x, CLAMP_EVERY.y) * 0.6
	since_divide = 0
	last_maze = ""
	stagger_t = 0.0


# ── 벽 ─────────────────────────────────────────────────
func wall_y_min() -> float:
	return BARRIER_Y


func wall_x_min() -> float:
	return -ARENA_X + maxf(0.0, squeeze_d[0])


func wall_x_max() -> float:
	return ARENA_X - maxf(0.0, squeeze_d[1])


## 못 쳐낸 격벽이 박힌다: 한동안 그대로 있다가 천천히 물러난다 (압착 모듈이 부른다)
func hold_squeeze(i: int, depth: float) -> void:
	squeeze_d[i] = depth
	squeeze_hold_t[i] = SQUEEZE_HOLD


# ── 배출구 예고 (미로 모듈이 부른다) ─────────────────
func vent_glow_row(gap: float, w: float, k: float) -> void:
	row_gap = gap
	row_w = w
	row_k = maxf(row_k, k)


func vent_x(i: int) -> float:
	return lerpf(-ARENA_X + 20.0, ARENA_X - 20.0, float(i) / (VENTS - 1))


# ── 표적: 방벽 ─────────────────────────────────────────
## 방벽에 닿았는가 (돌진 판정). 표적은 늘 방벽 하나 — 리버스 드라이브만 뚫는다
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead:
		return {}
	if p.y - r <= BARRIER_Y + 6.0:
		return {"kind": "shield", "n": Vector2.DOWN, "x": p.x}
	return {}


func blocks_strike(hit: Dictionary, kind: String, _perfect: bool, _strong: bool) -> bool:
	if hit.get("kind", "") != "shield":
		return false
	pending_drive = kind == "power"
	if not pending_drive:
		barrier_flash = 1.0
		barrier_hit_x = float(hit.get("x", 0.0))
	return not pending_drive


func damage(hit: Dictionary, _dmg: int) -> bool:
	if hit.get("kind", "") != "shield" or not pending_drive or dead:
		return false
	pending_drive = false
	var x: float = float(hit.get("x", 0.0))
	var i := _panel_toward(x)
	hot[i] = true
	panel_flash[i] = 1.0
	heat += 1
	core.armor_hp = HEAT_N - heat                # (플레이 기록·진행 비율용)
	barrier_flash = 1.0
	barrier_hit_x = x
	emit(Ev.CORE_STAGE, Vector2(PANEL_X[i], PANEL_Y), {"stage": heat, "fell": 1})
	if heat >= HEAT_N:
		return true                              # 마지막 방열판까지: 노심 융해 → main 이 승리 처리 (die)
	emit(Ev.BLAST, Vector2(x, BARRIER_Y), {"dir": Vector2(clampf(-x / 1600.0, -0.35, 0.35), 1.0)})
	_stagger()
	return false


## 경직: 지금 패턴이 끊기고 쏟아지던 탄이 걷힌다. 반응로가 정신을 차릴 때까지 쉰다 (사이클 초기화)
func _stagger() -> void:
	atk = null
	lingering.clear()
	shots.clear_near(Vector2(0, -1200), 99999.0)
	next_t = RECOVER
	stagger_t = 1.0
	row_k = 0.0
	flinch(true)


## x 쪽의 식은 방열판 (모두 과열이면 아무거나)
func _panel_toward(x: float) -> int:
	var best := -1
	var bd := INF
	for i in HEAT_N:
		if hot[i]:
			continue
		var d := absf(float(PANEL_X[i]) - x)
		if d < bd:
			bd = d
			best = i
	return best if best >= 0 else 0


## 반사탄·호위기 탄은 방벽에 막힌다 (리버스 드라이브만 뚫는다)
func takes_reflect(_hit: Dictionary) -> bool:
	return false


## 조준: 패리 후 리버스 드라이브를 겨눌 때만 방벽 너머 식은 방열판이 표적으로 드러난다 (패턴 중 돌진·차지에는 표적이 없다)
func assist_targets(from := Vector2.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	if drive_aim:
		for i in HEAT_N:
			if not hot[i]:
				out.append({"pos": Vector2(PANEL_X[i], BARRIER_Y - 30.0), "r": 150.0})
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


func target_pos(from: Vector2) -> Vector2:
	var i := _panel_toward(from.x)
	return Vector2(PANEL_X[i], BARRIER_Y - 30.0)


func gauge_values() -> Vector3:
	return Vector3(HEAT_N - heat, HEAT_N, 0)


func core_damageable() -> bool:
	return true


func bolt_mult() -> float:
	return (1.0 + FURY_BOLT * heat) * (1.0 + LEVEL_SPEEDUP * level)


func pattern_scale() -> float:
	return super() * (1.0 + FURY_TEMPO * heat)


# ── 진행 ───────────────────────────────────────────────
func _step_effects(dt: float) -> void:
	barrier_flash = maxf(0.0, maxf(barrier_flash, shield_flash) - dt * 3.0)
	shield_flash = 0.0
	stagger_t = maxf(0.0, stagger_t - dt * 0.8)
	row_k = maxf(0.0, row_k - dt * 3.0)
	for i in HEAT_N:
		panel_flash[i] = maxf(0.0, panel_flash[i] - dt * 1.5)


func _step_phase(dt: float) -> void:
	for i in 2:                                  # 박힌 격벽: 한동안 그대로, 그다음 천천히 물러난다 (압착 공격이 돌고 있으면 그쪽이 움직인다)
		if is_lingering("clamp"):
			break
		if squeeze_hold_t[i] > 0.0:
			squeeze_hold_t[i] -= dt
		elif squeeze_d[i] > 0.0:
			squeeze_d[i] = maxf(0.0, squeeze_d[i] - SQUEEZE_BACK * dt)
	if not hold_attacks:
		clamp_t -= dt


func _on_attack_finished() -> void:
	attack_gap = GAP


func _choose(_ppos: Vector2) -> void:
	if dead:
		return
	since_divide += 1
	if since_divide >= 3 and last != "divide" and not _squeezed():   # 양분 + 줄넘기: 미로 둘에 한 번 (격벽이 박혀 좁을 땐 쉰다)
		since_divide = 0
		last = "divide"
		start_attack(Divide.new())
		return
	var mode := weighted_pick({"zigzag": 1.0, "snake": 1.0, "funnel": 0.7}, last_maze)
	last_maze = mode
	last = "maze"
	start_attack(Maze.new(mode, true))
	if clamp_t <= 0.0 and not is_lingering("clamp") and not _squeezed():   # 압착: 미로 도중에 (양분 광선과는 겹치지 않는다 — 보라 + 근접 금지)
		clamp_t = randf_range(CLAMP_EVERY.x, CLAMP_EVERY.y)
		var c = Clamp.new()
		c.t = -CLAMP_DELAY
		start_side(c)


func _squeezed() -> bool:
	return squeeze_d[0] > 1.0 or squeeze_d[1] > 1.0


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_housing()
	_draw_reactor()
	for i in HEAT_N:
		_draw_panel(i)
	_draw_vents()
	_draw_barrier()
	_draw_plates()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)
	if dead:
		_draw_meltdown()


## 반응로 몸체: 맵 위를 다 덮는 두꺼운 격납 외벽 + 배관 + 표시등 (경기장 밖까지)
func _draw_housing() -> void:
	var shake := Vector2(sin(t * 61.0), cos(t * -47.0)) * 10.0 * stagger_t
	draw_set_transform(shake + Vector2(0, DY), 0.0, Vector2.ONE)
	draw_rect(Rect2(-1700, -3600, 3400, 1250 + 40), C_HULL_DARK)
	draw_rect(Rect2(-1700, -2470, 3400, 120), C_HULL)
	draw_line(Vector2(-1700, -2470), Vector2(1700, -2470), Color(C_RIM, 0.5), 4.0)
	draw_line(Vector2(-1700, -2352), Vector2(1700, -2352), Color(C_RIM, 0.6), 4.0)
	for k in 9:                                      # 굵은 배관이 반응로에서 방열판들로
		var x := -1500.0 + k * 375.0
		draw_line(Vector2(x, -3600), Vector2(x, -2880), C_HULL, 46.0)
		draw_line(Vector2(x - 16, -3600), Vector2(x - 16, -2880), Color(C_RIM, 0.25), 3.0)
		draw_circle(Vector2(x, -2880), 30.0, C_HULL)
		var on := 0.5 + 0.5 * sin(t * 2.0 + k)
		draw_circle(Vector2(x, -2880), 9.0, Color(_heat_col(), 0.3 + 0.5 * on))
	for side in [-1.0, 1.0]:                         # 양 끝 거대한 냉각탑 (경기장 밖)
		var x: float = 1430.0 * side
		draw_colored_polygon(PackedVector2Array([Vector2(x - 190, -2400), Vector2(x + 190, -2400), Vector2(x + 140, -3400), Vector2(x - 140, -3400)]), C_HULL)
		draw_line(Vector2(x - 170, -2500), Vector2(x - 125, -3350), Color(C_RIM, 0.35), 3.0)
		for q in 5:
			var y := -2550.0 - q * 180.0
			draw_line(Vector2(x - 160 + q * 6, y), Vector2(x + 160 - q * 6, y), Color(C_HULL_DARK), 10.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 과열 정도에 따른 색: 식은 청록 → 붉은 주황
func _heat_col() -> Color:
	return C_COOL.lerp(C_HOT, float(heat) / HEAT_N)


## 노심: 방열판 뒤로 비치는 빛. 과열될수록 붉고 빠르게 고동친다
func _draw_reactor() -> void:
	var f := float(heat) / HEAT_N
	var beat := 0.5 + 0.5 * sin(t * (2.0 + 7.0 * f))
	var c := _heat_col()
	_soft_glow(REACTOR_POS, 900.0 + 300.0 * f, c, 0.12 + 0.12 * beat + 0.15 * f)
	draw_circle(REACTOR_POS, 260.0, Color(C_HULL, 1.0))
	draw_arc(REACTOR_POS, 260.0, 0.0, TAU, 64, Color(C_RIM, 0.6), 6.0)
	draw_circle(REACTOR_POS, 190.0, Color(c, 0.35 + 0.3 * beat))
	draw_circle(REACTOR_POS, 110.0, Color(c.lightened(0.4), 0.6 + 0.3 * beat))
	draw_circle(REACTOR_POS, 50.0, Color(1, 1, 1, 0.8))
	for k in 12:                                     # 노심을 두른 제어봉
		var a := k * TAU / 12.0 + t * 0.1
		draw_line(REACTOR_POS + Vector2.from_angle(a) * 270.0, REACTOR_POS + Vector2.from_angle(a) * 330.0, C_HULL, 18.0)


## 방열판 i: 세로 핀 여러 장. 식었으면 핀 사이로 청록 냉각수가 흐르고, 과열되면 핀이 붉게 달아올라 증기·불꽃이 샌다 (몇 장 남았는지 한눈에)
func _draw_panel(i: int) -> void:
	var c := Vector2(PANEL_X[i], PANEL_Y)
	var shake := Vector2(sin(t * 53.0 + i), cos(t * 41.0 + i)) * 8.0 * panel_flash[i]
	c += shake
	var r := Rect2(c - Vector2(PANEL_W, PANEL_H) * 0.5, Vector2(PANEL_W, PANEL_H))
	draw_rect(r.grow(14.0), C_HULL)
	draw_rect(r.grow(14.0), Color(C_RIM, 0.6), false, 4.0)
	var is_hot: bool = hot[i]
	var fins := 9
	for k in fins:
		var x := r.position.x + (k + 0.5) * PANEL_W / fins
		var top := r.position.y + 10.0
		var bot := r.end.y - 10.0
		if is_hot:
			var flick := 0.75 + 0.25 * sin(t * 13.0 + k * 1.7 + i)
			draw_line(Vector2(x, top), Vector2(x, bot), Color(C_HOT.lerp(Color(1, 0.85, 0.5), 0.3 * flick), 1.0), 18.0)
			draw_line(Vector2(x, top), Vector2(x, bot), Color(1.0, 0.9, 0.6, 0.6 * flick), 5.0)
		else:
			draw_line(Vector2(x, top), Vector2(x, bot), Color(0.2, 0.23, 0.27), 18.0)
			var flow := fposmod(t * 160.0 + k * 37.0, PANEL_H - 20.0)       # 핀 사이로 흐르는 냉각수
			draw_line(Vector2(x + 13.0, top + flow), Vector2(x + 13.0, minf(bot, top + flow + 60.0)), Color(C_COOL, 0.75), 4.0)
	if is_hot:
		_soft_glow(c, PANEL_W * 0.9, C_HOT, 0.35)
		for q in 5:                                      # 새어 나오는 증기 (위로 피어오름)
			var u := fposmod(t * 0.7 + q * 0.21 + i * 0.13, 1.0)
			var sp := c + Vector2(sin(q * 2.3 + i) * PANEL_W * 0.35, -PANEL_H * 0.5 - u * 260.0)
			draw_circle(sp, 26.0 + 60.0 * u, Color(0.8, 0.8, 0.85, 0.22 * (1.0 - u)))
		for q in 3:                                      # 갈라진 금
			var p0 := c + Vector2(-PANEL_W * 0.4 + q * PANEL_W * 0.35, -PANEL_H * 0.45)
			var pts := PackedVector2Array([p0])
			for st in 4:
				p0 += Vector2(sin(q * 4.1 + st * 1.9) * 40.0, PANEL_H * 0.22)
				pts.append(p0)
			draw_polyline(pts, Color(1.0, 0.95, 0.7, 0.85), 4.0)
	else:
		draw_rect(Rect2(c.x - 40.0, r.end.y + 4.0, 80.0, 10.0), Color(C_COOL, 0.6 + 0.3 * sin(t * 3.0 + i)))   # 정상 표시등
	if panel_flash[i] > 0.0:
		draw_rect(r.grow(20.0), Color(1, 0.95, 0.8, 0.6 * panel_flash[i]), false, 10.0)


## 배출구: 방벽 바로 아래 한 줄. 다음 줄의 통로 자리는 꺼져 있고(어두움), 나머지는 주황으로 달아오른다 (미리 보는 길)
func _draw_vents() -> void:
	for i in VENTS:
		var x := vent_x(i)
		var p := Vector2(x, SPAWN_Y - 6.0)
		draw_rect(Rect2(p - Vector2(34, 18), Vector2(68, 36)), C_HULL)
		draw_rect(Rect2(p - Vector2(34, 18), Vector2(68, 36)), Color(C_RIM, 0.5), false, 2.0)
		var open := row_k > 0.0 and absf(x - row_gap) <= row_w * 0.5
		if open:
			draw_rect(Rect2(p - Vector2(24, 8), Vector2(48, 16)), Color(C_COOL, 0.25 + 0.5 * row_k))
		else:
			draw_rect(Rect2(p - Vector2(24, 8), Vector2(48, 16)), Color(C_VENT, 0.15 + 0.8 * row_k))
			if row_k > 0.3:
				draw_circle(p + Vector2(0, 14), 18.0 * row_k, Color(C_VENT, 0.25 * row_k))


## 에너지 방벽: 경기장 위를 가로막는 흰 강철빛 막 + 흐르는 육각 무늬. 부딪힌 자리가 번쩍인다
func _draw_barrier() -> void:
	if dead:
		return
	var y0 := BARRIER_Y - 90.0
	draw_rect(Rect2(-ARENA_X - 300.0, y0, ARENA_X * 2.0 + 600.0, 90.0), Color(C_BARRIER, 0.1))
	draw_line(Vector2(-ARENA_X - 300.0, BARRIER_Y), Vector2(ARENA_X + 300.0, BARRIER_Y), Color(C_BARRIER, 0.75), 4.0)
	draw_line(Vector2(-ARENA_X - 300.0, BARRIER_Y - 8.0), Vector2(ARENA_X + 300.0, BARRIER_Y - 8.0), Color(C_BARRIER, 0.25), 10.0)
	var cell := 90.0
	var off := fposmod(t * 40.0, cell)
	var x := -ARENA_X - 300.0 + off
	while x < ARENA_X + 300.0:
		for row in 2:
			var cx := x + (cell * 0.5 if row == 1 else 0.0)
			var cy := y0 + 22.0 + row * 45.0
			var hexp := PackedVector2Array()
			for q in 7:
				hexp.append(Vector2(cx, cy) + Vector2.from_angle(q * TAU / 6.0) * 24.0)
			draw_polyline(hexp, Color(C_BARRIER, 0.18), 2.0)
		x += cell
	if barrier_flash > 0.0:
		draw_circle(Vector2(barrier_hit_x, BARRIER_Y - 30.0), 60.0 + 140.0 * (1.0 - barrier_flash), Color(1, 1, 1, 0.4 * barrier_flash))
		draw_arc(Vector2(barrier_hit_x, BARRIER_Y - 30.0), 80.0 + 160.0 * (1.0 - barrier_flash), PI, TAU, 24, Color(C_BARRIER, 0.8 * barrier_flash), 6.0)


## 카메라: 화면 위쪽에 반응로(방열판까지)가 늘 들어오게 끌어올리고, 플레이어는 화면 아래쪽에 둔다 (탄은 위에서 내려온다).
## 플레이어가 너무 아래면 플레이어가 화면 밖으로 나가지 않는 데까지만
const VIEW_HALF := 666.0                     # 화면 세로 절반 (기본 줌)
const VIEW_SHOW := 520.0                     # 방벽 위로 보여 줄 높이 (방열판)
const VIEW_FOOT := 140.0                     # 플레이어와 화면 아래 끝 사이 최소 여유


func view_bias(p: Vector2) -> Vector2:
	var base := p.y - 80.0
	var want := maxf(BARRIER_Y - VIEW_SHOW + VIEW_HALF, p.y - VIEW_HALF + VIEW_FOOT)
	return Vector2(0.0, minf(0.0, want - base))


## 양옆 격벽 (방호 셔터): 파고든 만큼 경기장 안으로. 안쪽 끝에 위험 줄무늬 (평소엔 경기장 벽 바깥의 강철 벽일 뿐)
func _draw_plates() -> void:
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var d: float = squeeze_d[i]
		if d <= -250.0:
			continue
		var inner := ARENA_X * sd - sd * d
		var outer := (ARENA_X + 500.0) * sd
		var x0 := minf(inner, outer)
		var x1 := maxf(inner, outer)
		draw_rect(Rect2(x0, BARRIER_Y, x1 - x0, -BARRIER_Y + 80.0), Color(0.15, 0.15, 0.17))
		for k in 7:
			var y := BARRIER_Y + 120.0 + k * 330.0
			draw_rect(Rect2(x0, y, x1 - x0, 26.0), Color(0.09, 0.09, 0.1))
		var face := inner
		if d <= 0.5 and not is_lingering("clamp"):
			continue
		draw_rect(Rect2(face - (50.0 if sd > 0 else 0.0), BARRIER_Y, 50.0, -BARRIER_Y + 80.0), Color(0.24, 0.22, 0.2))
		var y := BARRIER_Y
		while y < 80.0:
			var fx0 := face - (50.0 if sd > 0 else 0.0)
			draw_line(Vector2(fx0, y), Vector2(fx0 + 50.0, y + 50.0), Color(1.0, 0.35, 0.18, 0.8), 12.0)
			y += 100.0
		draw_line(Vector2(face, BARRIER_Y), Vector2(face, 80.0), Color(1.0, 0.35, 0.18), 4.0)


## 노심 융해: 방열판이 연달아 터지고 노심에서 흰 빛이 터져 나온다
func _draw_meltdown() -> void:
	var k := minf(1.0, death_t / 1.6)
	for i in HEAT_N:
		var kk := clampf((death_t - i * 0.12) / 0.6, 0.0, 1.0)
		if kk > 0.0:
			var c := Vector2(PANEL_X[i], PANEL_Y)
			draw_circle(c, 120.0 + 380.0 * kk, Color(1.0, 0.6, 0.25, 0.6 * (1.0 - kk)))
			draw_arc(c, 160.0 + 520.0 * kk, 0.0, TAU, 40, Color(1, 0.95, 0.8, 0.9 * (1.0 - kk)), 8.0)
	draw_circle(REACTOR_POS, 300.0 + 1800.0 * k, Color(1.0, 0.95, 0.85, 0.55 * (1.0 - k)))
	draw_arc(REACTOR_POS, 400.0 + 2600.0 * k, 0.0, TAU, 64, Color(1, 1, 1, 1.0 - k), 12.0)

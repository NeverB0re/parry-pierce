extends "res://scripts/colossus_base.gd"
## 콜로서스 ② 탄막 요새 (패리 중심형). 궤도 위를 기어 다니던 거대한 포대 요새. 인간형이 아니라 무한궤도 위의 성채.
## 핵심: 잔탄(작은 탄)은 피하거나 패리로 흡수, 주탄(큰 탄·유도탄)을 패리해 리버스 드라이브로 꽂는다.
## 페이즈: 1) 외부 시스템 파괴 — 좌/우 주포대(위), 좌/우 유도탄 사일로(아래)
##         2) 개방 — 몸통 방폭문이 위아래로 열린다
##         3) 반응로 — 팔각 장갑에 싸인 동력 코어. 탄막은 첨탑에서, 유도탄은 반응로 배기구에서
## 공격: 나선 탄막 · 부채 탄막(가운데 주탄) · 유도탄 · 융해 기뢰(바닥) · 프레스(근접, 회피 불가, 드물게) · 동심원 파동(패리 불가, 드물게)
##       · 반응로 폭주(코어 페이즈 전용). 코어 페이즈에선 기존 탄막도 강해진다(hard).
## 탄막형이라 화면이 비지 않게: 쉬는 시간이 짧고, 유도탄은 다른 공격과 겹쳐 쏘며(보조 공격),
## 동심원 파동·올라가는 프레스는 판정을 남긴 채 다음 공격에 자리를 내준다. 같은 탄막을 연달아 쓰지 않는다.
## 바닥 y=0, 위쪽이 음수. 몸 중심 x=0.

const ArmoredCore := preload("res://scripts/armored_core.gd")
const Spiral := preload("res://scripts/attacks/spiral.gd")
const Fan := preload("res://scripts/attacks/fan.gd")
const Homing := preload("res://scripts/attacks/homing.gd")
const Mines := preload("res://scripts/attacks/mines.gd")
const Press := preload("res://scripts/attacks/press.gd")
const Rings := preload("res://scripts/attacks/rings.gd")
const Overload := preload("res://scripts/attacks/overload.gd")

# ── 구조 ───────────────────────────────────────────────
const REACTOR_POS := Vector2(0, -1640)      # 동력 코어(반응로) 중심
const DOOR_RECT := Rect2(-270, -1920, 540, 560)   # 방폭문 (페이즈 1에 닫혀 있음)
const ARMOR_HP := 180
const PLATE_SITES := 10
const CORE_R := 58.0
# 반응로 외곽선 (REACTOR_POS 기준): 모서리를 깎은 팔각형 + 위아래 냉각 돌기
const REACTOR_OUTLINE := [
	Vector2(-90, -230), Vector2(-40, -262), Vector2(40, -262), Vector2(90, -230), Vector2(170, -170),
	Vector2(215, -80), Vector2(215, 80), Vector2(170, 170), Vector2(90, 230), Vector2(40, 262),
	Vector2(-40, 262), Vector2(-90, 230), Vector2(-170, 170), Vector2(-215, 80), Vector2(-215, -80), Vector2(-170, -170),
]
const PLATE_SITE_BOX := Rect2(-210, -250, 420, 500)
const BATTERIES := [Vector2(-560, -2200), Vector2(560, -2200)]      # 주포대 (외부 시스템 0, 1)
const BARREL_TIPS := [Vector2(-720, -2420), Vector2(720, -2420)]
const SILOS := [Vector2(-650, -1260), Vector2(650, -1260)]           # 유도탄 사일로 (외부 시스템 2, 3)
const SPIRE_TOP := Vector2(0, -2780)                                # 첨탑 포구 (주포대가 없으면 여기서)
const VENTS := [Vector2(-330, -1640), Vector2(330, -1640)]          # 코어 페이즈 유도탄 배기구
const MORTARS := [Vector2(-430, -640), Vector2(430, -640)]          # 기뢰 박격포

# ── 외부 시스템 ────────────────────────────────────────
const PART_HP := 24
const PART_R := [62.0, 62.0, 58.0, 58.0]
const OPEN_TIME := 1.6

# ── 공격 고르기 ────────────────────────────────────────
const LOW_ZONE_Y := -1000.0          # 이보다 아래면 기뢰 위주
const GAP := Vector2(0.35, 0.7)      # 공격 사이 쉬는 시간 (짧게: 탄막형이라 화면이 비지 않게)
const GAP_CORE := Vector2(0.2, 0.45) # 코어 페이즈는 더 몰아친다
const SPECIAL_EVERY := 5             # 특수기(프레스·동심원)는 이만큼 공격한 뒤에야 다시 (드물게, 연달아 쓰지 않음)
const HOMING_EVERY := 3              # 유도탄(보조 공격)은 공격 이만큼마다 (코어 페이즈는 2)

# ── 색 ─────────────────────────────────────────────────
const C_HULL := Color(0.085, 0.085, 0.095)
const C_HULL_DARK := Color(0.05, 0.05, 0.06)
const C_RIM := Color(0.5, 0.48, 0.44)
const C_RUST := Color(0.36, 0.2, 0.12)
const C_TREAD := Color(0.06, 0.06, 0.065)
const C_GLOW := Color(1.0, 0.78, 0.42)

var glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 발사 전 달아오름: 부위 0~3, 4 첨탑, 5 박격포, 6 반응로(보라)
var debris: Array[Dictionary] = []
var last := ""                       # 직전에 고른 주 공격 (같은 탄막 반복 방지)
var since_special := 0
var since_homing := 0


func _init() -> void:
	open_time = OPEN_TIME
	attack_gap = GAP
	core_assist_r = 220.0


func _ready() -> void:
	core = ArmoredCore.new(self, REACTOR_POS, REACTOR_OUTLINE, ARMOR_HP, PLATE_SITE_BOX, PLATE_SITES, 23)
	reset()


func reset() -> void:
	super()
	debris.clear()
	last = ""
	since_special = 0
	since_homing = 0
	for i in glow.size():
		glow[i] = 0.0


# ── 외부 시스템 ────────────────────────────────────────
func part_count() -> int:
	return 4


func part_max_hp(_i: int) -> int:
	return PART_HP


func part_radius(i: int) -> float:
	return PART_R[i]


func part_pos(i: int) -> Vector2:
	return BATTERIES[i] if i < 2 else SILOS[i - 2]


## 부서진 포대는 포신이, 사일로는 해치가 떨어져 나간다
func _on_part_broken(i: int) -> void:
	var s := 1.0 if i % 2 == 1 else -1.0
	if i < 2:
		var b: Vector2 = BATTERIES[i]
		var tip: Vector2 = BARREL_TIPS[i]
		debris.append({"pos": (b + tip) * 0.5, "half": (tip - b) * 0.5, "w": 46.0, "vel": Vector2(s * 280.0, -360.0), "rot": 0.0, "rotv": s * 3.2, "rest": false})
	else:
		var p: Vector2 = SILOS[i - 2]
		debris.append({"pos": p + Vector2(0, -90), "half": Vector2(80, 0), "w": 40.0, "vel": Vector2(s * 320.0, -300.0), "rot": 0.0, "rotv": s * 4.0, "rest": false})


# ── 진행 ───────────────────────────────────────────────
func _step_effects(dt: float) -> void:
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
		if p.y + reach >= 0.0:
			p.y = -reach
			d["rest"] = true
			emit(Ev.DEBRIS_LAND, Vector2(p.x, 0))
		d["pos"] = p
		d["rot"] = rot


func _step_phase(dt: float) -> void:
	attack_gap = GAP_CORE if phase == 3 else GAP
	for i in glow.size():
		glow[i] = move_toward(glow[i], 0.0, dt * 2.0)


func _choose(ppos: Vector2) -> void:
	var hard := phase == 3
	since_special += 1
	since_homing += 1
	if since_homing >= (2 if hard else HOMING_EVERY) and not homing_origins().is_empty():   # 유도탄은 다른 공격과 겹쳐 쏜다
		since_homing = 0
		start_side(Homing.new())
	if since_special >= SPECIAL_EVERY and randf() < 0.5:    # 드물게: 천장 프레스(근접, 회피 불가) / 심장부 동심원 파동(패리 불가)
		since_special = 0
		if randf() < 0.5 or is_lingering("rings"):
			_pick("press", Press.new())
		else:
			_pick("rings", Rings.new(REACTOR_POS))
		return
	if ppos.y > LOW_ZONE_Y and last != "mines" and randf() < 0.6:   # 낮은 곳: 기뢰 위주
		_pick("mines", Mines.new(ppos, hard))
		return
	var pool: Array[String] = ["spiral", "fan"]
	if hard:
		pool.append("overload")
		pool.append("overload")
	while pool.has(last):
		pool.erase(last)
	var c := _battery(ppos)
	var org: Vector2 = SPIRE_TOP if c < 0 else BARREL_TIPS[c]
	match pool[randi() % pool.size()]:
		"spiral":
			_pick("spiral", Spiral.new(c, org, hard))
		"fan":
			_pick("fan", Fan.new(c, org, ppos, hard))
		_:
			_pick("overload", Overload.new(REACTOR_POS))


func _pick(kind: String, a) -> void:
	last = kind
	start_attack(a)


## 탄막 발사점: 페이즈 1은 플레이어에게서 더 먼(살아있는) 주포대, 없거나 코어 페이즈면 첨탑(-1)
func _battery(ppos: Vector2) -> int:
	if phase == 3:
		return -1
	if part_alive(0) and part_alive(1):
		return 0 if ppos.distance_to(BARREL_TIPS[0]) >= ppos.distance_to(BARREL_TIPS[1]) else 1
	if part_alive(0):
		return 0
	if part_alive(1):
		return 1
	return -1


## 유도탄 발사점 [[번호, 위치]]: 페이즈 1은 살아 있는 사일로, 코어 페이즈는 배기구 둘
func homing_origins() -> Array:
	var out := []
	if phase == 3:
		out.append([-1, VENTS[0]])
		out.append([-1, VENTS[1]])
		return out
	for k in 2:
		if part_alive(2 + k):
			out.append([2 + k, SILOS[k] + Vector2(0, -110)])
	return out


## 발사 전 발광: 0~3 부위, -1 첨탑(코어 페이즈 배기구 포함), -3 박격포, -4 반응로(동심원 파동)
func set_glow(c: int, v: float) -> void:
	glow[_glow_idx(c)] = v


func glow_of(c: int) -> float:
	return glow[_glow_idx(c)]


static func _glow_idx(c: int) -> int:
	if c >= 0:
		return c
	if c == -4:
		return 6
	return 4 if c == -1 else 5


# ── 그리기 ─────────────────────────────────────────────
func _draw() -> void:
	_draw_spire()
	_draw_hull()
	_draw_doors()
	_draw_batteries()
	_draw_silos()
	_draw_base()
	_draw_part_marks()
	_draw_debris()
	_draw_shards()
	for a in active_attacks():
		a.draw()
	shots.draw(self)


func _draw_base() -> void:
	# 무한궤도 차대
	var base := PackedVector2Array([Vector2(-1000, 0), Vector2(1000, 0), Vector2(900, -560), Vector2(-900, -560)])
	draw_colored_polygon(base, C_HULL_DARK)
	draw_polyline(PackedVector2Array([Vector2(-900, -560), Vector2(900, -560)]), C_RIM, 4.0)
	for s in [-1.0, 1.0]:
		var c := Vector2(s * 620.0, -170.0)
		draw_rect(Rect2(c.x - 300.0, c.y - 130.0, 600.0, 260.0), C_TREAD)
		draw_rect(Rect2(c.x - 300.0, c.y - 130.0, 600.0, 260.0), Color(C_RIM, 0.5), false, 3.0)
		var roll := fmod(t * 40.0, 60.0)
		for k in 11:
			var x := c.x - 300.0 + fmod(k * 60.0 + roll * s, 600.0)
			draw_line(Vector2(x, c.y - 130.0), Vector2(x, c.y - 112.0), Color(C_RIM, 0.4), 4.0)
			draw_line(Vector2(x, c.y + 112.0), Vector2(x, c.y + 130.0), Color(C_RIM, 0.4), 4.0)
		for k in 5:
			var w := Vector2(c.x - 230.0 + k * 115.0, c.y)
			draw_circle(w, 46.0, C_HULL)
			draw_arc(w, 46.0, 0.0, TAU, 20, Color(C_RIM, 0.55), 3.0)
			draw_circle(w, 12.0, C_RUST)
	# 박격포 포구
	for i in 2:
		var m: Vector2 = MORTARS[i]
		var g := glow[5]
		draw_circle(m, 52.0, C_HULL)
		draw_arc(m, 52.0, PI, TAU, 18, C_RIM, 4.0)
		draw_circle(m, 22.0 + 10.0 * g, Color(C_GLOW, 0.2 + 0.6 * g))


func _draw_hull() -> void:
	var lower := PackedVector2Array([Vector2(-780, -560), Vector2(780, -560), Vector2(720, -1100), Vector2(-720, -1100)])
	draw_colored_polygon(lower, C_HULL)
	var upper := PackedVector2Array([Vector2(-720, -1100), Vector2(720, -1100), Vector2(640, -2050), Vector2(400, -2260), Vector2(-400, -2260), Vector2(-640, -2050)])
	draw_colored_polygon(upper, C_HULL)
	draw_polyline(PackedVector2Array([Vector2(-640, -2050), Vector2(-400, -2260), Vector2(400, -2260), Vector2(640, -2050)]), C_RIM, 5.0)
	draw_line(Vector2(-720, -1100), Vector2(720, -1100), C_RIM, 4.0)
	for y in [-700.0, -830.0, -960.0]:
		draw_line(Vector2(-740, y), Vector2(740, y), C_HULL_DARK, 8.0)
		draw_line(Vector2(-740, y + 8), Vector2(740, y + 8), Color(C_RIM, 0.25), 2.0)
	# 장갑 판 이음매와 리벳
	for x in [-560.0, -400.0, 400.0, 560.0]:
		draw_line(Vector2(x, -1120), Vector2(x * 0.92, -2080), Color(C_HULL_DARK, 1.0), 5.0)
	for k in 7:
		var y := -1180.0 - k * 130.0
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(s * 470.0, y), 6.0, Color(C_RIM, 0.5))
	# 녹슨 줄무늬 (경고 표시)
	for k in 6:
		var x := -300.0 + k * 120.0
		draw_line(Vector2(x, -1060), Vector2(x + 50, -1000), Color(C_RUST, 0.9), 14.0)


func _draw_spire() -> void:
	var sp := PackedVector2Array([Vector2(-170, -2240), Vector2(170, -2240), Vector2(95, -2690), Vector2(0, -2800), Vector2(-95, -2690)])
	draw_colored_polygon(sp, C_HULL)
	var ol := sp.duplicate()
	ol.append(sp[0])
	draw_polyline(ol, C_RIM, 4.0)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(s * 60, -2700), Vector2(s * 210, -2960), Color(C_RIM, 0.7), 5.0)
		draw_circle(Vector2(s * 210, -2960), 9.0, Color(1.0, 0.3, 0.2, 0.5 + 0.5 * float(int(t * 2.0) % 2)))
	var g := glow[4]
	if phase == 3 or not (part_alive(0) or part_alive(1)) or g > 0.0:
		draw_circle(SPIRE_TOP, 30.0 + 26.0 * g, Color(C_GLOW, 0.15 + 0.5 * g))
	draw_circle(SPIRE_TOP, 14.0, Color(C_GLOW, 0.6 + 0.4 * g))


func _draw_batteries() -> void:
	for i in 2:
		var b: Vector2 = BATTERIES[i]
		var tip: Vector2 = BARREL_TIPS[i]
		var d := (tip - b).normalized()
		var n := d.orthogonal()
		if part_alive(i):
			for k in [-1.0, 1.0]:                       # 쌍열 포신
				_cap(b + n * 26.0 * k, tip + n * 26.0 * k, 34.0, C_HULL_DARK)
				draw_line(b + n * 26.0 * k, tip + n * 26.0 * k, Color(C_RIM, 0.35), 3.0)
			var g := glow[i]
			draw_circle(tip, 26.0 + 20.0 * g, Color(C_GLOW, 0.12 + 0.55 * g))
		else:
			_cap(b, b + d * 70.0, 50.0, C_HULL_DARK)
			draw_circle(b + d * 70.0, 18.0, Color(C_HEART, 0.25 + 0.15 * sin(t * 4.0)))
		draw_circle(b, 110.0, C_HULL)
		draw_arc(b, 110.0, PI, TAU, 26, C_RIM, 6.0)
		draw_rect(Rect2(b.x - 130.0, b.y + 40.0, 260.0, 60.0), C_HULL_DARK)


func _draw_silos() -> void:
	for k in 2:
		var p: Vector2 = SILOS[k]
		var r := Rect2(p.x - 110.0, p.y - 150.0, 220.0, 300.0)
		draw_rect(r, C_HULL_DARK)
		draw_rect(r, Color(C_RIM, 0.6), false, 4.0)
		for j in 3:
			draw_line(Vector2(r.position.x, r.position.y + 80.0 + j * 70.0), Vector2(r.end.x, r.position.y + 80.0 + j * 70.0), Color(C_RIM, 0.25), 3.0)
		var hatch := p + Vector2(0, -110)
		if part_alive(2 + k):
			var g := glow[2 + k]
			var open := g * 50.0
			draw_rect(Rect2(hatch.x - 90.0 - open, hatch.y - 18.0, 90.0, 36.0), C_HULL)
			draw_rect(Rect2(hatch.x + open, hatch.y - 18.0, 90.0, 36.0), C_HULL)
			if g > 0.0:
				draw_rect(Rect2(hatch.x - open, hatch.y - 18.0, open * 2.0, 36.0), Color(C_GLOW, 0.3 + 0.6 * g))
		else:
			draw_circle(hatch, 34.0, C_CAVITY)
			draw_circle(hatch, 16.0, Color(C_HEART, 0.3 + 0.15 * sin(t * 4.0 + k)))


## 방폭문: 페이즈 1은 닫힘, 2는 위아래로 열리는 중, 3은 반응로
func _draw_doors() -> void:
	var open_k := 0.0 if phase == 1 else (1.0 if phase == 3 else clampf(open_t / OPEN_TIME, 0.0, 1.0))
	if open_k > 0.0:
		_draw_reactor()
	if open_k >= 1.0:
		return
	var rc := DOOR_RECT
	var half_h := rc.size.y * 0.5
	var slide := ease(open_k, 2.2) * (half_h + 20.0)
	var alpha := 1.0 - maxf(0.0, open_k - 0.7) / 0.3
	for s in [-1.0, 1.0]:
		var y0: float = rc.position.y + (0.0 if s < 0.0 else half_h) + s * slide
		var door := Rect2(rc.position.x, y0, rc.size.x, half_h)
		draw_rect(door, Color(C_HULL_DARK, alpha))
		draw_rect(door, Color(C_RIM, 0.6 * alpha), false, 4.0)
		for k in 5:                                   # 경고 줄무늬
			var x := door.position.x + 40.0 + k * 100.0
			draw_line(Vector2(x, door.position.y + 20.0), Vector2(x + 40.0, door.end.y - 20.0), Color(C_RUST, 0.7 * alpha), 10.0)
	if open_k > 0.0:
		var gap := slide * 2.0
		draw_rect(Rect2(rc.position.x, REACTOR_POS.y - gap * 0.5, rc.size.x, gap), Color(C_HEART, 0.25 * (1.0 - open_k)))
	else:
		draw_line(Vector2(rc.position.x, REACTOR_POS.y), Vector2(rc.end.x, REACTOR_POS.y), Color(C_HEART, 0.18 + 0.1 * sin(t * 3.0)), 3.0)
	if glow[6] > 0.0:                                 # 동심원 파동 예고: 문틈으로 보랏빛
		draw_line(Vector2(rc.position.x, REACTOR_POS.y), Vector2(rc.end.x, REACTOR_POS.y), Color(1.0, 0.62, 0.86, glow[6]), 4.0 + 10.0 * glow[6])


## 반응로: 안쪽은 회전하는 제어봉과 맥동하는 코어, 바깥은 강철 판(장갑)
func _draw_reactor() -> void:
	var hc := REACTOR_POS
	var f: float = core.frac()
	var beat := 0.5 + 0.5 * sin(t * (4.0 + f * 5.0))
	var lit := strike_glow or focus_glow > 0.0
	var shell: PackedVector2Array = core.shell_poly
	if dead:
		draw_colored_polygon(shell, Color(0.12, 0.05, 0.03))
		var k := minf(1.0, death_t / 1.2)
		draw_circle(hc, CORE_R + k * 240.0, Color(C_HEART, 0.5 * (1.0 - k)))
		draw_arc(hc, CORE_R + k * 450.0, 0.0, TAU, 48, Color(1, 0.9, 0.7, 1.0 - k), 6.0)
		return
	draw_colored_polygon(shell, Color(0.1, 0.06, 0.04))
	draw_colored_polygon(core.shell_inner, Color(0.2, 0.09, 0.05).lerp(Color(0.4, 0.14, 0.06), f * 0.6))
	for k in 6:                                       # 제어봉 (돌아간다)
		var a := t * (0.6 + f) + k * TAU / 6.0
		draw_line(hc + Vector2.from_angle(a) * 80.0, hc + Vector2.from_angle(a) * 170.0, Color(0.5, 0.3, 0.15, 0.8), 10.0)
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
	for v in VENTS:                                   # 코어 페이즈 유도탄 배기구
		var g := glow[4]
		draw_circle(v, 40.0, C_HULL_DARK)
		draw_arc(v, 40.0, 0.0, TAU, 20, C_RIM, 4.0)
		draw_circle(v, 14.0 + 12.0 * g, Color(C_GLOW, 0.3 + 0.6 * g))
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


func _draw_debris() -> void:
	for d in debris:
		var p: Vector2 = d["pos"]
		var half: Vector2 = d["half"]
		draw_set_transform(p, float(d["rot"]))
		_cap(-half, half, float(d["w"]), C_HULL_DARK)
		draw_circle(-half, float(d["w"]) * 0.35, Color(C_HEART, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0)

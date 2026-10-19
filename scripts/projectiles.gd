extends RefCounted
## 탄 시스템: 탄을 딕셔너리 대신 배열 묶음(위치·속도·수명·나이·중력·종류·주인)으로 들고 한꺼번에 움직이고 그린다.
## 탄 하나 = 같은 인덱스의 값들. 지울 때도 순서를 지킨다(먼저 쏜 탄이 먼저 판정된다).
## 주탄과 잔탄은 색·모양·크기를 모두 다르게 해서 한눈에 구별한다:
##  - 주탄(BOLT·LAVA·HOMING): 크고 둥근 금색 + 흰 심 + 금빛 번짐. 패리하면 리버스 드라이브 (금색 = 보상이 있는 패리)
##  - 잔탄(SMALL): 작고 뾰족한 주황빛(붉은 기가 도는 노랑) 별, 번짐 없음, 짧게 깜빡임. 맞으면 아프지만 패리해도 흡수될 뿐 (조준 없음).
##    패리할 수 있으니 금색 계열이지만, 붉은 기와 별 모양으로 둥근 금색 주탄과 구별한다
## 반사 코어·반격 코어로 되돌린 탄은 플레이어 것(mine)이 되어 청백색으로 바뀌고, 표적에 닿으면 피해를 준다.

enum Kind { BOLT, LAVA, SMALL, HOMING, SHELL }   # 일반 주탄 / 용융물 덩어리(포물선) / 잔탄 / 유도탄(크고 느리게 쫓아옴) / 대구경 포탄(크고 느린 주탄, 규칙은 주탄과 같다)

const R := 16.0                       # 주탄 판정 반지름
const RADII := [16.0, 16.0, 10.0, 24.0, 40.0]  # 종류별 판정 반지름
const WARMUP := 0.3                   # 발사 직후 50% 속도에서 출발해 이 시간 동안 100%까지
const WARMUP_FLOOR := 0.5
const HOMING_TIME := 3.6              # 유도탄은 발사 후 이 시간 동안만 방향을 튼다
const HOMING_TURN := 2.0              # 초당 회전 (라디안)
const STEER_CONE := 1.75              # steer 를 준 유도탄이 쫓는 앞쪽 범위 (반각, 약 100도)
const HOMING_BLINK := 1.2             # 적 유도탄은 수명이 이만큼 남으면 점멸한다 (곧 사라진다는 표시)
const SHELL_HOME := 9.0               # 대구경 포탄: 이 시간 동안 플레이어 쪽으로 천천히 방향을 튼다 (중요한 탄이 엉뚱한 데로 지나가지 않게)
const SHELL_TURN := 1.1
const ORBIT_SPIN := 1.3               # 호위탄이 포탄 둘레를 도는 속도 (rad/s)
const REFLECT_SPEED := 1500.0         # 반사된 탄 속도
const REFLECT_DMG := [1.0, 1.0, 0.5, 3.0, 3.0]   # 반사된 탄의 피해: 주탄 1 · 용융물 1 · 잔탄 0.5 · 유도탄 3 · 대구경 3 (main.gd 가 소수점을 모은다)
const KILL_X := 1250.0                # 이 밖으로 나가면 사라진다 (벽 너머 / 용암 / 천장 위)
const KILL_FLOOR := -6.0
const KILL_TOP := -3100.0
const C_BOLT := Color(1.0, 0.88, 0.35)
const C_LAVA := Color(1.0, 0.35, 0.12)
const C_MINE := Color(0.7, 0.95, 1.0)  # 반사된(플레이어) 탄
const C_HOMING := Color(1.0, 0.3, 0.12)  # 유도탄: 금색 몸에 붉은 불길 (쫓아오는 위험한 주탄)
const C_SMALL := Color(1.0, 0.58, 0.12)  # 잔탄: 붉은 기가 도는 노랑(주황) — 패리 가능 = 금색 계열, 주탄 금색보다 붉게

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat64Array()
var age := PackedFloat64Array()
var grav := PackedFloat64Array()
var kind := PackedByteArray()
var mine := PackedByteArray()         # 1 = 플레이어 것 (반사됨)
var dodged := PackedByteArray()       # 1 = 플레이어가 회피 무적으로 통과한 탄 (그 뒤로는 맞지 않는다)
var grp := PackedInt32Array()         # 묶음 번호 (0 = 없음). 묶음의 우두머리(orb_r 0)를 나머지가 orb_r 반지름으로 돌며 따라간다
var orb := PackedFloat64Array()       # 묶음 안의 각도
var orb_r := PackedFloat64Array()
var steer := PackedFloat64Array()     # 유도탄 선회력 (0 = 기본 HOMING_TURN, 그 밖 = 이 값으로 앞쪽 목표만 쫓는다)
static var _next_grp := 1

static var _tex_bolt: Texture2D
static var _tex_lava: Texture2D
static var _tex_small: Texture2D
static var _tex_homing: Texture2D


func size() -> int:
	return pos.size()


func is_empty() -> bool:
	return pos.is_empty()


func clear() -> void:
	pos.clear()
	vel.clear()
	life.clear()
	age.clear()
	grav.clear()
	kind.clear()
	mine.clear()
	dodged.clear()
	grp.clear()
	orb.clear()
	orb_r.clear()
	steer.clear()


func spawn(p: Vector2, v: Vector2, lf: float, a := 0.0, g := 0.0, k := Kind.BOLT, group := 0, orbit_a := 0.0, orbit_r := 0.0, turn := 0.0) -> void:
	pos.append(p)
	vel.append(v)
	life.append(lf)
	age.append(a)
	grav.append(g)
	kind.append(k)
	mine.append(0)
	dodged.append(0)
	grp.append(group)
	orb.append(orbit_a)
	orb_r.append(orbit_r)
	steer.append(turn)


## 새 묶음 번호 (대구경 포탄 + 호위탄)
static func new_group() -> int:
	_next_grp += 1
	return _next_grp


func remove(i: int) -> void:
	pos.remove_at(i)
	vel.remove_at(i)
	life.remove_at(i)
	age.remove_at(i)
	grav.remove_at(i)
	kind.remove_at(i)
	mine.remove_at(i)
	dodged.remove_at(i)
	grp.remove_at(i)
	orb.remove_at(i)
	orb_r.remove_at(i)
	steer.remove_at(i)


func is_lava(i: int) -> bool:
	return kind[i] == Kind.LAVA


## 움직이고, 수명이 다했거나 경기장 밖으로 나간 탄을 지운다. 사라진 위치들을 돌려준다 (연출용).
## 유도탄은 적 것이면 player 쪽으로, 반사된 것이면 boss_target 쪽으로 방향을 튼다
func step(dt: float, player: Vector2, boss_target: Vector2) -> PackedVector2Array:
	var popped := PackedVector2Array()
	var w := 0
	for i in pos.size():
		var v := vel[i]
		v.y += grav[i] * dt
		var a := age[i] + dt
		if kind[i] == Kind.HOMING and a < HOMING_TIME:
			var want := (boss_target if mine[i] == 1 else player) - pos[i]
			var da := wrapf(want.angle() - v.angle(), -PI, PI)
			if steer[i] <= 0.0:
				v = v.rotated(clampf(da, -HOMING_TURN * dt, HOMING_TURN * dt))
			elif absf(da) < STEER_CONE:                   # 앞쪽 목표만 세게 쫓는다 (지나치면 돌아오지 않는다)
				v = v.rotated(clampf(da, -steer[i] * dt, steer[i] * dt))
		elif kind[i] == Kind.SHELL and mine[i] == 0 and a < SHELL_HOME:
			var da2 := wrapf((player - pos[i]).angle() - v.angle(), -PI, PI)
			v = v.rotated(clampf(da2, -SHELL_TURN * dt, SHELL_TURN * dt))
		var p := pos[i] + v * lerpf(WARMUP_FLOOR, 1.0, minf(1.0, a / WARMUP)) * dt
		var lf := life[i] - dt
		if lf <= 0.0 or p.y > KILL_FLOOR or p.x < -KILL_X or p.x > KILL_X or p.y < KILL_TOP:
			popped.append(p)
			continue
		pos[w] = p
		vel[w] = v
		life[w] = lf
		age[w] = a
		grav[w] = grav[i]
		kind[w] = kind[i]
		mine[w] = mine[i]
		dodged[w] = dodged[i]
		grp[w] = grp[i]
		orb[w] = orb[i]
		orb_r[w] = orb_r[i]
		steer[w] = steer[i]
		w += 1
	if w < pos.size():
		pos.resize(w)
		vel.resize(w)
		life.resize(w)
		age.resize(w)
		grav.resize(w)
		kind.resize(w)
		mine.resize(w)
		dodged.resize(w)
		grp.resize(w)
		orb.resize(w)
		orb_r.resize(w)
		steer.resize(w)
	_follow_groups()
	return popped


## 묶음: 우두머리 둘레를 돌며 따라간다. 우두머리가 사라지면(패리·수명) 마지막 속도 그대로 흩어진다
func _follow_groups() -> void:
	var lead := {}
	for i in pos.size():
		if grp[i] > 0 and orb_r[i] <= 0.0:
			lead[grp[i]] = i
	for i in pos.size():
		if grp[i] <= 0 or orb_r[i] <= 0.0:
			continue
		if not lead.has(grp[i]) or mine[i] == 1:
			grp[i] = 0
			continue
		var j: int = lead[grp[i]]
		pos[i] = pos[j] + Vector2.from_angle(orb[i] + age[i] * ORBIT_SPIN) * orb_r[i]
		vel[i] = vel[j]


## p 에서 거리 reach 안에 있는 적 탄들의 판정 상자 (탄마다 상자를 만들지 않고 가까운 것만)
func hitboxes_near(p: Vector2, reach: float, out: Array[Dictionary]) -> void:
	for i in pos.size():
		if mine[i] == 1:
			continue
		var r: float = RADII[kind[i]]
		if pos[i].distance_squared_to(p) <= (reach + r) * (reach + r):
			out.append({"id": "bolt", "pos": pos[i], "r": r, "push": vel[i].normalized(), "idx": i,
				"lava": kind[i] == Kind.LAVA, "small": kind[i] == Kind.SMALL, "homing": kind[i] == Kind.HOMING})


## p 둘레 r 안의 적 탄을 지운다 (동조 코어). 지운 개수
func clear_near(p: Vector2, r: float) -> int:
	var n := 0
	for i in range(pos.size() - 1, -1, -1):
		if mine[i] == 0 and pos[i].distance_to(p) < r:
			remove(i)
			n += 1
	return n


## 반사: p 에서 reach 안의 적 탄을 플레이어 것으로 바꿔 target 쪽으로 되돌린다. 바꾼 개수
func reflect_near(p: Vector2, reach: float, target: Vector2) -> int:
	var n := 0
	for i in pos.size():
		if mine[i] == 1 or kind[i] == Kind.LAVA:
			continue
		if pos[i].distance_to(p) <= reach + RADII[kind[i]]:
			reflect_one(i, target)
			n += 1
	return n


## 탄 하나를 플레이어 것으로 바꿔 target 쪽으로 빠르게 되돌린다 (반사 코어·반격 코어)
func reflect_one(i: int, target: Vector2) -> void:
	mine[i] = 1
	vel[i] = (target - pos[i]).normalized() * REFLECT_SPEED
	grav[i] = 0.0
	age[i] = WARMUP
	life[i] = 4.0


## 플레이어 것(반사된 탄)이 표적에 닿으면 지우고 [{pos, hit, dmg}] 로 돌려준다
func take_hits(boss) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := pos.size() - 1
	while i >= 0:
		if mine[i] == 1:
			var hit: Dictionary = boss.strike_hit(pos[i], RADII[kind[i]])
			if not hit.is_empty():
				out.append({"pos": pos[i], "hit": hit, "dmg": REFLECT_DMG[kind[i]]})
				remove(i)
		i -= 1
	return out


## 꼬리는 한꺼번에, 몸은 텍스처 한 장으로 (금빛 번짐 + 금색 몸 + 흰 심). 유도탄은 도는 고리, 반사된 탄은 청백색
func draw(ci: CanvasItem) -> void:
	if pos.is_empty():
		return
	if _tex_bolt == null:
		_tex_bolt = _make_tex(C_BOLT)
		_tex_lava = _make_tex(C_LAVA)
		_tex_small = _make_small_tex()
		_tex_homing = _make_homing_tex()
	var tails := PackedVector2Array()
	var lava_tails := PackedVector2Array()
	var mine_tails := PackedVector2Array()
	var small_tails := PackedVector2Array()
	var homing_tails := PackedVector2Array()
	for i in pos.size():
		var p := pos[i]
		var tail := p - vel[i].normalized() * (26.0 if kind[i] == Kind.SMALL else (90.0 if kind[i] == Kind.SHELL else 50.0))
		if mine[i] == 1:
			mine_tails.append_array(PackedVector2Array([p, tail]))
		elif kind[i] == Kind.SMALL:
			small_tails.append_array(PackedVector2Array([p, tail]))
		elif kind[i] == Kind.HOMING:
			homing_tails.append_array(PackedVector2Array([p, tail]))
		elif kind[i] == Kind.LAVA:
			lava_tails.append_array(PackedVector2Array([p, tail]))
		else:
			tails.append_array(PackedVector2Array([p, tail]))
	if not tails.is_empty():
		ci.draw_multiline(tails, Color(C_BOLT, 0.35), 10.0)
	if not homing_tails.is_empty():
		ci.draw_multiline(homing_tails, Color(C_HOMING, 0.5), 14.0)
	if not lava_tails.is_empty():
		ci.draw_multiline(lava_tails, Color(C_LAVA, 0.35), 10.0)
	if not mine_tails.is_empty():
		ci.draw_multiline(mine_tails, Color(C_MINE, 0.5), 8.0)
	if not small_tails.is_empty():
		ci.draw_multiline(small_tails, Color(C_SMALL, 0.4), 4.0)
	var blink := 0.82 + 0.18 * float(int(Time.get_ticks_msec() / 70) % 2)
	var spin := Time.get_ticks_msec() * 0.006
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for i in pos.size():
		var k := kind[i]
		var half: Vector2 = Vector2.ONE * float(RADII[k]) * 1.8
		var mod := Color(0.75, 1.0, 1.0) if mine[i] == 1 else Color.WHITE
		if k == Kind.SMALL:
			half = Vector2.ONE * RADII[k] * 2.1
			if mine[i] == 0:
				mod = Color(1, 1, 1, blink)
			ci.draw_texture_rect(_tex_small, Rect2(pos[i] - half, half * 2.0), false, mod)
			continue
		var hot: bool = k == Kind.HOMING and mine[i] == 0
		var fade := 1.0
		if hot:
			half = Vector2.ONE * float(RADII[k]) * 2.1
			if life[i] < HOMING_BLINK:              # 곧 사라진다: 점멸 (끝에 가까울수록 빠르게)
				fade = 1.0 if fmod(sqrt(life[i]) * 10.0, 1.0) > 0.4 else 0.22
				mod = Color(1, 1, 1, fade)
		var tex: Texture2D = _tex_lava if k == Kind.LAVA else (_tex_homing if hot else _tex_bolt)
		if k == Kind.SHELL and mine[i] == 0:        # 대구경 포탄: 크고 무겁게 — 번지는 열기, 맥동하는 금빛 고리 둘, 도는 날
			ci.draw_circle(pos[i], RADII[k] * 3.0 + 10.0 * pulse, Color(1.0, 0.6, 0.2, 0.08))
			ci.draw_circle(pos[i], RADII[k] * 2.0 + 6.0 * pulse, Color(C_BOLT, 0.16))
			ci.draw_arc(pos[i], RADII[k] + 12.0 + 5.0 * pulse, 0.0, TAU, 28, Color(1.0, 0.95, 0.7, 0.85), 4.0)
			for j in 6:
				var a0 := -spin * 0.6 + j * TAU / 6.0
				ci.draw_arc(pos[i], RADII[k] + 26.0, a0, a0 + 0.5, 6, Color(1.0, 0.8, 0.4, 0.7), 5.0)
		ci.draw_texture_rect(tex, Rect2(pos[i] - half, half * 2.0), false, mod)
		if k == Kind.HOMING:                      # 유도탄: 바깥에서 도는 끊긴 고리 (쫓아온다는 모양 단서). 적 것은 붉게 맥동한다
			var rr: float = RADII[k] + 9.0
			if hot:
				ci.draw_arc(pos[i], rr + 7.0 + 4.0 * pulse, 0.0, TAU, 20, Color(C_HOMING, 0.4 * fade), 2.0)
			var segs := 4 if hot else 3
			for j in segs:
				var a0 := spin * (1.6 if hot else 1.0) + j * TAU / float(segs)
				ci.draw_arc(pos[i], rr, a0, a0 + (1.0 if hot else 1.3), 8, Color(C_MINE, 0.9) if mine[i] == 1 else Color(1.0, 0.45, 0.2, 0.95 * fade), 4.0 if hot else 3.0)


## 잔탄 텍스처: 네 갈래로 뾰족한 주황 별 (가운데는 밝은 노랑, 테두리는 짙은 갈색, 번짐 없음) — 금색 둥근 주탄과 모양부터 다르게
static func _make_small_tex() -> Texture2D:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var q := Vector2(absf(x - c), absf(y - c)) / (n * 0.5)
			var d := sqrt(q.x) + sqrt(q.y)              # 아스트로이드(네 갈래 별) 거리
			var col := Color(0, 0, 0, 0)
			if d <= 0.55:
				col = Color(1.0, 0.93, 0.6)
			elif d <= 0.85:
				col = C_SMALL
			elif d <= 1.0:
				col = Color(0.5, 0.17, 0.02)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 유도탄 텍스처: 흰 심 + 주황 금색 몸 + 붉은 테두리와 붉은 불길 번짐 (금색 = 패리 가능은 그대로, 더 눈에 띄고 위험해 보이게)
static func _make_homing_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n * 0.5)
			var col := Color(0, 0, 0, 0)
			if d <= 0.25:
				col = Color(1, 1, 0.85)
			elif d <= 0.5:
				col = Color(1.0, 0.7, 0.14)
			elif d <= 0.66:
				col = Color(1.0, 0.28, 0.08, 0.95)
			elif d <= 1.0:
				col = Color(C_HOMING, 0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 탄 텍스처: 반지름 비율 0.55 까지 금색 몸, 0.28 까지 흰 심, 바깥은 옅은 번짐 (그리는 크기 = 반지름 × 3.6)
static func _make_tex(outer: Color) -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n * 0.5)
			var col := Color(0, 0, 0, 0)
			if d <= 0.28:
				col = Color(1, 1, 0.9)
			elif d <= 0.555:
				col = C_BOLT
			elif d <= 1.0:
				col = Color(outer, 0.22)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

extends RefCounted
## 탄 시스템: 탄을 딕셔너리 대신 배열 묶음(위치·속도·수명·나이·중력·종류·주인)으로 들고 한꺼번에 움직이고 그린다.
## 탄 하나 = 같은 인덱스의 값들. 지울 때도 순서를 지킨다(먼저 쏜 탄이 먼저 판정된다).
## 금색 = 패리할 수 있는 것 (모든 콜로서스 공통 색 언어). 크기로 역할을 구별한다:
##  - 주탄(BOLT·LAVA·HOMING): 크다. 패리하면 리버스 드라이브
##  - 잔탄(SMALL): 작다. 패리하면 흡수되어 사라지기만 한다 (조준 없음)
## 반사 코어로 되돌린 탄은 플레이어 것(mine)이 되어 청백색으로 바뀌고, 표적에 닿으면 피해를 준다.

enum Kind { BOLT, LAVA, SMALL, HOMING }   # 일반 주탄 / 용융물 덩어리(포물선) / 잔탄 / 유도탄(크고 느리게 쫓아옴)

const R := 16.0                       # 주탄 판정 반지름
const RADII := [16.0, 16.0, 9.0, 24.0]  # 종류별 판정 반지름
const WARMUP := 0.3                   # 발사 직후 50% 속도에서 출발해 이 시간 동안 100%까지
const WARMUP_FLOOR := 0.5
const HOMING_TIME := 3.2              # 유도탄은 발사 후 이 시간 동안만 방향을 튼다
const HOMING_TURN := 1.7              # 초당 회전 (라디안)
const REFLECT_SPEED := 1500.0         # 반사된 탄 속도
const REFLECT_DMG := [1, 1, 1, 3]     # 반사된 탄의 피해 (유도탄은 되돌리면 크게)
const KILL_X := 1250.0                # 이 밖으로 나가면 사라진다 (벽 너머 / 용암 / 천장 위)
const KILL_FLOOR := -6.0
const KILL_TOP := -3100.0
const C_BOLT := Color(1.0, 0.88, 0.35)
const C_LAVA := Color(1.0, 0.35, 0.12)
const C_MINE := Color(0.7, 0.95, 1.0)  # 반사된(플레이어) 탄

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat64Array()
var age := PackedFloat64Array()
var grav := PackedFloat64Array()
var kind := PackedByteArray()
var mine := PackedByteArray()         # 1 = 플레이어 것 (반사됨)

static var _tex_bolt: Texture2D
static var _tex_lava: Texture2D


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


func spawn(p: Vector2, v: Vector2, lf: float, a := 0.0, g := 0.0, k := Kind.BOLT) -> void:
	pos.append(p)
	vel.append(v)
	life.append(lf)
	age.append(a)
	grav.append(g)
	kind.append(k)
	mine.append(0)


func remove(i: int) -> void:
	pos.remove_at(i)
	vel.remove_at(i)
	life.remove_at(i)
	age.remove_at(i)
	grav.remove_at(i)
	kind.remove_at(i)
	mine.remove_at(i)


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
			v = v.rotated(clampf(da, -HOMING_TURN * dt, HOMING_TURN * dt))
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
		w += 1
	if w < pos.size():
		pos.resize(w)
		vel.resize(w)
		life.resize(w)
		age.resize(w)
		grav.resize(w)
		kind.resize(w)
		mine.resize(w)
	return popped


## p 에서 거리 reach 안에 있는 적 탄들의 판정 상자 (탄마다 상자를 만들지 않고 가까운 것만)
func hitboxes_near(p: Vector2, reach: float, out: Array[Dictionary]) -> void:
	for i in pos.size():
		if mine[i] == 1:
			continue
		var r: float = RADII[kind[i]]
		if pos[i].distance_squared_to(p) <= (reach + r) * (reach + r):
			out.append({"id": "bolt", "pos": pos[i], "r": r, "push": vel[i].normalized(), "idx": i,
				"lava": kind[i] == Kind.LAVA, "small": kind[i] == Kind.SMALL, "homing": kind[i] == Kind.HOMING})


## 반사: p 에서 reach 안의 적 탄을 플레이어 것으로 바꿔 target 쪽으로 되돌린다. 바꾼 개수
func reflect_near(p: Vector2, reach: float, target: Vector2) -> int:
	var n := 0
	for i in pos.size():
		if mine[i] == 1 or kind[i] == Kind.LAVA:
			continue
		if pos[i].distance_to(p) <= reach + RADII[kind[i]]:
			mine[i] = 1
			vel[i] = (target - pos[i]).normalized() * REFLECT_SPEED
			age[i] = WARMUP
			life[i] = 4.0
			n += 1
	return n


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
	var tails := PackedVector2Array()
	var lava_tails := PackedVector2Array()
	var mine_tails := PackedVector2Array()
	for i in pos.size():
		var p := pos[i]
		var tail := p - vel[i].normalized() * (26.0 if kind[i] == Kind.SMALL else 50.0)
		if mine[i] == 1:
			mine_tails.append_array(PackedVector2Array([p, tail]))
		elif kind[i] == Kind.LAVA:
			lava_tails.append_array(PackedVector2Array([p, tail]))
		else:
			tails.append_array(PackedVector2Array([p, tail]))
	if not tails.is_empty():
		ci.draw_multiline(tails, Color(C_BOLT, 0.35), 10.0)
	if not lava_tails.is_empty():
		ci.draw_multiline(lava_tails, Color(C_LAVA, 0.35), 10.0)
	if not mine_tails.is_empty():
		ci.draw_multiline(mine_tails, Color(C_MINE, 0.5), 8.0)
	var spin := Time.get_ticks_msec() * 0.006
	for i in pos.size():
		var k := kind[i]
		var half: Vector2 = Vector2.ONE * float(RADII[k]) * 1.8
		var mod := Color(0.75, 1.0, 1.0) if mine[i] == 1 else Color.WHITE
		ci.draw_texture_rect(_tex_lava if k == Kind.LAVA else _tex_bolt, Rect2(pos[i] - half, half * 2.0), false, mod)
		if k == Kind.HOMING:                      # 유도탄: 바깥에서 도는 끊긴 고리 (쫓아온다는 모양 단서)
			var rr: float = RADII[k] + 9.0
			for j in 3:
				var a0 := spin + j * TAU / 3.0
				ci.draw_arc(pos[i], rr, a0, a0 + 1.3, 8, Color(C_MINE, 0.9) if mine[i] == 1 else Color(1.0, 0.95, 0.7, 0.9), 3.0)


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

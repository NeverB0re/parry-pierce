extends RefCounted
## 탄 시스템: 탄을 딕셔너리 대신 배열 묶음(위치·속도·수명·나이·중력·종류)으로 들고 한꺼번에 움직이고 그린다.
## 탄 하나 = 같은 인덱스의 값들. 지울 때도 순서를 지킨다(먼저 쏜 탄이 먼저 판정된다).
## 금색 = 패리할 수 있는 것 (모든 콜로서스 공통 색 언어)

enum Kind { BOLT, LAVA }              # 일반 탄 / 용융물 덩어리(포물선, 붉은 겉불)

const R := 16.0                       # 판정 반지름
const WARMUP := 0.3                   # 발사 직후 50% 속도에서 출발해 이 시간 동안 100%까지
const WARMUP_FLOOR := 0.5
const KILL_X := 1250.0                # 이 밖으로 나가면 사라진다 (벽 너머 / 용암 / 천장 위)
const KILL_FLOOR := -6.0
const KILL_TOP := -3100.0
const C_BOLT := Color(1.0, 0.88, 0.35)
const C_LAVA := Color(1.0, 0.35, 0.12)

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat64Array()
var age := PackedFloat64Array()
var grav := PackedFloat64Array()
var kind := PackedByteArray()

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


func spawn(p: Vector2, v: Vector2, lf: float, a := 0.0, g := 0.0, k := Kind.BOLT) -> void:
	pos.append(p)
	vel.append(v)
	life.append(lf)
	age.append(a)
	grav.append(g)
	kind.append(k)


func remove(i: int) -> void:
	pos.remove_at(i)
	vel.remove_at(i)
	life.remove_at(i)
	age.remove_at(i)
	grav.remove_at(i)
	kind.remove_at(i)


func is_lava(i: int) -> bool:
	return kind[i] == Kind.LAVA


## 움직이고, 수명이 다했거나 경기장 밖으로 나간 탄을 지운다. 사라진 위치들을 돌려준다 (연출용)
func step(dt: float) -> PackedVector2Array:
	var popped := PackedVector2Array()
	var w := 0
	for i in pos.size():
		var v := vel[i]
		v.y += grav[i] * dt
		var a := age[i] + dt
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
		w += 1
	if w < pos.size():
		pos.resize(w)
		vel.resize(w)
		life.resize(w)
		age.resize(w)
		grav.resize(w)
		kind.resize(w)
	return popped


## p 에서 거리 reach 안에 있는 탄들의 판정 상자 (탄마다 상자를 만들지 않고 가까운 것만)
func hitboxes_near(p: Vector2, reach: float, out: Array[Dictionary]) -> void:
	var lim := (reach + R) * (reach + R)
	for i in pos.size():
		if pos[i].distance_squared_to(p) <= lim:
			out.append({"id": "bolt", "pos": pos[i], "r": R, "push": vel[i].normalized(), "idx": i, "lava": kind[i] == Kind.LAVA})


## 꼬리는 한꺼번에, 몸은 텍스처 한 장으로 (금빛 번짐 + 금색 몸 + 흰 심)
func draw(ci: CanvasItem) -> void:
	if pos.is_empty():
		return
	if _tex_bolt == null:
		_tex_bolt = _make_tex(C_BOLT)
		_tex_lava = _make_tex(C_LAVA)
	var tails := PackedVector2Array()
	var lava_tails := PackedVector2Array()
	for i in pos.size():
		var p := pos[i]
		var tail := p - vel[i].normalized() * 50.0
		if kind[i] == Kind.LAVA:
			lava_tails.append_array(PackedVector2Array([p, tail]))
		else:
			tails.append_array(PackedVector2Array([p, tail]))
	if not tails.is_empty():
		ci.draw_multiline(tails, Color(C_BOLT, 0.35), 10.0)
	if not lava_tails.is_empty():
		ci.draw_multiline(lava_tails, Color(C_LAVA, 0.35), 10.0)
	var half := Vector2(R, R) * 1.8
	for i in pos.size():
		ci.draw_texture_rect(_tex_lava if kind[i] == Kind.LAVA else _tex_bolt, Rect2(pos[i] - half, half * 2.0), false)


## 탄 텍스처: 반지름 비율 0.55 까지 금색 몸, 0.28 까지 흰 심, 바깥은 옅은 번짐 (그리는 크기 = R × 3.6)
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

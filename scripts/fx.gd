extends Node2D
## 불꽃/파편/충격파 링. 월드 좌표.

const Sprites := preload("res://scripts/sprites.gd")

var parts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rays: Array[Dictionary] = []
var sprites: Array[Dictionary] = []
var numbers: Array[Dictionary] = []    # 피해 숫자 {pos, val, color, size, life, max, key}

const NUM_LIFE := 0.8
const NUM_MERGE := 0.35                # 같은 종류가 이 시간 안에 또 맞으면 숫자를 합친다 (반사탄 연타)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # 도트가 번지지 않게
	z_index = 4


func clear() -> void:
	parts.clear()
	rings.clear()
	rays.clear()
	sprites.clear()
	numbers.clear()


## 피해 숫자: 맞은 자리에서 튀어 올랐다 사라진다. key 가 같은 숫자가 방금 떴으면 그 숫자에 더한다
func number(pos: Vector2, val: float, color: Color, size: int, key := "") -> void:
	if key != "":
		for n in numbers:
			if n["key"] == key and float(n["max"]) - float(n["life"]) < NUM_MERGE:
				n["val"] = float(n["val"]) + val
				n["life"] = n["max"]
				n["pop"] = 1.0
				return
	var off := Vector2(float(numbers.size() % 3 - 1) * 30.0, -40.0)   # 겹치지 않게 좌우로 (게임 난수는 쓰지 않는다)
	numbers.append({"pos": pos + off, "val": val, "color": color, "size": size, "life": NUM_LIFE, "max": NUM_LIFE, "key": key, "pop": 1.0})


## 도트 폭발 애니메이션. kind 1(주황 불꽃)/2(주황 링)/3(청록 링), size = 화면에서 보이는 지름(px).
## reverse = 거꾸로 재생(안으로 모이는 연출, 퍼펙트 회피). 퍼펙트 패리·회피 등 큰 이벤트에 쓴다.
func sprite(pos: Vector2, kind: int, size: float, life := 0.45, reverse := false, tint := Color.WHITE, delay := 0.0) -> void:
	sprites.append({"pos": pos, "kind": kind, "size": size, "life": life, "max": life, "reverse": reverse, "tint": tint, "delay": delay})


## 중심에서 사방으로 뻗는 빛줄기
func rays_burst(pos: Vector2, n: int, color: Color, length: float, life := 0.4, width := 6.0) -> void:
	var off := randf() * TAU
	for i in n:
		var a := off + TAU * i / n + randf_range(-0.12, 0.12)
		rays.append({"pos": pos, "dir": Vector2.from_angle(a), "len": length * randf_range(0.7, 1.2), "life": life, "max": life, "color": color, "width": width})


func burst(pos: Vector2, n: int, color: Color, speed: float, life := 0.45, size := 3.0, grav := 0.0, dir := Vector2.ZERO, spread := PI) -> void:
	for i in n:
		var a := randf_range(-spread, spread) + (dir.angle() if dir != Vector2.ZERO else 0.0)
		var v := Vector2.from_angle(a) * speed * randf_range(0.35, 1.0)
		var l := life * randf_range(0.6, 1.0)
		parts.append({"pos": pos, "vel": v, "life": l, "max": l, "color": color, "size": size * randf_range(0.6, 1.2), "grav": grav})


func ring(pos: Vector2, color: Color, max_r: float, life := 0.35, width := 4.0, inward := false) -> void:
	rings.append({"pos": pos, "color": color, "max_r": max_r, "life": life, "max": life, "width": width, "inward": inward})


## 호 하나 (ang 방향을 가운데로 span 만큼). 막아 낸 방패 모양 (근접공격 패리: 피해 없이 튕겨냄)
func arc(pos: Vector2, color: Color, r: float, ang: float, span: float, life := 0.3, width := 6.0) -> void:
	rings.append({"pos": pos, "color": color, "max_r": r, "life": life, "max": life, "width": width, "ang": ang, "span": span})


const MAX_PARTS := 900                 # 입자 상한: 큰 연출이 겹쳐도 프레임이 무너지지 않게 (넘치면 오래된 것부터 버린다)


func step(dt: float) -> void:
	# 배열을 복사하지 않고 뒤에서부터 돌며, 지울 때는 맨 끝 요소와 바꿔 지운다 (순서는 그리기에 영향 없음)
	var i := parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		var l := float(p["life"]) - dt
		if l <= 0.0:
			parts[i] = parts[parts.size() - 1]
			parts.pop_back()
		else:
			p["life"] = l
			var v: Vector2 = p["vel"]
			v.y += float(p["grav"]) * dt
			v *= 1.0 - 2.5 * dt
			p["vel"] = v
			p["pos"] = (p["pos"] as Vector2) + v * dt
		i -= 1
	if parts.size() > MAX_PARTS:
		parts = parts.slice(parts.size() - MAX_PARTS)
	_tick(rings, dt)
	_tick(rays, dt)
	i = sprites.size() - 1
	while i >= 0:
		var sp: Dictionary = sprites[i]
		if float(sp["delay"]) > 0.0:
			sp["delay"] = float(sp["delay"]) - dt
		else:
			sp["life"] = float(sp["life"]) - dt
			if float(sp["life"]) <= 0.0:
				sprites.remove_at(i)              # 스프라이트는 순서(겹침)가 보이므로 순서를 유지한다 (개수가 적다)
		i -= 1
	for n in numbers:
		n["pos"] = (n["pos"] as Vector2) + Vector2(0, -90.0 * dt)
		n["pop"] = maxf(0.0, float(n["pop"]) - dt * 6.0)
	_tick(numbers, dt)
	queue_redraw()


static func _tick(arr: Array[Dictionary], dt: float) -> void:
	var i := arr.size() - 1
	while i >= 0:
		var l := float(arr[i]["life"]) - dt
		if l <= 0.0:
			arr[i] = arr[arr.size() - 1]
			arr.pop_back()
		else:
			arr[i]["life"] = l
		i -= 1


func _draw() -> void:
	for sp in sprites:
		if float(sp["delay"]) > 0.0:
			continue
		var k := 1.0 - float(sp["life"]) / float(sp["max"])
		if sp["reverse"]:
			k = 1.0 - k
		var kind: int = sp["kind"]
		var tex: Texture2D = Sprites.explosion(kind, int(k * Sprites.explosion_frames(kind)))
		var sz: float = sp["size"]
		var tint: Color = sp["tint"]
		draw_texture_rect(tex, Rect2((sp["pos"] as Vector2) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, tint)
	for p in parts:
		var k := float(p["life"]) / float(p["max"])
		var c: Color = p["color"]
		c.a *= k
		var pos: Vector2 = p["pos"]
		var v: Vector2 = p["vel"]
		draw_line(pos, pos - v * 0.035, c, float(p["size"]) * (0.5 + 0.5 * k))
	for r in rays:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var d: Vector2 = r["dir"]
		var p0: Vector2 = r["pos"]
		var l := float(r["len"])
		var rc: Color = r["color"]
		rc.a *= 1.0 - k
		draw_line(p0 + d * l * (0.1 + 0.5 * k), p0 + d * l * (0.3 + 0.7 * k), rc, float(r["width"]) * (1.0 - k) + 1.0)
	for r in rings:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var c: Color = r["color"]
		if r.get("inward", false):                  # 안으로 모이는 링 (퍼펙트 회피)
			c.a *= 0.5 + 0.5 * k
			draw_arc(r["pos"], lerpf(float(r["max_r"]), 8.0, ease(k, 0.6)), 0.0, TAU, 48, c, float(r["width"]) * (0.4 + 0.6 * k) + 1.0)
			continue
		c.a *= 1.0 - k
		if r.has("span"):
			var a0 := float(r["ang"]) - float(r["span"]) * 0.5
			draw_arc(r["pos"], float(r["max_r"]) * (0.75 + 0.25 * ease(k, 0.35)), a0, a0 + float(r["span"]), 20, c, float(r["width"]) * (1.0 - k) + 1.0)
			continue
		draw_arc(r["pos"], float(r["max_r"]) * ease(k, 0.35), 0.0, TAU, 48, c, float(r["width"]) * (1.0 - k) + 1.0)
	var font := ThemeDB.fallback_font
	for n in numbers:
		var k := float(n["life"]) / float(n["max"])
		var v := float(n["val"])
		var txt := str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
		var fs := int(float(n["size"]) * (1.0 + 0.35 * float(n["pop"])))
		var c: Color = n["color"]
		c.a *= minf(1.0, k * 2.5)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = (n["pos"] as Vector2) - Vector2(w * 0.5, 0)
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, c.a * 0.8))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

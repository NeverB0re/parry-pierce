extends Node2D
## 불꽃/파편/충격파 링. 월드 좌표.

const Sprites := preload("res://scripts/sprites.gd")

var parts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rays: Array[Dictionary] = []
var sprites: Array[Dictionary] = []
var streaks: Array[Dictionary] = []    # 잔상 궤적 {a, b, color, life, max}
var absorbs: Array[Dictionary] = []    # 흡수 빛알 {from, delay, life, max} — 빨아들인 보라 줄기가 기체로 빨려 든다
var absorb_target: Node2D              # 빨려 들 곳 (main 이 플레이어를 넣는다)
const C_ABSORB_FROM := Color(0.85, 0.3, 0.7)
const C_ABSORB_TO := Color(0.5, 1.0, 0.88)
const ABSORB_FLY := 0.16               # 빛알이 기체까지 날아가는 시간 (짧게: 회피 직후 버프와 함께 끝나 있게, v0.126)
const ABSORB_UNZIP := 9000.0           # 닿은 곳에서 멀어질수록 아주 조금 늦게 풀린다 (px/초)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # 도트가 번지지 않게
	z_index = 4


func clear() -> void:
	parts.clear()
	rings.clear()
	rays.clear()
	sprites.clear()
	streaks.clear()
	absorbs.clear()


## 도트 폭발 애니메이션. kind 1(주황 불꽃)/2(주황 링)/3(청록 링), size = 화면에서 보이는 지름(px).
## reverse = 거꾸로 재생(안으로 모이는 연출, 퍼펙트 회피). 퍼펙트 패리·회피 등 큰 이벤트에 쓴다.
func sprite(pos: Vector2, kind: int, size: float, life := 0.45, reverse := false, tint := Color.WHITE, delay := 0.0) -> void:
	sprites.append({"pos": pos, "kind": kind, "size": size, "life": life, "max": life, "reverse": reverse, "tint": tint, "delay": delay})


## 잔상 궤적: a → b 직선에 굵은 빛줄기 + 일정 간격 잔상 원이 남았다가 끝(b) 쪽부터 사라진다 (PERFECT 리버스 드라이브)
func streak(a: Vector2, b: Vector2, color: Color, life := 0.4) -> void:
	streaks.append({"a": a, "b": b, "color": color, "life": life, "max": life})


## 흡수: 퍼펙트 회피로 빨아들인 보라 줄기의 점들이 빛알이 되어 기체로 곧장 빨려 든다 (닿은 곳 쪽이 아주 조금 먼저)
func absorb(points: PackedVector2Array, at: Vector2) -> void:
	for q in points:
		absorbs.append({"from": q, "delay": minf(0.06, q.distance_to(at) / ABSORB_UNZIP), "life": ABSORB_FLY, "max": ABSORB_FLY})


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
	_tick(streaks, dt)
	i = absorbs.size() - 1
	while i >= 0:
		var ab: Dictionary = absorbs[i]
		if float(ab["delay"]) > 0.0:
			ab["delay"] = float(ab["delay"]) - dt
		else:
			ab["life"] = float(ab["life"]) - dt
			if float(ab["life"]) <= 0.0:
				absorbs[i] = absorbs[absorbs.size() - 1]
				absorbs.pop_back()
		i -= 1
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
	_draw_absorbs()
	for s in streaks:
		var k := float(s["life"]) / float(s["max"])     # 1 → 0
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var c: Color = s["color"]
		var tail := a.lerp(b, 1.0 - k)                  # 출발점 쪽부터 걷힌다
		draw_line(tail, b, Color(c, 0.35 * k), 34.0 * k + 4.0)
		draw_line(tail, b, Color(1, 1, 1, 0.8 * k), 8.0 * k + 2.0)
		var n := int(a.distance_to(b) / 90.0)
		for q in n:
			var p := a.lerp(b, (q + 0.5) / maxf(1.0, n))
			if (p - a).length() < (tail - a).length():
				continue
			draw_circle(p, 26.0 * (0.4 + 0.6 * k), Color(c, 0.22 * k))
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


## 흡수 빛알: 줄기 자리에서 곧바로 기체로 빨려 들며 청록으로 바뀌고 작아진다 (0.2초 남짓에 끝난다)
func _draw_absorbs() -> void:
	if absorbs.is_empty():
		return
	var tgt := Vector2.ZERO
	if absorb_target != null:
		tgt = to_local(absorb_target.global_position)
	for ab in absorbs:
		var from: Vector2 = ab["from"]
		if float(ab["delay"]) > 0.0:
			draw_circle(from, 22.0, Color(C_ABSORB_FROM, 0.22))
			draw_circle(from, 9.0, Color(1.0, 0.75, 0.95, 0.9))
			continue
		var u := 1.0 - float(ab["life"]) / float(ab["max"])
		var e := u * u * (3.0 - 2.0 * u)
		var p := from.lerp(tgt, e)
		var c := C_ABSORB_FROM.lerp(C_ABSORB_TO, u)
		draw_line(p, from.lerp(tgt, maxf(0.0, e - 0.25)), Color(c, 0.5), 5.0)      # 짧은 꼬리 (빨려 드는 방향이 보이게)
		draw_circle(p, lerpf(8.0, 3.0, u), Color(c.lightened(0.3), 0.95))

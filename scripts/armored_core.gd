extends RefCounted
## 장갑 + 동력 코어 (모든 콜로서스 공통). 체력바 대신 불규칙한 강철 판이 찌그러지고 → 휘고 금이 가고 → 뜯겨 나간다.
## 장갑이 다 부서져도 피해는 코어로 넘어가지 않고, 드러난 코어를 한 번 더 맞혀야 부서진다.
## 모양(외곽선)과 장갑 체력은 콜로서스마다 다르게 준다. 그리는 쪽은 강철 판만 맡고, 안쪽(근육·빛)은 콜로서스가 그린다.

const Ev := preload("res://scripts/ev.gd")

const CORE_HP := 1                          # 장갑이 다 부서진 뒤 코어는 한 발이면 부서진다
const CORE_GUARD := 0.35                    # 장갑이 부서진 직후 이 시간은 코어가 맞아도 부서지지 않는다 (한 번에 둘 다 깨지는 것 방지)
const C_STEEL := Color(0.34, 0.38, 0.45)
const C_STEEL_DARK := Color(0.2, 0.22, 0.27)
const C_PLATE_EDGE := Color(0.62, 0.3, 0.14)     # 상시 표적 → 달궈진 가장자리

var host                                    # 이 코어를 가진 콜로서스 (이벤트·파편을 넘긴다)
var center := Vector2.ZERO
var armor_max := 160
var shell_poly := PackedVector2Array()      # 외곽선 (모서리를 둥글린 것)
var shell_inner := PackedVector2Array()     # 안쪽 윤곽 (외곽선을 0.86배로 줄인 것)
var plates: Array[Dictionary] = []          # 불규칙한 강철 판: poly(중심 기준), cen, th(떨어지는 시점), 패임·균열선, gone
var armor_hp := 0
var core_hp := CORE_HP
var flash := 0.0
var stage := 0                              # 장갑 손상 단계 0~4 (피해 20%마다, 연출용)
var broken := false                         # 장갑이 다 부서져 코어가 드러남 (한 발 더 필요)
var guard := 0.0


## outline: center 기준 외곽선 꼭짓점. site_box: 판 중심을 뿌릴 범위(center 기준). sites: 판 수
func _init(owner, c: Vector2, outline: Array, armor: int, site_box: Rect2, sites: int, seed_v: int) -> void:
	host = owner
	center = c
	armor_max = armor
	_build(outline, site_box, sites, seed_v)
	reset()


func reset() -> void:
	armor_hp = armor_max
	core_hp = CORE_HP
	flash = 0.0
	stage = 0
	broken = false
	guard = 0.0
	for pl in plates:
		pl["gone"] = false


func step(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 4.0)
	guard = maxf(0.0, guard - dt)


func frac() -> float:
	return 1.0 - float(armor_hp) / armor_max


## 판의 손상 단계: 0 멀쩡 / 1 찌그러짐 / 2 휘고 금 감 / 3 떨어져 나감.
## 판마다 임계값(th)이 달라 불규칙하게 하나씩 망가진다. f = 장갑 손상 비율 0~1
func plate_level(pl: Dictionary, f: float) -> int:
	var th: float = pl["th"]
	if f >= th or broken:
		return 3
	if f >= th * 0.75:
		return 2
	if f >= th * 0.45:
		return 1
	return 0


## 피해. 장갑이 남아 있으면 장갑만 깎는다(남는 피해는 버린다) → 장갑이 다 부서지면 코어가 드러난다.
## 이미 드러난 코어를 맞히면 true (부서짐). 장갑이 부서진 그 일격으로는 코어가 부서지지 않는다.
func damage(dmg: int) -> bool:
	if core_hp <= 0:
		return false
	if armor_hp > 0:
		armor_hp = maxi(0, armor_hp - dmg)
		flash = 1.0
		_update_plates()
		if armor_hp == 0:
			broken = true
			guard = CORE_GUARD
			host.emit(Ev.ARMOR_BREAK, center)
		return false
	if guard > 0.0:
		flash = 1.0
		return false
	core_hp = 0
	flash = 1.0
	return true


## 손상 비율에 따라 임계값을 넘은 판이 떨어져 나가고(불규칙한 파편), 단계 이벤트를 낸다
func _update_plates() -> void:
	var f := frac()
	var st := mini(4, int(f * 5.0 + 0.001))
	var fell := 0
	for pl in plates:
		if pl["gone"] or plate_level(pl, f) < 3:
			continue
		pl["gone"] = true
		fell += 1
		var cen: Vector2 = pl["cen"]
		var out := (cen - center).normalized()
		var v := out * randf_range(260.0, 420.0) + Vector2(randf_range(-80, 80), randf_range(-380, -180))
		host.shards.append({"pos": cen, "vel": v, "rot": 0.0, "rotv": randf_range(-4.0, 4.0), "pts": pl["poly"]})
	if fell > 0 or st > stage:
		stage = maxi(stage, st)
		host.emit(Ev.CORE_STAGE, center, {"stage": stage, "fell": fell})


## 외곽선과의 충돌: 안쪽이면 중심에서 바깥 방향, 바깥이면 가장 가까운 변에서 바깥 방향이 법선. {kind:"core", n} 또는 {}
func hit(p: Vector2, r: float) -> Dictionary:
	if Geometry2D.is_point_in_polygon(p, shell_poly):
		var n := p - center
		return {"kind": "core", "n": n.normalized() if n.length() > 0.1 else Vector2.UP}
	var best_d := INF
	var best_q := Vector2.ZERO
	for j in shell_poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, shell_poly[j], shell_poly[(j + 1) % shell_poly.size()])
		var d := q.distance_to(p)
		if d < best_d:
			best_d = d
			best_q = q
	if best_d < r:
		return {"kind": "core", "n": (p - best_q).normalized()}
	return {}


## 강철 판을 그린다 (안쪽 근육·코어 빛은 콜로서스가 먼저 그린다). lit = 공격 중이라 표적이 드러남, beat = 맥동 0~1
func draw_plates(ci: CanvasItem, t: float, lit: bool, beat: float) -> void:
	var f := frac()
	var steel := C_STEEL.lerp(Color.WHITE, flash * 0.5)
	if lit:
		steel = steel.lerp(Color(1.0, 0.85, 0.5), 0.15)
	for pl in plates:
		if pl["gone"]:
			continue
		var lv := plate_level(pl, f)
		var cen: Vector2 = pl["cen"]
		var off: Vector2 = pl["off"]
		var rot: float = pl["rot"]
		var col := steel
		var shift := Vector2.ZERO
		var ang := 0.0
		if lv >= 1:
			col = steel.lerp(C_STEEL_DARK, 0.35)
			shift = off * 2.0
			ang = rot * 0.015
		if lv >= 2:
			col = steel.lerp(C_STEEL_DARK, 0.6)
			shift = off * 7.0 + Vector2(0, 2.0 * sin(t * 9.0 + cen.x))   # 헐거워져 덜컹거린다
			ang = rot * 0.12 + 0.02 * sin(t * 7.0 + cen.y)
		ci.draw_set_transform(cen + shift, ang)
		var poly: PackedVector2Array = pl["poly"]
		ci.draw_colored_polygon(poly, col)
		ci.draw_polyline(pl["outline"], Color(1.0, 0.85, 0.5) if lit else (C_PLATE_EDGE if lv < 2 else Color(1.0, 0.45, 0.15, 0.5 + 0.4 * beat)), 3.0 if lv < 2 else 4.0)
		if lv == 0:
			ci.draw_circle(pl["rivet"], 4.0, C_STEEL_DARK)
			ci.draw_circle(pl["rivet"] + Vector2(-1, -1), 1.6, Color(0.72, 0.76, 0.82))
		if lv >= 1:                                # 찌그러짐: 눌린 자국과 주름
			for c in pl["crumple"]:
				ci.draw_polyline(c, Color(C_STEEL_DARK, 0.9), 3.0)
				ci.draw_polyline(c + PackedVector2Array([Vector2(1, 1), Vector2(1, 1), Vector2(1, 1)]), Color(0.7, 0.74, 0.8, 0.45), 1.5)
		if lv >= 2:                                # 균열 틈으로 코어 빛이 샌다 + 불꽃
			for c in pl["cracks"]:
				ci.draw_polyline(c, Color(1.0, 0.5, 0.2, 0.7 + 0.3 * beat), 3.0)
			if int(t * 6.0 + cen.x * 0.01) % 5 == 0:
				ci.draw_circle(Vector2(sin(t * 20.0 + cen.y) * 14.0, cos(t * 17.0) * 14.0), 2.5, Color(1.0, 0.9, 0.5))
		ci.draw_set_transform(Vector2.ZERO, 0.0)


## 외곽선과 불규칙한 강철 판(보로노이 조각 + 들쭉날쭉한 변), 패임·균열선을 한 번만 만든다
func _build(outline: Array, site_box: Rect2, sites_n: int, seed_v: int) -> void:
	var pts := PackedVector2Array()
	for q in outline:
		pts.append(center + q)
	for it in 2:                                  # 모서리를 둥글려 유기적인 윤곽으로
		var sm := PackedVector2Array()
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			sm.append(a.lerp(b, 0.25))
			sm.append(a.lerp(b, 0.75))
		pts = sm
	shell_poly = pts
	shell_inner.clear()
	for q in shell_poly:
		shell_inner.append(center + (q - center) * 0.86)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sites: Array[Vector2] = []
	var tries := 0
	while sites.size() < sites_n and tries < 4000:
		tries += 1
		var q := center + Vector2(rng.randf_range(site_box.position.x, site_box.end.x), rng.randf_range(site_box.position.y, site_box.end.y))
		if not Geometry2D.is_point_in_polygon(q, shell_poly):
			continue
		var ok := true
		for o in sites:
			if o.distance_to(q) < 105.0:
				ok = false
				break
		if ok:
			sites.append(q)
	plates.clear()
	for i in sites.size():
		var cell := shell_poly
		for j in sites.size():
			if i != j:
				cell = _clip_half(cell, (sites[i] + sites[j]) * 0.5, (sites[j] - sites[i]).normalized())
		if cell.size() < 3:
			continue
		cell = _jag(cell, rng)
		var cen := Vector2.ZERO
		for q in cell:
			cen += q
		cen /= cell.size()
		var local := PackedVector2Array()
		for q in cell:
			local.append(q - cen)
		var crumple: Array[PackedVector2Array] = []
		var cracks: Array[PackedVector2Array] = []
		var bb := Rect2(local[0], Vector2.ZERO)
		for q in local:
			bb = bb.expand(q)
		for k in 3:
			var a := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if Geometry2D.is_point_in_polygon(a, local):
				var d := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(10.0, 24.0)
				crumple.append(PackedVector2Array([a - d, a, a + d.rotated(rng.randf_range(-0.9, 0.9))]))
		var cr := Vector2.ZERO
		var cd := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var line := PackedVector2Array([cr])
		for k in 4:
			cd = cd.rotated(rng.randf_range(-0.7, 0.7))
			cr += cd * rng.randf_range(12.0, 26.0)
			if not Geometry2D.is_point_in_polygon(cr, local):
				break
			line.append(cr)
		if line.size() >= 2:
			cracks.append(line)
		var closed := local.duplicate()
		closed.append(local[0])
		plates.append({"poly": local, "outline": closed, "cen": cen, "th": rng.randf_range(0.12, 0.96), "off": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)),
			"rot": rng.randf_range(-1.0, 1.0), "crumple": crumple, "cracks": cracks, "gone": false, "rivet": local[0].lerp(Vector2.ZERO, 0.55)})


## 볼록하지 않은 다각형을 반평면(점 m 에서 n 쪽의 반대편 = 가까운 쪽)으로 자른다
static func _clip_half(poly: PackedVector2Array, m: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		var da := (a - m).dot(n)
		var db := (b - m).dot(n)
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## 변을 쪼개 살짝 들쭉날쭉하게 (깨진 철판 느낌)
static func _jag(poly: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		out.append(a)
		var l := a.distance_to(b)
		if l > 46.0:
			var nrm := (b - a).orthogonal().normalized()
			out.append(a.lerp(b, rng.randf_range(0.35, 0.65)) + nrm * rng.randf_range(-7.0, 7.0))
	return out

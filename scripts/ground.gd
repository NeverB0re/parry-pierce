extends Node2D
## 용암 바닥 + 양쪽 벽 + 시작 발판(뒤), 또는 앞쪽 용암 표면과 불씨(front = true). 월드 좌표.
## 용암 표면 y=0. 빠지면 목숨 하나를 잃는다.

const Quality := preload("res://scripts/quality.gd")

const C_LAVA_DEEP := Color(0.35, 0.05, 0.02)
const C_LAVA := Color(1.0, 0.38, 0.1)
const C_LAVA_HOT := Color(1.0, 0.8, 0.35)

var front := false
var orbit := false                # 궤도 무대 (결계 위성): 용암 대신 대기권 경계, 벽은 에너지 기둥, 천장은 결계
const C_ATMO := Color(0.35, 0.65, 1.0)
const C_ATMO_HOT := Color(0.85, 0.95, 1.0)
var t := 0.0
var embers: Array[Vector3] = []   # x, 위상, 속도

# 시작 발판 상태 (main.gd 가 매 프레임 설정)
var plat_center := Vector2(650, -40)
var plat_half := 90.0
var plat_sink := 0.0              # 0 = 떠 있음, 1 = 완전히 가라앉음
var plat_crack := 0.0             # 0~1 금 간 정도
var _last_sink := -1.0
var _last_crack := -1.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in (16 if Quality.low else 40):
		embers.append(Vector3(rng.randf_range(-1150, 1150), rng.randf() * 10.0, rng.randf_range(40, 110)))
	if front:
		z_index = 5


func _process(delta: float) -> void:
	t += delta
	if front:
		queue_redraw()                   # 출렁이는 표면은 매 프레임
	elif plat_sink != _last_sink or plat_crack != _last_crack:
		_last_sink = plat_sink           # 뒤쪽(벽·발판)은 발판 상태가 바뀔 때만 다시 그린다
		_last_crack = plat_crack
		queue_redraw()


func set_orbit(v: bool) -> void:
	if orbit != v:
		orbit = v
		queue_redraw()


func _surface_y(x: float) -> float:
	return sin(x * 0.012 + t * 1.6) * 6.0 + sin(x * 0.031 - t * 2.3) * 3.0


func _draw() -> void:
	if front:
		if orbit:
			_draw_atmo_front()
		else:
			_draw_front()
		return
	if orbit:
		_draw_orbit_back()
		_draw_platform()
		return
	# 용암 위 열기 (위로 갈수록 투명)
	var glow := PackedVector2Array([Vector2(-1400, -380), Vector2(1700, -380), Vector2(1700, 0), Vector2(-1400, 0)])
	var gc := PackedColorArray([Color(C_LAVA, 0.0), Color(C_LAVA, 0.0), Color(C_LAVA, 0.22), Color(C_LAVA, 0.22)])
	draw_polygon(glow, gc)
	# 양쪽 벽(폐허 기둥) — 아래쪽은 용암 빛을 받아 붉다
	for side in [-1.0, 1.0]:
		var edge: float = -1150.0 if side < 0 else 1150.0
		var r := Rect2(edge - 500, -4000, 500, 4000) if side < 0 else Rect2(edge, -4000, 500, 4000)
		draw_rect(r, Color(0.035, 0.04, 0.05))
		draw_line(Vector2(edge, -4000), Vector2(edge, 0), Color(0.2, 0.22, 0.26), 3.0)
		draw_line(Vector2(edge, -300), Vector2(edge, 0), Color(C_LAVA, 0.35), 3.0)
		var y := -200.0
		while y > -4000.0:
			draw_line(Vector2(edge, y), Vector2(edge - side * 40.0, y), Color(0.12, 0.13, 0.16), 4.0)
			y -= 260.0
	_draw_ceiling()
	_draw_platform()


## 천장: 이 높이를 넘어 올라갈 수 없다 (아랫면 y = -3080)
func _draw_ceiling() -> void:
	var y := -3080.0
	draw_rect(Rect2(-1650, y - 600, 3300, 600), Color(0.035, 0.04, 0.05))
	draw_line(Vector2(-1150, y), Vector2(1150, y), Color(0.32, 0.35, 0.42), 4.0)
	draw_rect(Rect2(-1150, y - 14, 2300, 10), Color(0.1, 0.11, 0.14))
	var x := -1100.0
	var i := 0
	while x < 1150.0:                  # 아래로 늘어진 돌 이빨 + 이음새
		var h := 26.0 + float(i % 3) * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 24, y), Vector2(x + 24, y), Vector2(x, y + h)]), Color(0.1, 0.11, 0.14))
		draw_line(Vector2(x + 110, y - 4), Vector2(x + 110, y - 90), Color(0.12, 0.13, 0.16), 4.0)
		x += 220.0
		i += 1


## 시작 발판: 발사 후 금이 가며 용암 속으로 가라앉는다 (재출격 때 다시 솟아오름)
func _draw_platform() -> void:
	if plat_sink >= 1.0:
		return
	var top := plat_center.y + plat_sink * 120.0
	var rc := Rect2(plat_center.x - plat_half, top, plat_half * 2.0, 70.0)
	var col := Color(0.16, 0.15, 0.17).lerp(Color(0.5, 0.15, 0.05), plat_sink)
	var slab := PackedVector2Array([rc.position, Vector2(rc.end.x, rc.position.y), Vector2(rc.end.x - 20, rc.end.y), Vector2(rc.position.x + 20, rc.end.y)])
	draw_colored_polygon(slab, col)
	draw_line(rc.position, Vector2(rc.end.x, rc.position.y), Color(0.45, 0.47, 0.52), 3.0)
	if plat_crack > 0.0:
		var cx := plat_center.x
		draw_polyline(PackedVector2Array([Vector2(cx - 40, top), Vector2(cx - 15, top + 25), Vector2(cx - 30, top + 50)]), Color(C_LAVA_HOT, plat_crack), 3.0)
		draw_polyline(PackedVector2Array([Vector2(cx + 30, top), Vector2(cx + 10, top + 30), Vector2(cx + 35, top + 60)]), Color(C_LAVA_HOT, plat_crack), 3.0)


## 궤도 무대 뒤쪽: 대기권 열기(푸른 빛) + 양쪽 에너지 기둥(경기장 끝) + 결계 천장
func _draw_orbit_back() -> void:
	draw_polygon(PackedVector2Array([Vector2(-1400, -420), Vector2(1700, -420), Vector2(1700, 0), Vector2(-1400, 0)]),
		PackedColorArray([Color(C_ATMO, 0.0), Color(C_ATMO, 0.0), Color(C_ATMO, 0.2), Color(C_ATMO, 0.2)]))
	for side in [-1.0, 1.0]:
		var edge: float = -1150.0 if side < 0 else 1150.0
		draw_rect(Rect2(edge - 500, -4000, 500, 4000) if side < 0 else Rect2(edge, -4000, 500, 4000), Color(0.02, 0.025, 0.05, 0.85))
		draw_line(Vector2(edge, -4000), Vector2(edge, 0), Color(C_ATMO, 0.45), 3.0)
		var y := -150.0
		while y > -4000.0:
			draw_line(Vector2(edge, y), Vector2(edge - side * 26.0, y - 40.0), Color(C_ATMO, 0.25), 2.0)
			y -= 300.0
	var cy := -3080.0                                  # 결계 천장 (위성이 친 보라 막)
	draw_rect(Rect2(-1650, cy - 600, 3300, 600), Color(0.03, 0.02, 0.05, 0.9))
	draw_line(Vector2(-1150, cy), Vector2(1150, cy), Color(0.8, 0.35, 0.65, 0.7), 4.0)
	var x := -1100.0
	while x < 1150.0:
		draw_line(Vector2(x, cy), Vector2(x + 60, cy - 50), Color(0.6, 0.15, 0.4, 0.5), 2.0)
		x += 120.0


## 궤도 무대 앞쪽: 대기권 경계 (닿으면 용암과 같다) — 빛나는 대기 띠 + 타오르는 불꽃
func _draw_atmo_front() -> void:
	var surf := PackedVector2Array()
	var x := -1400.0
	var step := 80.0 if Quality.low else 40.0
	while x <= 1700.0:
		surf.append(Vector2(x, _surface_y(x) * 0.6))
		x += step
	var body := surf.duplicate()
	body.append(Vector2(1700, 900))
	body.append(Vector2(-1400, 900))
	draw_colored_polygon(body, Color(0.04, 0.08, 0.18))
	var band := surf.duplicate()
	for i in range(surf.size() - 1, -1, -1):
		band.append(surf[i] + Vector2(0, 40))
	draw_colored_polygon(band, Color(C_ATMO, 0.7))
	draw_polyline(surf, C_ATMO_HOT, 4.0)
	for e in embers:                                     # 대기 마찰 불꽃 (위로 튄다)
		var life := fmod(t * 0.5 + e.y, 1.0)
		var p := Vector2(e.x + sin(t + e.y * 3.0) * 14.0, -life * e.z * 4.0)
		draw_circle(p, 2.5 * (1.0 - life) + 0.5, Color(1.0, 0.75, 0.45, 0.7 * (1.0 - life)))


## 앞쪽: 출렁이는 용암 표면 (발판·발 아래쪽을 덮는다) + 떠오르는 불씨
func _draw_front() -> void:
	var surf := PackedVector2Array()
	var x := -1400.0
	var step := 80.0 if Quality.low else 40.0
	while x <= 1700.0:
		surf.append(Vector2(x, _surface_y(x)))
		x += step
	var body := surf.duplicate()
	body.append(Vector2(1700, 900))
	body.append(Vector2(-1400, 900))
	draw_colored_polygon(body, C_LAVA_DEEP)
	# 표면 근처 밝은 띠
	var band := surf.duplicate()
	for i in range(surf.size() - 1, -1, -1):
		band.append(surf[i] + Vector2(0, 36))
	draw_colored_polygon(band, Color(C_LAVA, 0.85))
	draw_polyline(surf, C_LAVA_HOT, 4.0)
	# 표면의 굳은 껍질 조각
	for i in 14:
		var px := -1200.0 + i * 190.0 + sin(t * 0.3 + i) * 40.0
		var py := _surface_y(px) + 14.0
		draw_line(Vector2(px - 30, py), Vector2(px + 30, py + 3), Color(0.25, 0.06, 0.03, 0.8), 6.0)
	# 불씨
	for e in embers:
		var life := fmod(t * 0.35 + e.y, 1.0)
		var p := Vector2(e.x + sin(t + e.y * 3.0) * 20.0, -life * e.z * 6.0)
		draw_circle(p, 2.5 * (1.0 - life) + 0.5, Color(C_LAVA_HOT, 0.8 * (1.0 - life)))

extends Node2D
## 용암 바닥 + 양쪽 벽 + 시작 발판(뒤), 또는 앞쪽 용암 표면과 불씨(front = true). 월드 좌표.
## 용암 표면 y=0. 빠지면 목숨 하나를 잃는다.

const C_LAVA_DEEP := Color(0.35, 0.05, 0.02)
const C_LAVA := Color(1.0, 0.38, 0.1)
const C_LAVA_HOT := Color(1.0, 0.8, 0.35)

var front := false
var t := 0.0
var embers: Array[Vector3] = []   # x, 위상, 속도

# 시작 발판 상태 (main.gd 가 매 프레임 설정)
var plat_center := Vector2(650, -40)
var plat_half := 90.0
var plat_sink := 0.0              # 0 = 떠 있음, 1 = 완전히 가라앉음
var plat_crack := 0.0             # 0~1 금 간 정도


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		embers.append(Vector3(rng.randf_range(-1150, 1150), rng.randf() * 10.0, rng.randf_range(40, 110)))
	if front:
		z_index = 5


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _surface_y(x: float) -> float:
	return sin(x * 0.012 + t * 1.6) * 6.0 + sin(x * 0.031 - t * 2.3) * 3.0


func _draw() -> void:
	if front:
		_draw_front()
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
	_draw_platform()


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


## 앞쪽: 출렁이는 용암 표면 (발판·발 아래쪽을 덮는다) + 떠오르는 불씨
func _draw_front() -> void:
	var surf := PackedVector2Array()
	var x := -1400.0
	while x <= 1700.0:
		surf.append(Vector2(x, _surface_y(x)))
		x += 40.0
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

extends CanvasLayer
## FTL 도약 연출 = 스테이지 전환. 별빛이 중앙에서 뻗어 나가며 빨라지고 → 흰 섬광(이 순간 다음 스테이지를 준비) → 섬광이 걷히며 도착.
## 연출 동안 게임은 멈춰 있다.
const UiFont := preload("res://scripts/ui_font.gd")

const Loc := preload("res://scripts/loc.gd")
signal arrived                       # 섬광이 다 걷혀 조작을 돌려줄 때

const T_ACCEL := 1.1                 # 별빛 가속
const T_FLASH := 0.25                # 흰 섬광 (가득 찬 순간 스테이지 교체)
const T_FADE := 0.7                  # 섬광이 걷힌다
const STARS := 140

var t := -1.0                        # < 0 = 꺼짐
var title := ""
var on_swap: Callable                # 섬광이 가득 찼을 때 한 번 (다음 스테이지 준비)
var swapped := false
var canvas: Control
var font: Font
var stars: Array[Vector3] = []       # (각도, 시작 거리 비율, 속도 배율)


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = UiFont.make()
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_paint)
	add_child(canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in STARS:
		stars.append(Vector3(rng.randf() * TAU, rng.randf_range(0.02, 1.0), rng.randf_range(0.6, 1.4)))


func play(destination: String, swap: Callable) -> void:
	title = destination
	on_swap = swap
	swapped = false
	t = 0.0
	visible = true
	get_tree().paused = true


func is_playing() -> bool:
	return t >= 0.0


## 테스트용: 연출을 건너뛰고 바로 도착
func skip() -> void:
	if t < 0.0:
		return
	_swap()
	_finish()


func _process(dt: float) -> void:
	if t < 0.0:
		return
	t += dt
	if t >= T_ACCEL + T_FLASH * 0.5:
		_swap()
	if t >= T_ACCEL + T_FLASH + T_FADE:
		_finish()
		return
	canvas.queue_redraw()


func _swap() -> void:
	if swapped:
		return
	swapped = true
	if on_swap.is_valid():
		on_swap.call()


func _finish() -> void:
	t = -1.0
	visible = false
	get_tree().paused = false
	arrived.emit()


func _paint() -> void:
	var s := canvas.size
	var c := s * 0.5
	var far := s.length() * 0.6
	var after := t - T_ACCEL - T_FLASH                    # 도착 후 (섬광이 걷히는 중)
	if after < 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.015, 0.03, minf(1.0, t * 4.0)))
		var k := clampf(t / T_ACCEL, 0.0, 1.0)
		var speed := k * k                              # 점점 빨라진다
		for st in stars:
			var d := Vector2.from_angle(st.x)
			var r0 := fmod(st.y + t * (0.25 + 1.6 * speed) * st.z, 1.0)
			var len := 0.02 + 0.5 * speed * st.z
			var p0 := c + d * far * r0 * r0
			var p1 := c + d * far * minf(1.2, (r0 + len) * (r0 + len))
			var a := clampf(r0 * 2.0, 0.0, 1.0)
			canvas.draw_line(p0, p1, Color(0.75 + 0.25 * speed, 0.9, 1.0, a), 1.0 + 2.0 * speed * r0)
		canvas.draw_circle(c, 6.0 + 60.0 * speed, Color(0.8, 0.95, 1.0, 0.25 + 0.5 * speed))
		canvas.draw_string(font, Vector2(0, s.y * 0.78), Loc.t("FTL 도약"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(0.85, 0.95, 1.0, 0.9))
		canvas.draw_string(font, Vector2(0, s.y * 0.78 + 34), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 18, Color(0.7, 0.8, 0.9, 0.8))
	var flash := 0.0
	if t >= T_ACCEL and after < 0.0:
		flash = clampf((t - T_ACCEL) / (T_FLASH * 0.5), 0.0, 1.0)
	elif after >= 0.0:
		flash = 1.0 - clampf(after / T_FADE, 0.0, 1.0)
	if flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.92, 0.97, 1.0, flash))

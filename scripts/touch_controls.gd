extends Control
## 모바일 터치 조작: 왼쪽 플로팅 스틱(방향), 오른쪽 패리(꾹)/회피·차지 버튼, 우상단 일시정지.
## 모바일에서만(또는 --touch 로 시험할 때) main.gd 가 만든다. 마우스 조작은 그대로 유지된다.

const BTN_PARRY_R := 94.0
const BTN_DASH_R := 106.0            # 회피/차지를 더 자주 쓰므로 가장 크고 엄지가 닿기 쉬운 자리
const STICK_R := 120.0               # 스틱 최대 반경
const STICK_ZONE := 0.5              # 화면 왼쪽 이 비율 안에서 시작한 터치만 스틱
const MARGIN := 60.0                 # 노치/가장자리 여유
const LIFT := 96.0                   # 바닥에서 띄우는 높이 (손바닥에 가려지지 않도록)

var main: Node
var stick := Vector2.ZERO            # -1..1 (방향 입력)
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var fingers := {}                    # index -> "stick" | "parry" | "dash" | "pause"
var parry_down := false
var dash_down := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


## 회피/차지: 오른쪽 아래, 엄지가 가장 편한 자리
func dash_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - MARGIN - BTN_DASH_R - 24.0, s.y - LIFT - BTN_DASH_R)


## 패리: 회피 버튼의 왼쪽 위 (엄지를 살짝 올려 누른다)
func parry_center() -> Vector2:
	var d := dash_center()
	return d + Vector2(-(BTN_DASH_R + BTN_PARRY_R) * 0.92 - 10.0, -(BTN_PARRY_R) * 0.9)


func pause_center() -> Vector2:
	return Vector2(get_viewport_rect().size.x - MARGIN - 20.0, MARGIN + 20.0)


func _input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		if fingers.get(e.index, "") == "stick":
			_drag(e.position)


func _down(idx: int, pos: Vector2) -> void:
	var s := get_viewport_rect().size
	if pos.distance_to(pause_center()) < 52.0:
		fingers[idx] = "pause"
		main.touch_pause()
	elif pos.distance_to(parry_center()) < BTN_PARRY_R * 1.1:
		fingers[idx] = "parry"
		parry_down = true
		main.touch_parry(true)
	elif pos.distance_to(dash_center()) < BTN_DASH_R * 1.1:
		fingers[idx] = "dash"
		dash_down = true
		main.touch_dash(true)
	elif pos.x < s.x * STICK_ZONE and not fingers.values().has("stick"):
		fingers[idx] = "stick"
		stick_origin = pos
		stick_pos = pos
		stick = Vector2.ZERO


func _up(idx: int) -> void:
	var role: String = fingers.get(idx, "")
	fingers.erase(idx)
	match role:
		"stick":
			stick = Vector2.ZERO
		"parry":
			parry_down = false
			main.touch_parry(false)
		"dash":
			dash_down = false
			main.touch_dash(false)


func _drag(pos: Vector2) -> void:
	var d := pos - stick_origin
	if d.length() > STICK_R:                 # 손가락이 멀어지면 스틱 중심이 따라온다 (플로팅)
		stick_origin = pos - d.normalized() * STICK_R
		d = pos - stick_origin
	stick_pos = pos
	stick = d / STICK_R


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if get_tree().paused:
		return
	var pl = main.player
	# 스틱
	if fingers.values().has("stick"):
		draw_circle(stick_origin, STICK_R, Color(1, 1, 1, 0.07))
		draw_arc(stick_origin, STICK_R, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 3.0)
		draw_circle(stick_origin + stick * STICK_R, 44.0, Color(0.7, 0.92, 1.0, 0.45))
	else:
		var s := get_viewport_rect().size
		var hint := Vector2(MARGIN + STICK_R + 40.0, s.y - LIFT - STICK_R * 0.8)
		draw_arc(hint, STICK_R * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 3.0)
		draw_circle(hint, 30.0, Color(1, 1, 1, 0.08))
	# 패리: 금색
	var pc := parry_center()
	var pa := 0.5 if parry_down else 0.28
	draw_circle(pc, BTN_PARRY_R, Color(1.0, 0.85, 0.35, pa * 0.5))
	draw_arc(pc, BTN_PARRY_R, 0.0, TAU, 40, Color(1.0, 0.88, 0.4, pa + 0.25), 4.0)
	draw_arc(pc, BTN_PARRY_R * 0.5, PI * 1.15, PI * 1.85, 16, Color(1.0, 0.92, 0.55, pa + 0.4), 6.0)
	# 회피/차지: 청백(쿨다운 중엔 링이 차오른다)
	var dc := dash_center()
	var da := 0.5 if dash_down else 0.28
	draw_circle(dc, BTN_DASH_R, Color(0.5, 0.85, 1.0, da * 0.5))
	draw_arc(dc, BTN_DASH_R, 0.0, TAU, 40, Color(0.7, 0.92, 1.0, da + 0.25), 4.0)
	var ar := Vector2(BTN_DASH_R * 0.42, 0.0)
	draw_line(dc - ar, dc + ar, Color(0.85, 0.97, 1.0, da + 0.4), 6.0)
	draw_line(dc + ar, dc + ar + Vector2(-16, -14), Color(0.85, 0.97, 1.0, da + 0.4), 6.0)
	draw_line(dc + ar, dc + ar + Vector2(-16, 14), Color(0.85, 0.97, 1.0, da + 0.4), 6.0)
	if pl.charge_cd > 0.0:
		draw_arc(dc, BTN_DASH_R + 9.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - pl.charge_cd / pl.CHARGE_COOLDOWN), 40, Color(1.0, 0.55, 0.2, 0.9), 5.0)
	# 일시정지
	var qc := pause_center()
	draw_circle(qc, 26.0, Color(1, 1, 1, 0.1))
	draw_rect(Rect2(qc + Vector2(-9, -11), Vector2(6, 22)), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(qc + Vector2(3, -11), Vector2(6, 22)), Color(1, 1, 1, 0.55))

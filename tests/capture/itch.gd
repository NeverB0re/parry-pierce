extends SceneTree
# itch.io 페이지용 이미지 캡처 (창 모드, 자동 종료): 스크린샷 5장(1280x720) + 표지(1260x1000, 630x500 의 2배).
# 인자: -- --notutorial --out=<dir>.  영어 화면. 진행·언어 저장은 끈다.
# 장면은 실제 게임 로직으로 연출한다: 탄막이 가득한 곳을 돌진으로 지나가거나, 금색 탄을 패리하고 리버스 드라이브로 꽂는 순간.
const Loc := preload("res://scripts/loc.gd")
var main
var n := 0
var out := ""
var idx := 0
var f := 0                           # 장면 안의 프레임
var pin := true                      # 플레이어를 제자리에 고정 (돌진·조준을 시작하면 푼다)
var pin_pos := Vector2.ZERO
var target := Vector2.ZERO           # 조준·리버스 드라이브 표적 (월드 좌표)
var cover_layer: CanvasLayer = null
# [파일 이름, 장면, 찍을 프레임, 카메라 위치, 줌]
var plan := [
	["01_title", "title", 30, Vector2.ZERO, 1.0],
	["02_dash_through_barrage", "dash_fort", 120, Vector2(0, -1950), 0.5],
	["03_parry_slowmo", "parry_fort", 118, Vector2(0, -1950), 0.5],
	["04_dash_ink_barrage", "dash_kraken", 116, Vector2(0, -1900), 0.5],
	["05_dash_through_net", "dash_net", 202, Vector2(0, -1900), 0.5],
	["cover", "reverse_drive", 94, Vector2(150, -1780), 0.75],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup(name: String) -> void:
	var p = main.player
	pin = true
	main.title.close()
	main.hud.visible = true
	main.debug.god = true                              # 맞아서 장면이 흐트러지지 않게
	match name:
		"title":
			main.start_stage(0)
			main.title.open()
		"dash_fort", "parry_fort":
			main.start_stage(1)
			var b = main.boss
			b.next_t = 999.0
			pin_pos = Vector2(250, -1500)
			p.reset(pin_pos, false)
			b.start_attack(b.Spiral.new(-1, b.SPIRE_TOP, pin_pos, true))
			b.start_side(b.Fan.new(0, b.BARREL_TIPS[0], pin_pos, true))
			target = b.part_pos(0)
		"dash_kraken", "reverse_drive":
			main.start_stage(2)
			var b = main.boss
			b.next_t = 999.0
			pin_pos = Vector2(-250, -1500) if name == "dash_kraken" else Vector2(-120, -1450)
			p.reset(pin_pos, false)
			b.start_attack(b.Fan.new(-1, b.SIPHON, pin_pos, true))
			target = b.CORE_POS
		"dash_net":
			main.start_stage(2)
			var b = main.boss
			b.next_t = 999.0
			pin_pos = Vector2(100, -1500)
			p.reset(pin_pos, false)
			b.start_attack(b.Net.new(true))


func _tick(name: String) -> void:
	var p = main.player
	var b = main.boss
	if pin:
		p.position = pin_pos
		p.vel = Vector2.ZERO
	match name:
		"dash_fort":
			if f == 100:
				_field(pin_pos + Vector2(-380, -60), 520.0, 300.0, 90)
			if f == 112:                                    # 탄막 속으로 돌진 (무적)
				pin = false
				p.aim = Vector2(-1.0, -0.2).normalized()
				p._dash("dash")
		"dash_kraken":
			if f == 96:
				_field(pin_pos + Vector2(380, 40), 520.0, 300.0, 90)
			if f == 108:
				pin = false
				p.aim = Vector2(1.0, 0.1).normalized()
				p._dash("dash")
		"parry_fort", "reverse_drive":
			var parry_f := 96 if name == "parry_fort" else 70
			if name == "reverse_drive" and f == 60:
				_field(pin_pos + Vector2(60, -150), 480.0, 360.0, 70)
			if f == parry_f:                                 # 금색 탄 하나를 패리
				b.shots.spawn(p.position + Vector2(28, 0), Vector2.ZERO, 5.0, 1.0)
				p.parry_press()
			if f > parry_f and p.aim_phase:
				var sp: Vector2 = main.get_viewport().get_canvas_transform() * target
				Input.warp_mouse(sp)
			if name == "reverse_drive" and f == parry_f + 8 and p.aim_phase:
				pin = false
				p.aim = (target - p.position).normalized()
				p.launch_parry_dash()                         # 리버스 드라이브
		"dash_net":
			if f == 197:                                    # 다가오는 보라 띠를 돌진 무적으로 통과
				pin = false
				p.aim = Vector2(1.0, -0.05).normalized()
				p._dash("dash")


## 멈춘 듯 떠 있는 탄 무더기 (잔탄 위주, 주탄 조금). 탄막 한가운데를 지나가는 장면용
func _field(c: Vector2, rx: float, ry: float, count: int) -> void:
	var b = main.boss
	var K = b.shots.Kind
	seed(7)
	for i in count:
		var pos := c + Vector2(randf_range(-rx, rx), randf_range(-ry, ry))
		if pos.distance_to(pin_pos) < 110.0:
			continue
		var k = K.SMALL if randf() < 0.78 else K.BOLT
		b.shots.spawn(pos, Vector2.from_angle(randf() * TAU) * 24.0, 6.0, 1.0, 0.0, k)


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.tele.enabled = false
		var pr = main.Profile.new()
		pr.persist = false
		main.profile = pr
		main.world.profile = pr
		main.title.profile = pr
		Loc.persist = false
		Loc.lang = "en"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if n < 4:
		return false
	if idx >= plan.size():
		quit()
		return false
	var pl: Array = plan[idx]
	var name: String = pl[1]
	if f == 0:
		if pl[0] == "cover":
			DisplayServer.window_set_size(Vector2i(1260, 1000))
		_setup(name)
	f += 1
	_tick(name)
	if name != "title":
		main.cam.position = pl[3]
		main.cam.zoom = Vector2(pl[4], pl[4])
		main.hud.clear_banner()
	if pl[0] == "cover":                                    # 표지: HUD 를 숨기고 제목을 얹는다
		main.hud.visible = false
		if cover_layer == null:
			cover_layer = CanvasLayer.new()
			cover_layer.layer = 90
			root.add_child(cover_layer)
			var font := SystemFont.new()
			font.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "sans-serif"])
			var t1 := _label("PARRY PIERCE", 104, font, 12, Color(1.0, 0.93, 0.8))
			t1.offset_top = -250.0
			t1.offset_bottom = -110.0
			cover_layer.add_child(t1)
			var t2 := _label("Parry the barrage. Pierce the colossus.", 32, font, 8, Color(0.9, 0.95, 1.0))
			t2.offset_top = -110.0
			t2.offset_bottom = -50.0
			cover_layer.add_child(t2)
	if f == int(pl[2]):
		print(pl[0], " bolts=", main.boss.shots.size(), " aim_phase=", main.player.aim_phase, " dash=", main.player.dash_kind, " pos=", main.player.position)
		root.get_texture().get_image().save_png("%s/%s.png" % [out, pl[0]])
		idx += 1
		f = 0
		pin = true
	return false


func _label(text: String, size: int, font: Font, outline: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

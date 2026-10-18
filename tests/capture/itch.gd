extends SceneTree
# itch.io 페이지용 이미지 캡처 (창 모드, 자동 종료): 스크린샷 7장(1280x720) + 표지(1260x1000, 630x500 의 2배).
# 인자: -- --notutorial --out=<dir>.  영어 화면. 진행·언어 저장은 끈다.
# 장면은 실제 보스 공격을 그대로 쏘게 두고 연출한다: 날아온 탄이 가까이 오면 그때 돌진하거나 패리하고 리버스 드라이브로 꽂는다.
# (탄을 임의로 만들어 깔지 않는다 — 실제 게임과 다른 모양이 되므로)
const Loc := preload("res://scripts/loc.gd")
var main
var n := 0
var out := ""
var idx := 0
var f := 0                           # 장면 안의 프레임
var pin := true                      # 플레이어를 제자리에 고정 (돌진·조준을 시작하면 푼다)
var pin_pos := Vector2.ZERO
var target := Vector2.ZERO           # 조준·리버스 드라이브 표적 (월드 좌표)
var ev := -1                         # 돌진·패리를 시작한 프레임 (-1 = 아직, 탄이 다가오길 기다린다)
const TRIGGERED := ["dash_fort", "parry_fort", "dash_kraken", "reverse_drive"]   # 찍을 프레임 = 시작 뒤 몇 프레임
const MAX_WAIT := 900
var cover_layer: CanvasLayer = null
# [파일 이름, 장면, 찍을 프레임(TRIGGERED 장면은 돌진·패리 뒤 프레임), 카메라 위치, 줌]
var plan := [
	["01_title", "title", 30, Vector2.ZERO, 1.0],
	["02_dash_through_barrage", "dash_fort", 8, Vector2(0, -1950), 0.5],
	["03_parry_slowmo", "parry_fort", 22, Vector2(0, -1950), 0.5],
	["04_dash_ink_barrage", "dash_kraken", 8, Vector2(0, -1550), 0.5],
	["05_dash_through_beam", "dash_beam", 160, Vector2(0, -1900), 0.5],
	["06_barrier_storm", "sat_burst", 120, Vector2(0, -1500), 0.42],
	["07_barrier_open", "sat_open", 150, Vector2(0, -1550), 0.45],
	["cover", "reverse_drive", 16, Vector2(0, -1500), 0.62],
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
			pin_pos = Vector2(-300, -1000) if name == "dash_kraken" else Vector2(-220, -1080)
			p.reset(pin_pos, false)
			var none: Array[int] = []
			b._start("ink", none, pin_pos, true)              # 실제 게임처럼 먹물 부채 + 저격 유도탄
			target = b.CORE_POS
		"sat_burst", "sat_open":
			main.start_stage(3)
			var b = main.boss
			b.next_t = 999.0
			pin_pos = Vector2(300, -900) if name == "sat_burst" else Vector2(320, -1150)
			p.reset(pin_pos, false)
			if name == "sat_burst":
				b.start_attack(b.RadialBurst.new(b.CORE_POS, b.BURST_BEAMS))
			else:
				b._open()
		"dash_beam":
			main.start_stage(2)
			var b = main.boss
			b.next_t = 999.0
			pin_pos = Vector2(100, -1500)
			p.reset(pin_pos, false)
			b.start_attack(b.EyeSweep.new(b.CORE_POS))


func _tick(name: String) -> void:
	var p = main.player
	if pin:
		p.position = pin_pos
		p.vel = Vector2.ZERO
	match name:
		"dash_fort", "dash_kraken":
			if ev < 0 and _incoming(220.0, false) >= (6 if name == "dash_fort" else 14):          # 실제 탄막이 몰려오면 그 속으로 돌진 (무적)
				ev = f
				pin = false
				p.aim = Vector2(-1.0, -0.2).normalized() if name == "dash_fort" else Vector2(1.0, 0.1).normalized()
				p._dash("dash")
		"parry_fort", "reverse_drive":
			if ev < 0:                                        # 가까운 실제 금색 탄 쪽으로 다가가 맞이한다 (탄은 건드리지 않는다)
				var g := _nearest_gold(320.0)
				if g != Vector2.INF:
					pin_pos = pin_pos.move_toward(g, 7.0)
			if ev < 0 and _incoming(p.RADIUS + p.stats.parry_reach, true) > 0:   # 날아온 금색 탄을 패리
				ev = f
				p.parry_press()
			if ev >= 0 and p.aim_phase:
				var sp: Vector2 = main.get_viewport().get_canvas_transform() * target
				Input.warp_mouse(sp)
			if name == "reverse_drive" and ev >= 0 and f == ev + 8 and p.aim_phase:
				pin = false
				p.aim = (target - p.position).normalized()
				p.launch_parry_dash()                         # 리버스 드라이브
		"dash_beam":
			if f == 197:                                    # 다가오는 보라 띠를 돌진 무적으로 통과
				pin = false
				p.aim = Vector2(1.0, -0.05).normalized()
				p._dash("dash")


## 플레이어 r 안의 가장 가까운 적 금색 탄 위치 (없으면 INF)
func _nearest_gold(r: float) -> Vector2:
	var sh = main.boss.shots
	var best := Vector2.INF
	for i in sh.size():
		if sh.mine[i] == 0 and sh.kind[i] == sh.Kind.BOLT and sh.pos[i].distance_to(pin_pos) < minf(r, best.distance_to(pin_pos) if best != Vector2.INF else r):
			best = sh.pos[i]
	return best


## 플레이어 r 안에 들어온 적 탄 수 (gold_only = 주탄만)
func _incoming(r: float, gold_only: bool) -> int:
	var sh = main.boss.shots
	var c := 0
	for i in sh.size():
		if sh.mine[i] == 1:
			continue
		if gold_only and sh.kind[i] != sh.Kind.BOLT:
			continue
		if sh.pos[i].distance_to(main.player.position) < r:
			c += 1
	return c


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
		ev = -1
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
	var shoot: bool = f == int(pl[2]) if not TRIGGERED.has(name) else (ev >= 0 and f == ev + int(pl[2]))
	if not shoot and f >= MAX_WAIT:
		push_error("%s: trigger never fired" % pl[0])
		shoot = true
	if shoot:
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

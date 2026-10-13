extends SceneTree
# 탄막 요새 캡처 (창 모드, 자동 종료): 전체 모습 → 공격 4종 → 코어 페이즈. 인자: -- --notutorial --out=<dir>
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [시작 프레임, 이름, 공격, 찍을 프레임 오프셋, 카메라 위치, 줌]
var plan := [
	["spiral", "spiral", 150, Vector2(-300, -2000), 0.5],
	["bullets", "bullets", 20, Vector2(250, -1200), 1.0],
	["press_warn", "press", 80, Vector2(0, -1500), 0.23],
	["press_hold", "press", 170, Vector2(0, -1500), 0.23],
	["rings", "rings", 150, Vector2(0, -1640), 0.3],
	["overload", "overload", 130, Vector2(0, -1640), 0.4],
	["shield", "shield", 20, Vector2(250, -1200), 1.6],
	["tail", "tail", 20, Vector2(250, -1200), 1.4],
	["spiral_warn", "spiral", 40, Vector2(0, -2000), 0.4],
]
var idx := 0
var local := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.tele.enabled = false
		var pr = main.Profile.new()
		pr.persist = false
		main.profile = pr
		main.world.profile = pr
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if n < 4:
		return false
	if idx >= plan.size():
		quit()
		return false
	var pl: Array = plan[idx]
	var b = main.boss
	var p = main.player
	if local == 0:
		main.start_stage(1)
		b = main.boss
		b.next_t = 999.0
		p.reset(Vector2(250, -1200) if pl[1] != "mines" else Vector2(250, -400), false)
		match pl[1]:
			"spiral": b.start_attack(b.Spiral.new(0, b.BARREL_TIPS[0]))
			"fan": b.start_attack(b.Fan.new(1, b.BARREL_TIPS[1], p.position))
			"homing": b.start_attack(b.Homing.new())
			"mines": b.start_attack(b.Mines.new(p.position))
			"press": b.start_attack(b.Press.new())
			"rings": b.start_attack(b.Rings.new(b.REACTOR_POS))
			"overload":
				for i in 4:
					b.damage_part(i, 99)
				b.phase = 3
				b.atk = null
				b.next_t = 999.0
				b.start_attack(b.Overload.new(b.REACTOR_POS))
			"tail":                                    # 금빛 꼬리(완전 동조) + 유도탄·주탄·잔탄 비교
				p.buffed = true
				p.buff_strong = true
				p.buff_t = 9.0
				var K3 = b.shots.Kind
				b.shots.spawn(Vector2(420, -1280), Vector2(-1, 0) * 0.01, 99.0, 1.0, 0.0, K3.HOMING)
				b.shots.spawn(Vector2(420, -1160), Vector2(-1, 0) * 0.01, 99.0, 1.0)
				b.shots.spawn(Vector2(420, -1060), Vector2(-1, 0) * 0.01, 99.0, 1.0, 0.0, K3.SMALL)
			"shield":                                  # 무적 실드 + 잔탄 확대
				var K2 = b.shots.Kind
				for k in 3:
					b.shots.spawn(Vector2(140 + k * 50, -1260), Vector2(-1, 0.3) * 0.01, 99.0, 1.0, 0.0, K2.SMALL)
				b.shots.spawn(Vector2(370, -1180), Vector2(-1, 0.3) * 0.01, 99.0, 1.0)
			"bullets":                                 # 주탄·잔탄·유도탄 비교 (멈춰 있는 탄)
				var K = b.shots.Kind
				for k in 6:
					b.shots.spawn(Vector2(-150 + k * 60, -1320), Vector2(-1, 0.3) * 0.01, 99.0, 1.0, 0.0, K.SMALL)
				for k in 3:
					b.shots.spawn(Vector2(-120 + k * 110, -1100), Vector2(-1, 0.3) * 0.01, 99.0, 1.0)
				b.shots.spawn(Vector2(480, -1220), Vector2(-1, 0) * 0.01, 99.0, 1.0, 0.0, K.HOMING)
			"core":
				for i in 4:
					b.damage_part(i, 99)
				b.phase = 3
				b.damage_core(90)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = Vector2(250, -400) if pl[1] == "mines" or pl[1] == "press" else Vector2(250, -1200)
	main.cam.position = pl[3]
	main.cam.zoom = Vector2(pl[4], pl[4])
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/fortress_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

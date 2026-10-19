extends SceneTree
# itch.io 페이지용 스크린샷 캡처 (창 모드, 자동 종료, 1280x720). 표지(itch/cover.png)는 따로 그린 그림을 쓴다 (v0.105).
# 인자: -- --notutorial --out=<dir>.  영어 화면. 진행·언어 저장은 끈다.
# v0.101: 보스 네 마리의 리메이크된 모습(실제 공격 그대로) + 도트 글꼴로 바뀐 항로도·동력 코어 장착 화면.
const Loc := preload("res://scripts/loc.gd")
var main
var n := 0
var out := ""
var idx := 0
var f := 0                           # 장면 안의 프레임
var ppos := Vector2.ZERO             # 플레이어를 고정할 자리
var warn_seen := -1
# [파일 이름, 장면, 찍을 프레임, 플레이어 자리, 카메라 위치, 줌]
var plan := [
	["01_title", "title", 30, Vector2.ZERO, Vector2.ZERO, 1.0],
	["02_observer_greatsword", "obs_sword", 130, Vector2(380, -1450), Vector2(0, -1800), 0.29],
	["03_observer_shield_rings", "obs_rings", 100, Vector2(380, -1300), Vector2(0, -1800), 0.29],
	["04_fortress_heavy_shell", "fort_gun", 150, Vector2(320, -1250), Vector2(0, -2000), 0.31],
	["05_kraken_ink_barrage", "kraken_ink", 80, Vector2(250, -1200), Vector2(0, -1650), 0.3],
	["06_satellite_barrier_open", "sat_open", 90, Vector2(300, -1100), Vector2(0, -1500), 0.42],
	["07_route_map", "map", 40, Vector2.ZERO, Vector2.ZERO, 1.0],
	["08_power_cores", "cores", 40, Vector2.ZERO, Vector2.ZERO, 1.0],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup(scene: String, pl: Array) -> void:
	var p = main.player
	main.title.close()
	main.world.close()
	main.hud.visible = true
	main.debug.god = true                              # 맞아서 장면이 흐트러지지 않게
	ppos = pl[3]
	match scene:
		"title":
			main.start_stage(0)
			main.title.open()
			return
		"obs_sword", "obs_rings":
			main.start_stage(0)
			var b = main.boss
			b.awake = true                             # 깨어난 모습 (깨어나는 연출 없이)
			b.wake_k = 1.0
			b.next_t = 999.0
			if scene == "obs_sword":
				var sw = b.Greatsword.new()
				b.start_attack(sw)
				sw.aim_at(ppos)
			else:
				b.start_attack(b.Rings.new(b.shield_center()))
		"fort_gun":
			main.start_stage(1)
			var b = main.boss
			b.next_t = 999.0
			b._pick("big_gun", b.BigGun.new())
		"kraken_ink":
			main.start_stage(2)
			var b = main.boss
			b.next_t = 999.0
			var none: Array[int] = []
			b._start("ink", none, ppos, false)
		"sat_open":
			main.start_stage(3)
			var b = main.boss
			b.next_t = 999.0
			b._open()
		"map", "cores":
			var pr = main.profile
			pr.reset()
			pr.record_clear(0, 72.4)
			pr.record_clear(1, 65.9)
			pr.record_clear(2, 68.1)
			pr.select_stage(3)
			main.open_world()
			if scene == "cores":
				main.world.open_cores()
			return
	p.reset(ppos, false)


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
	var scene: String = pl[1]
	if f == 0:
		_setup(scene, pl)
	f += 1
	if scene != "title" and scene != "map" and scene != "cores":
		main.player.position = ppos
		main.player.vel = Vector2.ZERO
		main.player.invuln = 999.0
		main.cam.position = pl[4]
		main.cam.zoom = Vector2(pl[5], pl[5])
		main.hud.clear_banner()
	var shoot := f == int(pl[2])
	if scene == "obs_sword":                                # 대검은 물리 틱으로 진행하므로 프레임 대신 경고 자세를 기다린다
		var a = main.boss.atk
		if a != null and a.phase == "warn" and a.t > 0.45 and warn_seen < 0:
			warn_seen = f
		shoot = (warn_seen >= 0 and f == warn_seen) or f >= 400
	if shoot:
		print(pl[0], " bolts=", main.boss.shots.size())
		root.get_texture().get_image().save_png("%s/%s.png" % [out, pl[0]])
		idx += 1
		f = 0
		warn_seen = -1
	return false


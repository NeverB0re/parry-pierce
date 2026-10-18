extends SceneTree
# 크라켄 캡처 (창 모드, 자동 종료): 전체 모습 → 촉수 공격 예고·판정 → 방전 그물 → 코어 페이즈. 인자: -- --notutorial --out=<dir>
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 공격, 찍을 프레임, 플레이어 위치, 카메라 위치, 줌]
var plan := [
	["idle", "", 30, Vector2(250, -1200), Vector2(0, -1600), 0.24],
	["hammer_warn", "hammer", 80, Vector2(300, -1300), Vector2(0, -1500), 0.25],
	["hammer_hit", "hammer", 116, Vector2(300, -1300), Vector2(0, -1500), 0.25],
	["chase_follow", "chase", 70, Vector2(300, -1300), Vector2(0, -1500), 0.25],
	["chase_warn", "chase", 125, Vector2(300, -800), Vector2(0, -1100), 0.42],
	["recoil", "recoil", 20, Vector2(300, -1300), Vector2(0, -1500), 0.25],
	["detach", "detach", 12, Vector2(300, -1300), Vector2(0, -1500), 0.25],
	["sweep_warn", "sweep", 80, Vector2(700, -700), Vector2(0, -1100), 0.42],
	["sweep_hit", "sweep", 140, Vector2(700, -1300), Vector2(0, -1500), 0.25],
	["constrict_warn", "constrict", 80, Vector2(0, -1300), Vector2(0, -1500), 0.3],
	["constrict_sq", "constrict", 150, Vector2(0, -1300), Vector2(0, -1500), 0.3],
	["beam_wind", "beam", 50, Vector2(250, -1200), Vector2(0, -1600), 0.24],
	["beam_sweep", "beam", 200, Vector2(250, -1200), Vector2(0, -1600), 0.24],
	["ink", "ink", 75, Vector2(250, -1200), Vector2(0, -1700), 0.3],
	["broken", "broken", 60, Vector2(250, -1200), Vector2(0, -1600), 0.24],
	["core", "core", 60, Vector2(250, -1800), Vector2(0, -2100), 0.3],
	["regrow", "regrow", 50, Vector2(250, -1300), Vector2(0, -1900), 0.3],
	["zap", "zap", 24, Vector2(250, -1300), Vector2(0, -1900), 0.3],
	["shatter", "shatter", 14, Vector2(250, -1300), Vector2(0, -2100), 0.3],
	["k_sweep", "k_sweep", 75, Vector2(300, -700), Vector2(0, -1100), 0.42],
	["k_constrict", "k_constrict", 75, Vector2(0, -900), Vector2(0, -1100), 0.42],
	["k_snipe", "k_snipe", 70, Vector2(300, -800), Vector2(0, -1300), 0.42],
	["k_tips", "k_tips", 110, Vector2(300, -800), Vector2(0, -1300), 0.42],
	["k_eye", "k_eye", 80, Vector2(300, -800), Vector2(0, -1500), 0.42],
	["new_idle", "", 30, Vector2(250, -700), Vector2(0, -1500), 0.42],
	["tips", "tips", 70, Vector2(250, -700), Vector2(0, -1100), 0.5],
	["tips_fire", "tips", 130, Vector2(250, -700), Vector2(0, -1300), 0.42],
	["ring", "ring", 120, Vector2(250, -700), Vector2(0, -1100), 0.5],
	["close", "idle", 30, Vector2(300, -1500), Vector2(-150, -1700), 0.6],
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
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	while only != "" and idx < plan.size() and not (plan[idx][0] as String).begins_with(only):
		idx += 1
	if idx >= plan.size():
		quit()
		return false
	var pl: Array = plan[idx]
	var b = main.boss
	var p = main.player
	if local == 0:
		main.start_stage(2)
		b = main.boss
		b.next_t = 999.0
		p.reset(pl[3], false)
		var a = null
		if (pl[1] as String).begins_with("k_"):
			var rr: Array[int] = [0, 1, 2, 3, 4, 5]
			b._start((pl[1] as String).substr(2), rr, pl[3], false)
		match pl[1]:
			"hammer": a = b.Hammer.new(1)
			"chase": a = b.Chase.new(3)
			"recoil", "detach":
				a = b.Hammer.new(1)
				b.start_attack(a)
				a.claim()
				for k in 115:
					b.step(1.0 / 60.0, pl[3])
				var hb = b.clash_box(pl[3])
				hb["dir"] = Vector2(0.3, -1).normalized()
				b.hit_dir = hb["dir"]
				b.hit_dir_t = b.t
				b.on_parried(hb)
				if pl[1] == "detach":
					b.damage_part(1, 99)
				a = null
			"sweep": a = b.Lash.new(7)
			"zap":
				b.damage_part(1, 8)
				b.damage_part(4, 16)
			"shatter":
				for i in 6:
					b.damage_part(i, 99)
			"constrict": a = b.Constrict.new(0, 1)
			"beam": a = b.EyeSweep.new(b.CORE_POS)
			"ink": a = b.Fan.new(-1, b.SIPHON, p.position)
			"tips", "ring": a = b.Barrage.new(pl[1], b.emitters(), p.position)
			"broken":
				b.damage_part(0, 16)
				b.damage_part(3, 16)
				b.damage_part(4, 8)
			"core", "vortex", "regrow":
				for i in 6:
					b.damage_part(i, 99)
				b.phase = 3
				b.atk = null
				b.next_t = 999.0
				if pl[1] == "core":
					b.damage_core(60)
				elif pl[1] == "vortex":
					b.grown[2] = 1.0
					b.grown[3] = 1.0
					var rr: Array[int] = [2, 3]
					a = b._pound(rr, pl[3])
		if a != null:
			b.start_attack(a)
			if a.has_method("claim"):
				a.claim()
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = pl[3]
	main.cam.position = pl[4]
	main.cam.zoom = Vector2(pl[5], pl[5])
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/kraken_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

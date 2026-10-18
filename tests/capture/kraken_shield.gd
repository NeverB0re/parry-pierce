extends SceneTree
# 크라켄 방어막·몸통 캡처 (창 모드, 자동 종료): 온전한 방어막을 뚫는 일격 → 판이 떨어진 방어막 → 동력선·상처 입은 촉수 → 눈알 → 연속 내려치기 → 눈알 쓸기.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["pierce_full", "full", 6],
	["pierce_worn", "worn", 6],
	["panels", "panels", 50],
	["wide", "wide", 50],
	["eye_close", "eye", 30],
	["pound_raise", "pound", 70],
	["beam_wind", "beam", 50],
	["beam_sweep", "beam", 260],
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
		main.start_stage(2)
		b = main.boss
		b.next_t = 999.0
		p.reset(Vector2(300, -1000), false)
		var sh := {"kind": "shield", "n": Vector2(0.4, 1.0).normalized()}
		match pl[1]:
			"full":
				b.damage(sh, 16)
			"worn":
				for j in 4:
					b.panel_gone[j] = true
				b.damage(sh, 16)
			"panels":
				b.damage_part(0, 16)
				b.damage_part(3, 16)
				b.damage_part(4, 8)
			"pound":
				var rd: Array[int] = [0, 1, 2, 3, 4, 5]
				b.start_attack(b._pound(rd, Vector2(300, -1000)))
			"beam":
				b.start_attack(b.EyeSweep.new(b.CORE_POS))
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = Vector2(300, -1000)
	b.next_t = 999.0
	main.cam.position = b.CORE_POS if pl[1] == "eye" else Vector2(0, -1600 if pl[1] == "wide" else (-1300 if pl[1] == "beam" else -1500))
	var z := 1.0 if pl[1] == "eye" else (0.24 if pl[1] == "wide" else (0.3 if pl[1] == "beam" else 0.42))
	main.cam.zoom = Vector2(z, z)
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/kraken_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

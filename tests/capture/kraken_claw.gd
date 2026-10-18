extends SceneTree
# 크라켄 집게·방어막 캡처 (창 모드, 자동 종료): 온전한 방어막을 뚫는 일격 → 닳은 방어막을 깊이 뚫는 일격 + 떨어지는 집게 → 날아가는 집게.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["pierce_full", "full", 6],
	["pierce_worn", "worn", 6],
	["claw_fall", "fall", 50],
	["claw_fly", "fly", 8],
	["eye_close", "eye", 30],
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
				b.shield_hp = b.SHIELD_HP * 0.15
				b.damage(sh, 16)
			"fall", "fly":
				b.shield_hp = b.SHIELD_HP * 0.6
				b.damage_part(3, 16)
				if pl[1] == "fly":
					for k in 40:
						b.step(1.0 / 60.0, p.position)
					b.launch_claw(0)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = Vector2(300, -1000)
	b.next_t = 999.0
	main.cam.position = b.CORE_POS if pl[1] == "eye" else Vector2(0, -1500)
	var z := 1.0 if pl[1] == "eye" else 0.42
	main.cam.zoom = Vector2(z, z)
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/kraken_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

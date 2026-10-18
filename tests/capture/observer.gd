extends SceneTree
# 관측자 캡처 (창 모드, 자동 종료): 대기 → 검 휘두르기 예고·휘두름 → 방패 휘두르기 예고 → 부위 파괴 → 코어.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["idle", "idle", 30],
	["sword_warn", "sword", 75],
	["sword_swing", "sword", 125],
	["shield_warn", "shield", 75],
	["broken", "broken", 40],
	["core", "core", 150],
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
	var ppos := Vector2(-300, -1500) if pl[1] == "shield" else Vector2(350, -1500)
	if local == 0:
		main.start_stage(0)
		b = main.boss
		b.next_t = 999.0
		p.reset(ppos, false)
		match pl[1]:
			"sword":
				var sw = b.Swing.new(1, 3, b.fists[1])
				b.start_attack(sw)
				sw.aim_at(ppos)
			"shield":
				var sw = b.Swing.new(0, 2, b.fists[0])
				b.start_attack(sw)
				sw.aim_at(ppos)
			"broken":
				b.damage_part(0, 999)
				b.damage_part(2, 999)
				b.damage_part(3, 999)
			"core":
				for i in b.part_count():
					b.damage_part(i, 999)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = ppos
	if pl[1] != "sword" and pl[1] != "shield":
		b.next_t = 999.0
	main.cam.position = Vector2(0, -1650)
	main.cam.zoom = Vector2(0.3, 0.3)
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/observer_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

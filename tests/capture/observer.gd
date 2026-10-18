extends SceneTree
# 관측자 캡처 (창 모드, 자동 종료): 대기 → 대검 긋기 예고·긋기 → 쳐낸 대검이 튕겨 올라 돌다 떨어져 심장에 꽂힘 → 헤일로 사격 → 방패 동심원 → 어깨포 파괴·장갑 손상.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["idle", "idle", 30],
	["sword_warn", "sword", 95],
	["sword_swing", "sword", 135],
	["fling_up", "fling", 22],
	["fling_fall", "fling", 62],
	["sword_stuck", "fling", 85],
	["halo", "halo", 75],
	["rings", "rings", 95],
	["damaged", "broken", 40],
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
	var ppos := Vector2(350, -1500)
	if local == 0:
		main.start_stage(0)
		b = main.boss
		b.next_t = 999.0
		p.reset(ppos, false)
		match pl[1]:
			"sword":
				var sw = b.Greatsword.new()
				b.start_attack(sw)
				sw.aim_at(ppos)
			"fling":
				var sw = b.Greatsword.new()
				b.start_attack(sw)
				sw.aim_at(ppos)
				for k in 100:
					b.step(1.0 / 60.0, ppos)
				sw.on_parried({"id": "arm", "dmg": 8})
			"halo":
				var hs = b.HaloShot.new()
				b.start_attack(hs)
				hs.pick(ppos)
			"rings":
				b.start_attack(b.Rings.new(b.shield_center()))
			"broken":
				b.damage_part(0, 999)
				b.damage_core(100)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = ppos
	if pl[1] == "idle" or pl[1] == "broken":
		b.next_t = 999.0
	main.cam.position = Vector2(0, -1650)
	main.cam.zoom = Vector2(0.3, 0.3)
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/observer_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

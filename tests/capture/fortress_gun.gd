extends SceneTree
# 탄막 요새 대구경 포대 캡처 (창 모드, 자동 종료): 닫힘 → 열림·조준 → 발사(호위탄) → 드러난 포 강조 → 맞고 휘청 → 부서짐.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["closed", "closed", 20],
	["aim", "gun", 80],
	["fired", "gun", 125],
	["exposed", "gun", 175],
	["stagger", "hit", 12],
	["broken", "broken", 40],
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
		p.reset(Vector2(350, -1300), false)
		match pl[1]:
			"gun":
				b.start_side(b.BigGun.new())
			"hit":
				var g = b.BigGun.new()
				b.start_side(g)
				for k in 110:
					b.step(1.0 / 60.0, p.position)
				b.damage_part(b.BIG, 8)
			"broken":
				b.part_hp[b.BIG] = 1
				b.gun_exposed = true
				b.damage_part(b.BIG, 8)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = Vector2(350, -1300)
	b.next_t = 999.0
	main.cam.position = Vector2(0, -1900)
	main.cam.zoom = Vector2(0.36, 0.36)
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/fortress_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

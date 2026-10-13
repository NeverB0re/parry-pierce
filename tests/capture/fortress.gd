extends SceneTree
# 탄막 요새 캡처 (창 모드, 자동 종료): 전체 모습 → 공격 4종 → 코어 페이즈. 인자: -- --notutorial --out=<dir>
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [시작 프레임, 이름, 공격, 찍을 프레임 오프셋, 카메라 위치, 줌]
var plan := [
	["overview", "", 10, Vector2(0, -1500), 0.23],
	["spiral", "spiral", 110, Vector2(0, -1800), 0.32],
	["fan", "fan", 85, Vector2(0, -1800), 0.32],
	["homing", "homing", 110, Vector2(0, -1500), 0.32],
	["mines", "mines", 120, Vector2(200, -500), 0.5],
	["reactor", "core", 40, Vector2(0, -1640), 0.6],
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
		main.hangar.profile = pr
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
			"core":
				for i in 4:
					b.damage_part(i, 99)
				b.phase = 3
				b.damage_core(90)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	main.cam.position = pl[3]
	main.cam.zoom = Vector2(pl[4], pl[4])
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/fortress_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

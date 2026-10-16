extends SceneTree
# 결계 위성 캡처 (창 모드, 자동 종료): 닫힌 결계 → 궤도 광선 예고·쓸기 → 결계면 → 노드 분사 → 열림 탄막. 인자: -- --notutorial --out=<dir> [--only=이름]
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 공격, 찍을 프레임, 플레이어 위치, 카메라 위치, 줌]
var plan := [
	["idle", "", 30, Vector2(300, -900), Vector2(0, -1500), 0.42],
	["orbit_wind", "orbit", 40, Vector2(300, -900), Vector2(0, -1400), 0.42],
	["orbit_sweep", "orbit", 110, Vector2(300, -900), Vector2(0, -1400), 0.42],
	["wall", "wall", 140, Vector2(300, -900), Vector2(0, -1500), 0.42],
	["spray", "spray", 100, Vector2(300, -900), Vector2(0, -1400), 0.42],
	["open", "open", 90, Vector2(300, -1100), Vector2(0, -1500), 0.42],
	["close", "idle", 30, Vector2(300, -1300), Vector2(0, -1800), 0.6],
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
		main.start_stage(3)
		b = main.boss
		b.next_t = 999.0
		p.reset(pl[3], false)
		match pl[1]:
			"orbit": b.start_attack(b.OrbitBeam.new(b, pl[3]))
			"wall": b.start_attack(b.BarrierWall.new(pl[3]))
			"spray": b.start_attack(b.NodeSpray.new())
			"open": b._open()
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = pl[3]
	main.cam.position = pl[4]
	main.cam.zoom = Vector2(pl[5], pl[5])
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/satellite_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

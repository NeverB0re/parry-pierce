extends SceneTree
# 모함 캡처 (창 모드, 자동 종료): 포위망 → 편대 패턴 아홉(편대마다 셋) → 대형 포탄 → 주포 → 부서진 드론이 모함으로 → 최후의 발악.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["ring", "idle", 150],
	["gun_fan", "gun:fan", 70],
	["gun_stream", "gun:stream", 90],
	["gun_missiles", "gun:missiles", 110],
	["rush_line", "rush:line", 55],
	["rush_chain", "rush:chain", 75],
	["rush_lance", "rush:lance", 55],
	["veil_net_form", "veil:net", 55],
	["veil_net", "veil:net", 160],
	["veil_cross", "veil:cross", 75],
	["veil_pulse", "veil:pulse", 110],
	["shell", "shell", 100],
	["cannon_aim", "cannon", 80],
	["cannon_fire", "cannon", 150],
	["fling", "fling", 50],
	["final", "final", 280],
]
var idx := 0
var local := 0
const PPOS := Vector2(150, -1450)


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
		main.title.close()
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
		main.start_stage(4)
		b = main.boss
		main.debug.god = true
		b.next_t = 999.0
		p.reset(PPOS, false)
		for k in 120:                                  # 드론이 격납고에서 나와 고리를 잡을 시간
			b.step(1.0 / 60.0, PPOS)
		var sc: String = pl[1]
		if sc.contains(":"):
			var kd: String = sc.get_slice(":", 0)
			var md: String = sc.get_slice(":", 1)
			match kd:
				"gun":
					b.start_attack(b.SquadGun.new(0, md))
				"rush":
					b.start_attack(b.SquadRush.new(1, md))
				"veil":
					b.start_attack(b.SquadVeil.new(2, md))
		match sc:
			"shell":
				b.start_attack(b.CarrierShell.new())
			"cannon":
				b.start_attack(b.CarrierCannon.new())
			"fling":
				b.damage_part(4, 999)
				b.damage_part(0, 999)
			"final":
				for i in b.part_count():
					b.damage_part(i, 999)
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = PPOS
	if pl[1] == "idle" or pl[1] == "fling":
		b.next_t = 999.0
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/carrier_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false

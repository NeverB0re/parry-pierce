extends SceneTree
# 모함 캡처 (창 모드, 자동 종료): 포위 고리 → 탄막 편대 → 돌격 편대 예고 → 결계 편대 → 함포 포격 → 탐조 광선 → 부서진 드론이 모함으로 → 최후의 발악.
# 인자: -- --notutorial --out=<dir>. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임]
var plan := [
	["ring", "idle", 150],
	["gun", "gun", 140],
	["rush_warn", "rush", 70],
	["veil", "veil", 150],
	["shells", "shells", 55],
	["search", "search", 110],
	["fling", "fling", 30],
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
		match pl[1]:
			"gun":
				b.start_attack(b.SquadGun.new(0))
			"rush":
				b.start_attack(b.SquadRush.new(1))
			"veil":
				b.start_attack(b.SquadVeil.new(2))
			"shells":
				b.start_attack(b.CarrierShells.new())
			"search":
				b.start_attack(b.RadialBurst.new(b._search_origin(), b.SEARCH_BEAMS))
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

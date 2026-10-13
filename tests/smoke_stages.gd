extends SceneTree
# 그리기 스모크: 부위 손상 단계 → 가슴 개방 → 코어 단계 0~4 → 파괴까지 프레임을 돌리며 오류가 없는지
var main
var n := 0
var draws := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	n += 1
	if n == 1:
		for a in OS.get_cmdline_user_args():      # -- --stage=1 : 다른 콜로서스로
			if a.begins_with("--stage="):
				main.start_stage(a.trim_prefix("--stage=").to_int())
	if n == 1:
		main.boss.draw.connect(func(): draws += 1)
	var b = main.boss
	var p = main.player
	p.invuln = 99.0
	if n > 3:
		main.player.on_platform = false
		p.position = Vector2(300, -1200 - (n % 400))
		p.vel = Vector2.ZERO
	if n == 5:
		b.next_t = 0.5
	if n % 40 == 0 and n < 400:          # 부위를 조금씩 깎아 단계 그림을 거친다
		for i in 4:
			b.damage_part(i, 3)
	if n == 300:
		p.buffed = true
		p.charging = true
		p.charge_t = 0.5
	if n == 320:
		p.charging = false
		p.dash_cd = 0.5
	if n % 60 == 0 and b.phase == 3 and not b.dead:
		if b.damage_core(31):
			main._core_destroyed(b.core.center)
	main._physics_process(1.0 / 60.0)
	if n >= 1100:
		print("stages ok frames=", n, " phase=", b.phase, " core_stage=", b.core.stage, " dead=", b.dead, " shards=", b.shards.size(), " boss_draws=", draws)
		quit()
	return false

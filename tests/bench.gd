extends SceneTree
# 헤드리스 CPU 비용 측정: 시나리오별 평균 프레임 시간(스크립트 시뮬 + _draw 명령 생성).
# 렌더러가 없으므로 GPU 비용은 포함되지 않는다.
var main
var n := 0
var scen := 0
var acc := 0
var cnt := 0
var last := 0
var t_phys := 0
var t_draw0 := 0
var draw_acc := 0
var draw_cnt := 0
var probe: Node2D
var pdraw_acc := 0
var pdraw_cnt := 0
var tp0 := 0
var pprobe: Node2D
var names := ["A 페이즈1 대기", "B 페이즈1 + 탄 80발", "C 코어 3단계 + 파편", "D C에서 보스 숨김", "E 탄 80발 + 보스 숨김"]


func _initialize() -> void:
	Engine.max_fps = 0
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup(i: int) -> void:
	var b = main.boss
	var p = main.player
	main.reset_run()
	p.reset(Vector2(300, -1600), false)
	p.invuln = 9999.0
	b.next_t = 9999.0
	b.visible = true
	main.cam.position = p.position
	if i == 1 or i == 4:
		for k in 80:
			b.shots.spawn(Vector2(randf_range(-900, 900), randf_range(-2600, -800)), Vector2.from_angle(randf() * TAU) * 1.0, 999.0, 1.0)
	if i == 2 or i == 3:
		for k in 4:
			b.damage_part(k, 99)
		b.phase = 3
		b.damage_core(100)
		main.cam.position = b.HEART_POS
	if i == 3 or i == 4:
		b.visible = false


func _process(_d: float) -> bool:
	n += 1
	var now := Time.get_ticks_usec()
	if n == 3:
		_setup(0)
		main.boss.draw.connect(func(): t_draw0 = Time.get_ticks_usec())
		probe = Node2D.new()
		main.boss.add_child(probe)
		probe.draw.connect(func():
			draw_acc += Time.get_ticks_usec() - t_draw0
			draw_cnt += 1)
		main.player.draw.connect(func(): tp0 = Time.get_ticks_usec())
		pprobe = Node2D.new()
		main.player.add_child(pprobe)
		pprobe.draw.connect(func():
			pdraw_acc += Time.get_ticks_usec() - tp0
			pdraw_cnt += 1)
	elif n > 3:
		var local := n - 3
		if local % 400 == 0:
			print("%s: 물리 %.0f µs, 보스 _draw %.0f µs, 플레이어 _draw %.0f µs" % [names[scen], float(t_phys) / cnt, float(draw_acc) / maxi(1, draw_cnt), float(pdraw_acc) / maxi(1, pdraw_cnt)])
			draw_acc = 0
			draw_cnt = 0
			pdraw_acc = 0
			pdraw_cnt = 0
			scen += 1
			acc = 0
			cnt = 0
			t_phys = 0
			if scen >= names.size():
				quit()
				return false
			_setup(scen)
		elif local % 400 > 60:                 # 안정화 후 측정
			acc += now - last
			cnt += 1
			var t0 := Time.get_ticks_usec()
			main.player.invuln = 9999.0
			main._physics_process(1.0 / 60.0)
			if probe:
				probe.queue_redraw()
				pprobe.queue_redraw()
			t_phys += Time.get_ticks_usec() - t0
	last = Time.get_ticks_usec()
	return false

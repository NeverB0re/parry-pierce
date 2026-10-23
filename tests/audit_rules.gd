extends SceneTree
# 규칙 점검 (헤드리스, 약 2분): 보스마다 150초, 부위를 차례로 부수며 겹침(보라+근접·보라 둘, 참고로 탄막+근접)·동시 패턴 수·멍때림을 잰다. docs/RULES.md 10장
var main
var n := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	n += 1
	if n != 3:
		return false
	var DT := 1.0 / 60.0
	for st in 6:
		main.start_stage(st)
		var b = main.boss
		main.debug.god = true
		main.player.on_platform = false
		seed(3 + st)
		var stat := {"melee+shots": 0.0, "melee+purple": 0.0, "purple2": 0.0, "over2": 0.0, "idle_max": 0.0, "idle_total": 0.0, "melee_t": 0.0, "purple_t": 0.0}
		var idle := 0.0
		var kinds := {}
		var why := {}
		if b.has_method("wake"):
			b.wake()
		for k in int(150.0 / DT):
			var tt := k * DT
			b.hold_attacks = false
			var pp := Vector2(150 + 500.0 * sin(tt * 0.7), -1450 + 300.0 * cos(tt * 0.5))
			if k % int(14.0 / DT) == int(10.0 / DT) and b.phase == 1:
				for i in b.part_count():
					if b.part_alive(i):
						b.damage_part(i, 999)
						break
			b.step(DT, pp)
			if b.dead:
				break
			var acts: Array = b.active_attacks()
			for a in acts:
				kinds[a.kind] = true
			var melee: bool = b.melee_warning() or not b.clash_box(pp).is_empty()
			var purple := 0
			for a in acts:
				if not a.dodged and a.unparry_point(pp).is_finite():
					purple += 1
			var incoming: bool = not b.shots_clear(pp)
			if melee:
				stat["melee_t"] += DT
				if incoming:
					stat["melee+shots"] += DT
					why["melee+shots " + _ks(acts)] = true
				if purple > 0:
					stat["melee+purple"] += DT
					why["melee+purple " + _ks(acts)] = true
			if purple > 0: stat["purple_t"] += DT
			if purple > 1:
				stat["purple2"] += DT
				why["purple2 " + _ks(acts)] = true
			if _patterns(acts) > 2:
				stat["over2"] += DT
				why["over2 " + _ks(acts)] = true
			if acts.is_empty() and b.phase != 2 and b.shots_near(pp, 1500.0) == 0:
				idle += DT
				stat["idle_total"] += DT
				stat["idle_max"] = maxf(stat["idle_max"], idle)
			else:
				if idle > 1.5:
					print("   gap %.1fs ending t=%.1f next=%s parts_left=%d" % [idle, tt, _ks(acts), b.parts_left()])
				idle = 0.0
		var out := "AUDIT stage %d %s phase=%d" % [st, b.get_script().resource_path.get_file(), b.phase]
		for key in stat:
			out += " %s=%.1f" % [key, stat[key]]
		print(out)
		print("   kinds: ", kinds.keys())
		for w in why:
			print("   ", w)
	quit()
	return false


func _ks(acts: Array) -> String:
	var a := []
	for x in acts:
		a.append(x.kind)
	a.sort()
	return str(a)


## 동시에 도는 "패턴" 수: 한 패턴을 이루는 모듈은 하나로 센다
## (탄막에 딸린 저격·유도탄, 연타 묶음의 촉수 타 = 묶음 하나, 같은 종류 여럿 = 하나)
func _patterns(acts: Array) -> int:
	var ks := {}
	for x in acts:
		var k: String = x.kind
		if k == "hammer":
			k = "pound"
		ks[k] = true
	if ks.size() > 1:
		ks.erase("snipe")
		ks.erase("homing")
	return ks.size()

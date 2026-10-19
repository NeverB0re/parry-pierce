extends CanvasLayer
## 월드 맵 (스테이지 사이, ESC 메뉴에서도): 은하 9개(스테이지)와 목적지(10번째)를 굽은 점선 항로로 잇고, 기체가 고른 은하 위에 떠 있다.
## 깬 은하는 다시 골라 재전투할 수 있고 최단 클리어 기록이 붙는다. 안 깬 곳(다음 하나만 고를 수 있음)·아직 만들지 않은 곳은 회색.
## 아래 줄: 고른 도약지 안내 + [뒤로] [동력 코어] [FTL 도약 ▶]. 동력 코어는 따로 장착 화면(CoresView: 기체 설계도의 장착 칸 + 코어 아이콘)에서 고른다.
const UiFont := preload("res://scripts/ui_font.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const CoreIcon := preload("res://scripts/core_icon.gd")

const Loc := preload("res://scripts/loc.gd")
signal jump_requested
signal back_requested               # 타이틀에서 열었을 때만 (allow_back)

const Upgrades := preload("res://scripts/upgrades.gd")
const Stages := preload("res://scripts/stages.gd")
const Sprites := preload("res://scripts/sprites.gd")
const C_TAKEN := Color(1.0, 0.85, 0.45)
const C_LOCKED := Color(0.5, 0.52, 0.58)
const C_INFO := Color(0.88, 0.91, 0.96)

var profile                          # main.gd 가 연결 (profile.gd)
var ui_scale := 1.0
var font: Font
var map: MapView
var info_l: Label                    # 고른 도약지
var hint_l: Label
var jump_button: Button
var back_button: Button
var cores_button: Button
var title_l: Label
var allow_back := false
var cores_view: Control              # 동력 코어 장착 화면 (항로도 위에 덮는다)
var cores_title: Label
var cores_back: Button
var blueprint: BlueprintView
var core_tiles := {}                 # 코어 id → CoreTile
var core_name_l: Label
var core_desc_l: Label
var focus_core := ""                 # 설명을 보여 줄 코어 (올린 것, 없으면 장착한 것)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = UiFont.make()

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.045, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := _screen(self)

	title_l = _label("", 36, UiStyle.C_TITLE)
	UiStyle.title(title_l, int(36 * ui_scale))
	root.add_child(title_l)

	map = MapView.new()
	map.world = self
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(0, 300) * ui_scale
	root.add_child(map)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(12 * ui_scale))
	root.add_child(bottom)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", int(4 * ui_scale))
	bottom.add_child(info)
	info_l = _label("", 24, C_INFO)
	info_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(info_l)
	hint_l = _label("", 12, UiStyle.C_DIM)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(hint_l)
	back_button = _button(bottom, back)
	cores_button = _button(bottom, open_cores)
	jump_button = _button(bottom, jump)

	_build_cores()


## 화면 여백 + 세로 상자
func _screen(parent: Node) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(28 * ui_scale))
	parent.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(12 * ui_scale))
	margin.add_child(root)
	return root


## 버튼: 글자 길이에 맞춰 늘어난다 (영어로 바꿔도 화면 밖으로 나가지 않게 최소 폭만 준다)
func _button(parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 56) * ui_scale
	UiStyle.button(b, font, int(24 * ui_scale))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## 동력 코어 장착 화면: 왼쪽 기체 설계도(장착 칸), 오른쪽 코어 아이콘들과 설명, 아래 [뒤로]
func _build_cores() -> void:
	cores_view = ColorRect.new()
	(cores_view as ColorRect).color = Color(0.02, 0.025, 0.045, 1.0)
	cores_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	cores_view.visible = false
	add_child(cores_view)
	var root := _screen(cores_view)
	cores_title = _label("", 36, UiStyle.C_TITLE)
	UiStyle.title(cores_title, int(36 * ui_scale))
	root.add_child(cores_title)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", int(20 * ui_scale))
	root.add_child(mid)
	blueprint = BlueprintView.new()
	blueprint.world = self
	blueprint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint.size_flags_stretch_ratio = 1.15
	mid.add_child(blueprint)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", int(14 * ui_scale))
	mid.add_child(side)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(12 * ui_scale))
	grid.add_theme_constant_override("v_separation", int(12 * ui_scale))
	side.add_child(grid)
	for id in Upgrades.CORES:
		var tile := CoreTile.new()
		tile.world = self
		tile.id = id
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0, 132) * ui_scale
		UiStyle.button(tile, font, int(12 * ui_scale))
		tile.toggle_mode = true
		tile.pressed.connect(func() -> void: equip(id))
		tile.mouse_entered.connect(func() -> void:
			focus_core = id
			_show_core())
		tile.mouse_exited.connect(func() -> void:
			if focus_core == id:
				focus_core = ""
			_show_core())
		grid.add_child(tile)
		core_tiles[id] = tile
	var desc := PanelContainer.new()
	desc.add_theme_stylebox_override("panel", UiStyle.panel(int(16 * ui_scale)))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(desc)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", int(8 * ui_scale))
	desc.add_child(dbox)
	core_name_l = _label("", 24, C_TAKEN)
	core_name_l.add_theme_font_override("font", UiFont.bold())
	dbox.add_child(core_name_l)
	core_desc_l = _label("", 12, C_INFO)
	core_desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_desc_l.add_theme_constant_override("line_spacing", int(4 * ui_scale))
	dbox.add_child(core_desc_l)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	cores_back = _button(bottom, close_cores)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(size * ui_scale))
	l.add_theme_color_override("font_color", col)
	return l


func open() -> void:
	visible = true
	cores_view.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	map.ship_at = float(profile.stage)
	refresh()


func close() -> void:
	visible = false


## 타이틀로 돌아간다 (타이틀에서 연 경우만)
func back() -> void:
	if not visible or not allow_back:
		return
	close()
	back_requested.emit()


func jump() -> void:
	if not visible:
		return
	close()
	jump_requested.emit()


func open_cores() -> void:
	if not visible:
		return
	cores_view.visible = true
	focus_core = ""
	refresh()


func close_cores() -> void:
	cores_view.visible = false
	refresh()


## 코어 장착·교체 (얻은 코어만)
func equip(id: String) -> bool:
	if not profile.toggle_equip(id):
		refresh()
		return false
	refresh()
	return true


## 월드 맵에서 스테이지를 고른다 (고를 수 없는 곳이면 false)
func select(i: int) -> bool:
	if not profile.select_stage(i):
		return false
	refresh()
	return true


## 숨은 개발자 명령 (안내 없음, 모든 빌드): Ctrl+Shift+O = 모든 스테이지를 고를 수 있게 (main.gd 와 같다 — 월드 맵은 일시정지 중이라 여기서도 받는다)
func _input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.ctrl_pressed and e.shift_pressed and e.keycode == KEY_O and profile != null:
		profile.open_all = true
		profile.save()
		refresh()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if cores_view.visible:
		match e.keycode:
			KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER:
				close_cores()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:   # 숫자 키: 그 번째 코어 장착·교체
				var ids := Upgrades.CORES.keys()
				var k: int = e.keycode - KEY_1
				if k < ids.size():
					equip(ids[k])
		get_viewport().set_input_as_handled()
		return
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			jump()
		KEY_ESCAPE, KEY_BACKSPACE:
			back()
		KEY_LEFT:
			select(profile.stage - 1)
		KEY_RIGHT:
			select(profile.stage + 1)
	get_viewport().set_input_as_handled()            # 맵을 연 동안엔 다른 키(ESC 메뉴 등)를 막는다. 나가는 길은 FTL 도약


func refresh() -> void:
	title_l.text = Loc.t("항로도 — 퇴각 항로")                 # 언어가 바뀌었을 수 있으니 열 때마다 다시
	cores_title.text = Loc.t("동력 코어 장착")
	jump_button.text = Loc.t("FTL 도약 ▶")
	back_button.text = Loc.t("뒤로")
	cores_back.text = Loc.t("뒤로")
	cores_button.text = Loc.t("동력 코어 장착")
	back_button.visible = allow_back
	var st: Dictionary = Stages.LIST[profile.stage]
	info_l.text = Loc.t("도약지 %d — 콜로서스 「%s」") % [profile.stage + 1, Loc.t(st["name"])]   # 구간 이름은 빼서 짧게 (영어에서 잘리지 않게)
	hint_l.text = Loc.t("은하를 눌러 도약지를 고르세요. 깬 곳은 다시 싸울 수 있습니다")
	for id in core_tiles:
		var tile: CoreTile = core_tiles[id]
		tile.set_pressed_no_signal(profile.equipped.has(id))
		tile.disabled = not profile.cores.has(id)
		tile.queue_redraw()
	_show_core()
	map.queue_redraw()
	blueprint.queue_redraw()


## 오른쪽 설명 칸: 올린 코어, 없으면 처음 장착한 코어, 그것도 없으면 안내
func _show_core() -> void:
	var id := focus_core
	if id == "" and not profile.equipped.is_empty():
		id = profile.equipped[0]
	if id == "":
		core_name_l.text = Loc.t("장착 칸이 비어 있습니다")
		core_name_l.add_theme_color_override("font_color", C_LOCKED)
		core_desc_l.text = Loc.t("콜로서스를 처리하면 그 동력 코어를 얻습니다. 코어를 눌러 장착하세요 — 장착한 코어만 작동합니다.")
		return
	var c: Dictionary = Upgrades.CORES[id]
	if profile.cores.has(id):
		core_name_l.text = Loc.t(c["name"]) + ("  " + Loc.t("[장착]") if profile.equipped.has(id) else "")
		core_name_l.add_theme_color_override("font_color", c["color"])
		core_desc_l.text = Loc.t(c["desc"])
	else:
		core_name_l.text = "???"
		core_name_l.add_theme_color_override("font_color", C_LOCKED)
		core_desc_l.text = Loc.t("콜로서스 「%s」를 처리하면 얻습니다") % _stage_name(c["from"])


static func _stage_name(id: String) -> String:
	for st in Stages.LIST:
		if st["id"] == id:
			return Loc.t(st["name"])
	return id


## 초 → "1:23.4"
static func fmt_time(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%d:%04.1f" % [m, sec - m * 60.0]


# ═══ 항로도 그림 ════════════════════════════════════════
class MapView extends Control:
	var world                                    # 바깥 world_map
	var ship_at := 0.0                           # 기체가 떠 있는 위치 (스테이지 번호, 고르면 미끄러져 간다)
	var hover := -1
	var t := 0.0
	var stars := []                              # [위치(0~1), 크기, 밝기, 깜빡임 위상]
	var puffs := []                              # 성운 조각 [자리(0~1), 반지름(높이 비), 색]
	# 지점(은하 9 + 목적지) 자리 (0~1): 손으로 놓은 굽이치는 항로 — 규칙적인 지그재그가 아니게
	const NODES := [Vector2(0.06, 0.74), Vector2(0.15, 0.32), Vector2(0.255, 0.6), Vector2(0.34, 0.14), Vector2(0.43, 0.48),
		Vector2(0.51, 0.86), Vector2(0.62, 0.6), Vector2(0.7, 0.2), Vector2(0.8, 0.52), Vector2(0.93, 0.34)]
	const BEND := [0.18, -0.25, 0.3, -0.12, 0.22, -0.3, 0.15, -0.2, 0.25]   # 구간마다 휘는 정도 (구간 길이 비)
	# 은하마다 다른 모양: [크기, 팔 수, 기울기(라디안), 납작함, 색조]
	const LOOK := [[1.0, 2, 0.3, 0.6, 0.0], [0.82, 3, -0.5, 0.75, 0.08], [1.18, 2, 1.1, 0.45, -0.06], [0.9, 2, -0.2, 0.85, 0.12],
		[1.08, 3, 0.7, 0.55, -0.1], [0.86, 2, -1.0, 0.5, 0.05], [1.2, 2, 0.15, 0.7, -0.04], [0.92, 3, 0.9, 0.6, 0.1], [1.04, 2, -0.6, 0.48, -0.08]]
	# 성운 (뒤 배경): [자리, 반지름(높이 비), 색]
	const NEBULAE := [[Vector2(0.2, 0.75), 0.42, Color(0.42, 0.2, 0.55)], [Vector2(0.55, 0.25), 0.5, Color(0.12, 0.36, 0.45)],
		[Vector2(0.85, 0.8), 0.4, Color(0.5, 0.22, 0.16)], [Vector2(0.38, 0.9), 0.3, Color(0.15, 0.25, 0.5)]]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 220:                            # 은하수 띠 (비스듬히) 를 따라 더 촘촘하게
			var p := Vector2(rng.randf(), rng.randf())
			if k % 3 == 0:
				var u := rng.randf()
				p = Vector2(u, 0.95 - 0.8 * u + rng.randfn(0.0, 0.08))
			stars.append([p, 1 if rng.randf() < 0.8 else 2, rng.randf_range(0.15, 0.7), rng.randf() * TAU if rng.randf() < 0.25 else -1.0])
		for nb in NEBULAE:                       # 성운은 크기가 제각각인 조각을 흩어 겹친다 (둥근 덩어리 하나로 보이지 않게)
			for k in 14:
				var off := Vector2(rng.randfn(0.0, 0.5), rng.randfn(0.0, 0.3)) * float(nb[1])
				puffs.append([nb[0] + off * Vector2(0.5625, 1.0), float(nb[1]) * rng.randf_range(0.15, 0.45), nb[2]])

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		t += dt
		ship_at = lerpf(ship_at, float(world.profile.stage), 1.0 - exp(-6.0 * dt))
		queue_redraw()

	## i 번째 지점(0~8 은하, 9 목적지) 화면 위치 (이름표 자리를 아래에 남긴다)
	func node_pos(i: int) -> Vector2:
		var q: Vector2 = NODES[clampi(i, 0, NODES.size() - 1)]
		return Vector2(lerpf(50.0, size.x - 60.0, q.x), lerpf(50.0, size.y - 70.0, q.y))

	## 구간 i → i+1 의 곡선 위 점 (u 0~1)
	func route_at(i: int, u: float) -> Vector2:
		var a := node_pos(i)
		var b := node_pos(i + 1)
		var c: Vector2 = (a + b) * 0.5 + (b - a).orthogonal() * BEND[i]
		return a.lerp(c, u).lerp(c.lerp(b, u), u)

	func _pick(p: Vector2) -> int:
		for i in Stages.MAP_STAGES:
			if node_pos(i).distance_to(p) < 44.0:
				return i
		return -1

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = _pick(e.position)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var i := _pick(e.position)
			if i >= 0:
				world.select(i)

	func _draw() -> void:
		var pr = world.profile
		var font: Font = world.font
		var n := Stages.MAP_STAGES
		for pf in puffs:                         # 성운: 옅은 조각을 겹쳐 둔다
			var c: Vector2 = Vector2(pf[0].x * size.x, pf[0].y * size.y)
			var r: float = pf[1] * size.y
			draw_circle(c, r, Color(pf[2], 0.03))
			draw_circle(c, r * 0.55, Color(pf[2], 0.03))
		for s in stars:                          # 별 (몇몇은 깜빡인다)
			var a: float = s[2]
			if s[3] >= 0.0:
				a *= 0.55 + 0.45 * sin(t * 2.0 + s[3])
			var sp: Vector2 = Vector2(s[0].x * size.x, s[0].y * size.y).floor()
			draw_rect(Rect2(sp, Vector2(s[1], s[1])), Color(0.75, 0.85, 1.0, a))
		for i in n:                              # 굽은 점선 항로: 깬 구간은 밝게, 빛 알갱이가 흐른다
			var lit: bool = pr.is_cleared(i)
			var col := Color(0.6, 0.9, 1.0, 0.85) if lit else Color(0.45, 0.47, 0.52, 0.5)
			var steps := int(node_pos(i).distance_to(node_pos(i + 1)) / 12.0)
			for s in steps:
				if s % 2 == 0:
					draw_line(route_at(i, float(s) / steps), route_at(i, float(s + 1) / steps), col, 2.0)
			if lit:
				draw_circle(route_at(i, fmod(t * 0.35 + i * 0.3, 1.0)), 2.5, Color(0.8, 1.0, 1.0, 0.9))
		for i in n:
			_galaxy(node_pos(i), i, pr)
		var dp := node_pos(n)                    # 목적지: 멀리 빛나는 별 (아직 닿을 수 없다)
		var dpulse := 0.5 + 0.5 * sin(t * 1.5)
		draw_circle(dp, 26.0 + 4.0 * dpulse, Color(0.75, 0.7, 0.55, 0.08))
		draw_circle(dp, 14.0, Color(0.75, 0.7, 0.55, 0.15))
		for k in 4:
			var d := Vector2.from_angle(k * PI * 0.5) * (30.0 + 6.0 * dpulse)
			draw_line(dp - d * 0.2, dp + d, Color(0.85, 0.8, 0.65, 0.5), 2.0)
		draw_circle(dp, 5.0, Color(0.95, 0.92, 0.8))
		_text(font, "%d. %s" % [n + 1, Loc.t(Stages.DESTINATION)], dp + Vector2(0, 50), Color(0.62, 0.64, 0.7))
		var i0 := clampi(int(floor(ship_at)), 0, n - 1)   # 기체: 고른 은하 위에 겹쳐 떠 있다 (이름표·안내 글을 가리지 않게)
		var i1 := clampi(i0 + 1, 0, n - 1)
		var f := ship_at - i0
		var sp2 := node_pos(i0).lerp(node_pos(i1), f) + Vector2(0, -8.0 + 3.0 * sin(t * 3.0))
		draw_texture_rect(Sprites.ship("b", 0.0), Rect2(sp2 - Vector2(20, 20), Vector2(40, 40)), false)
		draw_colored_polygon(PackedVector2Array([sp2 + Vector2(-4, 21), sp2 + Vector2(4, 21), sp2 + Vector2(0, 28.0 + 3.0 * sin(t * 20.0))]), Color(1.0, 0.6, 0.2))

	## 은하 하나: 깬 곳은 푸른 소용돌이, 고를 수 있는 다음 곳은 깜빡이는 금빛 테두리, 그 밖은 회색. 모양은 은하마다 다르다 (LOOK)
	func _galaxy(p: Vector2, i: int, pr) -> void:
		var cleared: bool = pr.is_cleared(i)
		var open: bool = pr.can_play(i)
		var lk: Array = LOOK[i % LOOK.size()]
		var sc: float = lk[0]
		var core := Color(0.75, 0.9, 1.0) if cleared else (Color(0.95, 0.85, 0.65) if open else Color(0.45, 0.47, 0.52))
		var arm := Color.from_hsv(fposmod(0.62 + lk[4], 1.0), 0.6, 1.0) if cleared else (Color.from_hsv(fposmod(0.09 + lk[4] * 0.5, 1.0), 0.35, 0.75) if open else Color(0.35, 0.37, 0.42))
		var spin := t * (0.35 if cleared or open else 0.08) + i * 1.3
		var squash := Vector2(1.0, lk[3])
		var tilt: float = lk[2]
		var arms: int = lk[1]
		for k in 3:                              # 은하 빛무리
			draw_circle(p, (36.0 - k * 9.0) * sc, Color(arm, 0.06 + 0.04 * k))
		for k in arms:                           # 나선 팔
			var pts := PackedVector2Array()
			for j in 18:
				var u := float(j) / 17.0
				var v := Vector2.from_angle(spin + k * TAU / arms + u * 3.4) * (5.0 + 30.0 * u) * sc
				pts.append(p + (v * squash).rotated(tilt))
			draw_polyline(pts, Color(arm, 0.85), 2.0)
			draw_circle(pts[pts.size() - 1], 1.5, Color(arm, 0.8))
		draw_circle(p, 7.0 * sc, core)
		draw_circle(p, 3.0 * sc, Color(1, 1, 1, 0.9 if cleared or open else 0.4))
		if open and not cleared:
			draw_arc(p, 42.0, 0.0, TAU, 36, Color(1.0, 0.85, 0.45, 0.5 + 0.4 * sin(t * 5.0)), 2.0)
		if i == pr.stage:
			draw_arc(p, 48.0, 0.0, TAU, 40, Color(0.75, 0.95, 1.0, 0.9), 2.0)
		elif i == hover and open:
			draw_arc(p, 48.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		var name := "???"
		if i < Stages.LIST.size() and (open or cleared):
			name = Loc.t(Stages.LIST[i]["name"])
		_text(world.font, "%d. %s" % [i + 1, name], p + Vector2(0, 54), core if cleared or open else Color(0.5, 0.52, 0.58))
		var bt: float = pr.best_time(i)
		if cleared and bt > 0.0:                 # 깬 곳: 최단 클리어 기록
			_text(world.font, Loc.t("최단 %s") % world.fmt_time(bt), p + Vector2(0, 70), Color(1.0, 0.85, 0.45, 0.9))

	func _text(font: Font, s: String, p: Vector2, c: Color) -> void:
		var fs := 12
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := (p - Vector2(w * 0.5, 0)).floor()
		draw_string(font, o + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		draw_string(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


# ═══ 동력 코어 화면: 기체 설계도 ════════════════════════════
## 푸른 모눈 위에 기체를 크게 그리고, 몸통에 장착 칸(보석 모양 빈 홈)을 둔다. 장착한 코어는 그 홈에 끼워져 빛난다.
## 홈을 누르면 그 코어를 뺀다. 아직 열리지 않은 칸은 잠김으로 보인다.
class BlueprintView extends Control:
	var world
	var t := 0.0
	const C_LINE := Color(0.45, 0.75, 1.0)
	const SLOTS_MAX := 2

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		t += dt
		queue_redraw()

	## 장착 칸 k 자리 (기체 몸통 위)
	func slot_pos(k: int) -> Vector2:
		var c := size * 0.5 + Vector2(0, 10)
		var s := _ship_size()
		return c + Vector2(0, s * 0.06) + Vector2((k - 0.5) * s * 0.28, 0) if SLOTS_MAX > 1 else c

	func _ship_size() -> float:
		return minf(size.x, size.y) * 0.72

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var eq: Array = world.profile.equipped
			for k in mini(eq.size(), SLOTS_MAX):
				if e.position.distance_to(slot_pos(k)) < 34.0:
					world.equip(eq[k])                # 끼운 코어를 누르면 뺀다
					return

	func _draw() -> void:
		var pr = world.profile
		var font: Font = world.font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.12))
		var g := 24.0                                # 모눈
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(C_LINE, 0.12 if int(x / g) % 4 == 0 else 0.05), 1.0)
			x += g
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(C_LINE, 0.12 if int(y / g) % 4 == 0 else 0.05), 1.0)
			y += g
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(C_LINE, 0.5), false, 2.0)
		var c := size * 0.5 + Vector2(0, 10)
		var s := _ship_size()
		var tex: Texture2D = Sprites.ship("b", 0.0)
		var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:   # 설계도 윤곽: 푸른 선 + 옅은 몸
			draw_texture_rect(tex, Rect2(r.position + o, r.size), false, Color(C_LINE, 0.45))
		draw_texture_rect(tex, r, false, Color(0.06, 0.12, 0.22, 0.92))
		var top := r.position.y + s * 0.08                          # 치수선
		draw_line(Vector2(r.position.x, r.end.y + 8), Vector2(r.end.x, r.end.y + 8), Color(C_LINE, 0.5), 1.0)
		for ex in [r.position.x, r.end.x]:
			draw_line(Vector2(ex, r.end.y + 2), Vector2(ex, r.end.y + 14), Color(C_LINE, 0.5), 1.0)
		_text(font, "PP-01  PARRY PIERCE", Vector2(c.x, r.end.y + 30), Color(C_LINE, 0.7))
		_text(font, Loc.t("장착 칸 %d / %d") % [pr.equipped.size(), pr.slots()], Vector2(c.x, top - 6), Color(C_LINE, 0.85))
		for k in SLOTS_MAX:                          # 장착 칸
			var p := slot_pos(k)
			var side := -1.0 if k == 0 else 1.0
			var lab := p + Vector2(side * s * 0.42, -s * 0.18)           # 지시선 → 이름표
			draw_polyline(PackedVector2Array([p + Vector2(side * 30, 0), Vector2(lab.x - side * 30, lab.y + 14), lab + Vector2(side * 30, 14)]), Color(C_LINE, 0.5), 1.0)
			var label := ""
			var col := Color(C_LINE, 0.8)
			if k >= pr.slots():                      # 잠긴 칸
				_socket(p, Color(0.35, 0.38, 0.45, 0.6), true)
				label = Loc.t("잠김")
				col = Color(0.5, 0.52, 0.58)
			elif k < pr.equipped.size():
				var id: String = pr.equipped[k]
				var cc: Color = Upgrades.CORES[id]["color"]
				draw_circle(p, 36.0, Color(cc, 0.12 + 0.06 * sin(t * 3.0)))
				CoreIcon.draw(self, p, 22.0, cc, true, 0.5 + 0.5 * sin(t * 3.0))
				label = Loc.t(Upgrades.CORES[id]["name"])
				col = cc
			else:
				_socket(p, Color(C_LINE, 0.55 + 0.3 * sin(t * 4.0)), false)
				label = Loc.t("빈 칸")
			_text(font, label, lab + Vector2(side * 30, 6), col)

	## 빈 홈: 보석 모양 점선 테두리 (잠긴 칸은 가위표)
	func _socket(p: Vector2, col: Color, locked: bool) -> void:
		var pts := PackedVector2Array()
		for q in CoreIcon.Observer.HEART_SHAPE:
			pts.append(p + q * 26.0)
		draw_colored_polygon(pts, Color(0.01, 0.03, 0.07, 0.9))
		for k in pts.size():
			var a := pts[k]
			var b := pts[(k + 1) % pts.size()]
			draw_line(a, a.lerp(b, 0.6), col, 2.0)
		if locked:
			draw_line(p + Vector2(-9, -9), p + Vector2(9, 9), col, 2.0)
			draw_line(p + Vector2(9, -9), p + Vector2(-9, 9), col, 2.0)

	func _text(font: Font, s: String, p: Vector2, c: Color) -> void:
		var fs := 12
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := (p - Vector2(w * 0.5, 0)).floor()
		draw_string(font, o + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		draw_string(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## 코어 칸 하나 (버튼): 보석 아이콘 + 이름. 장착하면 눌린(금빛) 상태, 아직 얻지 못했으면 꺼진 회색 + ???
class CoreTile extends Button:
	var world
	var id := ""

	func _draw() -> void:
		var pr = world.profile
		var c: Dictionary = Upgrades.CORES[id]
		var owned: bool = pr.cores.has(id)
		var col: Color = c["color"]
		var mid := Vector2(size.x * 0.5, size.y * 0.42)
		if pr.equipped.has(id):
			draw_circle(mid, 34.0, Color(col, 0.15))
		CoreIcon.draw(self, mid, 22.0, col, owned)
		var name := Loc.t(c["name"]) if owned else "???"
		var f: Font = world.font
		var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tc := (C_TAKEN if pr.equipped.has(id) else Color(0.88, 0.91, 0.96)) if owned else C_LOCKED
		draw_string(f, Vector2(floor((size.x - w) * 0.5), size.y - 16.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		if pr.equipped.has(id):
			var tag := Loc.t("[장착]")
			var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(f, Vector2(size.x - tw - 10.0, 22.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TAKEN)

extends RefCounted
## 진행 저장 (user://profile.cfg): 다음 스테이지, 처리한 콜로서스, 얻은 동력 코어, 장착한 코어 (장착 칸 수만큼만 작동한다).
## 죽으면 그 스테이지부터 다시 (진행은 클리어할 때만 저장된다). 헤드리스(테스트)에서는 디스크에 쓰지 않는다.

const Stages := preload("res://scripts/stages.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const PATH := "user://profile.cfg"

var path := PATH                     # 테스트에서는 다른 파일로 바꾼다
var persist := true                  # false 면 읽기·쓰기를 하지 않는다
var stage := 0                       # 다음에 싸울 스테이지 번호 (Stages.LIST)
var cleared: Array[String] = []      # 처음 처리한 콜로서스 id
var cores: Array[String] = []        # 얻은 코어
var equipped: Array[String] = []     # 장착한 코어 (작동하는 것은 이것뿐, slots() 개까지)
const SLOT_BONUS_AFTER := 4          # 이 번호의 스테이지(5스테이지)를 깨면 장착 칸이 하나 늘어난다


func load_from_disk() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	stage = clampi(int(cf.get_value("run", "stage", 0)), 0, Stages.LIST.size() - 1)
	cleared.assign(cf.get_value("run", "cleared", []))
	cores.clear()
	for id in cf.get_value("upgrade", "cores", []):  # 없어진 코어(기동·파동 등)는 버린다
		if Upgrades.CORES.has(id):
			cores.append(id)
	for st in Stages.LIST:                           # 처리한 콜로서스의 코어는 모두 가진다 (코어가 바뀐 경우 포함)
		var core: String = st.get("core", "")
		if cleared.has(st["id"]) and core != "" and not cores.has(core):
			cores.append(core)
	equipped.clear()
	for id in cf.get_value("upgrade", "equip", []):  # (옛 저장의 "equipped" 문자열은 무시)
		if cores.has(id) and not equipped.has(id) and equipped.size() < slots():
			equipped.append(id)
	if not cf.has_section_key("upgrade", "equip") and not cores.is_empty():  # 장착 기록이 없는 옛 저장: 마지막에 얻은 코어를 장착
		equipped.append(cores[cores.size() - 1])


func save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "stage", stage)
	cf.set_value("run", "cleared", Array(cleared))
	cf.set_value("upgrade", "cores", Array(cores))
	cf.set_value("upgrade", "equip", Array(equipped))
	cf.save(path)


func reset() -> void:
	stage = 0
	cleared.clear()
	cores.clear()
	equipped.clear()


## 스테이지 클리어: 처음이면 그 콜로서스의 코어를 얻는다 (빈 장착 칸이 있으면 바로 장착). 다음 스테이지로 넘어간다 (마지막이면 그대로). 보상 내용을 돌려준다
func record_clear(stage_idx: int) -> Dictionary:
	var st: Dictionary = Stages.LIST[stage_idx]
	var id: String = st["id"]
	var got := {"first": false, "core": ""}
	if not cleared.has(id):
		cleared.append(id)
		got["first"] = true
		var core: String = st.get("core", "")
		if core != "" and not cores.has(core):
			cores.append(core)
			got["core"] = core
			if equipped.size() < slots():          # 빈 칸이 있으면 바로 장착
				equipped.append(core)
	stage = mini(stage_idx + 1, Stages.LIST.size() - 1)
	save()
	return got


## 장착 칸 수: 1개, 5스테이지를 깨면 2개
func slots() -> int:
	var n := 1
	var k := SLOT_BONUS_AFTER                    # (상수 그대로 쓰면 아직 스테이지가 그만큼 없을 때 파싱 오류)
	if k < Stages.LIST.size() and cleared.has(Stages.LIST[k]["id"]):
		n += 1
	return n


## 코어 장착·해제: 장착된 것을 누르면 해제, 아니면 장착 (칸이 다 찼으면 가장 먼저 장착한 것과 바꾼다)
func toggle_equip(id: String) -> bool:
	if equipped.has(id):
		equipped.erase(id)
	elif cores.has(id):
		if equipped.size() >= slots():
			equipped.pop_front()
		equipped.append(id)
	else:
		return false
	save()
	return true


## 고를 수 있는 스테이지인가: 만들어진 스테이지이고, 첫 스테이지이거나 바로 앞 스테이지를 깼다 (깬 스테이지는 다시 고를 수 있다)
func can_play(i: int) -> bool:
	if i < 0 or i >= Stages.LIST.size():
		return false
	return i == 0 or cleared.has(Stages.LIST[i - 1]["id"])


func is_cleared(i: int) -> bool:
	return i >= 0 and i < Stages.LIST.size() and cleared.has(Stages.LIST[i]["id"])


## 월드 맵에서 다음 도약지를 고른다
func select_stage(i: int) -> bool:
	if not can_play(i):
		return false
	stage = i
	save()
	return true

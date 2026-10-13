extends RefCounted
## 진행 저장 (user://profile.cfg): 다음 스테이지, 처리한 콜로서스, 얻은 동력 코어 (모두 영구 강화로 켜져 있다).
## 죽으면 그 스테이지부터 다시 (진행은 클리어할 때만 저장된다). 헤드리스(테스트)에서는 디스크에 쓰지 않는다.

const Stages := preload("res://scripts/stages.gd")
const PATH := "user://profile.cfg"

var path := PATH                     # 테스트에서는 다른 파일로 바꾼다
var persist := true                  # false 면 읽기·쓰기를 하지 않는다
var stage := 0                       # 다음에 싸울 스테이지 번호 (Stages.LIST)
var cleared: Array[String] = []      # 처음 처리한 콜로서스 id
var cores: Array[String] = []        # 얻은 코어 (모두 적용)


func load_from_disk() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	stage = clampi(int(cf.get_value("run", "stage", 0)), 0, Stages.LIST.size() - 1)
	cleared.assign(cf.get_value("run", "cleared", []))
	cores.assign(cf.get_value("upgrade", "cores", []))
	var old := cores.find("mobility")                # v0.34: 관측자의 코어가 기동 코어 → 파동 코어로 바뀜
	if old >= 0:
		cores[old] = "pulse"
	for st in Stages.LIST:                           # v0.35: 노드 트리 폐기. 처리한 콜로서스의 코어는 모두 가진다
		var core: String = st.get("core", "")
		if cleared.has(st["id"]) and core != "" and not cores.has(core):
			cores.append(core)


func save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "stage", stage)
	cf.set_value("run", "cleared", Array(cleared))
	cf.set_value("upgrade", "cores", Array(cores))
	cf.save(path)


func reset() -> void:
	stage = 0
	cleared.clear()
	cores.clear()


## 스테이지 클리어: 처음이면 그 콜로서스의 코어를 얻는다 (영구 강화). 다음 스테이지로 넘어간다 (마지막이면 그대로). 보상 내용을 돌려준다
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
	stage = mini(stage_idx + 1, Stages.LIST.size() - 1)
	save()
	return got


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

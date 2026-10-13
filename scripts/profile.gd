extends RefCounted
## 진행 저장 (user://profile.cfg): 다음 스테이지, 처리한 콜로서스, 찍은 노드, 보유·장착 코어.
## 죽으면 그 스테이지부터 다시 (진행은 클리어할 때만 저장된다). 헤드리스(테스트)에서는 디스크에 쓰지 않는다.

const Upgrades := preload("res://scripts/upgrades.gd")
const Stages := preload("res://scripts/stages.gd")
const PATH := "user://profile.cfg"

var path := PATH                     # 테스트에서는 다른 파일로 바꾼다
var persist := true                  # false 면 읽기·쓰기를 하지 않는다
var stage := 0                       # 다음에 싸울 스테이지 번호 (Stages.LIST)
var cleared: Array[String] = []      # 처음 처리한 콜로서스 id (1개당 부산물 포인트 1)
var nodes: Array[String] = []        # 찍은 노드
var cores: Array[String] = []        # 보유 코어
var equipped := ""                   # 장착 코어 ("" = 없음)
var bonus_points := 0                # 개발용 (F7)


func load_from_disk() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	stage = clampi(int(cf.get_value("run", "stage", 0)), 0, Stages.LIST.size() - 1)
	cleared.assign(cf.get_value("run", "cleared", []))
	nodes.assign(cf.get_value("upgrade", "nodes", []))
	cores.assign(cf.get_value("upgrade", "cores", []))
	equipped = str(cf.get_value("upgrade", "equipped", ""))
	bonus_points = int(cf.get_value("dev", "bonus_points", 0))
	if not cores.has(equipped):
		equipped = ""


func save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "stage", stage)
	cf.set_value("run", "cleared", Array(cleared))
	cf.set_value("upgrade", "nodes", Array(nodes))
	cf.set_value("upgrade", "cores", Array(cores))
	cf.set_value("upgrade", "equipped", equipped)
	cf.set_value("dev", "bonus_points", bonus_points)
	cf.save(path)


func reset() -> void:
	stage = 0
	cleared.clear()
	nodes.clear()
	cores.clear()
	equipped = ""
	bonus_points = 0


func points_total() -> int:
	return cleared.size() + bonus_points


func points_left() -> int:
	return points_total() - nodes.size()


## 스테이지 클리어: 처음이면 코어 + 포인트 1. 다음 스테이지로 넘어간다 (마지막이면 그대로). 보상 내용을 돌려준다
func record_clear(stage_idx: int) -> Dictionary:
	var st: Dictionary = Stages.LIST[stage_idx]
	var id: String = st["id"]
	var got := {"first": false, "core": "", "point": 0}
	if not cleared.has(id):
		cleared.append(id)
		got["first"] = true
		got["point"] = 1
		var core: String = st.get("core", "")
		if core != "" and not cores.has(core):
			cores.append(core)
			got["core"] = core
			if equipped == "":
				equipped = core                # 첫 코어는 바로 장착 (정비 화면에서 해제·교체)
	stage = mini(stage_idx + 1, Stages.LIST.size() - 1)
	save()
	return got


func take_node(id: String) -> bool:
	if not Upgrades.can_take(id, nodes, points_left()):
		return false
	nodes.append(id)
	save()
	return true


## 장착 (같은 코어를 다시 고르면 해제)
func equip(core: String) -> void:
	if core == equipped or core == "":
		equipped = ""
	elif cores.has(core):
		equipped = core
	save()

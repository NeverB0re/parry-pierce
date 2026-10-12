extends RefCounted
## 플레이 기록: 한 판(시작 → 승리/기체 손실/재시작/종료)마다 JSON 한 개를 user://telemetry/ 에 남긴다.
## 직접 플레이할 수 없는 개발 과정에서, 사용자가 이 파일을 보내 주면 수치·난이도를 데이터로 판단하기 위한 것.
## 헤드리스(테스트)에서는 기록하지 않는다.

const DIR := "user://telemetry"

var dir := DIR                       # 테스트에서는 다른 폴더로 바꾼다

var enabled := true
var started_ms := 0
var finished := false
var counts := {}                     # 이름 → 횟수
var damage := {}                     # 공격 종류 → 누적 피해
var hurt := {}                       # 피격 원인 → 횟수
var marks: Array[Dictionary] = []    # [{"name": 이벤트, "t": 게임 시간}]
var last_path := ""


func begin() -> void:
	started_ms = Time.get_ticks_msec()
	finished = false
	counts = {}
	damage = {}
	hurt = {}
	marks = []


func add(name: String, n := 1) -> void:
	counts[name] = int(counts.get(name, 0)) + n


func hit(kind: String, dmg: int) -> void:
	add("hit_" + kind)
	damage[kind] = int(damage.get(kind, 0)) + dmg


func hurt_by(cause: String) -> void:
	hurt[cause] = int(hurt.get(cause, 0)) + 1


func mark(name: String, game_t: float) -> void:
	marks.append({"name": name, "t": snappedf(game_t, 0.01)})


## 한 판을 마치고 파일로 남긴다. 아무 일도 없던 판(1초 미만, 행동 없음)은 남기지 않는다
func finish(result: String, game_t: float, lives: int, extra := {}) -> void:
	if finished:
		return
	finished = true
	if not enabled or (game_t < 1.0 and counts.is_empty()):
		return
	var data := {
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"date": Time.get_datetime_string_from_system(),
		"result": result,
		"game_time": snappedf(game_t, 0.01),
		"real_time": snappedf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.01),
		"lives_left": lives,
		"counts": counts,
		"damage": damage,
		"hurt": hurt,
		"marks": marks,
	}
	data.merge(extra)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	last_path = "%s/run_%s_%s.json" % [dir, stamp, result]
	var f := FileAccess.open(last_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))


static func folder_path() -> String:
	return ProjectSettings.globalize_path(DIR)

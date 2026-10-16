extends RefCounted
## 플레이 기록: 한 판(시작 → 승리/기체 손실/재시작/종료)마다 JSON 한 개를 user://telemetry/ 에 남긴다.
## 텔레메트리 빌드(내보내기 기능 "telemetry", dev 빌드)는 실행 파일 옆 <exe 이름>_log.md 에도 판마다 요약을 덧붙인다.
## 직접 플레이할 수 없는 개발 과정에서, 사용자가 이 파일을 보내 주면 수치·난이도를 데이터로 판단하기 위한 것.
## 헤드리스(테스트)에서는 기록하지 않는다.

const DIR := "user://telemetry"

var dir := DIR                       # 테스트에서는 다른 폴더로 바꾼다

var enabled := true
var md_path := ""                    # 텔레메트리 빌드: 판마다 요약을 덧붙일 md 파일 (실행 파일 옆). "" = 쓰지 않음
var started_ms := 0
var finished := false
var counts := {}                     # 이름 → 횟수
var damage := {}                     # 공격 종류 → 누적 피해
var hurt := {}                       # 피격 원인 → 횟수
var marks: Array[Dictionary] = []    # [{"name": 이벤트, "t": 게임 시간}]
var seq: Array[Dictionary] = []      # 보스 패턴 순서 [{"name": 패턴, "t": 게임 시간}]
var last_path := ""


func begin() -> void:
	started_ms = Time.get_ticks_msec()
	finished = false
	counts = {}
	damage = {}
	hurt = {}
	marks = []
	seq = []


func add(name: String, n := 1) -> void:
	counts[name] = int(counts.get(name, 0)) + n


func hit(kind: String, dmg: int) -> void:
	add("hit_" + kind)
	damage[kind] = int(damage.get(kind, 0)) + dmg


func hurt_by(cause: String) -> void:
	hurt[cause] = int(hurt.get(cause, 0)) + 1


func mark(name: String, game_t: float) -> void:
	marks.append({"name": name, "t": snappedf(game_t, 0.01)})


## 보스 패턴이 시작됨 (횟수 + 순서)
func pattern(name: String, game_t: float) -> void:
	add("atk_" + name)
	seq.append({"name": name, "t": snappedf(game_t, 0.01)})


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
		"patterns": seq,
	}
	data.merge(extra)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	last_path = "%s/run_%s_%s.json" % [dir, stamp, result]
	var f := FileAccess.open(last_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
	if md_path != "":
		_append_md(data)


## 텔레메트리 빌드: 판마다 사람이 바로 읽을 수 있는 요약을 실행 파일 옆 md 파일에 덧붙인다
func _append_md(d: Dictionary) -> void:
	var gt := float(d["game_time"])
	var lines := PackedStringArray()
	lines.append("## %s · %s · %s · %d분 %02d초" % [str(d["date"]).replace("T", " "), str(d.get("stage", "?")), str(d["result"]), int(gt) / 60, int(gt) % 60])
	lines.append("")
	var build := md_path.get_file().trim_suffix("_log.md")       # 실행 파일 이름 (예: ParryPierce0.50-dev08)
	lines.append("- 빌드 %s · 남은 실드 %d · 끝난 페이즈 %s · 코어 %s · 외부 시스템 %s" % [build, int(d["lives_left"]), str(d.get("phase", "?")), str(d.get("armor_hp", "?")), str(d.get("part_hp", "?"))])
	lines.append("- 피격: %s" % _fmt(d["hurt"]))
	lines.append("- 준 피해: %s" % _fmt(d["damage"]))
	var pats := {}
	var acts := {}
	for k in d["counts"]:
		if str(k).begins_with("atk_"):
			pats[str(k).trim_prefix("atk_")] = d["counts"][k]
		else:
			acts[k] = d["counts"][k]
	lines.append("- 보스 패턴: %s" % _fmt(pats))
	lines.append("- 행동: %s" % _fmt(acts))
	lines.append("- 흐름: %s" % _timeline(d["marks"]))
	lines.append("- 패턴 순서: %s" % _timeline(d.get("patterns", [])))
	lines.append("")
	var exists := FileAccess.file_exists(md_path)
	var f := FileAccess.open(md_path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if exists:
		f.seek_end()
	else:
		f.store_string("# Parry Pierce 플레이 기록\n\n판마다 아래에 하나씩 쌓입니다. 이 파일을 그대로 보내 주세요.\n\n")
	f.store_string("\n".join(lines) + "\n")


## [{name, t}, ...] → "0:07 이름, ..."
static func _timeline(list: Array) -> String:
	var out := PackedStringArray()
	for m in list:
		var mt := float(m["t"])
		out.append("%d:%02d %s" % [int(mt) / 60, int(mt) % 60, str(m["name"])])
	return ", ".join(out) if not out.is_empty() else "-"


## {이름: 횟수} → "이름 ×횟수, ..." (많은 순)
static func _fmt(m: Dictionary) -> String:
	if m.is_empty():
		return "-"
	var keys := m.keys()
	keys.sort_custom(func(a, b): return int(m[a]) > int(m[b]))
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s ×%d" % [str(k), int(m[k])])
	return ", ".join(parts)


static func folder_path() -> String:
	return ProjectSettings.globalize_path(DIR)

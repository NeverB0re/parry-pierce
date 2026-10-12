#!/usr/bin/env bash
# 헤드리스 테스트 전부 실행. 창이 뜨지 않는다.
# 사용: GODOT=<Godot 콘솔 실행 파일 경로> tests/run.sh
#   예) GODOT="/c/Users/me/Godot/Godot_v4.7.2-stable_win64_console.exe" tests/run.sh
# 테스트 폴더에는 .gdignore 가 있어 Godot 가 가져오기·내보내기에 포함하지 않는다 (-s 로 절대 경로 실행).
set -u
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
ROOT="$(pwd -W 2>/dev/null || pwd)"
fail=0

run() {
	local name="$1"; shift
	local out
	out="$(timeout 180 "$G" --headless --path "$ROOT" -s "$ROOT/tests/$name" "$@" 2>&1)"
	if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		echo "[ERROR] $name"
		echo "$out" | grep -E "SCRIPT ERROR|Parse Error|at:" | head -10
		fail=1
		return
	fi
	echo "$out" | grep -E "^FAIL  " && fail=1
	echo "[$name] $(echo "$out" | grep -E "FAILS [0-9]|smoke ok|stages ok" | tail -1)"
}

run test_rules.gd
run smoke.gd
run smoke.gd -- --touch
run smoke_stages.gd
exit $fail
